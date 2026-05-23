"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { GodotBridge, type BridgeStatus } from "@/lib/godot-bridge";
import { t } from "@/lib/i18n";

/**
 * Create chrome — the Tauri shell page that hosts the in-engine BUILDER
 * canvas. Today this is a transparent input surface that captures the
 * kid's pointer + keyboard input and ships it across the WebSocket
 * bridge to the Godot side as `input` cmd envelopes carrying
 * `place_block` / `break_block` / `cursor_move` actions. The actual 3D
 * render happens in the Godot sidecar window; this canvas is just an
 * input forwarder + status surface for now.
 *
 * Why a separate canvas (vs the Godot window owning input directly):
 *   - Tauri shell can render PL UI chrome (header/footer/parent nav)
 *     over the engine without the Godot side having to bring up
 *     web-native controls.
 *   - Keyboard fallback (Arrow/Enter/Backspace) lives in the shell so
 *     non-mouse kids can place/break blocks.
 *   - Per kid-safety policy, the engine never gets a raw mouse stream
 *     from the OS — it only sees high-level intents that we validate
 *     here first.
 *
 * Wire protocol (sent via GodotBridge.send):
 *   { type: "cmd", command: "input",
 *     params: { action: "place_block" | "break_block" | "cursor_move",
 *               x: number, y: number  // 0..1 normalized } }
 */
export default function CreateChromePage() {
  const [status, setStatus] = useState<BridgeStatus>("idle");
  const bridgeRef = useRef<GodotBridge | null>(null);
  const canvasRef = useRef<HTMLDivElement | null>(null);
  // Cursor position is normalized 0..1 for resolution-independent dispatch.
  const cursorRef = useRef<{ x: number; y: number }>({ x: 0.5, y: 0.5 });
  const [lastDispatched, setLastDispatched] = useState<string>("");

  const ensureBridge = useCallback(async (): Promise<GodotBridge> => {
    if (!bridgeRef.current) {
      const b = new GodotBridge();
      b.on("status", setStatus);
      bridgeRef.current = b;
    }
    if (bridgeRef.current.getStatus() !== "open") {
      try {
        await bridgeRef.current.connect();
      } catch {
        /* surface via status state */
      }
    }
    return bridgeRef.current;
  }, []);

  useEffect(() => {
    void ensureBridge();
    return () => {
      bridgeRef.current?.disconnect();
      bridgeRef.current = null;
    };
  }, [ensureBridge]);

  const dispatchInput = useCallback(
    async (action: "place_block" | "break_block" | "cursor_move") => {
      const bridge = bridgeRef.current;
      if (!bridge || bridge.getStatus() !== "open") {
        setLastDispatched(`offline · ${action}`);
        return;
      }
      try {
        await bridge.send({
          type: "cmd",
          command: "input",
          params: { action, x: cursorRef.current.x, y: cursorRef.current.y },
        });
        setLastDispatched(action);
      } catch (e) {
        setLastDispatched(`error · ${action} · ${(e as Error).message}`);
      }
    },
    []
  );

  // Pointer handlers — capture clicks on the canvas surface and translate
  // them into bridge envelopes. Normalize coords to 0..1 so the engine
  // can reproject at its current viewport.
  const updateCursor = useCallback((clientX: number, clientY: number) => {
    const el = canvasRef.current;
    if (!el) return;
    const rect = el.getBoundingClientRect();
    if (rect.width === 0 || rect.height === 0) return;
    cursorRef.current = {
      x: (clientX - rect.left) / rect.width,
      y: (clientY - rect.top) / rect.height,
    };
  }, []);

  const handlePointerMove = useCallback(
    (e: React.PointerEvent<HTMLDivElement>) => {
      updateCursor(e.clientX, e.clientY);
      // Throttle cursor_move to ~30Hz in a follow-up; for now every move.
      void dispatchInput("cursor_move");
    },
    [updateCursor, dispatchInput]
  );

  const handleClick = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      updateCursor(e.clientX, e.clientY);
      void dispatchInput("place_block");
    },
    [updateCursor, dispatchInput]
  );

  const handleContextMenu = useCallback(
    (e: React.MouseEvent<HTMLDivElement>) => {
      e.preventDefault(); // suppress browser context menu over the canvas
      updateCursor(e.clientX, e.clientY);
      void dispatchInput("break_block");
    },
    [updateCursor, dispatchInput]
  );

  // Keyboard fallback for non-mouse kids: arrows move the cursor in 5%
  // steps; Enter places; Backspace breaks. Required by a11y guidance in
  // the MVP plan §15.
  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent<HTMLDivElement>) => {
      const STEP = 0.05;
      const c = cursorRef.current;
      let consumed = true;
      switch (e.key) {
        case "ArrowLeft":
          cursorRef.current = { x: Math.max(0, c.x - STEP), y: c.y };
          void dispatchInput("cursor_move");
          break;
        case "ArrowRight":
          cursorRef.current = { x: Math.min(1, c.x + STEP), y: c.y };
          void dispatchInput("cursor_move");
          break;
        case "ArrowUp":
          cursorRef.current = { x: c.x, y: Math.max(0, c.y - STEP) };
          void dispatchInput("cursor_move");
          break;
        case "ArrowDown":
          cursorRef.current = { x: c.x, y: Math.min(1, c.y + STEP) };
          void dispatchInput("cursor_move");
          break;
        case "Enter":
          void dispatchInput("place_block");
          break;
        case "Backspace":
        case "Delete":
          void dispatchInput("break_block");
          break;
        default:
          consumed = false;
      }
      if (consumed) e.preventDefault();
    },
    [dispatchInput]
  );

  const engineLabel =
    status === "open"
      ? t("create.status_engine_online")
      : status === "connecting"
        ? t("create.status_engine_connecting")
        : t("create.status_engine_offline");

  const offline = status !== "open";

  return (
    <section className="px-8 py-12">
      <header className="mb-6">
        <h1
          className="glitch-text text-4xl md:text-6xl font-black tracking-tight neon-lime"
          data-text={t("create.title")}
        >
          {t("create.title")}
        </h1>
        <p className="mt-3 font-mono text-xs tracking-widest text-white/50">
          {t("create.sub")}
        </p>
      </header>

      <div className="flex flex-wrap items-center justify-between gap-4 mb-4">
        <div className="font-mono text-[10px] tracking-[0.4em] text-white/60">
          {engineLabel}
        </div>
        {offline && (
          <div className="flex items-center gap-3 text-[10px] font-mono text-white/40">
            <span>{t("create.engine_offline_help")}</span>
            <button
              type="button"
              onClick={() => void ensureBridge()}
              className="bracket-cta text-lime-300"
            >
              {t("create.connect_retry")}
            </button>
          </div>
        )}
      </div>

      <div
        ref={canvasRef}
        // role + tabIndex make this focusable for keyboard fallback
        role="application"
        aria-label={t("create.title")}
        tabIndex={0}
        onPointerMove={handlePointerMove}
        onClick={handleClick}
        onContextMenu={handleContextMenu}
        onKeyDown={handleKeyDown}
        data-testid="create-canvas"
        className="checkerboard-bg relative h-[60vh] w-full border border-lime-500/30 cursor-crosshair focus:outline-none focus:ring-2 focus:ring-lime-400 select-none"
      >
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <p className="font-mono text-[10px] tracking-widest text-white/40 text-center">
            {t("create.canvas_hint")}
          </p>
        </div>
        <div
          // Visual cursor marker for keyboard users — purely cosmetic.
          aria-hidden="true"
          style={{
            position: "absolute",
            left: `calc(${cursorRef.current.x * 100}% - 6px)`,
            top: `calc(${cursorRef.current.y * 100}% - 6px)`,
          }}
          className="w-3 h-3 border border-lime-400 pointer-events-none"
        />
      </div>

      {lastDispatched && (
        <div
          aria-live="polite"
          className="mt-3 font-mono text-[10px] tracking-widest text-lime-400/70"
        >
          {`// ${lastDispatched.toUpperCase()}`}
        </div>
      )}
    </section>
  );
}
