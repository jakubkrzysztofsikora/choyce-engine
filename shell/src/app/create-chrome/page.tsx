import { t } from "@/lib/i18n";

export default function CreateChromePage() {
  return (
    <section className="px-8 py-12">
      <header className="mb-10">
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
      <a href="#" className="bracket-cta text-lime-300">
        {t("create.open_engine_cta")}
      </a>
    </section>
  );
}
