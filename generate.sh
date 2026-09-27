#!/bin/bash
# Generates ToolkitTest.xcodeproj from project.yml — on a Mac, or in CI.
#   DEVELOPMENT_TEAM=ABCDE12345 ./generate.sh
set -euo pipefail
cd "$(dirname "$0")"

# CI: a pinned XcodeGen, checked against its checksum.
XCODEGEN_VERSION=2.46.0
XCODEGEN_SHA256=4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  dir="${RUNNER_TEMP:-/tmp}/xcodegen-$XCODEGEN_VERSION"
  if [ ! -x "$dir/xcodegen/bin/xcodegen" ]; then
    mkdir -p "$dir"
    curl -sfL --proto =https -o "$dir/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip"
    echo "$XCODEGEN_SHA256  $dir/xcodegen.zip" | shasum -a 256 -c -
    unzip -q "$dir/xcodegen.zip" -d "$dir"
  fi
  export PATH="$dir/xcodegen/bin:$PATH"
fi
command -v xcodegen >/dev/null || brew install xcodegen

if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  sed -i '' "s/^DEVELOPMENT_TEAM *=.*/DEVELOPMENT_TEAM = ${DEVELOPMENT_TEAM}/" Config.xcconfig
fi
xcodegen generate
echo "[generate] ToolkitTest.xcodeproj ready"
