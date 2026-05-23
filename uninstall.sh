#!/bin/zsh

if [[ "$(id -u)" -eq 0 ]]; then
    echo "Error: do not run as root or with sudo." >&2
    exit 1
fi

PLIST_LABEL="com.local.screenshot-mover"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_LABEL.plist"
USER_ID=$(id -u)

echo "=== Screenshot Mover — Uninstaller ==="

if launchctl print "gui/$USER_ID/$PLIST_LABEL" &>/dev/null; then
    # Use label form so this works even if the plist is already gone
    if launchctl bootout "gui/$USER_ID/$PLIST_LABEL" 2>/dev/null; then
        echo "✓ Agent stopped and unloaded"
    else
        echo "  Warning: could not unload agent — it may have already stopped"
    fi
else
    echo "  Agent was not running"
fi

if [[ -f "$PLIST_PATH" ]]; then
    rm "$PLIST_PATH"
    echo "✓ LaunchAgent plist removed"
fi

echo ""
echo "✓ Screenshot Mover uninstalled. Your existing screenshots are untouched."
