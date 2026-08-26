# CatHealth

## Wat dit is
Single-file PWA om het gewicht, bloedwaarden, vaccinaties, medicatie,
afwijkingen en dierenartsbezoeken van een huisdier bij te houden.
- `index.html` — alles inline: HTML, CSS en JS in één bestand. Bewuste
  keuze, geen build-stap. Externe libraries komen via CDN `<script>`-tags
  (Neon JS, Chart.js, Hammer.js, chartjs-plugin-zoom, Tesseract.js,
  pdf.js, html2canvas). Neon JS wordt als gepinde ESM-bundle dynamisch
  geladen; de overige libraries zijn globals (`Chart`, `Hammer`,
  `Tesseract`, `pdfjsLib`, `html2canvas`). Het zijn geen npm-afhankelijkheden.
  **CDN-versies staan altijd exact
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
  `connect-src` beperkt tot de eigen Neon Auth- en Data API-endpoints) staan
  wél strak. Nieuwe externe host toevoegen (nieuwe CDN, ander Neon-project)? Ook de
  CSP bijwerken, anders wordt die stilzwijgend geblokkeerd.
- `sw.js` — service worker voor PWA-offline-gebruik. Network-first voor
  app-shell assets. `CACHE_NAME` ophogen bij elke deploy die je op een
  geïnstalleerde PWA wilt forceren te verversen.
- `manifest.json` — PWA-manifest.
- Backend: Neon (Neon Auth met e-mail/wachtwoord + Postgres, Data API en RLS).
- Hosting: GitHub Pages op `https://bevertjenl.github.io/cat-health/`, vanuit
  de `main`-branch van `BevertjeNL/cat-health`.

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
  release) en, bij wijzigingen in `neon/migrations/**`, de migratie-
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

## Neon
- Neon-project: `CatHealth` (`square-truth-06822146`), database `neondb`,
  primaire branch `main` (`br-steep-poetry-as5wth2o`).
- De browser gebruikt alleen de publieke Neon Auth- en Data API-endpoints;
  een Postgres connection string hoort uitsluitend in het versleutelde
  GitHub Actions-secret `NEON_DATABASE_URL`.
- Tabellen van déze app: `pets`, `weight_measurements`, `blood_values`,
  `vaccinations`, `symptom_logs`, `medications`, `medication_catalog`,
  `vet_visits`, `veterinarians`, `food_catalog`, `food_purchases`. Alle rijen
  scopen via `pet_id` → `pets.user_id = auth.user_id()`. `veterinarians` is een losse contactenlijst
  (naam, telefoon, e-mail, adres, notities, hoofddierenarts-vlag) — niet te
  verwarren met `vet_visits`, dat alleen bezoek-logs bijhoudt.
- Schema staat als migraties in `neon/migrations/`
  (`0001_initial_schema.sql` + volgende genummerde bestanden) — geen
  handmatige wijzigingen via de Neon SQL Editor meer buiten migraties
  om. Nieuwe schema-wijzigingen: nieuw bestand
  `neon/migrations/000N_....sql` toevoegen, bestaande nummers niet meer
  aanpassen.
- `supabase/` is **historisch** en wordt niet door CI uitgevoerd. Het blijft
  bewaard als auditspoor van de bron en het oude single-user-upgradepad.
- `cathealth_migration.legacy_users` en de bijbehorende Auth-trigger zijn
  uitsluitend de tijdelijke eigendomsbrug tijdens de Supabase-cutover. Ze
  zijn niet via de Data API bereikbaar en mogen na succesvolle accountclaim
  in een afzonderlijke cleanup-migratie worden verwijderd.

## CI/CD
- `.github/workflows/ci.yml`: `lint` (ESLint via `eslint-plugin-html` op
  `index.html`, elke PR + push naar `main`) en `release` (semantic-release,
  alleen push naar `main`, na een groene `lint`).
- `.github/workflows/neon-migrations.yml`: past `neon/migrations/*.sql` in
  volgorde toe bij een push naar `main` die deze map raakt. Vereist secret
  `NEON_DATABASE_URL`.
- De eenmalige Supabase-naar-Neon-overdracht is op 27 augustus 2026
  afgerond en geverifieerd: 265 rijen in 11 tabellen en 2 oude
  account-e-mailkoppelingen. De tijdelijke migratieworkflows en het
  overdrachtsscript zijn daarna verwijderd.
