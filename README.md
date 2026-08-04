# jeap-renovate-presets

Renovate presets for jEAP based projects.

## Overview

[Renovate](https://docs.renovatebot.com/) is an open-source dependency update tool. It scans dependency files such as Maven POMs, Dockerfiles, Docker Compose files, and npm manifests, detects available updates, and opens pull requests with the required version changes and available release information. Its Dependency Dashboard provides a central view of pending, blocked, and open updates.

Regular automated updates help teams adopt security and bug fixes sooner and replace large, infrequent upgrade efforts with smaller, reviewable changes. Teams remain in control: updates can require manual approval and review, or eligible low-risk updates can be merged automatically after CI and branch protection requirements pass.

This repository provides composable jEAP presets that standardize grouping, approval, versioning, changelog, and automerge behavior for Maven, Dockerfile, Docker Compose, npm, and GitHub Actions dependencies. They give platform teams a common starting point while allowing each repository to adapt Renovate to its release process and test coverage.

## Onboarding

Platform teams receive an opt-in pull request titled `feat: Onboarding to renovate (opt-in)`. It adds a `renovate.json` at the repository root. Review the proposed configuration, select the default variant that matches the project, and merge the pull request to enable Renovate.

The planned initial configuration enables the jEAP default behavior and ignores npm dependencies:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

Teams can change `renovate.json` at any time, choose another default variant, or compose the single-purpose presets directly. Renovate applies the change on its next run.

## Choose a default preset

| Preset | Choose when | Maven project version bump | Existing `CHANGELOG.md` update | Routine update automerge |
| --- | --- | --- | --- | --- |
| `default` | The repository is a versioned Maven application and dependency PRs require review | Yes | Yes | No |
| `default-automerge` | The repository is a versioned Maven application with reliable CI and branch protection | Yes | Yes | Yes |
| `default-no-version-bump` | Renovate must not change the project version, or the repository is not a Maven application | No | No | No |
| `default-no-version-bump-automerge` | The project needs no version bump and reliable CI makes routine automerge safe | No | No | Yes |

All four variants apply Renovate best practices, ignore unstable Maven versions and Kafka message-type dependencies, and group updates from all managers and dependency types into one pull request. Automerge variants merge the grouped pull request only when every included update is eligible for automerge. A major update or an update from a manager outside Maven, Dockerfile, and Docker Compose keeps the complete pull request manual.

With platform-native automerge, the hosting platform normally merges an enabled pull request as soon as its requirements pass. If platform-native automerge is unavailable and Renovate falls back to its own automerge, the merge may require a subsequent Renovate run; Renovate-managed automerge processes at most one branch or pull request per target branch in each run. See [Renovate automerges take time](https://docs.renovatebot.com/key-concepts/automerge/#renovate-automerges-take-time).

## Documentation

| Topic | Description |
| --- | --- |
| [Platform-team onboarding](docs/onboarding.md) | Opt-in flow, Dependency Dashboard, and update pull requests |
| [Preset reference](docs/presets.md) | Behavior and selection guidance for every preset |
| [Configuration examples](docs/configuration-examples.md) | Complete `renovate.json` examples for Maven, Dockerfile, Docker Compose, and npm |

## Compatibility-aware Kafka message dependencies

The opt-in compatibility presets keep Maven dependency extraction but route release lookup for packages containing
`.messagetype.` to the production Message Contract Service (MCS). Add one of them after a default preset so its
`enabled: true` rule supersedes the default `ignore-kafka-message-deps` rule.

The recommended preset is `compatibility-aware-kafka-message-deps-app-specific`. Teams normally pass only the MCS
application name and do not override the datasource:

```json
{
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/compatibility-aware-kafka-message-deps-app-specific(my-application)"
  ]
}
```

`appName` is the application's `spring.application.name` represented in its uploaded MCS message contracts. MCS uses
it to find the application's latest PROD deployment and derive the relevant role and topic from its contracts. There
is no `appVersion` preset parameter.

Use `compatibility-aware-kafka-message-deps` only as an explicit fallback when no application-specific compatibility
context is available. It requests versions globally compatible in PROD and sends no `appName`:

```json
{
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/compatibility-aware-kafka-message-deps"
  ]
}
```

The app-specific preset does not automatically fall back to global compatibility if MCS cannot answer. The production
presets use the `JEAP_MCS_PROD_BASE_URL` variable configured by the self-hosted Renovate runner; repository
configurations should not replace it under normal operation.

For development and end-to-end verification, `compatibility-aware-kafka-message-deps-app-specific-dev` provides the
same app-specific behavior through the DEV Message Contract Service endpoint. It evaluates the latest `DEV` deployment
records held by that service:

```json
{
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/compatibility-aware-kafka-message-deps-app-specific-dev(my-application)"
  ]
}
```

The self-hosted Renovate runner owns MCS authentication and TLS trust. Teams do not add credentials to repository
configuration or shared presets. Runner administrators must configure `JEAP_MCS_PROD_BASE_URL` and
`JEAP_MCS_DEV_BASE_URL` as Renovate variables and provide matching authenticated host rules.

## Changes

Change log is available at [CHANGELOG.md](./CHANGELOG.md)

## Note

This repository is part of the open source distribution of jEAP. See [github.com/jeap-admin-ch/jeap](https://github.com/jeap-admin-ch/jeap)
for more information.

## License

This repository is Open Source Software licensed under the [Apache License 2.0](./LICENSE).
