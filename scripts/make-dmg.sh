#!/usr/bin/env bash
# make-dmg.sh — Build Inkling.app and package it as a DMG.
#
# Usage:
#   ./scripts/make-dmg.sh                   # builds Release, outputs ./Inkling.dmg
#   VERSION=0.2.0 ./scripts/make-dmg.sh     # tags the DMG name
#
# Prereqs: xcodegen, Xcode command-line tools, hdiutil (built-in).
#
# Output: ./Inkling-<version>.dmg in the repo root, ready to upload to a
# GitHub release.

set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${VERSION:-dev}"
APP_NAME="Inkling"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
BUILD_DIR=".build-dmg"
STAGE_DIR="${BUILD_DIR}/stage"

echo "==> Regenerating Xcode project"
xcodegen generate >/dev/null

echo "==> Building Release"
xcodebuild \
  -project "${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -derivedDataPath "${BUILD_DIR}/derived" \
  build >/dev/null

APP_PATH="${BUILD_DIR}/derived/Build/Products/Release/${APP_NAME}.app"
[ -d "${APP_PATH}" ] || { echo "Build did not produce ${APP_PATH}"; exit 1; }

echo "==> Ad-hoc signing"
codesign --force --deep --sign - "${APP_PATH}" >/dev/null

echo "==> Staging DMG contents"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp -R "${APP_PATH}" "${STAGE_DIR}/${APP_NAME}.app"
ln -s /Applications "${STAGE_DIR}/Applications"

echo "==> Creating ${DMG_NAME}"
rm -f "${DMG_NAME}"
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "${STAGE_DIR}" \
  -ov \
  -format UDZO \
  "${DMG_NAME}" >/dev/null

echo "==> Cleanup"
rm -rf "${BUILD_DIR}"

SIZE=$(du -h "${DMG_NAME}" | awk '{print $1}')
echo
echo "Done: ${DMG_NAME} (${SIZE})"
echo "Upload via: gh release create v${VERSION} ${DMG_NAME} --title \"v${VERSION}\" --notes \"...\""
