#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║         OmhcSilence Build APK - Builder Script             ║
# ║              Web to APK Converter                           ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/home/$USER/omhcsilence-workspace"
OUTPUT_DIR="$WORKSPACE_DIR/output"
TEMPLATE_DIR="$(dirname "$0")/template"
BUILD_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           OmhcSilence Build APK v1.0                        ║"
    echo "║           Web to APK Converter                              ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check environment
check_environment() {
    echo -e "${YELLOW}[*] Checking environment...${NC}"
    
    # Check Flutter
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}[✗] Flutter not found. Please run setup.sh first${NC}"
        exit 1
    fi
    
    # Check Java
    if ! command -v java &> /dev/null; then
        echo -e "${RED}[✗] Java not found${NC}"
        exit 1
    fi
    
    # Check Android SDK
    if [ ! -d "$ANDROID_HOME" ]; then
        echo -e "${RED}[✗] Android SDK not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Environment check passed${NC}"
}

# Validate URL
validate_url() {
    local url=$1
    if [[ $url =~ ^https?:// ]]; then
        return 0
    else
        return 1
    fi
}

# Generate app name from URL
generate_app_name() {
    local url=$1
    local domain=$(echo "$url" | sed -e 's|https\?://||' -e 's|www\.||' -e 's|/.*||' -e 's|\..*||')
    echo "OmhcSilence_${domain}"
}

# Create Flutter project from template
create_project() {
    local url=$1
    local app_name=$2
    local build_dir="$WORKSPACE_DIR/${app_name}_${BUILD_TIMESTAMP}"
    
    echo -e "${YELLOW}[*] Creating project: $app_name${NC}"
    
    # Create Flutter project
    mkdir -p "$build_dir"
    cd "$WORKSPACE_DIR"
    flutter create --org com.omhcsilence --project-name "$app_name" "$build_dir" --platforms android
    
    # Copy template files
    cp "$TEMPLATE_DIR/pubspec.yaml" "$build_dir/"
    cp "$TEMPLATE_DIR/lib/main.dart" "$build_dir/lib/"
    cp "$TEMPLATE_DIR/android/app/src/main/AndroidManifest.xml" "$build_dir/android/app/src/main/"
    
    # Replace URL placeholder
    sed -i "s|WEBVIEW_URL_PLACEHOLDER|$url|g" "$build_dir/lib/main.dart"
    
    # Create assets directory
    mkdir -p "$build_dir/assets"
    
    # Create network security config
    mkdir -p "$build_dir/android/app/src/main/res/xml"
    cat > "$build_dir/android/app/src/main/res/xml/network_security_config.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>
</network-security-config>
EOF
    
    # Update Android build.gradle for better performance
    cat > "$build_dir/android/app/build.gradle" <<'EOF'
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    namespace "com.omhcsilence.webview"
    compileSdkVersion 34
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
        coreLibraryDesugaringEnabled true
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.omhcsilence.webview"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
    }

    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            ndk {
                abiFilters 'armeabi-v7a', 'arm64-v8a', 'x86_64'
            }
        }
        debug {
            debuggable true
            minifyEnabled false
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:1.2.2'
    implementation 'androidx.core:core-ktx:1.12.0'
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'com.google.android.material:material:1.11.0'
}
EOF
    
    # Create ProGuard rules
    cat > "$build_dir/android/app/proguard-rules.pro" <<'EOF'
# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# WebView
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**

# InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception
EOF
    
    # Update project-level build.gradle
    cat > "$build_dir/android/build.gradle" <<'EOF'
buildscript {
    ext.kotlin_version = '1.9.22'
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:8.2.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.buildDir = '../build'
subprojects {
    project.buildDir = "${rootProject.buildDir}/${project.name}"
}
subprojects {
    project.evaluationDependsOn(':app')
}

tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
EOF
    
    # Update gradle properties
    cat > "$build_dir/android/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx4G -XX:+HeapDumpOnOutOfMemoryError
android.useAndroidX=true
android.enableJetifier=true
android.enableR8.fullMode=true
EOF
    
    echo -e "${GREEN}[✓] Project created successfully${NC}"
    echo "$build_dir"
}

# Build APK
build_apk() {
    local build_dir=$1
    local app_name=$2
    
    echo -e "${YELLOW}[*] Building APK (this may take 5-10 minutes)...${NC}"
    
    cd "$build_dir"
    
    # Get dependencies
    echo -e "${CYAN}[+] Installing dependencies...${NC}"
    flutter pub get
    
    # Enable webview
    echo -e "${CYAN}[+] Configuring Android...${NC}"
    
    # Clean build
    echo -e "${CYAN}[+] Cleaning previous builds...${NC}"
    flutter clean
    
    # Build APK
    echo -e "${CYAN}[+] Building release APK...${NC}"
    flutter build apk --release --target-platform android-arm64 --split-per-abi
    
    # Check if build was successful
    if [ -f "$build_dir/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" ]; then
        # Copy APK to output directory
        mkdir -p "$OUTPUT_DIR"
        cp "$build_dir/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk" \
           "$OUTPUT_DIR/OmhcSilence_${app_name}_${BUILD_TIMESTAMP}.apk"
        
        # Get APK size
        APK_SIZE=$(du -h "$OUTPUT_DIR/OmhcSilence_${app_name}_${BUILD_TIMESTAMP}.apk" | cut -f1)
        
        echo -e "${GREEN}"
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║                    Build Complete!                          ║"
        echo "╠══════════════════════════════════════════════════════════════╣"
        echo "║  APK: OmhcSilence_${app_name}_${BUILD_TIMESTAMP}.apk"
        echo "║  Size: $APK_SIZE"
        echo "║  Location: $OUTPUT_DIR"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo -e "${NC}"
        
        return 0
    else
        echo -e "${RED}[✗] Build failed${NC}"
        return 1
    fi
}

# Main function
main() {
    show_banner
    check_environment
    
    echo -e "${CYAN}"
    echo "Enter the website URL to convert to APK:"
    echo -e "Example: https://example.com${NC}"
    read -p "URL: " WEBSITE_URL
    
    # Validate URL
    if ! validate_url "$WEBSITE_URL"; then
        echo -e "${RED}[✗] Invalid URL format. Please include http:// or https://${NC}"
        exit 1
    fi
    
    # Generate app name
    APP_NAME=$(generate_app_name "$WEBSITE_URL")
    echo -e "${CYAN}App Name: $APP_NAME${NC}"
    
    # Confirm
    echo -e "\n${YELLOW}Build Configuration:${NC}"
    echo -e "  URL: ${GREEN}$WEBSITE_URL${NC}"
    echo -e "  App Name: ${GREEN}$APP_NAME${NC}"
    echo -e "  Output: ${GREEN}$OUTPUT_DIR${NC}"
    echo ""
    read -p "Continue? (y/n): " CONFIRM
    
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        echo -e "${RED}Build cancelled${NC}"
        exit 0
    fi
    
    # Create project
    BUILD_DIR=$(create_project "$WEBSITE_URL" "$APP_NAME")
    
    # Build APK
    build_apk "$BUILD_DIR" "$APP_NAME"
    
    # Cleanup
    echo -e "${YELLOW}[*] Cleaning up build files...${NC}"
    rm -rf "$BUILD_DIR"
    
    echo -e "${GREEN}[✓] Process complete!${NC}"
    echo -e "${YELLOW}Your APK is ready in: $OUTPUT_DIR${NC}"
}

# Run main
main
