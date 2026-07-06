plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.uddoygi"

    compileSdk = 36

    defaultConfig {
        applicationId = "com.example.uddoygi"
        minSdk = flutter.minSdkVersion // Firebase Phone Auth requires at least 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    // (Optional) Configure build types; keep debug signing for local builds
    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("release") {
            // Turn both ON together
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }


    // Java 17 + desugaring
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // Kotlin 17
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // (Optional) Packaging tweaks if you hit duplicate files
    // packaging {
    //     resources {
    //         excludes += "/META-INF/{AL2.0,LGPL2.1}"
    //     }
    // }
}

dependencies {
    // Core library desugaring (required when using Java 8+ APIs on lower minsdk)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // ML Kit text recognition — Latin script (used by document extractor).
    // Declaring this explicitly gives R8 the real classes so the release build
    // does not fail with "Missing class" errors for the recogniser options.
    implementation("com.google.mlkit:text-recognition:16.0.1")
}

flutter {
    source = "../.."
}
