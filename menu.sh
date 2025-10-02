#!/bin/bash

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
WHITE="\033[1;37m"
RESET="\033[0m"

sha256_key=""
BACKUP_DIR="$HOME/Backup_home_$(date +%Y-%m-%d)"

check_root() {
    if [ "$EUID" -eq 0 ]; then
        echo -e "${WHITE}[${RED}!${WHITE}] ${RED}Do not run as root. Exiting.${RESET}"
        exit 1
    else
        echo -e "${BLUE}[${GREEN}+${BLUE}] ${GREEN}Not running as root.${RESET}"
    fi
}

check_internet() {
    if ping -c 1 google.com &> /dev/null; then
        echo -e "${BLUE}[${GREEN}+${BLUE}] ${GREEN}Internet connection detected.${RESET}"
    else
        echo -e "${WHITE}[${RED}!${WHITE}] ${RED}No internet connection.${RESET}"
        exit 1
    fi
}

# check
check_root
check_internet


progress_bar_start() {
    PROGRESS_START_TIME=$(date +%s)
}

progress_bar() {
    local current="$1"
    local total="$2"
    local width=40
    local percent=$((current * 100 / total))
    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    local now elapsed eta
    now=$(date +%s)
    elapsed=$((now - PROGRESS_START_TIME))
    if (( current > 0 )); then
        eta=$((elapsed * (total - current) / current))
    else
        eta=0
    fi

    local eta_h=$((eta / 3600))
    local eta_m=$(((eta % 3600) / 60))
    local eta_s=$((eta % 60))

    printf "\r["
    for ((i=0;i<filled;i++)); do printf "█"; done
    for ((i=0;i<empty;i++)); do printf " "; done
    printf "] %d%% (%d/%d) ETA %02d:%02d:%02d" "$percent" "$current" "$total" "$eta_h" "$eta_m" "$eta_s"
}

count_file_types() {
    local dir="$1"

    local total_dirs total_files pdf_files txt_files png_files jpg_files webp_files py_files pyc_files other_files

    total_dirs=$(find "$dir" -type d | wc -l)
    total_files=$(find "$dir" -type f | wc -l)
    pdf_files=$(find "$dir" -type f -iname "*.pdf" | wc -l)
    txt_files=$(find "$dir" -type f -iname "*.txt" | wc -l)
    png_files=$(find "$dir" -type f -iname "*.png" | wc -l)
    jpg_files=$(find "$dir" -type f -iname "*.jpg" | wc -l)
    webp_files=$(find "$dir" -type f -iname "*.webp" | wc -l)
    py_files=$(find "$dir" -type f -iname "*.py" | wc -l)
    pyc_files=$(find "$dir" -type f -iname "*.pyc" | wc -l)
    BACKUP_DIR_SIZE=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
    other_files=$((total_files - pdf_files - txt_files - png_files - jpg_files - webp_files - py_files - pyc_files))

    echo -e "${BLUE}============ Backup stats ============${RESET}"
    echo -e "${BLUE}|-Directories: ${WHITE}$total_dirs"
    echo -e "${BLUE}|-PDF files: ${WHITE}$pdf_files"
    echo -e "${BLUE}|-TXT files: ${WHITE}$txt_files"
    echo -e "${BLUE}|-PNG files: ${WHITE}$png_files"
    echo -e "${BLUE}|-JPG files: ${WHITE}$jpg_files"
    echo -e "${BLUE}|-WEBP files: ${WHITE}$webp_files"
    echo -e "${BLUE}|-PY files: ${WHITE}$py_files"
    echo -e "${BLUE}|-PYC files: ${WHITE}$pyc_files"
    echo -e "${BLUE}|-Other files: ${WHITE}$other_files"
    echo -e "${BLUE}|-Total Files: ${WHITE}$total_files"
    echo -e "${BLUE}|-Backup Size: ${WHITE}$BACKUP_DIR_SIZE${RESET}"     # total size of backup dir
    echo -e "${BLUE}=======================================${RESET}"
}

backup_files() {
    echo -e "${BLUE}[${YELLOW}!${BLUE}] Starting backup to : ${WHITE}$BACKUP_DIR...${RESET}"
    mkdir -p "$BACKUP_DIR"
    echo -e "${BLUE}[${GREEN}+${BLUE}]${GREEN} Created backup dir to :${WHITE} $BACKUP_DIR"

    # except backup dir and anything containing 'venv' (VENV accepted)
    mapfile -t file_list < <(find "$HOME" -mindepth 1 -maxdepth 1 ! -path "$BACKUP_DIR" ! -iname "*venv*")
    local total="${#file_list[@]}"
    local counter=0

    progress_bar_start
    for f in "${file_list[@]}"; do
        cp -a "$f" "$BACKUP_DIR/"
        ((counter++))
        progress_bar "$counter" "$total"
    done

    echo -e "\n${BLUE}[${GREEN}+${BLUE}]${GREEN} Backup finished! All files copied to: ${WHITE}$BACKUP_DIR${RESET}"
    count_file_types "$BACKUP_DIR"
}

backup_and_zip() {
    backup_files

    local zip_file
    zip_file="$HOME/Backup_home_$(date +%Y-%m-%d_%H%M%S).zip"

    echo -e "${BLUE}[${YELLOW}!${BLUE}] Creating zip file :${WHITE} $zip_file ${RESET}"

    mapfile -t file_list < <(find "$BACKUP_DIR" -type f)
    local total="${#file_list[@]}"
    local counter=0

    progress_bar_start
    for f in "${file_list[@]}"; do
        zip -q "$zip_file" "$f"
        ((counter++))
        progress_bar "$counter" "$total"
    done
    echo -e "\n${BLUE}[${GREEN}+${BLUE}] ${GREEN}Zip finished:${WHITE}$zip_file${RESET}"
}

backup_and_encrypt() {
    backup_files

    local key
    if [[ -n "$sha256_key" ]]; then
        key="$sha256_key"
    else
        while true; do
            read -rsp "[!] Enter 32-byte key for SHA256 encryption >" key
            echo
            if [[ "${#key}" -eq 32 ]]; then
                break
            else
                echo -e "${WHITE}[${RED}!${WHITE}] ${RED}Key must be exactly 32 bytes.${RESET}"
            fi
        done
    fi

    local enc_file
    enc_file="$HOME/Backup_home_enc_$(date +%Y-%m-%d_%H%M%S).tar.gz.enc"
    echo -e "${BLUE}[${YELLOW}!${BLUE}] Encrypting files ..${RESET}"

    mapfile -t file_list < <(find "$BACKUP_DIR" -type f)
    local total="${#file_list[@]}"
    local counter=0

    progress_bar_start
    for f in "${file_list[@]}"; do
        tar -czf - "$f" | openssl enc -aes-256-cbc -K "$(echo -n "$key" | xxd -p)" \
        -iv 00000000000000000000000000000000 >> "$enc_file"
        ((counter++))
        progress_bar "$counter" "$total"
    done

    echo -e "\n${BLUE}[${GREEN}+{BLUE] ${GREEN}Encryption finished: ${GREEN} $enc_file  ${RESET}"
}

while true; do
    clear
    echo -e "\n${WHITE}=========== Backup Menu ===========${RESET}"
    echo -e "${BLUE}[${WHITE}1${BLUE}] ${WHITE}Backup & zip"
    echo -e "${BLUE}[${WHITE}2${BLUE}] ${WHITE}Backup & encrypt"
    echo -e "${BLUE}[${WHITE}3${BLUE}] ${WHITE}Backup only ${RESET}"
    echo -e "${BLUE}[${WHITE}4${BLUE}] ${WHITE}Exit"
    echo -e ""
    read -r -p "[!] Choose an option >" opt

    case "$opt" in
        1) backup_and_zip ;;
        2) backup_and_encrypt ;;
        3) backup_files ;;
        4) echo -e "${BLUE}[${GREEN}+${BLUE}] ${GREEN}Exiting.${RESET}"; exit 0 ;;
        *) echo -e "${WHITE}[${RED}!${WHITE}] ${RED}Invalid option .${RESET}" ;;
    esac
done
