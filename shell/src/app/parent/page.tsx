"use client";

import { useCallback, useEffect, useState } from "react";
import { t } from "@/lib/i18n";

/**
 * Parent zone — PIN-gated controls for parental settings.
 *
 * Storage layout (localStorage, browser-only for MVP):
 *   choyce_parent_pin_sha    — SHA-256 hex digest of "<pin>" salted with
 *                              "choyce-parent-v1". Hashed so the kid
 *                              shoulder-surfing localStorage can't read
 *                              the literal PIN.
 *   choyce_ai_voices         — "true"/"false" (default "false" — COPPA opt-in)
 *   choyce_combat            — "true"/"false" (default "true")
 *   choyce_reduce_motion     — "true"/"false" (default "false")
 *   choyce_daily_quota       — stringified int 0..200 (default 50)
 *
 * Follow-up (tracked in MVP plan): migrate to ~/.choyce/parent.json via
 * Tauri fs API so a power-cycled browser cache can't reset the gate.
 * For now localStorage is acceptable because the Tauri app embeds a
 * single webview profile that survives across launches.
 */
const PIN_SALT = "choyce-parent-v1";

async function sha256Hex(input: string): Promise<string> {
  const enc = new TextEncoder().encode(input);
  const buf = await crypto.subtle.digest("SHA-256", enc);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

type ParentalSettings = {
  aiVoices: boolean;
  combat: boolean;
  reduceMotion: boolean;
  dailyQuota: number;
};

const DEFAULT_SETTINGS: ParentalSettings = {
  aiVoices: false,
  combat: true,
  reduceMotion: false,
  dailyQuota: 50,
};

function loadSettings(): ParentalSettings {
  if (typeof window === "undefined") return DEFAULT_SETTINGS;
  return {
    aiVoices: localStorage.getItem("choyce_ai_voices") === "true",
    combat: localStorage.getItem("choyce_combat") !== "false",
    reduceMotion: localStorage.getItem("choyce_reduce_motion") === "true",
    dailyQuota: Number.parseInt(
      localStorage.getItem("choyce_daily_quota") ?? "50",
      10
    ),
  };
}

function saveSettings(s: ParentalSettings): void {
  if (typeof window === "undefined") return;
  localStorage.setItem("choyce_ai_voices", String(s.aiVoices));
  localStorage.setItem("choyce_combat", String(s.combat));
  localStorage.setItem("choyce_reduce_motion", String(s.reduceMotion));
  localStorage.setItem("choyce_daily_quota", String(s.dailyQuota));
  // Apply reduce-motion immediately so the change is visible without reload.
  document.documentElement.setAttribute(
    "data-reduce-motion",
    s.reduceMotion ? "true" : "false"
  );
}

export default function ParentZonePage() {
  // Mode machine: 'set' (no PIN configured yet), 'locked', 'unlocked'.
  const [mode, setMode] = useState<"loading" | "set" | "locked" | "unlocked">(
    "loading"
  );
  const [pinInput, setPinInput] = useState("");
  const [pinConfirm, setPinConfirm] = useState("");
  const [error, setError] = useState<string>("");
  const [settings, setSettings] = useState<ParentalSettings>(DEFAULT_SETTINGS);
  const [savedNotice, setSavedNotice] = useState(false);

  useEffect(() => {
    if (typeof window === "undefined") return;
    setMode(localStorage.getItem("choyce_parent_pin_sha") ? "locked" : "set");
    setSettings(loadSettings());
  }, []);

  const handleSetPin = useCallback(async () => {
    setError("");
    if (!/^\d{4}$/.test(pinInput)) {
      setError(t("parent.pin_mismatch"));
      return;
    }
    if (pinInput !== pinConfirm) {
      setError(t("parent.pin_mismatch"));
      return;
    }
    const digest = await sha256Hex(PIN_SALT + pinInput);
    localStorage.setItem("choyce_parent_pin_sha", digest);
    setPinInput("");
    setPinConfirm("");
    setMode("unlocked");
  }, [pinInput, pinConfirm]);

  const handleUnlock = useCallback(async () => {
    setError("");
    const stored = localStorage.getItem("choyce_parent_pin_sha") ?? "";
    const digest = await sha256Hex(PIN_SALT + pinInput);
    if (digest === stored) {
      setPinInput("");
      setMode("unlocked");
    } else {
      setError(t("parent.pin_mismatch"));
    }
  }, [pinInput]);

  const handleSave = useCallback(() => {
    saveSettings(settings);
    setSavedNotice(true);
    setTimeout(() => setSavedNotice(false), 1_500);
  }, [settings]);

  const handleLock = useCallback(() => {
    setMode("locked");
    setSavedNotice(false);
  }, []);

  return (
    <section className="px-8 py-12">
      <header className="mb-10">
        <h1
          className="glitch-text text-4xl md:text-6xl font-black tracking-tight neon-lime"
          data-text={t("parent.title")}
        >
          {t("parent.title")}
        </h1>
        <p className="mt-3 font-mono text-xs tracking-widest text-white/50">
          {t("parent.sub")}
        </p>
      </header>

      {mode === "loading" && (
        <div className="font-mono text-xs tracking-widest text-white/40">…</div>
      )}

      {mode === "set" && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void handleSetPin();
          }}
          className="max-w-md border border-white/10 bg-card/40 p-8 space-y-4"
          aria-label={t("parent.set_pin")}
        >
          <div className="font-mono text-xs tracking-widest text-white/70">
            {t("parent.set_pin")}
          </div>
          <input
            type="password"
            inputMode="numeric"
            pattern="\d{4}"
            maxLength={4}
            autoComplete="new-password"
            value={pinInput}
            onChange={(e) => setPinInput(e.target.value.replace(/\D/g, ""))}
            placeholder="••••"
            className="w-full bg-black/60 border border-white/20 px-4 py-2 font-mono text-center tracking-[0.5em] text-lime-300"
            data-testid="parent-pin-new"
          />
          <input
            type="password"
            inputMode="numeric"
            pattern="\d{4}"
            maxLength={4}
            autoComplete="new-password"
            value={pinConfirm}
            onChange={(e) => setPinConfirm(e.target.value.replace(/\D/g, ""))}
            placeholder="••••"
            className="w-full bg-black/60 border border-white/20 px-4 py-2 font-mono text-center tracking-[0.5em] text-lime-300"
            data-testid="parent-pin-confirm"
          />
          {error && (
            <div className="font-mono text-[10px] tracking-widest text-red-400">
              {error}
            </div>
          )}
          <button type="submit" className="bracket-cta text-lime-300">
            {t("parent.save")}
          </button>
        </form>
      )}

      {mode === "locked" && (
        <form
          onSubmit={(e) => {
            e.preventDefault();
            void handleUnlock();
          }}
          className="max-w-md border border-white/10 bg-card/40 p-8 space-y-4"
          aria-label={t("parent.enter_pin")}
        >
          <div className="font-mono text-xs tracking-widest text-white/70">
            {t("parent.enter_pin")}
          </div>
          <input
            type="password"
            inputMode="numeric"
            pattern="\d{4}"
            maxLength={4}
            autoComplete="current-password"
            value={pinInput}
            onChange={(e) => setPinInput(e.target.value.replace(/\D/g, ""))}
            placeholder="••••"
            autoFocus
            className="w-full bg-black/60 border border-white/20 px-4 py-2 font-mono text-center tracking-[0.5em] text-lime-300"
            data-testid="parent-pin-unlock"
          />
          {error && (
            <div className="font-mono text-[10px] tracking-widest text-red-400">
              {error}
            </div>
          )}
          <button type="submit" className="bracket-cta text-lime-300">
            {t("parent.unlock")}
          </button>
        </form>
      )}

      {mode === "unlocked" && (
        <div className="max-w-2xl space-y-6">
          <ToggleRow
            label={t("parent.toggle_ai_voices")}
            value={settings.aiVoices}
            onChange={(v) => setSettings({ ...settings, aiVoices: v })}
            testId="parent-toggle-ai-voices"
          />
          <ToggleRow
            label={t("parent.toggle_combat")}
            value={settings.combat}
            onChange={(v) => setSettings({ ...settings, combat: v })}
            testId="parent-toggle-combat"
          />
          <ToggleRow
            label={t("parent.toggle_reduce_motion")}
            value={settings.reduceMotion}
            onChange={(v) => setSettings({ ...settings, reduceMotion: v })}
            testId="parent-toggle-reduce-motion"
          />
          <div className="border border-white/10 bg-card/40 p-4 space-y-2">
            <label
              htmlFor="daily-quota"
              className="font-mono text-xs tracking-widest text-white/70"
            >
              {t("parent.daily_quota")}: {settings.dailyQuota}
            </label>
            <input
              id="daily-quota"
              type="range"
              min={0}
              max={200}
              step={5}
              value={settings.dailyQuota}
              onChange={(e) =>
                setSettings({
                  ...settings,
                  dailyQuota: Number.parseInt(e.target.value, 10),
                })
              }
              className="w-full accent-lime-400"
              data-testid="parent-daily-quota"
            />
          </div>

          <div className="flex items-center gap-3">
            <button
              type="button"
              onClick={handleSave}
              className="bracket-cta text-lime-300"
              data-testid="parent-save"
            >
              {t("parent.save")}
            </button>
            <button
              type="button"
              onClick={handleLock}
              className="bracket-cta text-white/60"
            >
              {t("parent.lock")}
            </button>
            {savedNotice && (
              <span
                aria-live="polite"
                className="font-mono text-[10px] tracking-widest text-lime-400"
              >
                {t("parent.settings_saved")}
              </span>
            )}
          </div>
        </div>
      )}
    </section>
  );
}

function ToggleRow(props: {
  label: string;
  value: boolean;
  onChange: (v: boolean) => void;
  testId: string;
}) {
  return (
    <label
      className="flex items-center justify-between border border-white/10 bg-card/40 px-4 py-3 cursor-pointer"
      data-testid={props.testId}
    >
      <span className="font-mono text-xs tracking-widest text-white/70">
        {props.label}
      </span>
      <input
        type="checkbox"
        checked={props.value}
        onChange={(e) => props.onChange(e.target.checked)}
        className="w-5 h-5 accent-lime-400"
      />
    </label>
  );
}
