import { t } from "@/lib/i18n";

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
      <div className="border border-dashed border-white/15 p-12 text-center font-mono text-sm tracking-widest text-white/40">
        {t("library.empty")}
      </div>
    </section>
  );
}
