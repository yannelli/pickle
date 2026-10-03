#!/bin/bash
set -euo pipefail
umask 077
: "${RUNNER_TEMP:?Run this script on the GitHub-hosted runner}"
[[ "${GITHUB_ACTIONS:-}" == true ]] || { echo 'This script requires GitHub Actions'; exit 1; }
signing_dir="$RUNNER_TEMP/little-dill-signing"
release_dir="$RUNNER_TEMP/little-dill-release"
keychain="$signing_dir/signing.keychain-db"
profile_name="LittleDill-ci-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}.mobileprovision"
profile_dir="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"

case "${1:-}" in
  api-key)
    : "${APPLE_API_KEY:?Missing APPLE_API_KEY}" "${APPLE_API_ISSUER:?Missing APPLE_API_ISSUER}"
    : "${APPLE_API_KEY_BASE64:?Missing APPLE_API_KEY_BASE64}"
    [[ "$APPLE_API_KEY" =~ ^[A-Za-z0-9]+$ ]] || { echo 'Invalid API key ID'; exit 1; }
    mkdir -p "$signing_dir/private_keys"
    printf '%s' "$APPLE_API_KEY_BASE64" | base64 --decode > "$signing_dir/private_keys/AuthKey_${APPLE_API_KEY}.p8"
    printf 'APPLE_API_KEY_PATH=%s/private_keys/AuthKey_%s.p8\n' "$signing_dir" "$APPLE_API_KEY" >> "$GITHUB_ENV"
    printf 'API_PRIVATE_KEYS_DIR=%s/private_keys\n' "$signing_dir" >> "$GITHUB_ENV"
    ;;
  signing)
    : "${IOS_CERTIFICATE:?Missing IOS_CERTIFICATE}" "${IOS_CERTIFICATE_PASSWORD:?Missing IOS_CERTIFICATE_PASSWORD}"
    : "${IOS_MOBILE_PROVISION:?Missing IOS_MOBILE_PROVISION}"
    mkdir -p "$signing_dir" "$release_dir" "$profile_dir"
    security list-keychains -d user > "$signing_dir/original-keychains.txt"
    printf '%s' "$IOS_CERTIFICATE" | base64 --decode > "$signing_dir/distribution.p12"
    printf '%s' "$IOS_MOBILE_PROVISION" | base64 --decode > "$signing_dir/profile.mobileprovision"
    security cms -D -i "$signing_dir/profile.mobileprovision" > "$signing_dir/profile.plist"
    keychain_password=$(openssl rand -hex 32)
    security create-keychain -p "$keychain_password" "$keychain"
    security set-keychain-settings -lut 21600 "$keychain"
    security unlock-keychain -p "$keychain_password" "$keychain"
    security import "$signing_dir/distribution.p12" -P "$IOS_CERTIFICATE_PASSWORD" -t cert -f pkcs12 -k "$keychain" -T /usr/bin/codesign -T /usr/bin/security
    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$keychain_password" "$keychain" >/dev/null
    security find-identity -v -p codesigning "$keychain" > "$signing_dir/identities.txt"
    python3 ios/scripts/signing-profile.py prepare "$signing_dir"
    python3 - "$signing_dir/original-keychains.txt" "$keychain" <<'PY'
import pathlib, shlex, subprocess, sys
original = shlex.split(pathlib.Path(sys.argv[1]).read_text())
subprocess.run(['security', 'list-keychains', '-d', 'user', '-s', sys.argv[2], *original], check=True)
PY
    cp "$signing_dir/profile.mobileprovision" "$profile_dir/$profile_name"
    rm "$signing_dir/distribution.p12"
    ;;
  archive)
    : "${MARKETING_VERSION:?}" "${BUILD_NUMBER:?}" "${PROFILE_UUID:?}" "${SIGNING_IDENTITY:?}"
    xcodebuild archive -project ios/LittleDill.xcodeproj -scheme LittleDill \
      -configuration Release -destination 'generic/platform=iOS' \
      -derivedDataPath "$RUNNER_TEMP/little-dill-derived" -archivePath "$release_dir/LittleDill.xcarchive" \
      MARKETING_VERSION="$MARKETING_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
      CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM=2P58V89SR7 CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
      PROVISIONING_PROFILE_SPECIFIER="$PROFILE_UUID" OTHER_CODE_SIGN_FLAGS="--keychain $keychain"
    xcodebuild -exportArchive -archivePath "$release_dir/LittleDill.xcarchive" \
      -exportOptionsPlist "$signing_dir/ExportOptions.plist" -exportPath "$release_dir/export"
    test -f "$release_dir/export/LittleDill.ipa"
    ;;
  verify)
    mkdir -p "$signing_dir/ipa"
    ditto -x -k "$release_dir/export/LittleDill.ipa" "$signing_dir/ipa"
    app="$signing_dir/ipa/Payload/LittleDill.app"
    codesign --verify --deep --strict "$app"
    codesign -d --entitlements :- "$app" > "$signing_dir/app-entitlements.plist"
    codesign -d --extract-certificates "$signing_dir/signer" "$app"
    security cms -D -i "$app/embedded.mobileprovision" > "$signing_dir/profile.plist"
    cp "$app/Info.plist" "$signing_dir/app-info.plist"
    python3 ios/scripts/signing-profile.py verify "$signing_dir" "$MARKETING_VERSION" "$BUILD_NUMBER"
    (cd "$release_dir/export" && shasum -a 256 LittleDill.ipa > SHA256SUMS)
    printf 'Signed IPA verified: %s (%s)\n' "$MARKETING_VERSION" "$BUILD_NUMBER" >> "$GITHUB_STEP_SUMMARY"
    ;;
  cleanup)
    if [[ -f "$signing_dir/original-keychains.txt" ]]; then
      python3 - "$signing_dir/original-keychains.txt" <<'PY'
import pathlib, shlex, subprocess, sys
subprocess.run(['security', 'list-keychains', '-d', 'user', '-s',
                *shlex.split(pathlib.Path(sys.argv[1]).read_text())], check=True)
PY
    fi
    if [[ -f "$keychain" ]]; then security delete-keychain "$keychain"; fi
    rm -f "$profile_dir/$profile_name"
    rm -rf "$signing_dir"
    ;;
  *) echo 'Usage: release.sh api-key|signing|archive|verify|cleanup' >&2; exit 1 ;;
esac
