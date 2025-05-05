# Homebrew related functions

b() {
  local pkgname
  if [ -n "$1" ]; then
    pkgname="$1"
  else
    echo "Search for: "
    read pkgname
  fi
  
  brew search "$pkgname" &> /dev/null || { echo; echo "No formulae or casks found for $pkgname. Skipping info."; return 1; }
  
  local brew_info
  brew_info=$(brew info "$pkgname")
  echo "$brew_info"
  
  if [[ "$brew_info" =~ "Error: No available formula with the name" ]]; then
    echo "No available formula with this name."
    return 1
  elif [[ "$brew_info" =~ "Not installed" ]]; then
    echo "Package '$pkgname' not installed. Install it? (y/n)"
    read -r install_choice
    if [ "$install_choice" = "y" ]; then
      brew install "$pkgname"

      PACKAGES_FILE="/Users/$(whoami)/git/macos/packages.txt"
      if [ ! -f "$PACKAGES_FILE" ]; then
        echo "$pkgname" > "$PACKAGES_FILE"
      else
        if grep -q "^$pkgname$" "$PACKAGES_FILE"; then
          echo "Package already in $PACKAGES_FILE"
        else
          if [ -s "$PACKAGES_FILE" ] && [ "$(tail -c1 "$PACKAGES_FILE" | wc -l)" -eq 0 ]; then
            echo "" >> "$PACKAGES_FILE"
          fi
          echo "$pkgname" >> "$PACKAGES_FILE"
          sort -o "$PACKAGES_FILE" "$PACKAGES_FILE"
          echo "Added $pkgname to $PACKAGES_FILE"
        fi
      fi
    else
      echo "Skipping installation."
    fi
  else
    echo "Package already installed. Uninstall it? (y/n)"
    read -r uninstall_choice
    if [ "$uninstall_choice" = "y" ]; then
      brew uninstall --force "$pkgname"
      
      PACKAGES_FILE="/Users/$(whoami)/git/macos/packages.txt"
      if [ -f "$PACKAGES_FILE" ] && grep -q "^$pkgname$" "$PACKAGES_FILE"; then
        sed -i '' "/^$pkgname$/d" "$PACKAGES_FILE"
        echo "Removed $pkgname from $PACKAGES_FILE"
      fi
    fi
  fi
}