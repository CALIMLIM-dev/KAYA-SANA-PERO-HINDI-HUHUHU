plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/*
    Firebase, only once it exists.

    The google-services plugin fails the build outright when
    android/app/google-services.json is missing, so applying it unconditionally
    would break every build until someone creates a Firebase project — including
    for anyone who never touches push notifications.

    Applied conditionally instead: without the file the app builds and runs
    exactly as before, and FcmService reports push as unavailable. Drop the file
    in and push starts working with no further edits here.
*/
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.alphatech.kaya_app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        /*
            Required by flutter_local_notifications, which the background
            service uses to raise a notification while the app is closed.

            The plugin calls java.time APIs that do not exist on older Android
            versions. Desugaring rewrites them at build time so they work on
            every version this app supports, rather than forcing minSdk up and
            dropping older phones — which matters here, since the cheaper
            handsets this is aimed at are the ones on older Android.
        */
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.alphatech.kaya_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Google Sign-In OAuth Client ID
        manifestPlaceholders["googleClientId"] = "217067120890-b5p9b0lkath30n40ph3ii14gamnk1oom.apps.googleusercontent.com"
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

dependencies {
    // The desugaring library itself, enabled in compileOptions above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
