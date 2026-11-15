plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. CI decodes the keystore from repository secrets and passes
// its path and password in these variables (see docs/RELEASING.md). Without
// them a local release build falls back to the debug key, which is fine for
// trying things out but cannot update an installed release.
val releaseKeystore: String? = System.getenv("PANTRY_KEYSTORE_PATH")
val releasePassword: String? = System.getenv("PANTRY_KEYSTORE_PASSWORD")

android {
    namespace = "au.com.combinationsoupstudio.pantry_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "au.com.combinationsoupstudio.pantry_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseKeystore != null && releasePassword != null) {
            create("release") {
                storeFile = file(releaseKeystore)
                storePassword = releasePassword
                keyAlias = "pantry"
                keyPassword = releasePassword
            }
        }
    }

    // Release builds run Android lint's "vital" checks over every plugin, and
    // the lint tool crashes on url_launcher_android's sources (NoSuchMethodError
    // in JavaDocParser) on some JDKs. That is a tool fault, not ours, and must
    // not block a release; Dart analysis and tests are the gate (CI).
    lint {
        checkReleaseBuilds = false
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
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
