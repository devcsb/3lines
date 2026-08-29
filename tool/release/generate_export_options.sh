#!/usr/bin/env bash
set -euo pipefail

output="${1:-${IOS_EXPORT_OPTIONS_PATH:-}}"
if [[ -z "$output" ]]; then
  echo "Usage: $0 <export-options.plist>" >&2
  exit 2
fi

for variable in IOS_DEVELOPMENT_TEAM IOS_RUNNER_PROVISIONING_PROFILE_SPECIFIER IOS_WIDGET_PROVISIONING_PROFILE_SPECIFIER; do
  if [[ -z "${!variable:-}" ]]; then
    echo "Missing iOS export setting: $variable" >&2
    exit 2
  fi
done

xml_escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g' -e "s/'/\&apos;/g"
}

runner_profile="$(xml_escape "$IOS_RUNNER_PROVISIONING_PROFILE_SPECIFIER")"
widget_profile="$(xml_escape "$IOS_WIDGET_PROVISIONING_PROFILE_SPECIFIER")"
team="$(xml_escape "$IOS_DEVELOPMENT_TEAM")"
mkdir -p "$(dirname "$output")"
cat >"$output" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>compileBitcode</key>
	<false/>
	<key>method</key>
	<string>app-store</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>com.threelines.threeLines</key>
		<string>$runner_profile</string>
		<key>com.threelines.threeLines.ThreeLinesWidget</key>
		<string>$widget_profile</string>
	</dict>
	<key>signingStyle</key>
	<string>manual</string>
	<key>stripSwiftSymbols</key>
	<true/>
	<key>teamID</key>
	<string>$team</string>
</dict>
</plist>
EOF

plutil -lint "$output"
echo "Generated iOS export options: $output"
