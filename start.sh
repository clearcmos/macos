#!/bin/bash
set -e

# ------------------------------------------------------------------------------
# MacOS System Setup Script
# This script handles:
# 1. Homebrew package management
# 2. Hostname configuration
# 3. npm/nodejs and Claude CLI installation
# 4. macOS Dock management
# ------------------------------------------------------------------------------

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper function for printing status messages
log() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# ------------------------------------------------------------------------------
# SECTION 1: Homebrew Installation and Package Management
# ------------------------------------------------------------------------------

# Function to install Homebrew if not already installed
ensure_homebrew_installed() {
  log "Checking if Homebrew is installed..."
  
  if [ -x /opt/homebrew/bin/brew ]; then
    BREW="/opt/homebrew/bin/brew"
    log_success "Homebrew is already installed at $BREW"
  elif [ -x /usr/local/bin/brew ]; then
    BREW="/usr/local/bin/brew"
    log_success "Homebrew is already installed at $BREW"
  elif command -v brew &> /dev/null; then
    BREW="brew"
    log_success "Homebrew is already installed and in PATH"
  else
    log_warning "Homebrew is not installed. Installing now..."
    
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    if [ $? -ne 0 ]; then
      log_error "Failed to install Homebrew"
      return 1
    fi
    
    # Check where it was installed
    if [ -x /opt/homebrew/bin/brew ]; then
      BREW="/opt/homebrew/bin/brew"
    elif [ -x /usr/local/bin/brew ]; then
      BREW="/usr/local/bin/brew"
    else
      log_error "Homebrew was installed but executable not found in expected locations"
      return 1
    fi
    
    # Add Homebrew to PATH for this session if it's not already there
    if [[ ":$PATH:" != *":$(dirname $BREW):"* ]]; then
      export PATH="$(dirname $BREW):$PATH"
    fi
    
    log_success "Homebrew installed successfully at $BREW"
    
    # Add Homebrew to shell profile if not already configured
    local SHELL_PROFILE=""
    if [ -f "$HOME/.zshrc" ]; then
      SHELL_PROFILE="$HOME/.zshrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      SHELL_PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.profile" ]; then
      SHELL_PROFILE="$HOME/.profile"
    fi
    
    if [ -n "$SHELL_PROFILE" ]; then
      if ! grep -q "$(dirname $BREW)" "$SHELL_PROFILE"; then
        log "Adding Homebrew to your $SHELL_PROFILE"
        echo "# Homebrew" >> "$SHELL_PROFILE"
        echo "export PATH=\"$(dirname $BREW):\$PATH\"" >> "$SHELL_PROFILE"
      fi
    fi
  fi
  
  # Ensure Homebrew is up to date
  log "Updating Homebrew..."
  $BREW update || log_warning "Homebrew update failed, continuing anyway"
  
  return 0
}

manage_homebrew_packages() {
  log "Managing Homebrew packages..."
  
  # Make sure Homebrew is installed first
  ensure_homebrew_installed || {
    log_error "Cannot manage Homebrew packages without Homebrew installed"
    return 1
  }
  
  # Path to packages file
  PACKAGES_FILE="$(dirname "$0")/packages.txt"
  
  # Check if packages file exists
  if [ ! -f "$PACKAGES_FILE" ]; then
    log_error "Packages file not found at $PACKAGES_FILE"
    return 1
  fi
  
  # Read packages from file into array
  BREW_PACKAGES=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]]; then
      BREW_PACKAGES+=("$line")
    fi
  done < "$PACKAGES_FILE"
  
  # Confirm packages were loaded
  if [ ${#BREW_PACKAGES[@]} -eq 0 ]; then
    log_error "No packages found in $PACKAGES_FILE"
    return 1
  else
    log_success "Loaded ${#BREW_PACKAGES[@]} packages from $PACKAGES_FILE"
  fi
  
  log "Using Homebrew at: $BREW"
  
  # Update Homebrew (but don't fail if update fails)
  log "Updating Homebrew..."
  $BREW update || log_warning "Homebrew update failed, continuing anyway"
  
  # Install packages that aren't already installed
  PACKAGES_INSTALLED=0
  for package in "${BREW_PACKAGES[@]}"; do
    if ! $BREW list "$package" &>/dev/null; then
      log "Installing $package..."
      if $BREW install "$package"; then
        log_success "$package installed successfully"
        PACKAGES_INSTALLED=$((PACKAGES_INSTALLED+1))
      else
        log_error "Failed to install $package"
      fi
    else
      log "$package is already installed"
    fi
  done
  
  # Get list of explicitly installed Homebrew packages (leaves) - not dependencies
  # --cask for GUI applications
  INSTALLED_CASKS=($($BREW list --cask 2>/dev/null))
  # --formula for CLI tools, using leaves to get only explicitly installed packages
  INSTALLED_FORMULAS=($($BREW leaves 2>/dev/null))
  
  # Combine casks and explicitly installed formulas
  INSTALLED_PACKAGES=("${INSTALLED_CASKS[@]}" "${INSTALLED_FORMULAS[@]}")
  
  # Find packages to uninstall - explicitly installed packages that are not in our configuration
  PACKAGES_UNINSTALLED=0
  for installed_pkg in "${INSTALLED_PACKAGES[@]}"; do
    # Skip system packages that Homebrew manages
    if [[ "$installed_pkg" == "openssl"* || "$installed_pkg" == "xz" || "$installed_pkg" == "ca-certificates" ]]; then
      continue
    fi
    
    # Check if this installed package is in our desired packages list
    KEEP=0
    for desired_pkg in "${BREW_PACKAGES[@]}"; do
      if [ "$installed_pkg" = "$desired_pkg" ]; then
        KEEP=1
        break
      fi
    done
    
    # Package is installed but not in our desired list
    if [ $KEEP -eq 0 ]; then
      log "Uninstalling $installed_pkg as it's not in the configured package list..."
      if $BREW uninstall "$installed_pkg"; then
        log_success "$installed_pkg uninstalled successfully"
        PACKAGES_UNINSTALLED=$((PACKAGES_UNINSTALLED+1))
      else
        log_error "Failed to uninstall $installed_pkg"
      fi
    fi
  done
  
  # Clean up any orphaned dependencies that are no longer needed
  log "Cleaning up orphaned dependencies..."
  DEPS_REMOVED=$($BREW autoremove -n | grep -c "Would remove:" || true)
  # Ensure DEPS_REMOVED is a single integer
  if [[ ! "$DEPS_REMOVED" =~ ^[0-9]+$ ]]; then
    DEPS_REMOVED=0
  fi
  
  if [ "$DEPS_REMOVED" -gt 0 ]; then
    log "Found $DEPS_REMOVED orphaned dependencies to remove"
    $BREW autoremove
    log_success "Removed orphaned dependencies"
  else
    log "No orphaned dependencies found"
  fi
  
  log_success "Homebrew package management complete. Installed: $PACKAGES_INSTALLED, Uninstalled: $PACKAGES_UNINSTALLED"
}

# ------------------------------------------------------------------------------
# SECTION 2: Hostname Configuration
# ------------------------------------------------------------------------------
configure_hostname() {
  log "Checking macOS hostname configuration..."
  
  # Set your desired hostname here
  DESIRED_HOSTNAME="mba"
  
  # Use full paths to commands
  SCUTIL="/usr/sbin/scutil"
  HOSTNAME="/bin/hostname"
  DEFAULTS="/usr/bin/defaults"
  
  # Check if commands exist
  if [ ! -x "$SCUTIL" ]; then
    log_error "scutil command not found at $SCUTIL"
    return 1
  fi
  
  # Check all hostname variants
  COMPUTER_NAME=$($SCUTIL --get ComputerName 2>/dev/null || echo "unknown")
  HOST_NAME=$($SCUTIL --get HostName 2>/dev/null || $HOSTNAME 2>/dev/null || echo "unknown")
  LOCAL_HOST_NAME=$($SCUTIL --get LocalHostName 2>/dev/null || echo "unknown")
  
  log "Current hostnames:"
  log "  ComputerName: $COMPUTER_NAME"
  log "  HostName: $HOST_NAME"
  log "  LocalHostName: $LOCAL_HOST_NAME"
  
  if [ "$COMPUTER_NAME" != "$DESIRED_HOSTNAME" ] || \
     [ "$HOST_NAME" != "$DESIRED_HOSTNAME" ] || \
     [ "$LOCAL_HOST_NAME" != "$DESIRED_HOSTNAME" ]; then
    log "Need to change hostnames to $DESIRED_HOSTNAME."
    
    log "Setting hostname to $DESIRED_HOSTNAME (requires sudo)..."
    sudo $SCUTIL --set ComputerName "$DESIRED_HOSTNAME" && \
    sudo $SCUTIL --set HostName "$DESIRED_HOSTNAME" && \
    sudo $SCUTIL --set LocalHostName "$DESIRED_HOSTNAME" && \
    sudo $DEFAULTS write /Library/Preferences/SystemConfiguration/com.apple.smb.server NetBIOSName -string "$DESIRED_HOSTNAME"
    
    if [ $? -eq 0 ]; then
      log_success "All hostname variants set to $DESIRED_HOSTNAME"
    else
      log_error "Failed to set hostname. Check sudo permissions."
      return 1
    fi
  else
    log_success "All hostname variants are already set to $DESIRED_HOSTNAME"
  fi
}

# ------------------------------------------------------------------------------
# SECTION 3: NPM/NodeJS and Claude CLI Installation
# ------------------------------------------------------------------------------
manage_npm_packages() {
  log "Setting up npm and installing required packages..."
  
  # Make sure npm is configured correctly
  NPM_PACKAGES_DIR="$HOME/.npm-packages"
  NPMRC_FILE="$HOME/.npmrc"
  
  # Create/update .npmrc
  if [ ! -f "$NPMRC_FILE" ] || ! grep -q "prefix=$NPM_PACKAGES_DIR" "$NPMRC_FILE"; then
    log "Creating/updating .npmrc file"
    echo "prefix=$NPM_PACKAGES_DIR" > "$NPMRC_FILE"
  fi
  
  # Make sure the directories exist
  mkdir -p "$NPM_PACKAGES_DIR/bin"
  
  # Add npm bin directory to PATH if not already there
  if [[ ":$PATH:" != *":$NPM_PACKAGES_DIR/bin:"* ]]; then
    export PATH="$NPM_PACKAGES_DIR/bin:$PATH"
  fi
  
  # Check if Claude CLI is already installed
  log "Checking if Claude CLI is already installed..."
  if command -v claude &> /dev/null; then
    log_success "Claude CLI is already installed and available in PATH"
  else
    # Check if it's installed in npm packages but not in PATH
    if [ -d "$NPM_PACKAGES_DIR/lib/node_modules/@anthropic-ai/claude-code" ]; then
      log "Claude CLI is installed but may not be in PATH"
      log_success "Claude CLI installation verified"
    else
      log "Installing @anthropic-ai/claude-code..."
      npm install -g @anthropic-ai/claude-code
      
      if [ $? -eq 0 ]; then
        log_success "Claude CLI installed successfully"
      else
        log_error "Failed to install Claude CLI"
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# SECTION 4: MacOS Dock Management
# ------------------------------------------------------------------------------
manage_dock() {
  log "Managing macOS Dock items..."
  
  # Ensure dockutil is installed
  if ! command -v dockutil &> /dev/null; then
    # Try to find it in Homebrew locations
    if [ -n "$BREW" ] && $BREW list dockutil &>/dev/null; then
      DOCKUTIL_PATH="$($BREW --prefix)/bin/dockutil"
    else
      log_error "dockutil is not installed. Please install it first with brew install dockutil"
      return 1
    fi
  else
    DOCKUTIL_PATH="$(command -v dockutil)"
  fi
  
  log "Using dockutil at: $DOCKUTIL_PATH"
  
  # Pin Brave Browser to the Dock (second position)
  log "Ensuring Brave Browser is pinned to Dock in second position..."
  
  # First check if Brave is already in the Dock
  if $DOCKUTIL_PATH --find "Brave Browser" &>/dev/null; then
    # Remove it so we can add it in the correct position
    log "Removing existing Brave Browser from Dock to reposition it"
    $DOCKUTIL_PATH --remove "Brave Browser" --no-restart
  fi
  
  # Add Brave Browser at position 1 (after Finder which is always at position 1)
  log "Adding Brave Browser to Dock at position 1"
  APP_PATH="/Applications/Brave Browser.app"
  if [ -d "$APP_PATH" ]; then
    $DOCKUTIL_PATH --add "$APP_PATH" --position 1
    log_success "Brave Browser added to Dock at position 1"
  else
    log_error "Brave Browser application not found at $APP_PATH"
  fi
  
  log_success "Dock management complete"
}

# ------------------------------------------------------------------------------
# SECTION 5: Configure GNU nano
# ------------------------------------------------------------------------------
configure_nano() {
  log "Configuring GNU nano editor..."
  
  # Check if Homebrew nano is installed
  if ! command -v brew &> /dev/null || ! brew list nano &> /dev/null; then
    log_warning "Homebrew nano is not installed. Will be installed during package management."
    return 0
  fi
  
  # Create nano config directory if it doesn't exist
  mkdir -p "$HOME/.config/nano"
  
  # Path to nanorc file
  NANORC_FILE="$HOME/.nanorc"
  
  # Write configuration to .nanorc
  log "Creating/updating nano configuration at $NANORC_FILE"
  cat > "$NANORC_FILE" << EOF
# Nano editor configuration

set autoindent
set tabsize 4
set tabstospaces
unset mouse

#set linenumbers
#set numbercolor white,black

# Include syntax highlighting definitions provided by Homebrew nano
include "/opt/homebrew/share/nano/*.nanorc"
EOF
  
  log_success "Nano configuration created with autoindent and syntax highlighting"
  
  # NOTE: Nano alias is now managed in the dedicated aliases file
}

# ------------------------------------------------------------------------------
# SECTION 6: ZSH Configuration Management
# ------------------------------------------------------------------------------
manage_zshrc() {
  log "Managing .zshrc configuration..."
  
  # Check if there's a .zshrc in the home directory
  if [ ! -f "$HOME/.zshrc" ]; then
    log_warning "No .zshrc file found in home directory"
    
    # Check if we have a local copy to use
    if [ -f "$(pwd)/.zshrc" ]; then
      log "Found local .zshrc, copying to home directory"
      cp "$(pwd)/.zshrc" "$HOME/.zshrc"
      log_success "Copied .zshrc to home directory"
    else
      log_warning "No local .zshrc found to copy to home directory"
    fi
  else
    # Copy the home .zshrc to the current directory
    log "Backing up current .zshrc to the repository"
    cp "$HOME/.zshrc" "$(pwd)/.zshrc"
    log_success "Backed up .zshrc to $(pwd)/.zshrc"
  fi
  
  # Configure aliases sourcing
  if [ -f "$(pwd)/aliases" ]; then
    log "Setting up aliases sourcing in .zshrc..."
    
    # Check if .zshrc already has the aliases sourcing line
    if ! grep -q "source $(pwd)/aliases" "$HOME/.zshrc"; then
      log "Adding aliases sourcing to .zshrc"
      echo "" >> "$HOME/.zshrc"
      echo "# Source aliases from the macos repository" >> "$HOME/.zshrc"
      echo "source $(pwd)/aliases" >> "$HOME/.zshrc"
      log_success "Added aliases sourcing to .zshrc"
    else
      log "Aliases sourcing already configured in .zshrc"
    fi
  else
    log_warning "Aliases file not found at $(pwd)/aliases"
  fi
  
  # Configure direct functions.d sourcing
  log "Setting up functions.d sourcing in .zshrc..."
  
  # Make sure functions.d directory exists
  if [ ! -d "$(pwd)/functions.d" ]; then
    log "Creating functions.d directory"
    mkdir -p "$(pwd)/functions.d"
    log_success "Created functions.d directory"
  fi
  
  # Check if .zshrc already has the functions.d sourcing code
  if ! grep -q "for function_file in \$(pwd)/functions.d/\*.sh" "$HOME/.zshrc"; then
    log "Adding functions.d sourcing to .zshrc"
    echo "" >> "$HOME/.zshrc"
    echo "# Source all function files from functions.d directory" >> "$HOME/.zshrc"
    echo "for function_file in \$(pwd)/functions.d/*.sh; do" >> "$HOME/.zshrc"
    echo "  if [ -f \"\$function_file\" ]; then" >> "$HOME/.zshrc"
    echo "    source \"\$function_file\"" >> "$HOME/.zshrc"
    echo "  fi" >> "$HOME/.zshrc"
    echo "done" >> "$HOME/.zshrc"
    log_success "Added functions.d sourcing to .zshrc"
  else
    log "Functions.d sourcing already configured in .zshrc"
  fi
}

# ------------------------------------------------------------------------------
# SECTION 7: App Configuration Backup
# ------------------------------------------------------------------------------
backup_app_configurations() {
  log "Backing up application configurations..."
  
  if [ -f "$(pwd)/config/config-backup.sh" ]; then
    log "Running app configuration backup script"
    bash "$(pwd)/config/config-backup.sh"
    
    if [ $? -eq 0 ]; then
      log_success "Application configurations backed up successfully"
    else
      log_error "Failed to backup application configurations"
      return 1
    fi
  else
    log_warning "App configuration backup script not found at $(pwd)/config/config-backup.sh"
  fi
}

# ------------------------------------------------------------------------------
# MAIN SCRIPT EXECUTION
# ------------------------------------------------------------------------------
main() {
  log "Starting macOS system setup..."
  
  # Create config directory if it doesn't exist
  mkdir -p "$HOME/.config/home-manager"
  
  # Check if .zshrc exists in home directory, copy from local if not
  if [ ! -f "$HOME/.zshrc" ] && [ -f "$(pwd)/.zshrc" ]; then
    log "No .zshrc found in home directory but found in current directory, copying..."
    cp "$(pwd)/.zshrc" "$HOME/.zshrc"
    log_success "Copied .zshrc to home directory"
  fi
  
  # Run each section with error handling
  log "Step 1/8: Installing and updating Homebrew"
  ensure_homebrew_installed || {
    log_error "Homebrew installation/update failed"
    log_warning "Continuing with other tasks..."
  }
  
  log "Step 2/8: Managing Homebrew packages"
  manage_homebrew_packages || log_error "Homebrew package management failed"
  
  log "Step 3/8: Checking hostname configuration"
  configure_hostname || log_error "Hostname configuration failed"
  
  # Update zsh prompt to show hostname
  if [ -f "$HOME/.zshrc" ]; then
    log "Updating zsh prompt in .zshrc to show hostname..."
    
    # Check if PS1 setting already exists
    if grep -q "^export PS1=" "$HOME/.zshrc"; then
      # Replace existing PS1 with one that includes hostname
      sed -i '' 's/^export PS1=.*$/export PS1="%m:%~ %# "/' "$HOME/.zshrc"
    else
      # Add PS1 setting to use hostname
      echo "# Set prompt to show hostname" >> "$HOME/.zshrc"
      echo 'export PS1="%m:%~ %# "' >> "$HOME/.zshrc"
    fi
    log_success "Updated zsh prompt in .zshrc to show hostname"
    log_warning "Please restart your terminal or run 'source ~/.zshrc' for prompt changes to take effect"
  fi
  
  log "Step 4/8: Managing npm packages"
  manage_npm_packages || log_error "npm package management failed"
  
  log "Step 5/8: Managing macOS Dock"
  manage_dock || log_error "Dock management failed"
  
  log "Step 6/8: Configuring GNU nano"
  configure_nano || log_error "Nano configuration failed"
  
  log "Step 7/8: Managing .zshrc configuration"
  manage_zshrc || log_error ".zshrc management failed"
  
  log "Step 8/8: Backing up application configurations"
  backup_app_configurations || log_error "App configuration backup failed"
  
  log_success "macOS system setup completed!"
}

# Run the main function
main "$@"
