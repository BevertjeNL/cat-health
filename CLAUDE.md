# CatHealth

## Wat dit is
Single-file PWA om het gewicht, bloedwaarden, vaccinaties, medicatie,
afwijkingen en dierenartsbezoeken van een huisdier bij te houden.
- `index.html` — alles inline: HTML, CSS en JS in één bestand. Bewuste
  keuze, geen build-stap. Externe libraries komen via CDN `<script>`-tags
  (Supabase JS, Chart.js, Hammer.js, chartjs-plugin-zoom, Tesseract.js,
  pdf.js) — dit zijn globals (`supabase`, `Chart`, `Hammer`, `Tesseract`,
  `pdfjsLib`), geen npm-afhankelijkheden. **CDN-versies staan altijd exact
  gepind** (bv. `chart.js@4.5.1`, nooit `@4`) — voorkomt dat een nieuwe
  release van een CDN-pakket stilzwijgend meegetrokken wordt. Bij bijwerken:
  nieuwe exacte versie opzoeken (`npm view <pakket> version`) en zowel de
  `<script src>` als eventuele losse verwijzingen (bv. `pdfjsLib.GlobalWorkerOptions.workerSrc`)
  aanpassen.
- **Content-Security-Policy** staat als `<meta http-equiv>` in de `<head>`.
  `script-src`/`style-src` bevatten noodgedwongen `'unsafe-inline'` omdat de
  app overal `onclick="..."`-attributen en template-gegenereerde
  `style="..."`-attributen gebruikt (zie hierboven, geen build-stap) — de
  overige directives (welke hosts mogen laden, geen framing, geen plugins,
  `connect-src` beperkt tot het eigen Supabase-project) staan wél strak.
  Nieuwe externe host toevoegen (nieuwe CDN, ander Supabase-project)? Ook de
  CSP bijwerken, anders wordt die stilzwijgend geblokkeerd.
- `sw.js` — service worker voor PWA-offline-gebruik. Network-first voor
  app-shell assets. `CACHE_NAME` ophogen bij elke deploy die je op een
  geïnstalleerde PWA wilt forceren te verversen.
- `manifest.json` — PWA-manifest.
- Backend: Supabase (Auth met e-mail/wachtwoord + Postgres met RLS).
- Hosting: **onbekend/niet door Claude geverifieerd.** Als je een gehoste
  URL gebruikt (bv. Vercel), controleer zelf of die aan deze GitHub-repo/
  branch hangt — dit is niet iets wat Claude namens jou instelt of kan
  bevestigen.

## Versienummer
`APP_VERSION` in `index.html` (getoond onderaan het Account-kaartje in
Instellingen) wordt na de eerste release automatisch bijgewerkt door
semantic-release via `scripts/set-app-version.js` — nooit handmatig
aanpassen zodra er releases lopen. Tot de eerste release bevat het nog een
handmatige datum-string; zie punt hieronder over het semver-gedrag.

**Bekend gedrag, geen bug:** de eerste semantic-release-run begint bij
`v1.0.0`, ook al stond er al een oudere handmatige versie-string. Oudere
nummers blijven alleen als historische tekst in commit-logs/CHANGELOG staan.

## Commit- en release-flow
- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:` —
  bepaalt automatisch de volgende semver-bump (feat = minor, fix = patch,
  `BREAKING CHANGE:` in de body = major).
- Werk op een branch, laat lokaal `npm run lint` slagen, merge daarna zelf
  door naar `main` — ook bij schema/RLS-migraties, zonder daar per keer
  vooraf los toestemming voor te vragen. `main` triggert automatisch de
  release-job (semantic-release: versiebump, CHANGELOG, git-tag, GitHub
  release) en, bij wijzigingen in `supabase/migrations/**`, de migratie-
  workflow tegen de live database.
- Uitzondering die wél eerst overleg verdient: iets dat data onomkeerbaar
  kan laten verliezen (bv. een `drop table`/`drop column` migratie) of een
  grote herstructurering (bv. index.html opsplitsen in meerdere bestanden).
  Een nieuwe tabel/kolom toevoegen is geen reden om te wachten.

## Branch protection — bekende beperking
Op `main` staat (of hoort te staan) een **klassieke** branch protection rule
(niet de nieuwere "Ruleset"-functie — die vereist een betaald Team/
Enterprise-account voor privé-repo's): branch pattern `main`, "Require
status checks to pass before merging" aan met check `lint`. "Require a
pull request before merging" staat bewust **uit** — anders zou de directe
push van de semantic-release-bot naar `main` geblokkeerd worden.
Op een gratis privé-repo toont GitHub de rule als "Not enforced" — de regel
staat er, maar wordt technisch niet afgedwongen. Dit wordt gecompenseerd
door eigen discipline: nooit mergen met een rode `lint`-check.

## Secrets
Nooit als environment variable van een gedeelde Claude Code cloud-omgeving
zetten (zichtbaar voor iedereen die de omgeving gebruikt) — altijd als
GitHub Actions secret (Settings → Secrets and variables → Actions).

## Supabase
- Project-ref: **nog niet ingevuld** in `supabase/config.toml`
  (`project_id = ""`) — vul dit zelf in.
- Check of dit Supabase-project gedeeld wordt met een andere app van
  dezelfde gebruiker (gratis account = max. 2 projecten). Zo ja: RLS
  isoleert per gebruiker (`auth.uid() = user_id`), niet per app — zorg dat
  tabelnamen tussen apps uniek blijven.
- Tabellen van déze app: `pets`, `weight_measurements`, `blood_values`,
  `vaccinations`, `symptom_logs`, `medications`, `medication_catalog`,
  `vet_visits`, `veterinarians`. Alle rijen scopen via `pet_id` →
  `pets.user_id = auth.uid()`. `veterinarians` is een losse contactenlijst
  (naam, telefoon, e-mail, adres, notities, hoofddierenarts-vlag) — niet te
  verwarren met `vet_visits`, dat alleen bezoek-logs bijhoudt.
- Schema staat als migraties in `supabase/migrations/`
  (`0001_initial_schema.sql` + volgende genummerde bestanden) — geen
  handmatige wijzigingen via de Supabase SQL-editor meer buiten migraties
  om. Nieuwe schema-wijzigingen: nieuw bestand
  `supabase/migrations/000N_....sql` toevoegen, bestaande nummers niet meer
  aanpassen.
- `supabase/migrations_archive/migration_multiuser.sql` is **historisch**,
  zit niet in de actieve migratieketen en wordt niet door CI uitgevoerd —
  het beschrijft het eenmalige upgrade-pad van een oude single-user-install
  naar multi-user. `0001_initial_schema.sql` bevat de geconsolideerde,
  actuele schema (inclusief de tabellen die pas in latere STAPpen van dat
  archief-bestand zijn toegevoegd: `medications`, `medication_catalog`,
  `symptom_logs`, `vet_visits`) — dit was voorheen niet zo (het oude losse
  `supabase.sql` was buiten sync geraakt en miste die vier tabellen).

## CI/CD
- `.github/workflows/ci.yml`: `lint` (ESLint via `eslint-plugin-html` op
  `index.html`, elke PR + push naar `main`) en `release` (semantic-release,
  alleen push naar `main`, na een groene `lint`).
- `.github/workflows/supabase-migrations.yml`: `supabase db push` bij een
  push naar `main` die `supabase/migrations/**` raakt. Vereist secrets
  `SUPABASE_ACCESS_TOKEN`, `SUPABASE_PROJECT_REF`, `SUPABASE_DB_PASSWORD`.
