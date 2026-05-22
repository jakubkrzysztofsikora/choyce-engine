import { t } from "@/lib/i18n";

export default function ParentZonePage() {
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
      <div className="border border-white/10 bg-card/40 p-10 text-center font-mono text-sm tracking-widest text-white/60">
        {t("parent.locked")}
      </div>
    </section>
  );
}
