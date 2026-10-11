#!/usr/bin/env ruby
require 'yaml'
require 'tmpdir'
require 'fileutils'
require 'open3'

root = File.expand_path('../../..', __dir__)
workflow = YAML.load_file("#{root}/.github/workflows/release.yml")
condition = workflow['jobs']['github-release']['if']
# Execute the actual workflow expression for partial-Apple and Android-only cases.
[
  ['success', 'success', 'skipped', true],
  ['success', 'success', 'success', true],
  ['failure', 'success', 'skipped', false],
  ['cancelled', 'success', 'skipped', false],
  ['success', 'failure', 'skipped', false],
  ['success', 'success', 'failure', false],
].each do |preflight, android, ios, expected|
  expression = condition.gsub(/always\(\)/, 'true')
    .gsub(/startsWith\(github.ref, 'refs\/tags\/v'\)/, 'true')
  {preflight: preflight, android: android, ios: ios}.each do |job, result|
    expression = expression.gsub("needs.#{job}.result", result.inspect)
  end
  actual = eval(expression.gsub(/\s+/, ' '))
  raise "Release condition accepted #{[preflight, android, ios]}: #{actual}" unless actual == expected
end

Dir.mktmpdir('3lines-preflight-test') do |temp|
  detect = workflow['jobs']['preflight']['steps'].find { |step| step['id'] == 'detect' }
  variables = detect['env'].keys
  # All 30 partial configurations fail closed; none means Android-only, all enables iOS.
  (0...32).each do |mask|
    output_file = "#{temp}/output-#{mask}"
    env = {'GITHUB_OUTPUT'=>output_file, 'GITHUB_STEP_SUMMARY'=>"#{temp}/summary-#{mask}"}
    variables.each_with_index { |name,index| env[name] = mask[index] == 1 ? 'test-fixture-not-a-secret' : '' }
    output, status = Open3.capture2e(env, 'bash', '-euo', 'pipefail', '-c', detect['run'])
    if [0,31].include?(mask)
      raise "Preflight #{mask}: #{output}" unless status.success?
      expected = mask == 0 ? "ios_enabled=false\n" : "ios_enabled=true\n"
      raise "Wrong preflight output #{mask}" unless File.read(output_file) == expected
    else
      raise "Partial Apple setup accepted #{mask}" unless status.exitstatus == 2
      raise 'Partial Apple setup produced success output' if File.exist?(output_file)
    end
  end
end

non_tag = condition.gsub(/always\(\)/, 'true')
  .gsub(/startsWith\(github.ref, 'refs\/tags\/v'\)/, 'false')
  .gsub(/needs\.(preflight|android|ios)\.result/, "'success'")
raise 'Non-tag release accepted' if eval(non_tag.gsub(/\s+/, ' '))

steps = workflow['jobs']['android']['steps']
commands = steps.filter_map { |step| step['run'] if step['name'].match?(/Build signed|Verify .* signature|Stage Android/) }
upload = steps.find { |step| step['uses'] == 'actions/upload-artifact@v4' }
raise 'Upload must fail for missing files' unless upload['with']['if-no-files-found'] == 'error'

# Flutter/signers are external processes; keep workflow shell + real verifier intact.
Dir.mktmpdir('3lines-beta-test') do |temp|
  FileUtils.mkdir_p("#{temp}/bin")
  FileUtils.mkdir_p("#{temp}/tool/release")
  FileUtils.cp("#{root}/tool/release/verify_android_artifact.sh", "#{temp}/tool/release/")
  File.write("#{temp}/bin/flutter", <<~SH)
    #!/usr/bin/env bash
    set -euo pipefail
    case "$*" in
      'build appbundle --release') path=build/app/outputs/bundle/release/app-release.aab ;;
      'build apk --release') path=build/app/outputs/flutter-apk/app-release.apk ;;
      *) exit 17 ;;
    esac
    if [[ "${MISSING_APK:-}" == 1 && "$path" == *.apk ]]; then exit 0; fi
    mkdir -p "$(dirname "$path")"
    printf fixture > "$path"
  SH
  File.write("#{temp}/bin/jarsigner", <<~SH)
    #!/bin/sh
    [ "$*" = '-verify -verbose -certs build/app/outputs/bundle/release/app-release.aab' ] || exit 17
    [ "${INVALID_AAB:-}" = 1 ] && { echo 'jar is unsigned'; exit 0; }
    [ "${DEBUG_AAB:-}" = 1 ] && { echo 'X.509 CN=Android Debug'; echo 'jar verified'; exit 0; }
    echo 'X.509 CN=Beta fixture'
    echo 'jar verified'
  SH
  File.write("#{temp}/bin/apksigner", <<~SH)
    #!/bin/sh
    [ "$*" = 'verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk' ] || exit 17
    [ "${INVALID_APK:-}" = 1 ] && exit 1
    [ "${DEBUG_APK:-}" = 1 ] && { echo 'Signer #1 CN=Android Debug'; exit 0; }
    echo 'Signer #1 CN=Beta fixture'
  SH
  Dir.glob("#{temp}/bin/*").each { |file| File.chmod(0755, file) }
  [['valid', {}, true], ['missing', {'MISSING_APK'=>'1'}, false],
   ['invalid', {'INVALID_APK'=>'1'}, false], ['debug', {'DEBUG_APK'=>'1'}, false],
   ['unsigned-aab', {'INVALID_AAB'=>'1'}, false], ['debug-aab', {'DEBUG_AAB'=>'1'}, false]].each do |name, flags, expected|
    FileUtils.rm_rf(["#{temp}/build", "#{temp}/release-assets"])
    output, status = Open3.capture2e({'PATH'=>"#{temp}/bin:#{ENV['PATH']}"}.merge(flags), 'bash', '-euo', 'pipefail', '-c', commands.join("\n"), chdir: temp)
    raise "#{name}: #{output}" unless status.success? == expected
    assets = Dir.glob("#{temp}/#{upload['with']['path']}").map { |p| File.basename(p) }.sort
    if expected
      raise "Nested/missing release assets: #{assets}" unless assets == ['app-release.aab', 'app-release.apk']
    else
      raise "Failed signer staged release assets: #{assets}" unless assets.empty?
    end
  end
end
puts 'PASS Android APK/AAB build, verification, flat upload, 32 Apple configurations and release-condition matrix'
