# CatHealth — bron van waarheid voor coding-agents

Lees dit bestand volledig vóór je aan CatHealth werkt. Deze afspraken gelden
voor iedere AI/coding-agent. `README.md` is de menselijke projectintroductie;
dit bestand beschrijft de actuele architectuur, operationele toestand en
werkwijze.

## Actuele productiestatus

- Appnaam in de UI: **Huisdiergezondheid**.
- Repository: `BevertjeNL/cat-health`.
- Productie: `https://bevertjenl.github.io/cat-health/`.
- Hosting: GitHub Pages vanaf `main`.
- Backend: Neon Postgres + Neon Auth + Neon Data API.
- De actuele productierelease staat in `APP_VERSION` in `index.html` en in de
  nieuwste Git-tag; semantic-release onderhoudt beide automatisch.
- Supabase is volledig uit runtime en CI/CD verwijderd. `supabase/` is alleen
  een historisch auditspoor.

## Wat er gebouwd is

CatHealth is een installable single-file PWA voor meerdere huisdieren. De app
beheert:

- huisdierprofielen, actief huisdier en archivering;
- gewicht en gewichtstrends;
- bloedwaarden, referentiewaarden en OCR/PDF-invoer;
- vaccinaties en herinneringen;
- afwijkingen/symptomen;
- medicatie en medicatiecatalogus;
- dierenartsen en dierenartsbezoeken;
- voersoorten, aankopen, verbruik en kosten;
- dashboardwaarschuwingen, grafieken en rollend-jaar/kalenderjaarstatistiek;
- print/PDF-overzichten en delen als JPEG;
- schema-compleet JSON-gegevensarchief en leesbare Excel-export van alle
  accountgegevens;
- Nederlandse UI-teksten en een gedeeltelijke Engelse en Duitse vertaling.

## Frontendarchitectuur

- `index.html` bevat bewust alle HTML, CSS en applicatie-JavaScript inline.
  Er is geen framework, bundler, `app/`, `components/` of runtime-buildstap.
  Splits dit bestand niet op zonder voorafgaand overleg.
- Interactie gebruikt nog veel globale functies en inline `onclick="..."`.
  Dit is ondersteunde legacyarchitectuur, maar ook technische schuld: het
  bemoeilijkt testen, typecontrole, toetsenbordbediening en een strikte CSP.
  Splits niet breed op zonder overleg; verbeter geraakt gedrag wel lokaal met
  `addEventListener`, kleine pure functies en veilige DOM-API's.
- Neon JS wordt dynamisch geladen als exact gepinde ESM-bundle:
  `@neondatabase/neon-js@0.7.0-beta/+esm`.
- Overige gepinde CDN-globals zijn Chart.js, chartjs-adapter-date-fns,
  chartjs-plugin-zoom, Hammer.js, Tesseract.js, pdf.js, html2canvas en
  ExcelJS 4.4.0.
- CDN-versies altijd exact pinnen. Werk bij een upgrade alle verwijzingen bij,
  inclusief worker-URL's en de Content-Security-Policy.
- De CSP staat als `<meta http-equiv="Content-Security-Policy">` in de head.
  `connect-src` staat alleen de CatHealth Neon Auth- en Data API-hosts toe.
- De huidige `script-src` heeft door inline scripts en handlers nog
  `'unsafe-inline'` nodig. `frame-ancestors` werkt niet in een meta-CSP en
  GitHub Pages biedt geen projectspecifieke CSP-/X-Frame-Options-header.
- CDN-scripts zijn exact gepind, maar hebben nog geen Subresource Integrity.
  Behandel een CSP-aanscherping en SRI als afzonderlijke hardeningwijziging.

## PWA en offline gedrag

- `sw.js` cachet alleen de app-shell en gebruikt network-first. Bij een
  bedoelde clientverversing moet `CACHE_NAME` omhoog. De huidige cache is
  `cat-health-v12`.
- Externe CDN-runtimes worden niet door de serviceworker gecachet. Een koude
  offline start is daardoor niet gegarandeerd; een eerder geladen shell kan
  nog steeds stuklopen wanneer een library niet in de HTTP-cache staat.
- IndexedDB-database `cathealth-offline` (versie 2) heeft stores `cache` en
  `outbox`. Cachekeys en outboxrecords zijn genamespaced met account-ID;
  outboxrecords bevatten daarnaast `petId`, status en retrymetadata.
- Offline writes zijn bewust beperkt tot:
  `weight_measurements`, `blood_values`, `vaccinations`, `symptom_logs`,
  `medications`, `vet_visits` en `food_purchases`.
- `mutateTable()` probeert eerst Neon en queue't alleen netwerkfouten.
  Tijdelijke inserts krijgen negatieve IDs. `flushOutbox()` draait na login,
  bij het `online`-event en elke 30 seconden.
- Inserts in offline-ondersteunde tabellen krijgen een UUID in
  `client_mutation_id`; unieke partiële indexen maken een retry idempotent.
- Niet-netwerkfouten zoals RLS/validatie krijgen status `failed`, blijven op
  het apparaat bewaard en kunnen via Instellingen opnieuw worden geprobeerd.
  Ze worden niet automatisch eindeloos herhaald en niet stil verwijderd.
- Bestaande globale cache/outboxdata uit IndexedDB-versie 1 wordt alleen
  geadopteerd als het huisdier aantoonbaar bij het ingelogde account hoort.
- Er is nog geen fetch-timeout, expliciete updateprompt, Background Sync of
  aanvraag van persistente opslag. Registratiefouten van de serviceworker
  worden momenteel niet zichtbaar aan de gebruiker gemeld.

## Lokale instellingen

- Lokale UI-voorkeuren lopen via `SETTING_DEFINITIONS`, `readSetting()` en
  `writeSetting()` in `index.html`; schrijf nieuwe voorkeuren niet rechtstreeks
  naar `localStorage`.
- Iedere setting heeft een expliciete scope, standaardwaarde en validator.
  `appLang` en `iconStyle` zijn device-scoped, `activePetId` user-scoped en
  `watchMarkers`/`careReminderShownDate` pet-scoped.
- De storagekeys zijn versieerbaar (`cathealth:settings:v1:...`). Voeg bij een
  incompatibele vormwijziging een migratiepad toe en verhoog de versie bewust.
- Settings worden niet naar Neon gesynchroniseerd. De scope bepaalt alleen de
  lokale namespace; devicevoorkeuren en user-/petvoorkeuren blijven dus per
  browserprofiel bestaan.

## Neon-project en publieke endpoints

- Neon-project: `CatHealth` (`square-truth-06822146`).
- Database: `neondb`.
- Primaire branch: `main` (`br-steep-poetry-as5wth2o`).
- Compute/endpoint: `ep-old-union-as8n94jd`, AWS Frankfurt.
- Auth URL:
  `https://ep-old-union-as8n94jd.neonauth.c-4.eu-central-1.aws.neon.tech/neondb/auth`
- Data API URL:
  `https://ep-old-union-as8n94jd.apirest.c-4.eu-central-1.aws.neon.tech/neondb/rest/v1`
- Databasewachtwoord/connectionstring nooit in broncode of gedeelde
  environment variables zetten. Alleen GitHub Actions-secret
  `NEON_DATABASE_URL` mag de Postgres-connectionstring bevatten.

## Volledige gegevensexport

- De kaart **Gegevens exporteren** onder Instellingen biedt JSON en Excel.
  JSON (`cathealth-data-YYYY-MM-DD.json`) is het canonieke, schema-complete en
  provider-onafhankelijke gegevensarchief. Excel
  (`cathealth-data-YYYY-MM-DD.xlsx`) is bedoeld voor lezen en analyseren.
  De app heeft nog geen importfunctie; volledig terugzetten vereist aparte
  importtooling en is geen selfservice-herstelactie.
- `EXPORT_TABLES` en `EXPORT_COLUMNS` in `index.html` zijn de expliciete lijst
  van alle 11 actieve app-tabellen en hun kolommen. Werk beide bij wanneer een
  tabel of kolom wordt toegevoegd. `EXCEL_SHEET_NAMES` bepaalt de stabiele,
  Nederlandstalige werkbladnamen.
- `fetchAllExportRows()` leest per 1000 rijen, zodat een Data API-limiet geen
  stille, onvolledige export veroorzaakt. RLS blijft de eigendomsgrens.
- Voor de export wordt de offline outbox eerst gesynchroniseerd. Als er daarna
  nog wijzigingen wachten, wordt de export geblokkeerd in plaats van als
  volledig aangeboden.
- Het interne exportdocument bevat formaatnaam en `format_version`, exporttijd,
  appversie, account-ID/e-mail, lokale weergavevoorkeuren, rij-aantallen en de
  tabellen. Het bevat geen wachtwoord of private Neon Auth-/migratietabellen.
- `createExcelExport()` bouwt met de exact gepinde ExcelJS-browserbundle een
  werkmap met Arial, vaste kopregels, filters, echte datum-/getaltypen, Info,
  Voorkeuren en één blad per tabel. Foto-data-URL's gaan niet in Excel-cellen
  (die een lengtelimiet hebben), maar worden als afbeeldingen op `Foto's`
  ingesloten; de JSON-export bewaart de originele data-URL exact.
- Het bestand bevat gevoelige medische en contactgegevens. Voeg daarom geen
  automatische externe upload toe zonder expliciet beveiligings- en
  privacybesluit.

## Senior auditbaseline 31-08-2026

De app is bruikbaar voor het huidige kleinschalige productiegebruik en heeft
sterke datafundamenten. Zij voldoet nog niet op ieder onderdeel aan wat van een
modern afgeharde medische PWA wordt verwacht. Onderstaande scores zijn een
technische momentopname, geen certificering.

| Onderdeel | Score | Kernbeeld |
| --- | ---: | --- |
| Beveiliging en privacy | 7/10 | Sterke RLS en veilige contactlinks; brede CSP/DOM- en accountfuncties vragen hardening |
| Datacorrectheid | 8/10 | Constraints, idempotentie, collectiequeries en export zijn volledig gepagineerd |
| Betrouwbaarheid | 7,5/10 | Degelijke outbox en stale-loadbescherming; blijvende syncfouten zijn beperkt beheerbaar |
| Performance en PWA | 6/10 | Eenvoudige shell; zware eager CDN-runtimes en onvolledige koude-offlinedekking |
| Toegankelijkheid | 6,5/10 | Dashboardkern en dialogen zijn keyboardgeschikt; volledige formulieraudit resteert |
| Onderhoudbaarheid | 5,5/10 | Consistente conventies, maar één bestand van ruim 9.000 regels zonder types |
| Tests en operations | 6,5/10 | Tien contracttests draaien in CI; browser-E2E ontbreekt nog |
| **Totaalbeeld** | **7/10** | **Goed en consistent fundament, gericht verder hardenen** |

### Bevestigde sterke punten

- RLS staat op iedere actieve tabel; eigendom loopt consequent via `pets`.
- Offline inserts zijn accountgebonden en idempotent via
  `client_mutation_id`; mislukte writes worden niet stil verwijderd.
- Settings hebben versie, scope, standaardwaarde en validator.
- Async petloads negeren verouderde resultaten via een generatiecontrole.
- Alle collectiequeries en exportreads gebruiken één geteste paginatiehelper;
  export wordt geblokkeerd zolang de outbox niet leeg is.
- Dialogen hebben focus trapping, Escape-afhandeling en focusherstel.
- Dashboardkaarten/-meldingen gebruiken native controls, met focusverplaatsing
  naar het gekozen paneel; alle inklapbare formulierheaders ondersteunen
  Enter en spatie.
- Migraties zijn oplopend en idempotent; browserdependencies zijn exact
  gepind.
- `npm test` en lint zijn beide CI-gates.

### Uitgevoerde hardeningsfase 31-08-2026

- Dierenartscontactlinks worden met gevalideerde `tel:`/`mailto:`-waarden en
  DOM-properties gebouwd; gebruikersdata wordt daar niet meer in
  `innerHTML`-attributen geïnterpoleerd.
- `fetchAllRows()` haalt iedere collectie in stabiel gesorteerde pagina's op.
  Ook huisdieren, catalogi en alle logboeken gebruiken deze helper.
- Dashboardkaarten zijn links, meldingen zijn buttons en dynamische
  jaarselecties hebben een vertaald toegankelijk label.
- De voedingsheader heeft dezelfde ARIA- en keyboardcontracten als de andere
  inklapbare formulieren.
- De regressiesuite controleert deze contracten; `.github/workflows/ci.yml`
  draait `npm test` vóór lint.

### Hoogste technische prioriteiten

1. **Ga door met veilige DOM-opbouw.** Dierenartscontacten zijn hersteld;
   vermijd ook elders user-input in HTML-attributen, `href`, `style` en
   eventhandlertekst. Bouw inline handlers gefaseerd af zodat `'unsafe-inline'`
   uiteindelijk uit `script-src` kan.
2. **Voltooi WCAG 2.2 AA voor kernflows.** Dashboard en inklapbare headers zijn
   hersteld. Controleer nu alle inputs, dynamische foutmeldingen, contrast,
   focusvolgorde, touchdoelen en reduced motion.
3. **Voeg browser-E2E toe.** Unit-/contracttests zijn een CI-gate; automatiseer
   nu auth, RLS/accountscheiding, offline herstart, synchronisatie,
   exportblokkade en keyboardbediening in een echte browser.
4. **Verbeter koude offline start en performance.** Laad OCR, PDF, Excel en
   deelhulpmiddelen pas bij gebruik; bepaal bewust welke CDN-assets offline
   beschikbaar moeten zijn en voeg update-/foutfeedback toe.
5. **Voltooi internationalisatie.** Breng hardcoded Nederlandse tekst,
   maandnamen en datumformattering onder één locale-laag en test ontbrekende
   vertaalsleutels.
6. **Rond account- en privacybeheer af.** Voeg wachtwoordherstel,
   e-mailverificatiebeleid, accountverwijdering en een zichtbare optie voor het
   wissen van lokale medische cachedata toe.

### Architectuurgrenzen voor nieuw werk

- Vertrouw voor collecties nooit impliciet op de server-rowlimit.
- Gebruik `textContent` voor tekst en gevalideerde DOM-properties voor
  attributen; HTML-escaping maakt attribuut- of URL-context niet automatisch
  veilig.
- Bouw klikbare bediening als native `button`/`a`; een `div` met `onclick` is
  geen toegankelijke control.
- Laad zware optionele libraries pas wanneer de functie wordt geopend.
- Voeg lokale voorkeuren uitsluitend via de bestaande settingsregistry toe.
- Houd frontend en schema achterwaarts compatibel: Pages-deployment en
  Neon-migraties worden parallel, niet transactioneel, uitgerold.

## Neon Auth-configuratie en sessies

Actuele Auth-configuratie:

- application name: `CatHealth`;
- sign-up with email: aan;
- verify at sign-up: **uit** — er wordt dus geen bevestigingsmail verstuurd;
- sign-in with email: aan;
- email provider: gedeelde Neon-provider (`auth@mail.myneon.app`);
- trusted domain: `https://bevertjenl.github.io`;
- localhost toegestaan voor ontwikkeling;
- één productieaccount heeft twee gemigreerde huisdieren geclaimd.

De beta-versie van Neon JS kan `SIGNED_IN`/`SIGNED_OUT` later aan de huidige
tab leveren dan de Auth-call resolve't. Belangrijke, bewust dubbele route:

1. `onAuthStateChange(handleAuthStateChange)` verwerkt normale en cross-tab
   events.
2. Een geslaagde `signInWithPassword()`/`signUp()` roept óók direct
   `transitionToSession(data.session)` aan.
3. Een geslaagde `signOut()` roept direct `clearSessionUi()` aan.
4. `transitionToSession()` dedupliceert wanneer hetzelfde account al zichtbaar
   is.

Verwijder deze expliciete UI-overgangen niet. Alleen vertrouwen op
`onAuthStateChange()` veroorzaakt het bekende gedrag waarbij login/logout pas
na een paginaverversing zichtbaar wordt.

## Datamodel en RLS

Actieve app-tabellen in `public`:

| Tabel | Migratiestand 27-08-2026 |
| --- | ---: |
| `pets` | 3 |
| `weight_measurements` | 10 |
| `blood_values` | 95 |
| `vaccinations` | 9 |
| `symptom_logs` | 73 |
| `medications` | 26 |
| `medication_catalog` | 10 |
| `veterinarians` | 2 |
| `vet_visits` | 13 |
| `food_catalog` | 2 |
| `food_purchases` | 22 |
| **Totaal** | **265** |

Eigendom loopt altijd via `pets.user_id = auth.user_id()`. Alle onderliggende
records verwijzen met `pet_id` naar een pet. `veterinarians` is een aparte
contactenlijst; `vet_visits` bevat bezoeklogs en kan met `vet_id` verwijzen.

RLS staat op alle app-tabellen. Clientrollen krijgen alleen de benodigde
rechten; data blijft per ingelogde eigenaar afgeschermd. Gebruik bij nieuwe
tabellen hetzelfde eigendomspatroon en voeg passende indexen, grants en RLS-
policies toe.

## Schema en migraties

- Actief schema: `neon/migrations/0001_initial_schema.sql` en volgende
  oplopend genummerde bestanden.
- Bestaande toegepaste migraties nooit herschrijven om een wijziging door te
  voeren. Voeg `0002_...sql`, `0003_...sql`, enzovoort toe.
- De workflow doorloopt bij iedere relevante push alle migratiebestanden in
  volgorde. Schrijf migraties daarom herhaalbaar/idempotent (`if exists`,
  `if not exists`, guarded `DO`-blocks).
- Geen handmatige productieschemawijzigingen in Neon SQL Editor buiten
  migraties. Read-only diagnosequeries zijn wel toegestaan.
- Na een wijziging aan Data API-zichtbare tabellen/kolommen kan in Neon onder
  Data API `Refresh schema cache` nodig zijn.
- Destructieve migraties (`drop table`, `drop column`, massale rewrite) altijd
  eerst met de gebruiker bespreken en van een rollback/back-up voorzien.

## Supabase-migratie en legacy-accountclaim

- Cutover afgerond op 27 augustus 2026.
- Gecontroleerd resultaat: 265 rijen in 11 tabellen en 2 e-mailmappings.
- Wachtwoorden zijn niet gemigreerd; gebruikers registreren in Neon Auth met
  hetzelfde e-mailadres.
- Private schema `cathealth_migration` bevat `legacy_users`.
- Trigger `cathealth_claim_legacy_pets` op `neon_auth."user"` vervangt bij
  registratie de oude `pets.user_id` door de Neon Auth-user-ID.
- De productieaccountclaim is geslaagd: 2 pets zijn gekoppeld. Eén historische
  testmapping vertegenwoordigt de resterende derde pet.
- De private mappingtabel en trigger zijn niet via de Data API bereikbaar.
  Verwijder ze pas via een afzonderlijke cleanup-migratie nadat expliciet is
  besloten wat met de testpet/mapping gebeurt.
- Het externe Supabase-project mag pauzeren en is geen productieafhankelijkheid.
  Verwijder het project, de GitHub Supabase-secrets of `supabase/` niet zonder
  expliciete opdracht; ze vormen voorlopig rollback/auditmateriaal.

## Versies, commits en releases

- `APP_VERSION` in `index.html` wordt automatisch gezet door
  `scripts/set-app-version.js` tijdens semantic-release. Niet handmatig
  aanpassen.
- Conventional Commits bepalen semver:
  `fix:` = patch, `feat:` = minor, `BREAKING CHANGE:` = major; gebruik verder
  `docs:`, `chore:` en `refactor:` waar passend.
- Werk op een branch, draai lokaal `npm test`, `npm run lint` en
  `git diff --check`, open een PR en merge alleen met groene controles.
- Push naar `main` start `.github/workflows/ci.yml`: tests, lint en daarna
  semantic-release. De releasecommit werkt `CHANGELOG.md`, tag en
  `APP_VERSION` bij en veroorzaakt een tweede GitHub Pages-deployment.
- Een eerste Pages-run kan daardoor worden vervangen/geannuleerd door de
  releasecommit; beoordeel de nieuwste Pages-run, niet automatisch de eerste.
- Wijzigingen in `neon/migrations/**` starten daarnaast
  `.github/workflows/neon-migrations.yml` met secret `NEON_DATABASE_URL`.
- GitHub Actions gebruikt momenteel Node 20 in de workflowconfig; GitHub kan
  daarbij een deprecation-waarschuwing tonen maar forceert Node 24. Dit was
  tijdens de Neon-cutover niet blokkerend.
- `npm audit` rapporteerde op 30-08-2026 kwetsbaarheden in uitsluitend de
  ontwikkel-/releaseketen. Upgrade deze dependencies gecontroleerd en test het
  releasepad; voer geen blinde geforceerde auditfix uit.

## Lokale ontwikkeling en verificatie

```bash
npm ci
npm test
npm run lint
git diff --check
python3 -m http.server 8000
```

Open `http://localhost:8000/`. Test voor Auth- of datastorewijzigingen ten
minste:

1. registreren of inloggen gaat zonder paginaverversing naar het dashboard;
2. uitloggen gaat zonder paginaverversing naar het loginformulier;
3. het juiste account ziet uitsluitend zijn eigen pets;
4. minimaal één read en veilige write via de Data API werkt;
5. offline queue, online herstel en PWA-update blijven intact indien geraakt;
6. de live pagina serveert na release de verwachte `APP_VERSION` en
   `CACHE_NAME`;
7. gewijzigde bediening werkt met toetsenbord, zichtbare focus en correcte
   programmatische labels.

## Veiligheids- en wijzigingsregels

- Bewaar geen wachtwoorden, tokens, connectionstrings of persoonlijke
  accountdetails in broncode, logs of documentatie.
- Nieuwe externe host? Werk de CSP bij.
- Nieuwe CDN-library? Exact pinnen.
- Interpoleer geen gebruikersdata in `href`, `style`, `onclick` of andere
  HTML-attributen. Gebruik gevalideerde DOM-properties; `escapeHtml()` is
  uitsluitend geschikt voor tekstcontext.
- Nieuwe write-route voor een offline-ondersteunde tabel? Gebruik
  `mutateTable()` en werk `OFFLINE_TABLES`/rendering consequent bij.
- Nieuwe database-entiteit? Voeg migratie, indexen, grants, RLS, clientcode en
  relevante offline/cachelogica samen toe.
- Geen brede herstructurering of destructieve dataactie zonder overleg.
