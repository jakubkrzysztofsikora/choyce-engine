import Link from "next/link";
import { t } from "@/lib/i18n";

/**
 * Library page — kid-friendly grid of the bundled template packs.
 * Mirrors the JSON files under data/templates/ and the two W3 packs
 * with `default_goal` wired (adventure + obby) get a "✨ gotowa gra"
 * badge so the kid sees they're playable end-to-end.
 *
 * A follow-up will fetch saved kid-authored worlds from the engine
 * via the Tauri bridge; for now the catalog is the visible surface.
 */
type Template = {
  id: string;
  label_pl: string;
  description_pl: string;
  emoji: string;
  gradient: string;
  ring: string;
  playableMVP: boolean;
};

const TEMPLATES: ReadonlyArray<Template> = [
  {
    id: "adventure",
    label_pl: "Wyspa Skarbów",
    description_pl: "Zbierz 3 klucze i znajdź wyjście.",
    emoji: "🏝️",
    gradient: "from-emerald-400 to-cyan-500",
    ring: "ring-emerald-200",
    playableMVP: true,
  },
  {
    id: "obby",
    label_pl: "Tor Przeszkód",
    description_pl: "Skacz, omijaj lawę, dotrzyj do mety.",
    emoji: "🏁",
    gradient: "from-pink-400 to-rose-500",
    ring: "ring-pink-200",
    playableMVP: true,
  },
  {
    id: "farm",
    label_pl: "Mała Farma",
    description_pl: "Sadź, podlewaj, zbieraj plony.",
    emoji: "🌱",
    gradient: "from-lime-400 to-green-500",
    ring: "ring-lime-200",
    playableMVP: false,
  },
  {
    id: "city",
    label_pl: "Miasto Przygód",
    description_pl: "Pomagaj NPC. Rozwiązuj zadania.",
    emoji: "🏙️",
    gradient: "from-sky-400 to-blue-500",
    ring: "ring-sky-200",
    playableMVP: false,
  },
  {
    id: "tycoon",
    label_pl: "Fabryka Marzeń",
    description_pl: "Buduj, ulepszaj, rośnij.",
    emoji: "🏭",
    gradient: "from-violet-400 to-fuchsia-500",
    ring: "ring-violet-200",
    playableMVP: false,
  },
];

export default function LibraryPage() {
  return (
    <section className="min-h-screen bg-gradient-to-b from-sky-100 via-rose-50 to-amber-50 px-6 py-10">
      <header className="mx-auto mb-10 max-w-6xl text-center">
        <h1 className="text-4xl font-extrabold tracking-tight text-slate-800 md:text-5xl">
          {t("library.kid_title")}
        </h1>
        <p className="mt-2 text-lg text-slate-600">{t("library.kid_sub")}</p>
      </header>

      <div className="mx-auto grid w-full max-w-6xl grid-cols-1 gap-6 md:grid-cols-2 lg:grid-cols-3">
        {TEMPLATES.map((tpl) => (
          <article
            key={tpl.id}
            data-testid={`library-card-${tpl.id}`}
            className={`group relative flex flex-col gap-4 rounded-3xl bg-gradient-to-br ${tpl.gradient} p-6 shadow-lg ring-2 ${tpl.ring} transition-transform hover:-translate-y-1 hover:shadow-2xl`}
          >
            {tpl.playableMVP && (
              <span className="absolute right-4 top-4 rounded-full bg-white/90 px-3 py-1 text-[11px] font-bold text-slate-700 shadow-sm">
                ✨ gotowa gra
              </span>
            )}
            <div
              aria-hidden="true"
              className="text-6xl drop-shadow-md transition-transform group-hover:scale-110"
            >
              {tpl.emoji}
            </div>
            <h2 className="text-2xl font-extrabold tracking-tight text-white drop-shadow-sm">
              {tpl.label_pl}
            </h2>
            <p className="text-sm font-medium text-white/90">
              {tpl.description_pl}
            </p>
            <div className="mt-auto flex gap-2 pt-2">
              <Link
                href={`/create-chrome?world=${tpl.id}&autoplay=1`}
                className="flex-1 rounded-full bg-white px-4 py-2 text-center text-sm font-bold text-slate-800 shadow-sm transition-colors hover:bg-amber-100"
              >
                ▶ {t("library.kid_play_cta")}
              </Link>
              <Link
                href={`/create-chrome?world=${tpl.id}`}
                className="rounded-full bg-white/30 px-4 py-2 text-center text-sm font-bold text-white backdrop-blur-sm transition-colors hover:bg-white/40"
              >
                ✎ {t("library.kid_edit_cta")}
              </Link>
            </div>
          </article>
        ))}
      </div>

      <div className="mt-12 text-center">
        <Link
          href="/create-chrome"
          className="inline-block rounded-full bg-emerald-500 px-8 py-3 text-base font-bold text-white shadow-md transition-transform hover:-translate-y-0.5 hover:bg-emerald-600 hover:shadow-lg"
        >
          + {t("library.kid_new_cta")}
        </Link>
      </div>
    </section>
  );
}
