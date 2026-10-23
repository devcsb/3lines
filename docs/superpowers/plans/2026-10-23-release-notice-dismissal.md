# 작성 알림 닫기와 배포 검증

> **For agentic workers:** Use superpowers:executing-plans. Steps use checkbox syntax.

**Goal:** 작성 알림을 명시적으로 닫고 입력을 유지한 채 기록을 저장할 수 있게 한다.
**Architecture:** Today의 되돌리기와 사진 재시도 SnackBar에 Flutter 표준 닫기 조작을 제공한다. 기존 action, 초안과 저장 로직은 바꾸지 않는다.
**Tech Stack:** Flutter, Riverpod, SQLite 메모리 시험.
**Spec:** `docs/superpowers/specs/2026-10-11-product-trust-and-ux-design.md` R4/R6. 배포 전 발견한 후속 항목은 `docs/RELEASE.md`에 있다.

## Global Constraints

- 사용자 기록과 키를 읽거나 바꾸지 않는다. 테스트는 가상 기록과 메모리 DB만 쓴다.
- 기존 Undo의 revision/session 보호와 사진 취소의 조용한 종료를 유지한다.
- 200% 글씨, 48dp 조작, 플랫폼 접근성 이름을 보존한다.
- 최신 공개 `v1.3.1`의 책등 아이콘을 유지한다. 기존 태그를 덮어쓰지 않는다.

## Review Focus

- 접근성 탐색 때 사라지지 않는 알림을 버튼으로 닫을 수 있는가.
- 닫기 조작이 되돌리기나 사진 재시도를 실행하지 않는가.
- 320dp 폭/200% 글씨와 가로 화면에서 닫기가 도달 가능한가.
- 알림을 닫은 다음 저장한 데이터가 알림 전 입력과 같은가.
- 실제 앱의 한국어 tooltip과 native 터치 영역이 유지되는가.

### Task 1: 작성 알림 복구

**Files:** `lib/features/today/today_screen.dart`, `test/features/today/writing_recovery_screen_test.dart`, `test/features/today/photo_recovery_screen_test.dart`.
**Interfaces:** 기존 `SnackBar`/`TodayScreen`/`EntryRepository.getEntryByDate` 사용. 새 공유 API 없음.

- [x] 접근성 탐색 활성화 후 알림이 유지되는 상황에서 닫기, 입력 보존, 실제 저장을 검증하는 시험을 먼저 추가한다. 좁은 화면/큰 글씨와 가로 화면을 포함한다.
- [x] 두 시험 파일을 실행해 닫기 조작이 없어 실패함을 확인한다.
- [x] 두 action SnackBar에 표준 닫기 버튼을 제공하고 타깃 시험을 통과시킨다. 기존 Undo/재시도 시험도 유지한다.
- [x] 전체 analyze/test, 네이티브 및 파이프라인 검증을 실행하고 독립 소스 검토를 받는다.
- [ ] 새 버전과 태그로 서명 CI를 실행한다. 공개 자산의 서명/체크섬과 이전 인증서 일치, 설치/작성 흐름을 확인하고 RELEASE.md에 증거와 한계를 기록한다.
