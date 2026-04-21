#!/bin/bash
# modules/portknock.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

KNOCK_PROFILES="$SCRIPT_ROOT/data/portknock"

portknock_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🚫 Port Knocking${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Knock sequence — buka port tersembunyi"
    echo -e "  ${GREEN}[2]${NC} Simpan profil knock"
    echo -e "  ${GREEN}[3]${NC} Load & jalankan profil"
    echo -e "  ${GREEN}[4]${NC} Setup knockd di server (panduan)"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Port knocking = ketuk urutan port rahasia${NC}"
    echo -e "  ${DIM}   buat unlock akses (biasanya SSH) di server${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) knock_manual  ;;
      2) knock_save    ;;
      3) knock_load    ;;
      4) knock_guide   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

do_knock() {
  local host="$1"
  local ports="$2"   # space-separated
  local proto="$3"   # tcp/udp

  info "Knocking $host dengan sequence: ${CYAN}$ports${NC} ($proto)\n"

  # cek tool
  local knock_tool=""
  if command -v knock &>/dev/null; then
    knock_tool="knock"
  elif command -v nc &>/dev/null; then
    knock_tool="nc"
  else
    err "Butuh 'knock' atau 'nc'. Install: pkg install knock netcat-openbsd"
    return 1
  fi

  local i=1
  local total=$(echo $ports | wc -w)

  for port in $ports; do
    progress_bar $i $total "Knocking"
    if [[ "$knock_tool" == "knock" ]]; then
      if [[ "$proto" == "udp" ]]; then
        knock -u "$host" "$port" 2>/dev/null
      else
        knock "$host" "$port" 2>/dev/null
      fi
    else
      # nc fallback
      if [[ "$proto" == "udp" ]]; then
        echo "" | nc -u -w1 "$host" "$port" 2>/dev/null
      else
        nc -w1 "$host" "$port" 2>/dev/null </dev/null
      fi
    fi
    sleep 0.3
    ((i++))
  done
  echo ""
  ok "Sequence selesai!"
}

knock_manual() {
  section "Manual Port Knock"
  echo -ne "${WHITE}  Target IP/host${NC}: "
  read -r host
  [[ -z "$host" ]] && { err "Kosong!"; pause; return; }

  echo -ne "${WHITE}  Port sequence${NC} (pisah spasi, contoh: 7000 8000 9000): "
  read -r ports
  [[ -z "$ports" ]] && { err "Kosong!"; pause; return; }

  echo -ne "${WHITE}  Protocol${NC} [tcp/udp, default tcp]: "
  read -r proto
  proto=${proto:-tcp}

  do_knock "$host" "$ports" "$proto"

  echo ""
  echo -ne "${WHITE}  Cek SSH setelah knock? [y/N]${NC}: "
  read -r yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    echo -ne "${WHITE}  Username SSH${NC}: "
    read -r user
    echo -ne "${WHITE}  Port SSH${NC} [default 22]: "
    read -r sshport
    sshport=${sshport:-22}
    info "Connecting SSH..."
    ssh "$user@$host" -p "$sshport"
  fi
  pause
}

knock_save() {
  section "Simpan Profil Knock"
  mkdir -p "$KNOCK_PROFILES"
  echo -ne "${WHITE}  Nama profil${NC}: "
  read -r name
  [[ -z "$name" ]] && { err "Kosong!"; pause; return; }

  echo -ne "${WHITE}  Target IP/host${NC}: "
  read -r host
  echo -ne "${WHITE}  Port sequence${NC}: "
  read -r ports
  echo -ne "${WHITE}  Protocol${NC} [tcp/udp]: "
  read -r proto
  proto=${proto:-tcp}
  echo -ne "${WHITE}  Port SSH setelah knock${NC} [default 22]: "
  read -r sshport
  sshport=${sshport:-22}
  echo -ne "${WHITE}  Username SSH${NC}: "
  read -r user

  cat > "$KNOCK_PROFILES/${name}.conf" << CONF
HOST=$host
PORTS=$ports
PROTO=$proto
SSH_PORT=$sshport
SSH_USER=$user
CONF

  ok "Profil '$name' disimpan!"
  pause
}

knock_load() {
  section "Load Profil"
  mkdir -p "$KNOCK_PROFILES"
  FILES=("$KNOCK_PROFILES"/*.conf 2>/dev/null)
  if [[ ! -f "${FILES[0]}" ]]; then
    warn "Belum ada profil. Buat dulu di menu [2]."
    pause; return
  fi

  for i in "${!FILES[@]}"; do
    name=$(basename "${FILES[$i]}" .conf)
    source "${FILES[$i]}" 2>/dev/null
    echo -e "  ${GREEN}[$((i+1))]${NC} $name  ${DIM}($HOST — $PORTS)${NC}"
  done
  echo ""
  echo -ne "${WHITE}  Pilih profil${NC}: "
  read -r idx
  idx=$((idx-1))
  [[ $idx -lt 0 || $idx -ge ${#FILES[@]} ]] && { err "Tidak valid!"; pause; return; }

  source "${FILES[$idx]}"
  do_knock "$HOST" "$PORTS" "$PROTO"

  echo ""
  echo -ne "${WHITE}  Connect SSH setelah knock? [y/N]${NC}: "
  read -r yn
  [[ "$yn" =~ ^[Yy]$ ]] && ssh "$SSH_USER@$HOST" -p "$SSH_PORT"
  pause
}

knock_guide() {
  section "Setup knockd di Server"
  echo -e "  ${DIM}Install knockd di server Linux lo:${NC}\n"
  echo -e "  ${CYAN}# Debian/Ubuntu:${NC}"
  echo -e "  sudo apt install knockd\n"
  echo -e "  ${CYAN}# Config /etc/knockd.conf:${NC}"
  cat << 'CONF'
  [options]
      UseSyslog

  [openSSH]
      sequence    = 7000,8000,9000
      seq_timeout = 10
      command     = /sbin/iptables -A INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
      tcpflags    = syn

  [closeSSH]
      sequence    = 9000,8000,7000
      seq_timeout = 10
      command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -j ACCEPT
      tcpflags    = syn
CONF
  echo ""
  echo -e "  ${CYAN}# Aktifkan knockd:${NC}"
  echo -e "  sudo systemctl enable knockd"
  echo -e "  sudo systemctl start knockd\n"
  echo -e "  ${CYAN}# Block SSH default dulu di firewall:${NC}"
  echo -e "  sudo iptables -A INPUT -p tcp --dport 22 -j DROP\n"
  echo -e "  ${DIM}Setelah itu, SSH lo cuma bisa dibuka dengan knock${NC}"
  echo -e "  ${DIM}sequence 7000 → 8000 → 9000 dari HP!${NC}"
  pause
}
