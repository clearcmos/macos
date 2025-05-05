#!/bin/bash

# Combined script to set up Ollama with Qwen2.5-Coder:7b (128k context) and OpenWebUI
# This script is idempotent and will stop on any errors

set -e  # Exit immediately if a command exits with a non-zero status

# Define colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print messages
print_message() {
  local color=$1
  local message=$2
  echo -e "${color}${message}${NC}"
}

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
  print_message "$RED" "Error: This script is intended for macOS only."
  exit 1
fi

# Check if Homebrew is installed
if ! command_exists brew; then
  print_message "$YELLOW" "Homebrew is not installed. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  print_message "$GREEN" "Homebrew has been installed."
  print_message "$YELLOW" "Please run 'source ~/.zshrc' or start a new shell, then run this script again."
  exit 0
else
  print_message "$GREEN" "Homebrew is already installed."
fi

# PART 1: OLLAMA SETUP
# Check if Ollama is installed
if ! command_exists ollama; then
  print_message "$YELLOW" "Ollama is not installed. Installing via Homebrew..."
  
  # Install Ollama
  brew install ollama
  
  # Check if installation was successful
  if ! command_exists ollama; then
    print_message "$RED" "Failed to install Ollama. Please try installing manually."
    exit 1
  fi
  
  print_message "$GREEN" "Ollama installed successfully!"
else
  print_message "$GREEN" "Ollama is already installed."
fi

# Check if Ollama service is running
if ! pgrep -x "ollama" > /dev/null; then
  print_message "$YELLOW" "Ollama service is not running. Starting Ollama..."
  ollama serve > /dev/null 2>&1 &
  
  # Wait for Ollama service to start
  for i in {1..10}; do
    if curl -s http://localhost:11434/api/version > /dev/null; then
      break
    fi
    if [ "$i" -eq 10 ]; then
      print_message "$RED" "Failed to start Ollama service. Please try running 'ollama serve' manually."
      exit 1
    fi
    sleep 1
  done
  
  print_message "$GREEN" "Ollama service started."
else
  print_message "$GREEN" "Ollama service is already running."
fi

# Check if qwen2.5-coder:7b model is already pulled
if ! ollama list | grep -q "qwen2.5-coder:7b"; then
  print_message "$YELLOW" "Pulling qwen2.5-coder:7b model. This may take a while..."
  ollama pull qwen2.5-coder:7b
  
  # Check if pull was successful
  if ! ollama list | grep -q "qwen2.5-coder:7b"; then
    print_message "$RED" "Failed to pull qwen2.5-coder:7b model."
    exit 1
  fi
  
  print_message "$GREEN" "qwen2.5-coder:7b model pulled successfully!"
else
  print_message "$GREEN" "qwen2.5-coder:7b model is already available."
fi

# Create a temporary directory for the Modelfile
TEMP_DIR=$(mktemp -d)
MODELFILE_PATH="$TEMP_DIR/Modelfile"

# Create Modelfile
cat > "$MODELFILE_PATH" << 'EOF'
FROM qwen2.5-coder:7b
PARAMETER num_ctx 131072
EOF

print_message "$YELLOW" "Creating qwen2.5-coder-128k model with extended context window..."

# Check if the extended model already exists
if ollama list | grep -q "qwen2.5-coder-128k"; then
  print_message "$GREEN" "qwen2.5-coder-128k model already exists."
else
  # Create the extended model
  ollama create qwen2.5-coder-128k -f "$MODELFILE_PATH"
  
  # Check if creation was successful
  if ! ollama list | grep -q "qwen2.5-coder-128k"; then
    print_message "$RED" "Failed to create qwen2.5-coder-128k model."
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  
  print_message "$GREEN" "qwen2.5-coder-128k model created successfully!"
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Set up memory optimizations in shell profile
SHELL_PROFILE="$HOME/.zshrc"
OPTIMIZATION_VARS="export OLLAMA_FLASH_ATTENTION=1\nexport OLLAMA_KV_CACHE_TYPE=q8_0\nexport OLLAMA_MAX_INPUT_TOKENS=131072\nexport OLLAMA_CONTEXT_LENGTH=131072"

# Check if optimizations are already in shell profile
if ! grep -q "OLLAMA_FLASH_ATTENTION" "$SHELL_PROFILE" || ! grep -q "OLLAMA_KV_CACHE_TYPE" "$SHELL_PROFILE" || ! grep -q "OLLAMA_MAX_INPUT_TOKENS" "$SHELL_PROFILE"; then
  print_message "$YELLOW" "Adding memory optimization variables to $SHELL_PROFILE..."
  echo -e "\n# Ollama memory optimizations for large context windows" >> "$SHELL_PROFILE"
  echo -e "$OPTIMIZATION_VARS" >> "$SHELL_PROFILE"
  print_message "$GREEN" "Memory optimization variables added to $SHELL_PROFILE."
  print_message "$YELLOW" "Please run 'source $SHELL_PROFILE' to apply these changes to your current shell."
else
  print_message "$GREEN" "Memory optimization variables are already in $SHELL_PROFILE."
fi

# PART 2: OPENWEBUI SETUP
# Create openwebui directory if it doesn't exist
OPENWEBUI_DIR="$HOME/openwebui"
if [[ ! -d "$OPENWEBUI_DIR" ]]; then
  print_message "$YELLOW" "Creating openwebui directory at $OPENWEBUI_DIR"
  mkdir -p "$OPENWEBUI_DIR"
else
  print_message "$GREEN" "OpenWebUI directory already exists at $OPENWEBUI_DIR"
fi

# Change to the openwebui directory
cd "$OPENWEBUI_DIR"
print_message "$GREEN" "Changed to directory: $(pwd)"

# Install uv if not already installed
if ! command_exists uv; then
  print_message "$YELLOW" "Installing uv package manager..."
  brew install uv
else
  print_message "$GREEN" "uv package manager is already installed."
fi

# Check if a virtual environment already exists
if [[ ! -d ".venv" ]]; then
  print_message "$YELLOW" "Setting up a new virtual environment..."
  uv init --python=3.11 .
  uv venv
else
  print_message "$GREEN" "Virtual environment already exists."
fi

# Activate the virtual environment
print_message "$YELLOW" "Activating virtual environment..."
source .venv/bin/activate

# Check if Open WebUI is installed
if ! pip list | grep -q "open-webui"; then
  print_message "$YELLOW" "Installing Open WebUI..."
  uv pip install open-webui
else
  print_message "$GREEN" "Open WebUI is already installed. Checking for updates..."
  uv pip install --upgrade open-webui
fi

# Return to the original directory
cd - > /dev/null

print_message "$GREEN" "✅ Setup complete!"
print_message "$GREEN" "Ollama is set up with Qwen2.5-Coder with 128k context window."
print_message "$GREEN" "OpenWebUI is installed and ready to use."
print_message "$YELLOW" "To run the model directly: ollama run qwen2.5-coder-128k"
print_message "$YELLOW" "To run Open WebUI, go to $OPENWEBUI_DIR, activate the environment and run:"
print_message "$YELLOW" "cd $OPENWEBUI_DIR && source .venv/bin/activate && open-webui serve"
print_message "$YELLOW" "Then access Open WebUI at http://localhost:8080"
print_message "$YELLOW" "For your Mac, be cautious with very large contexts as they may require significant memory."