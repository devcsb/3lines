# 3Lines 릴리스 파이프라인 설계

## 목표

배포 가능한 릴리스가 서명·버전·의존성·테스트 조건을 모두 충족하도록 자동 검증하고, 비밀값은 저장소에 남기지 않은 채 GitHub Actions에서 Android/iOS 산출물을 재현 가능하게 만들고 보관한다.

## 범위

- `pubspec.yaml` 버전과 Git 태그의 일치 및 기존 태그와의 중복을 검증한다.
- Android release가 CI에서 unsigned/debug 서명으로 통과하지 않도록 fail-closed 한다.
- iOS Runner와 위젯 확장의 배포 인증서·프로비저닝 프로필을 CI secret으로 주입한다.
- `flutter pub get`과 `pod install --deployment`를 릴리스 전제 조건으로 고정한다.
- pull request CI와 태그 기반 릴리스 workflow를 제공한다.
- GitHub Release에는 빌드 산출물을 첨부하되, App Store/TestFlight 업로드는 명시적 workflow 입력과 자격 증명이 있을 때만 실행한다.

## 비목표

- Apple Developer 계정, Play Console, App Store Connect 자격 증명을 저장소에 생성하거나 자동 발급하지 않는다.
- 실제 스토어 업로드를 자격 증명 없이 시도하지 않는다.
- 로컬 개발자가 unsigned APK를 배포하는 우회 경로를 제공하지 않는다. `allowUnsignedRelease=true`는 로컬 비배포 검증에서만 허용한다.

## 결정 사항

### 버전 정책

`pubspec.yaml`의 `version: name+build`를 단일 원천으로 사용한다. 태그는 `v<name>` 형식이어야 하며, 현재 저장소의 태그와 동일한 이름·빌드 조합은 거부한다. 릴리스 workflow는 태그가 `pubspec.yaml`과 일치하지 않으면 즉시 실패한다.

### Android

`android/keystore.properties`는 로컬 파일 또는 CI가 임시 생성하며 Git에 커밋하지 않는다. release signing 설정이 없으면 모든 release variant의 사전 태스크가 실패한다. `CI=true`에서 `allowUnsignedRelease=true`를 사용하면 명시적으로 실패한다. 생성된 AAB/APK는 `apksigner` 또는 `jarsigner`로 검증하고 Android Debug signer를 거부한다.

### iOS

Runner 앱과 `ThreeLinesWidgetExtension`은 서로 다른 provisioning profile을 사용한다. 프로젝트 Release/Profile 설정은 CI가 주입할 수 있는 명시적 build-setting 변수(`IOS_DEVELOPMENT_TEAM`, `IOS_SIGNING_IDENTITY`, `IOS_RUNNER_PROVISIONING_PROFILE_SPECIFIER`, `IOS_WIDGET_PROVISIONING_PROFILE_SPECIFIER`)를 참조한다. CI는 base64로 전달된 p12 및 두 mobileprovision 파일을 임시 keychain/profile 디렉터리에 설치하고, archive/export 전에 `pod install --deployment`를 수행한다.

### CI와 릴리스

- PR/push CI: Flutter 의존성 설치, 정적 분석, Flutter 테스트, Android unit test를 실행한다.
- `v*` 태그 또는 수동 실행 릴리스: 버전 검증 후 Android AAB와 iOS IPA를 빌드하고 GitHub Release에 첨부한다.
- TestFlight 업로드는 `upload=true` 수동 입력과 `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_BASE64`가 모두 있을 때만 수행한다. 조건이 맞지 않으면 빌드는 성공하되 업로드 job은 실행하지 않는다.
- 서명·프로필·keystore secret이 없는 릴리스 빌드는 성공으로 간주하지 않는다.

## 실패 정책

서명 설정, 버전 태그, CocoaPods lock 동기화, 테스트, 산출물 서명 검증 중 하나라도 실패하면 배포 산출물을 릴리스하지 않는다. 로컬 unsigned 검증은 workflow가 아닌 개발자 명령으로만 명시한다.
