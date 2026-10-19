#!/usr/bin/env bash
#
# Idempotent Cloud Agent bootstrap for Element X Android.
#
# Installs the Android command-line tools + the SDK packages required to build
# the project (see plugins/src/main/kotlin/Versions.kt) and, optionally, an
# emulator + system image so the app can be run end to end.
#
# The base image already provides JDK 21 (required by the Gradle build).
set -euo pipefail

ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
CMDLINE_TOOLS_VERSION="11076708"
COMPILE_SDK="android-36"
BUILD_TOOLS="36.0.0"
# System image used to run the app on a headless emulator.
SYSTEM_IMAGE="system-images;android-35;google_apis;x86_64"
# Set INSTALL_EMULATOR=0 to skip the (large) emulator + system image download.
INSTALL_EMULATOR="${INSTALL_EMULATOR:-1}"

log() { printf '\n>>> %s\n' "$*"; }

mkdir -p "$ANDROID_HOME"

# 1. Command-line tools -------------------------------------------------------
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  log "Installing Android command-line tools"
  tmp="$(mktemp -d)"
  curl -sSLo "$tmp/cmdline-tools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  unzip -q -o "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  rm -rf "$ANDROID_HOME/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
else
  log "Android command-line tools already installed"
fi

export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# 2. Licenses + SDK packages --------------------------------------------------
log "Accepting SDK licenses"
yes | sdkmanager --licenses >/dev/null 2>&1 || true

log "Installing platform-tools, ${COMPILE_SDK}, build-tools ${BUILD_TOOLS}"
sdkmanager "platform-tools" "platforms;${COMPILE_SDK}" "build-tools;${BUILD_TOOLS}"

if [ "$INSTALL_EMULATOR" = "1" ]; then
  log "Installing emulator + ${SYSTEM_IMAGE}"
  sdkmanager "emulator" "$SYSTEM_IMAGE"
fi

# 3. Tell Gradle where the SDK lives (local.properties is git-ignored) --------
log "Writing local.properties"
echo "sdk.dir=$ANDROID_HOME" > "$(dirname "$0")/../local.properties"

# 4. Persist env vars for interactive shells (idempotent) ---------------------
if ! grep -q 'ANDROID_HOME=' "$HOME/.bashrc" 2>/dev/null; then
  log "Persisting ANDROID_HOME in ~/.bashrc"
  cat >> "$HOME/.bashrc" <<EOF

export ANDROID_HOME=$ANDROID_HOME
export ANDROID_SDK_ROOT=$ANDROID_HOME
export PATH=\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/emulator:\$PATH
EOF
fi

log "Android SDK setup complete (ANDROID_HOME=$ANDROID_HOME)"
