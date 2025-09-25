// android/app/build.gradle.kts
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// โหลด key.properties (ถ้ามี)
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(keystorePropertiesFile.inputStream())
    }
}

android {
    namespace = "com.example.hereme"

    // ใช้ SDK 36 + Build-Tools 36.0.0 (ตัว stable)
    compileSdk = 36
    buildToolsVersion = "36.0.0"

    defaultConfig {
        applicationId = "com.example.hereme"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    // ✅ ต้องอยู่ "ใน" android { } เสมอ
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            // ถ้าไม่มีไฟล์ proguard-rules.pro ให้สร้างไฟล์ว่างๆ ใน app/
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") { /* ค่าดีฟอลต์พอแล้ว */ }
    }

    // กันชนกรณี libaosl.so ซ้ำจาก Agora
    packaging {
        jniLibs {
            pickFirsts += listOf("**/libaosl.so")
        }
    }

    // ใช้ JDK 17 สำหรับคอมไพล์ (JBR 21 ใช้รัน Gradle ได้ ไม่ขัดกัน)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

// dependencies {} ปล่อยว่างได้ (Flutter จัดการเอง)
