import org.gradle.api.tasks.Delete
import org.gradle.api.tasks.compile.JavaCompile // <-- ADD THIS IMPORT
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile // <-- ADD THIS IMPORT

plugins {
    // Google services plugin for Firebase
    id("com.google.gms.google-services") version "4.4.2" apply false
}

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // Android Gradle plugin
        classpath("com.android.tools.build:gradle:8.9.0")
        // Kotlin Gradle plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        // Google services
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// FIX: Explicitly set Java 17 compatibility for all Java compilation tasks
tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
}

// FIX: Explicitly set JVM target for all Kotlin compilation tasks
tasks.withType<KotlinCompile>().configureEach {
    kotlinOptions {
        jvmTarget = "17"
    }
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}