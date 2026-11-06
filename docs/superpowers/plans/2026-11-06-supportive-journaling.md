# 부담을 낮추는 기록 경험 구현 계획

설계: [리서치와 경험 설계](../specs/2026-11-06-supportive-journaling-design.md)

기존 Flutter/Riverpod 구조와 저장 계약을 재사용한다. 현재 작업 폴더의 아이콘과 알림 변경을 보존한다. 커밋과 배포는 이번 작업에 포함하지 않는다.

- [x] `today_screen.dart`: 쓰기 우선 배치, 닫힌 회고, 인라인 저장 확인, 선택형 사진/예시. 기존 컨트롤러 메서드 그대로 사용.
- [x] `emotion_picker.dart`, `prompt_card.dart`, `prompt_suggestions.dart`, `animated_save_button.dart`: 읽기 쉬운 상태와 라벨, 48px 터치 영역, 분수 압박 제거, 명시적 선택.
- [x] `default_prompts.dart`, `onboarding_screen.dart`: 비판단적 질문과 안내. 기존 질문 스냅샷과 사용자 지정 문구 보존.
- [x] 위젯/통합 테스트: 회고 비노출→펼치기, 한 답변 저장→즉시 수정, 실패→입력 보존, 320px/200%/가로/다크 레이아웃, semantics/대비.
- [x] 전체 `flutter test`, `flutter analyze`, 변경 파일 포맷과 diff 검사. 새 실패가 발생한 범위만 재검증.
- [x] 실제 렌더링 이미지와 검증 한계를 보고서에 기록.

검토할 경계는 사용자 지정 질문, 기존 답변이 있는 수정 모드, 회고를 열지 않은 접근성 트리, 저장 실패, 키보드와 큰 글자가 겹친 화면이다.

검증 결과와 실기기 검증 한계는 [결과 보고서](../reviews/2026-11-06-supportive-journaling.md)에 기록했다.
