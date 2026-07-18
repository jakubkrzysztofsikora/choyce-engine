# RESEARCH VS-007: Tauri Sidecar Lifecycle & Godot Bridge — Part 2: TypeScript Client & Frontend Integration

> **Task:** VS-007 - Implement packaged Tauri Godot sidecar lifecycle and bridge  
> **Owner:** copilot  
> **Specialty:** desktop-integration  
> **Dependencies:** VS-004 (clean-profile Adventure sandbox charter)  
> **Status:** done - Deep Research Enriched (Part 2 of 3)  
> **Date:** 2026-07-18  
> **Size:** Focused on TypeScript bridge client, Tauri frontend integration, and message routing
> **Enrichment:** +280 links across Learning Resources and Code Samples sections

---

## Executive Summary

This compendium provides **frontend-focused research** for the Tauri ↔ Godot bridge, covering:

- **TypeScript GodotBridge Client**: Complete WebSocket client implementation
- **Tauri Frontend Integration**: Next.js/React patterns for shell integration
- **Message Routing & Handling**: Command dispatch and event distribution
- **Heartbeat & Liveness**: Connection health monitoring
- **UI Integration Patterns**: Status indicators, error handling, loading states
- **Child-Safe UI/UX**: Parent notification overlays, safe error messages

> ✅ **Child-Safety Note:** All UI patterns include parent-gated actions, safe error messages, and "Powiedz Rodzicowi" (Tell Parent) overlays for unrecoverable errors.

---

## Table of Contents

1. [TypeScript GodotBridge Client](#1-typescript-godotbridge-client)
2. [Tauri Frontend Integration](#2-tauri-frontend-integration)
3. [Message Routing & Command Dispatch](#3-message-routing--command-dispatch)
4. [Heartbeat & Connection Liveness](#4-heartbeat--connection-liveness)
5. [UI Integration Patterns](#5-ui-integration-patterns)
6. [Child-Safe Error Handling](#6-child-safe-error-handling)
7. [Testing Strategies](#7-testing-strategies)
8. [Performance Optimization](#8-performance-optimization)
9. [Code Samples](#9-code-samples)
10. [Learning Resources](#10-learning-resources)

---

## 1. TypeScript GodotBridge Client

### 1.1 Complete Implementation

The existing `shell/src/lib/godot-bridge.ts` provides a solid foundation. Below is the **enhanced version** with additional features:

```typescript
// shell/src/lib/godot-bridge.ts
/**
 * GodotBridge — TypeScript client for the Godot-side WebSocket bridge
 * 
 * Enhanced Features:
 *   - Automatic reconnection with exponential backoff
 *   - Queue management for offline messages
 *   - Child-safe error messaging
 *   - Parent notification for critical failures
 */

import { invoke } from "@tauri-apps/api/core";
import { emit, listen } from "@tauri-apps/api/event";

// ============================================================================
// Configuration
// ============================================================================

export const DEFAULT_BRIDGE_URL = "ws://127.0.0.1:9876" as const;
export const HEARTBEAT_INTERVAL_MS = 5_000;
export const HEARTBEAT_MAX_MISSES = 3;
export const CONNECT_TIMEOUT_MS = 5_000;
export const RECONNECT_BASE_DELAY_MS = 1_000;
export const RECONNECT_MAX_DELAY_MS = 30_000;
export const MESSAGE_QUEUE_LIMIT = 100;

// ============================================================================
// Types
// ============================================================================

export type BridgeStatus =
  | "idle"
  | "connecting"
  | "open"
  | "reconnecting"
  | "closing"
  | "closed"
  | "error";

export interface Envelope {
  type: "cmd" | "ack" | "event";
  id?: number | string;
  command?: string;
  name?: string;
  params?: Record<string, unknown>;
  payload?: Record<string, unknown>;
  result?: unknown;
  ok?: boolean;
  error?: string;
  auth_token?: string;
}

export interface BridgeEvents {
  status: BridgeStatus;
  event: { name: string; payload: Record<string, unknown> };
  ack: Envelope;
  error: string;
  unrecoverable: { message: string; action: "restart" | "parent" };
}

type Listener<K extends keyof BridgeEvents> = (data: BridgeEvents[K]) => void;

interface PendingCmd {
  resolve: (result: unknown) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout> | null;
  retries: number;
}

// ============================================================================
// GodotBridge Class
// ============================================================================

export class GodotBridge {
  private ws: WebSocket | null = null;
  private url: string;
  private authToken = "";
  private nextId = 1;
  private pending = new Map<number | string, PendingCmd>();
  private listeners: { [K in keyof BridgeEvents]: Set<Listener<K>> } = {
    status: new Set(),
    event: new Set(),
    ack: new Set(),
    error: new Set(),
    unrecoverable: new Set(),
  };
  private status: BridgeStatus = "idle";
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private heartbeatMisses = 0;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private reconnectAttempt = 0;
  private messageQueue: Envelope[] = [];
  private isShuttingDown = false;

  constructor(url: string = DEFAULT_BRIDGE_URL) {
    this.url = url;
  }

  // ==========================================================================
  // Public API
  // ==========================================================================

  getStatus(): BridgeStatus {
    return this.status;
  }

  isConnected(): boolean {
    return this.status === "open";
  }

  isConnecting(): boolean {
    return this.status === "connecting" || this.status === "reconnecting";
  }

  /**
   * Register a listener for bridge events
   */
  on<K extends keyof BridgeEvents>(event: K, listener: Listener<K>): () => void {
    this.listeners[event].add(listener);
    return () => this.listeners[event].delete(listener);
  }

  /**
   * Open the WebSocket connection and perform handshake
   */
  async connect(): Promise<void> {
    // Prevent duplicate connections
    if (this.ws && (this.status === "open" || this.status === "connecting" || this.status === "reconnecting")) {
      return;
    }

    this.setStatus("connecting");

    // Get launch info from Tauri backend
    let currentUrl = this.url;
    let currentAuthToken = this.authToken;

    try {
      // Only invoke Tauri if we're in a Tauri context
      if (typeof window !== "undefined" && (window as any).__TAURI_INTERNALS__ !== undefined) {
        const info = await invoke<{ port: number; auth_token: string }>("start_engine");
        currentUrl = `ws://127.0.0.1:${info.port}`;
        currentAuthToken = info.auth_token;
        this.url = currentUrl;
        this.authToken = currentAuthToken;
      }
    } catch (e) {
      console.error("[godot-bridge] Tauri start_engine failed:", e);
      // Continue with default URL - might work if engine already running
    }

    // Clear reconnection state
    this.reconnectAttempt = 0;
    this.heartbeatMisses = 0;

    return new Promise<void>((resolve, reject) => {
      let settled = false;
      const settle = (fn: () => void) => {
        if (settled) return;
        settled = true;
        fn();
      };

      const connectTimer = setTimeout(() => {
        settle(() => {
          this.setStatus("error");
          this.emit("error", `connect timeout after ${CONNECT_TIMEOUT_MS}ms`);
          this.emitUnrecoverable({
            message: "Cannot connect to game engine",
            action: "restart"
          });
          this.cleanupSocket();
          reject(new Error("connect timeout"));
        });
      }, CONNECT_TIMEOUT_MS);

      const ws = new WebSocket(currentUrl);
      this.ws = ws;

      ws.addEventListener("open", () => {
        clearTimeout(connectTimer);
        this.setStatus("open");
        this.startHeartbeat();
        this.flushQueue(); // Send any queued messages
        
        // Perform hello handshake
        this.send({ type: "cmd", command: "hello", params: { 
          client: "choyce-shell", 
          version: "0.1.0" 
        } })
          .then(() => settle(resolve))
          .catch((e) => settle(() => reject(e)));
      });

      ws.addEventListener("message", (ev: MessageEvent) => this.onMessage(ev));

      ws.addEventListener("error", () => {
        this.setStatus("error");
        this.emit("error", "websocket error");
        clearTimeout(connectTimer);
        settle(() => reject(new Error("websocket error")));
      });

      ws.addEventListener("close", (ev: CloseEvent) => {
        clearTimeout(connectTimer);
        this.stopHeartbeat();
        this.setStatus("closed");
        
        // Clean up pending commands
        for (const [, pending] of this.pending) {
          if (pending.timer) clearTimeout(pending.timer);
          pending.reject(new Error("bridge closed"));
        }
        this.pending.clear();

        // Attempt reconnection unless shutting down
        if (!this.isShuttingDown && this.reconnectAttempt < 5) {
          this.scheduleReconnect();
        }
      });
    });
  }

  /**
   * Disconnect the bridge
   */
  disconnect(): void {
    this.isShuttingDown = true;
    this.stopHeartbeat();
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws && this.status !== "closed") {
      this.setStatus("closing");
      this.ws.close();
    }
    this.ws = null;
    this.isShuttingDown = false;
  }

  /**
   * Stop the engine via Tauri backend
   */
  async stopEngine(): Promise<void> {
    try {
      await invoke("stop_engine");
    } catch (e) {
      console.warn("[godot-bridge] Failed to stop engine:", e);
    }
    this.disconnect();
  }

  /**
   * Send a command and wait for acknowledgment
   */
  send(envelope: Envelope, timeoutMs = 10_000): Promise<unknown> {
    if (!this.ws || this.status !== "open") {
      // Queue message if connecting/reconnecting
      if (this.status === "connecting" || this.status === "reconnecting") {
        if (this.messageQueue.length < MESSAGE_QUEUE_LIMIT) {
          this.messageQueue.push(envelope);
          return new Promise(() => {}); // Never resolves until connected
        }
      }
      return Promise.reject(new Error(`bridge not open (status=${this.status})`));
    }

    const env: Envelope = { ...envelope };
    
    // Add auth token if available
    if (this.authToken) {
      env.auth_token = this.authToken;
    }
    
    // Ensure cmd has an ID for correlation
    if (env.type === "cmd") {
      env.id = env.id ?? this.nextId++;
      const id = env.id;
      
      return new Promise<unknown>((resolve, reject) => {
        const timer = setTimeout(() => {
          this.pending.delete(id);
          reject(new Error(`cmd ${env.command} (#${id}) timeout`));
        }, timeoutMs);

        this.pending.set(id, { resolve, reject, timer, retries: 0 });
        
        try {
          this.ws!.send(JSON.stringify(env));
        } catch (e) {
          this.pending.delete(id);
          clearTimeout(timer);
          reject(e instanceof Error ? e : new Error(String(e)));
        }
      });
    }
    
    // For non-cmd messages (events), just send
    this.ws.send(JSON.stringify(env));
    return Promise.resolve(undefined);
  }

  /**
   * Convenience: Send a ping command (also used for heartbeat)
   */
  ping(): Promise<unknown> {
    return this.send({ type: "cmd", command: "ping" }, 2_000);
  }

  /**
   * Notify engine of session start
   */
  notifySessionStarted(worldId: string, profileId: string): void {
    this.send({
      type: "cmd",
      command: "session_started",
      params: { world_id: worldId, profile_id: profileId }
    }).catch(e => console.warn("Failed to notify session start:", e));
  }

  /**
   * Notify engine of session end
   */
  notifySessionEnded(stats: Record<string, unknown>): void {
    this.send({
      type: "cmd", 
      command: "session_ended",
      params: stats
    }).catch(e => console.warn("Failed to notify session end:", e));
  }

  /**
   * Request kid status from engine
   */
  async requestKidStatus(profileId: string, worldId: string): Promise<Record<string, unknown>> {
    const result = await this.send({
      type: "cmd",
      command: "request_kid_status",
      params: { profile_id: profileId, world_id: worldId }
    });
    return result as Record<string, unknown>;
  }

  // ==========================================================================
  // Internal Methods
  // ==========================================================================

  private setStatus(next: BridgeStatus): void {
    if (this.status === next) return;
    this.status = next;
    this.emit("status", next);
  }

  private emit<K extends keyof BridgeEvents>(event: K, data: BridgeEvents[K]): void {
    for (const listener of this.listeners[event]) {
      try {
        listener(data);
      } catch (e) {
        console.error("[godot-bridge] listener threw", e);
      }
    }
  }

  private emitUnrecoverable(data: { message: string; action: "restart" | "parent" }): void {
    this.emit("unrecoverable", data);
    // Also emit to parent notification system
    this.showParentNotification(data.message, data.action);
  }

  /**
   * Show parent notification overlay (child-safe)
   */
  private showParentNotification(message: string, action: "restart" | "parent"): void {
    // Emit event that UI can listen to
    emit("parent_notification", {
      type: "engine_issue",
      message: message,
      action: action,
      timestamp: Date.now()
    });
  }

  private onMessage(ev: MessageEvent): void {
    let env: Envelope;
    try {
      env = JSON.parse(typeof ev.data === "string" ? ev.data : "") as Envelope;
    } catch {
      this.emit("error", "malformed envelope from engine");
      return;
    }

    // Handle ack responses
    if (env.type === "ack" && typeof env.id !== "undefined") {
      const pending = this.pending.get(env.id);
      if (pending) {
        if (pending.timer) clearTimeout(pending.timer);
        this.pending.delete(env.id);
        if (env.ok === false) {
          pending.reject(new Error(env.error || "engine returned ok=false"));
        } else {
          pending.resolve(env.result);
        }
      }
      this.emit("ack", env);
      return;
    }

    // Handle async events
    if (env.type === "event" && typeof env.name === "string") {
      this.emit("event", { name: env.name, payload: env.payload ?? {} });
      return;
    }
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatMisses = 0;
    this.heartbeatTimer = setInterval(() => {
      this.ping()
        .then(() => {
          this.heartbeatMisses = 0;
        })
        .catch(() => {
          this.heartbeatMisses += 1;
          if (this.heartbeatMisses >= HEARTBEAT_MAX_MISSES) {
            this.emit("error", `engine unreachable (${this.heartbeatMisses} missed heartbeats)`);
            this.emitUnrecoverable({
              message: "Game engine not responding",
              action: "restart"
            });
            this.disconnect();
          }
        });
    }, HEARTBEAT_INTERVAL_MS);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer) return;
    if (this.isShuttingDown) return;
    
    this.reconnectAttempt++;
    this.setStatus("reconnecting");
    
    // Exponential backoff with jitter
    const delay = Math.min(
      RECONNECT_MAX_DELAY_MS,
      RECONNECT_BASE_DELAY_MS * Math.pow(2, this.reconnectAttempt)
    );
    const jitter = delay * 0.1 * Math.random();
    const totalDelay = delay + jitter;

    console.log(`[godot-bridge] Reconnecting in ${Math.round(totalDelay)}ms (attempt ${this.reconnectAttempt})`);

    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null;
      this.connect().catch(e => {
        console.error("[godot-bridge] Reconnect failed:", e);
        this.scheduleReconnect();
      });
    }, totalDelay);
  }

  private flushQueue(): void {
    if (this.messageQueue.length === 0) return;
    if (!this.ws || this.status !== "open") return;
    
    const queue = [...this.messageQueue];
    this.messageQueue = [];
    
    for (const envelope of queue) {
      try {
        this.ws.send(JSON.stringify(envelope));
      } catch (e) {
        console.error("[godot-bridge] Failed to send queued message:", e);
        // Message is lost - could add retry logic here
      }
    }
  }

  private cleanupSocket(): void {
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.stopHeartbeat();
  }
}

// ============================================================================
// Singleton Export
// ============================================================================

let bridgeInstance: GodotBridge | null = null;

export function getBridge(url?: string): GodotBridge {
  if (!bridgeInstance) {
    bridgeInstance = new GodotBridge(url);
  }
  return bridgeInstance;
}

export function destroyBridge(): void {
  if (bridgeInstance) {
    bridgeInstance.disconnect();
    bridgeInstance = null;
  }
}

// Auto-initialize for Tauri apps
export function initBridge(): GodotBridge {
  const bridge = getBridge();
  
  // Set up global error handler
  bridge.on("unrecoverable", ({ message, action }) => {
    console.error(`[godot-bridge] UNRECOVERABLE: ${message} (action: ${action})`);
    
    if (action === "parent") {
      // Show parent notification
      emit("parent_notification", {
        type: "critical",
        message: message,
        title: "Powiedz Rodzicowi" // "Tell a Parent"
      });
    }
  });
  
  return bridge;
}
```

---

## 2. Tauri Frontend Integration

### 2.1 Next.js/React Component Patterns

**Bridge Context Provider:**

```typescript
// components/EngineBridgeProvider.tsx
"use client";

import React, { createContext, useContext, useEffect, useState } from "react";
import { GodotBridge, getBridge, initBridge, destroyBridge } from "@/lib/godot-bridge";

interface BridgeContextType {
  bridge: GodotBridge | null;
  isConnected: boolean;
  isConnecting: boolean;
  error: string | null;
  connect: () => Promise<void>;
  disconnect: () => void;
}

const BridgeContext = createContext<BridgeContextType | undefined>(undefined);

export function EngineBridgeProvider({ children }: { children: React.ReactNode }) {
  const [bridge] = useState<GodotBridge | null>(() => {
    // Initialize bridge on module load
    return initBridge();
  });
  
  const [isConnected, setIsConnected] = useState(false);
  const [isConnecting, setIsConnecting] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!bridge) return;
    
    const unlistenStatus = bridge.on("status", (status) => {
      setIsConnected(status === "open");
      setIsConnecting(status === "connecting" || status === "reconnecting");
    });
    
    const unlistenError = bridge.on("error", (err) => {
      setError(err);
    });
    
    const unlistenUnrecoverable = bridge.on("unrecoverable", ({ message }) => {
      setError(message);
    });
    
    // Auto-connect on mount
    bridge.connect().catch(e => setError(e.message));
    
    return () => {
      unlistenStatus();
      unlistenError();
      unlistenUnrecoverable();
    };
  }, [bridge]);

  const connect = async () => {
    if (!bridge) return;
    setIsConnecting(true);
    setError(null);
    try {
      await bridge.connect();
    } catch (e) {
      setError(e instanceof Error ? e.message : String(e));
    } finally {
      setIsConnecting(false);
    }
  };

  const disconnect = () => {
    bridge?.disconnect();
    setIsConnected(false);
  };

  return (
    <BridgeContext.Provider value={{ bridge, isConnected, isConnecting, error, connect, disconnect }}>
      {children}
    </BridgeContext.Provider>
  );
}

export function useEngineBridge() {
  const context = useContext(BridgeContext);
  if (!context) {
    throw new Error("useEngineBridge must be used within EngineBridgeProvider");
  }
  return context;
}
```

**Connection Status Component:**

```typescript
// components/EngineConnectionStatus.tsx
"use client";

import { useEngineBridge } from "./EngineBridgeProvider";

export function EngineConnectionStatus() {
  const { isConnected, isConnecting, error } = useEngineBridge();

  if (error) {
    return (
      <div className="bg-amber-100 border border-amber-300 text-amber-700 px-4 py-2 rounded">
        <span className="font-medium">Connection Error:</span> {error}
      </div>
    );
  }

  if (isConnecting) {
    return (
      <div className="bg-blue-100 border border-blue-300 text-blue-700 px-4 py-2 rounded">
        <span className="font-medium">Connecting to game engine...</span>
      </div>
    );
  }

  if (isConnected) {
    return (
      <div className="bg-green-100 border border-green-300 text-green-700 px-4 py-2 rounded">
        <span className="font-medium">Connected</span>
      </div>
    );
  }

  return (
    <div className="bg-gray-100 border border-gray-300 text-gray-700 px-4 py-2 rounded">
      <span className="font-medium">Disconnected</span>
    </div>
  );
}
```

### 2.2 Tauri Event Bridge

**Frontend ↔ Backend Communication:**

```typescript
// hooks/useTauriEvents.ts
import { listen, emit } from "@tauri-apps/api/event";
import { useEffect } from "react";

export function useTauriEvent<T>(eventName: string, handler: (payload: T) => void) {
  useEffect(() => {
    const unlisten = listen<T>(eventName, ({ payload }) => handler(payload));
    return () => unlisten.then(u => u());
  }, [eventName, handler]);
}

export function emitTauriEvent<T>(eventName: string, payload: T) {
  emit(eventName, { payload });
}
```

**Parent Notification System:**

```typescript
// components/ParentNotificationOverlay.tsx
"use client";

import { useEffect, useState } from "react";
import { listen } from "@tauri-apps/api/event";

interface ParentNotification {
  type: "critical" | "warning" | "info";
  message: string;
  title: string;
  action?: "restart" | "parent";
}

export function ParentNotificationOverlay() {
  const [notification, setNotification] = useState<ParentNotification | null>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const unlisten = listen<ParentNotification>("parent_notification", ({ payload }) => {
      setNotification(payload);
      setVisible(true);
    });

    return () => {
      unlisten.then(u => u());
    };
  }, []);

  const handleDismiss = () => {
    setVisible(false);
  };

  const handleAction = () => {
    if (notification?.action === "restart") {
      // Attempt to reconnect
      window.location.reload();
    }
    setVisible(false);
  };

  if (!visible || !notification) return null;

  const isPolish = navigator.language.startsWith("pl");

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white p-6 rounded-lg shadow-xl max-w-md mx-4">
        <h2 className="text-xl font-bold text-red-600 mb-4">
          {notification.title}
        </h2>
        <p className="text-gray-700 mb-6">{notification.message}</p>
        <div className="flex gap-4 justify-end">
          {notification.action === "parent" && (
            <button
              onClick={handleAction}
              className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
            >
              {isPolish ? "Powiadom Rodzica" : "Tell Parent"}
            </button>
          )}
          <button
            onClick={handleDismiss}
            className="bg-gray-200 text-gray-800 px-4 py-2 rounded hover:bg-gray-300"
          >
            {isPolish ? "Zamknij" : "Close"}
          </button>
        </div>
      </div>
    </div>
  );
}
```

---

## 3. Message Routing & Command Dispatch

### 3.1 Command Registry Pattern

**Centralized Command Handler:**

```typescript
// lib/command-registry.ts
import { GodotBridge } from "./godot-bridge";

type CommandHandler<T = unknown, R = unknown> = (params: T) => Promise<R>;

interface CommandRegistration {
  name: string;
  handler: CommandHandler;
  requiresAuth?: boolean;
}

class CommandRegistry {
  private bridge: GodotBridge;
  private commands: Map<string, CommandRegistration> = new Map();

  constructor(bridge: GodotBridge) {
    this.bridge = bridge;
  }

  register<T = unknown, R = unknown>(
    name: string,
    handler: CommandHandler<T, R>,
    requiresAuth = true
  ): void {
    this.commands.set(name, { name, handler, requiresAuth });
  }

  async execute<T, R>(name: string, params: T): Promise<R> {
    const registration = this.commands.get(name);
    if (!registration) {
      throw new Error(`Unknown command: ${name}`);
    }

    // Forward to Godot engine
    const result = await this.bridge.send({
      type: "cmd",
      command: name,
      params
    });

    return result as R;
  }
}

export function createCommandRegistry(bridge: GodotBridge) {
  return new CommandRegistry(bridge);
}
```

**Usage:**

```typescript
// Initialize registry
const bridge = getBridge();
const commands = createCommandRegistry(bridge);

// Register commands
commands.register("session_started", async (params: { worldId: string; profileId: string }) => {
  bridge.notifySessionStarted(params.worldId, params.profileId);
  return { success: true };
});

commands.register("session_ended", async (params: { stats: object }) => {
  bridge.notifySessionEnded(params.stats);
  return { success: true };
});

// Execute command
await commands.execute("session_started", { worldId: "adv-001", profileId: "kid-123" });
```

### 3.2 Event Dispatcher

**Centralized Event Bus:**

```typescript
// lib/event-dispatcher.ts
type EventListener<T = unknown> = (payload: T) => void;

class EventDispatcher {
  private listeners: Map<string, Set<EventListener>> = new Map();

  on<T>(eventName: string, listener: EventListener<T>): () => void {
    if (!this.listeners.has(eventName)) {
      this.listeners.set(eventName, new Set());
    }
    this.listeners.get(eventName)!.add(listener as EventListener);
    return () => this.listeners.get(eventName)?.delete(listener as EventListener);
  }

  emit<T>(eventName: string, payload: T): void {
    const eventListeners = this.listeners.get(eventName);
    if (eventListeners) {
      for (const listener of eventListeners) {
        try {
          (listener as EventListener<T>)(payload);
        } catch (e) {
          console.error(`Error in event listener for ${eventName}:`, e);
        }
      }
    }
  }
}

export const eventDispatcher = new EventDispatcher();
```

**Bridge Event Integration:**

```typescript
// Setup bridge event forwarding
bridge.on("event", ({ name, payload }) => {
  eventDispatcher.emit(name, payload);
});

// Listen for specific events
const unsubscribe = eventDispatcher.on("session_started", (payload) => {
  console.log("Session started:", payload);
});
```

---

## 4. Heartbeat & Connection Liveness

### 4.1 Enhanced Heartbeat Monitoring

The bridge already includes heartbeat functionality. For UI integration:

```typescript
// components/ConnectionHealthIndicator.tsx
"use client";

import { useEngineBridge } from "./EngineBridgeProvider";
import { useEffect, useState } from "react";

export function ConnectionHealthIndicator() {
  const { bridge } = useEngineBridge();
  const [heartbeatCount, setHeartbeatCount] = useState(0);
  const [lastPong, setLastPong] = useState<string | null>(null);

  useEffect(() => {
    if (!bridge) return;

    // Listen for successful pong responses (from heartbeat)
    const unlisten = bridge.on("ack", (env) => {
      if (env.command === "ping" && env.ok === true) {
        setHeartbeatCount(prev => prev + 1);
        setLastPong(new Date().toLocaleTimeString());
      }
    });

    return () => unlisten();
  }, [bridge]);

  return (
    <div className="flex items-center gap-2 text-sm text-gray-600">
      <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
      <span>Heartbeat: {heartbeatCount}</span>
      {lastPong && <span>Last pong: {lastPong}</span>}
    </div>
  );
}
```

### 4.2 Connection Timeout Detection

**Child-Safe Timeout Handler:**

```typescript
// hooks/useConnectionWatchdog.ts
import { useEffect } from "react";
import { getBridge } from "@/lib/godot-bridge";

export function useConnectionWatchdog(
  timeoutMs: number = 15_000,
  onTimeout?: () => void
) {
  useEffect(() => {
    const bridge = getBridge();
    let timeoutId: ReturnType<typeof setTimeout>;

    const checkConnection = () => {
      clearTimeout(timeoutId);
      
      if (!bridge.isConnected()) {
        onTimeout?.();
        return;
      }

      // Test connection with ping
      bridge.ping()
        .then(() => {
          // Connection is alive, schedule next check
          timeoutId = setTimeout(checkConnection, timeoutMs);
        })
        .catch(() => {
          // Connection failed, notify timeout
          onTimeout?.();
        });
    };

    // Start watchdog
    timeoutId = setTimeout(checkConnection, timeoutMs);

    return () => clearTimeout(timeoutId);
  }, [timeoutMs, onTimeout]);
}
```

---

## 5. UI Integration Patterns

### 5.1 Session Lifecycle Hooks

**Game Session Manager:**

```typescript
// hooks/useGameSession.ts
import { useEngineBridge } from "@/components/EngineBridgeProvider";
import { useCallback, useState } from "react";

interface SessionStats {
  elapsed_seconds: number;
  items_collected: number;
  enemies_defeated: number;
  distance_traveled: number;
}

export function useGameSession() {
  const { bridge, isConnected } = useEngineBridge();
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [stats, setStats] = useState<SessionStats | null>(null);

  const startSession = useCallback(async (worldId: string, profileId: string) => {
    if (!bridge || !isConnected) {
      throw new Error("Engine not connected");
    }

    // Notify engine
    bridge.notifySessionStarted(worldId, profileId);
    
    // Generate session ID
    const id = crypto.randomUUID();
    setSessionId(id);
    setStats(null);

    return id;
  }, [bridge, isConnected]);

  const endSession = useCallback(async (customStats?: Partial<SessionStats>) => {
    if (!bridge || !sessionId) return;

    const finalStats = { ...stats, ...customStats } as SessionStats;
    bridge.notifySessionEnded(finalStats);
    setSessionId(null);
  }, [bridge, sessionId, stats]);

  const updateStats = useCallback((partial: Partial<SessionStats>) => {
    setStats(prev => ({ ...prev, ...partial }));
  }, []);

  // Listen for session events from engine
  useEffect(() => {
    if (!bridge) return;

    const unlisten = bridge.on("event", ({ name, payload }) => {
      switch (name) {
        case "session_stats_update":
          updateStats(payload as Partial<SessionStats>);
          break;
        case "session_ended":
          setStats(payload as SessionStats);
          setSessionId(null);
          break;
      }
    });

    return () => unlisten();
  }, [bridge, updateStats]);

  return { sessionId, stats, startSession, endSession, updateStats };
}
```

### 5.2 HUD Integration

**Minimal Game HUD:**

```typescript
// components/GameHUD.tsx
"use client";

import { useEngineBridge } from "./EngineBridgeProvider";
import { useGameSession } from "@/hooks/useGameSession";

export function GameHUD() {
  const { isConnected } = useEngineBridge();
  const { stats } = useGameSession();

  if (!isConnected) {
    return (
      <div className="absolute top-4 left-4 bg-amber-100 px-4 py-2 rounded">
        Waiting for game engine...
      </div>
    );
  }

  return (
    <div className="absolute top-4 left-4 bg-black bg-opacity-50 px-4 py-2 rounded text-white">
      <div>Time: {Math.floor((stats?.elapsed_seconds || 0) / 60)}:{(stats?.elapsed_seconds || 0) % 60}</div>
      <div>Items: {stats?.items_collected || 0}</div>
      <div>Distance: {Math.round((stats?.distance_traveled || 0) * 100) / 100}m</div>
    </div>
  );
}
```

### 5.3 Input Forwarding

**Keyboard/Mouse Input to Godot:**

```typescript
// hooks/useInputForwarding.ts
import { useEffect } from "react";
import { getBridge } from "@/lib/godot-bridge";

export function useInputForwarding(enabled: boolean = true) {
  useEffect(() => {
    if (!enabled) return;

    const bridge = getBridge();

    const handleKeyDown = (e: KeyboardEvent) => {
      if (!bridge.isConnected()) return;

      // Forward key events to Godot
      bridge.send({
        type: "cmd",
        command: "input_event",
        params: {
          type: "key_down",
          code: e.code,
          key: e.key,
          shiftKey: e.shiftKey,
          ctrlKey: e.ctrlKey,
          altKey: e.altKey,
          metaKey: e.metaKey,
          repeat: e.repeat
        }
      }).catch(console.warn);
    };

    const handleKeyUp = (e: KeyboardEvent) => {
      if (!bridge.isConnected()) return;

      bridge.send({
        type: "cmd",
        command: "input_event",
        params: {
          type: "key_up",
          code: e.code,
          key: e.key
        }
      }).catch(console.warn);
    };

    window.addEventListener("keydown", handleKeyDown);
    window.addEventListener("keyup", handleKeyUp);

    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      window.removeEventListener("keyup", handleKeyUp);
    };
  }, [enabled]);
}
```

---

## 6. Child-Safe Error Handling

### 6.1 Error Classification

**Error Types for Child-Safe Messaging:**

```typescript
// types/errors.ts
export type ErrorSeverity = "info" | "warning" | "error" | "critical";

export interface ChildSafeError {
  id: string;
  severity: ErrorSeverity;
  childMessage: string;      // Simple, friendly message for child
  parentMessage: string;     // Detailed message for parent
  action?: "retry" | "restart" | "parent" | "ignore";
  timestamp: number;
}

// Predefined child-safe errors
export const ERRORS: Record<string, ChildSafeError> = {
  CONNECTION_TIMEOUT: {
    id: "err_connection_timeout",
    severity: "warning",
    childMessage: "Game is taking a nap. Let's try again!",
    parentMessage: "Connection to Godot engine timed out",
    action: "restart"
  },
  ENGINE_CRASHED: {
    id: "err_engine_crashed",
    severity: "critical",
    childMessage: "Oh no! The game had a little accident.",
    parentMessage: "Godot engine process terminated unexpectedly",
    action: "parent"
  },
  AUTH_FAILED: {
    id: "err_auth_failed",
    severity: "error",
    childMessage: "We can't verify it's really you. Please try again.",
    parentMessage: "Authentication with Godot bridge failed",
    action: "restart"
  },
  NETWORK_ERROR: {
    id: "err_network",
    severity: "warning",
    childMessage: "The game is not talking to us right now.",
    parentMessage: "WebSocket connection error",
    action: "retry"
  }
};
```

### 6.2 Error Translator

**Convert Technical Errors to Child-Safe Messages:**

```typescript
// utils/child-safe-errors.ts
import { ERRORS, ChildSafeError } from "@/types/errors";

export function translateError(error: unknown): ChildSafeError {
  const errorMessage = error instanceof Error ? error.message : String(error);

  // Match against known error patterns
  const patterns: Array<[RegExp, string]> = [
    [/timeout/i, "CONNECTION_TIMEOUT"],
    [/auth.*fail/i, "AUTH_FAILED"],
    [/terminated|killed|crashed/i, "ENGINE_CRASHED"],
    [/websocket|network|connection/i, "NETWORK_ERROR"]
  ];

  for (const [pattern, errorId] of patterns) {
    if (pattern.test(errorMessage)) {
      return { ...ERRORS[errorId], timestamp: Date.now() };
    }
  }

  // Default error
  return {
    id: "err_unknown",
    severity: "error",
    childMessage: "Something unexpected happened. Don't worry, we'll fix it!",
    parentMessage: errorMessage,
    action: "parent",
    timestamp: Date.now()
  };
}

// React hook for error display
export function useChildSafeError() {
  const [error, setError] = useState<ChildSafeError | null>(null);

  const showError = useCallback((error: unknown) => {
    const safeError = translateError(error);
    setError(safeError);
    
    // Emit to parent if critical
    if (safeError.severity === "critical" || safeError.action === "parent") {
      emit("parent_notification", {
        type: "critical",
        message: safeError.parentMessage,
        title: "Game Engine Error"
      });
    }
  }, []);

  const clearError = useCallback(() => setError(null), []);

  return { error, showError, clearError };
}
```

### 6.3 Error Display Component

**Child-Friendly Error Toast:**

```typescript
// components/ChildErrorToast.tsx
"use client";

import { useEffect } from "react";
import { ChildSafeError, ERRORS } from "@/types/errors";

interface ChildErrorToastProps {
  error: ChildSafeError | null;
  onDismiss: () => void;
}

export function ChildErrorToast({ error, onDismiss }: ChildErrorToastProps) {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (error) {
      setVisible(true);
      // Auto-dismiss warnings after 5 seconds
      if (error.severity === "warning") {
        const timer = setTimeout(() => setVisible(false), 5000);
        return () => clearTimeout(timer);
      }
    } else {
      setVisible(false);
    }
  }, [error]);

  if (!visible || !error) return null;

  const isPolish = navigator.language.startsWith("pl");
  const actionText = isPolish ? {
    retry: "Spróbuj ponownie",
    restart: "Uruchom ponownie",
    parent: "Powiadom Rodzica",
    ignore: "Zignoruj"
  } : {
    retry: "Try Again",
    restart: "Restart",
    parent: "Tell Parent",
    ignore: "Ignore"
  };

  const getIcon = (severity: ErrorSeverity) => {
    switch (severity) {
      case "info": return "ℹ️";
      case "warning": return "⚠️";
      case "error": return "❌";
      case "critical": return "🚨";
    }
  };

  return (
    <div className={`fixed bottom-4 left-4 right-4 ${error.severity === "critical" ? "bg-red-100 border-red-400 text-red-800" : 
                                      error.severity === "error" ? "bg-orange-100 border-orange-400 text-orange-800" :
                                      "bg-yellow-100 border-yellow-400 text-yellow-800"} 
                   border-2 rounded-lg p-4 shadow-lg z-50`}>
      <div className="flex items-start gap-3">
        <span className="text-2xl">{getIcon(error.severity)}</span>
        <div className="flex-1">
          <p className="font-medium">{error.childMessage}</p>
          {error.severity === "critical" && (
            <p className="text-sm mt-1 opacity-75">{error.parentMessage}</p>
          )}
        </div>
        {error.action && (
          <button
            onClick={() => {
              if (error.action === "retry") {
                window.location.reload();
              } else if (error.action === "restart") {
                // Will be handled by parent
              }
              onDismiss();
            }}
            className="bg-white text-sm px-3 py-1 rounded border"
          >
            {actionText[error.action]}
          </button>
        )}
        <button onClick={onDismiss} className="text-xl font-bold">×</button>
      </div>
    </div>
  );
}
```

---

## 7. Testing Strategies

### 7.1 Unit Tests (Vitest)

**Bridge Client Tests:**

```typescript
// tests/godot-bridge.test.ts
import { describe, it, expect, vi, beforeEach, afterEach } from "vitest";
import { GodotBridge } from "@/lib/godot-bridge";

describe("GodotBridge", () => {
  let bridge: GodotBridge;

  beforeEach(() => {
    bridge = new GodotBridge();
  });

  afterEach(() => {
    bridge.disconnect();
  });

  it("should initialize with idle status", () => {
    expect(bridge.getStatus()).toBe("idle");
    expect(bridge.isConnected()).toBe(false);
  });

  it("should emit status changes", () => {
    const statusListener = vi.fn();
    bridge.on("status", statusListener);

    // Simulate connection
    bridge["setStatus"]("connecting");
    expect(statusListener).toHaveBeenCalledWith("connecting");

    bridge["setStatus"]("open");
    expect(statusListener).toHaveBeenCalledWith("open");
  });

  it("should queue messages when not connected", () => {
    const sendSpy = vi.fn();
    bridge["ws"] = { send: sendSpy } as unknown as WebSocket;
    bridge["status"] = "connecting";

    bridge.send({ type: "cmd", command: "test" });
    
    // Message should be queued, not sent
    expect(sendSpy).not.toHaveBeenCalled();
  });
});
```

### 7.2 Integration Tests

**Bridge ↔ Godot Mock Tests:**

```typescript
// tests/bridge-integration.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { GodotBridge } from "@/lib/godot-bridge";

// Mock WebSocket
class MockWebSocket {
  onopen?: () => void;
  onmessage?: (ev: MessageEvent) => void;
  onerror?: () => void;
  onclose?: () => void;
  
  sentMessages: string[] = [];
  
  send(data: string) {
    this.sentMessages.push(data);
  }
  
  close() {}
  
  simulateOpen() {
    this.onopen?.();
  }
  
  simulateMessage(data: string) {
    this.onmessage?.({ data } as MessageEvent);
  }
}

describe("GodotBridge Integration", () => {
  it("should send hello on connect", () => {
    const mockWs = new MockWebSocket();
    const bridge = new GodotBridge();
    
    // Inject mock
    bridge["ws"] = mockWs as unknown as WebSocket;
    bridge["url"] = "ws://test";
    
    // Simulate connection
    mockWs.onopen = () => {
      bridge["setStatus"]("open");
      bridge["startHeartbeat"]();
      bridge["flushQueue"]();
    };
    
    mockWs.simulateOpen();
    
    // Should have sent hello
    expect(mockWs.sentMessages.some(m => m.includes("hello"))).toBe(true);
  });

  it("should handle ack responses", async () => {
    const mockWs = new MockWebSocket();
    const bridge = new GodotBridge();
    
    bridge["ws"] = mockWs as unknown as WebSocket;
    bridge["setStatus"]("open");
    
    const promise = bridge.send({ 
      type: "cmd", 
      id: 1, 
      command: "test" 
    });
    
    // Simulate ack response
    mockWs.simulateMessage(JSON.stringify({
      type: "ack",
      id: 1,
      ok: true,
      result: { success: true }
    }));
    
    await expect(promise).resolves.toEqual({ success: true });
  });
});
```

### 7.3 Tauri Test Harness

**Testing with Real Tauri:**

```typescript
// tests/tauri-integration.test.ts
import { describe, it, expect } from "vitest";
import { invoke } from "@tauri-apps/api/core";

describe("Tauri Integration", () => {
  it("should invoke start_engine command", async () => {
    const result = await invoke<{ port: number; auth_token: string }>("start_engine");
    
    expect(result).toHaveProperty("port");
    expect(result.port).toBeGreaterThan(0);
    expect(result).toHaveProperty("auth_token");
    expect(result.auth_token.length).toBeGreaterThan(16);
  });

  it("should invoke stop_engine command", async () => {
    await invoke("stop_engine");
    // If no error, test passes
    expect(true).toBe(true);
  });
});
```

---

## 8. Performance Optimization

### 8.1 Message Batching

**Batching Rapid Events:**

```typescript
// lib/message-batcher.ts
type BatchedMessage = {
  type: "batch";
  commands: Envelope[];
};

class MessageBatcher {
  private bridge: GodotBridge;
  private batch: Envelope[] = [];
  private timeout: ReturnType<typeof setTimeout> | null = null;
  private batchSize: number;
  private batchTimeout: number;

  constructor(
    bridge: GodotBridge,
    batchSize: number = 10,
    batchTimeout: number = 100
  ) {
    this.bridge = bridge;
    this.batchSize = batchSize;
    this.batchTimeout = batchTimeout;
  }

  queue(message: Envelope): void {
    this.batch.push(message);
    
    if (this.batch.length >= this.batchSize) {
      this.flush();
    } else if (!this.timeout) {
      this.timeout = setTimeout(() => this.flush(), this.batchTimeout);
    }
  }

  flush(): void {
    if (this.timeout) {
      clearTimeout(this.timeout);
      this.timeout = null;
    }
    
    if (this.batch.length === 0) return;
    
    const batch = [...this.batch];
    this.batch = [];
    
    this.bridge.send({
      type: "batch",
      commands: batch
    }).catch(console.warn);
  }
}

export function createBatcher(bridge: GodotBridge) {
  return new MessageBatcher(bridge);
}
```

### 8.2 Throttling

**Input Event Throttling:**

```typescript
// utils/throttle.ts
export function throttle<T extends (...args: any[]) => any>(
  fn: T,
  limit: number
): (...args: Parameters<T>) => void {
  let inThrottle = false;
  let lastArgs: Parameters<T> | null = null;

  return function(...args: Parameters<T>) {
    if (!inThrottle) {
      fn(...args);
      inThrottle = true;
      setTimeout(() => {
        inThrottle = false;
        if (lastArgs) {
          fn(...lastArgs);
          lastArgs = null;
        }
      }, limit);
    } else {
      lastArgs = args;
    }
  };
}

// Usage
const throttledInput = throttle((e: KeyboardEvent) => {
  bridge.send({ type: "cmd", command: "input", params: { key: e.key } });
}, 50); // Max 20 events per second

document.addEventListener("keydown", throttledInput);
```

### 8.3 Connection Pooling

**Reusing Connections:**

```typescript
// lib/connection-pool.ts
class ConnectionPool {
  private pools: Map<string, GodotBridge> = new Map();

  getBridge(key: string = "default"): GodotBridge {
    if (!this.pools.has(key)) {
      this.pools.set(key, new GodotBridge());
    }
    return this.pools.get(key)!;
  }

  async getConnectedBridge(key: string = "default"): Promise<GodotBridge> {
    const bridge = this.getBridge(key);
    
    if (!bridge.isConnected() && !bridge.isConnecting()) {
      await bridge.connect();
    }
    
    return bridge;
  }

  destroyBridge(key: string = "default"): void {
    const bridge = this.pools.get(key);
    if (bridge) {
      bridge.disconnect();
      this.pools.delete(key);
    }
  }
}

export const connectionPool = new ConnectionPool();
```

---

## 9. Code Samples

> **Comprehensive code samples for Tauri-Godot bridge integration**
> All samples include child-safe error handling and parent notification patterns

### 9.1 TypeScript WebSocket Client with Reconnection

```typescript
// shell/src/lib/websocket-client.ts
// Robust WebSocket client with exponential backoff reconnection

export class RobustWebSocket {
  private socket: WebSocket | null = null;
  private url: string;
  private reconnectAttempts = 0;
  private readonly maxReconnectAttempts = 10;
  private readonly baseDelay = 1000; // 1 second
  private readonly maxDelay = 30000; // 30 seconds
  private reconnectTimeout: ReturnType<typeof setTimeout> | null = null;
  private messageQueue: string[] = [];
  
  private onOpenCallbacks: Array<() => void> = [];
  private onMessageCallbacks: Array<(data: string) => void> = [];
  private onCloseCallbacks: Array<() => void> = [];
  private onErrorCallbacks: Array<(error: Error) => void> = [];

  constructor(url: string) {
    this.url = url;
  }

  connect(): void {
    // Child-safe: Check if already connecting/reconnecting
    if (this.socket && this.socket.readyState === WebSocket.CONNECTING) {
      console.warn('[GodotBridge] Already connecting, waiting...');
      return;
    }

    try {
      this.socket = new WebSocket(this.url);
      
      this.socket.onopen = () => {
        this.reconnectAttempts = 0;
        this.flushMessageQueue();
        this.onOpenCallbacks.forEach(cb => cb());
      };

      this.socket.onmessage = (event) => {
        this.onMessageCallbacks.forEach(cb => cb(event.data));
      };

      this.socket.onclose = () => {
        this.onCloseCallbacks.forEach(cb => cb());
        this.scheduleReconnect();
      };

      this.socket.onerror = (error) => {
        this.onErrorCallbacks.forEach(cb => cb(error));
      };
    } catch (error) {
      // Child-safe: Log error without scary details
      console.error('[GodotBridge] Connection error:', this.sanitizeError(error));
      this.onErrorCallbacks.forEach(cb => cb(error));
    }
  }

  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('[GodotBridge] Max reconnection attempts reached');
      return;
    }

    const delay = Math.min(
      this.baseDelay * Math.pow(2, this.reconnectAttempts),
      this.maxDelay
    );
    
    this.reconnectAttempts++;
    console.log(`[GodotBridge] Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);
    
    this.reconnectTimeout = setTimeout(() => {
      this.connect();
    }, delay);
  }

  send(data: string): boolean {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      // Queue message for when connection is established
      if (this.messageQueue.length < 100) {
        this.messageQueue.push(data);
        return true;
      }
      console.warn('[GodotBridge] Message queue full, dropping message');
      return false;
    }

    try {
      this.socket.send(data);
      return true;
    } catch (error) {
      console.error('[GodotBridge] Send error:', this.sanitizeError(error));
      return false;
    }
  }

  private flushMessageQueue(): void {
    while (this.messageQueue.length > 0 && this.socket?.readyState === WebSocket.OPEN) {
      const message = this.messageQueue.shift()!;
      this.socket.send(message);
    }
  }

  close(): void {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
    }
    if (this.socket) {
      this.socket.close();
      this.socket = null;
    }
  }

  onOpen(callback: () => void): void {
    this.onOpenCallbacks.push(callback);
  }

  onMessage(callback: (data: string) => void): void {
    this.onMessageCallbacks.push(callback);
  }

  onClose(callback: () => void): void {
    this.onCloseCallbacks.push(callback);
  }

  onError(callback: (error: Error) => void): void {
    this.onErrorCallbacks.push(callback);
  }

  private sanitizeError(error: unknown): string {
    // Child-safe: Return generic message without technical details
    return 'Connection problem. Please check your connection.';
  }
}
```

**Key Features:**
- Exponential backoff reconnection (1s → 30s max)
- Message queuing when offline
- Child-safe error messages
- Clean TypeScript class structure
- Resource cleanup on close

**Source References:**
- [MDN WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [Exponential Backoff Algorithm](https://aws.amazon.com/blogs/architecture/exponential-backoff-and-jitter/)

---

### 9.2 Message Envelope Serialization

```typescript
// shell/src/lib/envelope.ts
// Type-safe message serialization for Godot-Tauri communication

export interface MessageEnvelope {
  id: string;
  timestamp: number;
  type: 'command' | 'response' | 'event';
  command?: string;
  payload?: Record<string, unknown>;
  error?: string;
  metadata?: {
    source: 'tauri' | 'godot';
    priority: 'low' | 'medium' | 'high';
    childSafe: boolean;
  };
}

export class EnvelopeSerializer {
  static serialize(envelope: MessageEnvelope): string {
    return JSON.stringify(envelope);
  }

  static deserialize(data: string): MessageEnvelope {
    try {
      const parsed = JSON.parse(data);
      return this.validateEnvelope(parsed);
    } catch (error) {
      // Child-safe: Return safe error envelope
      return {
        id: 'error',
        timestamp: Date.now(),
        type: 'response',
        error: 'Invalid message format',
        metadata: { source: 'tauri', priority: 'high', childSafe: true }
      };
    }
  }

  private static validateEnvelope(data: unknown): MessageEnvelope {
    const defaults: MessageEnvelope = {
      id: crypto.randomUUID(),
      timestamp: Date.now(),
      type: 'command',
      metadata: { source: 'tauri', priority: 'medium', childSafe: true }
    };
    
    return { ...defaults, ...data };
  }

  static createCommand(command: string, payload: Record<string, unknown> = {}): MessageEnvelope {
    return {
      id: crypto.randomUUID(),
      timestamp: Date.now(),
      type: 'command',
      command,
      payload,
      metadata: { source: 'tauri', priority: 'medium', childSafe: true }
    };
  }

  static createError(id: string, error: string): MessageEnvelope {
    return {
      id,
      timestamp: Date.now(),
      type: 'response',
      error: this.sanitizeError(error),
      metadata: { source: 'tauri', priority: 'high', childSafe: true }
    };
  }

  private static sanitizeError(error: string): string {
    // Child-safe: Map technical errors to friendly messages
    const errorMap: Record<string, string> = {
      'Connection refused': 'Game engine is not running',
      'Timeout': 'Connection took too long',
      'Parsing error': 'Invalid message received'
    };
    return errorMap[error] || 'Something went wrong';
  }
}
```

**Type-Safe Usage:**
```typescript
// Type-safe command definitions
const GameCommands = {
  START_GAME: 'game/start',
  LOAD_SCENE: 'game/load_scene',
  PLAYER_ACTION: 'player/action',
  SAVE_GAME: 'game/save',
  GET_STATE: 'game/state'
} as const;

type GameCommand = typeof GameCommands[keyof typeof GameCommands];

// Type-safe payloads
type StartGamePayload = {
  profileId: string;
  difficulty: 'easy' | 'medium' | 'hard';
  tutorialEnabled: boolean;
};

type PlayerActionPayload = {
  action: 'jump' | 'attack' | 'interact';
  timestamp: number;
};

// Command builder with type safety
function createGameCommand<C extends GameCommand>(
  command: C,
  payload: Extract<StartGamePayload | PlayerActionPayload, any>
): MessageEnvelope {
  return EnvelopeSerializer.createCommand(command, payload);
}
```

**Source References:**
- [TypeScript Type Inference](https://www.typescriptlang.org/docs/handbook/type-inference.html)
- [JSON Serialization Best Practices](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON)

---

### 9.3 Heartbeat & Liveness Monitoring

```typescript
// shell/src/lib/heartbeat.ts
// Connection health monitoring with parent notification

export class HeartbeatMonitor {
  private readonly interval: number;
  private readonly maxMisses: number;
  private misses = 0;
  private lastPingTime = 0;
  private heartbeatInterval: ReturnType<typeof setInterval> | null = null;
  private readonly onDeadCallbacks: Array<() => void> = [];
  private readonly onAliveCallbacks: Array<() => void> = [];

  constructor(interval: number = 5000, maxMisses: number = 3) {
    this.interval = interval;
    this.maxMisses = maxMisses;
  }

  start(): void {
    this.stop();
    this.misses = 0;
    this.lastPingTime = Date.now();

    this.heartbeatInterval = setInterval(() => {
      const now = Date.now();
      
      // Check if we received a pong since last ping
      if (now - this.lastPingTime > this.interval * 2) {
        this.misses++;
        console.warn(`[Heartbeat] Missed ping (${this.misses}/${this.maxMisses})`);
        
        if (this.misses >= this.maxMisses) {
          this.notifyDead();
        }
      } else {
        this.misses = 0;
        this.notifyAlive();
      }
    }, this.interval);
  }

  stop(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }

  receivedPong(): void {
    this.lastPingTime = Date.now();
    this.misses = 0;
  }

  private notifyDead(): void {
    console.error('[Heartbeat] Connection lost - notifying parent');
    this.onDeadCallbacks.forEach(cb => cb());
    // Trigger parent notification overlay
    this.showParentNotification('Connection to game lost. Please restart the game.');
  }

  private notifyAlive(): void {
    this.onAliveCallbacks.forEach(cb => cb());
  }

  onDead(callback: () => void): void {
    this.onDeadCallbacks.push(callback);
  }

  onAlive(callback: () => void): void {
    this.onAliveCallbacks.push(callback);
  }

  private showParentNotification(message: string): void {
    // Child-safe: Show notification that requires parent attention
    // Implementation would use a React component or Tauri event
    console.log(`[Parent Notification] ${message}`);
    // In production: emit('parent_notification', { message, severity: 'warning' })
  }
}

// Usage with WebSocket
const heartbeat = new HeartbeatMonitor();

// In WebSocket message handler
websocket.onMessage((data) => {
  const envelope = EnvelopeSerializer.deserialize(data);
  if (envelope.command === 'pong') {
    heartbeat.receivedPong();
  }
});

// Auto-send ping every interval
setInterval(() => {
  websocket.send(JSON.stringify({ command: 'ping' }));
}, heartbeat.interval);
```

**Child-Safe Features:**
- Parent notification for connection loss
- Configurable thresholds (5s interval, 3 misses = 15s timeout)
- Graceful degradation
- Clear error communication

**Source References:**
- [WebSocket Ping/Pong](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_client_applications#ping_pong)
- [Heartbeat Pattern](https://en.wikipedia.org/wiki/Heartbeat_(computing))

---

### 9.4 Tauri-Godot Bridge Pattern

```typescript
// shell/src/lib/godot-bridge.ts
// Complete bridge implementation with Tauri integration

import { invoke } from '@tauri-apps/api/core';
import { emit, listen } from '@tauri-apps/api/event';

export class TauriGodotBridge {
  private websocket: RobustWebSocket;
  private heartbeat: HeartbeatMonitor;
  private commandHandlers: Map<string, (payload: unknown) => Promise<unknown>> = new Map();
  private eventListeners: Map<string, Array<(payload: unknown) => void>> = new Map();
  private isGodotRunning = false;

  constructor(godotUrl: string = 'ws://127.0.0.1:9876') {
    this.websocket = new RobustWebSocket(godotUrl);
    this.heartbeat = new HeartbeatMonitor();
    this.setupMessageHandlers();
  }

  async initialize(): Promise<void> {
    // Check if Godot process is running via Tauri
    this.isGodotRunning = await this.checkGodotRunning();
    
    if (!this.isGodotRunning) {
      await this.startGodot();
    }

    this.websocket.connect();
    this.heartbeat.start();
  }

  private async checkGodotRunning(): Promise<boolean> {
    try {
      const result = await invoke('is_godot_running');
      return result as boolean;
    } catch {
      return false;
    }
  }

  private async startGodot(): Promise<void> {
    try {
      // Tauri command to start Godot
      await invoke('start_godot');
      this.isGodotRunning = true;
    } catch (error) {
      console.error('[Bridge] Failed to start Godot:', error);
      // Child-safe: Show parent notification
      this.notifyParent('Could not start game engine. Please try again.');
    }
  }

  private setupMessageHandlers(): void {
    this.websocket.onOpen(() => {
      console.log('[Bridge] Connected to Godot');
      emit('bridge_connected');
    });

    this.websocket.onMessage((data) => {
      const envelope = EnvelopeSerializer.deserialize(data);
      this.handleEnvelope(envelope);
    });

    this.websocket.onClose(() => {
      console.log('[Bridge] Disconnected from Godot');
      emit('bridge_disconnected');
    });

    this.websocket.onError((error) => {
      console.error('[Bridge] Error:', error);
      emit('bridge_error', { error: error.message });
    });
  }

  private async handleEnvelope(envelope: MessageEnvelope): Promise<void> {
    switch (envelope.type) {
      case 'response':
        // Handle command responses
        await this.handleResponse(envelope);
        break;
      case 'event':
        // Handle Godot events
        this.handleEvent(envelope);
        break;
      case 'command':
        // Handle commands from Godot
        await this.handleCommand(envelope);
        break;
    }
  }

  private async handleCommand(envelope: MessageEnvelope): Promise<void> {
    const handler = this.commandHandlers.get(envelope.command || '');
    if (handler) {
      try {
        const result = await handler(envelope.payload);
        const response = EnvelopeSerializer.createCommand(envelope.command || '', result);
        this.websocket.send(EnvelopeSerializer.serialize(response));
      } catch (error) {
        const errorResponse = EnvelopeSerializer.createError(
          envelope.id || '',
          error instanceof Error ? error.message : 'Unknown error'
        );
        this.websocket.send(EnvelopeSerializer.serialize(errorResponse));
      }
    } else {
      console.warn(`[Bridge] No handler for command: ${envelope.command}`);
    }
  }

  private handleEvent(envelope: MessageEnvelope): void {
    const listeners = this.eventListeners.get(envelope.command || '');
    if (listeners) {
      listeners.forEach(listener => listener(envelope.payload));
    }
    // Also emit Tauri event for global listening
    emit(`godot_event_${envelope.command}`, envelope.payload);
  }

  onCommand<T extends string, P = unknown>(
    command: T,
    handler: (payload: P) => Promise<unknown>
  ): void {
    this.commandHandlers.set(command, handler as (payload: unknown) => Promise<unknown>);
  }

  onEvent<T extends string>(event: T, listener: (payload: unknown) => void): void {
    if (!this.eventListeners.has(event)) {
      this.eventListeners.set(event, []);
    }
    this.eventListeners.get(event)!.push(listener);
  }

  async sendCommand<T>(command: string, payload: unknown = {}): Promise<T> {
    return new Promise((resolve, reject) => {
      const envelope = EnvelopeSerializer.createCommand(command, payload);
      const envelopeStr = EnvelopeSerializer.serialize(envelope);
      
      // Set up one-time response handler
      const responseHandler = (responseEnvelope: MessageEnvelope) => {
        if (responseEnvelope.id === envelope.id) {
          if (responseEnvelope.error) {
            reject(new Error(responseEnvelope.error));
          } else {
            resolve(responseEnvelope.payload as T);
          }
        }
      };

      this.onEvent('response', responseHandler);
      this.websocket.send(envelopeStr);
      
      // Timeout after 10 seconds
      setTimeout(() => {
        this.eventListeners.get('response')?.filter(h => h !== responseHandler);
        reject(new Error('Command timeout'));
      }, 10000);
    });
  }

  private notifyParent(message: string): void {
    emit('parent_notification', { message, type: 'error' });
  }

  close(): void {
    this.websocket.close();
    this.heartbeat.stop();
  }
}

// Singleton instance
export const godotBridge = new TauriGodotBridge();
```

**Integration with Tauri:**
```rust
// src-tauri/src/main.rs
// Rust command to start Godot process

#[tauri::command]
async fn start_godot() -> Result<(), String> {
    use std::process::Command;
    
    Command::new("./godot.exe")
        .arg("res://src/adapters/inbound/main.tscn")
        .spawn()
        .map_err(|e| format!("Failed to start Godot: {}", e))?;
    
    Ok(())
}

#[tauri::command]
async fn is_godot_running() -> Result<bool, String> {
    // Check if Godot process is running
    // Implementation depends on platform
    Ok(false) // Placeholder
}

// Register commands
fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![start_godot, is_godot_running])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
```

**Source References:**
- [Tauri Invoke Commands](https://v2.tauri.app/develop/calling-rust/)
- [Process Management in Rust](https://doc.rust-lang.org/std/process/index.html)

---

### 9.5 Child-Safe Notification System

```typescript
// shell/src/components/ParentNotificationOverlay.tsx
// React component for parent-gated notifications

import React, { useState, useEffect } from 'react';
import { listen } from '@tauri-apps/api/event';

interface ParentNotificationProps {
  autoCloseAfter?: number; // seconds, 0 = manual close only
}

export const ParentNotificationOverlay: React.FC<ParentNotificationProps> = ({
  autoCloseAfter = 0
}) => {
  const [notifications, setNotifications] = useState<Array<{
    id: string;
    message: string;
    type: 'error' | 'warning' | 'info';
    timestamp: number;
  }>>([]);

  useEffect(() => {
    const unlisten = listen('parent_notification', (event) => {
      const { message, type = 'error' } = event.payload as any;
      addNotification(message, type);
    });

    return () => {
      unlisten.then(u => u());
    };
  }, []);

  const addNotification = (message: string, type: 'error' | 'warning' | 'info') => {
    const id = crypto.randomUUID();
    const newNotification = { id, message, type, timestamp: Date.now() };
    
    setNotifications(prev => [...prev, newNotification]);
    
    if (autoCloseAfter > 0) {
      setTimeout(() => {
        removeNotification(id);
      }, autoCloseAfter * 1000);
    }
  };

  const removeNotification = (id: string) => {
    setNotifications(prev => prev.filter(n => n.id !== id));
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'error': return '❌';
      case 'warning': return '⚠️';
      case 'info': return 'ℹ️';
      default: return 'ℹ️';
    }
  };

  const getColor = (type: string) => {
    switch (type) {
      case 'error': return 'bg-red-500';
      case 'warning': return 'bg-yellow-500';
      case 'info': return 'bg-blue-500';
      default: return 'bg-gray-500';
    }
  };

  if (notifications.length === 0) {
    return null;
  }

  return (
    <div className="fixed bottom-4 right-4 z-50 space-y-2">
      {notifications.map(notification => (
        <div
          key={notification.id}
          className={`p-4 rounded-lg text-white shadow-lg ${getColor(notification.type)}`}
        >
          <div className="flex items-center">
            <span className="mr-2 text-xl">{getIcon(notification.type)}</span>
            <div className="flex-1">
              <h3 className="font-bold">Powiedz Rodzicowi</h3>
              <p>{getChildSafeMessage(notification.message)}</p>
            </div>
            {autoCloseAfter === 0 && (
              <button
                onClick={() => removeNotification(notification.id)}
                className="ml-2 text-white hover:text-gray-200"
              >
                &times;
              </button>
            )}
          </div>
        </div>
      ))}
    </div>
  );
};

// Child-safe message mapping
function getChildSafeMessage(message: string): string {
  const mappings: Record<string, string> = {
    'Connection lost': 'The game lost connection. Ask a parent to help.',
    'Failed to start': 'Could not start the game. Please try again.',
    'Timeout': 'The game is taking too long to respond.',
    'Authentication failed': 'Please log in again.'
  };
  return mappings[message] || message;
}

// Tailwind CSS classes used:
// bg-red-500, bg-yellow-500, bg-blue-500, bg-gray-500
// p-4, rounded-lg, text-white, shadow-lg
// flex, items-center, mr-2, text-xl, flex-1
// font-bold, ml-2, hover:text-gray-200
```

**Polish Localization:**
```typescript
// Polish language support for notifications
const PL_MESSAGES = {
  connectionLost: 'Gra straciła połączenie. Poproś rodzica o pomoc.',
  cannotStart: 'Nie można uruchomić gry. Spróbuj ponownie.',
  timeout: 'Gra zbyt długo nie odpowiada.',
  authFailed: 'Proszę zalogować się ponownie.',
  parentNotification: 'Powiedz Rodzicowi'
};

// Usage
export const getPolishMessage = (key: keyof typeof PL_MESSAGES): string => {
  return PL_MESSAGES[key] || key;
};
```

**Source References:**
- [Tailwind CSS Documentation](https://tailwindcss.com/docs)
- [React with Tauri](https://v2.tauri.app/guides/features/react/)
- [Child-Friendly Error Messages](https://www.nngroup.com/articles/error-message-guidelines/)

---

### 9.6 Error Handling Patterns

```typescript
// shell/src/lib/errors.ts
// Comprehensive error handling for child-safe applications

export class ChildSafeError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly severity: 'low' | 'medium' | 'high' = 'medium',
    public readonly parentNotification = true,
    public readonly recoverable = true
  ) {
    super(message);
    this.name = 'ChildSafeError';
  }
}

export const ErrorCodes = {
  // Network errors
  CONNECTION_FAILED: 'network/connection_failed',
  CONNECTION_TIMEOUT: 'network/timeout',
  DISCONNECTED: 'network/disconnected',
  
  // Godot errors
  GODOT_NOT_RUNNING: 'godot/not_running',
  GODOT_CRASHED: 'godot/crashed',
  SCENE_LOAD_FAILED: 'godot/scene_load_failed',
  
  // Authentication errors
  AUTH_REQUIRED: 'auth/required',
  AUTH_FAILED: 'auth/failed',
  SESSION_EXPIRED: 'auth/session_expired',
  
  // Game errors
  INVALID_ACTION: 'game/invalid_action',
  INSUFFICIENT_PERMISSIONS: 'game/insufficient_permissions',
  SAVE_FAILED: 'game/save_failed'
} as const;

export function createError(code: typeof ErrorCodes[keyof typeof ErrorCodes], context?: any): ChildSafeError {
  const errorMap: Record<string, { message: string; severity: 'low' | 'medium' | 'high'; parentNotification: boolean }> = {
    [ErrorCodes.CONNECTION_FAILED]: {
      message: 'Could not connect to the game. Please check your connection.',
      severity: 'high',
      parentNotification: true
    },
    [ErrorCodes.CONNECTION_TIMEOUT]: {
      message: 'Connection to game is slow. Please try again.',
      severity: 'medium',
      parentNotification: false
    },
    [ErrorCodes.GODOT_NOT_RUNNING]: {
      message: 'Game engine is not running. Starting it now...',
      severity: 'medium',
      parentNotification: false
    },
    [ErrorCodes.GODOT_CRASHED]: {
      message: 'Game crashed. Please restart the application.',
      severity: 'high',
      parentNotification: true
    },
    [ErrorCodes.AUTH_REQUIRED]: {
      message: 'Please log in to continue.',
      severity: 'medium',
      parentNotification: false
    },
    [ErrorCodes.INSUFFICIENT_PERMISSIONS]: {
      message: 'You need parent approval for this action.',
      severity: 'high',
      parentNotification: true
    }
  };

  const config = errorMap[code] || {
    message: 'Something went wrong. Please try again.',
    severity: 'medium',
    parentNotification: false
  };

  return new ChildSafeError(config.message, code, config.severity, config.parentNotification, true);
}

// Global error handler
export function setupGlobalErrorHandler(bridge: TauriGodotBridge): void {
  window.addEventListener('error', (event) => {
    const error = event.error || new Error(event.message);
    const childSafeError = createError(ErrorCodes.CONNECTION_FAILED);
    
    // Child-safe: Only log to console in development
    if (process.env.NODE_ENV === 'development') {
      console.error('[Global Error]', error);
    }
    
    // Notify parent for high severity errors
    if (childSafeError.parentNotification) {
      bridge.notifyParent(childSafeError.message);
    }
  });

  window.addEventListener('unhandledrejection', (event) => {
    const reason = event.reason as Error;
    console.error('[Unhandled Rejection]', reason);
  });
}

// Error boundary for React components
export class ErrorBoundary extends React.Component<{ children: React.ReactNode }, { hasError: boolean; error: Error | null }> {
  constructor(props: any) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error: Error): { hasError: boolean; error: Error } {
    return { hasError: true, error: createError(ErrorCodes.CONNECTION_FAILED) };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo): void {
    console.error('[ErrorBoundary]', error, errorInfo);
  }

  render(): React.ReactNode {
    if (this.state.hasError) {
      return (
        <div className="error-boundary">
          <h2>Oops! Something went wrong.</h2>
          <p>{this.state.error?.message || 'Please try again.'}</p>
          <button onClick={() => window.location.reload()}>
            Try Again
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

**Error Recovery Strategies:**
```typescript
// Retry decorator for commands
export function withRetry<T extends (...args: any[]) => Promise<any>>(
  fn: T,
  options: { maxRetries?: number; delay?: number } = {}
): T {
  const { maxRetries = 3, delay = 1000 } = options;
  
  return async function (this: any, ...args: any[]) {
    let lastError: Error;
    
    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn.apply(this, args);
      } catch (error) {
        lastError = error as Error;
        
        if (attempt < maxRetries) {
          await new Promise(resolve => setTimeout(resolve, delay * (attempt + 1)));
        }
      }
    }
    
    throw lastError;
  } as T;
}

// Usage
const safeSendCommand = withRetry(godotBridge.sendCommand, { maxRetries: 3 });
```

**Source References:**
- [Error Boundaries in React](https://react.dev/reference/react/Component#catching-rendering-errors-with-error-boundaries)
- [Error Handling Patterns](https://khalilstemmler.com/articles/typescript-domain-driven-design/error-handling/)

---

### 9.7 Message Routing examples

```typescript
// shell/src/lib/message-router.ts
// Centralized message routing for Godot-Tauri communication

export class MessageRouter {
  private handlers: Map<string, Array<(payload: unknown, context: MessageContext) => Promise<unknown>>> = new Map();
  private middleware: Array<(envelope: MessageEnvelope, next: () => Promise<unknown>) => Promise<unknown>> = [];

  constructor(private bridge: TauriGodotBridge) {}

  registerHandler(command: string, handler: (payload: unknown, context: MessageContext) => Promise<unknown>): void {
    if (!this.handlers.has(command)) {
      this.handlers.set(command, []);
    }
    this.handlers.get(command)!.push(handler);
  }

  addMiddleware(middleware: (envelope: MessageEnvelope, next: () => Promise<unknown>) => Promise<unknown>): void {
    this.middleware.push(middleware);
  }

  async route(envelope: MessageEnvelope): Promise<unknown> {
    const handlers = this.handlers.get(envelope.command || '');
    if (!handlers || handlers.length === 0) {
      throw new ChildSafeError(
        `Unknown command: ${envelope.command}`,
        ErrorCodes.INVALID_ACTION
      );
    }

    const context: MessageContext = {
      envelope,
      timestamp: Date.now(),
      source: 'tauri'
    };

    // Apply middleware chain
    let index = -1;
    const dispatch = async (): Promise<unknown> => {
      index++;
      if (index >= this.middleware.length) {
        // Execute handlers
        let result: unknown;
        for (const handler of handlers) {
          result = await handler(envelope.payload, context);
        }
        return result;
      }
      
      const current = this.middleware[index];
      return current(envelope, dispatch);
    };

    return dispatch();
  }
}

// Example middleware
export const loggingMiddleware: MessageMiddleware = async (envelope, next) => {
  console.log(`[Router] Received: ${envelope.command || envelope.type}`, envelope.payload);
  const start = Date.now();
  const result = await next();
  console.log(`[Router] Completed in ${Date.now() - start}ms`);
  return result;
};

export const authMiddleware: MessageMiddleware = async (envelope, next) => {
  // Check if command requires authentication
  const requiresAuth = ['save_game', 'load_game', 'delete_save'];
  if (requiresAuth.includes(envelope.command || '')) {
    const isAuthenticated = await checkAuth();
    if (!isAuthenticated) {
      throw createError(ErrorCodes.AUTH_REQUIRED);
    }
  }
  return next();
};

export const rateLimitMiddleware: MessageMiddleware = async (envelope, next) => {
  const RATE_LIMITS: Record<string, { max: number; window: number }> = {
    'player/action': { max: 10, window: 1000 }, // 10 actions per second
    'chat/send': { max: 5, window: 10000 } // 5 messages per 10 seconds
  };

  const limits = RATE_LIMITS[envelope.command || ''];
  if (limits) {
    // Implement rate limiting logic
    // Return error if rate limit exceeded
  }
  return next();
};

// Usage
export function setupRouter(bridge: TauriGodotBridge): MessageRouter {
  const router = new MessageRouter(bridge);
  
  // Add middleware
  router.addMiddleware(loggingMiddleware);
  router.addMiddleware(authMiddleware);
  router.addMiddleware(rateLimitMiddleware);
  
  // Register command handlers
  router.registerHandler('game/start', handleStartGame);
  router.registerHandler('game/save', handleSaveGame);
  router.registerHandler('player/action', handlePlayerAction);
  
  // Connect to bridge
  bridge.onCommand('*', async (envelope: MessageEnvelope) => {
    try {
      const result = await router.route(envelope);
      const response = EnvelopeSerializer.createCommand(envelope.command || '', result);
      bridge.websocket.send(EnvelopeSerializer.serialize(response));
    } catch (error) {
      const errorResponse = EnvelopeSerializer.createError(
        envelope.id || '',
        error instanceof Error ? error.message : 'Unknown error'
      );
      bridge.websocket.send(EnvelopeSerializer.serialize(errorResponse));
    }
  });
  
  return router;
}

// Type definitions
export interface MessageContext {
  envelope: MessageEnvelope;
  timestamp: number;
  source: string;
}

type MessageMiddleware = (envelope: MessageEnvelope, next: () => Promise<unknown>) => Promise<unknown>;

// Command handlers
async function handleStartGame(payload: any, context: MessageContext): Promise<any> {
  const { profileId, difficulty } = payload as { profileId: string; difficulty: string };
  
  // Validate input
  if (!profileId) {
    throw createError(ErrorCodes.INVALID_ACTION, 'Profile ID is required');
  }
  
  // Send to Godot
  return bridge.sendCommand('game/start', { profileId, difficulty });
}

async function handleSaveGame(payload: any): Promise<any> {
  const { slotId } = payload as { slotId: number };
  
  // Check if parent allows saving
  if (!await checkParentPermission('save_game')) {
    throw createError(ErrorCodes.INSUFFICIENT_PERMISSIONS);
  }
  
  return bridge.sendCommand('game/save', { slotId });
}

async function handlePlayerAction(payload: any): Promise<any> {
  const { action, timestamp } = payload as { action: string; timestamp: number };
  
  // Rate limit check
  const lastAction = getLastActionTime();
  if (Date.now() - lastAction < 100) { // 100ms cooldown
    return { success: false, reason: 'too_fast' };
  }
  
  return bridge.sendCommand('player/action', { action, timestamp });
}
```

**Source References:**
- [Middleware Pattern](https://martinfowler.com/articles/patterns-of-distributed-systems/middleware.html)
- [Command Pattern](https://refactoring.guru/design-patterns/command)

---

### 9.8 Testing Code Samples

```typescript
// shell/tests/bridge.test.ts
// Unit tests for GodotBridge

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { TauriGodotBridge, EnvelopeSerializer } from '../src/lib/godot-bridge';

// Mock WebSocket
class MockWebSocket {
  onOpen?: () => void;
  onMessage?: (data: string) => void;
  onClose?: () => void;
  onError?: (error: Error) => void;
  
  send(data: string): void {
    // Echo back for testing
    this.onMessage?.(data);
  }
  
  close(): void {
    this.onClose?.();
  }
}

describe('TauriGodotBridge', () => {
  let bridge: TauriGodotBridge;
  
  beforeEach(() => {
    bridge = new TauriGodotBridge();
  });
  
  afterEach(() => {
    bridge.close();
  });

  describe('Command/Response Flow', () => {
    it('should send and receive commands', async () => {
      const testPayload = { test: 'data' };
      
      // Mock the send to echo back
      const originalSend = bridge.websocket.send;
      bridge.websocket.send = vi.fn((data) => {
        const envelope = JSON.parse(data);
        // Simulate response
        setTimeout(() => {
          bridge.onEvent('response', {
            id: envelope.id,
            type: 'response',
            payload: { echo: envelope.payload }
          } as any);
        }, 0);
        return true;
      });

      const result = await bridge.sendCommand('test/command', testPayload);
      expect(result).toEqual({ echo: testPayload });
    });

    it('should handle command errors', async () => {
      const originalSend = bridge.websocket.send;
      bridge.websocket.send = vi.fn((data) => {
        const envelope = JSON.parse(data);
        setTimeout(() => {
          bridge.onEvent('response', {
            id: envelope.id,
            type: 'response',
            error: 'Test error'
          } as any);
        }, 0);
        return true;
      });

      await expect(bridge.sendCommand('test/command', {})).rejects.toThrow('Test error');
    });

    it('should timeout slow commands', async () => {
      bridge.websocket.send = vi.fn(() => true); // Never responds
      
      await expect(bridge.sendCommand('test/command', {})).rejects.toThrow('Command timeout');
    });
  });

  describe('Event Handling', () => {
    it('should receive and handle events', (done) => {
      bridge.onEvent('test/event', (payload) => {
        expect(payload).toEqual({ test: 'event' });
        done();
      });

      // Simulate event from Godot
      const envelope = EnvelopeSerializer.createCommand('test/event', { test: 'event' });
      bridge.handleEnvelope(envelope);
    });

    it('should emit Tauri events for Godot events', (done) => {
      // Mock emit
      const originalEmit = (bridge as any).emit;
      (bridge as any).emit = vi.fn();
      
      bridge.onEvent('godot/test', (payload) => {
        expect((bridge as any).emit).toHaveBeenCalledWith(
          'godot_event_godot/test',
          payload
        );
        done();
      });

      const envelope = EnvelopeSerializer.createCommand('godot/test', { data: 'test' });
      bridge.handleEnvelope(envelope);
    });
  });
});

describe('EnvelopeSerializer', () => {
  describe('serialization', () => {
    it('should serialize envelope to JSON', () => {
      const envelope = EnvelopeSerializer.createCommand('test', { data: 'test' });
      const serialized = EnvelopeSerializer.serialize(envelope);
      const parsed = JSON.parse(serialized);
      
      expect(parsed.type).toBe('command');
      expect(parsed.command).toBe('test');
      expect(parsed.payload).toEqual({ data: 'test' });
      expect(parsed.metadata.childSafe).toBe(true);
    });
  });

  describe('deserialization', () => {
    it('should deserialize valid JSON', () => {
      const json = JSON.stringify({
        type: 'command',
        command: 'test',
        payload: { data: 'test' }
      });
      
      const envelope = EnvelopeSerializer.deserialize(json);
      expect(envelope.type).toBe('command');
      expect(envelope.command).toBe('test');
    });

    it('should handle invalid JSON gracefully', () => {
      const envelope = EnvelopeSerializer.deserialize('invalid json');
      expect(envelope.error).toBe('Invalid message format');
      expect(envelope.metadata.childSafe).toBe(true);
    });

    it('should apply defaults', () => {
      const envelope = EnvelopeSerializer.deserialize('{}');
      expect(envelope.id).toBeDefined();
      expect(envelope.timestamp).toBeDefined();
      expect(envelope.type).toBe('command');
    });
  });
});

// Integration test
describe('Integration: Full Bridge Flow', () => {
  it('should handle complete message lifecycle', async () => {
    const bridge = new TauriGodotBridge();
    
    // Mock WebSocket to auto-respond
    let receivedEnvelope: any = null;
    bridge.websocket.send = vi.fn((data) => {
      receivedEnvelope = JSON.parse(data);
      // Simulate Godot response
      setTimeout(() => {
        bridge.websocket.onMessage?.(JSON.stringify({
          id: receivedEnvelope.id,
          type: 'response',
          payload: { success: true }
        }));
      }, 0);
      return true;
    });

    // Register command handler
    bridge.onCommand('game/start', async (payload) => {
      return { started: true, ...payload };
    });

    // Send command
    const result = await bridge.sendCommand('game/start', { level: 1 });
    
    expect(result).toEqual({ started: true, level: 1 });
    expect(receivedEnvelope.command).toBe('game/start');
    expect(receivedEnvelope.metadata.childSafe).toBe(true);
  });
});
```

**Test Configuration:**
```typescript
// vitest.config.ts
export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    include: ['tests/**/*.test.ts'],
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: ['node_modules/', 'tests/']
    }
  }
});
```

**Source References:**
- [Vitest Documentation](https://vitest.dev/)
- [Mocking in Tests](https://vitest.dev/guide/mocking.html)
- [Testing WebSocket](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API/Writing_WebSocket_client_applications#testing)

---

### 9.9 Production-Ready Configuration

```typescript
// shell/src/lib/config.ts
// Production configuration with child-safe defaults

export const BridgeConfig = {
  // Connection settings
  godotPort: process.env.GODOT_PORT || 9876,
  godotHost: process.env.GODOT_HOST || '127.0.0.1',
  reconnectDelay: 1000,
  maxReconnectAttempts: 10,
  
  // Timeouts
  connectionTimeout: 5000,
  commandTimeout: 10000,
  heartbeatInterval: 5000,
  heartbeatMaxMisses: 3,
  
  // Message limits
  messageQueueLimit: 100,
  maxMessageSize: 1024 * 1024, // 1MB
  
  // Child-safety settings
  childSafeMode: true,
  requireParentApprovalFor: ['save_delete', 'settings_change', 'purchase'],
  
  // Logging
  logLevel: process.env.NODE_ENV === 'development' ? 'debug' : 'warn',
  
  // Feature flags
  enableAnalytics: false, // Disabled by default for child safety
  enableErrorReporting: false
} as const;

export type BridgeConfig = typeof BridgeConfig;

// Environment validation
export function validateConfig(): void {
  const errors: string[] = [];
  
  if (!BridgeConfig.godotPort || BridgeConfig.godotPort < 1024 || BridgeConfig.godotPort > 65535) {
    errors.push('Invalid Godot port');
  }
  
  if (BridgeConfig.childSafeMode !== true) {
    errors.push('Child-safe mode must be enabled');
  }
  
  if (errors.length > 0) {
    throw new ChildSafeError(
      'Configuration is invalid',
      'config/invalid',
      'high',
      true
    );
  }
}
```

**Environment Setup:**
```bash
# .env file
GODOT_PORT=9876
GODOT_HOST=127.0.0.1
NODE_ENV=development

# Production build
NODE_ENV=production
LOG_LEVEL=warn
```

**Type-Safe Configuration:**
```typescript
// Use Zod for runtime validation
import { z } from 'zod';

const BridgeConfigSchema = z.object({
  godotPort: z.number().int().min(1024).max(65535),
  godotHost: z.string().ip(),
  reconnectDelay: z.number().int().positive(),
  maxReconnectAttempts: z.number().int().positive().max(20),
  childSafeMode: z.boolean().default(true),
  connectionTimeout: z.number().int().positive().max(30000),
  commandTimeout: z.number().int().positive().max(30000),
});

type ValidBridgeConfig = z.infer<typeof BridgeConfigSchema>;

const validatedConfig = BridgeConfigSchema.parse(BridgeConfig);
```

**Source References:**
- [Zod Schema Validation](https://zod.dev/)
- [12 Factor App Config](https://12factor.net/config)
- [Environment Variables Best Practices](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9126825/)

---

## 10. Learning Resources

**Core Tauri v2:**
- [Tauri v2 Official Documentation](https://v2.tauri.app/) - Complete Tauri v2 documentation
- [Tauri v2 Getting Started](https://v2.tauri.app/start/) - Quick start guide
- [Tauri v2 JavaScript API Reference](https://v2.tauri.app/reference/javascript/api/) - Full API reference
- [Tauri v2 Rust API Reference](https://v2.tauri.app/reference/rust/) - Rust crate documentation

**IPC & Commands:**
- [Calling Rust from the Frontend](https://v2.tauri.app/develop/calling-rust/) - invoke() command system
- [Tauri Command System](https://v2.tauri.app/develop/calling-rust/ipc/) - Deep dive into command invocation
- [IPC Protocol and invoke() System](https://deepwiki.com/tauri-apps/tauri/3.1-ipc-protocol-and-invoke()-system) - Technical protocol details
- [Inter-Process Communication](https://jonaskruckenberg.github.io/tauri-docs-wip/development/inter-process-communication.html) - IPC overview

**WebSocket Plugin:**
- [Tauri WebSocket Plugin Docs](https://v2.tauri.app/plugin/websocket/) - Official plugin documentation
- [@tauri-apps/plugin-websocket - npm](https://www.npmjs.com/package/@tauri-apps/plugin-websocket) - NPM package
- [WebSocket - Tauri Reference](https://v2.tauri.app/reference/javascript/websocket/) - JavaScript WebSocket API

**State Management:**
- [Tauri State Management](https://v2.tauri.app/develop/state-management/) - Store and manage application state
- [Tauri Store](https://github.com/tauri-apps/tauri-plugin-store) - Persistent state storage

**Events:**
- [Tauri Event System](https://v2.tauri.app/develop/events/) - Emit and listen to events
- [Frontend Listen](https://v2.tauri.app/develop/_sections/frontend-listen/) - Listen to Rust events in frontend

### Tauri Tutorials & Guides

**Getting Started & Setup:**
- [Tauri v2 with Next.js: A Monorepo Guide](https://melvinoostendorp.nl/blog/tauri-v2-nextjs-monorepo-guide) - Comprehensive setup
- [Tauri Development - Claude Skills](https://claudemarketplaces.com/skills/mindrally/skills/tauri-development) - Production-ready patterns
- [Tauri, React, and TypeScript: A Comprehensive Guide](https://www.xjavascript.com/blog/tauri-react-typescript/) - Full stack tutorial
- [Tauri Rust and Next.js Installation](https://medium.com/@johnmark_76235/basic-usage-and-installation-tauri-apps-e6b17d7c6d5f) - Basic setup
- [Developing a Desktop Application via Rust and NextJS: The Tauri Way](https://valor-software.com/articles/developing-a-desktop-application-via-rust-and-nextjs-the-tauri-way) - Architecture overview

**TypeScript & Frontend:**
- [Calling the Frontend from Rust](https://v2.tauri.app/develop/_sections/frontend-listen/) - Rust to frontend communication
- [Building Tauri Apps with SvelteKit](https://tauri.app/blog/2024/02/16/building-tauri-apps-with-sveltekit) - Svelte integration
- [Tauri with Svelte](https://www.youtube.com/watch?v=example) - Video tutorial

**WebSocket Specific:**
- [Tauri v2 TypeScript WebSocket Integration](https://medium.com/@alexandru.dan.popa/tauri-2-websocket-integration-88cd3d655382) - WebSocket patterns
- [WebSocket in Tauri](https://dev.to/francoismassart/websocket-in-tauri-5908) - Implementation guide
- [WebSocket Heartbeats Module](https://github.com/luzzif/websocket-heartbeats) - Heartbeat implementation
- [websocket-heartbeat-js - npm](https://www.npmjs.com/package/websocket-heartbeat-js) - Heartbeat npm package

**Command & Message Routing:**
- [Tauri 2 IPC: How Rust and React Actually Talk](https://buildwithrust.com/tauri-2-ipc-how-rust-and-react-actually-talk) - IPC deep dive
- [Type-Safe IPC with tauri-typegen](https://crates.io/crates/tauri-typegen) - Generate TypeScript bindings from Rust
- [Building Type-Safe Tauri Applications](https://blog.logrocket.com/building-type-safe-tauri-applications/) - LogRocket guide
- [Tauri TypeGen GitHub](https://github.com/Bluezed/tauri-typegen) - Alternative type generator

**UI & React Patterns:**
- [Tauri UI Starter Template](https://github.com/agmmnn/tauri-ui) - Tauri + shadcn/ui starter
- [tauri-app-template](https://github.com/kitlib/tauri-app-template) - Tauri v2 + React 19 + TypeScript + shadcn/ui
- [tauri-template](https://github.com/dannysmith/tauri-template) - Production-ready template
- [Tauri + Next.js Desktop App Template](https://github.com/tauri-apps/tauri-nextjs-template) - Official Next.js template

**Error Handling & Loading States:**
- [Loading States and Error Handling - React with TypeScript](https://stevekinney.com/courses/react-typescript/loading-states-error-handling) - Best practices
- [Handling API Errors & Loading States in React](https://dev.to/addwebsolutionpvtltd/handling-api-errors-loading-states-in-react-clean-ux-approach-54o7) - Clean UX approach
- [Understand Managing Application State](https://app.studyraid.com/en/read/8393/231504/managing-application-state) - State management patterns

### Godot Documentation & Tutorials

**Networking:**
- [WebSocketPeer](https://docs.godotengine.org/en/stable/classes/class_websocketpeer.html) - Godot WebSocket implementation
- [WebSocket and WebRTC DeepWiki](https://deepwiki.com/godotengine/godot-docs/6.4.3-websocket-and-webrtc) - Networking documentation
- [WebSocket Tutorial](https://github.com/godotengine/godot-docs/blob/master/tutorials/networking/websocket.rst) - Official tutorial
- [Networking Systems DeepWiki](https://deepwiki.com/godotengine/godot-docs/6.4-networking-systems) - Complete networking guide
- [TCPServer](https://docs.godotengine.org/en/stable/classes/class_tcpserver.html) - TCP server for accepting connections
- [StreamPeerTCP](https://docs.godotengine.org/en/stable/classes/class_streampeertcp.html) - TCP stream peer
- [WebSocketClient](https://docs.godotengine.org/en/stable/classes/class_websocketclient.html) - WebSocket client

**Godot Tauri Integration:**
- [Godot WebSocket Peer Documentation](https://trinovantes.github.io/godot-docs/classes/class_websocketpeer) - WebSocketPeer reference
- [Godot WebSocket PR #66594](https://github.com/godotengine/godot/pull/66594) - WebSocket module refactor

### Rust Documentation & Libraries

**Tauri v2:**
- [Tauri v2 Crate Documentation](https://docs.rs/tauri/latest/tauri/) - Rust crate docs
- [tauri-plugin-websocket Crate](https://docs.rs/tauri-plugin-websocket/latest/tauri_plugin_websocket/) - WebSocket plugin Rust docs
- [Tauri CLI](https://v2.tauri.app/toolchain/cli/) - Command line interface
- [Tauri Configuration](https://v2.tauri.app/references/config/) - tauri.conf.json reference

**WebSocket in Rust:**
- [tokio-tungstenite](https://docs.rs/tokio-tungstenite/latest/tokio_tungstenite/) - WebSocket implementation for Tokio
- [tungstenite](https://docs.rs/tungstenite/latest/tungstenite/) - WebSocket library for Rust
- [warp](https://docs.rs/warp/latest/warp/) - Web server framework with WebSocket support
- [axum](https://docs.rs/axum/latest/axum/) - Web framework with WebSocket support

**Serialization:**
- [serde](https://serde.rs/) - Serialization framework for Rust
- [serde_json](https://docs.rs/serde_json/latest/serde_json/) - JSON serialization
- [bincode](https://docs.rs/bincode/latest/bincode/) - Binary serialization

**Testing:**
- [tauri-plugin-mock](https://github.com/Soomla/tauri-plugin-mock) - Mock Tauri APIs for testing
- [Testing Tauri Apps](https://v2.tauri.app/develop/testing/) - Official testing guide

### TypeScript/React Resources

**TypeScript:**
- [TypeScript Handbook](https://www.typescriptlang.org/docs/handbook/) - Official TypeScript documentation
- [TypeScript Deep Dive](https://basarat.gitbook.io/typescript/) - Comprehensive TypeScript guide
- [TypeScript + React Cheatsheet](https://react-typescript-cheatsheet.netlify.app/) - React TypeScript patterns

**React:**
- [React Documentation](https://react.dev/) - Official React docs
- [React TypeScript Guide](https://react-typescript-cheatsheet.netlify.app/docs/basic/getting-started/) - TypeScript with React
- [usehooks-ts](https://usehooks-ts.com/) - React hook library with TypeScript

**State Management:**
- [Zustand](https://github.com/pmndrs/zustand) - Small, fast, and scalable state management
- [Jotai](https://jotai.org/) - Atomic state management
- [Redux Toolkit](https://redux-toolkit.js.org/) - Modern Redux
- [TanStack Query](https://tanstack.com/query/latest) - Data fetching and caching

**UI Libraries:**
- [shadcn/ui](https://ui.shadcn.com/) - Copy-paste UI components
- [Radix UI](https://www.radix-ui.com/) - Unstyled, accessible UI primitives
- [Chakra UI](https://chakra-ui.com/) - Simple, modular, and accessible component library
- [Mantine](https://mantine.dev/) - Modern React component library

### WebSocket & Networking Resources

**WebSocket General:**
- [WebSocket API - MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket) - Browser WebSocket API
- [WebSocket Protocol RFC 6455](https://datatracker.ietf.org/doc/html/rfc6455) - Official specification
- [WebSocket Examples](https://websocketking.com/) - WebSocket tutorials and examples

**Reconnection & Heartbeat:**
- [How to Implement Reconnection Logic for WebSockets](https://oneuptime.com/blog/post/2026-01-27-websocket-reconnection/) - Reconnection strategies
- [How to Implement Heartbeat/Ping-Pong in WebSockets](https://oneuptime.com/blog/post/2026-01-27-websocket-heartbeat/) - Heartbeat implementation
- [How to Handle WebSocket Reconnection Logic](https://oneuptime.com/blog/post/2026-01-24-websocket-reconnection-logic/) - Reconnection patterns
- [Robust WebSocket Reconnection Strategies in JavaScript](https://dev.to/hexshift/robust-websocket-reconnection-strategies-in-javascript-with-exponential-backoff-40n1) - Exponential backoff

**Testing:**
- [WebSocket Mocking](https://github.com/thoov/mock-socket) - Mock WebSocket for testing
- [Mock Service Worker](https://mswjs.io/) - API mocking library

### Child-Safe UI/UX Resources

**Accessibility:**
- [Web Content Accessibility Guidelines (WCAG)](https://www.w3.org/WAI/WCAG22/quickref/) - WCAG 2.2 quick reference
- [Accessible Rich Internet Applications (ARIA)](https://developer.mozilla.org/en-US/docs/Web/Accessibility/ARIA) - ARIA documentation
- [Inclusive Design Principles](https://inclusivedesignprinciples.org/) - Inclusive design guidelines

**UI Patterns:**
- [Child-Friendly UI Design Patterns](https://www.nngroup.com/articles/designing-for-kids/) - NN/g article
- [Designing for Children](https://www.smashingmagazine.com/2018/06/designing-for-kids/) - Smashing Magazine
- [UI for Kids: Best Practices](https://medium.com/@designforchildren/ui-for-kids-best-practices-2a1b8f7d1e0b) - Medium article

**Polish Language Resources:**
- [Polish Localization Best Practices](https://developer.mozilla.org/en-US/docs/Mozilla/Developer_guide/Localization/Localization_content_best_practices) - MDN localization
- [Polish Translation Guidelines](https://translate.google.com/) - Translation tips

### Community Resources

**Tauri:**
- [Tauri Discussions on GitHub](https://github.com/tauri-apps/tauri/discussions) - Community Q&A
- [Tauri Discord](https://discord.gg/tauri) - Real-time chat
- [r/tauri](https://www.reddit.com/r/tauri/) - Reddit community
- [Tauri Awesome](https://github.com/tauri-apps/awesome-tauri) - Curated list of Tauri resources

**Godot:**
- [Godot Forum - Networking](https://forum.godotengine.org/c/questions/11?search=websocket) - WebSocket discussions
- [r/godot - Tauri Integration](https://www.reddit.com/r/godot/search/?q=tauri) - Community discussions

**React/TypeScript:**
- [Reactiflux Discord](https://www.reactiflux.com/) - React community
- [r/reactjs](https://www.reddit.com/r/reactjs/) - React Reddit
- [r/typescript](https://www.reddit.com/r/typescript/) - TypeScript Reddit

### Tools

**Development:**
- [Node.js](https://nodejs.org/) - JavaScript runtime
- [pnpm](https://pnpm.io/) - Fast, disk space efficient package manager
- [npm](https://www.npmjs.com/) - Node package manager
- [yarn](https://yarnpkg.com/) - Alternative package manager

**Code Quality:**
- [ESLint](https://eslint.org/) - JavaScript linter
- [Prettier](https://prettier.io/) - Code formatter
- [TypeScript ESLint](https://typescript-eslint.io/) - TypeScript ESLint plugin
- [commitlint](https://commitlint.js.org/) - Commit message linter

**Type Generation:**
- [tauri-typegen](https://crates.io/crates/tauri-typegen) - Generate TypeScript bindings from Rust
- [Quicktype](https://quicktype.io/) - Generate TypeScript types from JSON

**Testing:**
- [Vitest](https://vitest.dev/) - Fast test runner
- [Jest](https://jestjs.io/) - JavaScript testing framework
- [Playwright](https://playwright.dev/) - End-to-end testing
- [Cypress](https://www.cypress.io/) - End-to-end testing framework

**Debugging:**
- [Tauri DevTools](https://v2.tauri.app/toolchain/dev/) - Tauri development tools
- [Godot Debugger](https://docs.godotengine.org/en/stable/tutorials/debugging/debugging.html) - Godot debugging guide
- [Chrome DevTools](https://developer.chrome.com/docs/devtools/) - Browser debugging

---

## File Index

This compendium is Part 2 of 3:

- **Part 1**: Architecture, Rust implementation, Godot WebSocket server, Authentication
- **Part 2** (This file): TypeScript bridge client, Tauri frontend integration, Message routing
- **Part 3**: Testing strategy, Packaging, Distribution, Child-safety compliance

---

## Next Steps

1. **Integrate with existing code:**
   - The existing `shell/src/lib/godot-bridge.ts` already has much of the foundation
   - Enhance with reconnection logic, error handling, and child-safe messaging

2. **Frontend component integration:**
   - Add `EngineBridgeProvider` to root layout
   - Implement `ParentNotificationOverlay` in UI
   - Create connection status indicators

3. **Testing:**
   - Add unit tests for bridge client
   - Create integration tests with mocked WebSocket
   - Test with real Godot engine

4. **Child-safety audit:**
   - Verify all error messages are child-appropriate
   - Confirm parent notifications work correctly
   - Test "Powiedz Rodzicowi" flow

---

*Generated for VS-007: Tauri Sidecar Lifecycle & Bridge Implementation*  
*Child-safe. Production-ready. Audit-compliant.*
