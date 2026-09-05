import java.io.File
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is supplied outside Git through android/key.properties
// (storeFile, storePassword, keyAlias, keyPassword) or through the
// ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS and
// ANDROID_KEY_PASSWORD environment variables. Release builds never fall back
// to the debug key: when no signing configuration exists, a requested release
// build fails with instructions instead of producing a debug-signed artifact.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

fun decodeEnvironmentKeystore(): File {
    val encodedKeystore = requireNotNull(System.getenv("ANDROID_KEYSTORE_BASE64"))
    val decodedKeystore = File.createTempFile("expert-listing-release", ".jks")
    try {
        decodedKeystore.writeBytes(Base64.getDecoder().decode(encodedKeystore))
    } catch (error: IllegalArgumentException) {
        throw GradleException("ANDROID_KEYSTORE_BASE64 is not valid base64 data.")
    }
    return decodedKeystore
}

data class ReleaseSigning(val storeFile: File, val storePassword: String, val keyAlias: String, val keyPassword: String)

val releaseSigning: ReleaseSigning? = when {
    keystorePropertiesFile.exists() -> {
        val storeFile = keystoreProperties.getProperty("storeFile")
        val storePassword = keystoreProperties.getProperty("storePassword")
        val keyAlias = keystoreProperties.getProperty("keyAlias")
        val keyPassword = keystoreProperties.getProperty("keyPassword")
        if (storeFile != null && storePassword != null && keyAlias != null && keyPassword != null) {
            ReleaseSigning(file(storeFile), storePassword, keyAlias, keyPassword)
        } else {
            null
        }
    }
    System.getenv("ANDROID_KEYSTORE_BASE64") != null -> {
        val storePassword = System.getenv("ANDROID_KEYSTORE_PASSWORD")
        val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
        val keyPassword = System.getenv("ANDROID_KEY_PASSWORD")
        if (storePassword != null && keyAlias != null && keyPassword != null) {
            ReleaseSigning(decodeEnvironmentKeystore(), storePassword, keyAlias, keyPassword)
        } else {
            null
        }
    }
    else -> null
}

// flutter invokes assembleRelease or bundleRelease for release builds, so
// detecting "release" in the requested tasks is how a release request is
// recognized while debug builds keep configuring normally.
val isReleaseBuildRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

android {
    namespace = "com.prnice.expert_listing"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.prnice.expert_listing"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    if (releaseSigning != null) {
        signingConfigs {
            create("release") {
                storeFile = releaseSigning.storeFile
                storePassword = releaseSigning.storePassword
                keyAlias = releaseSigning.keyAlias
                keyPassword = releaseSigning.keyPassword
            }
        }
    }

    buildTypes {
        release {
            val releaseSigningConfig = signingConfigs.findByName("release")
            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
            } else if (isReleaseBuildRequested) {
                throw GradleException(
                    "Release signing is not configured. Provide android/key.properties " +
                        "with storeFile, storePassword, keyAlias and keyPassword, or set the " +
                        "ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS " +
                        "and ANDROID_KEY_PASSWORD environment variables. Never commit the " +
                        "keystore or its passwords.",
                )
            }
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
