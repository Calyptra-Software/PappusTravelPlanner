plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.calyptra.pappus"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.calyptra.pappus"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // A build meant to be side-loaded beside a real install. Android
        // identifies an app by its applicationId, so a build carrying the same
        // one is an *update* of what is installed — and being signed with a
        // different key, it is refused as a conflicting package rather than
        // offered as a second app. A suffixed id is therefore the whole trick;
        // the label follows so a human can tell the two apart on the launcher,
        // and the widget picker inherits it, having no label of its own.
        //
        // Off unless asked for, so an ordinary `flutter build apk` and every
        // `flutter run` stay exactly what they were. CI asks by exporting
        // ORG_GRADLE_PROJECT_pappusSideBySide=true, which is how a project
        // property reaches Gradle through a Flutter build that forwards no -P.
        //
        // The *namespace* deliberately does not follow: it is where the Kotlin
        // classes and R actually live, and moving it would move them. That is
        // also why the widget is addressed by its fully qualified name from
        // Dart (see home_widget_service.dart) — the plugin's fallback builds
        // the class name out of the runtime package, which is this id.
        val sideBySide = (project.findProperty("pappusSideBySide") as String?).toBoolean()
        if (sideBySide) {
            applicationIdSuffix = ".ci"
        }
        manifestPlaceholders["appLabel"] = if (sideBySide) "Pappus CI" else "@string/app_name"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
