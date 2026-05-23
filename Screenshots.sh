#!/bin/zsh
# Monitors the Desktop (top-level only) for macOS screenshots and moves them
# to ~/Pictures/Screenshots/<Year>-<Month>/

_screenshots_folder() {
    echo "$HOME/Pictures/Screenshots/$(date +"%Y-%B")"
}

_ensure_folder() {
    local folder="$1"
    if [[ ! -d "$folder" ]]; then
        if ! mkdir -p "$folder"; then
            osascript -e "display notification \"Could not create $folder\" with title \"Screenshot Mover: Error\""
            return 1
        fi
    fi
}

move_screenshot() {
    local filePath="$1"
    local fileName="${filePath:t}"

    [[ -f "$filePath" ]] || return 0
    [[ "$fileName" == Screenshot* ]] || return 0

    local destFolder
    destFolder="$(_screenshots_folder)"
    _ensure_folder "$destFolder" || return 1

    local destPath="$destFolder/$fileName"

    # Avoid overwriting an existing file — append a counter suffix
    if [[ -e "$destPath" ]]; then
        local base="${fileName:r}"
        local ext="${fileName:e}"
        local counter=1
        local candidate
        while true; do
            if [[ -n "$ext" ]]; then
                candidate="$destFolder/${base}_${counter}.${ext}"
            else
                candidate="$destFolder/${base}_${counter}"
            fi
            [[ -e "$candidate" ]] || break
            (( counter++ ))
        done
        destPath="$candidate"
    fi

    if mv "$filePath" "$destPath" 2>/dev/null; then
        osascript -e "display notification \"Moved: ${destPath:t}\" with title \"Screenshot Moved\""
    elif [[ -f "$filePath" ]]; then
        osascript -e "display notification \"Could not move $fileName\" with title \"Screenshot Mover: Error\""
    fi
}

if ! command -v fswatch &>/dev/null; then
    echo "fswatch not found. Install with: brew install fswatch" >&2
    exit 1
fi

trap 'echo "\nStopped."; exit 0' INT TERM

# Move any screenshots already on the Desktop before we start watching
echo "Scanning ~/Desktop for existing screenshots…"
for file in "$HOME/Desktop/"*(N.); do
    move_screenshot "$file"
done

echo "Watching ~/Desktop for screenshots…"
fswatch -0 "$HOME/Desktop" | while IFS= read -r -d '' filePath; do
    move_screenshot "$filePath"
done
