// Run with Node.js 24 and an installed Renovate 44.109.1 package:
// node tests/ignore-npm-test.mjs /path/to/node_modules/renovate
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

assert.ok(process.argv[2], 'Pass the path to an installed Renovate package');
const renovate = resolve(process.argv[2]);
const { version } = JSON.parse(await readFile(join(renovate, 'package.json'), 'utf8'));
assert.equal(version, '44.109.1', 'This regression test targets Renovate 44.109.1 internals');
const load = (path) => import(pathToFileURL(join(renovate, 'dist', path)));
const { getConfig } = await load('config/defaults.js');
const { getManagerConfig, mergeChildConfig } = await load('config/index.js');
const { GlobalConfig } = await load('config/global.js');
const { getManagerPackageFiles } = await load('workers/repository/extract/manager-files.js');
const { applyPackageRules } = await load('util/package-rules/index.js');
const { validateConfig } = await load('config/validation.js');
const { massageConfig } = await load('config/massage.js');

const preset = JSON.parse(await readFile(new URL('../presets/ignore-npm.json', import.meta.url), 'utf8'));
const angular = JSON.parse(await readFile(new URL('../presets/manual-angular-stack-major-updates.json', import.meta.url), 'utf8'));
const validation = await validateConfig('repo', massageConfig(preset));
assert.deepEqual(validation.errors, [], 'Preset must be valid repository configuration');
assert.deepEqual(validation.warnings, [], 'Preset must not require global-only configuration');
const directory = await mkdtemp(join(tmpdir(), 'jeap-ignore-npm-'));

try {
  await writeFile(join(directory, 'package.json'), JSON.stringify({
    name: 'ignore-npm-regression',
    version: '1.0.0',
    dependencies: { '@angular/core': '20.3.19', '@angular/animations': '20.3.19' }
  }));
  await writeFile(join(directory, 'Dockerfile'), 'FROM postgres:17.7\n');
  await writeFile(join(directory, 'pom.xml'), '<project><modelVersion>4.0.0</modelVersion><groupId>example</groupId><artifactId>app</artifactId><version>1.0.0</version><dependencies><dependency><groupId>org.modelmapper</groupId><artifactId>modelmapper</artifactId><version>3.2.3</version></dependency></dependencies></project>');
  GlobalConfig.set({ localDir: directory, cacheDir: directory });

  const defaults = mergeChildConfig(getConfig(), {
    osvVulnerabilityAlerts: true,
    vulnerabilityAlerts: { enabled: true }
  });
  const extract = (config, manager, file) => getManagerPackageFiles({
    ...getManagerConfig(config, manager),
    fileList: [file],
    hasVulnerabilityAlertsRules: true
  });

  // Model the forced package rule produced by vulnerability-alert processing.
  // It overrides the former ignore-npm rule, but cannot bypass manager extraction.
  const oldRule = { matchManagers: ['npm'], enabled: false };
  const securityRule = {
    matchManagers: ['npm'],
    matchPackageNames: ['@angular/core'],
    isVulnerabilityAlert: true,
    force: { enabled: true }
  };
  const formerlyIgnored = mergeChildConfig(defaults, { packageRules: [oldRule, securityRule] });
  assert.ok((await extract(formerlyIgnored, 'npm', 'package.json')).length > 0);
  const overridden = await applyPackageRules({
    ...getManagerConfig(formerlyIgnored, 'npm'), depName: '@angular/core', packageName: '@angular/core'
  }, 'pre-lookup');
  assert.equal(overridden.enabled, true, 'Reproduce the security override of the old preset');

  for (const rules of [[], [securityRule], [securityRule, { matchManagers: ['npm'], enabled: true }]]) {
    const ignored = mergeChildConfig(mergeChildConfig(defaults, preset), { packageRules: rules });
    assert.deepEqual(await extract(ignored, 'npm', 'package.json'), [], 'No npm extraction, even with security/re-enabling rules');
    assert.ok((await extract(ignored, 'maven', 'pom.xml')).length > 0, 'Maven still extracts dependencies');
    assert.ok((await extract(ignored, 'dockerfile', 'Dockerfile')).length > 0, 'Docker still extracts dependencies');
  }

  const recommended = mergeChildConfig(defaults, angular);
  const files = await extract(recommended, 'npm', 'package.json');
  const names = files.flatMap((file) => file.deps.map((dep) => dep.depName));
  assert.ok(names.includes('@angular/core'));
  assert.ok(names.includes('@angular/animations'), 'Recommended configuration extracts companions too');
  assert.deepEqual(await extract(mergeChildConfig(mergeChildConfig(defaults, preset), angular), 'npm', 'package.json'), [], 'Angular preset does not undo the manager opt-out');
  console.log('PASS: security override reproduced; npm extraction disabled; Maven/Docker unaffected; recommended Angular configuration extracts companions');
} finally {
  await rm(directory, { recursive: true, force: true });
}
