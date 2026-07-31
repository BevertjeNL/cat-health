#!/usr/bin/env node
// Called by semantic-release (see .releaserc.json, exec.prepareCmd) with the
// new version as argv[2]. Rewrites the APP_VERSION constant in index.html —
// the one place the app displays its own version (Instellingen-tab) — so it
// never has to be bumped by hand again.
const fs = require("fs");
const path = require("path");

const version = process.argv[2];
if (!version) {
  console.error("Usage: node scripts/set-app-version.js <version>");
  process.exit(1);
}

const indexPath = path.join(__dirname, "..", "index.html");
const contents = fs.readFileSync(indexPath, "utf8");
const pattern = /const APP_VERSION = "[^"]*";/;

if (!pattern.test(contents)) {
  console.error("Could not find `const APP_VERSION = \"...\";` in index.html");
  process.exit(1);
}

fs.writeFileSync(indexPath, contents.replace(pattern, `const APP_VERSION = "${version}";`));
console.log(`APP_VERSION set to ${version}`);
