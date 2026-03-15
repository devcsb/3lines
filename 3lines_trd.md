# 3Lines — Technical Requirements Document (TRD)

> **문서 버전**: v1.0
> **최종 수정**: 2026-03-14
> **참조**: [3lines_prd.md](./3lines_prd.md)

---

## 1. 기술 스택

### 1.1 핵심 스택

| 영역 | 기술 | 버전 | 선택 이유 |
|------|------|------|-----------|
| 프레임워크 | Flutter | 3.x (stable) | 크로스플랫폼, 빠른 UI 개발 |
| 언어 | Dart | 3.x | Flutter 기본 언어 |
| 상태관리 | Riverpod | 2.x | 간결하고 테스트 용이, 컴파일 타임 안전성 |
| 로컬DB | Drift (moor 후속) | 2.x | SQLite 래퍼, 타입 안전, 리액티브 쿼리 |
| 라우팅 | go_router | 14.x | 선언적 라우팅, StatefulShellRoute |
| 차트 | fl_chart | 0.69.x | Flutter 네이티브, 커스터마이징 자유도 |
| 알림 | flutter_local_notifications | 17.x | 로컬 리마인더 |
| 날짜 | intl | 0.19.x | 다국어 날짜 포맷팅 |
| 공유 | share_plus | 9.x | JSON 내보내기 공유 시트 |
| 테마 | Material 3 (Material You) | — | 다크모드 기본, 동적 컬러 |
| 애니메이션 | Flutter 내장 | — | AnimationController, implicit animations |

### 1.2 pubspec.yaml

```yaml
name: three_lines
description: 하루 3줄 마이크로 저널 앱
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  go_router: ^14.2.0
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.3
  path: ^1.9.0
  fl_chart: ^0.69.0
  flutter_local_notifications: ^17.2.1
  intl: ^0.19.0
  share_plus: ^9.0.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.18.0
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  flutter_lints: ^4.0.0
  custom_lint: ^0.6.4
  riverpod_lint: ^2.3.10
```

> **참고**: `permission_handler` 제거 — MVP에서 카메라/갤러리 미사용. 알림 권한은 `flutter_local_notifications`이 자체 처리.

---

## 2. 아키텍처

### 2.1 레이어드 아키텍처

```
┌─────────────────────────────────────────────────┐
│                  UI Layer                        │
│  (Screens, Widgets)                              │
│  - today_screen.dart, timeline_screen.dart, ...  │
├─────────────────────────────────────────────────┤
│               Controller Layer                   │
│  (Riverpod AsyncNotifier / Notifier)             │
│  - today_controller.dart, insights_controller... │
├─────────────────────────────────────────────────┤
│              Repository Layer                    │
│  (비즈니스 로직, 데이터 변환)                       │
│  - entry_repository.dart, settings_repository..  │
├─────────────────────────────────────────────────┤
│                Data Layer                        │
│  (Drift Database, Tables)                        │
│  - app_database.dart, entries.dart, settings...   │
└─────────────────────────────────────────────────┘
```

**데이터 흐름**:
```
UI → Controller (state 변경)
      → Repository (비즈니스 로직)
        → Database (CRUD)
          → Repository (데이터 변환)
            → Controller (state 업데이트)
              → UI (리빌드)
```

**규칙**:
- UI는 Repository를 직접 참조하지 않음 (항상 Controller를 통해)
- Repository는 UI 모델(`DailyEntry`)을 반환, DB 엔티티(`Entry`)를 직접 노출하지 않음
- Controller는 Database를 직접 참조하지 않음 (항상 Repository를 통해)

### 2.2 프로젝트 구조

```
lib/
├── main.dart                          # 앱 진입점, ProviderScope
├── app.dart                           # GoRouter, MaterialApp.router
│
├── core/                              # 앱 전반 공유
│   ├── theme/
│   │   ├── app_theme.dart             # Material 3 라이트/다크 테마
│   │   └── app_colors.dart            # 감정 색상, 히트맵 색상 상수
│   ├── constants/
│   │   └── default_prompts.dart       # 기본 질문 3개 + 카테고리
│   └── utils/
│       ├── date_utils.dart            # 날짜 비교, 포맷, 인사말 로직
│       └── text_analysis.dart         # 키워드 추출, 불용어 필터
│
├── data/                              # 데이터 레이어
│   ├── database/
│   │   ├── app_database.dart          # Drift DB 클래스 + Provider
│   │   ├── app_database.g.dart        # 코드 생성 파일
│   │   └── tables/
│   │       ├── entries.dart           # entries 테이블
│   │       └── settings.dart          # settings 테이블
│   ├── repositories/
│   │   ├── entry_repository.dart      # 엔트리 CRUD + 통계 쿼리
│   │   └── settings_repository.dart   # 설정 읽기/쓰기
│   └── models/
│       └── daily_entry.dart           # UI용 엔트리 모델 (freezed 미사용, 단순 클래스)
│
├── features/                          # 화면별 feature 모듈
│   ├── onboarding/
│   │   └── onboarding_screen.dart     # 3페이지 온보딩
│   ├── today/
│   │   ├── today_screen.dart
│   │   ├── today_controller.dart
│   │   └── widgets/
│   │       ├── prompt_card.dart
│   │       ├── emotion_picker.dart
│   │       └── completion_animation.dart
│   ├── timeline/
│   │   ├── timeline_screen.dart
│   │   ├── timeline_controller.dart
│   │   └── widgets/
│   │       ├── heatmap_grid.dart
│   │       ├── streak_badge.dart
│   │       └── entry_detail_sheet.dart
│   ├── insights/
│   │   ├── insights_screen.dart
│   │   ├── insights_controller.dart
│   │   └── widgets/
│   │       ├── emotion_trend_chart.dart
│   │       ├── stat_card.dart
│   │       ├── keyword_cloud.dart
│   │       └── day_of_week_chart.dart
│   └── settings/
│       ├── settings_screen.dart
│       ├── settings_controller.dart
│       └── widgets/
│           ├── prompt_editor.dart
│           ├── reminder_picker.dart
│           └── export_button.dart
│
└── shared/                            # 공유 위젯
    └── widgets/
        ├── app_bottom_nav.dart
        └── section_header.dart
```

---

## 3. 데이터베이스 설계

### 3.1 테이블 정의 (Drift)

#### entries 테이블

```dart
class Entries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text().unique()();                // 'yyyy-MM-dd'
  TextColumn get prompt1 => text().withDefault(const Constant(''))();
  TextColumn get answer1 => text().withDefault(const Constant(''))();
  TextColumn get prompt2 => text().withDefault(const Constant(''))();
  TextColumn get answer2 => text().withDefault(const Constant(''))();
  TextColumn get prompt3 => text().withDefault(const Constant(''))();
  TextColumn get answer3 => text().withDefault(const Constant(''))();
  IntColumn get emotion => integer().check(emotion.isBetweenValues(1, 5))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

> **변경사항 (PRD v1 대비)**: `photoPath` 컬럼 제거 — MVP에서 사진 기능 미포함. 향후 마이그레이션으로 추가.

#### settings 테이블

```dart
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
```

### 3.2 Settings 키 목록

| Key | 기본값 | 타입 | 설명 |
|-----|--------|------|------|
| `prompt_1` | "오늘 감사한 작은 것 하나는?" | String | 감사 질문 |
| `prompt_2` | "오늘 불편했던 감정을, 있는 그대로 인정한다면?" | String | 수용 질문 |
| `prompt_3` | "내일 내가 되고 싶은 모습은?" | String | 의도 질문 |
| `reminder_enabled` | "false" | Bool(String) | 리마인더 ON/OFF |
| `reminder_hour` | "21" | Int(String) | 리마인더 시 (0~23) |
| `reminder_minute` | "0" | Int(String) | 리마인더 분 (0~59) |
| `theme_mode` | "system" | Enum(String) | "light" / "dark" / "system" |
| `onboarding_done` | "false" | Bool(String) | 온보딩 완료 여부 |

### 3.3 UI 모델

```dart
class DailyEntry {
  final int? id;
  final String date;           // 'yyyy-MM-dd'
  final int emotion;           // 1~5
  final String prompt1;
  final String answer1;
  final String prompt2;
  final String answer2;
  final String prompt3;
  final String answer3;
  final DateTime createdAt;
  final DateTime updatedAt;

  // DB Entry → DailyEntry 변환 factory
  factory DailyEntry.fromEntry(Entry entry);

  // DailyEntry → EntriesCompanion 변환 (저장용)
  EntriesCompanion toCompanion();
}
```

### 3.4 Repository 인터페이스

#### EntryRepository

```dart
class EntryRepository {
  final AppDatabase _db;

  // === CRUD ===

  /// 오늘 엔트리 조회 (없으면 null)
  Future<DailyEntry?> getTodayEntry();

  /// 특정 날짜 엔트리 조회
  Future<DailyEntry?> getEntryByDate(String date);

  /// 엔트리 저장 (upsert: date 기준)
  Future<void> saveEntry(DailyEntry entry);

  // === 히트맵 ===

  /// 기간 내 날짜별 감정 점수 맵
  /// 반환: {'2026-03-01': 4, '2026-03-02': 3, ...}
  Future<Map<String, int>> getEmotionMap(DateTime start, DateTime end);

  // === 스트릭 ===

  /// 현재 연속 기록일 (오늘 미작성이면 어제부터 카운트)
  Future<int> getCurrentStreak();

  /// 최장 연속 기록일
  Future<int> getLongestStreak();

  // === 인사이트 ===

  /// 총 기록 수
  Future<int> getTotalCount();

  /// 기간 내 일별 감정 데이터 (차트용)
  /// 반환: [{date: DateTime, emotion: int}, ...]
  Future<List<({DateTime date, int emotion})>> getEmotionTrend(DateTime start, DateTime end);

  /// 최근 N일 평균 감정
  Future<double> getAverageEmotion(int days);

  /// 요일별 평균 감정
  /// 반환: {1(월): 3.2, 2(화): 4.1, ..., 7(일): 3.8}
  Future<Map<int, double>> getEmotionByDayOfWeek();

  /// 전체 답변에서 키워드 빈도 (불용어 제거 후)
  Future<Map<String, int>> getKeywordFrequency({int limit = 10});

  /// 감사(prompt1) 답변에서만 키워드 빈도
  Future<Map<String, int>> getGratitudeKeywords({int limit = 5});

  // === 내보내기 ===

  /// 전체 데이터 JSON export
  Future<List<Map<String, dynamic>>> exportAllEntries();

  /// 모든 데이터 삭제
  Future<void> deleteAllEntries();
}
```

#### SettingsRepository

```dart
class SettingsRepository {
  final AppDatabase _db;

  /// 설정값 조회 (없으면 defaultValue 반환)
  Future<String> getSetting(String key, {required String defaultValue});

  /// 설정값 저장 (upsert)
  Future<void> setSetting(String key, String value);

  /// 질문 3개 조회 (기본값 포함)
  Future<List<String>> getPrompts();

  /// 리마인더 설정 조회
  Future<({bool enabled, int hour, int minute})> getReminderSettings();

  /// 테마 모드 조회
  Future<String> getThemeMode();
}
```

### 3.5 DB 마이그레이션 전략

```dart
@DriftDatabase(tables: [Entries, Settings])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // 향후 스키마 변경 시 여기에 마이그레이션 로직 추가
      // 예: if (from < 2) { await m.addColumn(entries, entries.photoPath); }
    },
  );
}
```

**마이그레이션 원칙**:
- 스키마 변경 시 `schemaVersion` 증가
- `onUpgrade`에서 버전별 분기 처리
- 컬럼 추가는 nullable로 시작 → 마이그레이션 후 기본값 설정
- 절대 컬럼 삭제/이름 변경 하지 않기 (SQLite 제약)

---

## 4. 상태 관리 (Riverpod)

### 4.1 Provider 구조

```
appDatabaseProvider (싱글톤)
├── entryRepositoryProvider
│   ├── todayControllerProvider (AsyncNotifier)
│   ├── timelineControllerProvider (AsyncNotifier)
│   └── insightsControllerProvider (AsyncNotifier)
└── settingsRepositoryProvider
    └── settingsControllerProvider (AsyncNotifier)
```

### 4.2 Controller 상태 정의

#### TodayController

```dart
// 상태
class TodayState {
  final int? emotion;          // null = 미선택
  final String answer1;
  final String answer2;
  final String answer3;
  final List<String> prompts;  // 질문 3개
  final bool isCompleted;      // 오늘 이미 기록 완료 여부
  final bool isEditing;        // 편집 모드 여부
  final int currentStreak;     // 연속 기록일
}

// 메서드
@riverpod
class TodayController extends _$TodayController {
  @override
  Future<TodayState> build() async { ... }

  void setEmotion(int value);
  void setAnswer(int index, String value);
  Future<void> save();
  void toggleEdit();
}
```

#### TimelineController

```dart
class TimelineState {
  final int currentStreak;
  final int longestStreak;
  final Map<String, int> emotionMap;   // date → emotion
  final TimelinePeriod period;         // weeks12, months6, year1
}

enum TimelinePeriod { weeks12, months6, year1 }

@riverpod
class TimelineController extends _$TimelineController {
  @override
  Future<TimelineState> build() async { ... }

  Future<void> setPeriod(TimelinePeriod period);
}
```

#### InsightsController

```dart
class InsightsState {
  final bool isUnlocked;              // 7일 이상 여부
  final int totalCount;
  final int requiredCount;            // 7
  final double averageEmotion;
  final int currentStreak;
  final String bestDayOfWeek;
  final List<({DateTime date, int emotion})> emotionTrend;
  final Map<int, double> dayOfWeekEmotions;
  final Map<String, int> keywords;
  final Map<String, int> gratitudeKeywords;
  final InsightsPeriod period;
}

enum InsightsPeriod { week1, month1, month3 }
```

#### SettingsController

```dart
class SettingsState {
  final List<String> prompts;
  final bool reminderEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String themeMode;    // "system" | "light" | "dark"
}

@riverpod
class SettingsController extends _$SettingsController {
  @override
  Future<SettingsState> build() async { ... }

  Future<void> updatePrompt(int index, String value);
  Future<void> resetPrompts();
  Future<void> setReminderEnabled(bool enabled);
  Future<void> setReminderTime(int hour, int minute);
  Future<void> setThemeMode(String mode);
  Future<String> exportData();
  Future<void> deleteAllData();
}
```

### 4.3 테마 Provider

```dart
/// 앱 전역 테마 모드를 관리하는 별도 Provider
/// main.dart의 MaterialApp에서 참조
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  Future<ThemeMode> build() async {
    final mode = await ref.read(settingsRepositoryProvider).getThemeMode();
    return switch (mode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(String mode) async { ... }
}
```

---

## 5. 라우팅 (go_router)

### 5.1 라우트 구조

```dart
GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    // 온보딩 미완료 시 → /onboarding 리디렉트
    if (!onboardingDone && state.matchedLocation != '/onboarding') {
      return '/onboarding';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (_, __, navigationShell) => ScaffoldWithNavBar(navigationShell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const TodayScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/timeline', builder: (_, __) => const TimelineScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/insights', builder: (_, __) => const InsightsScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
  ],
);
```

### 5.2 네비게이션 규칙

- 각 탭은 독립적인 네비게이션 스택 (StatefulShellBranch)
- 탭 전환 시 이전 탭 상태 보존
- 온보딩 완료 전에는 메인 화면 접근 불가

---

## 6. 핵심 유틸리티

### 6.1 date_utils.dart

```dart
/// 시간대별 인사말
String getGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return '좋은 아침이에요';
  if (hour >= 12 && hour < 18) return '좋은 오후예요';
  return '좋은 저녁이에요';
}

/// 오늘 날짜 문자열
String getTodayString() => DateFormat('yyyy-MM-dd').format(DateTime.now());

/// 한국어 날짜 포맷
String formatKoreanDate(DateTime date) =>
    DateFormat('yyyy년 M월 d일 EEEE', 'ko').format(date);

/// 두 날짜가 같은 날인지 비교
bool isSameDay(DateTime a, DateTime b);
```

### 6.2 text_analysis.dart

```dart
/// 한국어 불용어 목록
const koreanStopWords = {
  // 조사
  '은', '는', '이', '가', '을', '를', '의', '에', '에서',
  '로', '으로', '와', '과', '도', '만', '까지', '부터',
  // 대명사
  '나', '너', '그', '저', '이것', '그것', '저것',
  // 동사/형용사 어간
  '하다', '있다', '되다', '없다', '않다', '했다', '했는데',
  // 접속사/부사
  '그리고', '하지만', '그래서', '또한', '때문에',
  '것', '수', '때', '등', '중', '더', '좀', '잘', '못',
  '정말', '진짜', '매우', '아주', '너무',
  // 시간 관련 (질문에 이미 포함)
  '오늘', '내일', '어제',
};

/// 텍스트에서 키워드 추출
/// 로직: 공백 분리 → 불용어 제거 → 1글자 제거 → 빈도 카운트
Map<String, int> extractKeywords(List<String> texts, {int limit = 10});
```

### 6.3 default_prompts.dart

```dart
class PromptCategory {
  static const gratitude = 'gratitude';
  static const acceptance = 'acceptance';
  static const intention = 'intention';
}

const defaultPrompts = [
  (
    category: PromptCategory.gratitude,
    question: '오늘 감사한 작은 것 하나는?',
  ),
  (
    category: PromptCategory.acceptance,
    question: '오늘 불편했던 감정을, 있는 그대로 인정한다면?',
  ),
  (
    category: PromptCategory.intention,
    question: '내일 내가 되고 싶은 모습은?',
  ),
];
```

---

## 7. 에러 처리 전략

### 7.1 에러 계층

| 계층 | 에러 유형 | 처리 방식 |
|------|----------|----------|
| Database | DB 열기 실패, 쿼리 실패 | SnackBar + 재시도 안내 |
| Repository | 데이터 변환 실패 | 기본값 반환 + 로그 |
| Controller | AsyncValue.error | UI에서 에러 상태 렌더링 |
| UI | 위젯 빌드 에러 | ErrorWidget 대체 표시 |
| File I/O | JSON 내보내기 실패 | SnackBar 에러 메시지 |

### 7.2 AsyncValue 패턴

```dart
// Controller의 모든 상태는 AsyncValue로 래핑
ref.watch(todayControllerProvider).when(
  data: (state) => TodayContent(state: state),
  loading: () => const Center(child: CircularProgressIndicator()),
  error: (error, stack) => ErrorView(
    message: '데이터를 불러올 수 없어요',
    onRetry: () => ref.invalidate(todayControllerProvider),
  ),
);
```

---

## 8. 성능 요구사항

| 항목 | 목표 | 측정 방법 |
|------|------|----------|
| 앱 시작 (cold start) | < 2초 | 스플래시 → Today 화면 표시까지 |
| Today 화면 로딩 | < 200ms | DB 쿼리 → 화면 렌더링 |
| 히트맵 렌더링 (1년) | < 500ms | 52주 × 7일 = 364셀 렌더링 |
| 인사이트 계산 | < 1초 | 모든 통계 쿼리 병렬 실행 |
| 저장 (upsert) | < 100ms | DB 쓰기 + 상태 업데이트 |
| 앱 크기 | < 30MB | release 빌드 기준 |
| 메모리 사용 | < 100MB | 1년치 데이터 기준 |

### 8.1 성능 최적화 전략

- **히트맵**: 1년 모드에서 셀이 364개 → `CustomPaint`로 구현 (위젯 수 최소화)
- **인사이트 쿼리**: 여러 통계를 `Future.wait`로 병렬 실행
- **키워드 분석**: Repository에서 계산, 결과 캐싱 (Controller 상태에 보관)
- **이미지 없음**: MVP에서 사진 기능 미포함으로 메모리 부담 최소화

---

## 9. 테스트 전략

### 9.1 테스트 범위

| 레이어 | 테스트 유형 | 우선순위 | 커버리지 목표 |
|--------|-----------|---------|-------------|
| Repository | Unit Test | 높음 | 90%+ |
| Controller | Unit Test | 높음 | 80%+ |
| Utils | Unit Test | 높음 | 95%+ |
| Database | Integration Test | 중간 | 주요 쿼리 전수 |
| UI | Widget Test | 낮음 (MVP) | 핵심 플로우만 |

### 9.2 핵심 테스트 케이스

**EntryRepository**:
- `getTodayEntry()`: 엔트리 있는 경우 / 없는 경우
- `saveEntry()`: 신규 저장 / 기존 업데이트 (upsert)
- `getCurrentStreak()`: 연속 0일 / 1일 / N일 / 오늘 미작성 시
- `getLongestStreak()`: 빈 DB / 스트릭 1회 / 여러 스트릭 중 최장
- `getEmotionMap()`: 빈 기간 / 중간에 빈 날짜 / 기간 경계
- `getKeywordFrequency()`: 빈 답변 / 불용어만 / 정상 데이터

**TodayController**:
- 초기 로딩: 미작성 상태 / 작성 완료 상태
- `save()`: 유효한 입력 / 감정 미선택 / 답변 미입력
- `toggleEdit()`: 읽기↔편집 전환

**text_analysis**:
- 빈 문자열 / 불용어만 / 1글자만 / 정상 텍스트
- 한국어 + 영어 혼합 / 특수문자 포함

### 9.3 테스트 실행

```bash
# 전체 테스트
flutter test

# 커버리지 리포트
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
```

---

## 10. 빌드 & 배포

### 10.1 빌드 명령어

```bash
# Drift 코드 생성
dart run build_runner build --delete-conflicting-outputs

# Riverpod 코드 생성 (위 명령에 포함)
# dart run build_runner build

# 개발 빌드
flutter run

# 릴리즈 빌드
flutter build ios --release
flutter build appbundle --release  # Android AAB
```

### 10.2 코드 생성 파일

| 파일 | 생성 도구 | 트리거 |
|------|----------|--------|
| `app_database.g.dart` | drift_dev | 테이블 변경 시 |
| `*_controller.g.dart` | riverpod_generator | @riverpod 어노테이션 변경 시 |

> `.g.dart` 파일은 git에 포함 (CI에서 build_runner 불필요하도록)

### 10.3 앱 서명 & 배포 (추후)

- iOS: Xcode → App Store Connect
- Android: keystore → Google Play Console
- 자동화: 추후 Fastlane 또는 GitHub Actions 검토

---

## 11. 개발 Phase 순서

| Phase | 내용 | 예상 산출물 |
|-------|------|-----------|
| 0 | 프로젝트 초기화 | Flutter 프로젝트, 폴더 구조, pubspec.yaml, 빈 파일 |
| 1 | 데이터 레이어 | DB 테이블, Repository, Provider, 코드 생성 |
| 2 | 라우팅 & 네비게이션 | go_router, 4탭 쉘, 테마, 빈 화면들 |
| 3 | Today Screen | 감정 피커, 질문 카드, 저장/수정, 애니메이션 |
| 4 | Timeline Screen | 히트맵, 스트릭 배지, 상세 BottomSheet |
| 5 | Insights Screen | 차트들, 통계 카드, 키워드 분석, 빈 상태 |
| 6 | Settings Screen | 질문 편집, 리마인더, 테마, 내보내기, 삭제 |
| 7 | 폴리싱 | 온보딩, 빈 상태, 에러 처리, 접근성, 앱 아이콘 |

**Phase 간 의존성**:
```
Phase 0 → Phase 1 → Phase 2 → Phase 3
                              → Phase 4
                              → Phase 5
                              → Phase 6
                                      → Phase 7
```
> Phase 3~6은 데이터 레이어(1)와 라우팅(2) 완료 후 독립 진행 가능하나, 순서대로 진행 권장.
