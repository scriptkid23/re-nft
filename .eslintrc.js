module.exports = {
  root: true,
  parser: "@babel/eslint-parser",
  parserOptions: {
    ecmaVersion: 2020, // Allows for the parsing of modern ECMAScript features
    sourceType: "module", // Allows for the use of imports
  },
  env: {
    browser: false,
    es2021: true,
    mocha: true,
    node: true,
    commonjs: true,
  },
  plugins: ["prettier", "import"],
  extends: [
    "eslint:recommended",
    "prettier"
  ],
  overrides: [
    {
      files: ["hardhat.config.js"],
      globals: { task: true },
    },
  ],
  rules: {
    "compiler-version": ["error", "^0.8.0"],
    "func-visibility": ["warn", { "ignoreConstructors": true }],
    "not-rely-on-time": ["off"]
  },
};
