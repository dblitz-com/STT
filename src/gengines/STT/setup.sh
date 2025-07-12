#!/bin/bash

set -e

echo "🎤 STT Setup Script"
echo "==================="

# Check for macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This script is for macOS only"
    exit 1
fi

# Check for Apple Silicon
if [[ $(uname -m) != "arm64" ]]; then
    echo "❌ Error: This requires Apple Silicon (M1/M2/M3)"
    exit 1
fi

# Check for Homebrew
if ! command -v brew &> /dev/null; then
    echo "📦 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "🛠️  Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please complete the installation and run this script again."
    exit 1
fi

echo "📦 Installing dependencies..."

# Install Swift dependencies
if ! command -v swift-format &> /dev/null; then
    echo "Installing swift-format..."
    brew install swift-format
fi

if ! command -v swiftlint &> /dev/null; then
    echo "Installing swiftlint..."
    brew install swiftlint
fi

# Clone WhisperKit if not exists
if [ ! -d "WhisperKit" ]; then
    echo "📥 Cloning WhisperKit..."
    git clone https://github.com/argmaxinc/WhisperKit.git
fi

# Download model
echo "🤖 Downloading Whisper large-v3-turbo model..."
cd WhisperKit
if [ ! -d "Models/whisperkit-coreml/openai_whisper-large-v3-turbo" ]; then
    make download-model MODEL=openai_whisper-large-v3-turbo
fi
cd ..

# Create Swift Package
if [ ! -f "Package.swift" ]; then
    echo "📦 Creating Swift Package..."
    cat > Package.swift << 'EOF'
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "STTDictate",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.7.2")
    ],
    targets: [
        .executableTarget(
            name: "STTDictate",
            dependencies: [
                .product(name: "WhisperKit", package: "WhisperKit")
            ],
            path: "Sources"
        )
    ]
)
EOF
fi

# Create Sources directory
mkdir -p Sources

echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Run 'swift run STTDictate' to test the dictation"
echo "2. Run './install-service.sh' to install as background service"