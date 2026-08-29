import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

val releaseSigningKeys = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
)
val releaseStoreFile = keystoreProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let(rootProject::file)
val hasReleaseSigning = releaseSigningKeys.all { key ->
    !keystoreProperties.getProperty(key).isNullOrBlank()
} && releaseStoreFile?.isFile == true
if (keystorePropertiesFile.exists() && !hasReleaseSigning) {
    throw GradleException(
        "android/keystore.properties must define keyAlias, keyPassword, storeFile, " +
            "storePassword and point storeFile to an existing keystore",
    )
}

val allowUnsignedRelease = providers.gradleProperty("allowUnsignedRelease")
    .map(String::toBoolean)
    .orElse(false)
    .get()
val isCi = providers.environmentVariable("CI")
    .map { value ->
        value.trim().lowercase() in setOf("true", "1", "yes", "on")
    }
    .orElse(false)
    .get()
if (isCi && allowUnsignedRelease) {
    throw GradleException(
        "allowUnsignedRelease=true is forbidden when CI=true; configure Android release signing instead",
    )
}
val releaseSigningError =
    "Release signing is not configured. Add android/keystore.properties for a distributable build, " +
        "or pass --android-project-arg=allowUnsignedRelease=true only for local non-distribution builds. " +
        "CI builds must always provide a keystore."

android {
    namespace = "com.threelines.three_lines"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.threelines.three_lines"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

val validateReleaseSigning = tasks.register("validateReleaseSigning") {
    doLast {
        if (!hasReleaseSigning && !allowUnsignedRelease) {
            throw GradleException(releaseSigningError)
        }
    }
}

// Attach validation to the release lifecycle so aggregate `assemble`/`build` tasks
// cannot produce an unsigned release artifact by omitting "Release" in taskNames.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(validateReleaseSigning)
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
