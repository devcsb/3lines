package com.threelines.three_lines

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ThreeLinesWidgetStateTest {
    @Test
    fun `다음 자정 갱신 시각은 현지 날짜의 00시 00분 05초다`() {
        val zone = TimeZone.getTimeZone("Asia/Seoul")
        val now = Calendar.getInstance(zone).apply {
            set(2026, Calendar.AUGUST, 6, 23, 30, 0)
            set(Calendar.MILLISECOND, 0)
        }

        val next = Calendar.getInstance(zone).apply {
            timeInMillis = ThreeLinesWidgetProvider.nextMidnightTrigger(now)
        }

        assertEquals(2026, next.get(Calendar.YEAR))
        assertEquals(Calendar.AUGUST, next.get(Calendar.MONTH))
        assertEquals(7, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(0, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, next.get(Calendar.MINUTE))
        assertEquals(5, next.get(Calendar.SECOND))
    }

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
