#!/usr/bin/env bash
# Installs the Godot version this project uses, for the current user only (no sudo).
#
# Linux x86_64 only. On Windows or macOS, download Godot (the standard build, not .NET)
# with the version from tools/common.sh from https://godotengine.org/download/archive/
# and set the GODOT environment variable to its path if you want to use tools/*.sh.
#
# What it does:
#   1. downloads the official build from GitHub and checks its SHA-512 checksum
#   2. unpacks it to ~/.local/opt/godot/<version>/
#   3. links ~/.local/bin/godot to it, so `godot` works in a new terminal
#   4. adds "Godot Engine <version>" to your application menu
# Safe to run again: it skips the download when that version is already installed.
set -euo pipefail
source "$(dirname "$0")/common.sh"

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
	echo "This script only supports Linux x86_64. See the comment at the top for other systems." >&2
	exit 1
fi

zip_name="Godot_v${GODOT_RELEASE}_linux.x86_64.zip"
base_url="https://github.com/godotengine/godot/releases/download/${GODOT_RELEASE}"

if [[ -x "$GODOT_INSTALLED_BIN" ]]; then
	echo "Godot $GODOT_RELEASE is already installed in $GODOT_INSTALL_DIR"
else
	tmp="$(mktemp -d)"
	trap 'rm -rf "$tmp"' EXIT

	echo "Downloading $zip_name ..."
	curl -fL --progress-bar -o "$tmp/$zip_name" "$base_url/$zip_name"
	curl -fsSL -o "$tmp/SHA512-SUMS.txt" "$base_url/SHA512-SUMS.txt"

	echo "Checking the checksum ..."
	if ! (cd "$tmp" && grep " ${zip_name}\$" SHA512-SUMS.txt | sha512sum --check --status); then
		echo "Checksum does not match the official one. Not installing." >&2
		exit 1
	fi

	mkdir -p "$GODOT_INSTALL_DIR"
	unzip -q -o "$tmp/$zip_name" -d "$GODOT_INSTALL_DIR"
	chmod +x "$GODOT_INSTALLED_BIN"
fi

# Command-line shortcut. Your terminal adds ~/.local/bin to PATH once the folder exists
# (open a new terminal). tools/godot.sh finds Godot without it.
mkdir -p "$HOME/.local/bin"
ln -sfn "$GODOT_INSTALLED_BIN" "$HOME/.local/bin/godot"

# Application menu entry.
icon="$GODOT_INSTALL_DIR/godot.svg"
if [[ ! -f "$icon" ]]; then
	curl -fsSL -o "$icon" "https://raw.githubusercontent.com/godotengine/godot/${GODOT_RELEASE}/editor/icons/Godot.svg" || true
fi
mkdir -p "$HOME/.local/share/applications"
cat >"$HOME/.local/share/applications/godot-${GODOT_RELEASE}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Godot Engine ${GODOT_VERSION}
Comment=Game engine used by the Windsurfing Simulator
Exec="$GODOT_INSTALLED_BIN" %f
Icon=$icon
Terminal=false
Categories=Development;IDE;
StartupWMClass=Godot
EOF

echo "Installed: $("$GODOT_INSTALLED_BIN" --headless --version | tail -n 1)"
echo "Open the project with tools/edit.sh, or start \"Godot Engine ${GODOT_VERSION}\" from your app menu."
