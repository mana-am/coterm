#!/usr/bin/env bash
set -euo pipefail

# Build, sign, notarize, create DMG, generate appcast, and upload to GitHub release.
# Usage: ./scripts/build-sign-upload.sh <tag> [--allow-overwrite]
# Requires: source ~/.secrets/coterm.env && export SPARKLE_PRIVATE_KEY

usage() {
  cat <<'EOF'
Usage: ./scripts/build-sign-upload.sh <tag> [--allow-overwrite]

Options:
  --allow-overwrite   Permit replacing existing release assets for the same tag.
                      Use only for emergency rerolls.
EOF
}

ALLOW_OVERWRITE="false"
POSITIONAL=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --allow-overwrite)
      ALLOW_OVERWRITE="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL[@]}"

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

TAG="$1"
SIGN_HASH="A050CC7E193C8221BDBA204E731B046CDCCC1B30"
ENTITLEMENTS_TEMPLATE="coterm.entitlements"
APP_PATH="build/Build/Products/Release/Coterm.app"
GHOSTTYKIT_CRASH_REPORT_SUBDIR="cmux/crash"
STABLE_APPCAST_URL="${COTERM_STABLE_APPCAST_URL:-https://updates.coterm.cc/stable/appcast.xml}"
RELEASE_DOWNLOAD_URL_BASE="${COTERM_RELEASE_DOWNLOAD_URL_BASE:-https://download.coterm.cc/releases}"
DMG_RELEASE="coterm-macos.dmg"

# --- Pre-flight ---
source ~/.secrets/coterm.env
export SPARKLE_PRIVATE_KEY
for tool in zig xcodebuild create-dmg xcrun codesign ditto gh; do
  command -v "$tool" >/dev/null || { echo "MISSING: $tool" >&2; exit 1; }
done
echo "Pre-flight checks passed"

# --- Build GhosttyKit ---
echo "Building GhosttyKit..."
rm -rf GhosttyKit.xcframework ghostty/macos/GhosttyKit.xcframework
(
  cd ghostty
  zig build -Dcrash-report-subdir="$GHOSTTYKIT_CRASH_REPORT_SUBDIR" -Demit-xcframework=true -Demit-macos-app=false -Dxcframework-target=universal -Doptimize=ReleaseFast
)
cp -R ghostty/macos/GhosttyKit.xcframework GhosttyKit.xcframework

# --- Build app (Release, unsigned) ---
echo "Building app..."
rm -rf build/
xcodebuild -scheme coterm -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build 2>&1 | tail -5
echo "Build succeeded"

HELPER_PATH="$APP_PATH/Contents/Resources/bin/ghostty"
if [ ! -x "$HELPER_PATH" ]; then
  echo "Ghostty theme picker helper not found at $HELPER_PATH" >&2
  exit 1
fi

# --- Inject Sparkle keys ---
echo "Injecting Sparkle keys..."
SPARKLE_PUBLIC_KEY_DERIVED=$(swift scripts/derive_sparkle_public_key.swift "$SPARKLE_PRIVATE_KEY")
APP_PLIST="$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Delete :SUPublicEDKey" "$APP_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SUFeedURL" "$APP_PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $SPARKLE_PUBLIC_KEY_DERIVED" "$APP_PLIST"
/usr/libexec/PlistBuddy -c "Add :SUFeedURL string $STABLE_APPCAST_URL" "$APP_PLIST"
echo "Sparkle keys injected"

# coterm is a non-sandboxed app. Sparkle's sandbox-only XPC services make the
# installer handoff wait for an agent connection that never arrives.
./scripts/remove-sparkle-sandbox-xpc-services.sh "$APP_PATH"

# --- Codesign ---
echo "Codesigning..."
ENTITLEMENTS="$(mktemp /tmp/coterm-release-entitlements.XXXXXX)"
./scripts/resolve-app-entitlements.sh \
  "$ENTITLEMENTS_TEMPLATE" \
  "$ENTITLEMENTS" \
  "cc.coterm.app"
./scripts/sign-coterm-bundle.sh "$APP_PATH" "$ENTITLEMENTS" "$SIGN_HASH"
echo "Codesign verified"

# --- Notarize app ---
echo "Notarizing app..."
ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" coterm-notary.zip
xcrun notarytool submit coterm-notary.zip \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm -f coterm-notary.zip
echo "App notarized"

# --- Create and notarize DMG ---
echo "Creating DMG..."
rm -f "$DMG_RELEASE"
create-dmg --codesign "$SIGN_HASH" "$DMG_RELEASE" "$APP_PATH"
echo "Notarizing DMG..."
xcrun notarytool submit "$DMG_RELEASE" \
  --apple-id "$APPLE_ID" --team-id "$APPLE_TEAM_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD" --wait
xcrun stapler staple "$DMG_RELEASE"
xcrun stapler validate "$DMG_RELEASE"
echo "DMG notarized"

# --- Generate Sparkle appcast ---
echo "Generating appcast..."
DOWNLOAD_URL_PREFIX="${RELEASE_DOWNLOAD_URL_BASE}/${TAG}/" \
  ./scripts/sparkle_generate_appcast.sh "$DMG_RELEASE" "$TAG" appcast.xml

# --- Create GitHub release (if needed) and upload ---
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "Release $TAG already exists"
  EXISTING_ASSETS="$(gh release view "$TAG" --json assets --jq '.assets[].name' || true)"
  HAS_CONFLICTING_ASSET="false"
  for asset in "$DMG_RELEASE" appcast.xml; do
    if printf '%s\n' "$EXISTING_ASSETS" | grep -Fxq "$asset"; then
      HAS_CONFLICTING_ASSET="true"
      break
    fi
  done

  if [[ "$HAS_CONFLICTING_ASSET" == "true" && "$ALLOW_OVERWRITE" != "true" ]]; then
    echo "ERROR: Refusing to overwrite signed release assets for existing tag $TAG." >&2
    echo "Use a new tag, or rerun with --allow-overwrite for an emergency reroll." >&2
    exit 1
  fi

  if [[ "$ALLOW_OVERWRITE" == "true" ]]; then
    echo "Uploading with overwrite enabled for existing release $TAG..."
    gh release upload "$TAG" "$DMG_RELEASE" appcast.xml --clobber
  else
    echo "Uploading to existing release $TAG..."
    gh release upload "$TAG" "$DMG_RELEASE" appcast.xml
  fi
else
  echo "Creating release $TAG and uploading..."
  gh release create "$TAG" "$DMG_RELEASE" appcast.xml --title "$TAG" --notes "See CHANGELOG.md for details"
fi

# --- Verify ---
gh release view "$TAG"

# --- Update Homebrew cask (skip for nightlies) ---
if [[ "$TAG" != *"-nightly"* ]]; then
  VERSION="${TAG#v}"
  DMG_SHA256=$(shasum -a 256 "$DMG_RELEASE" | cut -d' ' -f1)
  echo "Updating homebrew cask to $VERSION (SHA: $DMG_SHA256)..."
  CASK_FILE="homebrew-coterm/Casks/coterm.rb"
  if [ -f "$CASK_FILE" ]; then
    cat > "$CASK_FILE" << CASKEOF
cask "coterm" do
  version "${VERSION}"
  sha256 "${DMG_SHA256}"

  url "https://download.coterm.cc/releases/v#{version}/coterm-macos.dmg"
  name "Coterm"
  desc "Lightweight native macOS terminal with vertical tabs for AI coding agents"
  homepage "https://coterm.cc"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :ventura"

  app "Coterm.app"
  binary "#{appdir}/Coterm.app/Contents/Resources/bin/coterm"

  zap trash: [
    "~/Library/Application Support/coterm",
    "~/Library/Caches/coterm",
    "~/Library/Preferences/ai.emergent.inc.coterm.plist",
  ]
end
CASKEOF
    cd homebrew-coterm
    git add Casks/coterm.rb
    if git diff --staged --quiet; then
      echo "Homebrew cask already up to date"
    else
      git commit -m "Update Coterm to ${VERSION}"
      git push
      echo "Homebrew cask updated"
    fi
    cd ..
  else
    echo "WARNING: homebrew-coterm submodule not found, skipping cask update"
  fi
fi

# --- Cleanup ---
rm -rf build/ "$DMG_RELEASE" appcast.xml
echo ""
echo "=== Release $TAG complete ==="
say "coterm release complete"
