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
  "kubernetes/ledger-core-metrics-secret.yaml",
  "kubernetes/workbench-metrics-secret.yaml",
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
if (!minikubeDeploy.includes('MINIKUBE_LOAD_IMAGES:-false')) {
  fail("Minikube image loading must remain opt-in");
}
if (/minikube start/.test(minikubeDeploy)) {
  fail("Minikube deployment must not create or start a cluster implicitly");
}
if (!minikubeDeploy.includes('Dockerfile.workspace')) {
  fail("Identity workspace builds must use Dockerfile.workspace");
}
if (!minikubeDeploy.includes('MAVULA_ENV_FILE')) {
  fail("Minikube deployment must load untracked local configuration");
}
for (const required of [
  'LEGACY_CONNECTORS_DATABASE_URL',
  'LEGACY_CONNECTORS_DATABASE_ROLE_PASSWORD',
  'WORKBENCH_DATABASE_URL',
  'WORKBENCH_DATABASE_ROLE_PASSWORD',
  'SETTLEMENTS_DATABASE_URL',
  'SETTLEMENTS_DATABASE_ROLE_PASSWORD',
  'database:provision-role',
  'WORKBENCH_METRICS_TOKEN',
  'LEDGER_CORE_METRICS_TOKEN',
  'WORKBENCH_QUEUES=payments,platform,legacy',
]) {
  if (!minikubeDeploy.includes(required)) fail(`Minikube legacy runtime wiring missing: ${required}`);
}
if (!minikubeDeploy.includes('LOAD_IMAGES=true')) {
  fail('Minikube rebuilds must automatically load rebuilt images into the selected profile');
}
if (read('kubernetes/ledger-core-secret.yaml').includes('LEDGER_CORE_METRICS_TOKEN')) {
  fail('ledger-core runtime secret must not contain metrics scrape token');
}
if (read('kubernetes/workbench-secret.yaml').includes('WORKBENCH_METRICS_TOKEN')) {
  fail('workbench runtime secret must not contain metrics scrape token');
}
const workbenchMonitoring = read('kubernetes/monitoring-workbench.yaml');
if (!workbenchMonitoring.includes('bearerTokenSecret')) fail('Workbench metrics scraping must use a bearer token');
if (workbenchMonitoring.includes('name: workbench-secrets')) {
  fail('Workbench ServiceMonitor must not read the runtime secret');
}
for (const metric of ['workbench_legacy_batch_processing', 'workbench_legacy_batch_rejected', 'workbench_legacy_batch_failed']) {
  if (!workbenchMonitoring.includes(metric)) fail(`Legacy batch alert missing: ${metric}`);
}
const ledgerMonitoring = read('kubernetes/monitoring-ledger-core.yaml');
if (!ledgerMonitoring.includes('bearerTokenSecret')) {
  fail('Ledger-core metrics scraping must use a bearer token');
}
if (ledgerMonitoring.includes('name: ledger-core-secrets')) {
  fail('Ledger-core ServiceMonitor must not read the runtime secret');
}
for (const required of ['ledger-core-metrics-secrets', 'workbench-metrics-secrets']) {
  if (!read('kubernetes/secrets-external.yaml').includes(required)) fail(`ExternalSecret missing: ${required}`);
}

const secretFiles = spawnSync("git", ["ls-files", "kubernetes/*-secret.yaml"], { encoding: "utf8" });
if (secretFiles.status !== 0) fail("git ls-files for secret templates failed");
for (const file of secretFiles.stdout.split("\n").filter(Boolean)) {
  if (file.startsWith("kubernetes/overlays/minikube/")) continue;
  const contents = read(file);
  if (contents.includes("mavula_dev")) fail(`${file} must not contain mavula_dev credentials`);
  if (contents.includes("getfluxo_dev")) fail(`${file} must not contain getfluxo_dev credentials`);
  if (/postgresql:\/\/[^/\s"']+:[^/\s"']+@/i.test(contents)) {
    fail(`${file} must not embed postgresql credentials; use REPLACE_WITH_* placeholders`);
  }
}

if (failures.length > 0) {
  console.error("MAVULA operations guardian failed:");
  for (const failure of failures) console.error(`- ${failure}`);
  process.exit(1);
}

console.log("MAVULA operations guardian passed.");
