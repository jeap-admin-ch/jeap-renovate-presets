# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2026-06-25

### Added

- New preset `group-routine-maven-docker`: groups all routine updates (pin, pinDigest, digest, patch, minor) for `maven`, `dockerfile`, and `docker-compose` managers into a single PR to prevent PR starvation.
- New preset `group-major-maven-docker`: groups all major updates for `maven`, `dockerfile`, and `docker-compose` managers into a single PR.
- New canonical preset `post-upgrade`: runs Maven project version bump and conditional `CHANGELOG.md` updates in one branch-level `postUpgradeTasks` block. Version bump is skipped for projects without a `pom.xml`, and changelog update is skipped when no `CHANGELOG.md` exists.
- New script `post-upgrade.sh`: reads all Renovate upgrades from the generated JSON data file, bumps Maven project versions, updates existing changelogs, and stages the post-upgrade changes for Renovate.
- New preset `automerge`: enables automerge for routine Maven, Dockerfile, and Docker Compose updates.
- New default preset variants:
  - `default`: grouping, Maven project version bump, and conditional changelog update.
  - `default-automerge`: same as `default`, with automerge enabled.
  - `default-no-version-bump`: grouping only, without Maven project version bump or changelog update.
  - `default-no-version-bump-automerge`: same as `default-no-version-bump`, with automerge enabled.
- Automated smoke tests for `scripts/post-upgrade.sh` covering Maven, Docker digest, special-character dependency names, missing changelogs, and irrelevant upgrades.

### Changed

- `default-no-version-bump` extends the two new cross-manager presets (`group-routine-maven-docker`, `group-major-maven-docker`) after the existing fine-grained Maven groups. Because Renovate applies `packageRules` in order and later rules win for scalar fields like `groupName`, all Maven, Dockerfile, and Docker Compose updates are consolidated into at most two PRs (one routine, one major) per Renovate run.
- `default` now composes `default-no-version-bump` with `post-upgrade`.
- `default-automerge` now composes `default` with `automerge`.
- `automerge` uses a single explicit `matchManagers` and `matchUpdateTypes` selector instead of extending grouped presets. This keeps grouped Maven, Dockerfile, and Docker Compose PRs intact and enables automerge only for routine updates while leaving major updates manual.
- `default-no-version-bump` and `group-all-into-one-pr` set `prHourlyLimit: 1` in the presets so PR creation limits do not depend on the Renovate Bot runner configuration. `prConcurrentLimit: 1` remains in `group-all-into-one-pr`.
- `README.md` now documents the four default preset variants.
- `README.md` now documents Renovate `41.1.0` as the minimum version for the `post-upgrade` preset.
- `publiccode.yml` was updated to version `0.3.0`.
- The post-upgrade data template now uses Renovate JSON serialization for upgrade data, so dependency names with JSON-special characters do not break parsing.
- Docker digest changelog entries now use digest information when version fields are absent and skip entries that do not contain useful version or digest data.
- Missing root `CHANGELOG.md` handling is documented as intentional skip behavior; the script logs the skip and does not create a new changelog.
- Missing post-upgrade data files now log a warning and skip Maven version and changelog updates instead of failing the Renovate branch.
- `group-all-into-one-pr` now extends `config:recommended` and declares the Renovate schema like the other presets.

### Removed

- `presets/default-no-project-version-bump.json`: removed in favor of `default-no-version-bump`.
- `presets/post-upgrade-maven.json`: removed in favor of `post-upgrade`.
- `scripts/post-upgrade-maven.sh`: removed in favor of `scripts/post-upgrade.sh`.
- `scripts/update-changelog.sh`: removed in favor of `scripts/post-upgrade.sh`.
- `presets/bump-maven-project-version.json`: merged into `post-upgrade`.
- `presets/update-changelog-maven.json`: merged into `post-upgrade`.

## [0.2.0] - 2026-04-29

### Added

- Added preset to group all updates into one single PR

## [0.1.0] - 2026-04-14

### Added

- Added Maven changelog update script and preset

## [0.0.5] - 2026-04-10

### Added

- Added the group-github-actions preset

## [0.0.4] - 2026-04-09

### Changed

- Fixed automerge preset path for JEAP minor and patch updates

## [0.0.3] - 2026-04-08

### Added

- Added the ignore-docker-compose preset

## [0.0.2] - 2025-12-09

### Changed

- Added the bump-maven-project-version preset to the default preset

## [0.0.1] - 2025-11-25

### Changed

- Initial version.
