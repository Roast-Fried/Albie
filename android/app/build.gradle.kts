import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release signing 설정 — android/key.properties (gitignore 됨) 에서 읽음.
// key.properties 없으면 debug key 로 fallback (개발용 빌드).
// 출시 전 절차:
//   1) keytool -genkey -v -keystore android/app/upload-keystore.jks ...
//   2) android/key.properties 생성:
//      storeFile=upload-keystore.jks
//      storePassword=<password>
//      keyAlias=upload
//      keyPassword=<password>
//   3) android/.gitignore 에 key.properties / upload-keystore.jks 추가 (이미 .gitignore 권장)
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey: Boolean = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.roastfried.albi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 17.x 가 java.time API 사용 → core library
        // desugaring 필수 (CI build-android fail: "requires core library desugaring").
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.roastfried.albi"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // key.properties 가 있을 때만 release config 등록.
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // key.properties 있으면 release config, 없으면 debug fallback (개발 빌드).
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // isCoreLibraryDesugaringEnabled 와 짝 — desugared java.time 백포트 제공.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
