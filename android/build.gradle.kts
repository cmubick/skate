// Plugin versions live in gradle/libs.versions.toml. Each module applies the ones it needs.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}
