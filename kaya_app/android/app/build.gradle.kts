plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
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

        /*
            No Google client id is declared here.

            A manifestPlaceholder named googleClientId used to be set to a
            different client id from the one the app actually signs in with,
            and nothing in AndroidManifest.xml ever referenced it — so it
            configured nothing while looking authoritative, which is worse than
            absent when someone is debugging a sign-in failure.

            google_sign_in needs no client id in the manifest on Android. It
            identifies the app by its package name and signing certificate,
            registered against the Android OAuth client in Google Cloud, and
            takes the *web* client id at runtime as serverClientId so the ID
            token is minted for the backend to verify.
        */
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
