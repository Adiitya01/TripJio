# ============================================================
# TripJio ProGuard / R8 rules — production code shrinking
# ============================================================

# ─── Flutter ────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ─── Firebase ──────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ─── Google Maps ───────────────────────────────────────────
-keep class com.google.android.libraries.maps.** { *; }
-keep class com.google.maps.** { *; }
-dontwarn com.google.android.libraries.maps.**

# ─── Geolocator ────────────────────────────────────────────
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ─── flutter_background_service ───────────────────────────
-keep class id.flutter.flutter_background_service.** { *; }
-dontwarn id.flutter.flutter_background_service.**

# ─── flutter_local_notifications ──────────────────────────
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# ─── Supabase / Postgres / WebSocket ───────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**
-keep class io.github.jan.supabase.** { *; }

# ─── HTTP / OkHttp / Dio ──────────────────────────────────
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# ─── Kotlin coroutines (transitive deps) ──────────────────
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# ─── Misc ─────────────────────────────────────────────────
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Don't warn about missing classes from optional dependencies
-dontwarn javax.annotation.**
-dontwarn org.codehaus.**
