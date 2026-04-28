#!/bin/bash

# ╔══════════════════════════════════════════════════════════════╗
# ║         OmhcSilence Build APK - Setup Script               ║
# ║              Automated Environment Setup                   ║
# ╚══════════════════════════════════════════════════════════════╝

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║         OmhcSilence Build APK - Setup Script               ║"
echo "║              Automated Environment Setup                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}Warning: Running as root is not recommended${NC}"
   exit 1
fi

# System Update
echo -e "${YELLOW}[1/7] Updating system packages...${NC}"
sudo apt update -y && sudo apt upgrade -y

# Install essential packages
echo -e "${YELLOW}[2/7] Installing essential packages...${NC}"
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    zip \
    openjdk-17-jdk-headless \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libsqlite3-dev \
    libncurses5-dev \
    libbz2-dev \
    libffi-dev \
    liblzma-dev \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev

# Setup Java environment
echo -e "${YELLOW}[3/7] Configuring Java environment...${NC}"
sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java 2>/dev/null || true
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc

# Install Android SDK Command-line tools
echo -e "${YELLOW}[4/7] Installing Android SDK...${NC}"
mkdir -p ~/Android/Sdk/cmdline-tools
cd ~/Android/Sdk/cmdline-tools

# Download Android command line tools
wget https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O cmdline-tools.zip
unzip -o cmdline-tools.zip
mv cmdline-tools latest
rm cmdline-tools.zip

# Setup environment variables
export ANDROID_HOME=$HOME/Android/Sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=$PATH:$ANDROID_HOME/cmdline-tools/latest/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
export PATH=$PATH:$ANDROID_HOME/emulator

echo "export ANDROID_HOME=$HOME/Android/Sdk" >> ~/.bashrc
echo "export ANDROID_SDK_ROOT=$ANDROID_HOME" >> ~/.bashrc
echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin" >> ~/.bashrc
echo "export PATH=\$PATH:\$ANDROID_HOME/platform-tools" >> ~/.bashrc
echo "export PATH=\$PATH:\$ANDROID_HOME/emulator" >> ~/.bashrc

# Accept licenses
yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --licenses

# Install required Android SDK components
echo -e "${YELLOW}[5/7] Installing Android SDK components...${NC}"
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager \
    "platform-tools" \
    "platforms;android-34" \
    "build-tools;34.0.0" \
    "ndk;25.1.8937393" \
    "cmake;3.22.1"

# Install Flutter
echo -e "${YELLOW}[6/7] Installing Flutter SDK...${NC}"
cd ~
wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.19.6-stable.tar.xz
tar xf flutter_linux_3.19.6-stable.tar.xz
rm flutter_linux_3.19.6-stable.tar.xz

export PATH="$HOME/flutter/bin:$PATH"
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc

# Flutter doctor and setup
flutter config --no-analytics
flutter precache
flutter doctor --android-licenses

# Create workspace
echo -e "${YELLOW}[7/7] Creating workspace directory...${NC}"
mkdir -p ~/omhcsilence-workspace

echo -e "${GREEN}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                         ║"
echo "║         OmhcSilence Build APK is ready to use             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Please run: source ~/.bashrc${NC}"
echo -e "${YELLOW}Then run: flutter doctor -v${NC}"
