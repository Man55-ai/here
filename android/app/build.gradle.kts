// android/app/build.gradle.kts
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ต้องตรงกับ package ใน MainActivity.kt
    namespace = "com.example.test"

    // ถ้าเครื่องคุณมี Android SDK 36 แล้ว ใช้ 36 ได้
    // ถ้า build เจอ error ว่าไม่มี android-36 ให้เปลี่ยนเป็น 34 แทน
    compileSdk = 36

    defaultConfig {
        // ตัวระบุแอปตอนติดตั้งเครื่อง
        applicationId = "com.example.test"

        // ปล่อยให้ Flutter กำหนดขั้นต่ำ (ปัจจุบันคือ 21)
        minSdk = flutter.minSdkVersion

        // เป้าหมาย API — ถ้าเครื่องไม่มี 36 ให้ลดเป็น 34
        targetSdk = 36

        // เวอร์ชันแอป
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        getByName("release") {
            // ปิด shrink/minify ในช่วงพัฒนา
            isMinifyEnabled = false
            isShrinkResources = false

            // ใช้ debug keystore เซ็นเพื่อทดสอบ (พอจะปล่อยจริงค่อยตั้ง signingConfig ของ release เอง)
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("debug") {
            // ตั้งค่าเฉพาะ debug ได้ตามต้องการ
        }
    }

    // ใช้ Java 11 เพื่อตัด warning เก่า (source/target 8 obsolete)
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    // path ไปยังโฟลเดอร์โปรเจกต์ Flutter
    source = "../.."
}
