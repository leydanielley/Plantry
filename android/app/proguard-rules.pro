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

# =============================================
# ANDROID COMPATIBILITY RULES
# =============================================

# AndroidX Core
-keep class androidx.core.** { *; }
-dontwarn androidx.core.**

# FileProvider
-keep class androidx.core.content.FileProvider { *; }

# Notifications
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }

# SharedPreferences
-keep class android.content.SharedPreferences { *; }
-keep class android.content.SharedPreferences$Editor { *; }

# Reflection for Flutter plugins
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Android 15 Edge-to-Edge
-keep class androidx.core.view.WindowCompat { *; }
-keep class androidx.core.view.WindowInsetsCompat { *; }

# Prevent obfuscation of database models
-keepclassmembers class * {
    @android.annotation.SuppressLint *;
}

# Keep serialization
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Crashlytics (if ever added)
-keepattributes SourceFile,LineNumberTable

# =============================================
# SUPPRESS WARNINGS FOR OPTIONAL DEPENDENCIES
# =============================================

# Apache Tika (used by some dependencies, not needed at runtime)
-dontwarn javax.xml.stream.XMLStreamException
