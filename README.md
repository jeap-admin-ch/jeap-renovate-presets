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

All four variants apply Renovate best practices, ignore unstable Maven versions and Kafka message-type dependencies, and group Maven, Dockerfile, and Docker Compose updates into a routine PR and a major PR. Automerge variants merge only routine `pin`, `pinDigest`, `digest`, `patch`, and `minor` updates; major updates remain manual.

With platform-native automerge, the hosting platform normally merges an enabled pull request as soon as its requirements pass. If platform-native automerge is unavailable and Renovate falls back to its own automerge, the merge may require a subsequent Renovate run; Renovate-managed automerge processes at most one branch or pull request per target branch in each run. See [Renovate automerges take time](https://docs.renovatebot.com/key-concepts/automerge/#renovate-automerges-take-time).

## Documentation

| Topic | Description |
| --- | --- |
| [Platform-team onboarding](docs/onboarding.md) | Opt-in flow, Dependency Dashboard, and update pull requests |
| [Preset reference](docs/presets.md) | Behavior and selection guidance for every preset |
| [Configuration examples](docs/configuration-examples.md) | Complete `renovate.json` examples for Maven, Dockerfile, Docker Compose, and npm |

## Compatibility-aware Kafka message dependencies POC

The opt-in `compatibility-aware-kafka-message-deps` preset keeps Maven dependency extraction but replaces
release lookup for packages containing `.messagetype.` with the Message Contract Service datasource. It can
be added after a default preset so that it supersedes `ignore-kafka-message-deps`:

```json
{
  "extends": [
    "github>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "github>jeap-admin-ch/jeap-renovate-presets//presets/compatibility-aware-kafka-message-deps"
  ]
}
```

The POC confirmed that `currentValue` is available to `defaultRegistryUrlTemplate`, but the MCS application name
is not. Each adopting repository must therefore override the datasource URL with its static `appName`. MCS uses
the highest uploaded non-SNAPSHOT Maven version for that application. The override below also replaces the POC
URL `host.docker.internal:18080` with the deployed service URL:

```json
{
  "customDatasources": {
    "jeap-message-contracts": {
      "defaultRegistryUrlTemplate": "https://message-contract-service.example/api/renovate/message-types/{{packageName}}?currentValue={{currentValue}}&appName=my-application&environment=PROD",
      "format": "json"
    }
  }
}
```

Configure authentication in the self-hosted Renovate runner, not in repository configuration or the shared
preset:

```json
{
  "hostRules": [
    {
      "matchHost": "message-contract-service.example",
      "username": "renovate",
      "password": "{{ secrets.MESSAGE_CONTRACT_SERVICE_PASSWORD }}"
    }
  ]
}
```

Run the routing POC with Docker:

```bash
./tests/renovate-compatibility-poc.sh
```

## Changes

Change log is available at [CHANGELOG.md](./CHANGELOG.md)

## Note

This repository is part of the open source distribution of jEAP. See [github.com/jeap-admin-ch/jeap](https://github.com/jeap-admin-ch/jeap)
for more information.

## License

This repository is Open Source Software licensed under the [Apache License 2.0](./LICENSE).
