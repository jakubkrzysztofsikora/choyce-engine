"use client";

import { useEffect, useState } from "react";
import { GodotBridge, type BridgeStatus } from "@/lib/godot-bridge";
import { t } from "@/lib/i18n";

type CardProps = {
  href: string;
  emoji: string;
  title: string;
  sub: string;
  gradient: string;
  ring: string;
};

function HeroCard({ href, emoji, title, sub, gradient, ring }: CardProps) {
  return (
    <a
      href={href}
      className={`group relative flex flex-col items-center justify-center gap-4 rounded-3xl ${gradient} p-8 shadow-lg ring-2 ${ring} transition-transform hover:-translate-y-1 hover:shadow-2xl focus-visible:-translate-y-1 focus-visible:outline-none`}
    >
      <div
        aria-hidden="true"
        className="text-7xl drop-shadow-md transition-transform group-hover:scale-110"
      >
        {emoji}
      </div>
      <div className="text-3xl font-extrabold tracking-tight text-white drop-shadow-sm">
        {title}
      </div>
      <div className="max-w-[18ch] text-center text-base font-medium text-white/90">
        {sub}
      </div>
    </a>
  );
}

export default function LandingPage() {
  const [status, setStatus] = useState<BridgeStatus>("idle");

  useEffect(() => {
    const bridge = new GodotBridge();
    const off = bridge.on("status", (s) => setStatus(s));
    bridge.connect().catch(() => {
      /* engine not running yet — CTAs spawn sidecar lazily */
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
    <section className="relative min-h-screen overflow-hidden bg-gradient-to-b from-sky-200 via-sky-100 to-amber-50 px-6 py-10">
      {/* engine status pill — small, non-intrusive */}
      <div className="absolute right-6 top-6 rounded-full bg-white/60 px-3 py-1 text-[10px] font-mono uppercase tracking-widest text-slate-600 backdrop-blur-sm">
        {engineLabel}
      </div>

      {/* hello banner */}
      <div className="mx-auto flex max-w-5xl flex-col items-center gap-3 pt-8 text-center">
        <div className="text-4xl">👋</div>
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-800 md:text-6xl">
          {t("landing.kid_hello")}
        </h1>
      </div>

      {/* 3 hero cards: Buduj / Graj / Rodzic */}
      <div className="mx-auto mt-12 grid w-full max-w-5xl grid-cols-1 gap-6 md:grid-cols-3">
        <HeroCard
          href="/create-chrome/"
          emoji="🧱"
          title={t("landing.kid_card_build_title")}
          sub={t("landing.kid_card_build_sub")}
          gradient="bg-gradient-to-br from-emerald-400 to-teal-500"
          ring="ring-emerald-200"
        />
        <HeroCard
          href="/library/"
          emoji="🎮"
          title={t("landing.kid_card_play_title")}
          sub={t("landing.kid_card_play_sub")}
          gradient="bg-gradient-to-br from-amber-400 to-orange-500"
          ring="ring-amber-200"
        />
        <HeroCard
          href="/parent/"
          emoji="🛡️"
          title={t("landing.kid_card_parent_title")}
          sub={t("landing.kid_card_parent_sub")}
          gradient="bg-gradient-to-br from-indigo-500 to-violet-600"
          ring="ring-indigo-200"
        />
      </div>
    </section>
  );
}
