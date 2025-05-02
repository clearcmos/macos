# macOS System Setup Script

A comprehensive bash script for automating macOS system configuration and software installation.

## Overview

This script automates the setup and configuration of a macOS system, handling everything from package management to system preferences. It's designed to help you quickly set up a new Mac or maintain consistent configurations across multiple machines.

## Features

The script handles the following tasks:

1. **Homebrew Package Management**
   - Installs Homebrew if not present
   - Installs a predefined list of applications and utilities
   - Removes packages not in the configured list
   - Updates Homebrew and all packages

2. **Hostname Configuration**
   - Sets Computer Name, Host Name, and Local Host Name
   - Updates NetBIOS name for networking

3. **npm/Node.js and Claude CLI Installation**
   - Configures npm with user-specific settings
   - Installs the Claude AI CLI tool

4. **macOS Dock Management**
   - Configures Dock items using dockutil
   - Positions applications in specific Dock slots

5. **GNU nano Configuration**
   - Sets up nano editor with syntax highlighting
   - Configures sensible defaults (autoindent, line numbers, etc.)

6. **ZSH Configuration Management**
   - Backs up and restores .zshrc configurations
   - Updates shell prompt to show hostname

## Prerequisites

- macOS (tested on macOS Ventura and later)
- Administrator access (for hostname changes and some installations)
- Internet connection (for downloading packages)

## Usage

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/macos-setup.git
   cd macos-setup
   ```

2. Make the script executable:
   ```bash
   chmod +x start.sh
   ```

3. Run the script:
   ```bash
   ./start.sh
   ```

## Customization

### Package Management

Edit the `BREW_PACKAGES` array in the script to customize which applications and utilities to install:

```bash
BREW_PACKAGES=(
  "brave-browser"
  "visual-studio-code"
  # Add or remove packages as needed
)
```

### Hostname

Change the `DESIRED_HOSTNAME` variable in the `configure_hostname` function to set your preferred system name:

```bash
DESIRED_HOSTNAME="your-hostname-here"
```

### Dock Configuration

Modify the `manage_dock` function to add, remove, or reposition your favorite applications in the Dock.

## Troubleshooting

- **Permissions Issues**: If you encounter permission errors, ensure the script is executable (`chmod +x start.sh`) and that you have administrator privileges.
- **Homebrew Installation Failures**: If Homebrew installation fails, check your internet connection and macOS version compatibility.
- **Package Installation Errors**: Some packages may fail to install due to dependencies or compatibility issues. The script will continue with other tasks and log errors.

## Logs

The script provides colored output for easy tracking:
- Blue [INFO] messages for general information
- Green [SUCCESS] messages for completed tasks
- Yellow [WARNING] messages for non-critical issues
- Red [ERROR] messages for failed operations

## Contributing

Feel free to fork this repository and submit pull requests with improvements or additional features.

## License

This project is open-source. Use, modify, and distribute as needed.
