plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.callsos.app"

    // F.6 — NOTA sobre compileSdk:
    // flutter.compileSdkVersion resuelve al SDK definido por el plugin de
    // Flutter Gradle (actualmente 35 en Flutter 3.24+). Si tu versión de
    // Flutter resuelve a un valor < 34, reemplaza esta línea por:
    //   compileSdk = 35
    // ya que POST_NOTIFICATIONS (Android 13 / API 33) y
    // flutter_local_notifications requieren compileSdk >= 34.
    // Verificar con: `flutter doctor -v` → "Android SDK Build-Tools".
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.callsos.app"
        // F.6 — minSdk y targetSdk:
        // flutter.minSdkVersion es 21 por defecto (Android 5.0+).
        // flutter.targetSdkVersion es 34+ en Flutter 3.22+.
        //
        // POST_NOTIFICATIONS (API 33) solo se solicita en tiempo de
        // ejecución en dispositivos con Android 13+; en versiones anteriores
        // se ignora automáticamente — no rompe compatibilidad hacia atrás.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))
    implementation("com.google.firebase:firebase-analytics")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}