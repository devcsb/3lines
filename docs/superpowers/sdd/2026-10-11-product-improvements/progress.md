# 3Lines 제품 개선 진행 기록

## 목표와 재개 기준

- 사용자 목표는 현재 앱의 기능, UI/UX, 카피를 독립적으로 심층 검토하고 현실적인 기획과 구현을 완료하는 것이다. 첫 데이터 보호 단계만을 전체 목표 완료로 간주하지 않는다.
- 구현자는 `gpt-6.1-sol medium`, 독립 컨텍스트 비판적 검토자는 `gpt-6.1-sol xhigh`를 사용한다.
- 구현 경로는 `/Users/ubermensch/.codex/worktrees/data-safety-import/3lines`, 브랜치는 `codex/data-safety-import-implementation`이다. 재개 시점 HEAD는 `82d2a4aacc358e5b401457a12afce87a03eb1709`이며 clean을 확인했다.
- 원본 `/Users/ubermensch/side-project/3lines`는 `codex/data-safety-import`, HEAD `4696df1`이며 clean이다. 이 원본에서 작업하지 않는다.
- 첨부된 기존 worktree를 사용한다. 실제 사용자 DB/사진/secret을 조사 자료로 쓰지 않는다. 배포/계정/외부 게시와 merge/push는 이 로컬 개선 수행에 포함하지 않는다.
- 첫 데이터 보호 구현과 전체 게이트 532개 통과는 2026-09-30 근거다. 현재 실행한 것은 소스 상태 확인과 Flutter 3.47.1/Dart 3.13.1 확인이며 현재 변경의 PASS로 과거 결과를 재사용하지 않는다.
- 이전 goal turn은 없으며 이번 초기 턴은 현재 소스와 독립 리뷰 반례를 확보한 progress다. goal은 active다.

## 현재 진행

| 책임 | 독립 리뷰어 | 상태 |
|---|---|---|
| 작성/초안/자정/앱 수명 | audit_writing_continuity | 조사 완료, 날짜 혼합 저장과 invalidate/늦은 응답/사진 초안 유실 반례를 R1에 반영 |
| 과거 기록/검색/통계/스트릭 | audit_history_insights | 조사 완료, 검색 응답 역전/기간 초기화/날짜 경계/최장 스트릭/PDF snapshot 반례를 R2~R3에 반영 |
| 제품/카피/접근성/첫 사용/아이콘 | audit_product_ux | 조사 완료, 예시/Undo/큰 글씨/대비/숨은 알림/과장 카피/기본 아이콘 문제를 R4~R6에 반영 |

설계와 7개 task 계획을 `28e5add`에 기록하고 독립적인 Task1/2/5를 medium 구현자에게 배정했다. 사용자에게 기획과 실제 구현 수행을 위임받았으므로 routine 설계 선택마다 승인을 다시 요청하지 않는다. 중요한 새 제품 방향이나 외부 작업 권한이 필요하면 그때 범위를 구분한다.

## 구현과 검증 인계

- Task5는 `b65ad82`에 명시 소유 6개 파일만 커밋했다. 서비스/플랫폼/coordinator 38개와 설정 widget 1개가 각각 exit0으로 통과했다. 독립 `review_single_reminder`가 launch migration에서 정상 일일 예약까지 먼저 제거하여 초기화 실패 때 pending0이 되는 P2를 찾았다. 실제 RED 후 `2a4ab82`에서 위험/weekly/legacy 정리와 비활성 전체 취소를 분리했다. 재검토는 이 지적을 닫고 비활성 migration 실패가 후속 일일 취소를 막는 새 P2를 보고했다. root가 호출 순서를 대조하고 `128f45b`에서 비활성 분기를 먼저 처리하도록 고쳤다. 실제 cancel300 실패 RED와 서비스/coordinator 41개 exit0을 확인했다. 최종 전체 독립 검토에서 이 경계를 다시 포함한다.
- Task1은 `1cc4b84`에 10개 소유 파일을 커밋했다. timeline target 61개 exit0 뒤 독립 `review_history_ux`가 DST 달력 날짜 누락 P2를 찾았다. 실제 LA84개 기대/77개 실제 RED 후 `a6ce590`에서 UTC 날짜 차이와 달력 셀 생성으로 고쳤다. LA/일반 환경 각각 heatmap10개 exit0이며 봄/가을84개 날짜집합과 중복0을 검사했다. 실제 한글/MaterialIcons 렌더 320×640/200% 두 장을 구현자/리뷰어/root가 열어 확인했다. 낮은 기존 기간 버튼 높이/흐린 공통 안내색은 Task6에 인계했다.
- Task2는 `0f76b51`에 13개 소유 파일을 커밋했다. repository/insights/PDF 최종 117개 exit0 뒤 독립 `review_insights_correctness` 검토 중이다. 중간 보고에서 build의 늦은 결과가 setPeriod를 되돌리는 반례와 기존 시험이 옛 build 완료 전에 assert하는 문제를 지적했다. 최종 보고와 수정은 아직 남아 있다. save/import/사진 API는 변경하지 않았고 EntryRepository 편집을 인계했다.
- Task3 `implement_durable_drafts` medium을 배정했다. 브리프 `.superpowers/sdd/2026-10-11-product-improvements/task-3-brief.md`에 모델/주입 DB/직렬 쓰기/epoch/원자 commit/사진 참조/충돌 복사 및 재열기 계약을 고정했다. Task3이 현재 Flutter 단독 슬롯을 사용한다.
- Task7 `implement_beta_entry` medium을 배정했다. 브리프 `.superpowers/sdd/2026-10-11-product-improvements/task-7-brief.md`에 벡터 세 줄 launcher, 서명 APK 추가, preflight 실패가 release에 전달되는 gate, 실제 배포와 로컬 소스 구분, 베타 관찰 계약을 담았다. 앱 기능 소스는 편집하지 않으며 Flutter 슬롯은 없다.
- Task4의 브리프도 작성했다. Task3 인계 후에 구현한다. Task6a `implement_readability_onboarding` medium은 theme/onboarding/info/security/data/daily_quote만 소유한다. 먼저 읽기/RED 시험을 작성하고 Task3 target 종료 후 공통 source를 편집한다. Task6b 하위화면은 Task4 이후 인계한다. 전체 R1~R6 완료 대조는 남아 있다. 일부 task 성공만으로 전체 목표 완료를 선언하지 않는다.
- 상세 RED/GREEN과 미검증은 `.superpowers/sdd/2026-10-11-product-improvements/task-{1,2,5}-report.md`에 있다.

## 후속 독립 검토와 현재 상태

- Task2 Important는 `73ab459`에서 실제 build 완료 barrier와 최신 generation 재조회로 수정했다. 실제 month3 기대/week1 실제 RED 후 controller5개 exit0이다.
- 독립 `review_insights_correctness`가 후속 `73ab459`, `a6ce590`, `2a4ab82`, `128f45b`를 source로 재검토하여 기존 지적 모두 닫힘/새 확정 반례 없음/인계 가능을 보고했다. 게이트는 재실행하지 않았다. Task1/2/5 기능은 전체 gate에 통합할 준비가 됐다.
- Task7은 `1a9da95`에 53개 source/생성 asset을 커밋했다. YAML preflight32조합/release 조건/build-verify-flatstage 외부command fake 시험, launcher크기/alpha/ICO/adaptive safe zone/대비5.2, 기존 iOS shell 시험이 PASS다. 실제 Android compile/서명/Actions/설치는 미검증이다. `review_beta_entry` xhigh 독립 리뷰 중이다. root도192px와원형preview를 열어 확인했다.
- Task3은 memoryDB/provider/기존Today/Settings111개, 넓은관련소비자392개, 충돌UI3개 PASS를 보고했다. 추가 날짜전환 조회오류를 발견하여 입력 유지/재시도 수정 후 마지막target 중이며 아직 source/검토 완료가 아니다. 사진조회는 같은queue+DBtransaction으로 묶고 같은DB의두Repository 경합을 시험했다. Task3만 현재 Flutter 슬롯을 갖는다.

## 실행 조율 판정

- 같은 worktree의 병렬 Flutter 명령에서 sqlite3 native asset 부재/codesign 오류가 관찰됐다. 이후 Flutter test/analyze/build는 root가 단독 슬롯을 배정하며 직렬 실행한다. 코드 작업은 파일 소유권을 나눠 병렬 유지한다.
- 다른 작업자가 source/constructor를 연결하는 중 두 widget compile 실패가 있었다. 존재하지 않는 helper import는 기존 `text_analysis.dart` 재사용으로 해소했고 Heatmap `endDate`도 연결 후 Task5 widget PASS를 확인했다. 이를 제품 assertion 실패와 구분한다.
- 하루 한 번 알림은 전체 pending 한 개가 아니라 30일 범위에서 날짜당 한 개다. 로컬 iOS plugin은 반복 time trigger에서 날짜를 제외하므로 오늘 기록 시 skip을 보장하는 기존 one-shot 범위를 유지한다. 앱 미접속 30일 이후와 실제 OS 알림 도착은 미검증/기존 제한으로 남긴다.

## 현재 외부 배포 상태

2026-10-11 root가 `gh release list`, `gh release view v1.2.3 --json ...`, `gh run list --workflow release.yml`을 읽기 전용 실행했다. 최신 공개 release는 [v1.2.3](https://github.com/devcsb/3lines/releases/tag/v1.2.3), publishedAt `2026-08-29T06:58:51Z`이다. 첨부는 `app-release.aab` 72,099,129 bytes 한 개이며 APK/IPA는 없다. [release run 33239369691](https://github.com/devcsb/3lines/actions/runs/33239369691)은 success이고 head `c2b8613b4024bb521ec26e09040218f7f8ceba2b`이다. 이 사실은 현재 로컬 개선 브랜치가 배포됐다는 뜻이 아니다. Task7에서 로컬 APK build/verify/upload 경로를 개선하되 외부 publish는 하지 않는다.

## 확인된 중간 근거

- TodayState에 초안 날짜/영속 저장이 없고 질문 변경, 변경 있는 import, 자정 갱신이 상태를 새로 만든다. 보통 탭 전환만으로 초안이 사라진다고 주장하지 않는다. indexedStack와 앱 수명 listener는 Today를 유지한다.
- 최장 스트릭 반례는 03-01,03-03,03-04,03-06,03-07이다. 현재 구현은 longest=3이지만 03-03부터 한 번의 유예를 포함하면 기록 4개 구간이 있다.
- 검색 clear 뒤 늦은 응답이 검색을 복원하고 journal 변경이 선택 기간/검색을 초기화하는 경로가 있다.
- index별 고정 입력 예시가 사용자 지정 질문에도 나타나며 예시 추가는 200자 경계를 우회한다. Undo는 이후 직접 입력까지 이전 값으로 덮을 수 있다.
- 제품 리뷰어의 코드 합성 대비 계산에서 light onSurface 50%는 3.28:1, 40%는 2.48:1이었다. launcher icon은 실제 이미지 확인에서 Flutter 기본 로고였다.

## 전체 목표 검증 원칙

소스 근거, 실제 사용자 시나리오, 필요한 행동 시험과 시각 검토를 연결한다. 실행자는 자기 task target만 실행하고 root가 변경 전체를 검증한다. 이미 실행한 동일 소스 게이트는 반복하지 않는다. 반례로 동작이 달라지면 이유를 기록하고 해당 검증을 다시 수행한다.

완료 시 기능/UX/카피 요구별 구현, 독립 검토 결과, 실제 실행 근거와 남은 한계를 대조한다. 실기기/화면 렌더링을 하지 않은 항목은 코드/위젯 검증과 구분한다. 컨텍스트 압축 후에는 이 기록과 최신 plan/report를 읽고 진행하며 완료한 데이터 보호 구현을 재시작하지 않는다.
