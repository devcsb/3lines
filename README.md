<div align="center">

<img src="https://img.shields.io/badge/Flutter-3.47.1-02569B?style=flat-square&logo=flutter&logoColor=white" />
<img src="https://img.shields.io/badge/Dart-3.11-0175C2?style=flat-square&logo=dart&logoColor=white" />
<img src="https://img.shields.io/badge/Android-API%2026+-3DDC84?style=flat-square&logo=android&logoColor=white" />
<img src="https://img.shields.io/badge/License-MIT-yellow?style=flat-square" />

# 3Lines

**한국어로 짧게 남기는 하루의 감정과 기록**

*감사, 수용, 의도 중 한 줄부터 시작하세요*

[GitHub 릴리스 확인](../../releases/latest) · [버그 리포트](../../issues) · [기능 제안](../../issues)

</div>

---

## 스크린샷

| 오늘의 기록 | 히트맵 타임라인 | 감정 인사이트 | 설정 |
|:-----------:|:---------------:|:-------------:|:----:|
| 감정 선택 + 3줄 작성 | GitHub 잔디 스타일 | 추이 차트 + 통계 | 테마 · 알림 · 보안 |

---

## 소개

저널링을 시작하려다 빈 페이지 앞에서 포기한 적 있으신가요?

**3Lines**는 "딱 3줄만" 이라는 원칙으로 만든 미니멀 저널 앱입니다.
감사, 수용, 의도라는 세 질문을 제공합니다. 감정과 답변 하나를 입력하면 기록을 저장할 수 있고, 세 질문을 모두 채우지 않아도 됩니다. 심리 효과와 30초 완료를 검증한 앱은 아닙니다.

```
감사  ─  오늘 감사한 작은 것 하나는?
수용  ─  오늘 불편했던 감정을, 있는 그대로 인정한다면?
의도  ─  내일 내가 되고 싶은 모습은?
```

---

## 주요 기능

### 📝 짧은 기록
- 5단계 감정 선택 (힘듦 😫 → 감사 😊)
- 탭 가능한 예시 문구로 빈 페이지 마찰 감소
- 저장 완료 체크마크 애니메이션
- 사진 첨부 지원 (카메라 / 갤러리)

### 📊 시각적 성취감
- **GitHub 잔디 스타일 히트맵** — 12주 / 6개월 / 1년 뷰
- 연속 기록일(스트릭) 추적 + 1일 유예(Grace Day) 시스템
- 마일스톤 축하 배너 (7일 / 30일 / 100일 / 365일)

### 💡 자기 발견 인사이트
- 감정 추이 라인 차트 (1주 / 1개월 / 3개월)
- 요일별 평균 감정 바 차트
- 자주 쓰는 단어 키워드 분석 (한국어 조사 분리 처리)
- 감사 키워드 TOP 5
- 월간 감정 요약 카드
- 주간 회고 리포트

### 🔒 기기 안에 저장하는 기록
- 일기는 계정이나 서버 없이 기기에 저장
- 내보내기나 공유를 선택하면 파일이 기기 밖으로 나갈 수 있음
- 생체인증(Face ID / 지문) 앱 잠금
- 알림 미리보기에도 저널 답변을 포함하지 않는 중립 문구 사용
- 완료 기록의 JSON 텍스트 내보내기 / 가져오기 (초안, 사진, 설정 제외)
- 월간 리포트 PDF 생성

### 🎨 세련된 디자인
- Muted Sage 컬러 팔레트
- 라이트 / 다크 / 시스템 테마
- 달성 조건부 잠금 해제 액센트 테마
- "1년 전 오늘" 회고 카드

---

## 기술 스택

| 영역 | 라이브러리 |
|------|-----------|
| 상태관리 | [flutter_riverpod](https://riverpod.dev) 3.x (수동 Notifier/AsyncNotifier) |
| 라우팅 | [go_router](https://pub.dev/packages/go_router) |
| 로컬 DB | [Drift](https://drift.simonbinder.eu) (SQLite) |
| 차트 | [fl_chart](https://pub.dev/packages/fl_chart) |
| 알림 | [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) |
| 인증 | [local_auth](https://pub.dev/packages/local_auth) |
| PDF | [printing](https://pub.dev/packages/printing) + [pdf](https://pub.dev/packages/pdf) |
| 사진 | [image_picker](https://pub.dev/packages/image_picker) |

---

## 설치

### APK 직접 설치 (Android)

2026-10-11에 확인한 공개 [v1.2.3](https://github.com/devcsb/3lines/releases/tag/v1.2.3)에는 `app-release.aab`만 있고 설치용 APK는 없습니다. AAB는 휴대폰에서 직접 설치할 수 없습니다. 이 로컬 개선은 아직 게시하지 않았습니다.

다음 서명 릴리스의 첨부에 `app-release.apk`가 실제로 나타나면 다음 순서로 설치합니다.

1. [Releases](../../releases/latest)에서 universal `app-release.apk`를 내려받습니다.
2. 해당 브라우저나 파일 앱에 필요한 외부 앱 설치 권한을 허용합니다.
3. APK를 열어 설치합니다. 설치 뒤 권한을 다시 끌 수 있습니다.

업데이트하려면 기존 설치본과 같은 서명이 필요합니다. 서명이 다르면 삭제로 우회하지 말고 먼저 완료 기록을 JSON으로 내보내세요. JSON은 사진, 초안, 설정을 보존하지 않습니다. GitHub 베타와 Google Play 등록은 별개입니다. [베타 관찰 안내](docs/ANDROID_BETA.md)를 참고하세요.

### 직접 빌드

**요구 사항**
- Flutter 3.47.1 (CI 기준)
- Dart 3.11+
- Android Studio (JDK 21)

```bash
# 1. 저장소 클론
git clone https://github.com/devcsb/3lines.git
cd 3lines

# 2. 의존성 설치
flutter pub get

# 3. 코드 생성 (필수)
dart run build_runner build --delete-conflicting-outputs

# 4. 앱 실행
flutter run

# 5. APK 빌드
# 배포 빌드는 CI에서 android/keystore.properties를 주입해야 합니다.
flutter build apk --release

# 서명 없는 로컬 컴파일/매니페스트 검증만 필요한 경우
flutter build apk --release --split-per-abi \
  --android-project-arg=allowUnsignedRelease=true
```

`allowUnsignedRelease=true`로 만든 APK는 배포·업데이트에 사용할 수 없습니다. Play 배포 전에는
upload keystore와 CI 서명 검사를 반드시 구성하세요.

모바일 릴리스의 버전·서명·CocoaPods·TestFlight 절차는 [릴리스 가이드](docs/RELEASE.md)를 따르세요. 태그 기반
GitHub Actions 소스는 검증을 통과한 AAB와 universal APK를 GitHub Release에 첨부하도록 구성합니다. Apple signing이 준비된 경우 IPA도 포함하며, TestFlight 업로드는 명시적으로 활성화한 경우에만 실행됩니다. 실제 게시 여부는 해당 Release 첨부에서 확인하세요.

---

## 프로젝트 구조

```
lib/
├── app.dart                        # 앱 진입점, 라우팅
├── core/
│   ├── constants/                  # 기본 프롬프트 등 상수
│   ├── services/                   # 알림, 생체인증, PDF, 사진 서비스
│   ├── theme/                      # 테마 (라이트/다크/액센트)
│   └── utils/                      # 날짜, 텍스트 분석 유틸리티
├── data/
│   ├── database/                   # Drift DB 정의
│   ├── models/                     # 데이터 모델
│   └── repositories/               # 데이터 접근 레이어
└── features/
    ├── insights/                   # 인사이트/통계 화면
    ├── lock/                       # 생체인증 잠금 화면
    ├── onboarding/                 # 온보딩 화면
    ├── settings/                   # 설정 화면
    ├── timeline/                   # 타임라인 + 히트맵
    └── today/                      # 오늘의 기록 (메인)
```

---

## 개발 로드맵

| 단계 | 기능 | 상태 |
|------|------|------|
| v1.0 | 핵심 루프 (기록 / 히트맵 / 인사이트) | ✅ 완료 |
| P0 | 프롬프트 제안, 애니메이션 저장 버튼 | ✅ 완료 |
| P1 | 마일스톤 축하, 1년 전 오늘, 월간 요약 | ✅ 완료 |
| P2 | 사진 첨부, 주간 회고, PDF 리포트, 홈 위젯 | ✅ 완료 |
| P3 | iCloud/Google Drive 백업, 다국어 | 🔜 예정 |

---

## 기여

이슈와 PR을 환영합니다.

```bash
# 개발 브랜치 생성
git checkout -b feat/your-feature

# 변경 후 테스트
flutter test

# PR 생성
```

---

## 라이선스

[MIT License](LICENSE)

---

<div align="center">

**3Lines** — 어제보다 오늘, 한 줄 더 나를 알게 돼요.

</div>
