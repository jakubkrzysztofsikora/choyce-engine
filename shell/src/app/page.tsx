"use client";

import { useEffect, useState } from "react";
import { GodotBridge, type BridgeStatus } from "@/lib/godot-bridge";
import { t } from "@/lib/i18n";

export default function LandingPage() {
  const [status, setStatus] = useState<BridgeStatus>("idle");

  useEffect(() => {
    const bridge = new GodotBridge();
    const off = bridge.on("status", (s) => setStatus(s));
    // Best-effort probe; landing page works fine when engine is offline.
    bridge.connect().catch(() => {
      /* engine not running yet — landing CTAs will trigger sidecar spawn later */
    });
    return () => {
      off();
      bridge.disconnect();
    };
  }, []);

  const engineLabel =
    status === "open"
      ? t("landing.status_engine_online")
      : status === "connecting"
        ? t("landing.status_engine_connecting")
        : t("landing.status_engine_offline");

  return (
    <section className="px-8 py-12 flex flex-col items-center text-center gap-12">
      <div className="text-[10px] font-mono tracking-[0.4em] text-white/50">
        {engineLabel}
      </div>

      <h1
        className="glitch-text text-6xl md:text-8xl font-black tracking-tight neon-lime"
        data-text={t("landing.headline")}
      >
        {t("landing.headline")}
      </h1>

      <p className="glitch-sub text-sm md:text-base font-mono tracking-widest text-white/60">
        {t("landing.sub")}
      </p>

      <div className="flex flex-wrap items-center justify-center gap-4 mt-4">
        <a href="#" className="bracket-cta text-lime-300">
          {t("landing.play_cta")}
        </a>
        <a href="/create-chrome/" className="bracket-cta text-lime-300">
          {t("landing.create_cta")}
        </a>
        <a href="/parent/" className="bracket-cta text-lime-300">
          {t("landing.parent_cta")}
        </a>
      </div>

      <div className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-4 w-full max-w-4xl">
        {[1, 2, 3].map((i) => (
          <div
            key={i}
            data-glow
            className="border border-white/10 bg-card/40 p-6 font-mono text-xs tracking-widest text-white/50"
          >
            {`// STUB · TILE_${i}`}
          </div>
        ))}
      </div>
    </section>
  );
}
