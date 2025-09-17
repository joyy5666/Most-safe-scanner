#!/bin/bash
# Script Safety System with Menu
# Language: Bash

LOGFILE="safety_scan.log"
DANGEROUS_CMDS=("rm -rf" "mkfs" ":(){ :|:& };:" "dd if=" "chmod 777 /" "chown root" "wget http" "curl http")

scan_script() {
    echo "Enter script path to scan:"
    read -r script
    if [[ ! -f "$script" ]]; then
        echo "File not found!"
        return
    fi
    echo "Scanning $script..."
    echo "----- Scan started at $(date) -----" >> "$LOGFILE"
    found=false
    while IFS= read -r line; do
        for cmd in "${DANGEROUS_CMDS[@]}"; do
            if [[ "$line" == *"$cmd"* ]]; then
                echo "[!] Dangerous command found: $cmd"
                echo "Line: $line" >> "$LOGFILE"
                found=true
            fi
        done
    done < "$script"
    if [ "$found" = false ]; then
        echo "No dangerous commands detected."
        echo "No issues found." >> "$LOGFILE"
    fi
    echo "Scan completed. Log saved to $LOGFILE"
}

safe_run() {
    echo "Enter script path to safely run:"
    read -r script
    if [[ ! -f "$script" ]]; then
        echo "File not found!"
        return
    fi
    echo "Running $script in restricted shell..."
    bash --restricted "$script"
}

view_logs() {
    if [[ -f "$LOGFILE" ]]; then
        echo "---- Safety Logs ----"
        cat "$LOGFILE"
    else
        echo "No logs available."
    fi
}

menu() {
    while true; do
        echo "============================="
        echo "  Script Safety System Menu"
        echo "============================="
        echo "1) Scan a script"
        echo "2) Run a script in safe mode"
        echo "3) View logs"
        echo "4) Exit"
        echo -n "Choose an option: "
        read -r choice
        case $choice in
            1) scan_script ;;
            2) safe_run ;;
            3) view_logs ;;
            4) echo "Goodbye!"; exit 0 ;;
            *) echo "Invalid option, try again." ;;
        esac
    done
}

menu
