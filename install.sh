#!/bin/zsh
set -e

if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: do not run as root or with sudo." >&2
    exit 1
fi

SCRIPT_DIR="${0:A:h}"
SCREENSHOTS_SCRIPT="$SCRIPT_DIR/Screenshots.sh"
PLIST_LABEL="com.local.screenshot-mover"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
USER_ID=$(id -u)

echo "=== Screenshot Mover — Installer ==="

if [[ ! -f "$SCREENSHOTS_SCRIPT" ]]; then
    echo "Error: Screenshots.sh not found at $SCREENSHOTS_SCRIPT" >&2
    exit 1
fi

# Homebrew
if ! command -v brew &>/dev/null; then
    echo "→ Installing Homebrew…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Bring Homebrew into PATH for the rest of this script (Apple Silicon installs to /opt/homebrew)
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
else
    echo "✓ Homebrew already installed"
fi

# fswatch
if ! command -v fswatch &>/dev/null; then
    echo "→ Installing fswatch…"
    brew install fswatch
else
    echo "✓ fswatch already installed"
fi

# Make script executable
chmod +x "$SCREENSHOTS_SCRIPT"
echo "✓ Screenshots.sh is executable"

# Write LaunchAgent plist
mkdir -p "$HOME/Library/LaunchAgents"
FSWATCH_PATH="$(command -v fswatch)"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$SCREENSHOTS_SCRIPT</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>$HOME</string>
        <key>PATH</key>
        <string>$(dirname "$FSWATCH_PATH"):/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/screenshot-mover.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/screenshot-mover.err</string>
</dict>
</plist>
EOF
echo "✓ LaunchAgent plist written"

# Unload existing instance before (re-)loading
if launchctl print "gui/$USER_ID/$PLIST_LABEL" &>/dev/null; then
    echo "→ Unloading existing agent…"
    launchctl bootout "gui/$USER_ID" "$PLIST_PATH"
fi

launchctl bootstrap "gui/$USER_ID" "$PLIST_PATH"

echo ""
echo "✓ Screenshot Mover is running and will start automatically at login."
echo "  Screenshots dropped on ~/Desktop are moved to ~/Pictures/Screenshots/<Year>-<Month>/"
echo ""
echo "  To uninstall: ./uninstall.sh"
