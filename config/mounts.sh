#!/bin/bash

# Load environment variables from .env file
ENV_FILE="$HOME/git/macos/.env"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored messages
print_message() {
    echo -e "${2}${1}${NC}"
}

# Check if running as root (we want to avoid this)
if [ "$(id -u)" = "0" ]; then
    print_message "This script should NOT be run as root. Please run without sudo." "$RED"
    exit 1
fi

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    print_message "Error: .env file not found at $ENV_FILE" "$RED"
    exit 1
fi

# Source the .env file
print_message "Loading configuration from $ENV_FILE..." "$YELLOW"
source "$ENV_FILE"

# Validate required variables
if [ -z "$NAS_HOST" ] || [ -z "$NAS_SHARE_NAME" ] || [ -z "$NAS_USERNAME" ] || [ -z "$NAS_PASSWORD" ] || [ -z "$MOUNT_POINT" ]; then
    print_message "Error: Missing required variables in .env file. Ensure NAS_HOST, NAS_SHARE_NAME, NAS_USERNAME, NAS_PASSWORD, and MOUNT_POINT are defined." "$RED"
    exit 1
fi

# Force mounting in /Volumes only
if [[ "$MOUNT_POINT" != /Volumes/* ]]; then
    # If not already in /Volumes, modify it to be in /Volumes
    VOLUME_MOUNT_POINT="/Volumes/$(basename "$MOUNT_POINT")"
    print_message "Changing mount point to standard /Volumes location: $VOLUME_MOUNT_POINT" "$YELLOW"
    MOUNT_POINT="$VOLUME_MOUNT_POINT"
fi

# Ensure Volumes exists and is accessible
if [ ! -d "/Volumes" ]; then
    print_message "Error: /Volumes directory doesn't exist." "$RED"
    exit 1
fi

# Check if already mounted first using multiple methods
IS_MOUNTED=false

# Method 1: Check if mount point exists, is accessible, and has content
if [ -d "$MOUNT_POINT" ] && ls -la "$MOUNT_POINT" > /dev/null 2>&1 && [ -n "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
    print_message "Mount point $MOUNT_POINT has content and is accessible." "$GREEN"
    print_message "Share appears to be already mounted." "$GREEN"
    IS_MOUNTED=true
# Method 2: Check mount command output
elif mount | grep -q "$MOUNT_POINT"; then
    print_message "NAS is already mounted at $MOUNT_POINT according to mount command" "$GREEN"
    IS_MOUNTED=true
# Method 3: Check for SMB mounts specifically
elif mount | grep -q "$NAS_HOST/$NAS_SHARE_NAME"; then
    print_message "NAS share $NAS_SHARE_NAME is already mounted from $NAS_HOST" "$GREEN"
    IS_MOUNTED=true
fi

# Only proceed with mounting if not already mounted
if ! $IS_MOUNTED; then
    # Clean up any existing directory
    if [ -d "$MOUNT_POINT" ]; then
        print_message "Mount point exists. Cleaning up for fresh mount..." "$YELLOW"
        
        # Try to unmount first in case it's a stale mount
        umount "$MOUNT_POINT" 2>/dev/null
        
        # Remove directory entirely to avoid "File exists" error
        rm -rf "$MOUNT_POINT" 2>/dev/null
        
        # Check if removal succeeded
        if [ -d "$MOUNT_POINT" ]; then
            print_message "Failed to remove existing mount point. Trying with sudo..." "$YELLOW"
            sudo rm -rf "$MOUNT_POINT" 2>/dev/null || true
        fi
    fi
    
    # Create fresh mount point
    print_message "Creating mount point at $MOUNT_POINT..." "$YELLOW"
    
    # Check if mount point's parent dir exists and is writable
    PARENT_DIR=$(dirname "$MOUNT_POINT")
    if [ ! -d "$PARENT_DIR" ]; then
        print_message "Parent directory $PARENT_DIR doesn't exist." "$YELLOW"
        sudo mkdir -p "$PARENT_DIR" 2>/dev/null
    fi
    
    # Try regular mkdir first
    mkdir -p "$MOUNT_POINT" 2>/dev/null
    
    # If mkdir failed, try with sudo
    if [ ! -d "$MOUNT_POINT" ]; then
        print_message "Failed to create mount point. Trying with sudo..." "$YELLOW"
        sudo mkdir -p "$MOUNT_POINT" 2>/dev/null
        sudo chown "$(whoami)" "$MOUNT_POINT" 2>/dev/null
    fi
    
    # Final check if mount point exists
    if [ ! -d "$MOUNT_POINT" ]; then
        print_message "Failed to create mount point. Please run:" "$RED"
        print_message "sudo mkdir -p \"$MOUNT_POINT\" && sudo chown $(whoami) \"$MOUNT_POINT\"" "$YELLOW"
        exit 1
    fi
    
    # Ensure mount point is empty
    if [ -n "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
        print_message "Warning: Mount point is not empty. This may cause mount failures." "$YELLOW"
        print_message "Trying to clean up..." "$YELLOW"
        rm -rf "$MOUNT_POINT"/* 2>/dev/null || true
    fi
    
    # Mount the NAS
    print_message "Mounting NAS share to $MOUNT_POINT..." "$YELLOW"
    mount_smbfs "//$NAS_USERNAME:$NAS_PASSWORD@$NAS_HOST/$NAS_SHARE_NAME" "$MOUNT_POINT"
    
    # Check if mount succeeded
    if [ $? -ne 0 ]; then
        print_message "Failed to mount NAS share. Trying alternative approaches..." "$YELLOW"
        
        # Try one more time with direct mount command
        print_message "Trying mount with different options..." "$YELLOW"
        mkdir -p "$MOUNT_POINT" 2>/dev/null
        mount -t smbfs "//guest:@$NAS_HOST/$NAS_SHARE_NAME" "$MOUNT_POINT" 2>/dev/null ||
        mount_smbfs -o soft "//guest:@$NAS_HOST/$NAS_SHARE_NAME" "$MOUNT_POINT" 2>/dev/null ||
        mount_smbfs -o soft "//$NAS_USERNAME:$NAS_PASSWORD@$NAS_HOST/$NAS_SHARE_NAME" "$MOUNT_POINT"
        
        if [ $? -eq 0 ]; then
            print_message "Alternative mount approach succeeded!" "$GREEN"
            IS_MOUNTED=true
        else
            print_message "All mount attempts failed. Please check network and credentials." "$RED"
            exit 1
        fi
    else
        print_message "NAS mounted successfully at $MOUNT_POINT" "$GREEN"
        IS_MOUNTED=true
    fi
fi

# At this point, we should have a mounted share
if $IS_MOUNTED; then
    # Test if we can access the mount
    ls -la "$MOUNT_POINT" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_message "Mount test successful. Your NAS is accessible at $MOUNT_POINT" "$GREEN"
        
        # Check for LaunchAgent for automatic mounting
        LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENTS_DIR"
        
        AGENT_FILE="$LAUNCH_AGENTS_DIR/com.user.mountnas.plist"
        AGENT_LABEL="com.user.mountnas"
        
        # Check if agent is already loaded and active
        if launchctl list | grep -q "$AGENT_LABEL"; then
            print_message "Login item already exists and is loaded." "$GREEN"
        else
            # Check if agent file exists with correct content
            AGENT_NEEDS_UPDATE=true
            
            if [ -f "$AGENT_FILE" ]; then
                # Check if existing file has the correct mount point and credentials
                if grep -q "$MOUNT_POINT" "$AGENT_FILE" && grep -q "$NAS_HOST/$NAS_SHARE_NAME" "$AGENT_FILE"; then
                    print_message "Login item exists with correct configuration." "$GREEN"
                    
                    # Ensure it's loaded
                    if ! launchctl list | grep -q "$AGENT_LABEL"; then
                        print_message "Reloading login item..." "$YELLOW"
                        launchctl load -w "$AGENT_FILE"
                    fi
                    
                    AGENT_NEEDS_UPDATE=false
                else
                    print_message "Login item exists but needs updating..." "$YELLOW"
                fi
            else
                print_message "Creating login item at $AGENT_FILE..." "$YELLOW"
            fi
            
            # Create/update the agent file if needed
            if $AGENT_NEEDS_UPDATE; then
                cat > "$AGENT_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.mountnas</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/sh</string>
        <string>-c</string>
        <string>if ! mount | grep -q "$MOUNT_POINT" && [ ! -d "$MOUNT_POINT" -o -z "$(ls -A "$MOUNT_POINT" 2>/dev/null)" ]; then
mkdir -p "$MOUNT_POINT" 2>/dev/null || true
mount_smbfs "//$NAS_USERNAME:$NAS_PASSWORD@$NAS_HOST/$NAS_SHARE_NAME" "$MOUNT_POINT" 2>/dev/null
fi</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
    <key>StartInterval</key>
    <integer>86400</integer>
</dict>
</plist>
EOF
                
                # Unload the agent if it already exists to prevent duplicate entries
                launchctl unload "$AGENT_FILE" 2>/dev/null
                
                # Load the agent
                launchctl load -w "$AGENT_FILE"
                if [ $? -eq 0 ]; then
                    print_message "Login item created/updated successfully! Your NAS will be mounted at login." "$GREEN"
                else
                    print_message "Failed to create/update login item." "$RED"
                fi
            fi
        fi
        
        # Check for mysides and install if missing
        SIDEBAR_ADDED=false
        
        if command -v mysides > /dev/null 2>&1; then
            print_message "Found mysides tool for Finder sidebar integration" "$GREEN"
            MYSIDES_INSTALLED=true
        elif command -v brew > /dev/null 2>&1; then
            print_message "mysides tool not found. Attempting to install with Homebrew..." "$YELLOW"
            
            # Check if package is available in brew
            if brew info mysides > /dev/null 2>&1; then
                brew install mysides > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    print_message "Successfully installed mysides" "$GREEN"
                    MYSIDES_INSTALLED=true
                else
                    print_message "Failed to install mysides" "$RED"
                    MYSIDES_INSTALLED=false
                fi
            else
                print_message "mysides package not found in Homebrew" "$RED"
                MYSIDES_INSTALLED=false
            fi
        else
            print_message "Homebrew not found. Cannot install mysides automatically." "$YELLOW"
            print_message "Install mysides manually to enable Finder sidebar integration" "$YELLOW"
            MYSIDES_INSTALLED=false
        fi
        
        # Add share to Finder sidebar if mysides is available
        if [ "$MYSIDES_INSTALLED" = true ] && command -v mysides > /dev/null 2>&1; then
            SIDEBAR_NAME=$(basename "$MOUNT_POINT")
            SIDEBAR_PATH="file://$MOUNT_POINT"
            
            # Check if already in sidebar (best effort - mysides doesn't have a list feature with easy grep)
            print_message "Adding share to Finder sidebar..." "$YELLOW"
            mysides add "$SIDEBAR_NAME" "$SIDEBAR_PATH" > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                print_message "Successfully added share to Finder sidebar" "$GREEN"
                SIDEBAR_ADDED=true
            else
                print_message "Could not add share to Finder sidebar. It may already be there." "$YELLOW"
                SIDEBAR_ADDED=false
            fi
        else
            print_message "Cannot add share to Finder sidebar (mysides not available)" "$YELLOW"
            if command -v brew > /dev/null 2>&1; then
                print_message "Try installing manually: brew install mysides" "$YELLOW"
            fi
            SIDEBAR_ADDED=false
        fi
        
        print_message "\nSUMMARY:" "$GREEN"
        print_message "1. NAS successfully mounted at: $MOUNT_POINT" "$GREEN"
        if launchctl list | grep -q "$AGENT_LABEL"; then
            print_message "2. Automatic mounting at login is configured" "$GREEN"
        else
            print_message "2. Failed to configure automatic mounting at login" "$RED"
        fi
        if [ "$SIDEBAR_ADDED" = true ]; then
            print_message "3. Share added to Finder sidebar" "$GREEN"
        elif [ "$MYSIDES_INSTALLED" = true ]; then
            print_message "3. Share may already be in Finder sidebar" "$YELLOW"
        else
            print_message "3. Share not added to Finder sidebar (mysides not available)" "$YELLOW"
        fi
        
        print_message "\nNAS mount setup completed successfully!" "$GREEN"
    else
        print_message "Mount appears to exist, but content is not accessible. Please check permissions." "$YELLOW"
    fi
else
    print_message "Failed to mount NAS. Please check your credentials and network connection." "$RED"
    exit 1
fi

print_message "Done!" "$GREEN"