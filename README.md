# jeap-renovate-presets

Renovate presets for jEAP based projects.

## Overview

This repository contains presets for managing dependency updates in jEAP-based projects with Renovate.

## Usage

To use one or more of these presets reference them in your project's `renovate.json` file:

```json
{
  "extends": [
    "github>jeap-admin-ch/jeap-renovate-presets//presets/default"
  ]
}
```

## Default presets

| Preset | Maven project version bump | CHANGELOG.md update | Automerge |
| --- | --- | --- | --- |
| `default` | Yes | Yes, if `CHANGELOG.md` exists | No |
| `default-automerge` | Yes | Yes, if `CHANGELOG.md` exists | Yes |
| `default-no-version-bump` | No | No | No |
| `default-no-version-bump-automerge` | No | No | Yes |

The post-upgrade presets update `CHANGELOG.md` only when a root `CHANGELOG.md` already exists; they never create a new changelog file.

The `post-upgrade` preset requires Renovate `41.1.0` or newer. It depends on Renovate's `postUpgradeTasks.dataFileTemplate`, `{{{ toJSON upgrades }}}`, and `RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE` support.

## Changes

Change log is available at [CHANGELOG.md](./CHANGELOG.md)

## Note

This repository is part of the open source distribution of jEAP. See [github.com/jeap-admin-ch/jeap](https://github.com/jeap-admin-ch/jeap)
for more information.

## License

This repository is Open Source Software licensed under the [Apache License 2.0](./LICENSE).
