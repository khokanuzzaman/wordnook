#!/usr/bin/env bash
# Builds a Play-ready release App Bundle with the REAL AdMob ids, signed with
# the upload key.
#
# Needs two gitignored files:
#   android/key.properties   storePassword / keyPassword / keyAlias / storeFile
#   android/admob.properties ADMOB_APP_ID_ANDROID + ADMOB_REWARDED /
#                            _INTERSTITIAL / _BANNER (see admob.properties.example)
#
# Refuses to build (instead of silently falling back) when either file is
# missing, an ad id is empty, or an id is one of Google's public TEST ids, so a
# debug-signed or test-ads bundle can never reach Play by accident.
# ADMOB_TEST_DEVICE_IDS is deliberately NOT passed: it is for local debugging.
#
# Usage:  bash scripts/build_release_aab.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PROPS="android/admob.properties"
KEYPROPS="android/key.properties"
GOOGLE_TEST_PUBLISHER="ca-app-pub-3940256099942544"

die() { echo "ERROR: $*" >&2; exit 1; }

[[ -f "$KEYPROPS" ]] || die "$KEYPROPS not found — the bundle would be debug-signed."
[[ -f "$PROPS" ]] || die "$PROPS not found — the bundle would ship TEST ads."

# Read a single key from a properties file (everything after the first '=').
# Avoids `source <(...)`, which fails silently under set -euo pipefail on macOS bash.
prop() { grep -E "^$2=" "$1" | head -1 | cut -d= -f2- | tr -d '[:space:]' || true; }

for k in storePassword keyPassword keyAlias storeFile; do
  [[ -n "$(prop "$KEYPROPS" "$k")" ]] || die "$k is empty in $KEYPROPS."
done
STORE_FILE="$(prop "$KEYPROPS" storeFile)"
# Gradle resolves storeFile relative to android/app/.
if [[ "$STORE_FILE" != /* ]]; then STORE_FILE="android/app/$STORE_FILE"; fi
[[ -f "$STORE_FILE" ]] || die "keystore not found at $STORE_FILE (storeFile is relative to android/app/)."

for k in ADMOB_APP_ID_ANDROID ADMOB_REWARDED ADMOB_INTERSTITIAL ADMOB_BANNER; do
  v="$(prop "$PROPS" "$k")"
  [[ -n "$v" ]] || die "$k is empty in $PROPS."
  [[ "$v" != "$GOOGLE_TEST_PUBLISHER"* ]] || die "$k is Google's TEST id."
done

flutter build appbundle --release \
  --dart-define=ADMOB_REWARDED="$(prop "$PROPS" ADMOB_REWARDED)" \
  --dart-define=ADMOB_INTERSTITIAL="$(prop "$PROPS" ADMOB_INTERSTITIAL)" \
  --dart-define=ADMOB_BANNER="$(prop "$PROPS" ADMOB_BANNER)"

echo
echo "Done → build/app/outputs/bundle/release/app-release.aab"
