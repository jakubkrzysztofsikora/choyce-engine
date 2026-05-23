import type { Metadata } from "next";
import Link from "next/link";
import Script from "next/script";
import { LOCALE, t } from "@/lib/i18n";
import "./globals.css";

export const metadata: Metadata = {
  title: "CHOYCE ENGINE",
  description: "Kid-safe Polish-language game engine — landing/library/parent/create chrome.",
};

// Runs before hydration so the runtime override (set by the parent zone)
// applies on first paint and there's no flash of full-motion content.
// localStorage key: `choyce_reduce_motion` ("true"/"false").
const REDUCE_MOTION_INIT = `
(function(){try{
  var f=localStorage.getItem('choyce_reduce_motion');
  if(f==='true'){document.documentElement.setAttribute('data-reduce-motion','true');}
}catch(e){}})();
`;

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang={LOCALE} className="dark">
      <head>
        <Script id="choyce-reduce-motion-init" strategy="beforeInteractive">
          {REDUCE_MOTION_INIT}
        </Script>
      </head>
      <body className="bg-black text-foreground antialiased scanlines">
        <div className="min-h-screen flex flex-col">
          <header className="border-b border-white/10 px-8 py-4 flex items-center justify-between">
            <Link href="/" className="font-mono text-lg tracking-widest neon-lime">
              {t("app.name")}
            </Link>
            <nav className="flex gap-4 text-xs font-mono tracking-widest text-white/70">
              <Link href="/library" className="hover:text-lime-400">{t("nav.library")}</Link>
              <Link href="/parent" className="hover:text-lime-400">{t("nav.parent")}</Link>
              <Link href="/create-chrome" className="hover:text-lime-400">{t("nav.create")}</Link>
            </nav>
          </header>
          <main className="flex-1">{children}</main>
          <footer className="border-t border-white/10 px-8 py-3 text-[10px] font-mono tracking-widest text-white/40">
            {`// ${t("app.tagline")} // pl-PL //`}
          </footer>
        </div>
      </body>
    </html>
  );
}
