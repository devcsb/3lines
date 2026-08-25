import Foundation

@main
struct ThreeLinesWidgetStateTests {
  static func main() {
    let stale = ThreeLinesWidgetState.resolve(
      storedDate: "2026-08-25",
      today: "2026-08-26",
      streakLabel: "42일",
      statusMessage: "오늘 기록 완료 · 감사",
      prompt: "어제 질문",
      isCompleted: true,
      emotionRaw: "5"
    )
    precondition(stale.isCompleted == false)
    precondition(stale.emotionRaw.isEmpty)
    precondition(stale.statusMessage == "오늘 한 줄만 적어도 돼요")
    precondition(stale.prompt == "오늘 감사한 작은 것 하나는?")

    let today = ThreeLinesWidgetState.resolve(
      storedDate: "2026-08-26",
      today: "2026-08-26",
      streakLabel: "42일",
      statusMessage: "오늘 기록 완료 · 감사",
      prompt: "오늘 질문",
      isCompleted: true,
      emotionRaw: "5"
    )
    precondition(today.isCompleted)
    precondition(today.emotionRaw == "5")
    precondition(today.prompt == "오늘 질문")
  }
}
