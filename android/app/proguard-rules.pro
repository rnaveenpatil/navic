# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep MainActivity for method channel
-keep class com.example.navic.MainActivity { *; }

# Keep MethodChannel classes
-keep class * extends io.flutter.plugin.common.MethodCallHandler { *; }

# Don't strip any method/class that is annotated with @Keep
-keep @androidx.annotation.Keep class * {*;}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <methods>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <fields>;
}
-keepclasseswithmembers class * {
    @androidx.annotation.Keep <init>(...);
}

# Kotlin metadata
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses

# Keep resource classes
-keepclassmembers class **.R$* {
    public static <fields>;
}

# Suppress warnings
-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugin.**
-dontwarn com.google.android.gms.**