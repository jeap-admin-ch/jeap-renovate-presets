# Open findings: jeap-renovate-presets

## 1. The post-upgrade script is downloaded unpinned and executed

`presets/post-upgrade.json` fetches `scripts/post-upgrade.sh` from the `main` branch on every run and executes it. Anyone who can push to `main` can therefore run code in the Renovate job of every consuming repository, with that job's environment and credentials. A change to `main` also takes effect everywhere at once, before any release.

This sits uneasily next to a cooldown whose purpose is supply chain protection for third-party releases.

**Suggestion:** pin the URL to a release tag or commit SHA, and update it as part of each release. Alternatively, verify a checksum before executing the script. A lighter interim step is branch protection with mandatory review on `main`.

## 2. GitHub Actions digest pinning is disabled in all defaults

`disable-github-actions-digest-pinning` undoes the pinning from `config:best-practices` for every action. Tags can be moved after release (the tj-actions/changed-files compromise in 2025 worked exactly this way). The new cooldown does not help here: Renovate checks the tag's age, not whether its content changed afterwards.

**Suggestion:** document why pinning was disabled. If the reason is internal reusable workflows, disable it only for those (`matchPackageNames`) and keep pinning for third-party actions.

## 3. Single grouped PR with `prConcurrentLimit: 1`

`group-all-into-one-pr` puts every update into one PR and allows only one PR at a time. If a single update breaks the build, all other updates are blocked, including routine patches, until someone fixes or excludes it. With the cooldown, the PR also changes more often as updates become eligible, which means more CI runs.

**Suggestion:** this is a legitimate trade-off for low-noise repositories, but document it as one. Explain how to unblock (exclude the dependency, or use the Dependency Dashboard) and how to switch to finer grouping.

## 4. Smaller items

- **Grouping rules that are always overridden.** `group-jeap-major`, `group-jeap-minor-patch`, `group-non-jeap-maven-deps-minor-patch` and `group-non-jeap-maven-plugins-minor-patch` define `groupName`/`groupSlug`, which `group-all-into-one-pr` overrides in the defaults; they are kept only for labels. Label-only presets, or a short note on how the rules are layered, would make this easier to maintain.
- **`group-all-into-one-pr` extends `config:recommended`.** A building-block preset should not pull in a base config. Under the defaults this is redundant; standalone use gets an unexpected side effect.
- **`prHourlyLimit: 1` is set twice**, in `default-no-version-bump` and in `group-all-into-one-pr`.
- **The post-upgrade runner has implicit requirements:** `node`, `python3` and `mvn` must be on the Renovate runner. Document them next to the preset.
