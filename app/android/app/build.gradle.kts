import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: crea android/key.properties (ver README) con
// storeFile, storePassword, keyAlias y keyPassword. No se sube al repositorio.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

// El AAB para Google Play nunca debe firmarse con la clave de depuración.
// (Un APK release de prueba sí puede: `flutter build apk --release`.)
if (!keystoreProperties.containsKey("storeFile") &&
    gradle.startParameter.taskNames.any { it.contains("bundleRelease", ignoreCase = true) }
) {
    throw GradleException(
        "Falta android/key.properties: no se puede generar el AAB de Google Play sin la clave de firma (ver README)."
    )
}

android {
    namespace = "com.conexfor.ally"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Requerido por flutter_local_notifications.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Identificador en Google Play: no se puede cambiar después de publicar.
        applicationId = "com.conexfor.ally"
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        // Dominio de los enlaces https (invitaciones, recuperar contraseña,
        // verificar correo). Configúralo en android/gradle.properties:
        //   ally.appLinkHost=api.tu-dominio.com
        manifestPlaceholders["appLinkHost"] =
            (project.findProperty("ally.appLinkHost") as String?) ?: "ally.invalid"
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.containsKey("storeFile")) {
                signingConfigs.getByName("release")
            } else {
                // Sin key.properties se firma con la clave de depuración (solo pruebas).
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Temas AppCompat (requeridos por local_auth en Android 8 y anteriores).
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Detección de «Hey Ally» con openWakeWord (voice/WakeWordDetector.kt).
    implementation("com.microsoft.onnxruntime:onnxruntime-android:1.20.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
