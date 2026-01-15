#!/bin/bash

# Focus App - Xcode Project Setup Script
# This script helps you create an Xcode project for the Focus app

echo "🚀 Focus App - Xcode Project Setup"
echo "=================================="
echo ""
echo "Follow these steps to create the Xcode project:"
echo ""
echo "1. Open Xcode"
echo "2. File → New → Project"
echo "3. Select 'App' under Multiplatform"
echo "4. Click Next"
echo ""
echo "5. Configure your project:"
echo "   - Product Name: Focus"
echo "   - Team: Select your team"
echo "   - Organization Identifier: com.focusproject"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Storage: None"
echo "   - ✓ Include Tests (optional)"
echo ""
echo "6. Click Next and save to: $(pwd)"
echo ""
echo "7. After creating, delete the auto-generated ContentView.swift and FocusApp.swift"
echo ""
echo "8. Drag the 'Focus/Sources' folder into your Xcode project"
echo "   - Select 'Create groups'"
echo "   - Add to targets: Focus"
echo ""
echo "9. In Xcode, go to the Focus target → Signing & Capabilities:"
echo "   - Add 'Push Notifications'"
echo "   - For macOS: Add 'App Sandbox' with 'Outgoing Connections (Client)'"
echo ""
echo "10. Build and Run! (Cmd+R)"
echo ""
echo "=================================="
echo "Project files are ready in: $(pwd)/Focus/Sources"
echo ""

# Check if Xcode is installed
if command -v xcodebuild &> /dev/null; then
    echo "✅ Xcode is installed"
    xcodebuild -version
else
    echo "❌ Xcode not found. Please install from App Store."
fi

echo ""
echo "Would you like to open the Sources folder in Finder? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    open "$(pwd)/Focus/Sources"
fi
