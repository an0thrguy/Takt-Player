import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) releasePropertiesFile.inputStream().use { releaseProperties.load(it) }

android {
    namespace = "dev.takt.takt"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "dev.takt.takt"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 36
        targetSdk = 36
        // Match Flutter's selected targets so unrelated plugin ABIs stay out of the APK.
        ndk {
            val targets = (project.findProperty("target-platform") as String?
                ?: "android-arm64").split(",")
            abiFilters.clear()
            abiFilters.addAll(targets.map { target ->
                when (target.trim()) {
                    "android-arm" -> "armeabi-v7a"
                    "android-x64" -> "x86_64"
                    else -> "arm64-v8a"
                }
            })
        }
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("taktRelease") {
            if (releasePropertiesFile.exists()) {
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            if (gradle.startParameter.taskNames.any { it.endsWith("Release", ignoreCase = true) }) {
                check(releasePropertiesFile.exists()) { "Create android/key.properties before building a release APK. See docs/install-android.md." }
            }
            signingConfig = signingConfigs.getByName("taktRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
