#!/usr/bin/env bash
set -euo pipefail

artifact="${1:-}"
if [[ -z "$artifact" || ! -f "$artifact" ]]; then
  echo "Usage: $0 <signed-apk-or-aab>" >&2
  exit 2
fi

report="$(mktemp)"
trap 'rm -f "$report"' EXIT

case "$artifact" in
  *.apk)
    sdk_root="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
    apksigner="$(command -v apksigner || true)"
    if [[ -z "$apksigner" && -n "$sdk_root" ]]; then
      apksigner="$(find "$sdk_root/build-tools" -type f -name apksigner -perm -111 2>/dev/null | sort -V | tail -n 1)"
    fi
    if [[ -z "$apksigner" ]]; then
      echo "No Android build-tools apksigner was found; install build-tools or set ANDROID_SDK_ROOT" >&2
      exit 2
    fi
    "$apksigner" verify --verbose --print-certs "$artifact" | tee "$report"
    ;;
  *.aab)
    jarsigner -verify -verbose -certs "$artifact" | tee "$report"
    grep -q "jar verified" "$report"
    ;;
  *)
    echo "Unsupported Android artifact: $artifact (expected .apk or .aab)" >&2
    exit 2
    ;;
esac

if grep -qi "Android Debug" "$report"; then
  echo "Debug signing certificate is not allowed for a release artifact" >&2
  exit 1
fi

if ! grep -Eqi "(Signer #1|X\.509|SHA-256|CN=|jar verified)" "$report"; then
  echo "No release signer certificate was found" >&2
  exit 1
fi

echo "Android release artifact signature verified: $artifact"
