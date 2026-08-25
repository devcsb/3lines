# 3Lines 출시 전 UI/UX·접근성·배터리·경쟁 기능 심층 검토

## 결론

현재 코드는 **릴리스 후보**로 판단한다. 핵심 기록 루프와 로컬 데이터 경로에 대한 회귀 테스트, Flutter 정적 분석, Android arm64 릴리스 빌드, iOS 위젯 extension 직접 빌드는 통과했다. 다만 실기기 배터리/알림 지연 측정과 배포 서명·스토어 업로드는 수행하지 않았으므로, 이 결과만으로 스토어 배포 완료라고 주장할 수는 없다.

동일 커밋에 대해 2차 재검증을 수행했으며, Flutter 381개·Android 단위·iOS extension·Android arm64 APK·release 권한 검사가 모두 동일하게 통과했다. 새 코드 회귀나 백그라운드 비용 증가 패턴은 발견되지 않았다.

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

- iOS 위젯은 `Calendar.current`의 현지 `yyyy-MM-dd`와 저장 날짜를 비교한다. 지난 날짜의 완료·감정 상태가 오늘 위젯에 남지 않는다.
- export metadata의 version은 `PackageInfo.fromPlatform()`을 우선하며, 실패 시 loaded state와 `unknown` 순으로 fallback한다. entries schema와 import parser는 변경하지 않았다.

### 배터리·백그라운드

- 이번 변경으로 polling, 네트워크, 추가 background task를 도입하지 않았다.
- Android 위젯의 기존 24시간 갱신 상한과 이벤트 기반 동기화를 유지했다. WidgetKit도 시스템 reload budget을 고려해 필요한 때만 갱신해야 하므로, 무리한 주기 갱신을 추가하지 않았다.
- release merged manifest에서 `INTERNET` 및 `SCHEDULE_EXACT_ALARM`이 확인되지 않았다. 알림 표시를 위한 `POST_NOTIFICATIONS`와 위젯/알림 실행에 필요한 `WAKE_LOCK`만 남아 있다.
- 배터리 수치 자체는 실기기에서 측정해야 한다. 자동화 통과를 배터리 절감 수치로 환산하지 않았다.

빌드 로그에는 향후 Flutter 지원 중단 예정인 Gradle 8.14/AGP 8.11.1/Kotlin 2.2.20 경고와 CupertinoIcons font 탐색 경고가 있다. 현재 APK 생성과 앱 코드에는 영향이 없지만, 다음 유지보수 릴리스에서 Android 도구체인을 상향하고 Cupertino 아이콘을 실제 도입할 경우 폰트 asset을 명시적으로 검증해야 한다.

참고: [WidgetKit reload budget](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date/), [Flutter accessibility](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling), [Android accessibility touch target](https://developer.android.com/guide/topics/ui/accessibility/views/apps-views?hl=en).

## 출시 게이트

| 게이트 | 결과 | 비고 |
|---|---|---|
| 정적 분석/포맷 | 통과 | `flutter analyze` 0 issues; format 변경 0 |
| Flutter 회귀 | 통과 | 전체 381개, coverage 실행도 381개 |
| Android 단위 | 통과 | JDK 21, `ThreeLinesWidgetStateTest` |
| Android release | 통과 | arm64 APK 27.6MB, size analysis 생성 |
| iOS widget | 조건부 통과 | 순수 Swift 테스트 + extension 직접 build 통과. 전체 scheme은 이 worktree에 CocoaPods `xcfilelist`가 없어 Runner 의존 단계에서 중단 |
| 실제 기기 UX | 미검증 | iOS/Android 수동 시나리오 필요 |
| 서명/스토어 배포 | 미실시 | 인증서·스토어 계정이 필요 |

### 배포 권고

Android 내부 테스트 트랙에 올릴 수 있는 **빌드 후보**이지만, 서명된 산출물 생성 전에는 공개 배포하지 않는다. 다음 단계는 실제 기기에서 200% 글자 크기, VoiceOver/TalkBack, 히트맵 손가락 조작, 알림 도착 시각, 24시간 위젯 배터리 영향을 확인하고 CocoaPods를 복원한 뒤 Android Play 내부 테스트와 iOS TestFlight로 승격하는 것이다.
