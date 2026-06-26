#!/bin/bash
set -euo pipefail

# post-upgrade.sh
#
# Reads Renovate postUpgradeTasks data from RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE
# and:
#   1. Bumps the Maven project version in pom.xml (if present) based on the highest
#      update type across all upgrades (major > minor > patch/digest/pin).
#   2. Adds a CHANGELOG.md entry for every dependency update (if CHANGELOG.md exists).
#
# This script handles maven, maven-wrapper, dockerfile, and docker-compose updates.
# If no CHANGELOG.md exists in the project root, the changelog step is skipped without error.
# If no pom.xml exists, the version bump step is skipped without error.

UPGRADES_FILE="${RENOVATE_POST_UPGRADE_COMMAND_DATA_FILE:-/tmp/renovate-upgrades.json}"
CHANGELOG="CHANGELOG.md"

if [ ! -f "$UPGRADES_FILE" ]; then
  echo "WARNING: $UPGRADES_FILE not found. Was the upgrades JSON written by Renovate? Skipping Maven version and changelog update."
  exit 0
fi

RELEVANT_UPGRADES_FILE=$(mktemp)
trap 'rm -f "$RELEVANT_UPGRADES_FILE"' EXIT

node - "$UPGRADES_FILE" "$RELEVANT_UPGRADES_FILE" <<'NODE'
const fs = require("fs");
const [inputFile, outputFile] = process.argv.slice(2);
const upgrades = JSON.parse(fs.readFileSync(inputFile, "utf8"));
const relevantManagers = new Set(["maven", "maven-wrapper", "dockerfile", "docker-compose"]);
const relevant = upgrades.filter((upgrade) => relevantManagers.has(upgrade.manager));
fs.writeFileSync(outputFile, JSON.stringify(relevant));
NODE

if [ "$(node -e 'const fs = require("fs"); console.log(JSON.parse(fs.readFileSync(process.argv[1], "utf8")).length);' "$RELEVANT_UPGRADES_FILE")" -eq 0 ]; then
  echo "No Maven, Dockerfile, or Docker Compose upgrades found - skipping Maven version and changelog update."
  exit 0
fi

UPGRADES_FILE="$RELEVANT_UPGRADES_FILE"

# -- Version bump (only if pom.xml is present) -------------------------------

if [ -f "pom.xml" ]; then
  # Determine the highest update type across ALL upgrades in this branch.
  # digest / pin / pinDigest fall through to "patch".
  MAX_TYPE=$(node -e '
    const fs = require("fs");
    const upgrades = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const maxType = upgrades.some((upgrade) => upgrade.updateType === "major")
      ? "major"
      : upgrades.some((upgrade) => upgrade.updateType === "minor")
        ? "minor"
        : "patch";
    console.log(maxType);
  ' "$UPGRADES_FILE")

  case "$MAX_TYPE" in
    major)
      mvn build-helper:parse-version versions:set \
        -DnewVersion='${parsedVersion.nextMajorVersion}.0.0${parsedVersion.qualifier?}' \
        -DgenerateBackupPoms=false -B -q
      ;;
    minor)
      mvn build-helper:parse-version versions:set \
        -DnewVersion='${parsedVersion.majorVersion}.${parsedVersion.nextMinorVersion}.0${parsedVersion.qualifier?}' \
        -DgenerateBackupPoms=false -B -q
      ;;
    *)
      mvn build-helper:parse-version versions:set \
        -DnewVersion='${parsedVersion.majorVersion}.${parsedVersion.minorVersion}.${parsedVersion.nextIncrementalVersion}${parsedVersion.qualifier?}' \
        -DgenerateBackupPoms=false -B -q
      ;;
  esac
fi

# -- CHANGELOG update (only if CHANGELOG.md is present) ----------------------

if [ ! -f "$CHANGELOG" ]; then
  echo "No CHANGELOG.md found in project root - skipping changelog update."
  exit 0
fi

# Read the current version from pom.xml (after the potential version bump above),
# skipping the parent block and Maven property placeholders.
VERSION=""
if [ -f "pom.xml" ]; then
  VERSION=$(awk '
    /<parent>/{ in_parent=1 }
    /<\/parent>/{ in_parent=0; next }
    !in_parent && /<version>/ && !/\$\{/ {
      gsub(/.*<version>|<\/version>.*/, "")
      gsub(/-SNAPSHOT/, "")
      gsub(/[[:space:]]/, "")
      print
      exit
    }
  ' pom.xml)
fi

if [ -z "$VERSION" ]; then
  echo "WARNING: Could not read version from pom.xml - skipping changelog update."
  exit 0
fi

DATE=$(date +%Y-%m-%d)

# Add a single dependency entry to CHANGELOG.md.
# Handles four cases:
#   1. ## [VERSION] section exists and already has a ### Dependencies sub-section -> append entry
#   2. ## [VERSION] section exists but has no ### Dependencies sub-section -> insert sub-section
#   3. No ## [VERSION] section yet -> insert a new one before the first existing ## section
#   4. No ## sections at all -> append at the end
add_changelog_entry() {
  local DEP_NAME="$1"
  local VERSION_CHANGE="$2"
  local UPDATE_TYPE="$3"

  local ENTRY="- **${DEP_NAME}**: ${VERSION_CHANGE} (${UPDATE_TYPE})"

  # Skip if this exact entry already exists (idempotent)
  if grep -qF -- "$ENTRY" "$CHANGELOG"; then
    echo "Entry already exists, skipping: ${DEP_NAME} ${VERSION_CHANGE} (${UPDATE_TYPE})"
    return
  fi

  local TMPFILE
  TMPFILE=$(mktemp)

  if grep -q "^## \[${VERSION}\]" "$CHANGELOG"; then
    # Section for this version exists - check whether ### Dependencies already exists within it
    local VERSION_HAS_DEPS=false
    local IN_VERSION=false
    while IFS= read -r line; do
      if echo "$line" | grep -q "^## \[${VERSION}\]"; then
        IN_VERSION=true
      elif echo "$line" | grep -q "^## \["; then
        IN_VERSION=false
      fi
      if [ "$IN_VERSION" = true ] && [ "$line" = "### Dependencies" ]; then
        VERSION_HAS_DEPS=true
        break
      fi
    done < "$CHANGELOG"

    IN_VERSION=false
    while IFS= read -r line; do
      echo "$line" >> "$TMPFILE"
      if echo "$line" | grep -q "^## \[${VERSION}\]"; then
        IN_VERSION=true
      elif echo "$line" | grep -q "^## \["; then
        IN_VERSION=false
      fi
      if [ "$IN_VERSION" = true ] && [ "$VERSION_HAS_DEPS" = true ] && [ "$line" = "### Dependencies" ]; then
        echo "$ENTRY" >> "$TMPFILE"
      elif [ "$IN_VERSION" = true ] && [ "$VERSION_HAS_DEPS" = false ] && echo "$line" | grep -q "^## \[${VERSION}\]"; then
        echo "" >> "$TMPFILE"
        echo "### Dependencies" >> "$TMPFILE"
        echo "$ENTRY" >> "$TMPFILE"
      fi
    done < "$CHANGELOG"
  else
    # No section for this version yet - insert before the first existing ## section
    local HEADER_DONE=false
    while IFS= read -r line; do
      if [ "$HEADER_DONE" = false ] && echo "$line" | grep -q "^## \["; then
        HEADER_DONE=true
        echo "## [${VERSION}] - ${DATE}" >> "$TMPFILE"
        echo "" >> "$TMPFILE"
        echo "### Dependencies" >> "$TMPFILE"
        echo "$ENTRY" >> "$TMPFILE"
        echo "" >> "$TMPFILE"
      fi
      echo "$line" >> "$TMPFILE"
    done < "$CHANGELOG"

    # No ## sections found at all - append at end
    if [ "$HEADER_DONE" = false ]; then
      echo "" >> "$TMPFILE"
      echo "## [${VERSION}] - ${DATE}" >> "$TMPFILE"
      echo "" >> "$TMPFILE"
      echo "### Dependencies" >> "$TMPFILE"
      echo "$ENTRY" >> "$TMPFILE"
    fi
  fi

  mv "$TMPFILE" "$CHANGELOG"
  echo "Updated ${CHANGELOG}: [${VERSION}] ${DEP_NAME} ${VERSION_CHANGE} (${UPDATE_TYPE})"
}

# Process each dependency upgrade from the JSON file written by Renovate.
# The Node step normalizes missing values, avoids literal null entries, and skips
# upgrades that do not have enough version or digest data for a useful changelog line.
node - "$UPGRADES_FILE" <<'NODE' | while IFS=$'\t' read -r DEP_NAME VERSION_CHANGE UPDATE_TYPE; do
const fs = require("fs");
const upgrades = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const clean = (value) => String(value ?? "").replace(/[\t\r\n]/g, " ").trim();
const hasValue = (value) => value !== "" && value !== "null" && value !== "undefined";
const shortDigest = (value) => {
  if (!hasValue(value)) {
    return "";
  }
  const digest = clean(value);
  const [algorithm, hash] = digest.includes(":") ? digest.split(":", 2) : ["", digest];
  const shortHash = hash.slice(0, 12);
  return algorithm ? `${algorithm}:${shortHash}` : shortHash;
};
const pair = (from, to) => {
  if (hasValue(from) && hasValue(to)) {
    return `${from} → ${to}`;
  }
  if (hasValue(to)) {
    return `updated to ${to}`;
  }
  if (hasValue(from)) {
    return `updated from ${from}`;
  }
  return "";
};
const versionChangeFor = (upgrade) => {
  const updateType = clean(upgrade.updateType);
  const currentVersion = clean(upgrade.currentVersion);
  const newVersion = clean(upgrade.newVersion);
  const currentDigest = shortDigest(upgrade.currentDigest);
  const newDigest = shortDigest(upgrade.newDigest);

  if (updateType === "digest" || (!hasValue(currentVersion) && !hasValue(newVersion))) {
    const digestChange = pair(currentDigest, newDigest);
    if (!digestChange) {
      return "";
    }
    const version = hasValue(newVersion) ? newVersion : currentVersion;
    return hasValue(version) ? `${version} (${digestChange})` : digestChange;
  }

  return pair(currentVersion, newVersion);
};

for (const upgrade of upgrades) {
  const depName = clean(upgrade.depName);
  const updateType = clean(upgrade.updateType);
  const versionChange = versionChangeFor(upgrade);
  if (!depName || !updateType || !versionChange) {
    continue;
  }
  console.log([depName, versionChange, updateType].join("\t"));
}
NODE
  add_changelog_entry "$DEP_NAME" "$VERSION_CHANGE" "$UPDATE_TYPE"
done
