package com.plantry.growlog

import android.os.Build
import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ✅ Android 15 Edge-to-Edge Support
        // Enable edge-to-edge display for better compatibility with Android 15+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            // Android 15 (API 35) and above
            WindowCompat.setDecorFitsSystemWindows(window, false)
        } else {
            // Backward compatibility for Android 14 and below
            // Flutter handles insets automatically for older versions
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }
    }
}
