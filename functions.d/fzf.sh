# Navigation related functions

c() {
    local selected_file
    
    if [ -z "$1" ]; then
        selected_file=$(fzf)
    else
        selected_file=$(cd "$1" && fzf)
    fi
    
    if [ -n "$selected_file" ]; then
        if [ -r "$selected_file" ]; then
            cat "$selected_file"
        else
            echo "You don't have read permission for $selected_file"
            echo "Try: sudo cat \"$selected_file\""
        fi
    fi
}

g() {
    local selected_file
    local target_dir
    
    if [ -z "$1" ]; then
        selected_file=$(fzf)
    else
        selected_file=$(cd "$1" && fzf)
    fi
    
    if [ -n "$selected_file" ]; then
        target_dir=$(dirname "$selected_file")
        
        if [ -d "$target_dir" ] && [ -x "$target_dir" ]; then
            cd "$target_dir" && ls
        else
            echo "You don't have permission to access $target_dir"
            echo "Consider running: sudo -i"
            echo "Then navigate to the directory manually"
        fi
    fi
}

n() {
    local selected_file
    
    if [ -z "$1" ]; then
        selected_file=$(fzf)
    else
        selected_file=$(cd "$1" && fzf)
    fi
    
    if [ -n "$selected_file" ]; then
        if [ -w "$selected_file" ] || [ ! -e "$selected_file" ]; then
            nano "$selected_file"
        else
            sudo nano "$selected_file"
        fi
    fi
}
