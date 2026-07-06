# ─────────────────────────────────────────────────────────────
# proguard-rules.pro
# Uddoygi — Android release build ProGuard/R8 rules
# ─────────────────────────────────────────────────────────────

# ── Google ML Kit — Text Recognition ─────────────────────────
# Keep the Latin recogniser (the only script we use at runtime).
-keep class com.google.mlkit.vision.text.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google_mlkit_text_recognition.**

# The plugin references these optional script modules at runtime via reflection.
# We don't ship them, so tell R8 to ignore the missing references instead of
# failing the build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep the options classes in case they are loaded reflectively on devices
# that do have the optional models installed.
-keep class com.google.mlkit.vision.text.chinese.** { *; }
-keep class com.google.mlkit.vision.text.devanagari.** { *; }
-keep class com.google.mlkit.vision.text.japanese.** { *; }
-keep class com.google.mlkit.vision.text.korean.** { *; }

# ── Flutter ───────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Google Play Services / Google Sign-In ─────────────────────
# ApiException: 10 is caused by R8 stripping these classes in release.
-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

-keep class com.google.api.client.** { *; }
-dontwarn com.google.api.client.**

# Google Sign-In specific
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }

# ── Firebase ──────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Auth (including Phone Auth / SafetyNet / Play Integrity)
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.auth.internal.** { *; }
# SafetyNet — required for Firebase Phone Auth reCAPTCHA fallback
-keep class com.google.android.gms.safetynet.** { *; }
# Play Integrity — newer alternative to SafetyNet
-keep class com.google.android.gms.appcheck.** { *; }
# reCAPTCHA WebView activity used as fallback when SMS auto-retrieval fails
-keep class com.google.android.recaptcha.** { *; }
-dontwarn com.google.android.recaptcha.**

# Firestore
-keep class com.google.firebase.firestore.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# ── Kotlin / Coroutines ───────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.coroutines.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ── OkHttp / Retrofit (used by Firebase internally) ──────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**

# ── General Android ───────────────────────────────────────────
-keepattributes SourceFile,LineNumberTable
-keepattributes InnerClasses
-keep public class * extends java.lang.Exception

# ── Video Player / AndroidX Media3 / ExoPlayer ───────────────
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-dontwarn androidx.media3.**
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
