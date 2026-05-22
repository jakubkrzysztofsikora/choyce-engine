/**
 * Minimal pl-PL i18n surface. Real next-intl wiring lands in a follow-up PR
 * once the routing model (App Router vs static export) is settled.
 *
 * Default + only locale for now: `pl-PL`. Keys mirror src/messages/pl.json.
 */
import messages from "@/messages/pl.json";

type Messages = typeof messages;
type DotPaths<T, P extends string = ""> = {
  [K in keyof T & string]: T[K] extends Record<string, unknown>
    ? DotPaths<T[K], `${P}${K}.`>
    : `${P}${K}`;
}[keyof T & string];

export type MessageKey = DotPaths<Messages>;

export const LOCALE = "pl-PL" as const;

export function t(key: MessageKey): string {
  const parts = key.split(".");
  let cursor: unknown = messages;
  for (const p of parts) {
    if (cursor && typeof cursor === "object" && p in (cursor as Record<string, unknown>)) {
      cursor = (cursor as Record<string, unknown>)[p];
    } else {
      return key;
    }
  }
  return typeof cursor === "string" ? cursor : key;
}
