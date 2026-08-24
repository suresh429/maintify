#!/bin/bash
# Xcode Run Script Phase — injects the correct GADApplicationIdentifier
# into the built Info.plist based on the active build configuration (flavor).
#
# !! BEFORE PUBLISHING !!
# Replace the PROD_ADMOB_APP_ID placeholder below with your real production
# iOS AdMob App ID. Get it from:
#   AdMob Console → Apps → Your iOS App → App settings → App ID
#
# How to add this script to Xcode:
#   1. Open ios/Runner.xcworkspace in Xcode
#   2. Select Runner target → Build Phases → + → New Run Script Phase
#   3. Paste: bash "${SRCROOT}/inject_admob_id.sh"
#   4. Drag the phase AFTER "Copy Bundle Resources"
#   5. Under "Input Files" add: (none required)
#   6. Under "Output Files" add: (none required)

set -e

# ── AdMob App IDs ────────────────────────────────────────────────────────────
DEV_ADMOB_APP_ID="ca-app-pub-3940256099942544~1458002511"   # Google test App ID
PROD_ADMOB_APP_ID="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"  # TODO: replace with real prod ID

# ── Select ID based on flavor ────────────────────────────────────────────────
if [[ "${CONFIGURATION}" == *"dev"* || "${FLAVOR}" == "dev" ]]; then
  ADMOB_APP_ID="${DEV_ADMOB_APP_ID}"
  echo "Injecting DEV AdMob App ID"
elif [[ "${CONFIGURATION}" == *"prod"* || "${FLAVOR}" == "prod" ]]; then
  ADMOB_APP_ID="${PROD_ADMOB_APP_ID}"
  echo "Injecting PROD AdMob App ID"
else
  # Default to dev (test ID) for safety — never accidentally use an unset prod ID
  ADMOB_APP_ID="${DEV_ADMOB_APP_ID}"
  echo "Injecting DEV AdMob App ID (default fallback)"
fi

# ── Inject into the built Info.plist ────────────────────────────────────────
/usr/libexec/PlistBuddy \
  -c "Set :GADApplicationIdentifier ${ADMOB_APP_ID}" \
  "${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

echo "GADApplicationIdentifier set to: ${ADMOB_APP_ID}"
