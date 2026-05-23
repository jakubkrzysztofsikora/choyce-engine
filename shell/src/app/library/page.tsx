import Link from "next/link";
import { t } from "@/lib/i18n";

/**
 * Library page — lists the bundled starter templates the kid can pick
 * from. For MVP the source-of-truth is the static list below, mirroring
 * the five JSON files under data/templates/. A follow-up will fetch the
 * actual list from the engine via a bridge `list_worlds` cmd so saved
 * kid worlds show up too.
 */
const TEMPLATES: ReadonlyArray<{
  id: string;
  label_pl: string;
  game_type: "PLATFORMER" | "BUILDER" | "ADVENTURE" | "TYCOON";
  description_pl: string;
}> = [
  {
    id: "adventure",
    label_pl: "WYSPA SKARBÓW",
    game_type: "PLATFORMER",
    description_pl: "Skacz, zbieraj, znajdź wyjście.",
  },
  {
    id: "farm",
    label_pl: "MAŁA FARMA",
    game_type: "ADVENTURE",
    description_pl: "Sadź, podlewaj, zbieraj.",
  },
  {
    id: "city",
    label_pl: "MIASTO PRZYGÓD",
    game_type: "ADVENTURE",
    description_pl: "Pomagaj NPC. Rozwiązuj zadania.",
  },
  {
    id: "obby",
    label_pl: "TOR PRZESZKÓD",
    game_type: "PLATFORMER",
    description_pl: "Skok. Sprężyna. Meta.",
  },
  {
    id: "tycoon",
    label_pl: "FABRYKA MARZEŃ",
    game_type: "TYCOON",
    description_pl: "Buduj, ulepszaj, rośnij.",
  },
];

export default function LibraryPage() {
  return (
    <section className="px-8 py-12">
      <header className="mb-10">
        <h1
          className="glitch-text text-4xl md:text-6xl font-black tracking-tight neon-lime"
          data-text={t("library.title")}
        >
          {t("library.title")}
        </h1>
        <p className="mt-3 font-mono text-xs tracking-widest text-white/50">
          {t("library.sub")}
        </p>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {TEMPLATES.map((tpl) => (
          <article
            key={tpl.id}
            data-glow
            data-testid={`library-card-${tpl.id}`}
            className="border border-white/10 bg-card/40 p-6 flex flex-col gap-3"
          >
            <header className="flex items-baseline justify-between">
              <h2 className="font-mono text-sm tracking-widest neon-lime">
                {tpl.label_pl}
              </h2>
              <span className="font-mono text-[10px] tracking-[0.4em] text-white/40">
                {tpl.game_type}
              </span>
            </header>
            <p className="font-mono text-xs tracking-wider text-white/60">
              {tpl.description_pl}
            </p>
            <Link
              href={`/create-chrome?world=${tpl.id}`}
              className="bracket-cta text-lime-300 mt-auto self-start"
            >
              {t("library.open_cta")}
            </Link>
          </article>
        ))}
      </div>

      <div className="mt-10 text-center">
        <Link href="/create-chrome" className="bracket-cta text-lime-300">
          {t("library.empty_cta")}
        </Link>
      </div>
    </section>
  );
}
