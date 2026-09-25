import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Keystore-Konfiguration laden
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.vibesbox.dj"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.vibesbox.dj"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // purchases_flutter 10.x / Play Billing Library 8.3+ erfordert API 23+
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = 36
        // Aus pubspec bzw. `flutter build --build-name` / `--build-number` (keine festen Werte!)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            val storeFilePath = keystoreProperties["storeFile"] as String
            storeFile = file(storeFilePath)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Minify/R8 AUS: 1.1.68/69 mit Minify → Abstürze + kaputte Musikerkennung (Android).
            // ShazamKit/Billing/Reflection — erst wieder an, wenn Keeps auf Gerät verifiziert.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")
}

dependencies {
    // Diese Zeile ist das Herzstück:
    implementation(files("libs/ShazamKit.aar"))
    
    // Standard-Kram, den du sicher schon hast:
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.9.0")
    
    // Retrofit-Abhängigkeiten für ShazamKit
    implementation("com.squareup.retrofit2:retrofit:2.9.0")
    implementation("com.squareup.retrofit2:converter-gson:2.9.0")
    implementation("com.squareup.okhttp3:logging-interceptor:4.11.0")
    
    // Google Play Billing Library 8+ (Play-Richtlinie; RevenueCat nutzt dieselbe Major)
    implementation("com.android.billingclient:billing:8.3.0")
    implementation("com.android.billingclient:billing-ktx:8.3.0")
    // Native RevenueCat-SDK kommt über purchases_flutter (purchases-hybrid-common / Billing 8).
}
