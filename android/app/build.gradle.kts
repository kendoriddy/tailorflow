plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: copy android/key.properties.example → key.properties (see docs/STORE_DEPLOYMENT.md).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}
val hasReleaseKeystore = keystorePropertiesFile.exists()

fun requireKeystoreProperty(name: String): String =
    (keystoreProperties[name] as String?)?.takeIf { it.isNotBlank() }
        ?: throw org.gradle.api.GradleException(
            "Missing '$name' in ${keystorePropertiesFile.path}. " +
                "Copy key.properties.example and fill in the release upload keystore values.",
        )

gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        it.name.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !hasReleaseKeystore) {
        throw org.gradle.api.GradleException(
            "Missing ${keystorePropertiesFile.path}. " +
                "Release builds must use the Play upload keystore; " +
                "copy key.properties.example to key.properties and fill it in.",
        )
    }
}

android {
    namespace = "ng.tailorflow.tailorflow_ng"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "ng.tailorflow.tailorflow_ng"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = requireKeystoreProperty("keyAlias")
                keyPassword = requireKeystoreProperty("keyPassword")
                storeFile = file(requireKeystoreProperty("storeFile"))
                storePassword = requireKeystoreProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
