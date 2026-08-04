# Preset reference

Presets are referenced from a root-level `renovate.json` with this syntax:

```text
local>jeap-admin-ch/jeap-renovate-presets//presets/<preset-name>
```

Start with one of the four default presets unless the repository has a specific reason to assemble its own behavior. Presets listed later in `extends`, and package rules defined directly in the repository, can override earlier matching settings.

## Default presets

The four default variants share the baseline defined by `default-no-version-bump`:

- extends Renovate's `config:best-practices`;
- ignores unstable Maven versions and Kafka message-type dependencies;
- requires Dependency Dashboard approval for Maven major updates, except jEAP major updates;
- retains jEAP and non-jEAP labels from the fine-grained Maven rules;
- groups updates from all managers and dependency types into one pull request; and
- limits both hourly and concurrent pull requests to one.

The all-dependencies grouping rule is applied after the manager-specific rules. Its group name therefore wins: current defaults do not create separate routine, major, security, jEAP, plugin, or ecosystem pull requests. Earlier rules still supply labels and dashboard approval behavior.

### `default`

Choose this for a versioned Maven application when update pull requests are reviewed manually. It adds `post-upgrade` to the shared baseline. For relevant Maven, Maven Wrapper, Dockerfile, and Docker Compose updates, the post-upgrade script bumps the Maven project version according to the highest update type on the branch. It also adds dependency entries to a root `CHANGELOG.md` if that file already exists.

The script skips the project version bump when no root `pom.xml` exists and never creates a missing changelog. This makes the preset usable for Docker-only repositories, although `default-no-version-bump` communicates that intent more clearly and avoids running the post-upgrade task.

### `default-automerge`

Choose this instead of `default` only when CI tests and required status checks can reliably detect regressions. It adds `automerge` to `default`. The grouped pull request is merged automatically only when every included update is an eligible routine Maven, Dockerfile, or Docker Compose update. Project version bump and existing changelog updates remain enabled. A major update or an update from another manager keeps the complete pull request manual.

### `default-no-version-bump`

Choose this when Renovate must not change the Maven project version or `CHANGELOG.md`, or when the repository is not a Maven application. It provides the complete shared grouping and approval baseline without a post-upgrade task. All pull requests require manual merging.

### `default-no-version-bump-automerge`

Choose this when no Maven project version or changelog update is wanted and the repository has reliable CI for automatic routine updates. It combines `default-no-version-bump` with `automerge`. The grouped pull request is merged automatically only when every included update is eligible; otherwise the complete pull request remains manual.

## Single-purpose presets

### `automerge`

Enables pull request automerge for `pin`, `pinDigest`, `digest`, `patch`, and `minor` updates managed by Maven, Dockerfile, or Docker Compose. It sets `platformAutomerge` to `true`, allowing the hosting platform to merge the pull request after all branch policies and required checks pass. Renovate falls back to Renovate-based automerge if platform-native automerge is unavailable. Use only with reliable CI and correctly configured branch protection. It does not enable automerge for npm, GitHub Actions, or major updates.

Successful platform-native automerge does not require another Renovate run: the hosting platform waits for the configured requirements and then merges the pull request. If platform-native automerge is unavailable, Renovate falls back to Renovate-managed automerge. That fallback can require a subsequent run to observe successful status checks and processes at most one branch or pull request per target branch in each run. See [Renovate automerges take time](https://docs.renovatebot.com/key-concepts/automerge/#renovate-automerges-take-time) and the [`platformAutomerge` reference](https://docs.renovatebot.com/configuration-options/#platformautomerge).

### `post-upgrade`

Runs one branch-level task for Maven, Maven Wrapper, Dockerfile, and Docker Compose upgrades. If a root `pom.xml` exists, it propagates a project version bump with Maven:

| Highest dependency update | Project version bump |
| --- | --- |
| `major` | Next major version |
| `minor` | Next minor version |
| `patch`, `pin`, `pinDigest`, or `digest` | Next patch version |

If a root `CHANGELOG.md` exists and the Maven project version can be read, the task adds dependency update entries to that version's `Dependencies` section. It does not create `CHANGELOG.md` and does nothing for branches containing only unrelated managers such as npm.

This preset requires Renovate 41.1.0 or newer and a runner that permits the configured post-upgrade commands. The runner also needs `curl`, Node.js, Maven, and network access to the script hosted in this repository.

### `group-routine-maven-docker`

Groups `pin`, `pinDigest`, `digest`, `patch`, and `minor` updates from Maven, Dockerfile, and Docker Compose into one `routine Maven and Docker dependency updates` pull request with priority 1. Use it to avoid routine updates starving behind a low pull request creation limit.

### `group-major-maven-docker`

Groups all major Maven, Dockerfile, and Docker Compose updates into one `major Maven and Docker dependency updates` pull request with priority 0. It controls grouping only; Maven dashboard approval is supplied by a separate preset.

### `group-jeap-minor-patch`

Matches minor and patch updates for Maven coordinates beginning with `ch.admin.bit.jeap:`, groups them, and adds the `maven` and `jeap` labels. Use it independently when custom configuration needs a dedicated jEAP routine pull request. In the defaults, the later cross-manager rule overrides its group name but keeps its labels.

### `group-jeap-major`

Matches major updates for Maven coordinates beginning with `ch.admin.bit.jeap:`, adds the `maven`, `major`, and `jeap` labels, and disables Dependency Dashboard approval. Use it when jEAP majors should produce pull requests without prior dashboard approval. In the defaults, the later cross-manager rule overrides its group name but retains labels and approval behavior.

### `group-non-jeap-maven-deps-minor-patch`

Matches minor and patch updates for non-jEAP Maven parents, dependencies, and dependency-management entries. It groups them and adds the `maven` and `non-jeap` labels. Use it independently for a dedicated third-party dependency pull request. Its group name is overridden by cross-manager grouping in the defaults.

### `group-non-jeap-maven-plugins-minor-patch`

Matches minor and patch updates for non-jEAP Maven build plugins. It groups them and adds the `maven`, `plugin`, and `non-jeap` labels. Use it independently for a dedicated build-plugin pull request. Its group name is overridden by cross-manager grouping in the defaults.

### `dashboard-approval-maven-major`

Requires Dependency Dashboard approval and adds `maven` and `major` labels for all Maven major updates. Combine it with `group-jeap-major` when jEAP majors should be exempt: the later jEAP-specific rule disables approval for those coordinates.

### `ignore-unstable-maven-deps`

Ignores unstable Maven releases and timestamp-like versions, including 14-digit suffixes and Maven timestamp/build-number suffixes. Use it to prevent snapshots and repository-generated unstable builds from being proposed as normal upgrades.

### `ignore-kafka-message-deps`

Disables updates for Maven package names containing `.messagetype.`. Message-type dependencies are interfaces that require coordinated producer and consumer evolution, so they should be upgraded through the applicable compatibility process instead of an uncoordinated Renovate pull request. This preset is included in all default variants.

### `compatibility-aware-kafka-message-deps-app-specific`

Re-enables Maven package names containing `.messagetype.` and replaces normal Maven release lookup with the Message Contract Service datasource configured through the runner's `JEAP_MCS_PROD_BASE_URL` variable. Pass the application's exact MCS `appName` as the preset argument. MCS evaluates newer message-type versions against that application's latest PROD contracts, role, topic, and deployed counterparts. Add this preset after a default preset. This is the recommended mode.

### `compatibility-aware-kafka-message-deps-app-specific-dev`

Provides the same app-specific behavior through the Message Contract Service configured by the runner's `JEAP_MCS_DEV_BASE_URL` variable. Use it for development and end-to-end verification. It accepts the same `appName` argument and evaluates the latest DEV deployment records held by that service.

### `compatibility-aware-kafka-message-deps`

Re-enables Maven package names containing `.messagetype.` and returns only versions globally compatible with all relevant latest PROD contracts. It sends no `appName` and is an explicit, more conservative fallback. It is never selected automatically by an app-specific preset.

### `ignore-npm`

Disables the npm manager. Add it when a repository contains Node.js files for tooling or generated assets but npm dependencies are maintained through another process. Omit it when Renovate should update npm dependencies.

### `manual-angular-stack-major-updates`

Disables Renovate major updates for the coupled Angular frontend stack: Angular, Angular DevKit, Angular ESLint, Angular Builders, Angular schematics, Quadrel Enterprise UI, ngx-translate, and TypeScript. The same restriction applies to vulnerability-alert updates, so a security fix that requires crossing a configured major version is not proposed automatically. Minor and patch updates remain enabled.

Add this preset to Angular repositories whose major frontend upgrades are performed as coordinated manual migrations. It is not included in the default variants. When the repository configuration also contains `ignore-npm`, remove `ignore-npm`; otherwise Renovate cannot process the permitted minor and patch npm updates.

### `ignore-docker-compose`

Disables image updates detected in Docker Compose files. Add it when Compose files are examples, local-development fixtures, generated files, or otherwise not intended for automated image updates. It does not disable Dockerfile updates.

### `group-github-actions`

Groups all GitHub Actions updates into one pull request and pins action references to digests. Add it when workflow updates should be reviewed as a single, reproducible change. It is not included in the default variants.

### `group-all-into-one-pr`

Extends `config:recommended`, groups every update type from every manager and dependency type into one pull request, and limits both hourly and concurrent pull requests to one. It is included in all four default variants. Use it independently only when the other default behavior is not required.

## Related

- [Platform-team onboarding](onboarding.md)
- [Configuration examples](configuration-examples.md)
- [Repository overview](../README.md)
