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

Android release job에는 다음 secret이 필요합니다. 이 4개는 이미 `devcsb/3lines`에 등록되어 있습니다.

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
3. `Mobile release` workflow가 `preflight` → `validate` → 서명 빌드 순으로 돕니다. Apple secret이 등록되어 있으면 AAB와 IPA가, 없으면 AAB만 GitHub Release에 첨부됩니다.
4. TestFlight 업로드는 workflow_dispatch를 태그 ref에서 실행하고 `upload=true`를 선택합니다.

```bash
git tag v1.2.3
git push origin v1.2.3
```

## Apple signing이 아직 없을 때

`preflight` job이 Apple secret 5개(`IOS_CERTIFICATE_BASE64`, `IOS_CERTIFICATE_PASSWORD`, `IOS_PROVISIONING_PROFILE_BASE64`, `IOS_WIDGET_PROVISIONING_PROFILE_BASE64`, `IOS_DEVELOPMENT_TEAM`)의 등록 여부를 먼저 확인합니다.

- 5개가 모두 있으면 iOS job이 돌고, 실패하면 GitHub Release도 막힙니다. unsigned archive는 절대 배포되지 않습니다.
- 5개가 모두 없으면 iOS job을 skip하고 Android AAB만으로 GitHub Release를 만듭니다. 릴리스 요약에 iOS 산출물이 빠졌다는 문구가 남습니다.
- 일부만 등록된 상태는 설정 실수로 보고 `preflight`에서 fail-closed로 중단합니다.

Apple 자료가 준비되면 secret 5개를 등록하는 것만으로 iOS job이 자동으로 켜집니다. 워크플로 수정은 필요 없습니다.

### iOS secret 만드는 법

`Yuon Inc.` 팀(Team ID `7D5XL3L4ZT`)의 Apple Distribution 인증서를 사용합니다.

1. Apple Developer 포털에서 App ID 두 개와 App Group을 등록합니다.
   - `com.threelines.threeLines`, `com.threelines.threeLines.ThreeLinesWidget`
   - App Group `group.com.threelines.threeLines` 를 두 App ID 모두에 붙입니다.
2. 두 App ID에 대한 App Store distribution provisioning profile을 만들어 내려받습니다.
3. Keychain Access에서 `Apple Distribution: Yuon Inc.` 인증서를 개인 키와 함께 `.p12`로 내보냅니다.
4. 값을 만들어 등록합니다.

```bash
base64 -i distribution.p12 | tr -d '\n' | gh secret set IOS_CERTIFICATE_BASE64
gh secret set IOS_CERTIFICATE_PASSWORD
base64 -i ThreeLines_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_PROVISIONING_PROFILE_BASE64
base64 -i ThreeLinesWidget_AppStore.mobileprovision | tr -d '\n' | gh secret set IOS_WIDGET_PROVISIONING_PROFILE_BASE64
gh secret set IOS_DEVELOPMENT_TEAM --body 7D5XL3L4ZT
```

## 로컬 서명 빌드

Android upload keystore는 저장소 밖에 둡니다. 현재 개발 머신 기준 경로는 다음과 같습니다.

- keystore: `~/.keys/3lines-upload-keystore.jks` (alias `upload`, RSA 4096)
- 비밀번호: `~/.keys/3lines-upload-keystore.env`

`android/keystore.properties`는 `.gitignore` 대상이며 다음과 같이 만듭니다.

```bash
. ~/.keys/3lines-upload-keystore.env
cat > android/keystore.properties <<EOF
storePassword=$ANDROID_KEYSTORE_PASSWORD
keyPassword=$ANDROID_KEY_PASSWORD
keyAlias=$ANDROID_KEY_ALIAS
storeFile=$ANDROID_KEYSTORE_PATH
EOF

flutter build appbundle --release
tool/release/verify_android_artifact.sh build/app/outputs/bundle/release/app-release.aab
```

이 keystore는 아직 Play Console에 업로드된 적이 없으므로 교체해도 안전합니다. 한 번이라도 스토어에 올린 뒤에는 절대 분실하면 안 됩니다.

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
