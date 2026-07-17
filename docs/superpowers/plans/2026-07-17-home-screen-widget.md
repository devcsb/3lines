# Home Screen Widget Implementation Plan

> **Status:** Completed (approach A)

## Summary

- Dart `WidgetSyncService` writes shared keys and calls `HomeWidget.updateWidget`
- Android `ThreeLinesWidgetProvider` (small/medium RemoteViews)
- iOS `ThreeLinesWidget` WidgetKit extension (small/medium)
- Deep link `threelines://today?emotion=N` preselects emotion in Today
- Settings → 홈 화면 위젯 설치 안내

## Native notes

### Android
- Receiver: `com.threelines.three_lines.ThreeLinesWidgetProvider`
- Layouts: `three_lines_widget_small`, `three_lines_widget_medium`

### iOS
- App Group: `group.com.threelines.threeLines` (Runner + extension)
- Widget kind / `iOSName`: `ThreeLinesWidget`
- Xcode: enable App Groups for both targets with your Team if signing fails
- First-time: `flutter build ios` then add widget from home screen

## Verify
```bash
flutter test test/core/services/widget_sync_service_test.dart
flutter analyze lib
# device: save today entry → widget status updates after app sync
```
