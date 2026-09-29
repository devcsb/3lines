# 제품 개선 재개 기록

## 현재 상태

- 기준 저장소 `/Users/ubermensch/side-project/3lines`
- 원본 계획 브랜치 `codex/data-safety-import`
- 구현 경로 `/Users/ubermensch/.codex/worktrees/data-safety-import/3lines`
- 구현 브랜치 `codex/data-safety-import-implementation`, 시작 `4696df1`
- 조사 기준 커밋 `a12d554ac9009823d44130e1ac88e4b36f3df709`
- 2026-09-30 사용자 승인: 감사 결과의 개선 순서와 작성된 첫 작업 명세.
- 2026-09-30 사용자 계획 승인과 실행 지시 완료.
- 단계: `subagent-driven-development` 실행 중. Task 1/4/5 구현과 독립 검토 승인. Task 2의 저장소/확인 UI 연결을 구현한다.
- 명세: `docs/superpowers/specs/2026-09-30-data-safety-import-design.md`
- 계획: `docs/superpowers/plans/2026-09-30-data-safety-import.md`
- Flutter 3.47.1 의존성/플러그인 등록 동기화를 `96962ff`에 commit했다. 현재 구현 head는 `17f7f80`이다. 릴리스와 계정 설정은 변경하지 않았다.

## 목적과 결정

타겟은 짧은 한국어 기록을 원하는 바쁜 20~30대다. 로컬 저장과 기록 보존을 유지하며,
현재 GitHub Release를 통한 Android 베타 경험을 개선한다. Google Play 등록과 iOS
배포는 이번 첫 작업에 포함하지 않는다.

첫 작업은 안전한 JSON 가져오기와 사진 삭제 경계다. 기존 기록 보존을 기본값으로
하고, 충돌 텍스트 교체는 미리 보여준 뒤 명시적으로 선택하도록 한다. 외부 JSON의
사진 경로는 신뢰하지 않는다. 사진 파일을 담지 않는 현 JSON 기능은 텍스트 기록
내보내기와 가져오기로 안내한다. 사진 포함 백업 형식은 후속 설계로 남긴다.

독립 명세 검토에서 두 경합 정책을 보완했다. 미리보기에서 제외한 입력은 자정이
지나도 적용 대상으로 승격하지 않는다. 시작 정리 중 생성한 사진은 picker 반환
뒤에도 정리 완료까지 보호한다. 이는 설계 결정이며 제품 구현과 실행 검증은 아직
하지 않았다.

## 승인된 우선순위

| 순서 | 작업 | 상태 |
|---|---|---|
| 1 | 가져오기 확인, 충돌 보존, 입력 검증, 사진 삭제 경계 | 명세/계획 승인, 구현 중 |
| 2 | 초안 보존, 자정 저장 경합, 과거 기록 조회와 검색 | 감사 완료, 구현 전 |
| 3 | 기간 경계, 유예일과 최장 스트릭, 화면 데이터 정합성 | 감사 완료, 구현 전 |
| 4 | 서명 APK 빌드와 GitHub Release 설치 안내 | 감사 완료, 구현 전 |
| 5 | 텍스트 가독성, 전용 아이콘, 최신 홍보 이미지 | 감사 완료, 구현 전 |
| 6 | 베타 성공 기준, KPI 정의와 검증 시나리오 | 감사 완료, 구현 전 |

시스템 백업과 프라이버시 문구의 일치도 해결해야 한다. 첫 작업에 플랫폼 백업
변경을 끼워 넣지 않고, 베타 배포 준비에서 별도 정책을 확정한다.

## 확인한 근거

- `lib/data/repositories/entry_repository.dart:538`의 가져오기는 날짜 형식 검증 없이
  같은 날짜를 upsert한다. `:557`은 손상된 질문을 빈 문자열로 바꾸며 `:578`은
  외부 `photo_path`를 그대로 저장한다.
- `lib/features/settings/widgets/data_section.dart:86`은 파일 선택 뒤 확인 없이
  `importData`를 호출한다. 기존 덮어쓰기 기대는
  `test/data/repositories/entry_repository_test.dart:492`에 있다.
- `lib/core/services/photo_service.dart:24`의 삭제는 받은 파일 경로에 디렉터리
  소유권 검사를 하지 않는다. 관련 호출자는 Today, Timeline과 Settings다.
- `lib/data/models/daily_entry.dart:83`의 JSON은 사진 바이트 없이 절대 경로만
  포함한다.
- `lib/features/insights/insights_controller.dart:27`의 기간은 양 끝을 포함하므로
  7/30/90일 표시에 8/31/91일이 들어간다.
- `lib/data/repositories/entry_repository.dart:282`는 이력 끝에서도 유예 플래그를
  소비하고, `test/data/repositories/entry_repository_test.dart:163`이 이를 기대한다.
- `lib/features/timeline/timeline_screen.dart:65`는 최근 기간 공백을 전체 신규로
  취급해 검색과 기간 선택을 숨긴다.
- 실제 `v1.2.3` GitHub Release는 `app-release.aab` 하나만 포함한다. 2026-09-30
  `gh release view`로 재확인했다. README는 APK 직접 설치를 안내한다.

## 검증 원장

아래는 2026-09-30 감사 단계에서 이미 실행한 결과이며 이 문서 작성을 위해
재실행하지 않았다. 과거 보고서의 통과 결과를 현재 통과로 사용하지 않는다.

| 검사 | 실제 결과 |
|---|---|
| `flutter analyze --no-pub` | 실패, `flutter_timezone` 관련 오류 2개 |
| `flutter test --no-pub --reporter expanded` | 실패, 346개 통과와 11개 로딩 실패 |
| 의존성 구성 조사 | pubspec과 lock에는 `flutter_timezone`이 있지만 로컬 package configuration에는 없음 |
| GitHub Release 조회 | v1.2.3, 서명 AAB 1개, APK와 IPA 없음 |
| 실기기 설치, 백업 복원, 접근성, 30초 사용성 | 미검증 |

실제 사용자 데이터나 DB 파일을 지우는 재현은 하지 않았다. 감사의 삭제 위험은
소스 호출 경로를 확인한 결과다. 날짜 문자열 범위와 스트릭 반례의 작은 SQLite/JS
재현은 실제 앱 실행과 구분한다.

## 이어서 할 일

1. 승인된 계획의 Task 1과 Task 4를 각각 Luna high와 6.1-sol high 실행자가 구현한다.
2. 작업별 target RED/GREEN 뒤 root가 소유 파일을 직렬 commit하고 fresh-context 검토자에게 범위 diff를 전달한다.
3. 이어서 여섯 작업을 구현한다. 모델/검증과 사진 경계는 병렬 가능하며 겹치는 저장소, 컨트롤러와 시험 편집은 직렬화한다.
   작성 파일 소유권을 나누고 다른 작업자의 편집을 되돌리지 않는다.
4. 로컬 의존성 복구는 완료했다. 작업별 회귀 시험과 최종 전체 검증을 실행한다. 실기기 검증이 없으면 이를 완료로 표시하지 않는다.

실행 판정은 공통 사진 삭제 helper를 PhotoService에 두어 세 controller의 복제를
피하고, 시작 정리 시험의 전용 hook 대신 실제 파일 copy I/O 주입을 사용한다.
전체 게이트는 마지막 root 실행으로 대조한다. 세부 판정, 오판 비용과 task별
dispatch/review commit은 구현 경로의 `.superpowers/sdd/2026-09-30-data-safety-import/progress.md`에 남긴다.

## 현재 구현 검증

| 작업 | 실제 target 결과 | 독립 검토 | 커밋 |
|---|---|---|---|
| 1 입력 모델 | API/정책/alias/clock RED 뒤 최종 +7, exit 0 | 공개 constructor deep freeze와 fixture URI 누락 수정 후 Approved | 3f42dc2, d7dd13b, 17f7f80 |
| 4 사진 소유 경계 | 외부 파일 삭제 행동 RED 뒤 +28, exit 0 | spec/quality Approved | 3c46736 |
| 5 시작 정리 경합 | 실제 파일/DB RED +33/-5 뒤 +38, exit 0 | spec/quality Approved | 8a431df |
| 2 가져오기 수직 흐름 | 구현 중 | 대기 | 미완료 |
| 3 텍스트 내보내기 | 2 뒤 시작 | 대기 | 미완료 |
| 6 호출자 참조 보호 | 2/3 뒤 시작 | 대기 | 미완료 |

위 결과는 실행자의 target 출력과 독립 source review를 대조한 기록이다. 전체
analyze/test, 플랫폼 빌드와 실기기 검증은 아직 실행하지 않았다.

## 실행 판정과 오판 비용

1. 겹치지 않는 편집은 사용자 지시대로 병렬 수행하고 Git은 root가 직렬 처리한다.
   dispatch base와 review base를 분리한다. 오판 시 소유권/Git 범위 재대조가 필요하다.
2. CI와 같은 Flutter 3.47.1의 7개 SDK 의존성 pin과 generated timezone 등록을 유지한다.
   새 패키지는 없다. 오판 시 플랫폼 빌드 회귀 비용이 든다.
3. 전체 게이트는 root 최종 실행으로 대조하고 작업별 RED/GREEN만 중간에 수행한다.
   오판 시 기존 오류를 뒤늦게 발견할 수 있어 최종 실패를 그대로 보고한다.
4. API 부재 컴파일 RED와 실제 정책 assertion RED를 구분한다. 조금 더 많은 RED
   단계가 들지만 컴파일 실패를 동작 검증으로 사용하지 않는다.
5. Task 6의 동일 삭제 helper 세 복제 대신 PhotoService의 좁은 공통 실제 동작을
   사용한다. 오판 시 계층 경계 재정리 비용이 든다.
6. 시작 정리의 순수 테스트 hook 두 개 대신 실제 copy I/O 주입과 DB loader gate를
   쓴다. 오판 시 경합 시험 seam 재조정이 필요하다.
7. 수동 provider identity assertion을 실제 bootstrap 증거로 세지 않는다. 실제
   helper FS 시험과 production override wiring을 검토한다. 실기기 연결 문제는
   놓칠 수 있으므로 실기기 미검증을 유지한다.

계획 대조에서 일반 saveEntry가 createdAt을 바꾸지 않는다는 점을 반영해 timestamp
변경 반례는 실제 DB column update로 고정했다. 완료된 Today 표시와 작성/수정
초안을 구분해 마지막 사진 참조 삭제를 방해하지 않도록 했고, UI 중복 선택,
원문 없는 오류, dispose 뒤 무쓰기, 실제 파일 복사와 정리 수명의 시험을 명시했다.
기존 image_picker 1.2.2의 public ImagePicker를 상속해 시험할 수 있어 새 의존성은
계획하지 않았다. 제품 코드와 계획의 테스트 예시는 아직 실행하지 않았다.

## 컨텍스트 관리

작업 단위가 끝나거나 긴 검토 결과를 받으면 이 기록을 갱신한다. 자동 컨텍스트
압축 뒤에는 현재 단계, 승인 범위, 브랜치, 소유 파일과 검증 원장을 읽고 이어간다.
이미 완료한 감사나 동일 조건의 검증을 설명 없이 반복하지 않는다. 변경과 새
실패가 있을 때만 해당 검증을 다시 실행한다. 현재 도구에는 세션 컨텍스트 사용률
조회나 강제 압축 호출이 없으므로 50% 임계값을 직접 설정했다고 보고하지 않는다.
