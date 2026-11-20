package com.seungho.one_way_love

import android.os.Handler
import android.os.Looper
import android.util.Log
import java.io.BufferedReader
import java.util.Calendar
import java.util.concurrent.Executors

// 공유받은 대화 보관함: ShareActivity가 열어 준 파일을 백그라운드에서 읽어 Flutter로 넘김
//   Flutter가 준비돼 있으면 바로 넘기고 (MainActivity의 deliver), 아니면 맡아 뒀다가 'takeSharedText' 때 넘김
// 몇 년치 대화도 멈추지 않게 한 줄씩 읽고, 최근 KEEP_DAYS일 대화만 남김
//   분석 기간은 최대 30일 23시간, 같은 기준: lib/analysis/chat/chat_parser.dart의 keepDays
object ShareInbox {
    /// logcat 태그 (읽기 실패 등)
    const val TAG = "DueDateShare"

    /// 넘길 최대 기간 (일)
    const val KEEP_DAYS = 31

    private val worker = Executors.newSingleThreadExecutor()
    private val mainThread = Handler(Looper.getMainLooper())

    /// 넘기지 못하고 맡아 둔 대화
    private var pending: String? = null

    /// 받은 대화를 Flutter로 바로 넘기는 곳, 넘겼으면 true (MainActivity가 등록)
    var deliver: ((String) -> Boolean)? = null

    /// 열어 둔 파일(또는 글자)들을 백그라운드에서 읽기, 다 읽으면 화면 스레드에서 넘김
    fun receive(readers: List<BufferedReader>) {
        if (readers.isEmpty()) return
        worker.execute {
            val text = readers.mapNotNull { reader ->
                try {
                    reader.use { keepRecent(it) }
                } catch (e: Exception) {
                    Log.e(TAG, "read failed", e)
                    null
                }
            }.joinToString("\n")
            if (text.isEmpty()) return@execute
            mainThread.post {
                if (deliver?.invoke(text) != true) pending = text
            }
        }
    }

    /// 맡아 둔 대화 꺼내기 (꺼내면 비움), 화면 스레드에서
    fun take(): String? {
        val text = pending
        pending = null
        return text
    }

    // 최근 KEEP_DAYS일 대화만 남기기 (첫 줄 같은 머리말은 유지)
    // 카톡 내보내기는 시간 순이라, 날짜로 시작하는 줄이 처음 기간 안에 들면 그 뒤는 검사 없이 그대로
    private fun keepRecent(reader: BufferedReader): String {
        val cutoff = cutoffKey()
        val out = StringBuilder()
        var seenDate = false
        var keeping = false
        reader.forEachLine { line ->
            if (!keeping) {
                val key = dateKey(line)
                if (key != null) {
                    seenDate = true
                    keeping = key >= cutoff
                }
            }
            // 첫 날짜 줄 전(머리말)이거나 기간 안이면 남김
            if (keeping || !seenDate) out.append(line).append('\n')
        }
        return out.toString()
    }

    // 줄 맨 앞 날짜 → 20261120 같은 숫자, 날짜로 시작하지 않으면 null
    // '2026년 11월 20일 …', '2026. 11. 20. …', PC 날짜 줄 '----- 2026년 11월 20일 금요일 -----'
    private fun dateKey(line: String): Int? {
        val m = DATE_PREFIX.find(line) ?: return null
        val (y, mo, d) = m.destructured
        return y.toInt() * 10000 + mo.toInt() * 100 + d.toInt()
    }

    // 오늘에서 KEEP_DAYS일 전 날짜 → 20261020 같은 숫자
    private fun cutoffKey(): Int {
        val c = Calendar.getInstance()
        c.add(Calendar.DAY_OF_YEAR, -KEEP_DAYS)
        return c.get(Calendar.YEAR) * 10000 + (c.get(Calendar.MONTH) + 1) * 100 + c.get(Calendar.DAY_OF_MONTH)
    }

    private val DATE_PREFIX = Regex("""^-*\s*(\d{4})(?:년 |\. ?)(\d{1,2})(?:월 |\. ?)(\d{1,2})""")
}
