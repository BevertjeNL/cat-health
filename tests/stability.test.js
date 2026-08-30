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
