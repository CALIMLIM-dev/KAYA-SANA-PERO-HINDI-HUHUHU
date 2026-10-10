package com.alphatech.kaya_app

import android.os.Build
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.view.ViewTreeObserver
import io.flutter.embedding.android.FlutterActivity

/*
    The opening animation.

    On Android 12 and later the system splash plays the KAYA icon going up,
    frame by frame (res/drawable/splash_build.xml), the moment the app is
    tapped. Left alone, the splash would be taken down at the app's first
    frame and the build cut off half-made, so the first draw is held until it
    has finished. The app is then told the icon is already built and opens on
    it finished, rather than building it a second time.
*/
class MainActivity : FlutterActivity() {
    private val systemBuildsIcon = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

    override fun getDartEntrypointArgs(): List<String>? =
        if (systemBuildsIcon) listOf("splash-built") else null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (!systemBuildsIcon) return

        val shownAt = SystemClock.uptimeMillis()
        val content: View = findViewById(android.R.id.content)
        content.viewTreeObserver.addOnPreDrawListener(object : ViewTreeObserver.OnPreDrawListener {
            override fun onPreDraw(): Boolean {
                if (SystemClock.uptimeMillis() - shownAt < SPLASH_MS) return false
                content.viewTreeObserver.removeOnPreDrawListener(this)
                return true
            }
        })
    }

    private companion object {
        // Matches KayaLaunch.splashDuration and the frames' total length.
        const val SPLASH_MS = 1000L
    }
}
