import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
}

// Load local.properties
val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        load(localPropertiesFile.inputStream())
    }
}

val flutterRoot = localProperties.getProperty("flutter.sdk") ?: System.getenv("FLUTTER_SDK")

if (flutterRoot == null) {
    throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file or with a FLUTTER_SDK environment variable.")
}

android {
    namespace = "com.example.navic"
    compileSdk = 34

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.navic"
        minSdk = 23
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
        multiDexEnabled = true
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
    }

    // Flutter specific configuration
    buildTypes {
        getByName("debug") {
            // TODO: Add your own signing config for the release build.
            // signingConfig = signingConfigs.getByName("debug")
        }
        getByName("release") {
            // TODO: Add your own signing config for the release build.
            // signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Enable view binding if needed (optional)
    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.navigation:navigation-fragment-ktx:2.7.6")
    implementation("androidx.navigation:navigation-ui-ktx:2.7.6")
    // Flutter dependencies are added by the Flutter plugin
}

// Apply the Flutter plugin
apply(from = "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle")