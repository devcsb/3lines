# 3Lines 기록 보존과 안전한 JSON 가져오기 설계

## 상태

2026-09-30 사용자가 이 명세와 구현 계획을 승인하고 실행을 지시했습니다. 승인된 실행 방식은 task별 subagent 구현과 독립 검토입니다. 격리 브랜치 `codex/data-safety-import-implementation`에서 구현하며 실행 상태는 `docs/superpowers/sdd/2026-09-30-data-safety-import/progress.md`에 기록합니다.

## 목적

지친 20~30대가 한국어로 짧게 쓰는 로컬 저널의 기록을 잃지 않도록 합니다. 오프라인 사용을 유지하고, 기록 내보내기·가져오기에서 확인과 복구를 쉽게 하며, 안전을 위한 절차가 글쓰기 흐름에 불필요한 마찰을 더하지 않게 합니다.

첫 작업은 안전한 JSON 가져오기, 충돌을 확인 없이 덮어쓰지 않는 정책, 외부 `photo_path`가 앱 파일을 지우지 못하게 하는 경계, 그리고 사진이 포함되지 않는 백업의 설명을 바로잡는 일입니다.

## 구조 분류와 결정

기존 DB 스키마, `EntryRepository.saveEntry`의 일반 작성 계약, 현재 JSON 필드는 유지합니다. JSON 기능을 “텍스트 기록 내보내기/가져오기”로 명확히 부릅니다. 새 내보내기에서는 `photo_path`를 `null`로 내보내고, 가져오기에서는 입력의 `photo_path`를 항상 무시합니다. 사진 바이트는 내보내지 않습니다. 가져온 새 기록은 사진 없이 저장하며, 기존 기록을 명시적으로 텍스트 교체해도 현재 로컬 사진을 보존합니다.

가져오기를 순수 검증·미리보기와 사용자가 확인한 트랜잭션 적용으로 나눕니다. 기본 정책은 기존 기록 보존입니다. 충돌 기록의 텍스트 교체를 사용자가 명시적으로 선택해도 사진 메타데이터는 대상 로컬 기록에서 유지합니다. 저장 계약 변경이나 범용 import 프레임워크 없이 구체적인 `ImportPreview`, `ImportResult`, `ConflictPolicy` 모델과 기존 저장소의 좁은 메서드로 구현합니다.

## 현재 근거

| 코드 위치 | 현재 동작 | 설계상 의미 |
| --- | --- | --- |
| `lib/data/repositories/entry_repository.dart:79-101` | `saveEntry`는 날짜 충돌 시 텍스트와 `photoPath`를 upsert합니다. | 일반 작성 계약은 유지하고 import만 사전 충돌정책을 적용해야 합니다. |
| `lib/data/repositories/entry_repository.dart:538-601` | 날짜 형식·실재일·미래 여부와 감정 범위를 엄격히 확인하지 않고, prompts 손상을 빈 문자열로 채우며 입력 `photo_path`를 저장합니다. | 새 import parser가 손상 데이터를 명시적으로 분류하고 경로를 배제해야 합니다. |
| `lib/data/models/daily_entry.dart:83-95` | `toJson()`은 `photo_path`를 포함합니다. | export 경계에서 사진 경로를 `null`로 정규화해야 합니다. |
| `lib/features/settings/settings_controller.dart:187-214` | `importData`가 JSON을 풀어 곧바로 저장소에 전달합니다. | 검증/미리보기와 적용 진입점을 분리합니다. |
| `lib/features/settings/widgets/data_section.dart:86-104` | 파일 선택 후 확인 없이 바로 적용합니다. | 파일 선택 후 미리보기 확인 단계를 둡니다. |
| `lib/core/services/photo_service.dart:24-33,41-66` | 삭제는 전달 경로를 그대로 사용하고, 정리는 photos 디렉터리 항목을 경로 기준으로 제거합니다. | 삭제와 정리 모두 같은 소유 경로 검증을 거쳐야 합니다. |
| `lib/app/bootstrap.dart:36,110-113` | 시작 시 DB 경로를 읽고 별도 `PhotoService`로 비동기 고아 사진 정리를 시작합니다. | 시작 정리와 사진 선택·저장 사이 race를 다뤄야 합니다. |
| `lib/features/today/today_controller.dart:173,253,315,328`, `lib/features/timeline/timeline_controller.dart:74`, `lib/features/settings/settings_controller.dart:225` | 여러 기능이 사진 삭제를 호출합니다. | 호출자는 손상된 레거시 DB 경로를 포함할 수 있으므로 최종 안전성은 서비스가 보장합니다. |

기존 호환 기준은 `test/data/repositories/entry_repository_test.dart:443-647`, `test/features/settings/settings_controller_test.dart:180-394`, `test/helpers/fake_photo_service.dart`, `lib/app/bootstrap.dart`입니다. 저장소 테스트에는 충돌 덮어쓰기, 감정값 보정, 손상 prompts 허용 동작이 있으므로 안전한 import 계약으로 의도적으로 갱신해야 합니다. 일반 `saveEntry`의 upsert 테스트는 계속 유지합니다.

## 범위와 비범위

포함합니다.

- JSON 텍스트 기록 미리보기, 취소, 명시적 적용과 실제 결과 요약
- 충돌, 입력 형식, 중복, 앱 시계 기준 날짜를 검증하는 가져오기
- 앱 소유 사진 파일만 지우는 사진 서비스 경계와 시작 정리의 최소 race 보호
- 사진은 백업에 포함되지 않는다는 내보내기 안내
- 저장소, 컨트롤러, UI, 실제 임시 파일시스템 경계의 단위·위젯 테스트

포함하지 않습니다.

- DB 스키마 변경, 사진 바이트를 넣는 ZIP/백업, 클라우드 동기화, 텔레메트리
- 입력에 없는 정보를 추측해 복구하거나, 기존 손상 DB 기록을 삭제·수정하는 일
- 원본 기록 자동 삭제, 일반 기록 저장 계약 변경, 임의 장문 답변의 자르기
- 추상화 프레임워크, 범용 파일시스템 레이어, 광범위한 사진 서비스 재작성

## JSON과 검증 정책

허용 입력은 기존 envelope인 `{ "app": "3Lines", "version": "문자열", "entries": [...] }`와 legacy bare list입니다. `app` 필드가 없는 envelope는 현재 호환성을 위해 허용하되, 필드가 있는데 값이 `3Lines`가 아니거나 타입이 잘못되면 파일 전체를 형식 오류로 거부합니다. envelope의 `entries`는 목록이어야 합니다. JSON 파싱·envelope 오류는 미리보기 전 오류로 표시하며 DB 쓰기는 0건입니다. 목록 안의 non-map 항목은 `invalid` 한 건으로 셉니다.

`version`은 가져오기 호환성·신뢰 판정에 쓰지 않는 메타데이터입니다. 생략은 허용하고, 있으면 문자열이어야 합니다.

각 map 기록은 다음 규칙을 모두 만족해야 유효합니다.

- 날짜는 정확히 `yyyy-MM-dd` 형식이고 실제 달력 날짜이며, `AppClock`의 로컬 오늘보다 미래가 아닙니다. 각 미리보기/적용 단계는 주입된 같은 `AppClock`으로 기준 시각을 읽습니다.
- 감정은 정수 1~5입니다. JSON 숫자 `5.0`처럼 유한하고 수학적으로 정수인 값은 허용하고, 소수부가 있거나 범위 밖인 값은 보정하지 않고 `invalid`로 셉니다.
- `prompts`는 길이가 정확히 3인 목록이고 각 원소는 map이며 `question`, `answer` 값은 모두 문자열이어야 합니다. trim한 답변 중 하나 이상은 비어 있지 않아야 합니다. 손상 prompt를 빈 문자열로 대체하지 않습니다.
- `created_at`, `updated_at`은 생략하거나 `null`일 수 있습니다. 그 외에는 문자열이어야 하고 `DateTime.tryParse` 가능한 값만 허용하며, 정상 값은 보존합니다. 생략 또는 `null`은 시각 미지정으로 취급합니다.
- `photo_path`는 형식 검사나 저장에 사용하지 않습니다. 어떠한 입력 경로도 앱 파일 삭제·참조의 근거가 될 수 없습니다.

새 기록은 유효한 `created_at`과 `updated_at`을 각각 보존하고, 미지정 시각은 적용 단계의 `AppClock.now()`로 채웁니다. 충돌 텍스트 교체는 대상 행의 `createdAt`과 로컬 `photoPath`를 보존합니다. 유효한 입력 `updated_at`이 있으면 이를 적용하고, 없으면 적용 단계 `AppClock.now()`를 씁니다. 입력 `created_at`은 교체 시 사용하지 않습니다. 파싱 가능한 timestamp를 실제 일기 날짜나 입력의 신뢰성 증거로 사용하지 않습니다.

유효한 날짜가 같은 여러 입력은 원래 목록 순서로 처리합니다. 같은 날짜의 첫 번째 유효 항목만 후보로 남기고 뒤의 유효 항목은 각각 `duplicate`로 셉니다. 먼저 나온 무효 항목은 날짜를 선점하지 않습니다. 미리보기 순서와 결과의 duplicate 수는 원본 입력 순서를 따릅니다.

## 미리보기와 원자적 적용

1. 파일을 선택하고 UTF-8 JSON을 파싱합니다. 앱 경로, 파일 경로, 원문 답변은 알림이나 오류 메시지에 노출하지 않습니다.
2. 원본 입력과 유효 후보를 변경 불가능한 미리보기 스냅샷으로 고정합니다. DB를 읽기만 하며 `신규`, `충돌`, `유효하지 않음`, `중복` 건수와 충돌 날짜 목록을 표시합니다. 유효한 새 기록은 기본으로 추가 대상이 됩니다. 충돌은 기본 보존이며, 충돌 텍스트 전체 교체는 선택사항으로 명확한 확인 문구와 함께 제공합니다. 사진은 이 파일에 포함되지 않는다는 안내를 보여줍니다.
3. 취소하면 DB 쓰기는 0건입니다. 확인 버튼은 중복 탭을 막고 적용 진입을 한 번만 허용합니다. 화면에는 큰 글씨에서 읽고 조작할 수 있는 스크롤 가능한 요약과 접근성 의미를 제공합니다.
4. 적용 후보는 미리보기에서 유효하고 중복이 아니었던 입력으로 고정합니다. 이 후보만 단일 DB 트랜잭션 안에서 현재 DB 상태를 다시 평가합니다. 기본 정책은 현재 충돌도 보존합니다. 교체 허가는 사용자가 미리보기에서 본 충돌 날짜 집합에만 적용합니다. 미리보기 뒤 새로 생긴 충돌 날짜는 교체 선택이 켜져 있어도 보존합니다. 교체를 선택한 미리보기 충돌의 기존 행이 아직 있더라도 그 행이 바뀌었다면 덮어쓰지 않고 `changedSincePreview`로 집계합니다. 비교는 ID, 날짜, 감정, 세 질문과 답변, 사진 경로, 생성·수정 시각을 명시적으로 포함하며 timestamp를 비교하지 않는 현재 `DailyEntry.==`만 사용하지 않습니다. 이미 사라진 충돌 날짜는 새 기록으로 삽입합니다.
5. 저장소는 `inserted`, `replaced`, `conflictSkipped`, `changedSincePreview`, `invalid`, `duplicate`의 서로 겹치지 않는 실제 건수를 반환합니다. 기본 보존 정책에서는 수정 여부와 무관하게 현재 충돌을 `conflictSkipped`로 셉니다. 교체 정책에서 새 충돌은 `conflictSkipped`, 미리보기 후 바뀐 교체 대상은 `changedSincePreview`로 셉니다. 이 합은 입력 목록 전체 건수와 같아야 합니다. JSON 자체 형식 오류는 목록이 확정되기 전 별도 오류이며 합계 대상이 아닙니다.
6. 예상치 못한 DB I/O 오류는 레코드 단위로 삼키지 않습니다. 트랜잭션 전체를 rollback하고 UI에 재시도 가능한 일반 오류를 표시합니다. 이 경우 부분 성공 요약을 보여주지 않습니다. 성공 후에만 저널 변경 신호·화면 갱신을 한 번 수행하고 실제 결과 건수를 표시합니다.

적용 단계는 기준 시각을 한 번 읽습니다. 미리보기 유효 후보가 시계 변경으로 미래 날짜가 되면 `invalid`로 제외하지만, 미리보기에서 제외했던 항목을 새 후보로 승격하지 않습니다. 자정 뒤 제외 항목을 다시 가져오려면 새 미리보기가 필요합니다. 미리보기의 `invalid`와 `duplicate` 분류는 유지하고 후보 강등만 `invalid`에 더합니다. 첫 후보가 강등되어도 같은 날짜의 뒤쪽 중복을 승격하지 않으며 합계 불변식을 유지합니다.

## 사진 파일 삭제 안전성

`PhotoService.deletePhoto`와 `cleanupOrphanedPhotos`는 앱 문서 폴더의 `photos` 디렉터리 바로 아래에 있는 소유 후보 파일만 대상으로 삼습니다. 플랫폼이 반환한 앱 문서 폴더를 real path로 해석한 곳이 신뢰 기준입니다. 운영체제의 문서 경로 별칭 자체는 거부하지 않되, 그 아래 `photos` 디렉터리와 최종 파일이 symlink이면 거부합니다. 후보는 절대경로여야 하고 원래 경로에 `..` 성분이 없어야 하며, 해석한 경로가 신뢰 기준 아래 `photos`의 직접 자식이어야 합니다. 링크를 따라가지 않는 조회·디렉터리 순회와 동일 검증을 사용합니다. 루트 자체, 부모, 디렉터리, DB 파일, 소유 규칙에 맞지 않는 파일, 외부 경로는 지우지 않습니다. 파일이 이미 없으면 성공으로 취급합니다.

소유 후보의 basename은 `photo_<숫자로 된 밀리초>.<확장자>`여야 하고 확장자는 대소문자 구분 없이 `jpg`, `jpeg`, `png`, `heic`, `heif`, `webp`, `gif`, `bmp`, `avif`만 허용합니다. 이는 새 삭제 정책이며 모든 picker의 실제 출력 목록이라는 주장은 아닙니다. 현행 생성 코드(`photo_service.dart:87-94`)는 선택 파일의 확장자를 그대로 쓰므로, 목록 밖 확장자를 가진 기존 파일은 실패로 삭제하지 않고 남깁니다. 파일 내용을 이미지로 판별하는 기능은 추가하지 않습니다. basename과 확장자만으로 경로 경계를 대체하거나 입력 JSON의 소유권을 인정하지 않습니다.

저장된 사진 정리는 DB 커밋 뒤에만 수행합니다. Today의 사진 교체, Timeline의 기록 삭제, Settings의 전체 삭제는 DB 변경 성공 뒤 현재 남은 사진 참조를 다시 읽고, 다른 행이 보존하는 파일은 삭제하지 않습니다. 미저장 사진 폐기는 DB를 수정하지 않고 현재 DB 참조와 해당 작업이 끝난 뒤 보존할 draft 사진을 보호합니다. 같은 파일의 경로 별칭을 다르게 취급하지 않도록 보호 참조도 동일한 정규 경로 기준으로 비교합니다. 참조를 읽거나 경로를 검증할 수 없으면 파일을 보존합니다. 호출자는 참조 보호를 맡고 서비스는 최종 파일 소유 경계를 맡으며, 서비스 외부에서 직접 `File.delete`하지 않습니다. DB 변경이 이미 성공한 뒤 실제 파일 삭제가 실패해도 성공한 텍스트 저장·삭제를 실패로 되돌리지 않습니다. 경로 원문은 사용자에게 표시하거나 삭제 실패 로그에 넣지 않습니다.

고아 정리도 동일한 root·basename·symlink 검사를 사용합니다. 부트스트랩과 앱에서 같은 `PhotoService` 인스턴스를 사용합니다. 시작 정리 보호 구간은 DB 스냅샷을 읽기 전부터 정리 완료까지입니다. 이 구간 중 사진 복사 경로를 복사 시작 전에 보호 집합에 넣고, picker Future가 끝나도 정리 완료까지 보호를 유지합니다. 따라서 미저장 draft와 이미 저장한 신규 사진이 낡은 스냅샷 때문에 삭제되지 않습니다. 기존 DB 사진은 스냅샷으로 보호하며 import는 새 외부 경로를 추가하지 않습니다. 정리 완료 뒤에는 보호 집합을 비웁니다. 명시적인 폐기·교체 삭제는 앞 문단의 현재 참조 검사로 처리합니다. 정리 실패도 보호 구간을 종료하고 파일 보존 쪽으로 처리합니다. 전역 락·공유 coordinator는 추가하지 않습니다. 다중 프로세스나 외부 프로세스의 적대적인 파일 교체에 대한 원자성은 보장하지 않습니다.

실제 서비스 경계에 임시 디렉터리 provider를 주입해 테스트합니다. 기존 picker 의존성을 다시 설계하지 않고 파일 경계만 시험 가능하게 좁힙니다.

## 파일 후보

| 파일 | 변경 책임 |
| --- | --- |
| `lib/data/repositories/entry_repository.dart` | 순수 import 검증 결과를 받고, 미리보기 및 트랜잭션 적용을 위한 제한된 DB 작업 제공. `saveEntry`는 변경하지 않음. |
| `lib/features/settings/settings_controller.dart` 및 새 소형 import 모델 파일 | JSON envelope 해석, `ImportPreview` 생성, 확인된 적용, `ImportResult` 전달, 성공 후 갱신. |
| `lib/features/settings/widgets/data_section.dart` | 미리보기 dialog, 취소/확인, 실제 결과와 사진 미포함 안내, export 사진 경고. |
| `lib/data/models/daily_entry.dart` 또는 export 경계 | 새 JSON 내보내기의 `photo_path`를 항상 `null`로 정규화. 기존 DB 매핑은 유지. |
| `lib/core/services/photo_service.dart`, `lib/app/bootstrap.dart` | 단일 소유 경로 validator, 서비스 삭제·정리, 최소 in-flight 보호 및 동일 인스턴스 연결. |
| `lib/features/today/today_controller.dart`, `lib/features/timeline/timeline_controller.dart`, `lib/features/settings/settings_controller.dart` | DB 커밋 뒤 남은 참조 검사와 미저장 사진 폐기의 보존 경로 검사. 일반 작성·취소 흐름의 계약은 유지. |
| `test/data/repositories/entry_repository_test.dart`, `test/features/settings/settings_controller_test.dart`, 데이터 UI 테스트, 사진 서비스 테스트 | 정책 경계와 수락 조건 검증. |

한 파일짜리 작은 import 결과 모델은 허용합니다. 저장소 전체에 퍼지는 인터페이스 추상화나 미래 기능용 provider hierarchy는 만들지 않습니다.

## 오류와 호환성

- 형식 오류·손상 레코드·중복은 미리보기에서 분류하고, DB I/O 오류는 전체 rollback으로 구분합니다.
- legacy timestamp 없는 JSON과 `app` 없는 `entries` envelope는 지원합니다. 기존 JSON 필드 이름은 바꾸지 않습니다.
- import의 과거 `photo_path`는 무시합니다. 새 export도 null을 기록하므로 절대 경로를 백업이라고 오해하지 않습니다.
- 일반 `saveEntry`의 날짜 upsert와 기존 DB 스키마는 그대로 둡니다. 충돌 방지 정책은 import UX와 import 전용 DB 적용 경로에만 둡니다.
- 사진 정리·삭제의 실패는 파일 보존 쪽으로 기웁니다. 확인되지 않은 소유권은 삭제하지 않습니다.

## 수락 조건

| 상황 | 기대 결과 |
| --- | --- |
| JSON 취소, 빈 파일 또는 envelope 오류 | 적용 전 DB 변경 0건. 오류는 경로 원문 없이 복구 가능하게 표시. |
| 충돌을 기본 정책으로 적용 | 기존 텍스트와 사진 모두 보존, `conflictSkipped`에 포함. |
| 충돌을 명시적으로 교체 | 텍스트만 교체, 기존 `createdAt`과 로컬 사진 경로·파일 보존. 유효한 입력 `updated_at`은 적용하고 생략 시 앱 clock을 사용. 확인 진입 1회. |
| 미리보기 뒤 같은 날짜에 새 DB 기록 생성 | 새 충돌은 교체 허가 대상이 아니며 기존 기록 보존, `conflictSkipped`에 포함. |
| 교체를 선택한 미리보기 충돌 행이 확인 전 수정됨 | 덮어쓰지 않고 기존 행 보존, `changedSincePreview`로 집계해 재검토 안내. 생성·수정 시각만 바뀐 경우도 포함. 기본 보존 선택이면 `conflictSkipped`. |
| 미리보기 충돌이 적용 전에 삭제됨 | 해당 입력은 신규 삽입으로 계산. |
| 중복·invalid·conflict·수정된 충돌·신규 혼합 입력 | 첫 유효 같은 날짜만 후보, 여섯 결과 카운터는 서로 배타적이고 합이 전체 입력 항목 수와 같음. |
| 형식 오류 날짜, 존재하지 않는 날짜, 미래 날짜, 소수/범위 밖 감정, 잘못된 prompts | 모두 `invalid`; 날짜는 앱 clock 기준이며 유효 레코드가 임의 보정되지 않음. |
| 미리보기 뒤 자정 경과 또는 시계 역행 | 제외 입력은 승격하지 않음. 후보가 미래가 되면 `invalid`에 추가하며 중복 후보 승격 없이 전체 건수 유지. |
| 정수 double 감정값 `5.0`, timezone timestamp, timestamp 생략 또는 null | `5.0`은 허용, 정상 timestamp 보존, 미지정 timestamp는 적용 단계 앱 clock 값 사용. |
| 예상치 못한 DB 오류 | 전체 import rollback, 부분 성공 결과를 반환하지 않음. |
| 외부·traversal·photos root symlink·최종 파일 symlink·DB/디렉터리/소유 규칙 밖 경로 | 파일을 보존. 정상 문서 경로 별칭은 지원. 서비스 테스트는 실제 임시 파일시스템에서 검증. |
| 실제 앱 소유 사진, 같은 경로를 참조하는 다른 기록, 마지막 참조 | 단독 소유는 삭제 가능, 공유 중에는 보존, 마지막 참조가 사라진 뒤 정리 가능. |
| DB 스냅샷 뒤 사진 복사 완료, picker 반환, draft 유지, 정리 순회 순서 | picker Future가 끝나도 정리 완료까지 파일 보존. 복사 중과 DB 저장 직후도 보존. 실제 서비스의 정리 대기 gate로 순서를 고정해 시험. |
| 기존 DB에 남은 신뢰 불가 `photo_path` 및 import JSON의 악성 경로 | 정리·삭제 호출을 통해 앱 밖 파일을 제거할 수 없음. 입력 경로는 새 DB에 저장되지 않음. |
| 작은 화면부터 큰 글씨 200% 설정 | 파일 선택→요약→취소/확인→적용→실제 결과의 순서를 완료하고 dialog가 읽고 조작 가능. 중복 탭은 1회 적용. |
| export에 로컬 사진이 있는 기록 | JSON의 `photo_path`는 null이고, 사용자는 사진 파일이 백업되지 않는다는 설명을 받음. |

## 검증과 미검증

테스트는 현재 계약 테스트를 새 정책에 맞게 갱신하고, 컨트롤러 테스트에서 미리보기와 적용 호출을 분리해 검증합니다. 위젯 테스트는 파일 선택 후 preview 생성, dialog 취소/확인, 적용, 실제 결과 표시 순서를 검증합니다. 사진 테스트는 임시 디렉터리 안·밖 파일, symlink, 공유 경로, 파일 부재와 정리 경쟁을 실제 `File` 경계에서 확인합니다.

심층감사 기준선은 통과 상태가 아닙니다. `flutter analyze --no-pub`는 timezone 관련 오류 2건이 있었고, `flutter test --no-pub --reporter expanded`는 loading/compile 오류로 실패했으며 결과는 +346/-11이었습니다. `pubspec.yaml`/`pubspec.lock`에는 `flutter_timezone`이 있지만 현재 `.dart_tool/package_config.json`에는 해당 패키지 항목이 없습니다. 분석·테스트는 정상 완료되지 않았으며 제품 코드만으로 발생한 회귀라고 확정하지 않습니다. 이 명세 작성 중에는 테스트를 재실행하지 않았습니다. 위 기준선은 최신 PASS로 간주하지 않습니다.

## 후속 순서

1. 이 설계 문서 검토와 승인
2. 승인 후 구현 계획 작성 및 별도 승인
3. 순수 import 검증·미리보기 모델과 저장소 트랜잭션 적용
4. 확인 UI와 사진 미포함 export 안내
5. 사진 삭제·정리 경계 및 실제 임시 파일시스템 테스트
6. 의존성 환경을 복구한 뒤 전체 분석·테스트 게이트를 실행하고 결과를 별도로 보고
