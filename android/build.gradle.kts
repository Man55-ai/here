// android/build.gradle.kts (Project-level)

plugins {
    id("com.android.application") apply false   // ใช้เวอร์ชันที่มากับ Flutter
    id("com.android.library") apply false       // ใช้เวอร์ชันที่มากับ Flutter
    id("org.jetbrains.kotlin.android") apply false // ใช้เวอร์ชันที่มากับ Flutter (2.1.0)
    id("dev.flutter.flutter-gradle-plugin") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = file("../build")

subprojects {
    project.buildDir = file("${rootProject.buildDir}/${project.name}")
    project.evaluationDependsOn(":app")
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}
