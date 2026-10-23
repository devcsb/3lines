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

내보낸 JSON은 암호화하지 않은 평문 파일이며 파일을 읽을 수 있는 사람은 내용을 볼 수 있습니다. 민감한 JSON을 공유하지 말고 안전하게 보관하세요. 앱 잠금은 앱 진입 보호이며 저장 데이터나 내보낸 파일의 암호화가 아닙니다. OS 설정에 따라 시스템 백업에 데이터가 포함될 수 있지만, 실제 백업이 사용 중이라고 단정하지 않습니다.

## 최신 배포 검증 (v1.3.2)

2026-10-23에 [v1.3.2](https://github.com/devcsb/3lines/releases/tag/v1.3.2)를
`2026-10-23T14:12:19Z`에 공개했습니다. 앱 버전은 `1.3.2+9`, 배포 소스는
`b3456de45455a87208f700dbb21c1fdd14e4ec55`입니다. 기존 `v1.3.1` 책등 아이콘을
유지하고, 예시 되돌리기와 사진 재시도 알림에 표준 닫기 버튼을 추가했습니다.
닫기는 알림만 없애며 답변 되돌리기나 사진 재시도를 실행하지 않습니다.

[릴리스 실행 39966137222](https://github.com/devcsb/3lines/actions/runs/39966137222)에서
검증, 서명 APK/AAB 빌드, 두 서명 검사와 게시가 모두 성공했습니다.
Apple signing 미설정으로 iOS/TestFlight는 건너뛰었고 IPA는 없습니다.
Play Console/App Store 게시, secret 값 조회나 교체, 기존 태그 재지정은 하지 않았습니다.

| 공개 파일 | 크기(bytes) | SHA-256 |
| --- | ---: | --- |
| `app-release.apk` | 75,569,106 | `0b788fbfd51222b198aaf6931a639029d731df2bc82994cf1de4b2d046da602f` |
| `app-release.aab` | 73,034,406 | `d37d9133b05e349c52450f23805a05030d5726b8274647d79b4423ff9c4f2d19` |

공개 파일을 다시 내려받아 GitHub digest와 일치함을 확인했습니다.
APK apksigner v2와 AAB jarsigner 검증이 통과했습니다. AAB의 자체 서명/타임스탬프
경고는 남아 있습니다. APK와 AAB의 인증서 SHA-256은
`320c932cbc7cbc8f353f767020610caafb64f596e4762fa2266f8499271921df`로,
이번에 내려받은 `v1.3.1` APK와 같습니다. APK는
`com.threelines.three_lines`, versionCode 9, minSdk 24, targetSdk 36이며
`arm64-v8a`, `armeabi-v7a`, `x86_64`를 포함하고 debuggable 플래그는 없습니다.

### 검증 범위와 남은 한계

- 실제 router와 하단 탭을 포함한 알림 시험 18개 통과. 새 6개 회귀는
  375×812, 320×640, 640×320, 200% 글씨, 동작 줄이기와 접근성 탐색에서
  지속 알림 닫기, 48dp 조작, 한국어 이름, 입력 보존과 DB 저장을 확인합니다.
  현재 Flutter SDK에서는 action이 있는 알림이 일반 탐색에서도 기본적으로 유지됩니다.
- 전체 Flutter 시험 813개, 분석 지적 0개, Android 네이티브 시험 5개 통과.
  버전 guard, actionlint, APK/AAB 및 Apple secret 32조합, 아이콘,
  iOS 누락-secret guard와 실제 Gradle의 CI 무서명 거부 검사도 통과했습니다.
- [브랜치 CI](https://github.com/devcsb/3lines/actions/runs/39965340256),
  [main CI](https://github.com/devcsb/3lines/actions/runs/39966137440),
  [태그 CI](https://github.com/devcsb/3lines/actions/runs/39966137477) 성공.
  독립 소스 검토에서 배포 차단 결함은 없었습니다. 검토 중 발견한 단독 화면과
  실제 하단 탭의 시험 차이는 실제 router를 쓰는 fixture로 보완했습니다.
- 별도 Android 14 에뮬레이터에 공개 `v1.3.1`을 설치하고 가상 완료 기록과
  수정 중인 초안을 남겼습니다. 공개 `v1.3.2`를 앱 삭제 없이 업데이트하여
  versionCode 9를 확인했고, 다크 모드/200% 글씨에서 초안 복원과 수정 취소 후
  기존 완료 기록 유지를 확인했습니다. 실제 사용자 기록이나 기기는 사용하지 않았습니다.
  같은 공개 APK의 일반 탐색에서 예시를 추가하고 새 닫기 버튼을 눌러
  내용이 유지되는지 확인했습니다. 가려졌던 저장 버튼으로 저장한 뒤 앱을
  강제 종료하고 다시 열어 수정한 완료 기록이 남았음을 확인했습니다.
  사진 오류의 닫기와 재시도 분리는 위젯 시험 결과이며 OS 권한 오류를
  에뮬레이터에서 재현했다고 주장하지 않습니다.
- 물리 기기의 생체 센서, TalkBack 탐색 순서, 알림 도착, OS 백업과 다른 경로로
  설치한 모든 APK의 업데이트 호환성은 확인하지 않았습니다. 특정 타깃의 적합성,
  30초 완료율이나 심리 효과도 실측하지 않았습니다. 기존 도구체인 지원 중단 경고는
  이번 변경에서 업그레이드하거나 우회하지 않았습니다.

## 이전 배포 기록 (v1.3.0)

2026-10-20에 [v1.3.0](https://github.com/devcsb/3lines/releases/tag/v1.3.0)을
`2026-10-20T12:15:48Z`에 공개했습니다. 앱 버전은 `1.3.0+7`, 배포 소스는
`b6a3d6c93d9e257fb49a6dac92b950f119897754`이며 main과 태그에 반영했습니다.
[릴리스 실행 39419518612](https://github.com/devcsb/3lines/actions/runs/39419518612)에서
검증, Android 서명 빌드, APK/AAB 서명 검사와 GitHub 게시가 모두 성공했습니다.
Apple secret이 없어 iOS와 TestFlight는 건너뛰었으며 IPA는 없습니다.
Google Play나 App Store 배포는 하지 않았고 서명 키와 secret을 교체하지 않았습니다.

| 공개 파일 | 크기(bytes) | SHA-256 |
| --- | ---: | --- |
| `app-release.apk` | 75,552,806 | `90e80c7394dbc818d83290dd2d64134456066f15eaf8ae33bdcae72382e6275e` |
| `app-release.aab` | 73,031,968 | `af35b73f55b430db5aa68d1e9022055e0168c78af8c240666843823e373d02ad` |

공개 파일을 다시 내려받아 GitHub의 digest와 위 해시가 일치함을 확인했습니다.
APK는 apksigner v2 서명 검증, AAB는 jarsigner 검증을 통과했습니다.
jarsigner는 자체 서명 인증서의 신뢰 체인과 타임스탬프 경고도 출력했으며,
서명 검증 결과는 `jar verified`였습니다.
인증서 SHA-256은
`320c932cbc7cbc8f353f767020610caafb64f596e4762fa2266f8499271921df`로
v1.2.3 AAB, v1.3.0 AAB와 APK가 일치합니다. 이는 다른 경로에서 설치한
모든 APK와의 업데이트 호환성을 보장하지 않습니다.
APK 메타데이터는 `com.threelines.three_lines`, versionCode 7,
versionName 1.3.0, minSdk 24, targetSdk 36입니다.
ABI는 `arm64-v8a`, `armeabi-v7a`, `x86_64`이며 debuggable 플래그가 없습니다.

### 이번 배포 전후 검증

- 로컬 Flutter 분석 지적 0개, 전체 테스트 807개 통과.
- [검증 브랜치 CI](https://github.com/devcsb/3lines/actions/runs/39418631618),
  [main CI](https://github.com/devcsb/3lines/actions/runs/39419514804),
  [태그 CI](https://github.com/devcsb/3lines/actions/runs/39419518684) 성공.
- actionlint, APK/AAB 파이프라인과 Apple secret 32개 조합,
  아이콘 검사, iOS 누락-secret guard, 실제 Gradle의 CI 무서명 거부 검사 통과.
- 마지막 네이티브 검토에서 `MainActivity`가 인증 플러그인이 요구하는
  `FragmentActivity`가 아닌 문제를 발견했습니다. 실제 클래스 호환성 시험의
  실패를 확인한 뒤 `3f54276`에서 `FlutterFragmentActivity`와 낮/밤 AppCompat
  테마로 수정했습니다. Android 단위 테스트는 기존 위젯 4개와 새 회귀 1개,
  총 5개가 통과했습니다.
- 별도로 만든 Android 14 에뮬레이터에서 부팅 통합 시험 1개 통과.
  디버그 앱의 실제 PIN 인증, 재시작 후 잠금 해제, 강제 종료 후 초안 복구,
  저장과 타임라인 상세 조회를 가상 기록으로 확인했습니다.
  실제 화면에서 기본 글씨와 200% 글씨의 기록 상세를 확인했습니다.
- 공개된 서명 APK도 같은 전용 에뮬레이터에 새로 설치하여 버전과 정상 부팅,
  온보딩 표시, 가상 기록 저장과 강제 종료 후 완료 기록 유지를 확인했습니다.
  UI 자동화 중에는 예시의 '되돌리기' 알림이 저장 버튼 위에 유지되어,
  알림을 아래로 밀어 닫은 뒤 저장했습니다. 상시 보이는 알림 닫기 조작은
  당시 후속 UX 개선 항목이었으며 `v1.3.2`에서 닫기 버튼을 추가했습니다.
  디버그 설치와 가상 기록만 지웠고 사용자 기기, 실제 기록, 사진이나
  비밀 키는 읽거나 삭제하지 않았습니다.

물리 기기별 생체 센서, 화면 읽기 도구, OS 알림 도착, 백업과 이전 설치본
업데이트는 미검증입니다. 인증 창 취소 동작도 에뮬레이터의 ADB 조작으로는
완료를 확인하지 못했으며, 취소와 재시도 처리는 위젯 시험 결과와 구분합니다.
Gradle/AGP/Kotlin과 GitHub Actions의 향후 지원 중단 경고가 남아 있습니다.
이번 배포에서 도구체인 버전을 올리거나 검증을 우회하지 않았습니다.

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

릴리스 빌드에는 `--no-pub`를 추가하지 않습니다. Flutter 3.47.1에서는 이
옵션이 플랫폼 플러그인 등록 파일 재생성도 건너뜁니다. 테스트용 등록 파일이
남아 있으면 Gradle이 릴리스에서 제외한 `integration_test` 클래스를 Java에서
참조하여 컴파일에 실패할 수 있습니다. 생성 파일을 직접 고치거나 테스트
의존성을 배포 의존성으로 옮기지 말고 위 일반 빌드 명령으로 재생성합니다.

로컬 iOS archive는 Apple 인증서·프로필과 `pod install --deployment`가 필요합니다. CI 스크립트는 `tool/release/prepare_ios_signing.sh`와 `tool/release/generate_export_options.sh`를 사용합니다.
