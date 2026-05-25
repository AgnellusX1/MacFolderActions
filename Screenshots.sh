#!/bin/zsh
# Monitors Desktop for screenshots and moves them to ~/Pictures/Screenshots/<Year>-<Month>/

_screenshots_folder() {
    echo "$HOME/Pictures/Screenshots/$(date +"%Y-%B")"
}

_ensure_folder() {
    local folder="$1"
    [[ -d "$folder" ]] && return 0

    # Try native mkdir first (works if TCC already granted)
    mkdir -p "$folder" 2>/dev/null && return 0

    # mkdir blocked by TCC — create via Finder level by level
    local parent="${folder:h}"
    local name="${folder:t}"

    _ensure_folder "$parent" || return 1

    if ! osascript 2>>/tmp/screenshot-mover.err <<EOF
tell application "Finder"
    make new folder at POSIX file "$parent" with properties {name:"$name"}
end tell
EOF
    then
        osascript -e "display notification \"Could not create $folder\" with title \"Screenshot Mover: Error\""
        return 1
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

    # Resolve a collision-free destination name
    local destName="$fileName"
    if [[ -e "$destFolder/$destName" ]]; then
        local base="${fileName:r}"
        local ext="${fileName:e}"
        local counter=1
        local candidate
        while true; do
            candidate="${base}_${counter}${ext:+.$ext}"
            [[ -e "$destFolder/$candidate" ]] || break
            (( counter++ ))
        done
        destName="$candidate"
    fi

    # Try native mv first (fast path, works if TCC is already granted)
    if mv "$filePath" "$destFolder/$destName" 2>/dev/null; then
        osascript -e "display notification \"Moved: $destName\" with title \"Screenshot Moved\""
        return 0
    fi

    # mv blocked by TCC — move via Finder which has full filesystem access
    if osascript 2>>/tmp/screenshot-mover.err <<EOF
tell application "Finder"
    set movedFile to (move POSIX file "$filePath" to POSIX file "$destFolder")
    if "$destName" is not "$fileName" then
        set name of movedFile to "$destName"
    end if
end tell
EOF
    then
        osascript -e "display notification \"Moved: $destName\" with title \"Screenshot Moved\""
    elif [[ -f "$filePath" ]]; then
        osascript -e "display notification \"Could not move $fileName\" with title \"Screenshot Mover: Error\""
        return 1
    fi
}

if ! command -v fswatch &>/dev/null; then
    echo "fswatch not found. Install with: brew install fswatch" >&2
    exit 1
fi

trap 'echo "\nStopped."; exit 0' INT TERM

echo "Scanning ~/Desktop for existing screenshots…"
for file in "$HOME/Desktop/"*(N.); do
    move_screenshot "$file"
done

echo "Watching ~/Desktop for screenshots…"
typeset -A _last_moved
fswatch -0 "$HOME/Desktop" | while IFS= read -r -d '' filePath; do
    integer now=$(date +%s)
    if [[ -n "${_last_moved[$filePath]}" ]] && (( now - _last_moved[$filePath] < 5 )); then
        continue
    fi
    if move_screenshot "$filePath"; then
        _last_moved[$filePath]=$now
    fi
done
