# CatHealth

Single-file PWA om het gewicht, bloedwaarden, vaccinaties, medicatie,
afwijkingen en dierenartsbezoeken van een huisdier bij te houden.

## Mappenstructuur

```
.
├── index.html                    Alles: HTML, CSS en JS in één bestand
├── sw.js                         Service worker (PWA-offline app-shell-cache)
├── manifest.json                 PWA-manifest
├── icons/                        App-iconen (192/512/apple-touch)
├── scripts/
│   └── set-app-version.js        Schrijft APP_VERSION in index.html bij een release
├── supabase/
│   ├── config.toml                Supabase-projectconfig
│   ├── migrations/                 Actieve, chronologische schema-migraties
│   └── migrations_archive/         Historische migratie (niet actief, zie hieronder)
├── eslint.config.js               Lint-config (ESLint + eslint-plugin-html)
├── .releaserc.json                semantic-release-config
└── .github/workflows/              CI: lint, release, Supabase-migraties
```

**Bewust geen `app/`, `components/`, `lib/` of build-stap.** `index.html`
is één bestand met alle HTML, CSS en JS inline — geen framework, geen
bundler, geen `import`/`export`. Interactie loopt via `onclick="..."`-
attributen die rechtstreeks globale functies in het ene `<script>`-blok
aanroepen. Dat is een bewuste keuze (simpele hosting als statisch bestand,
geen build-tooling nodig, makkelijk in de browser te debuggen) en geen
tussenstap richting een grotere herstructurering — zie `CLAUDE.md` voor de
volledige toelichting en de codeer-conventies binnen `index.html`.

Externe libraries (Supabase JS, Chart.js, Hammer.js, chartjs-plugin-zoom,
Tesseract.js, pdf.js, html2canvas) komen via CDN `<script>`-tags in
`index.html` en zijn dus globals (`supabase`, `Chart`, `Hammer`, etc.),
geen npm-afhankelijkheden — de `devDependencies` in `package.json` zijn
alleen voor lint/release-tooling, niet voor de app zelf.

## `supabase/migrations_archive/`

`migration_multiuser.sql` staat hier omdat het een historisch, eenmalig
upgrade-pad beschrijft (van een oude single-user-install naar multi-user)
dat niet in de actieve migratieketen zit en niet door CI wordt uitgevoerd.
`supabase/migrations/0001_initial_schema.sql` bevat het volledige, actuele
schema en dekt dat pad al. Zie `CLAUDE.md` voor details.

## Lokaal draaien

Geen build-stap nodig — `index.html` rechtstreeks openen (of via een
lokale static-file-server) volstaat. Zonder een geldige Supabase-config
toont de app een configuratiemelding in plaats van in te loggen; met een
Supabase-project ingesteld werkt de volledige app (Auth + data) lokaal
hetzelfde als in productie.

## Meer info

Zie `CLAUDE.md` voor commit-/release-flow, Supabase-tabellen en -conventies,
en de reden achter alle bovenstaande keuzes.
