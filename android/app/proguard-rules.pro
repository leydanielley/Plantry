# Flutter ProGuard Rules
# Keep Flutter engine classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# SQLite & Database
-keep class com.tekartik.sqflite.** { *; }
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Image Picker
-keep class com.baseflow.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Google Play Core (for Flutter Engine)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Keep all model classes
-keep class com.plantry.growlog.** { *; }
