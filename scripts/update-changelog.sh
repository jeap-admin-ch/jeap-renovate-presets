#!/bin/bash
# DEPRECATED: This script is replaced by scripts/post-upgrade.sh which handles
# both Maven version bumping and changelog updates in a single branch-level postUpgradeTask.
# This file is kept for backwards compatibility only and will be removed in a future release.
set -euo pipefail

UPDATE_TYPE="${1:-unknown}"
DEP_NAME="${2:-unknown}"
OLD_VERSION="${3:-unknown}"
NEW_VERSION="${4:-unknown}"

CHANGELOG="CHANGELOG.md"
DATE=$(date +%Y-%m-%d)
ENTRY="- **${DEP_NAME}**: ${OLD_VERSION} → ${NEW_VERSION} (${UPDATE_TYPE})"

# Extract version from root pom.xml, skipping parent block and Maven properties
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

if [ -z "$VERSION" ]; then
  echo "ERROR: Could not read version from pom.xml"
  exit 1
fi

# Skip if entry already exists
if [ -f "$CHANGELOG" ] && grep -qF "${DEP_NAME}: ${OLD_VERSION} → ${NEW_VERSION}" "$CHANGELOG"; then
  echo "Entry already exists, skipping"
  exit 0
fi

# Create CHANGELOG if it doesn't exist
if [ ! -f "$CHANGELOG" ]; then
  cat > "$CHANGELOG" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres
to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
EOF
fi

TMPFILE=$(mktemp)

if grep -q "## \[${VERSION}\]" "$CHANGELOG"; then
  # Section for this version exists — append entry
  if grep -q "### Dependencies" "$CHANGELOG"; then
    # Check if the ### Dependencies heading exists within the target version's section
    IN_VERSION=false
    VERSION_HAS_DEPS=false
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
    while IFS= read -r line; do
      echo "$line" >> "$TMPFILE"
      if echo "$line" | grep -q "^## \[${VERSION}\]"; then
        echo "" >> "$TMPFILE"
        echo "### Dependencies" >> "$TMPFILE"
        echo "$ENTRY" >> "$TMPFILE"
      fi
    done < "$CHANGELOG"
  fi
else
  # No section for this version — insert before first existing ## section
  HEADER_DONE=false
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

  # If no ## section was found, append at the end
  if [ "$HEADER_DONE" = false ]; then
    echo "" >> "$TMPFILE"
    echo "## [${VERSION}] - ${DATE}" >> "$TMPFILE"
    echo "" >> "$TMPFILE"
    echo "### Dependencies" >> "$TMPFILE"
    echo "$ENTRY" >> "$TMPFILE"
  fi
fi

mv "$TMPFILE" "$CHANGELOG"
echo "Updated ${CHANGELOG}: [${VERSION}] ${DEP_NAME} ${OLD_VERSION} → ${NEW_VERSION}"