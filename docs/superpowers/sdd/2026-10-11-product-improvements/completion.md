# 제품 개선 완료 대조

## 범위와 현재 판정

구현 브랜치는 `codex/data-safety-import-implementation`이며 앱 소스 기준은
`5468c00`이다. 로컬 기능·표시 개선의 독립 검토 지적은 모두 닫았다.
root 전체 분석과 807개 시험, Android 로컬 unsigned 컴파일은 통과했다.
외부 릴리스 게시, 계정·secret 변경, 실제 사용자 자료 접근은 하지 않았다.
아래 판정은 실기기 동작이나 제품 효과를 검증했다는 뜻이 아니다.

## 요구사항별 근거

| 요구 | 구현과 검증 | 직접 근거 |
|---|---|---|
| R1 작성 연속성 | 날짜별 영속 초안, 질문 snapshot, revision·epoch 보호, 저장과 초안 제거의 원자 처리, 원본 충돌·손상 복구, 전체 삭제와 사진 참조 보존 | `lib/data/models/journal_draft.dart:29`, `lib/data/repositories/entry_repository.dart:55,133,259,280`, `lib/features/today/today_controller.dart:35,384`; `test/features/today/durable_drafts_test.dart`, `durable_drafts_screen_test.dart`, `test/data/repositories/journal_draft_repository_test.dart` |
| R2 기록 탐색 | 전체 빈 기록과 기간 공백 구분, 검색 clear/늦은 응답 무효화, 기간 선택 유지, 달력 기준 기간과 DST, 상세 양 끝과 실패 복구 | `lib/features/timeline/timeline_controller.dart:73,78,104`, `timeline_screen.dart`, `widgets/heatmap_grid.dart`, `widgets/entry_detail_sheet.dart`; `test/features/timeline/` |
| R3 통계 정합성 | 정확한 7/30/90일, 실제 한 번의 유예와 전체 날짜 기반 최장 streak, 빈 표본·소표본 안내, 최신 선택 유지, 월별 PDF 단일 snapshot | `lib/data/repositories/entry_repository.dart:431,473`, `lib/features/insights/insights_controller.dart`, `lib/core/services/pdf_report_service.dart`; `test/data/repositories/entry_repository_test.dart`, `test/features/insights/`, `test/core/services/pdf_report_service_test.dart` |
| R4 작성과 회복 | 200 grapheme 예시 경계, 가져온 장문 보존과 같은 session import 상한 갱신, stale Undo 거부, 실제 질문별 예시, 사진 취소/권한/복사 실패 구분·재시도, 질문 초기화 transaction과 인증 재시도 | `lib/features/today/today_controller.dart:471,488`, `answer_input.dart`, `widgets/prompt_help.dart`, `lib/core/services/photo_service.dart`, `lib/features/settings/widgets/questions_section.dart`; `test/features/today/{writing_recovery_screen_test,photo_recovery_screen_test}.dart`, `test/features/settings/prompt_reset_transaction_test.dart`, `test/features/lock/` |
| R5 알림·보관 안내 | 선택 시간의 하루 한 번 알림과 작성한 날 건너뛰기, 미동의 위험/회고 예약 제거, 실패 보상 유지, JSON 평문·사진/초안/설정 미포함·OS 백업·앱 잠금 범위 안내 | `lib/core/services/{notification_service,reminder_coordinator}.dart`, `lib/features/settings/widgets/{notifications_section,data_section,security_section}.dart`, `lib/features/onboarding/onboarding_screen.dart`; `test/core/services/notification_service_test.dart`, `reminder_coordinator_test.dart`; `docs/ANDROID_BETA.md:9,11` |
| R6 시각·베타 진입 | 정보색 대비, native 48dp 조작, 한글 200%/좁은 화면/가로/감소 모션 렌더, 날짜축 간격, 손상 확인 본문과 사진 제거 겹침, 자체 launcher 아이콘, APK 생성·서명검증·첨부 pipeline, 정직한 베타 관찰 분모 | `lib/core/theme/app_theme.dart`, `lib/features/onboarding/`, `lib/features/{today,timeline,insights,settings}/`, `tool/branding/`, `.github/workflows/release.yml:134,136,138,140,218`; `test/core/theme/app_theme_readability_test.dart`, `test/features/today/today_readability_test.dart`, `test/features/settings/settings_readability_test.dart`, `test/tool/release/`, `docs/ANDROID_BETA.md:15,24` |

구현자는 medium, 독립 검토자는 xhigh로 나눴다. 반복 검토는 실제로 확인된
반례의 수정과 접점에 한정했다. Task1/2/5, Task3, Task4a/4b, Task6a/6b,
Task7의 검토 지적을 모두 닫았으며 마지막 사진 Minor는 `5468c00`에서 닫았다.
상세 이력은 [진행 기록](progress.md), 수락 조건은
[설계](../../specs/2026-10-11-product-trust-and-ux-design.md)를 따른다.

## root 최종 실행

- `flutter analyze --no-pub`: `5468c00` 기준 No issues found, exit 0.
- `flutter test --no-pub --reporter expanded`: `5468c00` 기준 807 PASS, exit 0, 약33초.
  로그 `/tmp/3lines-product-final-tests-5468c00.log`.
- `ruby test/tool/release/launcher_assets_test.rb`: 크기, Apple PNG 불투명,
  Windows ICO, adaptive 안전 영역, 대비5.2:1 PASS.
- `ruby test/tool/release/android_beta_pipeline_test.rb`: APK/AAB 생성·검증·평탄한
  첨부 경로와 Apple32설정/release조건 PASS. 외부 빌드·서명 명령은 fake이므로
  실제 인증서나 업로드 성공을 입증하지 않는다.
- `bash test/tool/release/ios_release_config_test.sh`: 설정·누락secret guard PASS.
- `bash test/tool/release/android_release_gate_test.sh`: 실제 Gradle에서
  CI의 unsigned 허용을 거부하는 메시지를 확인하고 shell gate exit 0.
- `env -u CI JAVA_HOME=<JDK21> flutter build apk --release
  --android-project-arg=allowUnsignedRelease=true`: exit 0, 약51초.
  로그 `/tmp/3lines-product-android-build-with-pub.log`.
  APK `build/app/outputs/flutter-apk/app-release.apk`, 75,244,034 bytes,
  SHA-256 `096cf186101b68588c6f1bf696fcce8583b792ab5c065e04b0e723411fd064ef`.
  `apksigner verify --verbose`는 exit 1/`DOES NOT VERIFY`다.
  이는 의도한 로컬 무서명 검증 산출물이며 설치·배포용 서명 APK가 아니다.

첫 Android 시도는 `--no-pub` 때문에 기존 GeneratedPluginRegistrant에
`integration_test`가 남아 Java 컴파일에서 실패했다. 로컬 Flutter3.47.1의
`flutter_command.dart` 재생성 조건과 `flutter_plugins.dart` release dev-plugin
필터를 읽고, `--no-pub`만 빼서 재실행했다. 자동 재생성된 파일에서 테스트
플러그인이 빠졌고 컴파일에 성공했다. 생성 파일을 수동 수정하거나 dependency를
옮기지 않았고 `pubspec.lock`도 바뀌지 않았다. CI의 빌드 명령에는 원래 이 옵션이 없다.

Flutter migrator가 `android/gradle.properties`에 추가한
`android.builtInKotlin=false`, `android.newDsl=false`를 유지해 현재 프로젝트의
외부 Kotlin plugin/기존 DSL 사용을 명시했다. 로컬 Kotlin 생성 캐시
`android/.kotlin/`는 Android ignore에 추가했다. 원래 Gradle8.14/AGP8.11.1/
Kotlin2.2.20에서 빌드가 성공했지만 Flutter는 향후 지원 중단 경고를 출력했다.
이번 범위에서 패키지·Gradle·AGP·Kotlin 버전을 올리거나 검증을 우회하지 않았다.

## 실제 화면 확인

가상 기록·메모리 DB·임시 사진과 앱의 한글/MaterialIcons 폰트로 렌더했다.
실행자와 독립 검토자가 대표 PNG를 확인했고 root도 온보딩, 아이콘,
Insights, 감정 선택, 설정, 손상 안내, 사진 오류 조합을 열었다.
모든 실기기·가능한 상태 조합을 육안 검사했다고 주장하지 않는다.

최종 사진 오류의 실제 부모 Stack 시험은 텍스트와 제거48dp 영역의 겹침,
readonly 폭256, 정상 사진 높이180과 제거 callback을 함께 확인한다.
기존 errorBuilder 단독 렌더가 놓친 반례와 fixture 오류는 제품 실패와 구분했다.

## 외부 배포와 남은 한계

2026-10-11 root의 마지막 GitHub 조회에서도 최신 공개 릴리스는
[v1.2.3](https://github.com/devcsb/3lines/releases/tag/v1.2.3),
게시 시각은 `2026-08-29T06:58:51Z`다. `app-release.aab`
72,099,129 bytes만 있으며 APK/IPA는 없다. 현재 개선 소스는 배포하지 않았다.

repository Android secret 네 이름은 등록을 확인했고 값은 읽지 않았다.
Apple/ASC 이름은 해당 repository 목록에 없었다. 조직/environment secret,
Apple 계정 등록과 유효성은 확인 불가다. 자세한 입력과 gate는
[RELEASE.md](../../../RELEASE.md)를 따른다. Google Play 등록은 GitHub Release에 필요하지 않다.

- 실제 기기의 설치/업데이트, OS picker·권한·인증, 화면 읽기 도구, 키보드,
  알림 도착, 공유와 OS 백업은 미검증이다.
- 알림은 기존 one-shot 30일 예약 범위를 유지한다. 30일 넘게 앱을 열지 않을
  때의 예약 연장은 보장하지 않는다.
- 제품 효과, 특정 연령 적합성, 30초 완료율은 실측하지 않았다. 베타 문서의
  관찰 시나리오와 분모는 계획이며 새 추적·본문 수집 기능은 추가하지 않았다.
- 실제 배포에는 개선 소스 통합, 새 버전/태그와 서명 CI 실행, APK 설치 확인이
  남는다. 현재 `pubspec.yaml`은 이미 공개된 `1.2.3+6`이므로 기존 태그를 새
  코드에 재사용하지 않는다. 이 작업에서 push/merge/tag/publish는 하지 않았다.
