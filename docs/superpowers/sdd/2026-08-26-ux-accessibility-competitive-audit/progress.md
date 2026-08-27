# UI/UX·접근성·배터리 감사 진행 원장

## 상태

- 완료일: 2026-08-26 (KST)
- 작업 브랜치: `codex/runtime-correctness-energy`
- 기준 커밋: `d1be2df`
- 감사 커밋 범위: `d1be2df..HEAD` (현재 브랜치의 릴리스 게이트 수정 포함)
- 판정: **운영 배포 보류(조건부 릴리스 후보)**. 코드 회귀와 Android 예약 경로는 보강했지만, 사용자 Android keystore와 iOS Team/인증서가 없어 서명된 운영 산출물을 만들 수 없다.

## 루브릭 점수

| 축 | 시작 | 현재 | 근거 |
|---|---:|---:|---|
| 핵심 기록 UX | 2/5 | 4/5 | 200% 시스템 글자 크기 보존, 새로고침 완료 계약, 기존 30초 흐름 보존 |
| 접근성 | 2/5 | 4/5 | 히트맵 48×48 논리 픽셀 semantics 타깃, 라벨, Android/iOS 가이드 테스트 |
| 배터리/백그라운드 | 3/5 | 4/5 | Android 위젯 자정 1회 inexact alarm, 이벤트 기반 동기화, 예약 알림만 사용; 실기기 측정은 미실시 |
| 플랫폼 일관성 | 2/5 | 4/5 | iOS 위젯 stale 날짜 정규화, Android/iOS 순수 상태 테스트 |
| 데이터 신뢰성 | 3/5 | 4/5 | export 버전 실제 `PackageInfo` 사용, 실패 fallback 및 round-trip 유지 |
| 출시 품질 | 3/5 | 4/5 | analyze/Flutter/Android 단위/iOS extension은 통과했지만 release 서명·스토어 업로드는 미완료 |

## 변경 요약

1. 루트 `TextScaler` 상한 제거: OS 글자 크기를 200%까지 앱이 임의로 제한하지 않는다.
2. 히트맵 시각 셀(8–20px)은 유지하고 semantics/gesture 컨테이너를 48×48로 확장했다.
3. Timeline/Insights pull-to-refresh가 provider Future 완료까지 spinner를 유지한다.
4. iOS 위젯이 저장 날짜와 현지 오늘 날짜가 다르면 완료·감정·상태를 오늘 기본값으로 초기화한다.
5. JSON export `version`을 실제 앱 버전으로 기록하고 플랫폼 조회 실패 시 state/`unknown`으로 안전하게 fallback한다.
6. Android 예약 알림 receiver와 재부팅 권한을 명시하고, 위젯은 현지 자정에 다음 갱신을 한 번 예약하며 재부팅·시간대·시계 변경 시 재예약한다.
7. 스트릭 위험 알림을 30일 단발 horizon으로 미리 예약해 앱을 열지 않아도 다음 날 알림이 유지되도록 했다.
8. 설정 질문 변경/초기화도 `journalChangesProvider`를 발행해 열린 앱의 위젯이 즉시 동기화된다.
9. Face ID privacy 문구와 `flutter_timezone` CocoaPods lock을 반영했다.
10. Android release는 debug key fallback을 제거하고, keystore가 없으면 배포 작업을 fail-closed한다.
11. 기존 최신 tag `v1.2.2`(build 5)와 중복되지 않도록 앱 버전을 `1.2.3+6`으로 올렸다.

## 검증 원장

| 명령 | 결과 |
|---|---|
| `dart format --output=none --set-exit-if-changed ...` | 11개 파일, 변경 0 |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 383개 통과 |
| `flutter test --coverage` | 기준 루프에서 381개 통과, 최신 일반 실행은 383개 통과 |
| focused Flutter tests | 35개 통과 |
| Swift 순수 상태 테스트 (`swiftc ... && /tmp/...`) | 통과 |
| `xcodebuild -project ios/Runner.xcodeproj -list` | Runner/Widget target 및 scheme 인식; `ThreeLinesWidgetTests` target은 아직 없음 |
| `xcodebuild ... -target ThreeLinesWidgetExtension ... build` | `BUILD SUCCEEDED`; 전체 Runner 빌드는 `Pods/Manifest.lock` 부재로 CocoaPods sync 단계에서 중단되고 archive/signing은 Team·profile 부재로 미검증 |
| Android JDK 21 `app:testDebugUnitTest --tests ...ThreeLinesWidgetStateTest` | `BUILD SUCCESSFUL` |
| `./gradlew app:processReleaseManifest -PallowUnsignedRelease=true` | 성공; 예약 receiver/`RECEIVE_BOOT_COMPLETED`가 merged manifest에 포함 |
| `./gradlew app:assembleRelease` | 의도적으로 실패; keystore가 없으면 배포 작업을 차단 |
| `./gradlew :app:assemble` (집계 경로) | 의도적으로 실패; `preReleaseBuild`에 `validateReleaseSigning`을 연결해 unsigned release 우회를 차단 |
| `./gradlew app:assembleRelease -PallowUnsignedRelease=true` | 로컬 unsigned 검증용으로만 성공 |
| `flutter build apk --release ... --android-project-arg=allowUnsignedRelease=true` | 로컬 unsigned arm64 컴파일만 성공; 운영 artifact 아님 |
| release signing report | keystore 미설정 상태에서 release signing Config가 없음(debug fallback 없음) |

## 2차 영향 재검증

릴리스 게이트 수정 후 Android JDK 21 단위 테스트, merged manifest 검사, 예약 알림 집중 테스트, iOS 순수 Swift 상태 테스트를 별도로 재실행해 통과했다. Flutter 빌드가 재생성하는 플랫폼 registrant는 커밋 대상이 아니므로 원상 복구했다. `flutter build`가 생성하는 `GeneratedPluginRegistrant`는 `integration_test` dev dependency를 일시적으로 포함할 수 있으므로 직접 Gradle release 작업은 Flutter 생성 단계 이후에 실행하고, 배포 CI는 표준 `flutter build` 경로를 사용한다.

코드 수준에서는 예약 receiver 누락, 자정 위젯 stale 및 재부팅/시간대 변경, 단발 스트릭 위험 알림, 설정 질문 위젯 stale, Face ID privacy key를 보강했다. 배터리 전류·알림 지연·VoiceOver/TalkBack 체감은 실기기에서만 측정 가능하므로 여전히 미검증이다.

## 확인된 비차단 경고

- Android 빌드가 성공했지만 Flutter가 Gradle 8.14/AGP 8.11.1/Kotlin 2.2.20의 향후 지원 중단 예정 경고를 출력한다. 현재 릴리스 차단 사유는 아니며 다음 유지보수 루프에서 버전 상향을 계획한다.
- APK 빌드의 CupertinoIcons font 탐색 경고는 현재 코드에서 `CupertinoIcons` 사용처가 없고 `uses-material-design: true`가 설정되어 있어 기능 영향은 확인되지 않았다. Cupertino 아이콘 도입 시 별도 의존성과 asset 검증이 필요하다.

## 배터리 검토

- 앱 코드에서 네트워크 권한과 주기적 polling을 추가하지 않았다.
- Android 위젯은 24시간 polling으로 바꾸지 않고, 위젯이 활성화된 동안 현지 자정 1회의 inexact `AlarmManager.setWindow`만 예약한다. 실행 후 다음 자정을 재예약하고 위젯이 제거되면 취소한다.
- 예약 알림은 Android `inexactAllowWhileIdle`를 사용하며, 30일 단발 데이터를 미리 등록할 뿐 주기적 앱 실행이나 네트워크 polling을 추가하지 않는다.
- 저널 저장 이벤트의 widget/notification side effect 중복을 방지하는 기존 루프와 이번 위젯 변경을 함께 회귀 검증했다.
- 실제 iOS/Android 기기의 배터리 사용량, Doze/App Nap, 알림 도착 지연은 이 환경에서 측정하지 않았다. 출시 후 프로파일링 항목으로 남긴다.

## 다음 루프 백로그

- P2: 태그/즐겨찾기와 다중 리마인더(데이터 모델·알림 UX·개인정보 정책 결정 필요)
- P2: Calm/Headspace 유형의 오디오·가이드 명상 콘텐츠(콘텐츠/저작권/오프라인 캐시 정책 필요)
- P2: 실제 기기 배터리·알림 지연 프로파일링 및 저사양 기기 접근성 수동 점검
- P2: 웹 알림 미지원 상태를 설정 화면에서 더 명확히 안내할지 제품 문구 결정
- P2: 잠금 화면 알림에 감사 답변을 표시할지 프라이버시 정책 결정(중립 문구·미리보기 숨김·opt-in 검토)
- P1 release: Android upload keystore를 CI secret으로 연결하고 Play 내부 테스트 트랙에 서명 artifact 배포
- P1 release: iOS `DEVELOPMENT_TEAM`, signing certificate/provisioning profile/App Group을 CI에 연결하고 TestFlight archive 검증
- P1 release: 실기기에서 예약 알림(앱 종료/재부팅), 자정 위젯, timezone 변경, Face ID, 배터리 프로파일링 수행
