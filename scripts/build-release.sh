#!/usr/bin/env bash
set -euo pipefail

# Usage: TEAM_ID=XXXXXXXXXX NOTARY_PROFILE=voicedrop-notary ./scripts/build-release.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

# ── Prerequisites ─────────────────────────────────────────────────────────────

echo "==> [1/7] Checking prerequisites"

if [[ -z "${TEAM_ID:-}" ]]; then
    echo "ERROR: TEAM_ID env var is required (e.g. TEAM_ID=XXXXXXXXXX)" >&2
    exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    echo "ERROR: NOTARY_PROFILE env var is required (e.g. NOTARY_PROFILE=voicedrop-notary)" >&2
    exit 1
fi

if ! command -v create-dmg &>/dev/null; then
    echo "ERROR: create-dmg not found — run: brew install create-dmg" >&2
    exit 1
fi

# Verify notarytool can find the stored profile
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" &>/dev/null; then
    echo "ERROR: notarytool profile '$NOTARY_PROFILE' not found in keychain." >&2
    echo "       Run: xcrun notarytool store-credentials \"$NOTARY_PROFILE\" \\" >&2
    echo "              --apple-id you@example.com --team-id $TEAM_ID --password @keychain:AC_PASSWORD" >&2
    exit 1
fi

# ── Archive ───────────────────────────────────────────────────────────────────

echo "==> [2/7] Archiving (Release, Developer ID)"

ARCHIVE_PATH="build/VoiceDrop.xcarchive"
rm -rf "$ARCHIVE_PATH"

xcodebuild archive \
    -project voicedrop.xcodeproj \
    -scheme voicedrop \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_STYLE=Automatic \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    | xcpretty 2>/dev/null || cat /dev/stdin

# ── Export ────────────────────────────────────────────────────────────────────

echo "==> [3/7] Exporting app (Developer ID)"

EXPORT_DIR="build/export"
rm -rf "$EXPORT_DIR"

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_DIR" \
    -exportOptionsPlist scripts/export-options.plist \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    | xcpretty 2>/dev/null || cat /dev/stdin

APP_PATH="$EXPORT_DIR/voicedrop.app"
if [[ ! -d "$APP_PATH" ]]; then
    # Xcode sometimes uses the display name
    APP_PATH=$(find "$EXPORT_DIR" -maxdepth 1 -name "*.app" | head -1)
fi

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
    echo "ERROR: Could not find exported .app in $EXPORT_DIR" >&2
    exit 1
fi

# ── Read version ──────────────────────────────────────────────────────────────

VERSION=$(xcodebuild -project voicedrop.xcodeproj -scheme voicedrop \
    -showBuildSettings 2>/dev/null | awk '/MARKETING_VERSION/{print $3}')
VERSION="${VERSION:-1.0}"
DMG_PATH="build/VoiceDrop-${VERSION}.dmg"
rm -f "$DMG_PATH"

# ── Create DMG ────────────────────────────────────────────────────────────────

echo "==> [4/7] Creating DMG"

create-dmg \
    --volname "VoiceDrop" \
    --window-pos 200 120 \
    --window-size 600 300 \
    --icon-size 128 \
    --icon "voicedrop.app" 150 130 \
    --app-drop-link 450 130 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

# ── Notarize ──────────────────────────────────────────────────────────────────

echo "==> [5/7] Submitting to Apple notary service (this may take 30–120 seconds)"

xcrun notarytool submit "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

# ── Staple ────────────────────────────────────────────────────────────────────

echo "==> [6/7] Stapling notarization ticket"

xcrun stapler staple "$DMG_PATH"

# ── Verify ────────────────────────────────────────────────────────────────────

echo "==> [7/7] Verifying Gatekeeper acceptance"

spctl --assess --type open --context context:primary-signature -v "$DMG_PATH"

echo ""
echo "Done! Distributable DMG: $DMG_PATH"
