// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.example.test" // ให้ตรงกับ package ของ MainActivity.kt/Manifest
    compileSdk = 36 // ถ้า build ไม่ผ่านเพราะยังไม่ติดตั้ง 36 ให้ใช้ 34 ไปก่อน

    defaultConfig {
        applicationId = "com.example.test"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    // ผูก signing เฉพาะเมื่อมี key.properties
    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                // NOTE: ใน key.properties ให้ตั้ง storeFile=hereme.keystore (ไม่ต้องมี app/)
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
                storeType = "pkcs12" // <<< สำคัญสำหรับไฟล์ .keystore ที่เป็น PKCS12
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
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") { }
    }

    // JDK ที่ใช้รัน AGP ควรเป็น 17; ส่วน source/target 11 ใช้ได้
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions { jvmTarget = "11" }
}

flutter { source = "../.." }
