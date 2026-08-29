package com.threelines.three_lines

internal data class ThreeLinesWidgetState(
    val streakLabel: String,
    val statusMessage: String,
    val prompt: String,
    val isCompleted: Boolean,
    val emotionRaw: String,
)

internal fun resolveThreeLinesWidgetState(
    storedDate: String?,
    today: String,
    streakLabel: String,
    statusMessage: String,
    prompt: String,
    isCompleted: Boolean,
    emotionRaw: String,
): ThreeLinesWidgetState {
    if (storedDate != today) {
        return ThreeLinesWidgetState(
            streakLabel = streakLabel,
            statusMessage = "오늘 한 줄만 적어도 돼요",
            prompt = "오늘 감사한 작은 것 하나는?",
            isCompleted = false,
            emotionRaw = "",
        )
    }
    return ThreeLinesWidgetState(
        streakLabel = streakLabel,
        statusMessage = statusMessage,
        prompt = prompt,
        isCompleted = isCompleted,
        emotionRaw = emotionRaw,
    )
}
