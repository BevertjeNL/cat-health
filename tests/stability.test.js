const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const vm = require("node:vm");

const root = path.resolve(__dirname, "..");
const html = fs.readFileSync(path.join(root, "index.html"), "utf8");

function extractBetween(startMarker, endMarker) {
  const start = html.indexOf(startMarker);
  const end = html.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(start, -1, `missing start marker: ${startMarker}`);
  assert.notEqual(end, -1, `missing end marker: ${endMarker}`);
  return html.slice(start, end);
}

function createSettingsHarness() {
  const values = new Map();
  const localStorage = {
    getItem: (key) => values.has(key) ? values.get(key) : null,
    setItem: (key, value) => values.set(key, String(value)),
    removeItem: (key) => values.delete(key),
  };
  const source = extractBetween("  // --- Typed local settings", "  // --- Icon style");
  const context = { localStorage, currentUser: null, currentPetId: null };
  vm.createContext(context);
  vm.runInContext(`${source}\nthis.api = { readSetting, writeSetting, settingStorageKey };`, context);
  return { ...context.api, values, setUser: (user) => { context.currentUser = user; }, setPet: (id) => { context.currentPetId = id; } };
}

test("invalid device settings fall back to safe defaults", () => {
  const settings = createSettingsHarness();
  settings.values.set("appLang", "unsupported");
  settings.values.set("iconStyle", "flashing");
  assert.equal(settings.readSetting("appLang"), "nl");
  assert.equal(settings.readSetting("iconStyle"), "color");
});

test("pet settings are isolated by both account and pet", () => {
  const settings = createSettingsHarness();
  settings.setUser({ id: "user-a" });
  settings.setPet(11);
  assert.equal(settings.writeSetting("watchMarkers", ["CREA"]), true);
  assert.deepEqual([...settings.readSetting("watchMarkers")], ["CREA"]);

  settings.setPet(12);
  assert.deepEqual([...settings.readSetting("watchMarkers")], ["ALT", "ALKP", "GGT", "TBIL"]);

  settings.setUser({ id: "user-b" });
  settings.setPet(11);
  assert.deepEqual([...settings.readSetting("watchMarkers")], ["ALT", "ALKP", "GGT", "TBIL"]);
});

test("offline contract stores ownership and never deletes permanent failures", () => {
  assert.match(html, /ownerUserId, petId: row\.pet_id \|\| petId/);
  assert.match(html, /entry\.ownerUserId === currentUser\.id/);
  assert.match(html, /entry\.status = "failed"/);
  assert.doesNotMatch(
    extractBetween("        if (result.error) {", "        const cfg = OFFLINE_TABLES"),
    /idbDelete\("outbox"/
  );
});

test("all offline-capable tables have idempotent mutation indexes", () => {
  const migration = fs.readFileSync(
    path.join(root, "neon/migrations/0002_idempotent_offline_mutations.sql"),
    "utf8"
  );
  for (const table of [
    "weight_measurements",
    "blood_values",
    "vaccinations",
    "symptom_logs",
    "medications",
    "vet_visits",
    "food_purchases",
  ]) {
    assert.match(migration, new RegExp(`alter table ${table} add column if not exists client_mutation_id uuid`));
    assert.match(migration, new RegExp(`${table}_client_mutation_id_idx`));
  }
});

test("every refresh loader rejects stale generations", () => {
  for (const loader of [
    "loadWeights",
    "loadBloodValues",
    "loadVaccinations",
    "loadSymptoms",
    "loadMedications",
    "loadMedicationCatalog",
    "loadFoodPurchases",
    "loadFoodCatalog",
    "loadVetVisits",
    "loadVets",
    "loadProfile",
  ]) {
    assert.match(html, new RegExp(`async function ${loader}\\(loadContext = currentLoadContext\\(\\)\\)`));
  }
});

test("paged reads collect every row without relying on the server limit", async () => {
  const source = extractBetween("  // --- Paged Data API reads", "  // Fetch export rows");
  const context = {};
  vm.createContext(context);
  vm.runInContext(`${source}\nthis.fetchAllRows = fetchAllRows;`, context);

  const allRows = [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }];
  const ranges = [];
  const result = await context.fetchAllRows((from, to) => {
    ranges.push([from, to]);
    return Promise.resolve({ data: allRows.slice(from, to + 1), error: null });
  }, 2);

  assert.equal(result.error, null);
  assert.deepEqual(Array.from(result.data, (row) => row.id), [1, 2, 3, 4, 5]);
  assert.deepEqual(ranges, [[0, 1], [2, 3], [4, 5]]);
});

test("all collection loaders use the shared pagination helper", () => {
  for (const loader of [
    "loadPets",
    "openArchivedPetsMenu",
    "loadWeights",
    "loadBloodValues",
    "loadVets",
    "loadVetVisits",
    "loadVaccinations",
    "loadSymptoms",
    "loadMedicationCatalog",
    "loadMedications",
    "loadFoodCatalog",
    "loadFoodPurchases",
  ]) {
    assert.match(
      html,
      new RegExp(`async function ${loader}\\([^]{0,700}?fetchAllRows\\(`),
      `${loader} must use fetchAllRows()`
    );
  }
});

test("veterinarian contact links use validated DOM properties", () => {
  const source = extractBetween("  function vetContactHref", "  function appendVetContactRow");
  const context = {};
  vm.createContext(context);
  vm.runInContext(`${source}\nthis.vetContactHref = vetContactHref;`, context);

  assert.equal(context.vetContactHref("tel", "+31 6 12 34 56 78"), "tel:+31612345678");
  assert.equal(context.vetContactHref("tel", `06 12 34 56 78\" onclick=\"alert(1)`), null);
  assert.equal(
    context.vetContactHref("mailto", "dierenarts@example.nl?bcc=andere@example.nl"),
    null
  );
  assert.doesNotMatch(html, /vetDetailBody"\)\.innerHTML/);
  assert.match(html, /content\.setAttribute\("href", href\)/);
});

test("dashboard navigation and every collapsible form are keyboard accessible", () => {
  assert.match(
    html,
    /id="foodFormHeader" role="button" tabindex="0" aria-expanded="false" aria-controls="foodFormBody"[^>]+onkeydown=/
  );
  assert.doesNotMatch(html, /<div class="dashboard-alert-row"/);
  assert.doesNotMatch(html, /<div class="card dashboard-card" onclick=/);
  assert.match(html, /<button type="button" class="dashboard-alert-row" data-tab-target=/);
  assert.match(html, /<a class="card dashboard-card" href="#tabWeight" data-tab-target="weight"/);
  assert.match(html, /const DASHBOARD_TARGET_PANELS = \{/);
  assert.match(html, /aria-label="\$\{t\("selectYearLabel"\)\}"/);
});

test("CI runs regression tests before lint", () => {
  const workflow = fs.readFileSync(path.join(root, ".github/workflows/ci.yml"), "utf8");
  assert.ok(workflow.indexOf("- run: npm test") > -1);
  assert.ok(workflow.indexOf("- run: npm test") < workflow.indexOf("- run: npm run lint"));
});

function createDecimalHarness(lang = "nl") {
  const source = extractBetween("  // --- Decimal input", '  document.querySelectorAll(".today-btn")');
  const errors = [];
  const context = { readSetting: () => lang, showError: (msg) => errors.push(msg), t: (key) => key };
  vm.createContext(context);
  vm.runInContext(`${source}\nthis.api = { parseDecimalInput, parseOptionalDecimalInput, formatDecimalInput, validDecimalFields };`, context);
  return { ...context.api, errors };
}

test("decimal inputs accept a Dutch comma as well as a dot", () => {
  const { parseDecimalInput, parseOptionalDecimalInput } = createDecimalHarness();
  assert.equal(parseDecimalInput("4,2"), 4.2);
  assert.equal(parseDecimalInput(" 4.25 "), 4.25);
  assert.equal(parseDecimalInput(",5"), 0.5);
  assert.equal(parseDecimalInput("-1,5"), -1.5);
  assert.equal(parseDecimalInput("12"), 12);
  assert.ok(Number.isNaN(parseDecimalInput("1.234,5")));
  assert.ok(Number.isNaN(parseDecimalInput("4,2kg")));
  assert.ok(Number.isNaN(parseDecimalInput("")));
  assert.equal(parseOptionalDecimalInput("  "), null);
  assert.equal(parseOptionalDecimalInput("45,00"), 45);
});

test("decimal prefills follow the interface language and invalid values block saving", () => {
  assert.equal(createDecimalHarness("nl").formatDecimalInput(4.2), "4,2");
  assert.equal(createDecimalHarness("en").formatDecimalInput(4.2), "4.2");
  assert.equal(createDecimalHarness("nl").formatDecimalInput(null), "");
  const harness = createDecimalHarness();
  assert.equal(harness.validDecimalFields(4.2, null), true);
  assert.equal(harness.validDecimalFields(NaN), false);
  assert.deepEqual(harness.errors, ["errInvalidNumber"]);
});

test("decimal fields no longer use number inputs that drop a comma", () => {
  for (const id of ["weightKg", "vetVisitCost", "vaxCost", "medicationCost", "foodAmount", "foodCost", "catTargetMin", "catTargetMax"]) {
    assert.match(html, new RegExp(`<input type="text" id="${id}" inputmode="decimal"`));
  }
  assert.doesNotMatch(html, /parseFloat\(document\.getElementById/);
});

test("symptom logs store an optional time of day", () => {
  const migration = fs.readFileSync(path.join(root, "neon/migrations/0004_symptom_log_time.sql"), "utf8");
  assert.match(migration, /alter table symptom_logs add column if not exists time time;/);
  assert.match(html, /<input type="time" id="symptomTime"/);
  assert.match(html, /symptom_logs: \["id", "pet_id", "date", "time",/);
});

function createSymptomTimelineHarness() {
  const source = extractBetween("  // --- Afwijkingen: tijdlijn", "  function symptomRangeKey()");
  const context = {};
  vm.createContext(context);
  vm.runInContext(
    `${source}\nthis.api = { symptomRangeBounds, buildSymptomTimelineModel, computeSinceVisitOverview, isoWeekStart, isoAddDays, isoDayDiff };`,
    context
  );
  return context.api;
}

const timelineRows = [
  { id: 1, date: "2026-01-05", symptom: "Braken", severity: "licht" },
  { id: 2, date: "2026-06-01", symptom: "Braken", severity: "matig" },
  { id: 3, date: "2026-08-20", symptom: "Braken", severity: "ernstig" },
  { id: 4, date: "2026-08-21", symptom: "Braken", severity: "licht" },
  { id: 5, date: "2026-08-21", symptom: "Braken", severity: null },
  { id: 6, date: "2026-09-01", symptom: "Niezen", severity: null },
  { id: 7, date: "2026-07-15", symptom: "Diarree", severity: "matig" },
];

test("symptom timeline periods resolve to the expected bounds", () => {
  const { symptomRangeBounds } = createSymptomTimelineHarness();
  const dates = timelineRows.map((r) => r.date);
  const ctx = { today: "2026-09-25", lastVisitDate: "2026-08-12", dates };
  assert.deepEqual({ ...symptomRangeBounds("visit", ctx) }, { from: "2026-08-12", to: "2026-09-25" });
  assert.deepEqual({ ...symptomRangeBounds("1m", ctx) }, { from: "2026-08-26", to: "2026-09-25" });
  assert.deepEqual({ ...symptomRangeBounds("all", ctx) }, { from: "2026-01-05", to: "2026-09-25" });
  assert.deepEqual({ ...symptomRangeBounds("visit", { ...ctx, lastVisitDate: null }) }, { from: "2026-01-05", to: "2026-09-25" });
});

test("symptom timeline groups per day for short periods and per ISO week for long ones", () => {
  const { buildSymptomTimelineModel, isoWeekStart } = createSymptomTimelineHarness();
  assert.equal(isoWeekStart("2026-08-23"), "2026-08-17");
  assert.equal(isoWeekStart("2026-08-17"), "2026-08-17");

  const short = buildSymptomTimelineModel(timelineRows, { from: "2026-08-12", to: "2026-09-25" });
  assert.equal(short.mode, "day");
  assert.deepEqual([...short.names], ["Braken", "Niezen"]);
  assert.equal(short.total, 4);
  const aug21 = short.points.find((p) => p.x === "2026-08-21");
  assert.equal(aug21.count, 2);
  assert.equal(aug21.severity, "licht");

  const long = buildSymptomTimelineModel(timelineRows, { from: "2026-01-01", to: "2026-09-25" });
  assert.equal(long.mode, "week");
  const week = long.points.find((p) => p.from === "2026-08-17" && p.y === "Braken");
  assert.equal(week.count, 3);
  assert.equal(week.severity, "ernstig");
  assert.equal(week.to, "2026-08-23");
});

test("since-visit overview compares with the equally long period before the visit", () => {
  const { computeSinceVisitOverview } = createSymptomTimelineHarness();
  assert.equal(computeSinceVisitOverview(timelineRows, null, "2026-09-25"), null);
  const overview = computeSinceVisitOverview(timelineRows, "2026-08-12", "2026-09-25");
  assert.equal(overview.days, 44);
  assert.equal(overview.total, 4);
  assert.equal(overview.kinds, 2);
  const [braken, niezen] = overview.items;
  assert.equal(braken.symptom, "Braken");
  assert.equal(braken.count, 3);
  assert.equal(braken.previousCount, 0);
  assert.equal(braken.isNew, false);
  assert.deepEqual({ ...braken.severity }, { ernstig: 1, matig: 0, licht: 1, onbekend: 1 });
  assert.equal(niezen.isNew, true);
  assert.equal(niezen.daysSinceLast, 24);
});

test("symptom timeline range is a validated pet-scoped setting and marks are not built with innerHTML", () => {
  assert.match(html, /symptomChartRange: \{\s*scope: "pet",\s*defaultValue: "visit"/);
  const card = extractBetween("  function renderSymptomSinceVisitCard", "  function setSymptomListFilter");
  assert.doesNotMatch(card, /innerHTML/);
});
