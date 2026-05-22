/**
 * GodotBridge — TypeScript client for the Godot-side TestBridgePort/ShellBridgePort
 * WebSocket server (see thoughts/shared/research/shell-architecture-2026-05-21.md).
 *
 * Wire protocol (JSON envelopes, line-delimited if needed; one frame = one envelope):
 *
 *   client -> engine:
 *     { "type": "cmd",  "id": 1, "command": "ping", "params": {} }
 *
 *   engine -> client (ack):
 *     { "type": "ack",  "id": 1, "ok": true, "result": { "pong": true } }
 *
 *   engine -> client (event):
 *     { "type": "event", "name": "session_end", "payload": { ... } }
 *
 * Kid-safety invariants:
 *   - Bind only `127.0.0.1` on the Godot side. Never expose to LAN. Audit-ledger
 *     hashes every cmd + event inside Godot (TASK-019 hash chain).
 *   - Heartbeat every 5 s; if engine misses 3 in a row, the client surfaces a
 *     "Powiedz Rodzicowi" (Tell a Parent) overlay.
 *
 * This file is the skeleton: handshake (`hello`) + heartbeat (`ping`).
 * Real domain commands (start_play, quit, pause, …) land in a follow-up PR.
 */

export const DEFAULT_BRIDGE_URL = "ws://127.0.0.1:9876" as const;
export const HEARTBEAT_INTERVAL_MS = 5_000;
export const HEARTBEAT_MAX_MISSES = 3;
export const CONNECT_TIMEOUT_MS = 5_000;

export type BridgeStatus =
  | "idle"
  | "connecting"
  | "open"
  | "closing"
  | "closed"
  | "error";

export interface Envelope {
  type: "cmd" | "ack" | "event";
  id?: number;
  command?: string;
  name?: string;
  params?: Record<string, unknown>;
  payload?: Record<string, unknown>;
  result?: unknown;
  ok?: boolean;
  error?: string;
}

export interface BridgeEvents {
  status: BridgeStatus;
  event: { name: string; payload: Record<string, unknown> };
  ack: Envelope;
  error: string;
}

type Listener<K extends keyof BridgeEvents> = (data: BridgeEvents[K]) => void;

interface PendingCmd {
  resolve: (result: unknown) => void;
  reject: (err: Error) => void;
  timer: ReturnType<typeof setTimeout> | null;
}

export class GodotBridge {
  private ws: WebSocket | null = null;
  private url: string;
  private nextId = 1;
  private pending = new Map<number, PendingCmd>();
  private listeners: { [K in keyof BridgeEvents]: Set<Listener<K>> } = {
    status: new Set(),
    event: new Set(),
    ack: new Set(),
    error: new Set(),
  };
  private status: BridgeStatus = "idle";
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private heartbeatMisses = 0;

  constructor(url: string = DEFAULT_BRIDGE_URL) {
    this.url = url;
  }

  getStatus(): BridgeStatus {
    return this.status;
  }

  on<K extends keyof BridgeEvents>(event: K, listener: Listener<K>): () => void {
    this.listeners[event].add(listener);
    return () => this.listeners[event].delete(listener);
  }

  private emit<K extends keyof BridgeEvents>(event: K, data: BridgeEvents[K]): void {
    for (const l of this.listeners[event]) {
      try {
        l(data);
      } catch (e) {
        console.error("[godot-bridge] listener threw", e);
      }
    }
  }

  private setStatus(next: BridgeStatus): void {
    if (this.status === next) return;
    this.status = next;
    this.emit("status", next);
  }

  /**
   * Open the WS connection and perform a `hello` handshake. Resolves once
   * the engine acks the handshake. Rejects on timeout or socket error.
   */
  async connect(): Promise<void> {
    if (this.ws && (this.status === "open" || this.status === "connecting")) {
      return;
    }
    this.setStatus("connecting");

    return new Promise<void>((resolve, reject) => {
      let settled = false;
      const settle = (fn: () => void) => {
        if (settled) return;
        settled = true;
        fn();
      };

      const ws = new WebSocket(this.url);
      this.ws = ws;

      const connectTimer = setTimeout(() => {
        settle(() => {
          this.setStatus("error");
          this.emit("error", `connect timeout after ${CONNECT_TIMEOUT_MS}ms`);
          ws.close();
          reject(new Error("connect timeout"));
        });
      }, CONNECT_TIMEOUT_MS);

      ws.addEventListener("open", () => {
        clearTimeout(connectTimer);
        this.setStatus("open");
        this.startHeartbeat();
        this.send({ type: "cmd", command: "hello", params: { client: "choyce-shell", version: "0.1.0" } })
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

      ws.addEventListener("close", () => {
        this.stopHeartbeat();
        this.setStatus("closed");
        for (const [, pending] of this.pending) {
          if (pending.timer) clearTimeout(pending.timer);
          pending.reject(new Error("bridge closed"));
        }
        this.pending.clear();
      });
    });
  }

  disconnect(): void {
    this.stopHeartbeat();
    if (this.ws && this.status !== "closed") {
      this.setStatus("closing");
      this.ws.close();
    }
    this.ws = null;
  }

  /**
   * Send a JSON envelope. If the envelope is a `cmd` and has no `id` set,
   * an id is assigned and the returned promise resolves with the matching ack.
   */
  send(envelope: Envelope, timeoutMs = 10_000): Promise<unknown> {
    if (!this.ws || this.status !== "open") {
      return Promise.reject(new Error(`bridge not open (status=${this.status})`));
    }
    const env: Envelope = { ...envelope };
    if (env.type === "cmd") {
      env.id = env.id ?? this.nextId++;
      const id = env.id;
      return new Promise<unknown>((resolve, reject) => {
        const timer = setTimeout(() => {
          this.pending.delete(id);
          reject(new Error(`cmd ${env.command} (#${id}) timeout`));
        }, timeoutMs);
        this.pending.set(id, { resolve, reject, timer });
        try {
          this.ws!.send(JSON.stringify(env));
        } catch (e) {
          this.pending.delete(id);
          clearTimeout(timer);
          reject(e instanceof Error ? e : new Error(String(e)));
        }
      });
    }
    this.ws.send(JSON.stringify(env));
    return Promise.resolve(undefined);
  }

  /** Convenience: heartbeat ping that doubles as liveness probe. */
  ping(): Promise<unknown> {
    return this.send({ type: "cmd", command: "ping" }, 2_000);
  }

  private onMessage(ev: MessageEvent): void {
    let env: Envelope;
    try {
      env = JSON.parse(typeof ev.data === "string" ? ev.data : "") as Envelope;
    } catch {
      this.emit("error", "malformed envelope from engine");
      return;
    }
    if (env.type === "ack" && typeof env.id === "number") {
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
}
