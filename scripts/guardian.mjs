#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const failures = [];

function fail(message) {
  failures.push(message);
}

function read(path) {
  return readFileSync(path, "utf8");
}

function json(path) {
  return JSON.parse(read(path));
}

function requireFile(path) {
  if (!existsSync(path)) fail(`${path} is required`);
}

const pkg = json("package.json");

if (pkg.name !== "@mavula/operations") fail("package name must be @mavula/operations");
if (pkg.license !== "Apache-2.0") fail("operations must remain Apache-2.0");
if (pkg.author !== "EstandarMustaq <estandarmustaq@mavula.io>") {
  fail("author must use the MAVULA address");
}

[
  ".github/CODEOWNERS",
  ".github/PULL_REQUEST_TEMPLATE.md",
  ".github/workflows/guardian.yml",
  "LICENSE",
  "README.md",
  "kubernetes/overlays/minikube/kustomization.yaml",
  "kubernetes/deployment-identity-access.yaml",
  "kubernetes/service-identity-access.yaml",
  "kubernetes/secrets-external.yaml",
  "docker/build.sh",
  "scripts/minikube-deploy.sh",
  "terraform/main.tf",
].forEach(requireFile);

if (!/SPDX-License-Identifier: Apache-2\.0/.test(read("LICENSE"))) {
  fail("LICENSE must declare Apache SPDX");
}
if (!/@mavula\/operations/.test(read("README.md"))) {
  fail("README must identify @mavula/operations");
}

const tracked = spawnSync("git", ["ls-files"], { encoding: "utf8" });
if (tracked.status !== 0) fail("git ls-files failed");
for (const file of tracked.stdout.split("\n").filter(Boolean)) {
  if (/(^|\/)\.env($|\.(?!example$))/.test(file)) fail(`${file} must not be tracked`);
  if (file === "scripts/guardian.mjs") continue;
  if (/getfluxo-io|@getfluxo|packages\/fengine|packages\/fwk|packages\/fpay|packages\/finfra|JWT_SECRET|INTERNAL_API_KEY/.test(read(file))) {
    fail(`${file} contains legacy public identifiers`);
  }
}

const minikubeDeploy = read("scripts/minikube-deploy.sh");
if (!minikubeDeploy.includes('MINIKUBE_REBUILD_IMAGES:-false')) {
  fail("Minikube image rebuilds must remain opt-in");
}
if (!minikubeDeploy.includes('MAVULA_ENV_FILE')) {
  fail("Minikube deployment must load untracked local configuration");
}

if (failures.length > 0) {
  console.error("MAVULA operations guardian failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("MAVULA operations guardian passed.");
