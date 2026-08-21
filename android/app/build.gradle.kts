plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Whether to build the variant that installs beside a real install rather than
// over it. Read once here because both `defaultConfig` and `buildTypes` need
// it: the id and label are half the trick, the signing key is the other half.
// CI sets it by exporting ORG_GRADLE_PROJECT_pappusSideBySide=true, which is
// how a project property reaches Gradle through a Flutter build that forwards
// no -P.
val sideBySide = (project.findProperty("pappusSideBySide") as String?).toBoolean()

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
        // `flutter run` stay exactly what they were.
        //
        // The *namespace* deliberately does not follow: it is where the Kotlin
        // classes and R actually live, and moving it would move them. That is
        // also why the widget is addressed by its fully qualified name from
        // Dart (see home_widget_service.dart) — the plugin's fallback builds
        // the class name out of the runtime package, which is this id.
        if (sideBySide) {
            applicationIdSuffix = ".ci"
        }
        manifestPlaceholders["appLabel"] = if (sideBySide) "Pappus CI" else "@string/app_name"
        // The icon differs for the same reason the label does, and by the same
        // mechanism: a placeholder, because a Gradle property cannot bring a
        // resource source set with it the way a flavor would. Both icons
        // therefore live in `main` and the unused one rides along in a release
        // build -- a few tens of kilobytes, against a second flavor's cost of
        // making `--flavor` mandatory on every command.
        manifestPlaceholders["appIcon"] =
            if (sideBySide) "@mipmap/ic_launcher_ci" else "@mipmap/ic_launcher"
    }

    signingConfigs {
        // The key the side-by-side build is signed with, checked into the repo
        // on purpose.
        //
        // Android refuses to update an installed app whose signature does not
        // match, and `debug` is not one key but whichever one happens to be in
        // ~/.android/debug.keystore — a file AGP *generates* when it is
        // missing. Every CI runner is a fresh machine, so every run signed the
        // artifact with a new random key, and a tester who had installed the
        // APK from one pull request could only install the next by uninstalling
        // first. A key that lives in the repo is the same key on every runner
        // and on every fork, with no secret involved.
        //
        // The password is here in the open because hiding it would buy nothing:
        // the key it protects is in the same commit. What it does allow is
        // stated plainly — anyone can build an APK that Android accepts as an
        // update to `dev.calyptra.pappus.ci`, so a test install trusts anyone
        // who can hand you a file. What it does *not* allow is touching the
        // released app: that has a different applicationId and a different key,
        // and the two are separate installs with separate data directories.
        // This config is therefore only ever selected when `sideBySide` is on.
        create("ci") {
            storeFile = file("pappus-ci.jks")
            storePassword = "pappus-ci"
            keyAlias = "pappus-ci"
            keyPassword = "pappus-ci"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig =
                if (sideBySide) {
                    signingConfigs.getByName("ci")
                } else {
                    signingConfigs.getByName("debug")
                }
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
