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
