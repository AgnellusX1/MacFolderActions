#!/bin/zsh
# MacOS by Default saves Screenshots to the Desktop, over time this can get quite cluttered
# This script moves monitors Desktop Folder (Not Subfolders) for any Screenshots and moves them to a Folder under `Pictures/Screenshots/<CurrentYear-CurrentMonth>`

# Folder path for screenshots
currentYear=$(date +"%Y")
currentMonth=$(date +"%B")
screenshotsFolder="$HOME/Pictures/Screenshots/$currentYear-$currentMonth"

# Ensure the folder exists
if [ ! -d "$screenshotsFolder" ]; then
    mkdir -p "$screenshotsFolder"
    if [ $? -ne 0 ]; then
        osascript -e "display notification \"Could not create $screenshotsFolder\" with title \"Failed to Create Folder\""
        exit 1
    fi
fi

# Function to move screenshots
move_screenshot() {
    local filePath="$1"
    local fileName=$(basename "$filePath")
    
    if [[ "$fileName" == Screenshot* ]]; then
        local destinationPath="$screenshotsFolder/$fileName"
        mv "$filePath" "$destinationPath"
        if [ $? -eq 0 ]; then
            osascript -e "display notification \"Moved: $fileName to $destinationPath\" with title \"File Moved Successfully\""
        else
            osascript -e "display notification \"Could not move $fileName to $screenshotsFolder\" with title \"Failed to Move File\""
        fi
    fi
}

# Monitor Desktop for new files
function monitor_desktop {
    while true; do
        for file in "$HOME/Desktop/"*; do
            if [ -f "$file" ]; then
                move_screenshot "$file"
            fi
        done
        sleep 2  # Adjust the sleep duration as needed
    done
}

monitor_desktop
