#!/usr/bin/env bash
# Builds a Play-ready release App Bundle with the REAL AdMob ids.
#
# Reads ad-unit ids from android/admob.properties (gitignored) and passes them
# as --dart-define values. The AdMob *app id* is injected separately by Gradle
# (also from android/admob.properties) into the manifest. If the file or any id
# is missing, the corresponding placement falls back to Google's TEST ids.
#
# Usage:  bash scripts/build_release_aab.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROPS="android/admob.properties"
# Read a single key from the properties file (everything after the first '=').
# Avoids `source <(...)`, which fails silently under set -euo pipefail on macOS bash.
prop() { [ -f "$PROPS" ] && grep -E "^$1=" "$PROPS" | head -1 | cut -d= -f2- || true; }

REWARDED="$(prop ADMOB_REWARDED)"
INTERSTITIAL="$(prop ADMOB_INTERSTITIAL)"
BANNER="$(prop ADMOB_BANNER)"

if [[ ! -f "$PROPS" ]]; then
  echo "WARNING: $PROPS not found — building with TEST ad unit ids." >&2
fi

flutter build appbundle --release \
  --dart-define=ADMOB_REWARDED="$REWARDED" \
  --dart-define=ADMOB_INTERSTITIAL="$INTERSTITIAL" \
  --dart-define=ADMOB_BANNER="$BANNER"

echo
echo "Done → build/app/outputs/bundle/release/app-release.aab"
