import Foundation

/// Shared-store state normalized against the widget's local calendar date.
///
/// The app writes one snapshot for the current day. If WidgetKit renders an
/// older snapshot after midnight, the previous completion/emotion must not be
/// presented as today's state.
struct ThreeLinesWidgetState {
  let streakLabel: String
  let statusMessage: String
  let prompt: String
  let isCompleted: Bool
  let emotionRaw: String

  static func resolve(
    storedDate: String?,
    today: String,
    streakLabel: String,
    statusMessage: String,
    prompt: String,
    isCompleted: Bool,
    emotionRaw: String
  ) -> ThreeLinesWidgetState {
    guard storedDate == today else {
      return ThreeLinesWidgetState(
        streakLabel: streakLabel,
        statusMessage: "오늘 한 줄만 적어도 돼요",
        prompt: "오늘 감사한 작은 것 하나는?",
        isCompleted: false,
        emotionRaw: ""
      )
    }

    return ThreeLinesWidgetState(
      streakLabel: streakLabel,
      statusMessage: statusMessage,
      prompt: prompt,
      isCompleted: isCompleted,
      emotionRaw: emotionRaw
    )
  }
}
