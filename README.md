# CatHealth

Single-file PWA om het gewicht, bloedwaarden, vaccinaties, medicatie,
afwijkingen en dierenartsbezoeken van een huisdier bij te houden. De app
heet in de gebruikersinterface **Huisdiergezondheid**.

## Mappenstructuur

```
.
├── index.html                    Alles: HTML, CSS en JS in één bestand
├── sw.js                         Service worker (PWA-offline app-shell-cache)
├── manifest.json                 PWA-manifest
├── icons/                        App-iconen (192/512/apple-touch)
├── scripts/
│   └── set-app-version.js        Schrijft APP_VERSION in index.html bij een release
├── neon/
│   └── migrations/                Actieve Neon-schema- en RLS-migraties
├── supabase/                       Historisch bron-schema van vóór de Neon-migratie
├── eslint.config.js               Lint-config (ESLint + eslint-plugin-html)
├── .releaserc.json                semantic-release-config
└── .github/workflows/              CI: lint, release en Neon-migraties
```

**Bewust geen `app/`, `components/`, `lib/` of build-stap.** `index.html`
is één bestand met alle HTML, CSS en JS inline — geen framework, geen
bundler. Alleen de gepinde Neon-client wordt met een dynamische `import()`
geladen; de applicatiecode zelf gebruikt geen modules. Interactie loopt via `onclick="..."`-
attributen die rechtstreeks globale functies in het ene `<script>`-blok
aanroepen. Dat is een bewuste keuze (simpele hosting als statisch bestand,
geen build-tooling nodig, makkelijk in de browser te debuggen) en geen
tussenstap richting een grotere herstructurering — zie `CLAUDE.md` voor de
volledige toelichting en de codeer-conventies binnen `index.html`.

Externe libraries (Neon JS, Chart.js, Hammer.js, chartjs-plugin-zoom,
Tesseract.js, pdf.js, html2canvas) komen via een exact gepinde CDN-versie in
`index.html`. Het zijn geen npm-afhankelijkheden — de `devDependencies` in
`package.json` zijn alleen voor lint/release-tooling, niet voor de app zelf.

## Historische Supabase-bestanden

`supabase/` is alleen bewaard als auditspoor van het oude schema en het
historische single-user-naar-multi-user-pad. CI voert deze bestanden niet
meer uit. De gegevensoverdracht naar Neon is afgerond; nieuwe
schemawijzigingen horen in `neon/migrations/`.

## Lokaal draaien

Geen build-stap nodig — `index.html` rechtstreeks openen (of via een
lokale static-file-server) volstaat. Neon Auth staat localhost toe, zodat
Auth en data lokaal hetzelfde werken als op GitHub Pages.

## Meer info

Zie `CLAUDE.md` voor commit-/release-flow, Neon-tabellen en -conventies,
en de reden achter alle bovenstaande keuzes.
