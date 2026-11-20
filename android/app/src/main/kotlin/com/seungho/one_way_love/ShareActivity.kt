package com.seungho.one_way_love

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.Log
import java.io.BufferedReader

// 카톡 '대화 내보내기 → 텍스트 메시지만 저장 → DueDate'를 받는 투명한 중간 화면 (보이지 않고 바로 닫힘)
// 카톡은 받는 화면을 항상 새로 만들라고 요청함 (NEW_DOCUMENT, MULTIPLE_TASK)
//   MainActivity가 직접 받으면 앱이 켜져 있어도 Flutter가 하나 더 켜지고,
//   디버그 실행(start-paused 옵션) 중엔 새 Flutter가 일시정지된 채 검은 화면으로 멈춤 (logcat으로 확인)
// 그래서 여기서 받은 파일만 열어 ShareInbox에 맡기고, 켜져 있는 앱(MainActivity)을 앞으로 불러온 뒤 닫힘
// 읽기 · 자르기 · Flutter로 넘기기는 ShareInbox
class ShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 파일은 이 화면이 닫히기 전에 열어 둠 (카톡이 준 읽기 권한이 이 화면에 묶여 있어서), 읽기는 백그라운드
        ShareInbox.receive(openShared(intent))
        startActivity(
            Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        )
        finish()
    }

    // 공유받은 내용 열기: txt 파일이면 파일들, 글자면 글자 그대로
    private fun openShared(intent: Intent?): List<BufferedReader> {
        if (intent == null) return emptyList()
        val uris = if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            streamsOf(intent)
        } else {
            listOfNotNull(streamOf(intent))
        }
        if (uris.isNotEmpty()) return uris.mapNotNull { open(it) }
        val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return emptyList()
        return listOf(text.reader().buffered())
    }

    @Suppress("DEPRECATION")
    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamsOf(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }) ?: emptyList()

    // 파일 열기 (공유한 앱이 읽기 권한을 같이 넘겨주므로 따로 권한 요청 필요 없음)
    // 사진 · 동영상 · 음성은 대화가 아니라서 열지 않음
    private fun open(uri: Uri): BufferedReader? {
        val type = contentResolver.getType(uri) ?: ""
        if (type.startsWith("image/") || type.startsWith("video/") || type.startsWith("audio/")) {
            return null
        }
        return try {
            contentResolver.openInputStream(uri)?.bufferedReader(Charsets.UTF_8)
        } catch (e: Exception) {
            Log.e(ShareInbox.TAG, "open failed: $uri", e)
            null
        }
    }
}
