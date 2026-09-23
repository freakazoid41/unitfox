# Flutter embedding — keep engine + plugin registrant reachable under R8.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Generated plugin registrant is referenced reflectively by the engine.
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterApplication { *; }

# google_mobile_ads — keep public ad API used via method channels / JNI.
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# sqflite / path / file_picker / image_picker method-channel entry points.
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Keep annotations R8 full mode might strip.
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses,EnclosingMethod

# JNI / native libraries used by Flutter and sqlite3.
-keepclasseswithmembernames class * {
    native <methods>;
}

# Play Core split APIs referenced by Flutter embedding but not on the classpath
# (app is not delivered via Play Feature Delivery).
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# WorkManager + Room + SQLite driver (transitive, e.g. via play-services).
# R8 full mode strips the Room-generated WorkDatabase impl otherwise and the
# app dies in InitializationProvider before Flutter even starts.
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    <init>(android.content.Context,androidx.work.WorkerParameters);
}
-keep class androidx.room.** { *; }
-keep class * extends androidx.room.RoomDatabase
-keep @androidx.room.Database class *
-keep @androidx.room.Dao class *
-keep @androidx.room.Entity class *
-keep class androidx.sqlite.** { *; }
-dontwarn androidx.work.**
-dontwarn androidx.room.**
-dontwarn androidx.sqlite.**
