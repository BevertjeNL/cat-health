# CatHealth

CatHealth is een Nederlandstalige, installable single-file PWA voor het
bijhouden van de gezondheid van meerdere huisdieren. In de interface heet de
app **Huisdiergezondheid**.

- Productie: <https://bevertjenl.github.io/cat-health/>
- Repository: `BevertjeNL/cat-health`
- Frontendhosting: GitHub Pages
- Backend: Neon Postgres + Neon Auth + Neon Data API
- Productierelease bij deze overdracht: `1.14.2`

Supabase is geen runtime-afhankelijkheid meer. De map `supabase/` is alleen
een historisch auditspoor van het oude schema.

## Wat de app kan

- Meerdere huisdieren beheren, wisselen, archiveren en herstellen.
- Gewicht, bloedwaarden, vaccinaties, medicatie, afwijkingen,
  dierenartsbezoeken, dierenartsen en voeding vastleggen.
- Trends, herinneringen, kosten en rollend-jaar/kalenderjaarstatistieken tonen.
- Bloedonderzoeken uit afbeeldingen/PDF's verwerken met OCR-hulpmiddelen.
- Een printoverzicht maken en als PDF of JPEG delen.
- Zeven soorten logboekmutaties offline opslaan en later synchroniseren via
  IndexedDB (`weight_measurements`, `blood_values`, `vaccinations`,
  `symptom_logs`, `medications`, `vet_visits`, `food_purchases`).
- Nederlands, Engels en Duits tonen vanuit de inline vertaalcatalogus.

## Architectuur

```text
GitHub Pages
  └─ index.html (HTML + CSS + JavaScript, geen bundler)
       ├─ Neon JS 0.7.0-beta via gepinde ESM-import
       ├─ Neon Auth (e-mail + wachtwoord)
       ├─ Neon Data API (PostgREST-achtige client)
       ├─ IndexedDB-cache en offline outbox
       └─ sw.js (network-first PWA-shell)

Neon
  ├─ Postgres-tabellen en indexen
  ├─ RLS: auth.user_id() → pets.user_id → onderliggende pet_id
  ├─ Neon Auth-tabellen in neon_auth
  └─ private tijdelijke legacy-accountclaim in cathealth_migration
```

`index.html` is bewust één bestand. Er is geen framework, bundler of
applicatie-buildstap. Externe browserlibraries staan exact gepind; npm bevat
alleen ontwikkel- en releasegereedschap.

## Mappenstructuur

```text
.
├── index.html                     Volledige applicatie: HTML, CSS en JS
├── sw.js                          Network-first service worker
├── manifest.json                  PWA-manifest
├── icons/                         PWA-iconen
├── neon/migrations/               Actieve Neon-schema- en RLS-migraties
├── supabase/                      Historisch schema; niet meer actief
├── scripts/set-app-version.js     Zet APP_VERSION tijdens releases
├── eslint.config.js               ESLint voor inline JavaScript
├── .releaserc.json                semantic-release-configuratie
├── .github/workflows/ci.yml       Lint en release
├── .github/workflows/neon-migrations.yml
└── CLAUDE.md                      Technische bron van waarheid voor AI-agents
```

## Lokaal draaien

```bash
npm ci
python3 -m http.server 8000
```

Open daarna <http://localhost:8000/>. Neon Auth accepteert localhost. Voor een
snelle statische controle kan `index.html` ook rechtstreeks worden geopend.

Controle vóór iedere merge:

```bash
npm run lint
git diff --check
```

## Neon en authenticatie

Het Neon-project heet `CatHealth`; database en branch zijn respectievelijk
`neondb` en `main`. De browser bevat alleen publieke Auth- en Data API-URL's.
De Postgres-connectionstring staat uitsluitend in GitHub Actions-secret
`NEON_DATABASE_URL`.

E-mailregistratie en -login staan aan. **E-mailverificatie bij registratie
staat uit**, dus nieuwe gebruikers krijgen geen bevestigingsmail en kunnen
direct inloggen. De bestaande productiegebruiker heeft de twee gemigreerde
huisdieren succesvol geclaimd.

Neon Auth-events kunnen in de gebruikte beta-client vertraagd arriveren.
Daarom verwerkt CatHealth een succesvolle loginresponse en logout expliciet
in de UI via `transitionToSession()` en `clearSessionUi()`. Verwijder deze
logica niet ten gunste van alleen `onAuthStateChange()`.

## Gegevensexport

Onder **Instellingen → Gegevens exporteren** kiest een ingelogde gebruiker uit:

- **JSON**: de volledige, provider-onafhankelijke en herstelbare back-up;
- **Excel (.xlsx)**: een professioneel opgemaakte werkmap met Info,
  Voorkeuren, één werkblad per actieve app-tabel en een apart fotoblad.

Beide exports bevatten alle 11 actieve app-tabellen, alle actieve en
gearchiveerde huisdieren, lokale weergavevoorkeuren, rij-aantallen, exportdatum
en formaatversie. De Excel-export behoudt datums en getallen als echte
Excel-typen en sluit opgeslagen huisdierfoto's als afbeeldingen in. JSON blijft
het canonieke formaat voor volledig en exact herstel.

Queries worden gepagineerd en RLS beperkt de inhoud tot het ingelogde account.
Openstaande offline wijzigingen worden eerst gesynchroniseerd; zolang dat niet
volledig lukt, wordt geen mogelijk onvolledige export aangeboden. De exports
bevatten geen wachtwoord of interne Neon Auth-tabellen en moeten vanwege
medische en contactgegevens veilig worden bewaard.

## Migratiestatus

De Supabase-naar-Neon-overdracht is op 27 augustus 2026 afgerond en
geverifieerd: **265 rijen in 11 tabellen** en **2 legacy-accountmappings**.
De tijdelijke overdrachtsworkflows en het exportscript zijn verwijderd.

Supabase mag pauzeren zonder effect op de productieapp. Het externe
Supabase-project en de historische bestanden blijven voorlopig als
rollback/auditspoor bestaan; verwijder ze niet zonder expliciete opdracht.

## Releases en schemawijzigingen

- Werk op een branch en gebruik Conventional Commits.
- Een groene PR-lint gaat vóór merge naar `main`.
- `main` start semantic-release, werkt `APP_VERSION` en `CHANGELOG.md` bij en
  publiceert GitHub Pages.
- Wijzigingen onder `neon/migrations/` starten de Neon-migratieworkflow.
- Verhoog `CACHE_NAME` in `sw.js` bij elke deploy die geïnstalleerde PWA's
  gedwongen moet verversen.

Lees [CLAUDE.md](./CLAUDE.md) vóór codewijzigingen. Dat bestand bevat de
volledige afspraken, identifiers, datamodellen, migratieregels en bekende
valkuilen voor iedere coding-agent.
