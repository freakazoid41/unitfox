package com.unit.fox

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Google Play SDK 35 edge-to-edge: draw behind system bars on every
        // API level so Android 15 behaviour matches older devices. Flutter's
        // AppBar/SafeArea consume the insets.
        WindowCompat.setDecorFitsSystemWindows(window, false)
    }
}
