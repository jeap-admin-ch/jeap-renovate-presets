# Renovate configuration examples

Place `renovate.json` at the repository root. Configure a repository in two steps:

1. Choose one of the four default variants based on project versioning, changelog, and automerge requirements.
2. Add manager-specific presets such as `ignore-npm` or `ignore-docker-compose` only when Renovate must ignore those files.

The default variant is not selected by dependency manager. All four variants detect Maven, Dockerfile, and Docker Compose dependencies. The `no-version-bump` variants are for any repository where Renovate must not change the Maven project version or `CHANGELOG.md`; they are not Docker-specific presets.

## Choose a default configuration

The platform's planned onboarding configurations include `ignore-npm`. Remove that preset when Renovate should update npm dependencies.

### `default`

Choose `default` when Renovate should bump the Maven project version, update an existing root `CHANGELOG.md`, and leave every pull request for manual merging.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

### `default-automerge`

Choose `default-automerge` when the same version and changelog updates are required and reliable CI makes automatic routine Maven, Dockerfile, and Docker Compose updates safe. Major updates remain manual.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-automerge",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

### `default-no-version-bump`

Choose `default-no-version-bump` when Renovate must not change the Maven project version or `CHANGELOG.md` and pull requests require manual review. This applies equally to Maven, Docker, and mixed repositories whose version is owned by another release process.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-no-version-bump",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

### `default-no-version-bump-automerge`

Choose `default-no-version-bump-automerge` when no Maven project version or changelog changes are wanted and reliable CI makes automatic routine Maven, Dockerfile, and Docker Compose updates safe. Major updates remain manual.

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-no-version-bump-automerge",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

## Adapt the configuration by manager

Renovate detects supported dependency files automatically. The examples below show common manager combinations, but the default variant must still be selected from the versioning and automerge requirements described above.

### Maven application

For a versioned Maven application whose project version and existing changelog should follow dependency updates, use the planned `default` onboarding configuration:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

Use a `no-version-bump` variant instead when another release process owns the project version, even though the repository is a Maven application. Select an automerge variant independently based on CI quality.

### Dockerfile project

For a Dockerfile-only repository with no Maven project version or changelog to maintain, a no-version-bump variant communicates that intent clearly:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-no-version-bump",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-docker-compose",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

This updates Dockerfile images while explicitly excluding Compose and npm updates. Remove `ignore-docker-compose` when both Dockerfile and Compose images should be maintained. If a Maven application also contains a Dockerfile and dependency updates should bump its project version, use `default` rather than `default-no-version-bump`. The default grouping separates routine and major Maven and Docker updates.

### Docker Compose project

For a Compose-only repository with no Maven project version or changelog to maintain, use:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-no-version-bump",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

This enables image updates in `compose.yaml`, `compose.yml`, `docker-compose.yaml`, and `docker-compose.yml`. Dockerfile updates are also enabled if a Dockerfile is present. For a versioned Maven application that also uses Compose, select `default` when Docker image updates should bump the application version and update its existing changelog. Select an automerge variant independently based on CI quality.

### npm project

For an npm-only project, omit `ignore-npm`. A no-version-bump default communicates that no Maven project version or changelog should be changed:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default-no-version-bump",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-docker-compose"
  ]
}
```

The jEAP routine grouping and automerge rules do not match npm. npm updates therefore follow Renovate's best-practice defaults unless the repository adds npm-specific `packageRules`. In a mixed Maven and npm repository, select the default variant based on Maven project versioning, omit `ignore-npm`, and remove `ignore-docker-compose` if Compose image dependencies should also be updated.

## Custom composition

A repository does not have to extend a default. This example creates separate jEAP major and routine pull requests, automatically merges only jEAP minor and patch updates, and groups GitHub Actions updates:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "config:best-practices",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/group-jeap-major",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/group-github-actions"
  ],
  "packageRules": [
    {
      "description": "Group and automerge jEAP minor and patch updates",
      "extends": [
        "local>jeap-admin-ch/jeap-renovate-presets//presets/group-jeap-minor-patch"
      ],
      "automerge": true,
      "automergeType": "pr",
      "platformAutomerge": true
    }
  ]
}
```

Repository-level rules are applied with the other Renovate package rules. Review matching and rule order carefully when multiple rules set scalar fields such as `groupName`, `dependencyDashboardApproval`, or `automerge`.

With `platformAutomerge` enabled, the hosting platform normally merges the pull request after its requirements pass without waiting for another Renovate run. If platform-native automerge is unavailable, Renovate's fallback may need a subsequent run to observe the result and perform the merge. See [Renovate automerges take time](https://docs.renovatebot.com/key-concepts/automerge/#renovate-automerges-take-time).

## Related

- [Platform-team onboarding](onboarding.md)
- [Preset reference](presets.md)
- [Renovate configuration options](https://docs.renovatebot.com/configuration-options/)
- [Renovate presets](https://docs.renovatebot.com/presets-config/)
