pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "Skate"

// The game rules: pure Kotlin, no Android. Ported from skate/Rules in the iOS app.
include(":rules")
// The Android app.
include(":app")
