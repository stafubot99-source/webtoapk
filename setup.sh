#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║       OmhcSilence Build APK - VPS Setup Script             ║
# ║       Optimized for Ubuntu/Debian VPS                       ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║           OmhcSilence Build APK v1.0                        ║"
echo "║           VPS Setup - Ubuntu/Debian                         ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# OS Detection
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
        OS_CODENAME=$VERSION_CODENAME
    else
        OS_NAME="unknown"
        OS_CODENAME="unknown"
    fi
}

detect_os

echo -e "${CYAN}Detected OS: ${GREEN}$OS_NAME $OS_VERSION ($OS_CODENAME)${NC}"
echo ""

# ============================================
# PART 1: System Update
# ============================================

echo -e "${MAGENTA}[1/8] Updating system packages...${NC}"
sudo apt update -y && sudo apt upgrade -y

# ============================================
# PART 2: Essential Packages
# ============================================

echo -e "${MAGENTA}[2/8] Installing essential packages...${NC}"
sudo apt install -y \
    curl wget git unzip zip xz-utils \
    build-essential clang cmake ninja-build \
    pkg-config libgtk-3-dev liblzma-dev \
    libglu1-mesa lib32z1 lib32stdc++6 \
    libreadline-dev libsqlite3-dev \
    libbz2-dev libffi-dev libncurses5-dev zlib1g-dev

# ============================================
# PART 3: Java 17 Installation
# ============================================

echo -e "${MAGENTA}[3/8] Installing Java 17...${NC}"

if [ "$OS_NAME" = "debian" ]; then
    echo -e "${YELLOW}  Debian detected - Installing Eclipse Temurin JDK 17...${NC}"
    
    sudo apt install -y wget apt-transport-https gnupg
    
    if [ ! -f /usr/share/keyrings/adoptium.gpg ]; then
        wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
            sudo gpg --dearmor -o /usr/share/keyrings/adoptium.gpg
    fi
    
    if [ ! -f /etc/apt/sources.list.d/adoptium.list ]; then
        echo "deb [signed-by=/usr/share/keyrings/adoptium.gpg] https://packages.adoptium.net/artifactory/deb $OS_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/adoptium.list
    fi
    
    sudo apt update
    sudo apt install -y temurin-17-jdk
    export JAVA_HOME=/usr/lib/jvm/temurin-17-jdk-amd64
else
    echo -e "${YELLOW}  Ubuntu detected - Installing OpenJDK 17...${NC}"
    sudo apt install -y openjdk-17-jdk openjdk-17-jdk-headless
    export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
fi

# Verify Java
if ! java -version &>/dev/null; then
    echo -e "${RED}ERROR: Java installation failed!${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Java: $(java -version 2>&1 | head -n1)${NC}"

# ============================================
# PART 4: Android SDK
# ============================================

echo -e "${MAGENTA}[4/8] Setting up Android SDK...${NC}"

ANDROID_HOME=/opt/android-sdk
sudo mkdir -p $ANDROID_HOME/cmdline-tools
cd $ANDROID_HOME/cmdline-tools

if [ ! -d "latest" ]; then
    echo -e "${YELLOW}  Downloading Android SDK Command Line Tools...${NC}"
    sudo wget -q --show-progress \
        "https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip" \
        -O tools.zip
    sudo unzip -q tools.zip
    
    if [ -d "cmdline-tools" ]; then
        sudo mv cmdline-tools latest
    fi
    sudo rm -f tools.zip
fi

sudo chmod -R 777 $ANDROID_HOME

export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools

# Accept licenses
echo -e "${YELLOW}  Accepting Android licenses...${NC}"
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses > /dev/null 2>&1 || true

# Install SDK components
echo -e "${YELLOW}  Installing SDK components (this may take a while)...${NC}"
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install \
    "platforms;android-34" \
    "platforms;android-35" \
    "build-tools;34.0.0" \
    "build-tools;35.0.0" \
    "platform-tools" \
    "ndk;25.1.8937393" \
    "cmake;3.22.1"

export ANDROID_NDK_HOME=$ANDROID_HOME/ndk/25.1.8937393
echo -e "${GREEN}  ✓ Android SDK installed${NC}"

# ============================================
# PART 5: Flutter SDK
# ============================================

echo -e "${MAGENTA}[5/8] Installing Flutter SDK...${NC}"
FLUTTER_HOME=/opt/flutter

if [ ! -d "$FLUTTER_HOME" ]; then
    echo -e "${YELLOW}  Downloading Flutter SDK...${NC}"
    cd /opt
    sudo git clone https://github.com/flutter/flutter.git -b stable --depth 1
    sudo chmod -R 777 $FLUTTER_HOME
fi

export PATH=$PATH:$FLUTTER_HOME/bin

# Pre-download dependencies
echo -e "${YELLOW}  Configuring Flutter...${NC}"
flutter config --no-analytics > /dev/null 2>&1
flutter precache --android > /dev/null 2>&1
yes | flutter doctor --android-licenses > /dev/null 2>&1

echo -e "${GREEN}  ✓ Flutter: $(flutter --version 2>&1 | head -n1 | awk '{print $2}')${NC}"

# ============================================
# PART 6: Node.js & PM2
# ============================================

echo -e "${MAGENTA}[6/8] Installing Node.js 20...${NC}"
if ! command -v node &> /dev/null || [[ $(node -v | cut -d. -f1 | tr -d 'v') -lt 18 ]]; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs
fi
echo -e "${GREEN}  ✓ Node.js: $(node -v)${NC}"
echo -e "${GREEN}  ✓ npm: v$(npm -v)${NC}"

echo -e "${MAGENTA}[7/8] Installing PM2...${NC}"
sudo npm install -g pm2
echo -e "${GREEN}  ✓ PM2 installed${NC}"

# ============================================
# PART 7: Environment Variables
# ============================================

echo -e "${MAGENTA}[8/8] Setting environment variables...${NC}"

# Clean old entries
sudo sed -i '/JAVA_HOME/d' /etc/environment 2>/dev/null || true
sudo sed -i '/ANDROID_HOME/d' /etc/environment 2>/dev/null || true
sudo sed -i '/ANDROID_SDK_ROOT/d' /etc/environment 2>/dev/null || true
sudo sed -i '/FLUTTER_HOME/d' /etc/environment 2>/dev/null || true
sudo sed -i '/ANDROID_NDK_HOME/d' /etc/environment 2>/dev/null || true

# Add new entries
echo "JAVA_HOME=$JAVA_HOME" | sudo tee -a /etc/environment > /dev/null
echo "ANDROID_HOME=$ANDROID_HOME" | sudo tee -a /etc/environment > /dev/null
echo "ANDROID_SDK_ROOT=$ANDROID_HOME" | sudo tee -a /etc/environment > /dev/null
echo "FLUTTER_HOME=$FLUTTER_HOME" | sudo tee -a /etc/environment > /dev/null
echo "ANDROID_NDK_HOME=$ANDROID_NDK_HOME" | sudo tee -a /etc/environment > /dev/null

# Add to bashrc
if ! grep -q "OmhcSilence Build APK" $HOME/.bashrc 2>/dev/null; then
    cat >> $HOME/.bashrc << 'EOF'

# ╔══════════════════════════════════════════════════════════════╗
# ║       OmhcSilence Build APK - Environment                  ║
# ╚══════════════════════════════════════════════════════════════╝
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export ANDROID_NDK_HOME=/opt/android-sdk/ndk/25.1.8937393
export FLUTTER_HOME=/opt/flutter
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$FLUTTER_HOME/bin
EOF
fi

# Create workspace
mkdir -p /root/omhcsilence-workspace/output

# ============================================
# COMPLETE
# ============================================

echo ""
echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                         ║"
echo "║                                                              ║"
echo "║  ✓ Java 17 installed                                       ║"
echo "║  ✓ Android SDK installed                                   ║"
echo "║  ✓ Flutter SDK installed                                   ║"
echo "║  ✓ Node.js & PM2 installed                                 ║"
echo "║  ✓ Environment configured                                  ║"
echo "║                                                              ║"
echo "║  Next step:                                                ║"
echo "║  source ~/.bashrc                                          ║"
echo "║  bash build.sh                                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${YELLOW}⚠ IMPORTANT: Run this command now:${NC}"
echo -e "${GREEN}  source ~/.bashrc${NC}"
echo ""
echo -e "${CYAN}Then you can start building APKs!${NC}"
