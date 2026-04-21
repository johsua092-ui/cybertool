#!/bin/bash
# modules/adblock.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

HOSTS_DIR="$SCRIPT_ROOT/data/adblock"
HOSTS_OUT="$HOSTS_DIR/hosts.txt"

adblock_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🚫 Ads & Tracker Blocker${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Generate hosts file (download blocklist terbaru)"
    echo -e "  ${GREEN}[2]${NC} Lihat statistik blocklist"
    echo -e "  ${GREEN}[3]${NC} Cek domain — apakah masuk blocklist"
    echo -e "  ${GREEN}[4]${NC} Tambah domain custom ke blocklist"
    echo -e "  ${GREEN}[5]${NC} Export hosts file ke /sdcard"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Hosts file bisa dipakai di router, Pi-hole, atau AdAway${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) adblock_generate ;;
      2) adblock_stats    ;;
      3) adblock_check    ;;
      4) adblock_add      ;;
      5) adblock_export   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

adblock_generate() {
  section "Generate Hosts File"
  mkdir -p "$HOSTS_DIR"

  # sumber blocklist populer
  declare -A SOURCES=(
    ["StevenBlack (Ads+Malware)"]="https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
    ["AdGuard DNS"]="https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt"
    ["EasyList Domains"]="https://v.firebog.net/hosts/Easylist.txt"
    ["Tracking/Analytics"]="https://v.firebog.net/hosts/Easyprivacy.txt"
    ["Malware Domains"]="https://v.firebog.net/hosts/RPiList-Malware.txt"
  )

  total=${#SOURCES[@]}
  current=0
  TMP_ALL=$(mktemp)

  for name in "${!SOURCES[@]}"; do
    ((current++))
    progress_bar $current $total "Downloading"
    url="${SOURCES[$name]}"
    spinner_start "$name"
    result=$(curl -s --max-time 15 "$url" 2>/dev/null)
    spinner_stop "$name"
    if [[ -n "$result" ]]; then
      # extract domain entries
      echo "$result" | grep -E '^(0\.0\.0\.0|127\.0\.0\.1)\s+\S+' | \
        grep -v '0\.0\.0\.0 0\.0\.0\.0' | \
        grep -v '127\.0\.0\.1 localhost' | \
        awk '{print $2}' >> "$TMP_ALL"
      # format domain-only lists
      echo "$result" | grep -E '^\|\|[a-z0-9]' | \
        sed 's/||//' | sed 's/\^.*//' >> "$TMP_ALL"
      ok "$name"
    else
      warn "$name — gagal download"
    fi
  done

  # dedup + sort + tambah custom
  CUSTOM="$HOSTS_DIR/custom.txt"
  {
    echo "# CyberTool Blocklist"
    echo "# Generated: $(date)"
    echo "# Source: StevenBlack + AdGuard + EasyList + Tracking + Malware"
    echo ""
    sort -u "$TMP_ALL"
    [[ -f "$CUSTOM" ]] && cat "$CUSTOM"
  } > "$HOSTS_OUT"

  rm -f "$TMP_ALL"
  COUNT=$(grep -c "^[^#]" "$HOSTS_OUT" 2>/dev/null || echo 0)
  echo ""
  ok "Hosts file dibuat: ${CYAN}$HOSTS_OUT${NC}"
  ok "Total entries: ${GREEN}$COUNT domains${NC} diblokir"
  echo ""
  echo -e "  ${DIM}Cara pakai:${NC}"
  echo -e "  ${DIM}• AdAway (Android root): import file ini${NC}"
  echo -e "  ${DIM}• Pi-hole: pakai sebagai custom blocklist${NC}"
  echo -e "  ${DIM}• Router: replace /etc/hosts${NC}"
  pause
}

adblock_stats() {
  section "Statistik Blocklist"
  if [[ ! -f "$HOSTS_OUT" ]]; then
    warn "Belum ada blocklist. Generate dulu di menu [1]."
    pause; return
  fi
  total=$(grep -c "^[^#]" "$HOSTS_OUT" 2>/dev/null || echo 0)
  size=$(du -sh "$HOSTS_OUT" 2>/dev/null | cut -f1)
  updated=$(grep "Generated:" "$HOSTS_OUT" 2>/dev/null | head -1 | cut -d: -f2-)
  echo -e "  ${CYAN}Total domains${NC} : ${GREEN}$total${NC}"
  echo -e "  ${CYAN}File size${NC}     : $size"
  echo -e "  ${CYAN}Last updated${NC}  :$updated"
  echo ""
  # top TLD yang diblokir
  echo -e "  ${CYAN}Top TLD diblokir:${NC}"
  grep "^[^#]" "$HOSTS_OUT" | grep -oP '\.[a-z]{2,6}$' | \
    sort | uniq -c | sort -rn | head -8 | \
    awk '{printf "    %-6s %s\n", $2, $1}'
  pause
}

adblock_check() {
  section "Cek Domain"
  if [[ ! -f "$HOSTS_OUT" ]]; then
    warn "Generate blocklist dulu di menu [1]."
    pause; return
  fi
  echo -ne "${WHITE}  Domain${NC}: "
  read -r domain
  [[ -z "$domain" ]] && { err "Kosong!"; pause; return; }
  domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
  if grep -qx "$domain" "$HOSTS_OUT" 2>/dev/null; then
    echo -e "\n  ${RED}[BLOCKED]${NC} $domain ada di blocklist"
  else
    echo -e "\n  ${GREEN}[CLEAN]${NC} $domain tidak ada di blocklist"
  fi
  pause
}

adblock_add() {
  section "Tambah Domain Custom"
  mkdir -p "$HOSTS_DIR"
  echo -e "  ${DIM}Masukkan domain satu per baris, ketik END setelah selesai${NC}\n"
  CUSTOM="$HOSTS_DIR/custom.txt"
  added=0
  while true; do
    echo -ne "  Domain: "
    read -r d
    [[ "$d" == "END" || -z "$d" ]] && break
    d=$(echo "$d" | tr '[:upper:]' '[:lower:]' | sed 's|https\?://||' | cut -d'/' -f1)
    echo "$d" >> "$CUSTOM"
    ok "Ditambahkan: $d"
    ((added++))
  done
  ok "$added domain ditambahkan ke custom list"
  info "Jalankan menu [1] lagi buat rebuild hosts file"
  pause
}

adblock_export() {
  section "Export ke /sdcard"
  if [[ ! -f "$HOSTS_OUT" ]]; then
    warn "Generate blocklist dulu di menu [1]."
    pause; return
  fi
  DEST="/sdcard/Download/cybertool_hosts.txt"
  cp "$HOSTS_OUT" "$DEST" 2>/dev/null
  if [[ $? -eq 0 ]]; then
    ok "Tersimpan di: ${CYAN}$DEST${NC}"
  else
    err "Gagal copy ke /sdcard. Coba manual:"
    info "cp $HOSTS_OUT /sdcard/Download/"
  fi
  pause
}
