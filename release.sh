#!/usr/bin/env bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <version>  (e.g. $0 1.0.0)"
  exit 1
fi

VERSION="$1"

# Abort if working tree is dirty
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Error: working tree has uncommitted changes. Commit or stash first."
  exit 1
fi

# Verify CHANGELOG.md has a section for this version
if ! grep -q "^## \[$VERSION\]" CHANGELOG.md; then
  echo "Error: no '## [$VERSION]' section found in CHANGELOG.md"
  exit 1
fi

# Update CFBundleVersion in build.sh
sed -i '' "/CFBundleVersion</{n; s|<string>[^<]*</string>|<string>${VERSION}</string>|;}" build.sh

# Update CFBundleShortVersionString in build.sh
sed -i '' "/CFBundleShortVersionString/{n; s|<string>[^<]*</string>|<string>${VERSION}</string>|;}" build.sh

echo "Updated build.sh to version $VERSION"

BRANCH=$(git symbolic-ref --short HEAD)

git add build.sh
git commit -m "chore: release v${VERSION}"
git tag "v${VERSION}"
git push origin "$BRANCH"
git push origin "v${VERSION}"

echo "✓ Tagged v${VERSION} and pushed — CI will build and publish the release."
