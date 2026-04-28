#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║       OmhcSilence Build APK - Builder Script               ║
# ║       Convert Any Website to Android APK                    ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'

# Configuration
WORKSPACE_DIR="/root/omhcsilence-workspace"
OUTPUT_DIR="$WORKSPACE_DIR/output"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/template"
BUILD_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Banner
show_banner() {
    clear
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║           OmhcSilence Build APK v1.0                        ║"
    echo "║           Web to APK Converter                              ║"
    echo "║           By OmhcSilence Team                               ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check environment
check_environment() {
    echo -e "${YELLOW}[*] Checking environment...${NC}"
    
    local errors=0
    
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}  ✗ Flutter not found${NC}"
        errors=$((errors + 1))
    fi
    
    if ! command -v java &> /dev/null; then
        echo -e "${RED}  ✗ Java not found${NC}"
        errors=$((errors + 1))
    fi
    
    if [ ! -d "$ANDROID_HOME" ]; then
        echo -e "${RED}  ✗ Android SDK not found${NC}"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}[✗] Environment check failed. Run setup.sh first${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[✓] Environment ready${NC}"
    echo ""
}

# Validate URL
validate_url() {
    local url=$1
    if [[ $url =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# Generate app name from URL
generate_app_name() {
    local url=$1
    local domain=$(echo "$url" | sed -e 's|https\?://||' -e 's|www\.||' -e 's|/.*||' -e 's|\..*||' -e 's/[^a-zA-Z0-9]/_/g')
    echo "OmhcSilence_${domain}"
}

# Show progress animation
show_progress() {
    local pid=$1
    local message=$2
    local spin='-\|/'
    local i=0
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 4 ))
        printf "\r${CYAN}[%c] %s...${NC}" "${spin:$i:1}" "$message"
        sleep 0.1
    done
    printf "\r${GREEN}[✓] %s - Done!${NC}\n" "$message"
}

# Create Flutter project
create_project() {
    local url=$1
    local app_name=$2
    local build_dir="$WORKSPACE_DIR/builds/${app_name}_${BUILD_TIMESTAMP}"
    
    echo -e "${YELLOW}[*] Creating project...${NC}"
    echo -e "${CYAN}  • App Name: ${WHITE}$app_name${NC}"
    echo -e "${CYAN}  • URL: ${WHITE}$url${NC}"
    echo -e "${CYAN}  • Build ID: ${WHITE}$BUILD_TIMESTAMP${NC}"
    echo ""
    
    mkdir -p "$build_dir"
    cd "$WORKSPACE_DIR"
    
    # Create Flutter project
    echo -e "${CYAN}[+] Generating Flutter project...${NC}"
    flutter create \
        --org com.omhcsilence \
        --project-name "$app_name" \
        --platforms android \
        "$build_dir" > /dev/null 2>&1 &
    show_progress $! "Creating Flutter project"
    
    # Copy template files
    echo -e "${CYAN}[+] Applying WebView template...${NC}"
    
    # Copy pubspec.yaml
    cp "$TEMPLATE_DIR/pubspec.yaml" "$build_dir/pubspec.yaml"
    
    # Copy main.dart with URL replacement
    sed "s|WEBVIEW_URL_PLACEHOLDER|$url|g" \
        "$TEMPLATE_DIR/lib/main.dart" > \
        "$build_dir/lib/main.dart"
    
    # Copy AndroidManifest.xml
    cp "$TEMPLATE_DIR/android/app/src/main/AndroidManifest.xml" \
       "$build_dir/android/app/src/main/AndroidManifest.xml"
    
    # Create assets directory
    mkdir -p "$build_dir/assets"
    
    # Create network security config
    mkdir -p "$build_dir/android/app/src/main/res/xml"
    cp "$TEMPLATE_DIR/android/app/src/main/res/xml/network_security_config.xml" \
       "$build_dir/android/app/src/main/res/xml/"
    
    # Create optimized build.gradle
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
    throw new GradleException("Flutter SDK not found.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode') ?: '1'
def flutterVersionName = localProperties.getProperty('flutter.versionName') ?: '1.0'

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

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

    defaultConfig {
        applicationId "com.omhcsilence.webview"
        minSdkVersion 21
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
        multiDexEnabled true
        testInstrumentationRunner "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
            ndk {
                abiFilters 'arm64-v8a'
            }
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:1.2.2'
    testImplementation 'junit:junit:4.13.2'
    androidTestImplementation 'androidx.test.ext:junit:1.1.5'
    androidTestImplementation 'androidx.test.espresso:espresso-core:3.5.1'
}
EOF
    
    # Create ProGuard rules
    cat > "$build_dir/android/app/proguard-rules.pro" <<'EOF'
# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# InAppWebView
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }
-keep class com.pichillilorenzo.flutter_inappwebview_android.** { *; }

# WebView
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**

# General
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep class * extends java.lang.Exception { *; }
