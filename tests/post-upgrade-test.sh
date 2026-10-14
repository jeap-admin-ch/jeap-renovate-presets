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
if [[ " $* " == *" help:effective-pom "* ]]; then
  [ "${FAIL_EFFECTIVE_POM:-false}" != true ] || exit 1
  for arg in "$@"; do
    if [[ "$arg" == -Doutput=* ]]; then
      cp "${EFFECTIVE_POM_FIXTURE:-pom.xml}" "${arg#-Doutput=}"
    fi
  done
fi
if [[ " $* " == *" spotless:apply "* ]]; then
  [ "${FAIL_SPOTLESS:-false}" != true ] || exit 1
  mkdir -p src/main/java
  echo '// formatted' > src/main/java/Example.java
fi
EOF
  chmod +x bin/mvn
  export PATH="$PWD/bin:$PATH"
}

run_post_upgrade() {
  RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE="$PWD/upgrades.json" bash "$SCRIPT"
}

run_post_upgrade_missing_data_file() {
  RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE="$PWD/missing-upgrades.json" bash "$SCRIPT"
}

run_case() {
  local name="$1"
  local dir="$TMP_ROOT/$name"
  mkdir -p "$dir"
  cd "$dir"
  export PATH_ORIGINAL="${PATH_ORIGINAL:-$PATH}"
  export PATH="$PATH_ORIGINAL"
  unset EFFECTIVE_POM_FIXTURE FAIL_EFFECTIVE_POM FAIL_SPOTLESS
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
assert_file_not_contains mvn.log 'spotless:apply'

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

run_case missing_data_file
write_pom "7.0.0-SNAPSHOT"
write_changelog
write_mvn_stub
cp CHANGELOG.md before.md
run_post_upgrade_missing_data_file
cmp -s before.md CHANGELOG.md || fail "Expected missing data file to leave CHANGELOG.md unchanged"
assert_file_missing mvn.log

write_maven_upgrade() {
  echo '[{"manager":"maven","updateType":"patch"}]' > upgrades.json
}

write_spotless_reactor() {
  export EFFECTIVE_POM_FIXTURE="$PWD/effective-pom.xml"
  cat > "$EFFECTIVE_POM_FIXTURE" <<'EOF'
<projects>
  <project xmlns="http://maven.apache.org/POM/4.0.0">
    <groupId>example</groupId><artifactId>parent</artifactId>
    <build><pluginManagement><plugins><plugin>
      <groupId>com.diffplug.spotless</groupId><artifactId>spotless-maven-plugin</artifactId>
    </plugin></plugins></pluginManagement></build>
  </project>
  <project xmlns="http://maven.apache.org/POM/4.0.0">
    <groupId>example</groupId><artifactId>wvs-condition-service</artifactId>
    <build><plugins><plugin>
      <groupId>com.diffplug.spotless</groupId><artifactId>spotless-maven-plugin</artifactId>
    </plugin></plugins></build>
  </project>
  <project xmlns="http://maven.apache.org/POM/4.0.0">
    <groupId>example</groupId><artifactId>inherited-plugin</artifactId>
    <build><plugins><plugin>
      <groupId>com.diffplug.spotless</groupId><artifactId>spotless-maven-plugin</artifactId>
    </plugin></plugins></build>
  </project>
  <project xmlns="http://maven.apache.org/POM/4.0.0">
    <groupId>example</groupId><artifactId>inactive-profile</artifactId>
    <profiles><profile><build><plugins><plugin>
      <groupId>com.diffplug.spotless</groupId><artifactId>spotless-maven-plugin</artifactId>
    </plugin></plugins></build></profile></profiles>
  </project>
</projects>
EOF
}

run_case spotless_modules_without_changelog
write_pom "1.0.0"
write_mvn_stub
write_maven_upgrade
write_spotless_reactor
run_post_upgrade
assert_file_contains mvn.log '-B spotless:apply -pl example:wvs-condition-service,example:inherited-plugin'
assert_file_not_contains mvn.log 'example:parent'
assert_file_not_contains mvn.log 'example:inactive-profile'
assert_file_contains src/main/java/Example.java '// formatted'
assert_file_missing CHANGELOG.md

run_case spotless_single_project_wrapper
write_pom "1.0.0"
write_changelog
write_mvn_stub
echo '[{"manager":"maven-wrapper","updateType":"patch"}]' > upgrades.json
cat > mvnw <<'EOF'
#!/bin/bash
echo "$*" >> wrapper.log
exec mvn "$@"
EOF
# An executable bit is not required for the wrapper.
export EFFECTIVE_POM_FIXTURE="$PWD/effective-pom.xml"
cat > "$EFFECTIVE_POM_FIXTURE" <<'EOF'
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <groupId>example</groupId><artifactId>service</artifactId>
  <build><plugins><plugin>
    <groupId>com.diffplug.spotless</groupId><artifactId>spotless-maven-plugin</artifactId>
  </plugin></plugins></build>
</project>
EOF
run_post_upgrade
assert_file_contains wrapper.log 'help:effective-pom'
assert_file_contains wrapper.log '-B spotless:apply -pl example:service'

run_case spotless_failure
write_pom "1.0.0"
write_mvn_stub
write_maven_upgrade
write_spotless_reactor
export FAIL_SPOTLESS=true
if run_post_upgrade; then fail 'Spotless errors must fail the task'; fi

run_case effective_pom_failure
write_pom "1.0.0"
write_mvn_stub
write_maven_upgrade
export FAIL_EFFECTIVE_POM=true
if run_post_upgrade; then fail 'Effective POM errors must fail the task'; fi
assert_file_not_contains mvn.log 'spotless:apply'

run_case docker_only_skips_spotless
write_pom "1.0.0"
write_mvn_stub
write_spotless_reactor
echo '[{"manager":"dockerfile","updateType":"patch"}]' > upgrades.json
run_post_upgrade
assert_file_not_contains mvn.log 'help:effective-pom'
assert_file_not_contains mvn.log 'spotless:apply'

run_case no_root_pom
write_mvn_stub
write_maven_upgrade
run_post_upgrade
assert_file_missing mvn.log

echo "post-upgrade tests ok"
