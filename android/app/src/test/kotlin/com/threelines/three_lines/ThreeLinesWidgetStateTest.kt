package com.threelines.three_lines

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ThreeLinesWidgetStateTest {
    @Test
    fun `오늘 저장값은 완료 상태와 감정을 유지한다`() {
        val state = resolveThreeLinesWidgetState(
            storedDate = "2026-08-06",
            today = "2026-08-06",
            streakLabel = "7일",
            statusMessage = "오늘 기록 완료 · 감사",
            prompt = "오늘 감사한 작은 것 하나는?",
            isCompleted = true,
            emotionRaw = "5",
        )
        assertTrue(state.isCompleted)
        assertEquals("5", state.emotionRaw)
        assertEquals("오늘 기록 완료 · 감사", state.statusMessage)
    }

    @Test
    fun `지난 날짜 저장값은 오늘 미작성 상태로 정규화한다`() {
        val state = resolveThreeLinesWidgetState(
            storedDate = "2026-08-05",
            today = "2026-08-06",
            streakLabel = "7일",
            statusMessage = "오늘 기록 완료 · 감사",
            prompt = "어제의 질문",
            isCompleted = true,
            emotionRaw = "5",
        )
        assertFalse(state.isCompleted)
        assertEquals("", state.emotionRaw)
        assertEquals("오늘 한 줄만 적어도 돼요", state.statusMessage)
        assertEquals("오늘 감사한 작은 것 하나는?", state.prompt)
        assertEquals("7일", state.streakLabel)
    }
}
