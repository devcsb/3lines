# 3Lines 출시 전 UI/UX·접근성·배터리·경쟁 기능 심층 검토

## 결론

현재 코드는 **조건부 릴리스 후보**로 판단한다. 핵심 기록 루프와 로컬 데이터 경로에 대한 회귀 테스트, Flutter 정적 분석, Android 단위 테스트, iOS 위젯 extension 직접 빌드는 통과했다. Android 예약 receiver·위젯 자정 갱신·스트릭 위험 알림 horizon·Face ID privacy·prompt 위젯 sync도 보강했다. 다만 사용자 Android keystore와 iOS Team/인증서가 없어 운영 서명 artifact와 스토어 업로드는 완료할 수 없다.

릴리스 게이트 수정 후 Flutter 전체 테스트·Android 단위 테스트·iOS 순수 Swift 테스트·merged manifest를 재확인했고 모두 통과했다. 새 코드가 추가한 background polling이나 네트워크 의존성은 발견되지 않았지만, 실기기 예약 알림/배터리 도착 지연은 이 호스트에서 검증할 수 없다. Android 집계 `assemble`/`build`/`bundle` 경로도 `validateReleaseSigning`에 연결해 서명 없는 release 산출물 우회를 차단한다.

## 경쟁 앱 대비 기능 검토

| 영역 | Day One / Stoic / Calm·Headspace에서 확인한 기대 | 3Lines 현재 | 판단 |
|---|---|---|---|
| 습관 형성 | Day One의 reminder·streak, Stoic의 아침/저녁 reflection·smart reminder, Headspace의 streak | 3줄 기록, 감정, streak, 단일 reminder | 핵심 루프는 충족. 다중 세션은 P2 |
| 회고·탐색 | Day One의 search/tags/favorites/On This Day, Stoic의 trends | 검색, 히트맵, 감정·키워드 인사이트, 월/년 회고 | 검색·회고 기반은 충분. tags/favorites는 P2 |
| 마음챙김 콘텐츠 | Calm check-in(기분·수면·감사), Headspace/Calm의 guided audio/program | 감정 check-in·회고는 제공, 오디오/가이드 명상 없음 | 콘텐츠/저작권 범위라 이번 루프 제외 |
| 데이터 소유권 | Day One의 export·암호화·미디어, 플랫폼 간 동기화 기대 | JSON/PDF export, 로컬 DB, 생체 잠금 | 로컬 우선 장점. 동기화는 개인정보 결정 후 |
| 접근성 | 플랫폼 시스템 글자 크기와 큰 터치 영역 기대 | 200% scaler 보존, 히트맵 48×48 semantics target | 이번 루프에서 결함 해소 |

참고한 공식 자료: [Day One 기능](https://dayoneapp.com/features/), [Stoic 기능](https://www.getstoic.com/features), [Calm 체크인](https://support.calm.com/hc/en-us/articles/9699990936731), [Headspace streak](https://help.headspace.com/hc/en-us/articles/215730567-How-does-the-run-streak-feature-work).

## 구현·회귀 검토

### 접근성/사용성

- `ThreeLinesApp`가 시스템 `MediaQuery.textScaler`를 그대로 전달한다. 큰 글자를 억지로 1.3배에서 자르던 결함을 제거했다.
- 히트맵은 시각 밀도를 유지하면서 semantics label과 48×48 조작 영역을 제공한다. Flutter/Android 가이드의 44–48pt/dp 기준을 테스트로 고정했다.
- Timeline/Insights 새로고침 callback은 데이터 Future가 끝날 때까지 완료되지 않아, 사용자에게 보이는 spinner와 실제 상태 전환이 일치한다.
- 200% text scaler smoke test에서 핵심 앱 shell이 렌더링되고 overflow 예외가 발생하지 않는다.

### 플랫폼/데이터 정확성

- iOS 위젯은 명시적 Gregorian calendar와 현지 timezone으로 `yyyy-MM-dd`를 만들고 저장 날짜와 비교한다. 지난 날짜의 완료·감정 상태가 오늘 위젯에 남지 않는다.
- export metadata의 version은 `PackageInfo.fromPlatform()`을 우선하며, 실패 시 loaded state와 `unknown` 순으로 fallback한다. entries schema와 import parser는 변경하지 않았다.

### 배터리·백그라운드

- 이번 변경으로 polling, 네트워크, 추가 background task를 도입하지 않았다.
- Android 위젯은 활성화 시 현지 다음 자정에 inexact one-shot alarm을 예약하고, 갱신 시 다음 알람을 재예약한다. 재부팅·시간대·시계 변경 broadcast에서도 활성 위젯이 있으면 다음 자정 알람을 다시 예약한다. WidgetKit도 시스템 reload budget을 고려해 필요한 때만 갱신하도록 유지했다.
- `flutter_local_notifications` v22 요구사항에 맞춰 scheduled/boot receiver와 `RECEIVE_BOOT_COMPLETED`를 앱 manifest에 명시했다. 예약 구현은 `inexactAllowWhileIdle`이므로 exact-alarm 권한은 추가하지 않았다.
- Android/iOS 예약은 예약 시점의 시간대 정보를 사용하므로, WidgetBootstrap이 resume마다 IANA 식별자를 비교하고 변경 시 알림·위젯을 함께 재조정한다. 앱이 종료된 동안의 변경은 다음 실행에서 재조정하며, 실기기에서 해외 이동·DST·재부팅 도착을 확인해야 한다.
- 스트릭 위험 알림은 최대 30일 단발 horizon을 미리 등록한다. 앱이 종료돼도 OS 예약이 유지되며, 기록/설정 변경 시 이전 ID 범위를 모두 취소하고 다시 만든다.
- 웹에서는 지원되지 않는 로컬 예약 알림을 초기화·예약하지 않고 권한 요청을 거부해 설정 토글이 예외로 종료되지 않는다. 모바일 알림 기능은 Android/iOS 범위로 명시한다.
- 알림 본문은 중립 문구만 사용해 잠금 화면·웨어러블·알림 미러링에 저널 내용이 노출되지 않도록 했다. 개인화 미리보기는 명시적 opt-in 정책과 별도 테스트가 확정될 때까지 비활성 상태로 둔다.
- 배터리 수치 자체는 실기기에서 측정해야 한다. 자동화 통과를 배터리 절감 수치로 환산하지 않았다.

빌드 로그에는 향후 Flutter 지원 중단 예정인 Gradle 8.14/AGP 8.11.1/Kotlin 2.2.20 경고와 CupertinoIcons font 탐색 경고가 있다. 현재 APK 생성과 앱 코드에는 영향이 없지만, 다음 유지보수 릴리스에서 Android 도구체인을 상향하고 Cupertino 아이콘을 실제 도입할 경우 폰트 asset을 명시적으로 검증해야 한다.

참고: [WidgetKit reload budget](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/), [Flutter accessibility](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [Android accessibility touch target](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views?hl=en).

## 출시 게이트

| 게이트 | 결과 | 비고 |
|---|---|---|
| 정적 분석/포맷 | 통과 | `flutter analyze` 0 issues; format 변경 0 |
| Flutter 회귀 | 통과 | 전체 383개 통과 |
| Android 단위 | 통과 | JDK 21, 위젯 자정 계산 포함 `ThreeLinesWidgetStateTest` |
| Android release | 조건부 | unsigned 로컬 컴파일만 허용; variant pre-build 검증으로 `assemble`/`build` 집계 경로도 keystore 없이는 fail-closed |
| Android 예약 매니페스트 | 통과 | merged manifest에 scheduled/boot receiver와 `RECEIVE_BOOT_COMPLETED` 확인 |
| 스토어 버전 고유성 | 통과 | 기존 최신 tag `v1.2.2`(build 5) 이후 `1.2.3+6`으로 bump |
| iOS widget | 조건부 통과 | 순수 Swift 테스트 + extension 직접 build 통과. Swift 테스트 파일은 현재 Xcode 테스트 target에 등록되지 않아 CI XCTest 실행 증거가 없으며, 전체 Runner 빌드는 `Pods/Manifest.lock` 부재로 CocoaPods sync 단계에서 중단 |
| 실제 기기 UX | 미검증 | iOS/Android 수동 시나리오 필요 |
| 서명/스토어 배포 | 차단 | Android upload keystore와 iOS Team/certificate/provisioning이 현재 호스트에 없음 |

### 배포 권고

현재는 서명된 산출물이 없어 운영 배포를 진행하지 않는다. `allowUnsignedRelease=true`는 로컬 컴파일/매니페스트 검증 전용이며 배포용 우회 수단이 아니다. 다음 단계는 Android upload keystore와 iOS 서명 설정을 CI에 주입한 뒤, 실제 기기에서 200% 글자 크기·VoiceOver/TalkBack·히트맵 조작·앱 종료/재부팅 예약 알림·자정 위젯·timezone 변경·배터리 영향을 확인하고 Play 내부 테스트와 TestFlight로 승격하는 것이다.

iOS CI는 `flutter pub get` 또는 `flutter build`로 `Generated.xcconfig`를 먼저 재생성한 뒤 `xcodebuild -showBuildSettings`에서 `FLUTTER_BUILD_NAME=1.2.3`, `FLUTTER_BUILD_NUMBER=6`을 assertion해야 한다. 무시 대상 xcconfig를 갱신하지 않고 Xcode archive를 직접 실행하면 이전 1.2.2(5)가 남을 수 있다.
