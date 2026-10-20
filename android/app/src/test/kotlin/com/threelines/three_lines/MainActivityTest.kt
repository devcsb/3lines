package com.threelines.three_lines

import androidx.fragment.app.FragmentActivity
import org.junit.Assert.assertTrue
import org.junit.Test

class MainActivityTest {
    @Test
    fun `앱 진입 Activity는 기기 인증 플러그인이 요구하는 FragmentActivity다`() {
        assertTrue(
            "local_auth rejects activities without FragmentActivity support",
            FragmentActivity::class.java.isAssignableFrom(MainActivity::class.java),
        )
    }
}
