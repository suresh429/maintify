#!/bin/bash
# Xcode Run Script Phase — copies the correct GoogleService-Info.plist
# based on the active build configuration.
#
# Add this script as a Run Script build phase in Xcode:
#   1. Open ios/Runner.xcworkspace in Xcode
#   2. Select Runner target → Build Phases → + → New Run Script Phase
#   3. Paste: bash "${SRCROOT}/copy_google_services.sh"
#   4. Drag the phase ABOVE "Copy Bundle Resources"
#   5. Under "Input Files" add:
#        $(SRCROOT)/config/dev/GoogleService-Info.plist
#        $(SRCROOT)/config/prod/GoogleService-Info.plist
#   6. Under "Output Files" add:
#        $(BUILT_PRODUCTS_DIR)/$(PRODUCT_NAME).app/GoogleService-Info.plist

set -e

PLIST_DEST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"

if [[ "${CONFIGURATION}" == *"dev"* || "${FLAVOR}" == "dev" ]]; then
  cp "${SRCROOT}/config/dev/GoogleService-Info.plist" "${PLIST_DEST}"
  echo "Copied DEV GoogleService-Info.plist"
elif [[ "${CONFIGURATION}" == *"prod"* || "${FLAVOR}" == "prod" ]]; then
  cp "${SRCROOT}/config/prod/GoogleService-Info.plist" "${PLIST_DEST}"
  echo "Copied PROD GoogleService-Info.plist"
else
  # Default to prod for safety (Release builds)
  cp "${SRCROOT}/config/prod/GoogleService-Info.plist" "${PLIST_DEST}"
  echo "Copied PROD GoogleService-Info.plist (default)"
fi
