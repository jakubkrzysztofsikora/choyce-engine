# Lokalizacja pl-PL

## Cel
Ten katalog przechowuje domyslne tlumaczenia interfejsu i slowniki terminologii dla silnika Choyce.

## Pliki
- `ui_pl.json` — klucze UI i domyslne teksty po polsku.
- `glossary_kid_pl.json` — slownictwo przyjazne dziecku oraz lista terminow blokowanych.
- `glossary_parent_pl.json` — techniczne terminy dla trybu rodzica.

## Zasady
1. Domyslny jezyk to `pl-PL`.
2. Teksty dla dziecka powinny byc krotkie, proste i bezpieczne.
3. Terminy rodzica powinny byc spojne technicznie (np. moderacja, polityka, publikacja).
4. Kazdy nowy klucz UI dodaj jednoczesnie do `ui_pl.json`.

## Jak dodawac nowe terminy
- Dla trybu dziecka: dodaj mapowanie do `glossary_kid_pl.json` w `preferred_terms`.
- Dla trybu rodzica: dodaj mapowanie do `glossary_parent_pl.json` w `preferred_terms`.
- Dla blokowania tresci: dopisz termin do `unsafe_terms` w `glossary_kid_pl.json`.
