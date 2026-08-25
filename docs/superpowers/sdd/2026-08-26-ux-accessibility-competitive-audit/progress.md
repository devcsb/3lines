# UI/UX·접근성·배터리 감사 진행 원장

## 상태

- 완료일: 2026-08-26 (KST)
- 작업 브랜치: `codex/runtime-correctness-energy`
- 기준 커밋: `d1be2df`
- 감사 커밋 범위: `59b278e..5bd9ee7`
- 판정: **릴리스 후보(조건부)**. 코드·테스트·Android arm64 산출물은 게이트를 통과했지만 실기기 배터리/알림 지연과 App Store 서명·배포는 별도 검증이 필요하다.

## 루브릭 점수

| 축 | 시작 | 현재 | 근거 |
|---|---:|---:|---|
| 핵심 기록 UX | 2/5 | 4/5 | 200% 시스템 글자 크기 보존, 새로고침 완료 계약, 기존 30초 흐름 보존 |
| 접근성 | 2/5 | 4/5 | 히트맵 48×48 논리 픽셀 semantics 타깃, 라벨, Android/iOS 가이드 테스트 |
| 배터리/백그라운드 | 3/5 | 4/5 | Android 위젯 갱신 24시간 정책과 중복 side effect 회귀 고정; 실기기 측정은 미실시 |
| 플랫폼 일관성 | 2/5 | 4/5 | iOS 위젯 stale 날짜 정규화, Android/iOS 순수 상태 테스트 |
| 데이터 신뢰성 | 3/5 | 4/5 | export 버전 실제 `PackageInfo` 사용, 실패 fallback 및 round-trip 유지 |
| 출시 품질 | 3/5 | 4/5 | analyze 0, Flutter 381개, Android 단위/릴리스 빌드, iOS extension 직접 빌드 |

## 변경 요약

1. 루트 `TextScaler` 상한 제거: OS 글자 크기를 200%까지 앱이 임의로 제한하지 않는다.
2. 히트맵 시각 셀(8–20px)은 유지하고 semantics/gesture 컨테이너를 48×48로 확장했다.
3. Timeline/Insights pull-to-refresh가 provider Future 완료까지 spinner를 유지한다.
4. iOS 위젯이 저장 날짜와 현지 오늘 날짜가 다르면 완료·감정·상태를 오늘 기본값으로 초기화한다.
5. JSON export `version`을 실제 앱 버전으로 기록하고 플랫폼 조회 실패 시 state/`unknown`으로 안전하게 fallback한다.

## 검증 원장

| 명령 | 결과 |
|---|---|
| `dart format --output=none --set-exit-if-changed ...` | 11개 파일, 변경 0 |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 381개 통과 |
| `flutter test --coverage` | 381개 통과, 전체 라인 3291/5137 = 64.1% |
| focused Flutter tests | 35개 통과 |
| Swift 순수 상태 테스트 (`swiftc ... && /tmp/...`) | 통과 |
| `xcodebuild -project ios/Runner.xcodeproj -list` | Runner/Widget target 및 scheme 인식 |
| `xcodebuild ... -target ThreeLinesWidgetExtension ... build` | `BUILD SUCCEEDED` (전체 Runner scheme은 CocoaPods xcfilelist 부재로 별도 중단) |
| Android JDK 21 `app:testDebugUnitTest --tests ...ThreeLinesWidgetStateTest` | `BUILD SUCCESSFUL` |
| `flutter build apk --release --target-platform android-arm64 --analyze-size` | `app-release.apk` 27.6MB 생성 |
| release merged manifest 권한 검사 | `INTERNET`·`SCHEDULE_EXACT_ALARM` 없음; 알림/깨우기 권한만 존재 |

## 2차 영향 재검증

동일 커밋(`22f15c1`)을 대상으로 재실행한 결과다.

- `flutter analyze`: 다시 `No issues found!`
- `flutter test`: 다시 **381개 통과**
- Android JDK 21 `ThreeLinesWidgetStateTest`: 다시 `BUILD SUCCESSFUL`
- iOS 순수 Swift 상태 테스트 및 `ThreeLinesWidgetExtension` 직접 빌드: 다시 통과
- Android arm64 release APK: 다시 27.6MB 생성 성공
- release merged manifest: `INTERNET`·`SCHEDULE_EXACT_ALARM` 없이 `POST_NOTIFICATIONS`·`WAKE_LOCK`만 확인
- polling/네트워크/중복 side-effect 정적 검색: 신규 위험 패턴 없음
- 자동 생성 파일을 원복한 뒤 `git status` clean, `git diff --check` 통과

재검증으로 코드 수준의 추가 회귀는 발견되지 않았다. 배터리 전류·알림 지연·VoiceOver/TalkBack 체감은 실기기에서만 측정 가능하므로 여전히 미검증이다.

## 확인된 비차단 경고

- Android 빌드가 성공했지만 Flutter가 Gradle 8.14/AGP 8.11.1/Kotlin 2.2.20의 향후 지원 중단 예정 경고를 출력한다. 현재 릴리스 차단 사유는 아니며 다음 유지보수 루프에서 버전 상향을 계획한다.
- APK 빌드의 CupertinoIcons font 탐색 경고는 현재 코드에서 `CupertinoIcons` 사용처가 없고 `uses-material-design: true`가 설정되어 있어 기능 영향은 확인되지 않았다. Cupertino 아이콘 도입 시 별도 의존성과 asset 검증이 필요하다.

## 배터리 검토

- 앱 코드에서 네트워크 권한과 주기적 polling을 추가하지 않았다.
- Android 위젯은 기존 24시간 갱신 상한과 필요한 경우에만 갱신하는 경로를 유지한다.
- 저널 저장 이벤트의 widget/notification side effect 중복을 방지하는 기존 루프와 이번 위젯 변경을 함께 회귀 검증했다.
- 실제 iOS/Android 기기의 배터리 사용량, Doze/App Nap, 알림 도착 지연은 이 환경에서 측정하지 않았다. 출시 후 프로파일링 항목으로 남긴다.

## 다음 루프 백로그

- P2: 태그/즐겨찾기와 다중 리마인더(데이터 모델·알림 UX·개인정보 정책 결정 필요)
- P2: Calm/Headspace 유형의 오디오·가이드 명상 콘텐츠(콘텐츠/저작권/오프라인 캐시 정책 필요)
- P2: 실제 기기 배터리·알림 지연 프로파일링 및 저사양 기기 접근성 수동 점검
- P1 release: iOS archive/App Store 서명, Android Play 서명·내부 테스트 트랙 배포
