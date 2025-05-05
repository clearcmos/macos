repo() {
  local dirs=() i=1 choice dir

  while IFS= read -r dir; do
    dirs+=("$dir")
    echo "$i. $(basename "$dir")"
    ((i++))
  done < <(find ~/git -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort -f)

  echo "Found ${#dirs[@]} directories"

  read "choice?Choose a directory number: "
  if [[ "$choice" =~ '^[0-9]+$' ]] && (( choice >= 1 && choice <= $#dirs )); then
    cd "${dirs[choice-1]}"
  else
    echo "Invalid choice."
  fi
}
