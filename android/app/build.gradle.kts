import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

// ─── Release signing config (reads from key.properties if present) ─────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tripjio.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tripjio.app"
        minSdk = flutter.minSdkVersion  // Android 6.0+ — required by Firebase/Supabase Realtime
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for large dependency tree (Firebase + Supabase + Maps)
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // Enable both v1 (JAR) and v2 (APK) signing
                // v1 is needed for older devices / sideload installers
                enableV1Signing = true
                enableV2Signing = true
            }
        }
    }

    buildTypes {
        release {
            // Refuse to build release without a real keystore — a debug-signed
            // "release" APK cannot be uploaded to the Play Store and would only
            // ever be a mistake here.
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "Release build requires android/key.properties with a real " +
                    "keystore. Missing file: ${keystorePropertiesFile.absolutePath}"
                )
            }
            signingConfig = signingConfigs.getByName("release")

            // Code shrinking + obfuscation for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        debug {
            // Debug builds: no minification, faster compile
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            // Avoid duplicate META-INF errors from multiple Firebase libs
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // For Java 8+ APIs on older Android (required by flutter_local_notifications)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
