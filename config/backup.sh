#!/bin/bash

# Source environment variables
if [[ -f "$HOME/git/macos/.env" ]]; then
    source "$HOME/git/macos/.env"
else
    echo "Error: .env file not found at $HOME/git/macos/.env"
    exit 1
fi

# List of apps to backup
APP_CONFIGS=(
    "alt-tab"
    "bettertouchtool"
    "linearmouse"
    # Add more apps here
)

# Ensure config directory exists
mkdir -p "$(dirname "${BASH_SOURCE[0]}")"
CONFIG_DIR="$(dirname "${BASH_SOURCE[0]}")"
PACKAGES_FILE="$(dirname "${BASH_SOURCE[0]}")/../packages.txt"

# Ensure NAS backup directory exists
NAS_BACKUP_DIR="/Volumes/$NAS_SHARE_NAME/backups/mba"
mkdir -p "$NAS_BACKUP_DIR"

# Function to check if an app is installed (listed in packages.txt)
is_app_installed() {
    local app_name="$1"
    grep -q "^$app_name\$" "$PACKAGES_FILE"
    return $?
}

# Backup logic for each app
backup_app_config() {
    local app_name="$1"
    
    # Only backup if app is installed
    if ! is_app_installed "$app_name"; then
        echo "Skipping $app_name backup (not installed)"
        return
    fi
    
    echo "Backing up $app_name configuration..."
    
    case "$app_name" in
        "bettertouchtool")
            # Create app config directory if it doesn't exist
            mkdir -p "$CONFIG_DIR/$app_name"
            
            # Backup plist file
            if [[ -f ~/Library/Preferences/com.hegenberg.BetterTouchTool.plist ]]; then
                rsync -a ~/Library/Preferences/com.hegenberg.BetterTouchTool.plist "$CONFIG_DIR/$app_name/"
            fi
            
            # Backup Application Support folder
            if [[ -d ~/Library/Application\ Support/BetterTouchTool ]]; then
                rsync -a ~/Library/Application\ Support/BetterTouchTool/ "$CONFIG_DIR/$app_name/"
            fi
            ;;
            
        "linearmouse")
            # Create app config directory if it doesn't exist
            mkdir -p "$CONFIG_DIR/$app_name"
            
            # Backup config file from ~/.config/linearmouse
            if [[ -d ~/.config/linearmouse ]]; then
                rsync -a ~/.config/linearmouse/ "$CONFIG_DIR/$app_name/"
            fi
            ;;
            
        "alt-tab")
            # Create app config directory if it doesn't exist
            mkdir -p "$CONFIG_DIR/$app_name"
            
            # Backup plist file
            if [[ -f ~/Library/Preferences/com.lwouis.alt-tab-macos.plist ]]; then
                rsync -a ~/Library/Preferences/com.lwouis.alt-tab-macos.plist "$CONFIG_DIR/$app_name/"
            fi
            ;;
            
        # Add more apps with their specific backup logic
        *)
            echo "No backup logic defined for $app_name"
            ;;
    esac
}

# Main backup function
backup_all_configs() {
    echo "Starting app configuration backup..."
    
    for app in "${APP_CONFIGS[@]}"; do
        backup_app_config "$app"
    done
    
    echo "App configuration backup completed"
    
    # Now copy the entire config directory to NAS
    echo "Copying backup to NAS at $NAS_BACKUP_DIR..."
    DATE_STAMP=$(date +"%Y%m%d_%H%M%S")
    BACKUP_NAME="macos_config_$DATE_STAMP"
    
    # Create a timestamped directory in the NAS location
    mkdir -p "$NAS_BACKUP_DIR/$BACKUP_NAME"
    
    # Copy all configs to the NAS
    rsync -av "$CONFIG_DIR/" "$NAS_BACKUP_DIR/$BACKUP_NAME/"
    
    echo "Backup copied to NAS at $NAS_BACKUP_DIR/$BACKUP_NAME"
}

# Run the backup
backup_all_configs
