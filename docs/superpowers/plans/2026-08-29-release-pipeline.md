# 3Lines 릴리스 파이프라인 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Android/iOS 릴리스가 버전·서명·의존성·테스트 조건을 fail-closed로 검증하고, GitHub Actions에서 재현 가능한 산출물을 생성하도록 구성한다.

**Architecture:** Dart 버전 검증 라이브러리와 셸 기반 플랫폼 검증 스크립트를 분리하고, Android Gradle 게이트와 iOS target별 CI build setting을 workflow에서 조합한다. 비밀값은 GitHub Secrets에서만 주입하며 GitHub Release 첨부와 스토어 업로드를 별도 단계로 둔다.

**Tech Stack:** Flutter/Dart, Gradle Kotlin DSL, Xcode/xcodebuild, CocoaPods, GitHub Actions, Bash.

**Spec:** `docs/superpowers/specs/2026-08-29-release-pipeline-design.md`

## 전역 제약

- 실제 keystore, p12, provisioning profile, App Store Connect key를 저장소에 기록하지 않는다.
- `allowUnsignedRelease=true`는 `CI=true`에서 거부한다.
- 변경마다 테스트를 먼저 추가하고, 마지막에는 깨끗한 검증 명령을 다시 실행한다.
- 기존 UX/알림 동작과 `pubspec.yaml`의 `1.2.3+6`을 보존한다.

## 작업 1 — 버전·태그 검증

- [x] **파일:** `tool/release/release_version.dart`, `tool/release/validate_version.dart`, `test/tool/release/release_version_test.dart`
- [x] **실패 테스트:** `name+build` 파싱, 잘못된 태그, 기존 태그 중복, 태그 없는 detached checkout을 검증하는 테스트를 먼저 작성한다.
- [x] **구현:** `pubspec.yaml`의 version을 파싱하고 `v<name>` 태그와 비교하는 순수 Dart API와 CLI를 구현한다.
- [x] **검증:** `flutter test --no-pub test/tool/release/release_version_test.dart` 및 `dart run tool/release/validate_version.dart --tag v1.2.3`를 실행한다.
- [x] **커밋:** `feat: add release version validation`

## 작업 2 — Android 서명 fail-closed 및 산출물 검증

- [x] **파일:** `android/app/build.gradle.kts`, `tool/release/verify_android_artifact.sh`, `test/tool/release/android_release_gate_test.sh`
- [x] **실패 테스트:** `CI=true -PallowUnsignedRelease=true`가 실패하고, keystore 없이 `assemble`, `build`, `bundle`, `packageRelease`가 모두 게이트에서 중단되는지 확인한다.
- [x] **구현:** CI 우회 금지, 실제 keystore 파일 존재 확인, signed artifact verifier를 추가한다.
- [x] **검증:** JDK 21로 Gradle aggregate/direct release task와 unsigned local escape hatch를 각각 확인한다.
- [x] **커밋:** `fix: harden android release signing gate`

## 작업 3 — iOS 서명 주입 및 export

- [x] **파일:** `ios/Runner.xcodeproj/project.pbxproj`, `tool/release/prepare_ios_signing.sh`, `tool/release/generate_export_options.sh`
- [x] **실패 테스트:** 필수 secret이 없을 때 준비 스크립트가 실패하고, target별 profile 이름이 누락되면 export 설정 생성이 실패하도록 한다.
- [x] **구현:** Runner/위젯 Release/Profile 설정에 CI 변수 참조를 추가하고 임시 keychain·profile 설치 및 exportOptions.plist 생성 스크립트를 구현한다.
- [x] **검증:** `pod install --deployment`, no-code-sign device compile, secret 없는 fail-closed 경로를 확인한다.
- [x] **커밋:** `feat: prepare ios distribution signing`

## 작업 4 — CI/release workflow 및 운영 문서

- [x] **파일:** `.github/workflows/ci.yml`, `.github/workflows/release.yml`, `docs/RELEASE.md`, `README.md`
- [x] **실패 테스트:** workflow YAML 문법, 버전 검증 명령, 서명 secret 이름, CocoaPods 동기화 명령을 정적 검사한다.
- [x] **구현:** PR CI, 태그/수동 릴리스, GitHub Release 첨부, 명시적 TestFlight 업로드 gate를 추가한다.
- [x] **검증:** `actionlint`, `shellcheck`, Ruby YAML parser, `git diff --check`, workflow에서 사용하는 로컬 명령을 실행한다.
- [x] **커밋:** `ci: add reproducible mobile release workflows`

## 작업 5 — 종합 검증 및 push/release

- [x] **파일:** 위 변경 전체
- [x] **검증:** `flutter analyze`, 전체 `flutter test`, Android unit test, version gate, shellcheck 가능한 스크립트 검사, git diff/status를 새 프로세스에서 실행한다.
- [x] **통합:** 브랜치를 `origin/codex/runtime-correctness-energy`로 push했고, PR #18의 최신 CI 두 job이 모두 통과했다. 자격 증명이 없으므로 태그 릴리스는 fail-closed 조건으로 보류했다.
- [x] **커밋/태그:** 최종 커밋까지 원격에 push했다. `v1.2.3` 태그는 GitHub Secrets 등록 후 생성하도록 보류했다.
