#!/usr/bin/env bash
set -euo pipefail

required=(
  IOS_CERTIFICATE_BASE64
  IOS_CERTIFICATE_PASSWORD
  IOS_PROVISIONING_PROFILE_BASE64
  IOS_WIDGET_PROVISIONING_PROFILE_BASE64
  IOS_DEVELOPMENT_TEAM
)
for variable in "${required[@]}"; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing required iOS release secret: $variable" >&2
    exit 2
  fi
done

if ! command -v security >/dev/null 2>&1 || ! command -v plutil >/dev/null 2>&1; then
  echo "prepare_ios_signing.sh must run on macOS with security and plutil" >&2
  exit 2
fi

temp_root="${RUNNER_TEMP:-$(mktemp -d)}"
mkdir -p "$temp_root"
keychain_path="$temp_root/3lines-build.keychain-db"
keychain_password="${IOS_KEYCHAIN_PASSWORD:-$(openssl rand -hex 16)}"
certificate_path="$temp_root/3lines-distribution.p12"
runner_profile_path="$temp_root/3lines-runner.mobileprovision"
widget_profile_path="$temp_root/3lines-widget.mobileprovision"
env_file="${IOS_RELEASE_ENV_FILE:-$temp_root/3lines-ios-release.env}"

decode_base64() {
  if base64 -D </dev/null >/dev/null 2>&1; then
    base64 -D
  else
    base64 --decode
  fi
}

printf '%s' "$IOS_CERTIFICATE_BASE64" | decode_base64 >"$certificate_path"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | decode_base64 >"$runner_profile_path"
printf '%s' "$IOS_WIDGET_PROVISIONING_PROFILE_BASE64" | decode_base64 >"$widget_profile_path"

security create-keychain -p "$keychain_password" "$keychain_path" >/dev/null
security set-keychain-settings -lut 21600 "$keychain_path"
security unlock-keychain -p "$keychain_password" "$keychain_path"
security import "$certificate_path" -P "$IOS_CERTIFICATE_PASSWORD" -A -t cert -f pkcs12 -k "$keychain_path"
security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_password" "$keychain_path" >/dev/null
security list-keychains -d user -s "$keychain_path" login.keychain-db

profiles_dir="$HOME/Library/MobileDevice/Provisioning Profiles"
mkdir -p "$profiles_dir"

profile_value() {
  local profile="$1"
  local key="$2"
  local plist="$temp_root/$(basename "$profile").plist"
  security cms -D -i "$profile" >"$plist"
  plutil -extract "$key" raw -o - "$plist"
}

runner_uuid="$(profile_value "$runner_profile_path" UUID)"
runner_name="$(profile_value "$runner_profile_path" Name)"
widget_uuid="$(profile_value "$widget_profile_path" UUID)"
widget_name="$(profile_value "$widget_profile_path" Name)"
runner_app_id="$(profile_value "$runner_profile_path" Entitlements.application-identifier)"
widget_app_id="$(profile_value "$widget_profile_path" Entitlements.application-identifier)"

if [[ "$runner_app_id" != *"com.threelines.threeLines" || "$widget_app_id" != *"com.threelines.threeLines.ThreeLinesWidget" ]]; then
  echo "Provisioning profiles do not match Runner and widget bundle identifiers" >&2
  exit 1
fi

cp "$runner_profile_path" "$profiles_dir/$runner_uuid.mobileprovision"
cp "$widget_profile_path" "$profiles_dir/$widget_uuid.mobileprovision"

signing_identity="${IOS_SIGNING_IDENTITY:-Apple Distribution}"
{
  printf 'IOS_DEVELOPMENT_TEAM=%q\n' "$IOS_DEVELOPMENT_TEAM"
  printf 'IOS_SIGNING_IDENTITY=%q\n' "$signing_identity"
  printf 'IOS_RUNNER_PROVISIONING_PROFILE_SPECIFIER=%q\n' "$runner_name"
  printf 'IOS_WIDGET_PROVISIONING_PROFILE_SPECIFIER=%q\n' "$widget_name"
  printf 'IOS_BUILD_KEYCHAIN=%q\n' "$keychain_path"
} >"$env_file"

echo "iOS signing prepared (Runner profile: $runner_name; widget profile: $widget_name)."
echo "Source $env_file before xcodebuild/export."
