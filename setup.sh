#!/bin/bash
# Gin setup — generates the Xcode project with XcodeGen.
set -e

cd "$(dirname "$0")"

if ! command -v xcodegen &> /dev/null; then
    echo "Installing XcodeGen..."
    brew install xcodegen
fi

# Signing is kept out of the repo — a Team ID identifies whoever owns it.
if [ ! -f Signing.xcconfig ]; then
    cp Signing.xcconfig.example Signing.xcconfig
    echo "Created Signing.xcconfig. Add your Apple Development Team ID to it if"
    echo "you want to run on a physical iPad; the Simulator needs nothing."
fi

xcodegen generate

echo ""
echo "✅ Project generated: Gin.xcodeproj"
echo ""
echo "Next steps:"
echo "  1. Open Gin.xcodeproj in Xcode"
echo "  2. Choose an iPad simulator (landscape) and run"
echo ""
