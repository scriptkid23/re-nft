"use strict";
process.env.TS_NODE_FILES = true;
module.exports = {
  "allow-uncaught": true,
  diff: true,
  extension: ["js"],
  recursive: true,
  reporter: "spec",
  require: ["hardhat/register"], // ['ts-node/register/transpile-only'], (for yarn link <plugin>)
  slow: 300,
  spec: "test/**/*.test.js",
  timeout: 20000,
  ui: "bdd",
  watch: false,
  "watch-files": ["contracts/**/*.sol", "test/**/*.js"],
};
