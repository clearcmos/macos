# macOS .zshrc - Standard configuration with personal customizations

# Path configuration
export PATH="/opt/homebrew/bin:$HOME/.npm-packages/bin:$PATH"

# History configuration
HISTSIZE="10000"
SAVEHIST="10000"
HISTFILE="$HOME/.zsh_history"

# Create history file if it doesn't exist
mkdir -p "$(dirname "$HISTFILE")"

# History options
setopt HIST_FCNTL_LOCK
unsetopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
unsetopt HIST_SAVE_NO_DUPS
unsetopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
unsetopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY
unsetopt EXTENDED_HISTORY

# Enable command completion
autoload -U compinit && compinit

# Set prompt to show hostname
export PS1="%m:%~ %# "

# Enable colors in terminal
export CLICOLOR=1
export LSCOLORS=ExFxBxDxCxegedabagacad

# Load syntax highlighting and autosuggestions
source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# Use Homebrew nano instead of system version
alias nano="/opt/homebrew/bin/nano"

# Source aliases from the macos repository
source /Users/nicholas/git/macos/aliases

# Source all function files from functions.d directory
for function_file in $(pwd)/functions.d/*.sh; do
  if [ -f "$function_file" ]; then
    source "$function_file"
  fi
done
