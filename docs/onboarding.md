# Platform-team onboarding

Renovate scans dependency declarations and opens pull requests for available updates. The jEAP presets provide consistent grouping, approval, versioning, and optional automerge behavior for repositories onboarded by platform teams.

## Opt-in flow

1. The platform enables the repository in the centrally operated Renovate service.
2. Renovate opens a pull request titled `feat: Onboarding to renovate (opt-in)`.
3. The pull request contains a root-level `renovate.json` and previews the managers and pending updates Renovate detected.
4. The team reviews the proposed configuration and selects the appropriate [default preset](presets.md#default-presets). The initial proposal can be changed before it is merged.
5. Merging the onboarding pull request enables dependency update pull requests for the repository.

The planned initial configuration is:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": [
    "local>jeap-admin-ch/jeap-renovate-presets//presets/default",
    "local>jeap-admin-ch/jeap-renovate-presets//presets/ignore-npm"
  ]
}
```

This is a starting point, not a permanent platform restriction. A team can edit `renovate.json` at any time to switch between default variants, enable npm, disable Docker Compose updates, or compose [single-purpose presets](presets.md#single-purpose-presets). Renovate reads the new configuration on its next run.

## After onboarding

Renovate creates a Dependency Dashboard as a GitHub issue. It lists detected dependencies, open update branches and pull requests, rate-limited or paused updates, and updates that require approval. Use it to approve non-jEAP Maven major updates and to request retries or rebases where supported by the platform configuration.

Update pull requests follow the selected presets. All default variants group updates from all managers and dependency types into one pull request. With the non-automerge defaults, the team reviews and merges it manually. With an automerge default, Renovate merges the grouped pull request only when every included update is an eligible routine Maven, Dockerfile, or Docker Compose update and all required checks and branch protection conditions pass. A major update or an update from another manager keeps the complete pull request manual.

With platform-native automerge, the hosting platform normally merges an enabled pull request independently as soon as its requirements pass. If platform-native automerge is unavailable, Renovate falls back to its own automerge. That fallback may create the pull request in one run and merge it in a subsequent run after observing successful status checks. Renovate-managed automerge also processes at most one branch or pull request per target branch in each run so it can recalculate the remaining branches against the updated base branch. See [Renovate automerges take time](https://docs.renovatebot.com/key-concepts/automerge/#renovate-automerges-take-time).

Renovate processes configuration changes, approvals, and rebase requests during a subsequent bot run.

## Related

- [Preset reference](presets.md)
- [Configuration examples](configuration-examples.md)
- [Repository overview](../README.md)
