// The Android app. Kotlin support is built into the Android Gradle plugin.
// The game draws its own pixels on a plain Android View (as the iOS app does
// with SpriteKit), so there is no Compose here.
plugins {
    alias(libs.plugins.android.application)
}

// The upload key that signs Play Store builds. Never in the repository: where it
// is and its passwords come from ~/.gradle/gradle.properties (or environment
// variables of the same names), as android/README.md explains. Debug builds
// don't need it.
fun uploadSetting(name: String): String? =
    (findProperty(name) as String?)?.takeIf { it.isNotBlank() } ?: System.getenv(name)?.takeIf { it.isNotBlank() }

val uploadSettings = listOf(
    "SKATE_UPLOAD_STORE_FILE", "SKATE_UPLOAD_STORE_PASSWORD", "SKATE_UPLOAD_KEY_ALIAS", "SKATE_UPLOAD_KEY_PASSWORD",
).associateWith(::uploadSetting)
val hasUploadKey = uploadSettings.values.all { it != null }

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

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(uploadSettings.getValue("SKATE_UPLOAD_STORE_FILE")!!)
                storePassword = uploadSettings.getValue("SKATE_UPLOAD_STORE_PASSWORD")
                keyAlias = uploadSettings.getValue("SKATE_UPLOAD_KEY_ALIAS")
                keyPassword = uploadSettings.getValue("SKATE_UPLOAD_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            if (hasUploadKey) signingConfig = signingConfigs.getByName("upload")
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

// Without the upload key a release build comes out unsigned, which Google Play
// won't take: stop with a message saying what's missing instead.
tasks.configureEach {
    if (name == "bundleRelease" || name == "assembleRelease") {
        doFirst {
            val missing = uploadSettings.filterValues { it == null }.keys
            if (missing.isNotEmpty()) {
                throw GradleException(
                    "No upload key: add ${missing.joinToString(", ")} to ~/.gradle/gradle.properties (see android/README.md, Releasing on Google Play).",
                )
            }
        }
    }
}
