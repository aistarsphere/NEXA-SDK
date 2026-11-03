import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties (never committed; see
// docs/mobile/RELEASE.md): storeFile, storePassword, keyAlias, keyPassword.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile") != null
// A local, NON-DISTRIBUTABLE release (e.g. `flutter run --release` on a test
// phone) may be debug-signed only by saying so: NEXA_DEBUG_SIGN=1.
val debugSignRelease = System.getenv("NEXA_DEBUG_SIGN") == "1"

android {
    namespace = "com.nexa.nexa_example"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nexa.nexa_example"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKey -> signingConfigs.getByName("release")
                debugSignRelease -> signingConfigs.getByName("debug")
                else -> null // refused below: no silent debug-signed release
            }
            // Shrink code and resources; keep rules are in proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// A release must be signed with the release key. Without it the build stops
// instead of producing a debug-signed or unsigned package.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project &&
            it.name in setOf("assembleRelease", "bundleRelease", "packageRelease")
    }
    if (buildsRelease && !hasReleaseKey && !debugSignRelease) {
        throw GradleException(
            "Release signing is not configured. Create android/key.properties " +
                "(storeFile, storePassword, keyAlias, keyPassword; see " +
                "docs/mobile/RELEASE.md), or set NEXA_DEBUG_SIGN=1 for a local " +
                "build that must NOT be distributed.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
