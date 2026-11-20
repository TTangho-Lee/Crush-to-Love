package com.seungho.one_way_love

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// 앱 화면 (Flutter), 공유받은 대화를 Flutter로 넘기는 통로
// 공유는 ShareActivity가 받아서 ShareInbox에 맡기고 이 화면을 앞으로 불러옴
// 짝: lib/analysis/chat/share_receiver.dart, 채널 이름 duedate/share
//   Flutter → 'takeSharedText': Flutter가 받을 준비가 됨 + 맡아 둔 대화 꺼내기 (없으면 null)
//   여기 → 'sharedText': 준비된 뒤 새로 받은 대화
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    /// Flutter 쪽이 'takeSharedText'를 불렀으면 true (그 전에 보내면 받을 곳이 없어 사라짐)
    private var flutterReady = false

    private val deliver: (String) -> Boolean = { text ->
        val ch = channel
        if (flutterReady && ch != null) {
            ch.invokeMethod("sharedText", text)
            true
        } else {
            false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "duedate/share").apply {
            setMethodCallHandler { call, result ->
                if (call.method == "takeSharedText") {
                    flutterReady = true
                    result.success(ShareInbox.take())
                } else {
                    result.notImplemented()
                }
            }
        }
        ShareInbox.deliver = deliver
    }

    override fun onDestroy() {
        if (ShareInbox.deliver === deliver) ShareInbox.deliver = null
        super.onDestroy()
    }
}
