#!/usr/bin/env bash
#
# Bumps the app version in the two places it has to match, then builds.
#
#   ./bump-version.sh 1.2.2
#
# pubspec.yaml carries the version Android installs and the build number it
# orders installs by; AppVersion.current is what the app tells the server it
# is. They are separate files and there is nothing in Dart that ties them
# together, so bumping one and forgetting the other is a one-character mistake
# with two silent outcomes: the update prompt nags people who are already
# current, or never appears for the people who are not.
#
# A test enforces the match. This stops you having to remember it in the first
# place.

set -euo pipefail

VERSION="${1:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./bump-version.sh 1.2.2" >&2
  exit 1
fi

cd "$(dirname "$0")/kaya_app"

# The build number after the plus is Android's versionCode. It must increase on
# every build that gets distributed, or Android refuses to install the new one
# over the old.
CURRENT_BUILD=$(grep '^version:' pubspec.yaml | sed 's/.*+//')
NEXT_BUILD=$((CURRENT_BUILD + 1))

sed -i "s|^version:.*|version: ${VERSION}+${NEXT_BUILD}|" pubspec.yaml
sed -i "s|^  static const String current = .*|  static const String current = '${VERSION}';|" \
  lib/core/constants/app_version.dart

echo "pubspec.yaml     -> ${VERSION}+${NEXT_BUILD}"
echo "AppVersion.current -> ${VERSION}"
echo
echo "Now run:"
echo "  flutter test                 # the version-match test must pass"
echo "  flutter build apk --release --dart-define=API_BASE_URL=https://kayaadmin.ucucite.tech"
echo
echo "Then upload the APK to Drive (Manage versions, same file), and on the server:"
echo "  sed -i 's|^APP_LATEST_VERSION=.*|APP_LATEST_VERSION=${VERSION}|' .env && php artisan config:clear"
