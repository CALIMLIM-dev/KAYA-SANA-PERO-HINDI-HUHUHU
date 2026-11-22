package com.alphatech.kaya_app

import android.annotation.SuppressLint
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    // The phone's ANDROID_ID, hashed, so a ban can reach the phone. It survives
    // a reinstall; a factory reset or another signing key gives a new one.
    @SuppressLint("HardwareIds")
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "kaya/device").setMethodCallHandler { call, result ->
            if (call.method != "id") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val raw = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
            if (raw.isNullOrEmpty()) {
                result.success(null)
                return@setMethodCallHandler
            }
            val hash = MessageDigest.getInstance("SHA-256").digest(raw.toByteArray())
                .joinToString("") { "%02x".format(it) }
            result.success(hash)
        }
    }
}
