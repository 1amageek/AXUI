#!/bin/bash

# AXON Swift Package Build Script

echo "🔨 Building AXON Swift Package..."

# Build in release mode
swift build -c release

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo "📦 Executable created at: .build/release/axon"
    
    # Make executable accessible
    echo "📋 Copying executable to /usr/local/bin..."
    sudo rm -rf /usr/local/bin/axon
    sudo cp .build/release/axon /usr/local/bin/axon
    
    echo "🎉 AXON is ready to use!"
    echo "   Run: axon --help"
else
    echo "❌ Build failed!"
    exit 1
fi
