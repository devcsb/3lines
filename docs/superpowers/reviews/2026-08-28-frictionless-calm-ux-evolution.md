# Frictionless Calm UX 고도화 검증 보고서

## 검증 범위

- 브랜치: `codex/runtime-correctness-energy`
- 대상: 모션 토큰·reduce-motion, 하단 탭 전환, 저장 완료 피드백, 빈 타임라인 회복 CTA
- 제외: iOS 서명·프로비저닝, CocoaPods 설치 상태, 실기기 알림/위젯, 실제 배터리·프레임 측정
- 설계 기준: `docs/superpowers/specs/2026-08-28-frictionless-calm-ux-evolution-design.md`

## 변경 요약

1. `AppMotion`에 `0/120/240/360/600ms` duration과 공통 easing을 정의하고, StaggeredFadeIn·Heatmap·Insights 잠금 화면에 적용했다.
2. `BranchFadeThrough`가 `StatefulNavigationShell`을 한 번만 보유한 채 활성 브랜치의 opacity/offset만 240ms 동안 전환한다. `AnimatedSwitcher`로 shell을 중복 마운트하지 않는다.
3. 저장 완료 오버레이의 주요 모션을 600ms 이하로 줄이고, 자동 종료와 별개로 즉시 누를 수 있는 `완료 화면 닫기` 버튼을 추가했다. 완료 callback은 한 번만 실행된다.
4. 완료 문구에서 글쓰기 효능·행복 보장·변화 보장으로 읽힐 수 있는 표현을 제거하고 감정 기록을 인정하는 중립 문구로 바꿨다.
5. 기록이 없는 타임라인에 `오늘 기록하기` 한 번의 회복 CTA를 추가했다. 데이터 모델·알림·위젯 계약은 변경하지 않았다.

## 자동 검증

| 검사 | 결과 | 증거 |
|---|---|---|
| `flutter test` 전체 | PASS — 401개 | `/tmp/3lines-flutter-test.log` 마지막 줄 `+401: All tests passed!` |
| `dart analyze` | PASS | `No issues found!` |
| 신규·핵심 focused tests | PASS — 15개 | 모션 토큰, stagger, branch transition, completion, timeline 테스트 실행 결과 |
| 기존 routing/integration 회귀 | PASS — 5개 | `routing_flash_test.dart`, `integration/app_flow_test.dart`, branch test 실행 결과 |
| 변경 파일 formatter | PASS | 13개 대상 `dart format --output=none --set-exit-if-changed` exit 0 |
| 저장소 전체 formatter | 기준 차이 | 설치된 formatter가 기존 49개 파일을 변경 대상으로 보고했으나 파일은 수정하지 않았다. 이번 변경 파일은 모두 별도 formatter 검사 PASS. |
| `git diff --check` | PASS | feature 브랜치와 `main` merge-base 기준 공백 오류 없음 |

## 접근성 검증

- `test/app/accessibility_guideline_test.dart`: Android/iOS tap-target 및 labeled-target guideline PASS.
- `test/app/text_scaling_test.dart`: 시스템 200% text scaler를 루트에서 제한하지 않음 PASS.
- `CompletionAnimation`: `기록 저장 완료` route semantics와 `완료 화면 닫기` button semantics PASS.
- reduce-motion: StaggeredFadeIn·BranchFadeThrough·완료 오버레이의 즉시 최종 상태 테스트 PASS.
- 실제 VoiceOver/TalkBack 탐색, 실제 200% 화면 레이아웃, 실제 색상 대비 측정: **미실행**.

## 회귀 위험 검토

- `StatefulNavigationShell`·Riverpod 화면 상태·로컬 DB에는 구조 변경을 하지 않았다.
- 전환 래퍼는 이전/새 shell을 동시에 생성하지 않으므로 기존 Duplicate GlobalKey 방지 설계와 양립한다.
- 자동 종료 타이머와 버튼이 같은 idempotent dismiss 경로를 사용해 중복 저장/중복 라우팅 callback을 막는다.
- 알림 본문은 저널 답변을 참조하지 않으며, 이번 변경은 알림 예약·위젯 동기화 로직을 건드리지 않는다.
- 앱 상태가 이미 완료된 Today 화면을 다시 열 때의 기존 read/edit 상태와 integration test는 유지됐다.

## 실기기 검증

다음 항목은 현재 호스트에서 증명할 수 없어 배포 승인으로 간주하지 않는다.

| 시나리오 | 상태 | 다음 확인 |
|---|---|---|
| Android/iOS profile 모드 탭 전환 프레임·jank | 미실행 | 저사양 Android 1대와 iOS 1대에서 cold launch→4탭 왕복 측정 |
| reduce-motion + 200% 글자 실제 핵심 흐름 | 미실행 | Android TalkBack, iOS VoiceOver에서 저장·닫기·탭 이동 수행 |
| 알림 권한·DST·timezone 변경·재부팅 후 도착 | 미실행 | 실제 기기에서 daily/streak/weekly 알림 도착 시각 확인 |
| 위젯 자정·재부팅·timezone 변경 | 미실행 | Android/iOS 런처에서 날짜·상태 snapshot 확인 |
| iOS Face ID/privacy 및 signed archive | 미실행/기존 차단 | Apple Team·certificate·profile·App Group을 CI에 주입한 signed archive 필요 |
| CocoaPods clean checkout | 미실행/환경 게이트 | `flutter pub get` 후 `cd ios && pod install --deployment` 실행 뒤 workspace build |

## 잔여 릴리스 게이트

- 사용성 P0 구현과 자동 회귀 검증: **통과**.
- 저장 완료의 접근성·중립 문구·빠른 닫기, 빈 상태 회복, 공통 모션 토큰: **통과**.
- 배터리 효율: 상시 polling·무한 animation을 추가하지 않았고, 실제 배터리 측정은 **미실행**.
- 운영 배포: 기존 iOS signed distribution 설정 부재와 CI CocoaPods/실기기 게이트가 남아 있으므로 이 보고서만으로 운영 배포 승인하지 않는다.
