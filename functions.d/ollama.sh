oserve() {
  if pgrep -f "ollama serve" > /dev/null; then
    echo "🟡 Ollama is already running in the background."
    read "resp?❓ Do you want to stop it? (y/n): "
    if [[ "$resp" =~ ^[Yy]$ ]]; then
      pkill -f "ollama serve" && echo "🛑 Ollama has been stopped."
    else
      echo "ℹ️  Ollama will keep running."
    fi
    return
  fi

  nohup ollama serve > /dev/null 2>&1 & disown

  sleep 1

  if pgrep -f "ollama serve" > /dev/null; then
    echo "✅ Ollama has been started successfully in the background."
  else
    echo "❌ Failed to start Ollama."
  fi
}

