#!/usr/bin/env bash
set -euo pipefail

echo "==> SD Card Import Assistant — Project Setup"

# Verify Homebrew
if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Verify XcodeGen
if ! command -v xcodegen &>/dev/null; then
  echo "  Installing XcodeGen..."
  brew install xcodegen
fi

# Generate Xcode project from project.yml
echo "  Generating SDCardImportAssistant.xcodeproj..."
xcodegen generate

echo ""
echo "Done. Open SDCardImportAssistant.xcodeproj to build and run."
