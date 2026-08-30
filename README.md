# CatHealth

CatHealth is een installeerbare webapp voor het bijhouden van de gezondheid
van meerdere huisdieren. In de interface heet de app
**Huisdiergezondheid**.

- Productie: <https://bevertjenl.github.io/cat-health/>
- Repository: `BevertjeNL/cat-health`
- Frontend: GitHub Pages
- Backend: Neon Postgres, Neon Auth en Neon Data API
- Actuele release: zie `APP_VERSION` in `index.html` of de nieuwste Git-tag

Supabase is geen runtime-afhankelijkheid meer. De map `supabase/` is alleen
een historisch audit- en rollbackspoor van het oude schema.

## Wat de app kan

- Meerdere huisdieren beheren, wisselen, archiveren en herstellen.
- Gewicht, bloedwaarden, vaccinaties, medicatie, afwijkingen,
  dierenartsbezoeken, dierenartsen en voeding vastleggen.
- Trends, herinneringen, kosten en rollend-jaar/kalenderjaarstatistieken tonen.
- Bloedonderzoeken uit afbeeldingen en PDF's verwerken met OCR-hulpmiddelen.
- Een printoverzicht maken en als PDF of JPEG delen.
- Zeven soorten logboekmutaties offline bewaren en later synchroniseren.
- Alle accountdata exporteren als JSON of als leesbare Excel-werkmap.
- Nederlandse UI en een gedeeltelijke Engelse en Duitse vertaling tonen.

De JSON-export is een volledig, provider-onafhankelijk gegevensarchief. De app
heeft nog geen importfunctie; terugzetten vereist daarom momenteel aparte
importtooling en is geen herstelactie met één klik.

## Architectuur

```text
GitHub Pages
  └─ index.html (HTML + CSS + JavaScript, geen bundler)
       ├─ exact gepinde browserlibraries via jsDelivr
       ├─ Neon Auth en Neon Data API
       ├─ versie- en scopebewuste lokale settings
       ├─ accountgebonden IndexedDB-cache en offline outbox
       └─ sw.js (network-first lokale app-shell)

Neon
  ├─ Postgres-tabellen, constraints en indexen
  ├─ RLS: auth.user_id() → pets.user_id → onderliggende pet_id
  ├─ idempotente offline inserts via client_mutation_id
  └─ private legacy-accountclaim in cathealth_migration
```

`index.html` is bewust één bestand zonder framework, bundler of
runtime-buildstap. Die keuze houdt deployment eenvoudig, maar maakt centrale
statehelpers, regressietests en terughoudend gebruik van globale functies extra
belangrijk.

## Kwaliteitsstatus

De app is geschikt voor het huidige kleinschalige productiegebruik, maar is
nog niet op ieder onderdeel modern afgehard. De review van 31 augustus 2026
gebruikt WCAG 2.2, actuele PWA-principes en OWASP-CSP-richtlijnen als
referentiekader.

Sterke fundamenten:

- RLS op alle actieve tabellen en geen databasegeheimen in de browser;
- accountgebonden en idempotente offline synchronisatie;
- herstelbare syncfouten in plaats van stil gegevensverlies;
- gevalideerde settings met expliciete device-, user- en pet-scope;
- databaseconstraints voor belangrijke domeinwaarden;
- gedeelde paginatie voor alle collectiequeries en de volledige export;
- semantic-release, Git-tags en geautomatiseerde Neon-migraties;
- contracttests als CI-gate, lint en een handmatig geverifieerde
  browser-smoketest;
- native toetsenbordnavigatie voor dashboardkaarten en -meldingen.

Belangrijkste resterende grenzen:

- `index.html` telt ruim 9.000 regels en gebruikt veel globale functies,
  `innerHTML` en 116 inline eventhandlers. Dat beperkt typeveiligheid,
  testbaarheid en een strikte Content Security Policy.
- De belangrijkste dashboardbediening is toetsenbordtoegankelijk gemaakt,
  maar een volledige WCAG 2.2 AA-audit van alle formulieren is niet afgerond.
- De Engelse en Duitse vertaling is onvolledig; diverse labels, meldingen en
  datum-/maandnotaties blijven Nederlands.
- De serviceworker cachet alleen lokale shellbestanden. Zware CDN-libraries
  voor grafieken, OCR, PDF en Excel zijn niet gegarandeerd beschikbaar bij een
  koude offline start en worden grotendeels direct geladen.
- De regressietests dekken settings, sync, paginatie, veilige contactlinks en
  belangrijke toegankelijkheidscontracten. Volledige browser-, authenticatie-,
  RLS- en offline end-to-endtests ontbreken nog.
- Wachtwoordherstel, e-mailverificatie, accountverwijdering, back-upimport en
  beheer van lokale medische cachedata ontbreken nog.
- De npm-afhankelijkheden zijn alleen ontwikkel-/releasegereedschap, maar
  `npm audit` is momenteel niet schoon. Beoordeel upgrades apart; dit zijn
  geen browser-runtimepackages.

Zie [het stabiliteitsplan](./docs/STABILITY_BUILD_PLAN.md) en de
audit-/wijzigingsregels in [CLAUDE.md](./CLAUDE.md) voor prioriteiten.

## Mappenstructuur

```text
.
├── index.html                     Volledige applicatie: HTML, CSS en JS
├── sw.js                          Network-first serviceworker
├── manifest.json                  PWA-manifest
├── icons/                         PWA-iconen
├── neon/migrations/               Actieve Neon-schema- en RLS-migraties
├── supabase/                      Historisch schema; niet meer actief
├── tests/                         Node-contract- en regressietests
├── docs/                          Architectuur- en bouwplannen
├── scripts/set-app-version.js     Zet APP_VERSION tijdens releases
├── eslint.config.js               ESLint voor inline JavaScript
├── .github/workflows/             CI, release en Neon-migraties
└── CLAUDE.md                      Technische bron van waarheid
```

## Lokaal draaien

```bash
npm ci
python3 -m http.server 8000
```

Open daarna <http://localhost:8000/>. Neon Auth accepteert localhost. Open de
app niet via `file://`: die origin is niet vertrouwd voor login en bootst de
PWA/serviceworkeromgeving niet correct na.

## Verificatie

Voer vóór iedere merge minimaal uit:

```bash
npm test
npm run lint
git diff --check
```

Controleer bij wijzigingen aan auth, dataopslag of PWA-gedrag daarnaast
handmatig:

1. login en logout zonder paginaverversing;
2. accountscheiding en het juiste actieve huisdier;
3. online read/write via de Data API;
4. offline invoer, herstart, herstel en retry van syncfouten;
5. de nieuwste productieversie en serviceworkercache;
6. keyboardbediening en zichtbare focus van gewijzigde interacties.

## Gegevens, privacy en beveiliging

De app verwerkt medische, financiële en contactgegevens. Exports en lokale
IndexedDB-cache moeten daarom als gevoelige gegevens worden behandeld.

- De browser bevat alleen publieke Auth- en Data API-URL's.
- De Postgres-connectionstring staat uitsluitend in GitHub Actions-secret
  `NEON_DATABASE_URL`.
- RLS beperkt reads en writes tot huisdieren van het ingelogde account.
- Offline records blijven accountgebonden op het apparaat staan, ook na
  logout, totdat ze zijn gesynchroniseerd of lokale sitegegevens worden
  gewist.
- E-mailverificatie bij registratie staat momenteel uit.
- De CSP beperkt hosts, maar `unsafe-inline` blijft nodig door inline handlers.
  `frame-ancestors` in een meta-CSP wordt door browsers genegeerd; GitHub Pages
  levert hiervoor geen projectspecifieke responseheader.

## Releases en schemawijzigingen

- Werk op een branch en gebruik Conventional Commits.
- Open een PR en merge alleen na de afgesproken controles.
- `main` start semantic-release en publiceert GitHub Pages.
- Wijzigingen onder `neon/migrations/` starten de Neon-migratieworkflow.
- Frontenddeployment en databasemigratie zijn niet georkestreerd. Nieuwe code
  moet daarom compatibel blijven tijdens de overgang waarin oud en nieuw
  schema kort naast elkaar bestaan.
- Verhoog `CACHE_NAME` in `sw.js` bij een bedoelde PWA-shellverversing.

## Referentiekader

- [WCAG 2.2](https://www.w3.org/TR/WCAG22/)
- [OWASP Content Security Policy Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Content_Security_Policy_Cheat_Sheet.html)
- [web.dev: PWA assets en data](https://web.dev/learn/pwa/assets-and-data)
- [web.dev: offline data](https://web.dev/learn/pwa/offline-data/)

Lees [CLAUDE.md](./CLAUDE.md) volledig vóór codewijzigingen. Dat bestand is de
technische bron van waarheid voor alle coding-agents.
