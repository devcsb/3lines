# 3Lines - 하루 3줄 마이크로 저널

하루를 세 줄로 기록하는 미니멀 저널링 Flutter 앱입니다.

## 기술 스택

| 영역 | 라이브러리 |
|------|-----------|
| 상태관리 | flutter_riverpod, riverpod_annotation |
| 라우팅 | go_router |
| 로컬 DB | drift (SQLite) |
| 차트 | fl_chart |
| 알림 | flutter_local_notifications |
| 인증 | local_auth (생체인증) |

## 사전 준비

### 1. Flutter SDK 설치

Flutter 3.41 이상 / Dart 3.11 이상이 필요합니다.

```bash
# 설치 확인
flutter --version

# 아직 설치하지 않았다면: https://docs.flutter.dev/get-started/install
```

### 2. 플랫폼별 개발 환경

| 플랫폼 | 필요 도구 |
|--------|----------|
| iOS | Xcode 15+, CocoaPods |
| Android | Android Studio, JDK 17 |
| macOS | Xcode 15+ |
| Web | Chrome |
| Windows | Visual Studio 2022 (C++ 데스크톱 개발 워크로드) |
| Linux | clang, cmake, ninja-build, libgtk-3-dev |

환경이 올바르게 설정되었는지 확인:

```bash
flutter doctor
```

모든 항목에 체크가 표시되어야 합니다. 문제가 있으면 `flutter doctor` 출력의 안내를 따르세요.

## 실행 방법

### 1. 의존성 설치

```bash
cd micro-journal
flutter pub get
```

### 2. 코드 생성 (필수)

이 프로젝트는 **drift**(DB)와 **riverpod_generator**를 사용하므로, 먼저 코드 생성을 실행해야 합니다.

```bash
dart run build_runner build --delete-conflicting-outputs
```

> `*.g.dart` 파일들이 생성됩니다. 이 단계를 건너뛰면 컴파일 에러가 발생합니다.

개발 중 파일 변경을 감지하며 자동으로 재생성하려면:

```bash
dart run build_runner watch --delete-conflicting-outputs
```

### 3. 앱 실행

```bash
# 연결된 기기/에뮬레이터 확인
flutter devices

# 기본 기기에서 실행 (디버그 모드)
flutter run

# 특정 플랫폼 지정
flutter run -d chrome          # 웹
flutter run -d macos           # macOS 데스크톱
flutter run -d <device-id>     # 특정 기기 (flutter devices 출력에서 확인)
```

### iOS 실행 시 추가 단계

```bash
cd ios
pod install
cd ..
flutter run -d <ios-device-or-simulator>
```

### 릴리스 빌드

```bash
flutter build apk              # Android APK
flutter build appbundle         # Android App Bundle (Play Store)
flutter build ios               # iOS (Xcode에서 아카이브 필요)
flutter build macos             # macOS
flutter build web               # 웹 (build/web 디렉토리에 출력)
```

## 테스트

```bash
# 전체 테스트 실행
flutter test

# 특정 테스트 파일 실행
flutter test test/core/utils/text_analysis_test.dart
```

## 프로젝트 구조

```
lib/
├── app.dart                     # 앱 진입점, 라우팅 설정
├── core/
│   ├── constants/               # 기본 프롬프트 등 상수
│   ├── services/                # 알림, 생체인증 서비스
│   ├── theme/                   # 테마 설정 (라이트/다크)
│   └── utils/                   # 날짜, 텍스트 분석 유틸리티
├── data/
│   ├── database/                # Drift DB 정의 및 플랫폼별 연결
│   ├── models/                  # 데이터 모델 (DailyEntry 등)
│   └── repositories/            # 데이터 접근 레이어
├── features/
│   ├── insights/                # 인사이트/통계 화면
│   ├── lock/                    # 생체인증 잠금 화면
│   ├── onboarding/              # 온보딩 화면
│   ├── settings/                # 설정 화면
│   ├── timeline/                # 타임라인 화면
│   └── today/                   # 오늘의 기록 화면
└── shared/
    └── widgets/                 # 공통 위젯 (하단 네비게이션 등)
```

## 문제 해결

| 증상 | 해결 방법 |
|------|----------|
| `*.g.dart` 파일을 찾을 수 없음 | `dart run build_runner build --delete-conflicting-outputs` 실행 |
| CocoaPods 관련 에러 (iOS/macOS) | `cd ios && pod install --repo-update && cd ..` |
| Gradle 빌드 실패 (Android) | JDK 17 설치 확인, `cd android && ./gradlew clean && cd ..` |
| 패키지 버전 충돌 | `flutter pub upgrade --major-versions` |
| 전체 초기화 | `flutter clean && flutter pub get && dart run build_runner build --delete-conflicting-outputs` |
