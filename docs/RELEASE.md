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

Android release job에는 다음 secret이 필요합니다.

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
3. `Mobile release` workflow의 `validate` → Android/iOS 서명 빌드가 모두 통과하면 GitHub Release에 AAB와 IPA가 첨부됩니다.
4. TestFlight 업로드는 workflow_dispatch를 태그 ref에서 실행하고 `upload=true`를 선택합니다.

```bash
git tag v1.2.3
git push origin v1.2.3
```

Apple signing secret이 없는 상태에서는 iOS job이 fail-closed로 중단되며 GitHub Release가 생성되지 않습니다. 이는 unsigned archive가 배포되는 것을 막기 위한 의도된 동작입니다.

## 로컬 검증

```bash
flutter pub get
flutter analyze
flutter test
cd android && ./gradlew :app:testDebugUnitTest --no-daemon
```

서명 없는 Android 컴파일이 꼭 필요할 때만 다음 우회 플래그를 사용합니다. `CI=true`에서는 Gradle이 이 플래그를 거부합니다.

```bash
flutter build apk --release --split-per-abi \
  --android-project-arg=allowUnsignedRelease=true
```

로컬 iOS archive는 Apple 인증서·프로필과 `pod install --deployment`가 필요합니다. CI 스크립트는 `tool/release/prepare_ios_signing.sh`와 `tool/release/generate_export_options.sh`를 사용합니다.
