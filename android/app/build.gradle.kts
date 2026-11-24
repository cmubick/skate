// The Android app. Kotlin support is built into the Android Gradle plugin.
// The game draws its own pixels on a plain Android View (as the iOS app does
// with SpriteKit), so there is no Compose here.
plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.tuesdaygames.skate"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.tuesdaygames.skate"
        minSdk = 26
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }
}

dependencies {
    implementation(project(":rules"))

    implementation(libs.androidx.activity)
    implementation(libs.androidx.core.ktx)
    // Google Play's in-app purchases.
    implementation(libs.google.play.billing)

    testImplementation(libs.kotlin.test.junit)
}
