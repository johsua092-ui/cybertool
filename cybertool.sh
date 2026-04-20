#!/bin/bash
# ================================================
#   cybertool.sh — Entry point utama
#   Jalankan: bash cybertool.sh
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source lib/colors.sh
source modules/network.sh
source modules/webapp.sh
source modules/password.sh
source modules/wifi.sh
source modules/ctf.sh
source modules/bluetooth.sh
source modules/osint.sh
source modules/remote.sh

main_menu() {
  while true; do
    banner
    echo -e "  ${GREEN}[1]${NC}  🌐  Network Scanning & Recon"
    echo -e "  ${GREEN}[2]${NC}  🕸️   Web App Testing"
    echo -e "  ${GREEN}[3]${NC}  🔑  Password & Hash Tools"
    echo -e "  ${GREEN}[4]${NC}  📡  WiFi Scanner"
    echo -e "  ${GREEN}[5]${NC}  🚩  CTF Tools"
    echo -e "  ${GREEN}[6]${NC}  🔵  Bluetooth Scanner"
    echo -e "  ${GREEN}[7]${NC}  🕵️   OSINT Tools"
    echo -e "  ${GREEN}[8]${NC}  🖥️   Remote Access"
    echo ""
    echo -e "  ${RED}[0]${NC}  ❌  Exit"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r choice
    case $choice in
      1) network_menu   ;;
      2) webapp_menu    ;;
      3) password_menu  ;;
      4) wifi_menu      ;;
      5) ctf_menu       ;;
      6) bluetooth_menu ;;
      7) osint_menu     ;;
      8) remote_menu    ;;
      0) echo -e "\n${CYAN}  Bye! Stay legal 👋${NC}\n"; exit 0 ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

main_menu
