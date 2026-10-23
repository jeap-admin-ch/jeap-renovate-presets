// Run with Node.js 24 and an installed Renovate 44.109.1 package:
// node tests/minimum-release-age-test.mjs /path/to/node_modules/renovate
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

assert.ok(process.argv[2], 'Pass the path to an installed Renovate package');
const renovate = resolve(process.argv[2]);
const { version } = JSON.parse(await readFile(join(renovate, 'package.json'), 'utf8'));
assert.equal(version, '44.109.1', 'This regression test targets Renovate 44.109.1 internals');
const load = (path) => import(pathToFileURL(join(renovate, 'dist', path)));
const { getConfig } = await load('config/defaults.js');
const { mergeChildConfig } = await load('config/index.js');
const { applyPackageRules } = await load('util/package-rules/index.js');
const { validateConfig } = await load('config/validation.js');
const { massageConfig } = await load('config/massage.js');
const { checkMinimumReleaseAge } = await load('util/minimum-release-age.js');
const { presets: security } = await load('config/presets/internal/security.preset.js');

const read = async (name) => JSON.parse(await readFile(new URL(`../presets/${name}.json`, import.meta.url), 'utf8'));
const preset = await read('minimum-release-age');
const ignoreKafka = await read('ignore-kafka-message-deps');
const kafkaPresets = ['compatibility-aware-kafka-message-deps', 'compatibility-aware-kafka-message-deps-app-specific', 'compatibility-aware-kafka-message-deps-app-specific-dev'];
for (const [name, config] of [['minimum-release-age', preset], ...await Promise.all(kafkaPresets.map(async (name) => [name, await read(name)]))]) {
  const validation = await validateConfig('repo', massageConfig(config));
  assert.deepEqual(validation.errors, [], `${name} must be valid repository configuration`);
  assert.deepEqual(validation.warnings, [], `${name} must not require global-only configuration`);
}

// Same order as the default presets: config:best-practices (which contributes
// security:minimumReleaseAgeNpm), ignore-kafka-message-deps, then this preset.
const merge = (...configs) => configs.reduce((config, child) => mergeChildConfig(config, child), getConfig());
const defaults = merge(security.minimumReleaseAgeNpm, ignoreKafka, preset);
const withKafka = mergeChildConfig(defaults, await read('compatibility-aware-kafka-message-deps'));

const hour = 60 * 60 * 1000;
const fresh = new Date(Date.now() - hour).toISOString();
const old = new Date(Date.now() - 10 * 24 * hour).toISOString();
const isPending = async (config, { datasource, packageName, updateType, releaseTimestamp, rules = [] }) => {
  const resolved = await applyPackageRules({
    ...mergeChildConfig(config, { packageRules: rules }),
    manager: datasource === 'docker' ? 'dockerfile' : datasource,
    datasource,
    packageName,
    depName: packageName,
    updateType
  });
  return checkMinimumReleaseAge(resolved, releaseTimestamp).isPending;
};

const upstream = { datasource: 'maven', packageName: 'org.example:lib', updateType: 'minor' };
assert.equal(await isPending(defaults, { ...upstream, releaseTimestamp: fresh }), true, 'Fresh upstream Maven release is delayed');
assert.equal(await isPending(defaults, { ...upstream, updateType: 'major', releaseTimestamp: fresh }), true, 'Major updates are delayed too');
assert.equal(await isPending(defaults, { ...upstream, releaseTimestamp: old }), false, 'Upstream release older than 3 days is proposed');
assert.equal(await isPending(defaults, upstream), true, 'Maven keeps timestamp-required: a missing timestamp holds the update');
assert.equal(await isPending(defaults, { ...upstream, packageName: 'ch.admin.bit.other:lib', releaseTimestamp: fresh }), true, 'Only jEAP is exempt, not every ch.admin dependency');
assert.equal(await isPending(defaults, { ...upstream, packageName: 'ch.admin.bit.jeap:jeap-spring-boot-parent', releaseTimestamp: fresh }), false, 'jEAP dependencies are not delayed');

const proxied = { datasource: 'docker', packageName: 'repo.bit.admin.ch:8444/postgres', updateType: 'digest' };
assert.equal(await isPending(defaults, proxied), false, 'Docker images without a timestamp (non-Docker Hub registries) are not held indefinitely');
assert.equal(await isPending(defaults, { ...proxied, packageName: 'postgres', releaseTimestamp: fresh }), true, 'Docker images with a timestamp (Docker Hub) are delayed');

for (const updateType of ['replacement', 'pin', 'bump', 'lockfileUpdate', 'rollback']) {
  assert.equal(await isPending(defaults, { ...upstream, updateType }), false, `${updateType} updates have no timestamp and are not held`);
  assert.equal(await isPending(defaults, { ...upstream, datasource: 'npm', packageName: 'lodash', updateType }), false, `npm ${updateType} keeps the upstream opt-out`);
}
assert.equal(await isPending(defaults, { datasource: 'npm', packageName: 'lodash', updateType: 'minor', releaseTimestamp: fresh }), true, 'npm is delayed by config:best-practices');
assert.equal(await isPending(merge(preset), { datasource: 'npm', packageName: 'lodash', updateType: 'minor', releaseTimestamp: fresh }), false, 'npm is left to config:best-practices, not this preset');

// Model the forced package rule produced by vulnerability-alert processing.
const securityRule = (config, packageName) => ({ matchPackageNames: [packageName], isVulnerabilityAlert: true, force: { ...config.vulnerabilityAlerts } });
assert.equal(await isPending(defaults, { ...upstream, releaseTimestamp: fresh, rules: [securityRule(defaults, upstream.packageName)] }), false, 'Vulnerability fixes are not delayed');
const { vulnerabilityAlerts, ...presetWithoutOverride } = preset;
const withoutOverride = merge(security.minimumReleaseAgeNpm, ignoreKafka, presetWithoutOverride);
assert.equal(await isPending(withoutOverride, { ...upstream, releaseTimestamp: fresh, rules: [securityRule(withoutOverride, upstream.packageName)] }), false, 'Renovate default already exempts vulnerability fixes; the explicit override is documentation');

const messageType = { datasource: 'maven', packageName: 'ch.admin.bit.example.messagetype.order:order-created', updateType: 'minor' };
assert.equal(await isPending(withKafka, messageType), false, 'Message-type dependencies from the contract service are not held');
assert.equal(await isPending(withKafka, { ...messageType, releaseTimestamp: fresh }), false, 'Message-type dependencies are not delayed');

console.log('PASS: upstream updates delayed; jEAP, vulnerability fixes, message types, untimestamped Docker images, and timestamp-less update types are not held; npm left to config:best-practices');
