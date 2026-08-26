const globals = require("globals");
const html = require("eslint-plugin-html");

module.exports = [
  {
    files: ["**/*.html"],
    plugins: { html },
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: "script",
      globals: {
        ...globals.browser,
        // Loaded via <script src> from CDNs in index.html — not npm deps,
        // so ESLint can't infer them and needs to be told they exist.
        Chart: "readonly",
        Hammer: "readonly",
        Tesseract: "readonly",
        pdfjsLib: "readonly",
        html2canvas: "readonly",
      },
    },
    rules: {
      // Existing, working single-file app — lint for real bugs, not style.
      "no-undef": "error",
      "no-unused-vars": "off",
      "no-redeclare": "error",
      "no-dupe-keys": "error",
      "no-fallthrough": "error",
    },
  },
];
