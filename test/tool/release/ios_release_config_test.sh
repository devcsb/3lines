#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
project="$repo_root/ios/Runner.xcodeproj/project.pbxproj"

for setting in \
  'DEVELOPMENT_TEAM = "$(IOS_DEVELOPMENT_TEAM)"' \
  '"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "$(IOS_SIGNING_IDENTITY)"' \
  'PROVISIONING_PROFILE_SPECIFIER = "$(IOS_RUNNER_PROVISIONING_PROFILE_SPECIFIER)"' \
  'PROVISIONING_PROFILE_SPECIFIER = "$(IOS_WIDGET_PROVISIONING_PROFILE_SPECIFIER)"'; do
  if ! grep -Fq "$setting" "$project"; then
    echo "Missing iOS release setting: $setting" >&2
    exit 1
  fi
done

set +e
output="$(env -i PATH="$PATH" HOME="${HOME:-}" "$repo_root/tool/release/prepare_ios_signing.sh" 2>&1)"
rc=$?
set -e
if [[ "$rc" -ne 2 || "$output" != *"Missing required iOS release secret: IOS_CERTIFICATE_BASE64"* ]]; then
  echo "iOS signing preparation did not fail closed for missing secrets" >&2
  printf '%s\n' "$output" >&2
  exit 1
fi

echo "iOS release configuration and missing-secret guard verified."
