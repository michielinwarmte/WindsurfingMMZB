# Shared settings for the scripts in tools/. Not meant to be run on its own.

# The Godot version this project is built with. Change it here only, then run
# tools/install_godot.sh and update CLAUDE.md and README.md.
GODOT_VERSION="4.7.2"
GODOT_RELEASE="${GODOT_VERSION}-stable"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$REPO_ROOT/Game"

# Where tools/install_godot.sh puts Godot (per user, no sudo needed).
GODOT_INSTALL_DIR="$HOME/.local/opt/godot/$GODOT_RELEASE"
GODOT_INSTALLED_BIN="$GODOT_INSTALL_DIR/Godot_v${GODOT_RELEASE}_linux.x86_64"

# Prints the path of the Godot executable to use.
# Order: $GODOT (if set), the copy from tools/install_godot.sh, `godot` on PATH.
find_godot() {
	local candidate=""
	if [[ -n "${GODOT:-}" ]]; then
		candidate="$GODOT"
	elif [[ -x "$GODOT_INSTALLED_BIN" ]]; then
		echo "$GODOT_INSTALLED_BIN"
		return 0
	elif command -v godot >/dev/null 2>&1; then
		candidate="$(command -v godot)"
	else
		echo "Godot $GODOT_VERSION was not found." >&2
		echo "Linux: run tools/install_godot.sh. Other systems: install Godot $GODOT_VERSION" >&2
		echo "(standard build, not .NET) and set GODOT=/path/to/godot." >&2
		return 1
	fi

	# Warn (but continue) when a different Godot version is picked up.
	local version
	version="$("$candidate" --headless --version 2>/dev/null | tail -n 1 || true)"
	if [[ "$version" != "$GODOT_VERSION".* ]]; then
		echo "Warning: $candidate is Godot '$version', this project expects $GODOT_VERSION." >&2
	fi
	echo "$candidate"
}

# Imports new or changed assets and refreshes Godot's class list, quietly.
# Prints error lines and returns non-zero if the import itself fails.
import_project() {
	local godot="$1"
	local log="$REPO_ROOT/.logs/import.log"
	mkdir -p "$(dirname "$log")"
	if ! "$godot" --headless --path "$PROJECT_DIR" --import >"$log" 2>&1; then
		echo "Godot import failed. Full log: $log" >&2
		grep -E "ERROR|error" "$log" >&2 || tail -n 20 "$log" >&2
		return 1
	fi
}
