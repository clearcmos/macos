# Git related functions

pushmac() {
  git add .
  
  if [ -z "$(git diff --cached)" ]; then
    echo "No changes staged for commit."
    return 1
  fi
  
  git diff --cached > /tmp/git_diff.txt
  
  if [ ! -s /tmp/git_diff.txt ]; then
    echo "No changes to commit."
    rm /tmp/git_diff.txt
    return 1
  fi
  
  local commit_message=$(ollama run qwen2.5-coder:7b "Generate only a concise git commit message (max 1 line, no quotation marks or backticks) for this diff: $(cat /tmp/git_diff.txt)" | grep -v "^Here is" | grep -v "^I would" | head -n 1 | sed 's/`//g')
  
  rm /tmp/git_diff.txt
  
  echo "$commit_message"
  echo "Press ENTER to confirm, or 'r' to enter your own message:"
  read response
  
  if [[ "$response" == "r" ]]; then
    echo "Enter your commit message:"
    read custom_message
    commit_message="$custom_message"
  fi
  
  git commit -m "$commit_message"
  
  git push
  
  echo "Changes committed and pushed successfully."
}
