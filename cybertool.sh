#!/bin/bash
# ================================================
#   cybertool.sh — Entry point utama
#   Jalankan: bash cybertool.sh
# ================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load lib
if [[ ! -f "lib/colors.sh" ]]; then
  echo "ERROR: lib/colors.sh tidak ditemukan!"
  echo "Pastikan lo jalanin dari folder cybertool/"
  echo "Contoh: cd cybertool && bash cybertool.sh"
  exit 1
fi
source lib/colors.sh

# Cek python3
if ! command -v python3 &>/dev/null; then
  echo -e "\033[1;33m[!] python3 tidak ditemukan. Install dulu:\033[0m"
  echo "    pkg install python"
  exit 1
fi

# Load semua modul
for mod in modules/*.sh; do
  source "$mod" 2>/dev/null || echo "Gagal load $mod"
done

main_menu() {
  while true; do
    banner
    echo -e "  ${GREEN}[1]${NC}   Network Scanning & Recon"
    echo -e "  ${GREEN}[2]${NC}   Web App Testing"
    echo -e "  ${GREEN}[3]${NC}   Password & Hash Tools"
    echo -e "  ${GREEN}[4]${NC}   WiFi Scanner"
    echo -e "  ${GREEN}[5]${NC}   CTF Tools"
    echo -e "  ${GREEN}[6]${NC}   Bluetooth Scanner"
    echo -e "  ${GREEN}[7]${NC}   OSINT Tools"
    echo -e "  ${GREEN}[8]${NC}   Remote Access"
    echo -e "  ${GREEN}[9]${NC}   Network Monitor"
    echo -e "  ${GREEN}[10]${NC}  AI Security Assistant"
    echo ""
    echo -e "  ${RED}[0]${NC}   Exit"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r choice
    case $choice in
      1)  network_menu    ;;
      2)  webapp_menu     ;;
      3)  password_menu   ;;
      4)  wifi_menu       ;;
      5)  ctf_menu        ;;
      6)  bluetooth_menu  ;;
      7)  osint_menu      ;;
      8)  remote_menu     ;;
      9)  netmonitor_menu ;;
      10) ai_menu         ;;
      0)  echo -e "\n${CYAN}  Bye!${NC}\n"; exit 0 ;;
      *)  err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

main_menu
