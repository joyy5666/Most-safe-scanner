#!/bin/bash
# BEAST SCANNER v1.0
# Author: Hasnain
# Ultimate Safety Scanner – fully upgraded

LOGFILE="$HOME/beast_safety_scan.log"
SAFERUNLOG="$HOME/beast_safe_run.log"
QUARANTINE_DIR="$HOME/beast_quarantine"
DANGEROUS_CMDS=("rm -rf" "mkfs" ":(){ :|:& };:" "dd if=" "chmod 777 /" "chown root" "wget http" "curl http")
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$QUARANTINE_DIR"

# === ALERT FUNCTION ===
alert() {
    # Termux Toast
    if command -v termux-toast &>/dev/null; then
        termux-toast "$1" --duration long
    fi
    # Termux Notification
    if command -v termux-notification &>/dev/null; then
        termux-notification -t "BEAST SCANNER ALERT" -c "$1"
    fi
    # Webhook Alert Placeholder (Telegram/Discord)
    # curl -s -X POST -H "Content-Type: application/json" -d '{"content":"'"$1"'"}' <WEBHOOK_URL>
}

# === SCAN SINGLE SCRIPT ===
scan_script() {
    local script="$1"
    if [[ -z "$script" ]]; then
        echo -n "Enter script path to scan: "
        read -r script
    fi
    if [[ ! -f "$script" ]]; then
        echo -e "${RED}File not found!${NC}"
        return
    fi
    echo -e "${YELLOW}Scanning $script...${NC}"
    echo "----- Scan started at $(date) -----" >> "$LOGFILE"
    found=false
    while IFS= read -r line; do
        for cmd in "${DANGEROUS_CMDS[@]}"; do
            if [[ "$line" == *"$cmd"* ]]; then
                echo -e "${RED}[!] Dangerous command found: $cmd${NC}"
                echo "Script: $script | Line: $line" >> "$LOGFILE"
                alert "[ALERT] Dangerous command detected: $cmd in $script"
                found=true
            fi
        done
        # Placeholder AI detection
        # if [[ $(python3 ai_detect.py "$line") == "danger" ]]; then
        #     echo -e "${RED}[AI ALERT] Suspicious code detected${NC}"
        #     found=true
        # fi
    done < "$script"

    if [[ "$found" = true ]]; then
        echo -e "${RED}Moving $script to quarantine...${NC}"
        mv "$script" "$QUARANTINE_DIR/"
        echo "Moved $script to $QUARANTINE_DIR" >> "$LOGFILE"
    else
        echo -e "${GREEN}No dangerous commands detected.${NC}"
        echo "No issues found in $script" >> "$LOGFILE"
    fi
    echo "Scan completed. Log saved to $LOGFILE"
}

# === SCAN MULTIPLE SCRIPTS IN FOLDER ===
scan_folder() {
    echo -n "Enter folder path to scan: "
    read -r folder
    if [[ ! -d "$folder" ]]; then
        echo -e "${RED}Folder not found!${NC}"
        return
    fi
    for f in "$folder"/*.sh; do
        [[ -f "$f" ]] && scan_script "$f"
    done
}

# === SAFE RUN SCRIPT ===
safe_run() {
    echo -n "Enter script path to safely run: "
    read -r script
    if [[ ! -f "$script" ]]; then
        echo -e "${RED}File not found!${NC}"
        return
    fi
    echo -e "${YELLOW}Running $script in restricted shell...${NC}"
    bash --restricted "$script"
    echo "$(date) - $USER ran $script in safe mode" >> "$SAFERUNLOG"
}

# === VIEW LOGS ===
view_logs() {
    if [[ -f "$LOGFILE" ]]; then
        echo -e "${YELLOW}---- Safety Logs ----${NC}"
        cat "$LOGFILE"
    else
        echo -e "${RED}No logs available.${NC}"
    fi
}

# === VIEW QUARANTINE ===
view_quarantine() {
    echo -e "${YELLOW}---- Quarantine Folder ----${NC}"
    ls -lh "$QUARANTINE_DIR"
}

# === CLEAR LOGS ===
clear_logs() {
    > "$LOGFILE"
    > "$SAFERUNLOG"
    echo -e "${GREEN}Logs cleared.${NC}"
}

# === AUTO-SCAN SCHEDULER ===
auto_scan_scheduler() {
    echo -n "Enter folder to auto-scan every 60s: "
    read -r folder
    echo -e "${YELLOW}Starting auto-scan scheduler for $folder...${NC}"
    while true; do
        scan_folder "$folder"
        sleep 60
    done
}

# === DASHBOARD ===
dashboard() {
    while true; do
        clear
        echo -e "${YELLOW}=== BEAST SCANNER DASHBOARD ===${NC}"
        date
        echo -e "${GREEN}Quarantine count:$(ls "$QUARANTINE_DIR" | wc -l)${NC}"
        echo -e "${GREEN}Total logs entries: $(wc -l < "$LOGFILE")${NC}"
        echo -e "${GREEN}Safe-run logs: $(wc -l < "$SAFERUNLOG")${NC}"
        echo "-------------------------------"
        sleep 10
    done
}

# === MENU ===
menu() {
    while true; do
        echo -e "\n============================="
        echo "      BEAST SCANNER MENU"
        echo "============================="
        echo "1) Scan a script"
        echo "2) Scan folder/multiple scripts"
        echo "3) Run script in safe mode"
        echo "4) View safety logs"
        echo "5) View quarantine folder"
        echo "6) Clear logs"
        echo "7) Start auto-scan scheduler"
        echo "8) Open dashboard (live stats)"
        echo "9) Exit"
        echo -n "Choose an option: "
        read -r choice
        case $choice in
            1) scan_script ;;
            2) scan_folder ;;
            3) safe_run ;;
            4) view_logs ;;
            5) view_quarantine ;;
            6) clear_logs ;;
            7) auto_scan_scheduler ;;
            8) dashboard ;;
            9) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option, try again.${NC}" ;;
        esac
    done
}

# === START MENU ===
menu
