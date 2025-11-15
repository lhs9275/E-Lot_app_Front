import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val envFile = listOf(
    // Flutter 프로젝트 루트에 있는 .env 사용 (android/ 한 단계 위)
    rootProject.file("../.env"),
    // 혹시 모듈 내부에 별도 .env가 있는 경우 대비
    rootProject.file(".env")
).firstOrNull { it.exists() } ?: rootProject.file("../.env")
val envProps = Properties().apply {
    if (envFile.exists()) {
        envFile.inputStream().use { load(it) }
    }
}
val kakaoNativeAppKey = envProps.getProperty("KAKAO_NATIVE_APP_KEY")?.trim().orEmpty()

if (kakaoNativeAppKey.isBlank()) {
    logger.warn("KAKAO_NATIVE_APP_KEY is missing in .env; Kakao redirect scheme will be empty.")
}

android {
    namespace = "kr.clos21.psp2fn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        create("sharedDebug") {
            storeFile = file("keystore/shared-debug.keystore")
            storePassword = "psp2fnShared"
            keyAlias = "shareddebug"
            keyPassword = "psp2fnShared"
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "kr.clos21.psp2fn"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        resValue("string", "kakao_scheme", "kakao$kakaoNativeAppKey")
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("sharedDebug")
        }
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("sharedDebug")
        }
    }
}

flutter {
    source = "../.."
}
