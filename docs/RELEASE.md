# 3Lines 모바일 릴리스

이 저장소의 릴리스는 `pubspec.yaml`의 버전, 서명, 테스트, CocoaPods 상태를 모두 검증한 뒤 생성됩니다. 배포용 인증서나 비밀번호는 저장소에 커밋하지 않습니다.

## 릴리스 버전

`pubspec.yaml`의 `version: name+build`를 올리고 변경사항을 커밋합니다. 태그는 `v<name>` 형식이어야 합니다.

```bash
flutter pub get
dart run tool/release/validate_version.dart --tag v1.2.3
```

태그가 이미 존재하면 검증기가 거부합니다. 스토어에 업로드했던 build number를 재사용하지 않도록 새 name과 build를 함께 확인하세요.

## GitHub Secrets

Android release job에는 다음 secret이 필요합니다. 등록 여부와 값의 유효성은 릴리스 담당자가 해당 실행에서 확인해야 합니다. 이 문서는 현재 secret 값이나 계정 설정을 확인한 기록이 아닙니다.

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

iOS release job에는 다음 secret이 필요합니다.

- `IOS_CERTIFICATE_BASE64` — Apple Distribution 인증서 `.p12`
- `IOS_CERTIFICATE_PASSWORD`
- `IOS_PROVISIONING_PROFILE_BASE64` — `com.threelines.threeLines`용 profile
- `IOS_WIDGET_PROVISIONING_PROFILE_BASE64` — `com.threelines.threeLines.ThreeLinesWidget`용 profile
- `IOS_DEVELOPMENT_TEAM`
- `IOS_SIGNING_IDENTITY` — 보통 `Apple Distribution`; 생략하면 이 값이 사용됨

TestFlight 업로드를 수동으로 활성화할 때만 다음 secret을 추가합니다.

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_BASE64`

## 실행

1. 위 secret을 GitHub Actions 환경에 등록합니다.
2. `v<version>` 태그를 push합니다.
3. `Mobile release` workflow가 preflight와 validate를 실행합니다. Android job은 같은 버전과 서명 구성으로 AAB와 universal APK를 빌드하고 각각 서명을 검증합니다. 두 파일을 `release-assets/`에 모아 업로드하여 최종 `release-assets/*`가 중첩 디렉터리 없이 두 파일을 포함합니다. 파일 누락, debug 서명, 서명 검증 실패는 업로드를 막습니다.
4. preflight와 Android job이 성공해야 GitHub Release를 만들 수 있습니다. Apple secret이 모두 있으면 iOS 성공도 필요하며 IPA를 추가합니다. Apple secret이 모두 없으면 iOS skip을 허용하여 AAB와 APK만 첨부합니다. 일부만 있거나 preflight가 실패/취소되면 iOS skip이어도 Release를 막습니다.
5. TestFlight 업로드는 workflow_dispatch를 태그 ref에서 실행하고 `upload=true`를 선택합니다. GitHub Release 생성은 Play Console 등록이나 Play 업로드가 아닙니다.

```bash
git tag v1.2.3
git push origin v1.2.3
```

## Apple signing이 아직 없을 때

`preflight` job이 Apple secret 5개(`IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`, `IOS_DEVELOPMENT_TEAM`)의 등록 여부를 먼저 확인합니다.

- 5개가 모두 있으면 iOS job이 돌고, 실패하면 GitHub Release도 막힙니다. unsigned archive는 절대 배포되지 않습니다.
- 5개가 모두 없으면 iOS job을 skip하고 Android AAB와 APK로 GitHub Release를 만듭니다. 릴리스 요약에 iOS 산출물이 빠졌다는 문구가 남습니다.
- 일부만 등록된 상태는 설정 실수로 보고 `preflight`에서 fail-closed로 중단합니다.

Apple 자료가 준비되면 secret 5개를 등록하는 것만으로 iOS job이 자동으로 켜집니다. 워크플로 수정은 필요 없습니다.

### iOS secret 만드는 법

Apple 배포를 준비할 때 릴리스 담당자가 계정과 권한을 확인하고 아래 순서로 준비합니다. 계정 유무나 현재 등록 상태를 이 문서만으로 판단하지 마세요.

1. Apple Developer 포털에서 App ID 두 개와 App Group을 등록합니다.
   - `com.threelines.threeLines`, `com.threelines.threeLines.ThreeLinesWidget`
   - App Group `group.com.threelines.threeLines` 를 두 App ID 모두에 붙입니다.
2. 두 App ID에 대한 App Store distribution provisioning profile을 만들어 내려받습니다.
3. Keychain Access에서 해당 팀의 `Apple Distribution` 인증서를 개인 키와 함께 `.p12`로 내보냅니다.
4. 값을 만들어 등록합니다.

```bash
base64 -i distribution.p12 | tr -d '\n' | gh secret set IOS_CERTIFICATE_BASE64
gh secret set IOS_CERTIFICATE_PASSWORD
base64 -i ThreeLines_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64
base64 -i ThreeLinesWidget_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_WIDGET_PROVISIONING_PROFILE_BASE64
gh secret set IOS_DEVELOPMENT_TEAM  # Apple Developer 팀 ID
```

## 로컬 서명 빌드

Android keystore는 저장소 밖에서 안전하게 관리합니다. 기존 GitHub APK 설치본과 업데이트 서명을 유지해야 하며, Play App Signing을 사용한다면 app signing key와 upload key 역할도 구분하세요. 개인 개발 머신의 경로는 다른 개발자의 요구 조건이 아닙니다.

`android/keystore.properties`는 `.gitignore` 대상입니다. 담당자가 기존 배포 서명에 맞는 값으로 안전하게 작성합니다. 값은 로그나 커밋에 넣지 않습니다.

```bash
flutter build appbundle --release
flutter build apk --release
tool/release/verify_android_artifact.sh build/app/outputs/bundle/release/app-release.aab
tool/release/verify_android_artifact.sh build/app/outputs/flutter-apk/app-release.apk
```

Play 등록 전이라도 기존 APK 사용자 업데이트에 같은 서명이 필요합니다. 키 교체를 안전하다고 단정하지 말고 기존 배포, 설치본, Play 정책을 확인하세요. 다른 서명 때문에 앱을 삭제하면 로컬 기록과 사진을 잃을 수 있습니다. JSON은 완료 기록 텍스트만 보존하며 초안, 사진, 설정은 포함하지 않습니다.

## 확인한 외부 배포 상태

2026-10-11 root가 GitHub CLI로 확인한 최신 공개 [v1.2.3](https://github.com/devcsb/3lines/releases/tag/v1.2.3)은 `2026-08-29T06:58:51Z`에 게시됐습니다. 첨부는 `app-release.aab` 72,099,129 bytes 하나이며 APK와 IPA는 없습니다. [실행 33239369691](https://github.com/devcsb/3lines/actions/runs/33239369691)은 성공했지만 현재 로컬 개선 소스가 배포됐다는 의미는 아닙니다. 이 작업은 push/tag/publish/secret 변경을 하지 않습니다.

## 로컬 검증

```bash
flutter pub get
flutter analyze
flutter test
ruby test/tool/release/android_beta_pipeline_test.rb
ruby test/tool/release/launcher_assets_test.rb
cd android && ./gradlew :app:testDebugUnitTest --no-daemon
```

서명 없는 Android 컴파일이 꼭 필요할 때만 다음 우회 플래그를 사용합니다. `CI=true`에서는 Gradle이 이 플래그를 거부합니다.

```bash
flutter build apk --release --split-per-abi \
  --android-project-arg=allowUnsignedRelease=true
```

로컬 iOS archive는 Apple 인증서·프로필과 `pod install --deployment`가 필요합니다. CI 스크립트는 `tool/release/prepare_ios_signing.sh`와 `tool/release/generate_export_options.sh`를 사용합니다.
