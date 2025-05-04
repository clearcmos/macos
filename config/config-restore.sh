#!/bin/bash

# List of apps to restore
APP_CONFIGS=(
    "bettertouchtool"
    "linearmouse"
    # Add more apps here
)

# Base directory for backed up configs
CONFIG_DIR="$(dirname "${BASH_SOURCE[0]}")"
PACKAGES_FILE="$(dirname "${BASH_SOURCE[0]}")/../packages.txt"

# Function to check if an app is installed
is_app_installed() {
    local app_name="$1"
    grep -q "^$app_name$" "$PACKAGES_FILE"
    return $?
}

# Restore logic for each app
restore_app_config() {
    local app_name="$1"
    
    # Only restore if app is installed and backup exists
    if ! is_app_installed "$app_name"; then
        echo "Skipping $app_name restore (not installed)"
        return
    fi
    
    if [[ ! -d "$CONFIG_DIR/$app_name" ]]; then
        echo "Skipping $app_name restore (no backup found)"
        return
    fi
    
    echo "Restoring $app_name configuration..."
    
    case "$app_name" in
        "bettertouchtool")
            # Restore plist file to Preferences
            if [[ -f "$CONFIG_DIR/$app_name/com.hegenberg.BetterTouchTool.plist" ]]; then
                echo "  • Restoring preferences file to ~/Library/Preferences/"
                mkdir -p ~/Library/Preferences
                rsync -a "$CONFIG_DIR/$app_name/com.hegenberg.BetterTouchTool.plist" ~/Library/Preferences/
            fi
            
            # Restore all possible App Support files
            echo "  • Restoring application files to ~/Library/Application Support/BetterTouchTool/"
            mkdir -p ~/Library/Application\ Support/BetterTouchTool
            
            # Restore all directories (excluding the plist that belongs elsewhere)
            for dir in "$CONFIG_DIR/$app_name"/*/ ; do
                if [[ -d "$dir" ]]; then
                    dir_name=$(basename "$dir")
                    rsync -a "$dir" ~/Library/Application\ Support/BetterTouchTool/
                fi
            done
            
            # Restore non-plist files in the root
            find "$CONFIG_DIR/$app_name" -maxdepth 1 -type f -not -name "com.hegenberg.BetterTouchTool.plist" -exec \
                rsync -a {} ~/Library/Application\ Support/BetterTouchTool/ \;
            ;;
            
        "linearmouse")
            # Restore config file to ~/.config/linearmouse
            echo "  • Restoring config to ~/.config/linearmouse/"
            mkdir -p ~/.config/linearmouse
            rsync -a "$CONFIG_DIR/$app_name/" ~/.config/linearmouse/
            ;;
            
        # Add more apps with their specific restore logic
        *)
            echo "No restore logic defined for $app_name"
            ;;
    esac
}

# Main restore function
restore_all_configs() {
    echo "Starting app configuration restore..."
    
    for app in "${APP_CONFIGS[@]}"; do
        restore_app_config "$app"
    done
    
    echo "App configuration restore completed"
}

# Allow restoring a single app
if [[ "$1" != "" ]]; then
    restore_app_config "$1"
else
    # Run the full restore
    restore_all_configs
fi