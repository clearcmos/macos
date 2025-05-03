# Navigation related functions

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