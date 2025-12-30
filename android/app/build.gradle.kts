plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.test_flutter"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.test_flutter"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // 修复资源链接问题
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    // 确保所有依赖使用兼容的版本（支持 Android 15）
    configurations.all {
        resolutionStrategy {
            // 使用更新的版本以支持 Android 15 的手写输入功能
            force("androidx.core:core:1.16.0")
            force("androidx.core:core-ktx:1.16.0")
        }
    }
}

flutter {
    source = "../.."
}

// 禁用所有插件的资源验证任务（解决 image_gallery_saver 的 lStar 问题）
tasks.matching { 
    it.name.contains("verifyReleaseResources") || 
    it.name.contains("verifyDebugResources")
}.configureEach {
    enabled = false
}

// 为所有子项目禁用资源验证
subprojects {
    afterEvaluate {
        tasks.matching { 
            it.name.contains("verifyReleaseResources") || 
            it.name.contains("verifyDebugResources")
        }.configureEach {
            enabled = false
        }
    }
}
