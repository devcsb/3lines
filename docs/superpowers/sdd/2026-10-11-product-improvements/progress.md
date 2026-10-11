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

### 최신 재개 지점

- 최신 확정 구현은 `d4208ee`이고 진행 기록 HEAD는 `1efc718`이다. 아래 단계별 기록은 시간순 이력이며 가장 아래의 후속 판정을 우선한다. Task3 독립 검토는 종료됐고 Task4b/Task6 최종 UI 작업과 전체 검증이 남았다.
- Task1/2/5는 후속 독립 검토에서 기존 지적이 모두 닫혔다. 전체 gate와 실제 OS 동작은 별도다.
- Task3 초기 구현은 `fc19521`이며 관련394개 PASS 뒤 독립 검토에서 Important5/Minor1을 발견했다. 날짜 조회 중 입력 덮어쓰기, 손상 초안의 사용자 복구 경로 부재, 취소 중 재시도로 초안 재등장, 미구독 Today의 전체삭제 수명, nullable key 누락 수용, 회고 metadata 유실을 고치는 중이다. `.superpowers/sdd/2026-10-11-product-improvements/task-3-review-fixes.md`에 판정을 기록했다. 기존394개 PASS를 수정 후 결과로 재사용하지 않는다.
- Task6a는 `89db6c0`에 커밋했다. target27개, Data 보관 안내1개 PASS 및 target analyze0issues다. 독립 xhigh 검토는 Critical/Important/Minor 모두0으로 인계 가능을 보고했고 실제 한글 렌더18장을 확인했다. DataSection의 기존 사진삭제 시험에서 드러난 Today 수명 결함은 Task3 소유로 인계했다. Task6b 하위 화면 대비/48dp/렌더는 아직 남았다.
- Task7의 독립 검토는 JSON 평문/OS 백업/앱 잠금 범위 문서 누락을 지적했고 `e5043ef`로 고쳤다. Task6a 독립 검토자가 이 문서 지적도 닫았다. 실제 Android 컴파일, 서명 배포, 설치는 아직 미검증이다.
- Task4는 미실행 RED 시험만 준비했다. Task4a QuestionsSection/LockScreen을 먼저 진행하고 Task4b Today/Prompt/Photo/SettingsController는 Task3 재검토 종료까지 보류한다. Task4의 새 RED 파일 때문에 Task3 시험에서 Today 디렉터리 전체를 무심코 실행하지 않는다.
- 현재 Flutter 단독 실행 슬롯은 Task3 구현자가 소유한다. 종료 확인 후 다른 task에 인계한다. 전체 analyze/test, Android gate/build, R1~R6 최종 대조는 아직 실행하지 않았다.

후속 진행은 다음과 같다.

- Task3의 6건 보완을 `af58a9a` 11파일에 커밋했다. 새 반례45개와 최종 관련 소비자344개 PASS(exit0), format0changed다. DataSection 기존 삭제 시험은 Today 강제 listener 없이 실제 사진 참조 gate/DB0/unknown 사진 보존/event/안내 assertion을 유지했다. 원래 xhigh 검토자에게 재검토를 넘겼으며 Task4b 소유권은 아직 보류했다.
- Task4a는 `9b7c4c9`다. 질문 저장 await/inline 오류/입력 유지/기기 인증 재시도 및 작은 화면 스크롤을 구현했다. 실제 RED6FAIL 후 새 질문4+새Lock2+기존Lock8=14PASS다. 독립 검토는 신규 Critical0/Important0, 시험Minor1이다. 영구 listener와30ms wait가 수명/완료 검증을 가리는 시험을 보강 중이다. 기존 resetPrompts 순차 write의 부분 실패/화면 불일치는 Important로 확인했으며 Task4b에서 기존 repository transaction으로 원자화한다.
- Task6b는 Timeline/Insights부터 진행한다. 실제 한글 렌더와 대비/48dp target25개에서 RED22FAIL/3PASS를 관찰했다. StatCard의 일반크기 한글 잘림, 200% 고정 grid 넘침, Timeline 3.277:1 및 detail dark2.850:1의 낮은 대비, PDF native button 부재를 고치는 중이다. Today/Prompt/Emotion은 Task4b 이후 인계한다.
- Flutter 슬롯은 Task3 consumer 종료 후 Task4a 질문 시험에 양도했다. 이후 Task6b GREEN을 실행한다. 전체 gate/Android build/전체 요구 대조는 여전히 남았다.

### af58a9a 재검토 후 진행

- 원래 Task3 검토자가 이전 지적의 직접 수정은 확인했지만 새 Important2건을 보고했다. 저장/취소 중 날짜전환을 허용한 뒤 원래 작업 완료→날짜조회 실패가 오면 busy 상태가 남는다. 저장/취소 중 날짜전환 자체를 UI/controller에서 거부하는 정책으로 정리한다. 손상 row2개 중 하나를 폐기한 뒤 build가 session을 바꾸고 두 번째 손상에서 실패하면 reset이 AsyncError를 버려 loading이 남는다. reset 완료 조건을 해당 요청/epoch 기준으로 고친다. Task3 구현자가 Today controller/screen와 durable 시험만 소유하여 보완한다.
- Task4a 보강 질문 시험은 외부 영구 listener와30ms완료추정을 제거한 뒤5PASS/원자초기화1RED다. 사용자지정3질문에서 두 번째 write 실패가 첫 질문만 DB에서 바꾸는 것을 확인했다. Task4 구현자에게 SettingsController의 prompt 부분, SettingsRepository, QuestionsSection을 먼저 인계했다. Task3 삭제/import 로직을 건드리지 않고 transaction/실패카피를 구현한다. Today/Prompt/Photo는 여전히 인계 전이다.
- Task6b 첫 GREEN은22PASS/3FAIL이다. 세로 SegmentedButton 무한 높이와 Insights200% 레이아웃 실패를 보완 중이며 Flutter 단독 슬롯을 소유한다. 이 중간 결과를 최종 통과로 간주하지 않는다.

### b294d6f 이후 인계 대기

- Task3의 추가2건은 `b294d6f`에 커밋했다. 실제 RED5건 후 Today 명시5파일102PASS/exit0,4파일format0changed다. busy 중 날짜전환 거부와 reset 요청/epoch 검사에 더해 build의 session/date를 await 전에 고정한다. 원래 검토자가 재검토 중이다. Task4b Today 인계는 이 결과를 기다린다.
- 질문 reset은 `63efff5`에서 원자화했다. 실제SQLite rollback/재시도/기존초안과기타설정보존을 포함해64PASS이며 독립 검토가 이전 Important/Minor를 모두 닫고 새 지적0으로 인계 가능을 보고했다.
- Task6b Timeline/Insights는35PASS 뒤 실제 렌더에서 단일 감정 숫자64px/원48px 잘림과 툴팁 대비3.0176:1을 추가 RED로 확인했다. 이를 보완하고 최종40개/회귀/렌더/analyze를 수행 중이며 Flutter 슬롯을 소유한다. LockScreen은 수정하지 않았고 여기의 잠금 표시 개선은 InsightsLockedView다.
- Task4b의 작성도움5+실Today복구/키보드6+사진회복4=15시험을 준비했다. 아직 실행/컴파일하지 않았고 운영 Today/Prompt/Photo 코드는 편집하지 않았다. 사진은 실 PhotoService/임시File/memoryDB로 취소/권한/복사실패/재시도/late결과 보호를 검사하도록 준비했다.

### b9d7ca9 이후 진행

- Timeline/Insights 표시계층18파일은 `b9d7ca9`다. readability40PASS, 기존UI56PASS, 감정점재캡처5PASS, 상세16조합2PASS, target18items analyze0issues/format0changed를 확인하고 독립 검토 중이다. 실제한글PNG에서 chart/월간/주간/PDF/잠금통계/상세/감정점/기간선택을 확인했다. root도 Ocean dark100% 렌더를 열었다.
- Task3 `b294d6f`의 기존2건은 닫혔지만 최초 Riverpod managed build pending 중 수동 reset이 앞서끝나고 새입력뒤 최초build가옛session을덮는 새Important1건이 나왔다. actualRED에서 답변이빈문자열로돌아감을확인했다. 첫managed future settle 이후 최신request/epoch의 reset만 별도load로실행하는직렬안을 구현 중이다. build는watch를, load는캡처의존성읽기를맡는다. 매reset마다현재future를await하여nestedreset을deadlock시키지않는다. framework재빌드/수동오류retry후캐시경계도확인한다. Task4b Today 인계는 계속보류다.
- 병렬 진행을 위해 Task6b의 Today 보조위젯 emotion_picker/one_year_ago/streak_pulse/milestone/completion_animation/animated_save_button와 해당시험만 기존구현자에게 인계했다. TodayScreen/controller/Prompt/Photo는편집하지않고 실제RED부터관찰한다.
- root가 `bash test/tool/release/android_release_gate_test.sh`를 실제실행했다. Gradle은 `allowUnsignedRelease=true is forbidden when CI=true`로실패했고 이를기대한shellgate는exit0으로통과했다(Gradle42s). 실제서명자료를읽거나배포하지않았다. 가능한로컬Android컴파일은여전히남았다.
- 현재 Flutter슬롯은 Androidgate종료후 Task3초기build GREEN에양도했다. 다음은Today보조위젯RED이며 전체Flutter gate는아직없다.

### d4208ee 초안 인계와 남은 작성/시각 작업

- Task3 managed build 보완은 `d4208ee`다. 최초 build 덮임, invalidate 후 같은 notifier의 완료barrier 재사용, retained-loading 입력으로 관리future조기완료 및 이전UI노출을 각각 actualRED로 확인했다. framework build마다 barrier/request를 갱신하고, reset은 첫관리future가성공/오류로settle된뒤 별도load를 실행한다. loading의이전값은활성입력으로취급하지않고 mutation/latewrite를거부하며 UI skipLoadingOnRefresh/Reload=false다. Today명시5파일107PASS/format0changed. 원래 독립검토자가 기존지적닫힘/새인계차단반례없음/Task4b소스인계가능을 보고했다.
- Task4b 실제15개에서 제품RED8개를 확인했다. 장문230→220편집이200으로잘림, 자유질문라벨/native예시/빈값Undo/199ZWJ경계, 권한/복사실패안내가 빠졌다. 유효PASS4개다. 직접편집/날짜Undo2건은SnackBar hit miss, latepicker1건은fixturetimeout으로분리하고보완했지만재실행전이다. Task4b 운영Today/Prompt/Photo 소유권을이제인계했다. 이미관찰한RED부터구현하며3개보완fixture는다음슬롯에서먼저확인한다.
- Task6b Timeline/Insights 독립검토는새Important1개, 연속7일200% 날짜축라벨겹침/끝점잘림을보고했다. 2일fixture가놓친경계이며 실제7/14/30일×2화면 RED6개를관찰했다. LayoutBuilder/TextPainter로라벨간격을정하고원본데이터점을유지하는후속수정중이다.
- Task6b Today보조위젯66개는12PASS/54FAIL 실제RED였다. 선택감정white아이콘2.568:1, 정보대비/스트릭Row넘침/native확인부재/가로완료문구겹침을보완중이다. Task6는보조6위젯과차트만, Task4는TodayScreen/Prompt/Photo와최소controller입력API만소유한다. Flutter단독슬롯은현재Task6가사용한다.

### 작성 복구와 보조 UI 최종 검증 중

- Task4b는 `da9e879`에 명시12파일을 커밋했다. fixture3개 보완 후 직접 편집/날짜 이동 Undo의 실제 덮어쓰기 RED2개와 기존 latepicker PASS를 구분했다. 최초 제품RED8개와 함께 수정한 뒤 Today/PhotoService/photo_cleanup 관련269개와 신규15개가 PASS다. format12개0changed, scoped analyze는 error/warning0이나 기존 TodayController/Screen info16개로 exit1이다. 최종 전체 검사 전 이를 정리해야 하며 독립 source review 중이다.
- Task6 날짜축은 연속7/14/30일×2화면 신규6개 PASS다. TextPainter로 라벨 폭을 측정해 간격을 정하며 실제 점7/14/30개와 첫/끝 날짜를 보존한다. Today 보조66개 최종 PASS이며 완료 화면의10개 중간실패는 fixture 종료 타이머 처리였고 운영 자동닫기2.5초는 유지했다. 소유10파일 format0changed다. 기존 회귀/target analyze는 다음 Flutter 슬롯에서 실행한다.
- root는 `/tmp/3lines-emotion-320x640-200pct.png`, `/tmp/3lines-insights-dates-14-320x640-200pct.png`를 열어 감정3+2 wrap/선택 체크와 겹치지 않는 날짜축을 확인했다. 독립 검토자에게 안정된 Task6 소유10파일만 인계했다. TodayScreen/Prompt/Photo/전체 Settings 최종 R6 및 root 전체 analyze/test/Android 컴파일은 여전히 남았다.
- 원본 checkout은 `codex/data-safety-import`에서 clean임을 다시 확인했다. 외부 배포, secret 값 조회 또는 사용자 자료 접근은 하지 않았다.
- root 최종 release 보조 검사로 `ruby test/tool/release/launcher_assets_test.rb`, `ruby test/tool/release/android_beta_pipeline_test.rb`, `bash test/tool/release/ios_release_config_test.sh`를 실행해 모두 exit0을 확인했다. launcher 크기/불투명 Apple PNG/ICO/safe zone/대비5.2와 APK·AAB build/verify/flat staging, Apple32설정/release조건 및 iOS누락secret gate가 통과했다. pipeline 시험의 외부 도구는 fake이며 실제서명/배포의 증거가 아니다.

### 5c72a98 이후 최종 UI와 통합 검증

- Task6 보조/날짜10파일은 `7159faa`에 커밋했다. 독립 검토가 기존 날짜 Important를 닫고 신규 Critical/Important/Minor 모두0을 보고했다. 신규66개와 날짜6개, 최종 Insights/기존보조 회귀63개 PASS, target10개 analyze0issues다. root가 회귀/분석 로그를 대조했다.
- Task4b 독립검토의 추가 Important는 최초 짧은답변의200상한을 캐시한 뒤 같은session에서 장문 import/refresh를 하면220자수정이200자로잘리는 경로다. Minor는 사진실패→예시Undo안내→새picker취소가 무관한Undo안내를닫는 경로다. 두 실제RED 후 `5c72a98`에서 session+immutable baseline으로 상한을 갱신하고 취소가SnackBar를건드리지않도록수정했다. 신규17PASS, scoped12파일analyze0issues/format0changed다. 기존lint16개도 의미변경없는braces/underscore정리로해소했다. 독립재검토는두지적닫힘/새접점반례없음을보고했다.
- Task4의 넓은 Today/PhotoService/photo_cleanup/SettingsController 실행은320PASS/10FAIL이다. 준비된 Task6 writing_readability의낮은대비 RED가포함됐으므로 전체PASS로쓰지않고 제외재실행도하지않았다. 최종root전체gate는R6수정뒤실행한다.
- 잔여R6는 writing11/Today복구7/전체Settings2개의 신규20개다. writing의최초결과는1PASS/10FAIL이며 category3.77:1/counter2.35:1/사진오류3.217:1와사진추가native버튼부재였다. 사진추가200% overflow를관찰한것은아니다. PhotoAttachment는native버튼과Wrap/정보색으로보완중이다. Task4검토종료후 Prompt/TodayScreen표시계층도Task6에인계했다. controller/서비스/Undo/사진결과/managedloading/저장조건은더이상수정하지않는다.
- 현재 Flutter단독슬롯은Task6다. 잔여20개실제RED→GREEN/관련회귀/analyze/render 및독립검토뒤 root전체analyze/test/Android컴파일, R1~R6최종대조가남았다. 외부배포와실기기검증은수행하지않았다.

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

같은 날짜 `gh secret list --json name,updatedAt`에서 repository secret 이름 네 개 `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`를 확인했다(등록 시각2026-08-29). 값은 읽지 않았다. 이 repository 목록에는 Apple/ASC 이름이 없었다. 조직/environment secret 전체 또는 Apple 계정 등록 여부를 확인한 것은 아니다.

## 확인된 중간 근거

- TodayState에 초안 날짜/영속 저장이 없고 질문 변경, 변경 있는 import, 자정 갱신이 상태를 새로 만든다. 보통 탭 전환만으로 초안이 사라진다고 주장하지 않는다. indexedStack와 앱 수명 listener는 Today를 유지한다.
- 최장 스트릭 반례는 03-01,03-03,03-04,03-06,03-07이다. 현재 구현은 longest=3이지만 03-03부터 한 번의 유예를 포함하면 기록 4개 구간이 있다.
- 검색 clear 뒤 늦은 응답이 검색을 복원하고 journal 변경이 선택 기간/검색을 초기화하는 경로가 있다.
- index별 고정 입력 예시가 사용자 지정 질문에도 나타나며 예시 추가는 200자 경계를 우회한다. Undo는 이후 직접 입력까지 이전 값으로 덮을 수 있다.
- 제품 리뷰어의 코드 합성 대비 계산에서 light onSurface 50%는 3.28:1, 40%는 2.48:1이었다. launcher icon은 실제 이미지 확인에서 Flutter 기본 로고였다.

## 전체 목표 검증 원칙

소스 근거, 실제 사용자 시나리오, 필요한 행동 시험과 시각 검토를 연결한다. 실행자는 자기 task target만 실행하고 root가 변경 전체를 검증한다. 이미 실행한 동일 소스 게이트는 반복하지 않는다. 반례로 동작이 달라지면 이유를 기록하고 해당 검증을 다시 수행한다.

완료 시 기능/UX/카피 요구별 구현, 독립 검토 결과, 실제 실행 근거와 남은 한계를 대조한다. 실기기/화면 렌더링을 하지 않은 항목은 코드/위젯 검증과 구분한다. 컨텍스트 압축 후에는 이 기록과 최신 plan/report를 읽고 진행하며 완료한 데이터 보호 구현을 재시작하지 않는다.
