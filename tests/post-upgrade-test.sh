#!/bin/bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SCRIPT="$REPO_ROOT/scripts/post-upgrade.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local expected="$2"
  grep -qF -- "$expected" "$file" || fail "Expected $file to contain: $expected"
}

assert_file_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -qF -- "$unexpected" "$file"; then
    fail "Expected $file not to contain: $unexpected"
  fi
}

assert_file_missing() {
  local file="$1"
  [ ! -e "$file" ] || fail "Expected $file to be missing"
}

write_pom() {
  local version="$1"
  cat > pom.xml <<EOF
<project>
  <modelVersion>4.0.0</modelVersion>
  <groupId>example</groupId>
  <artifactId>service</artifactId>
  <version>${version}</version>
</project>
EOF
}

write_changelog() {
  cat > CHANGELOG.md <<'EOF'
# Changelog

## [1.0.0] - 2026-01-01

### Added

- Initial entry
EOF
}

write_mvn_stub() {
  mkdir -p bin
  cat > bin/mvn <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> mvn.log
EOF
  chmod +x bin/mvn
  export PATH="$PWD/bin:$PATH"
}

run_post_upgrade() {
  RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE="$PWD/upgrades.json" bash "$SCRIPT"
}

run_case() {
  local name="$1"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  cd "$dir"
  export PATH_ORIGINAL="${PATH_ORIGINAL:-$PATH}"
  export PATH="$PATH_ORIGINAL"
}

run_case maven_update
write_pom "2.3.4-SNAPSHOT"
write_changelog
write_mvn_stub
cat > upgrades.json <<'EOF'
[
  {
    "depName": "ch.admin.bit.jeap:jeap-spring-boot-starter",
    "manager": "maven",
    "updateType": "minor",
    "currentVersion": "1.0.0",
    "newVersion": "1.1.0"
  }
]
EOF
run_post_upgrade
assert_file_contains mvn.log 'parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}'
assert_file_contains CHANGELOG.md '## [2.3.4] - '
assert_file_contains CHANGELOG.md '- **ch.admin.bit.jeap:jeap-spring-boot-starter**: 1.0.0 → 1.1.0 (minor)'

run_case docker_digest_update
write_pom "3.0.0-SNAPSHOT"
write_changelog
write_mvn_stub
cat > upgrades.json <<'EOF'
[
  {
    "depName": "repo.example.local/runtime",
    "manager": "dockerfile",
    "updateType": "digest",
    "currentVersion": null,
    "newVersion": null,
    "currentDigest": "sha256:abcdef1234567890",
    "newDigest": "sha256:1234567890abcdef"
  }
]
EOF
run_post_upgrade
assert_file_not_contains CHANGELOG.md 'null → null'
assert_file_contains CHANGELOG.md '- **repo.example.local/runtime**: sha256:abcdef123456 → sha256:1234567890ab (digest)'

run_case special_characters
write_pom "4.0.0-SNAPSHOT"
write_changelog
write_mvn_stub
cat > upgrades.json <<'EOF'
[
  {
    "depName": "repo.example/foo\"bar\\baz",
    "manager": "docker-compose",
    "updateType": "patch",
    "currentVersion": "1.0.0",
    "newVersion": "1.0.1"
  }
]
EOF
run_post_upgrade
assert_file_contains CHANGELOG.md '- **repo.example/foo"bar\baz**: 1.0.0 → 1.0.1 (patch)'

run_case missing_changelog
write_pom "5.0.0-SNAPSHOT"
write_mvn_stub
cat > upgrades.json <<'EOF'
[
  {
    "depName": "ch.admin.bit.jeap:example",
    "manager": "maven",
    "updateType": "patch",
    "currentVersion": "1.0.0",
    "newVersion": "1.0.1"
  }
]
EOF
run_post_upgrade
assert_file_missing CHANGELOG.md

run_case irrelevant_upgrade
write_pom "6.0.0-SNAPSHOT"
write_changelog
write_mvn_stub
cp CHANGELOG.md before.md
cat > upgrades.json <<'EOF'
[
  {
    "depName": "npm-package",
    "manager": "npm",
    "updateType": "minor",
    "currentVersion": "1.0.0",
    "newVersion": "1.1.0"
  }
]
EOF
run_post_upgrade
cmp -s before.md CHANGELOG.md || fail "Expected irrelevant upgrades to leave CHANGELOG.md unchanged"
assert_file_missing mvn.log

echo "post-upgrade tests ok"
