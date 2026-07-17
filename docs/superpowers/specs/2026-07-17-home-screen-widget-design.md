# Home Screen Widget Design

> **Status:** Approved (approach A) — implement iOS/Android home widgets

## Goal

홈 화면에서 오늘의 기록 상태·스트릭·질문·감정을 한눈에 보고, 탭 한 번으로 Today 작성 흐름에 들어가게 한다.

## Research → product mapping

| Best practice | 3Lines 적용 |
|---------------|-------------|
| Duo: streak + done/not done only | 스트릭 + 오늘 완료 여부 |
| Duo: tap opens app to complete | 탭 → Today (딥링크) |
| Journal soft UI | sage 톤, 차분한 문구 |
| Medium: larger action surface | 감정 5칩 (딥링크 프리셀렉트) |
| Install awareness | 설정에 위젯 추가 안내 |

## UX

### Small
- 3Lines 라벨
- 스트릭 (`N일` 또는 시작 유도)
- 상태 문구 (`오늘 아직이에요` / `오늘 기록 완료`)
- 탭 → `threelines://today`

### Medium
- 위 + 오늘의 질문(감사 축 1개)
- 미완료 시 감정 1~5 칩 → `threelines://today?emotion=N`
- 완료 시 선택 감정 라벨, 칩 숨김

### Emotion deep link (A)
- 위젯은 저장하지 않음
- 앱 오픈 후 Today에 감정 프리셀렉트
- 생체 잠금이 켜져 있으면 잠금 해제 후 적용

## Architecture

```
EntryRepository / SettingsRepository
        │
        ▼
  WidgetSyncService (Dart)
   save keys + updateWidget
        │
   SharedPreferences / App Group UserDefaults
        │
   Android AppWidgetProvider | iOS WidgetKit
```

### Shared keys
- `date`, `streak`, `is_completed`, `prompt`, `emotion`, `status_message`, `streak_label`

### Constants
- App Group: `group.com.threelines.threeLines`
- iOS widget name: `ThreeLinesWidget`
- Android widget name: `ThreeLinesWidgetProvider`
- Scheme: `threelines`

### Update triggers
- bootstrap (앱 시작)
- Today save / delete entry (import 등 포함 journalChanges)
- 자정 롤오버 / 포그라운드 복귀 시 날짜 불일치

## Out of scope
- 위젯에서 3줄 본문 저장
- Lock screen widget
- Glance generator / large size
- workmanager 백그라운드 주기 갱신 (타임라인 atEnd + 앱 동기화로 충분)

## Testing
- `WidgetSnapshot` / status message pure unit tests
- deep link emotion parse tests
- 기존 Today/settings 회귀
