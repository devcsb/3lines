#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
gradle_dir="$repo_root/android"

if [[ ! -x "$gradle_dir/gradlew" ]]; then
  echo "android/gradlew is missing or not executable" >&2
  exit 1
fi

if [[ -n "${JAVA_HOME:-}" ]]; then
  java_home="$JAVA_HOME"
elif [[ -x /usr/libexec/java_home ]]; then
  java_home="$(/usr/libexec/java_home -v 21 2>/dev/null || true)"
else
  java_home=""
fi
if [[ -z "$java_home" ]]; then
  echo "JDK 21 is required for the Android release gate test" >&2
  exit 1
fi

set +e
output="$(cd "$gradle_dir" && JAVA_HOME="$java_home" CI=true ./gradlew :app:assembleRelease --no-daemon -PallowUnsignedRelease=true 2>&1)"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "CI accepted allowUnsignedRelease=true" >&2
  exit 1
fi
grep -q "allowUnsignedRelease=true is forbidden when CI=true" <<<"$output"
printf '%s\n' "$output" | tail -n 12
