#!/bin/bash

# Source environment variables
if [[ -f "$HOME/git/macos/.env" ]]; then
    source "$HOME/git/macos/.env"
else
    echo "Error: .env file not found at $HOME/git/macos/.env"
    exit 1
fi

# List of apps to restore
APP_CONFIGS=(
    "alt-tab"
    "bettertouchtool"
    "linearmouse"
    # Add more apps here
)

# NAS backup directory
NAS_BACKUP_DIR="/Volumes/$NAS_SHARE_NAME/backups/mba"
PACKAGES_FILE="$(dirname "${BASH_SOURCE[0]}")/../packages.txt"

# Function to find the latest backup on NAS
find_latest_backup() {
    if [[ ! -d "$NAS_BACKUP_DIR" ]]; then
        echo "NAS backup directory not found: $NAS_BACKUP_DIR"
        exit 1
    fi
    
    # Find the most recent backup directory
    LATEST_BACKUP=$(find "$NAS_BACKUP_DIR" -maxdepth 1 -type d -name "macos_config_*" | sort -r | head -n 1)
    
    if [[ -z "$LATEST_BACKUP" ]]; then
        echo "No backups found in $NAS_BACKUP_DIR"
        exit 1
    fi
    
    echo "$LATEST_BACKUP"
}

# Set backup directory to use (latest by default)
BACKUP_DIR=$(find_latest_backup)

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
    
    if [[ ! -d "$BACKUP_DIR/$app_name" ]]; then
        echo "Skipping $app_name restore (no backup found in $BACKUP_DIR)"
        return
    fi
    
    echo "Restoring $app_name configuration from NAS backup..."
    
    case "$app_name" in
        "bettertouchtool")
            # Restore plist file to Preferences
            if [[ -f "$BACKUP_DIR/$app_name/com.hegenberg.BetterTouchTool.plist" ]]; then
                echo "  • Restoring preferences file to ~/Library/Preferences/"
                mkdir -p ~/Library/Preferences
                rsync -a "$BACKUP_DIR/$app_name/com.hegenberg.BetterTouchTool.plist" ~/Library/Preferences/
            fi
            
            # Restore all possible App Support files
            echo "  • Restoring application files to ~/Library/Application Support/BetterTouchTool/"
            mkdir -p ~/Library/Application\ Support/BetterTouchTool
            
            # Restore all directories (excluding the plist that belongs elsewhere)
            for dir in "$BACKUP_DIR/$app_name"/*/ ; do
                if [[ -d "$dir" ]]; then
                    dir_name=$(basename "$dir")
                    rsync -a "$dir" ~/Library/Application\ Support/BetterTouchTool/
                fi
            done
            
            # Restore non-plist files in the root
            find "$BACKUP_DIR/$app_name" -maxdepth 1 -type f -not -name "com.hegenberg.BetterTouchTool.plist" -exec \
                rsync -a {} ~/Library/Application\ Support/BetterTouchTool/ \;
            ;;
            
        "linearmouse")
            # Restore config file to ~/.config/linearmouse
            echo "  • Restoring config to ~/.config/linearmouse/"
            mkdir -p ~/.config/linearmouse
            rsync -a "$BACKUP_DIR/$app_name/" ~/.config/linearmouse/
            ;;
            
        "alt-tab")
            # Restore plist file to Preferences
            if [[ -f "$BACKUP_DIR/$app_name/com.lwouis.alt-tab-macos.plist" ]]; then
                echo "  • Restoring preferences file to ~/Library/Preferences/"
                mkdir -p ~/Library/Preferences
                rsync -a "$BACKUP_DIR/$app_name/com.lwouis.alt-tab-macos.plist" ~/Library/Preferences/
            fi
            ;;
            
        # Add more apps with their specific restore logic
        *)
            echo "No restore logic defined for $app_name"
            ;;
    esac
}

# Main restore function
restore_all_configs() {
    echo "Starting app configuration restore from NAS backup: $(basename "$BACKUP_DIR")"
    
    for app in "${APP_CONFIGS[@]}"; do
        restore_app_config "$app"
    done
    
    echo "App configuration restore completed"
}

# Parse arguments
RESTORE_APP=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --backup)
            if [[ -n "$2" ]]; then
                # A specific backup name was provided
                BACKUP_DIR="$NAS_BACKUP_DIR/$2"
                shift
            fi
            echo "Using NAS backup: $BACKUP_DIR"
            ;;
        --list)
            echo "Available backups on NAS:"
            if [[ -d "$NAS_BACKUP_DIR" ]]; then
                find "$NAS_BACKUP_DIR" -maxdepth 1 -type d -name "macos_config_*" | sort -r | while read -r backup; do
                    echo "  $(basename "$backup")"
                done
            else
                echo "  NAS backup directory not found: $NAS_BACKUP_DIR"
            fi
            exit 0
            ;;
        *)
            RESTORE_APP="$1"
            ;;
    esac
    shift
done

# Run the restore
if [[ -n "$RESTORE_APP" ]]; then
    restore_app_config "$RESTORE_APP"
else
    restore_all_configs
fi