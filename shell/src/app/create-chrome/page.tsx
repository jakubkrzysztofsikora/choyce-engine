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
    <section className="min-h-screen bg-gradient-to-b from-emerald-50 via-sky-50 to-amber-50 px-6 py-10">
      <header className="mx-auto mb-6 max-w-6xl">
        <div className="flex items-center gap-3">
          <span aria-hidden="true" className="text-4xl">🧱</span>
          <h1 className="text-3xl font-extrabold tracking-tight text-slate-800 md:text-4xl">
            {t("create.title")}
          </h1>
        </div>
        <p className="mt-1 text-sm text-slate-600">{t("create.sub")}</p>
      </header>

      <div className="mx-auto mb-4 flex max-w-6xl flex-wrap items-center justify-between gap-3">
        <div className="rounded-full bg-white/80 px-3 py-1 text-[11px] font-bold uppercase tracking-widest text-slate-600 shadow-sm">
          {engineLabel}
        </div>
        {offline && (
          <div className="flex items-center gap-3 rounded-full bg-amber-50 px-3 py-1 text-sm text-amber-800 shadow-sm">
            <span>{t("create.engine_offline_help")}</span>
            <button
              type="button"
              onClick={() => void ensureBridge()}
              className="rounded-full bg-amber-500 px-3 py-1 text-xs font-bold text-white shadow-sm transition-colors hover:bg-amber-600"
            >
              {t("create.connect_retry")}
            </button>
          </div>
        )}
      </div>

      <div
        ref={canvasRef}
        role="application"
        aria-label={t("create.title")}
        tabIndex={0}
        onPointerMove={handlePointerMove}
        onClick={handleClick}
        onContextMenu={handleContextMenu}
        onKeyDown={handleKeyDown}
        data-testid="create-canvas"
        className="checkerboard-bg relative mx-auto h-[60vh] w-full max-w-6xl select-none rounded-3xl border-2 border-emerald-300 bg-white/60 shadow-lg focus:border-emerald-500 focus:outline-none focus:ring-4 focus:ring-emerald-200"
        style={{ cursor: "crosshair" }}
      >
        <div className="pointer-events-none absolute inset-0 flex items-center justify-center">
          <p className="rounded-2xl bg-white/80 px-6 py-3 text-center text-sm font-medium text-slate-700 shadow-sm">
            {t("create.canvas_hint")}
          </p>
        </div>
        <div
          aria-hidden="true"
          style={{
            position: "absolute",
            left: `calc(${cursorRef.current.x * 100}% - 6px)`,
            top: `calc(${cursorRef.current.y * 100}% - 6px)`,
          }}
          className="pointer-events-none h-3 w-3 rounded-full border-2 border-emerald-500 bg-emerald-200"
        />
      </div>

      {lastDispatched && (
        <div
          aria-live="polite"
          className="mx-auto mt-3 max-w-6xl text-center text-sm font-medium text-emerald-700"
        >
          {lastDispatched}
        </div>
      )}
    </section>
  );
}
