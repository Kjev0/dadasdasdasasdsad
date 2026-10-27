import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// Release signing
//
// Resolved in this order (see docs/platform/ANDROID.md, "Signing"):
//   1. android/key.properties (gitignored; template: android/key.properties.example)
//      with storeFile, storePassword, keyAlias, keyPassword. A relative storeFile
//      is resolved against the android/ directory.
//   2. Environment variables FERMATA_KEYSTORE_PATH, FERMATA_KEYSTORE_PASSWORD,
//      FERMATA_KEY_ALIAS, FERMATA_KEY_PASSWORD (CI).
//   3. Neither present: release builds are signed with the DEBUG key so that
//      `flutter build apk --release` still produces an installable APK, and a
//      warning is printed. Such an APK cannot later be updated in place by a
//      properly signed one (signature mismatch: uninstall first).
// A partial configuration (some values missing, or keystore file not found) is a
// hard error, so a misconfigured release is never silently debug-signed.
// ---------------------------------------------------------------------------
class ReleaseSigning(
    val storeFile: File,
    val storePassword: String,
    val keyAlias: String,
    val keyPassword: String,
    val source: String,
)

fun loadReleaseSigning(): ReleaseSigning? {
    val keyPropertiesFile = rootProject.file("key.properties")
    val values: Map<String, String?>
    val source: String
    if (keyPropertiesFile.isFile) {
        val properties = Properties()
        keyPropertiesFile.inputStream().use { properties.load(it) }
        source = "android/key.properties"
        values = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .associateWith { properties.getProperty(it) }
    } else {
        source = "FERMATA_KEYSTORE_* environment variables"
        values = listOf(
            "FERMATA_KEYSTORE_PATH",
            "FERMATA_KEYSTORE_PASSWORD",
            "FERMATA_KEY_ALIAS",
            "FERMATA_KEY_PASSWORD",
        ).associateWith { providers.environmentVariable(it).orNull }
        if (values.values.all { it.isNullOrBlank() }) return null
    }

    val missing = values.filterValues { it.isNullOrBlank() }.keys
    if (missing.isNotEmpty()) {
        throw GradleException(
            "Incomplete release signing configuration in $source: missing " +
                "${missing.joinToString()}. See android/key.properties.example " +
                "and docs/platform/ANDROID.md."
        )
    }
    val (storePath, storePassword, keyAlias, keyPassword) = values.values.map { it!! }
    val storeFile = rootProject.file(storePath.trim())
    if (!storeFile.isFile) {
        throw GradleException("Release keystore not found: $storeFile (configured in $source).")
    }
    return ReleaseSigning(storeFile, storePassword, keyAlias.trim(), keyPassword, source)
}

val releaseSigning = loadReleaseSigning()
val isReleaseBuildRequested =
    gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseSigning == null && isReleaseBuildRequested) {
    // logger.error rather than logger.warn: `flutter build` runs Gradle with -q,
    // which hides warn/lifecycle output (the Flutter Gradle plugin reports its own
    // configuration warnings the same way). It does not fail the build.
    logger.error(
        """
        |WARNING: No release signing configuration found (android/key.properties or
        |FERMATA_KEYSTORE_* environment variables). The release build will be signed
        |with the DEBUG key. Fine for local testing, NOT for distribution.
        |See docs/platform/ANDROID.md, "Signing".
        """.trimMargin()
    )
}

android {
    namespace = "app.fermata.player"
    // compileSdk only decides which APIs are visible at compile time; runtime
    // behaviour follows targetSdk (36). 37 is required: permission_handler_android
    // 14.1.0 declares minCompileSdk 37 in its AAR metadata (checkAarMetadata fails
    // with 36).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.fermata.player"
        // 24 is the highest minimum among the plugins in use (app_links,
        // audio_session, flutter_secure_storage, permission_handler_android,
        // shared_preferences_android, url_launcher_android all require 24).
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigning != null) {
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
            signingConfig =
                if (releaseSigning != null) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
            // R8 (code shrinking + obfuscation) and resource shrinking. The Flutter
            // Gradle plugin registers proguard-android-optimize.txt,
            // flutter_proguard_rules.pro and this module's proguard-rules.pro.
            isMinifyEnabled = true
            isShrinkResources = true
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
