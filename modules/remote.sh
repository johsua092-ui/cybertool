#!/bin/bash
# modules/remote.sh

remote_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🖥️  Remote Access${NC}"
    echo ""
    echo -e "  ${YELLOW}── HP → Laptop ──${NC}"
    echo -e "  ${GREEN}[1]${NC} SSH masuk ke laptop dari HP"
    echo -e "  ${GREEN}[2]${NC} Kirim file dari HP ke laptop"
    echo -e "  ${GREEN}[3]${NC} Ambil file dari laptop ke HP"
    echo ""
    echo -e "  ${YELLOW}── Laptop → HP ──${NC}"
    echo -e "  ${GREEN}[4]${NC} Jalankan SSH server di HP (biar laptop bisa masuk)"
    echo -e "  ${GREEN}[5]${NC} Info koneksi SSH server HP"
    echo -e "  ${GREEN}[6]${NC} Stop SSH server"
    echo ""
    echo -e "  ${YELLOW}── Tunnel (beda jaringan / internet) ──${NC}"
    echo -e "  ${GREEN}[7]${NC} Reverse tunnel — akses HP dari laptop via internet"
    echo -e "  ${GREEN}[8]${NC} Reverse tunnel — akses laptop dari HP via internet"
    echo ""
    echo -e "  ${DIM}ℹ  Semua fitur no root. Butuh koneksi WiFi/internet.${NC}"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) remote_ssh_to_laptop  ;;
      2) remote_send_file      ;;
      3) remote_get_file       ;;
      4) remote_start_server   ;;
      5) remote_server_info    ;;
      6) remote_stop_server    ;;
      7) remote_tunnel_phone   ;;
      8) remote_tunnel_laptop  ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────
remote_ssh_to_laptop() {
  section "SSH → Laptop"
  check_tool ssh || return

  echo -ne "${WHITE}  IP laptop${NC}: "
  read -r host
  [[ -z "$host" ]] && { err "IP kosong!"; pause; return; }

  echo -ne "${WHITE}  Username laptop${NC}: "
  read -r user
  [[ -z "$user" ]] && { err "Username kosong!"; pause; return; }

  echo -ne "${WHITE}  Port SSH${NC} [default 22]: "
  read -r port
  port=${port:-22}

  info "Connecting ke $user@$host:$port ..."
  echo -e "${DIM}  (ketik 'exit' untuk keluar dari sesi SSH)${NC}\n"
  ssh -p "$port" "$user@$host"
  echo ""
  ok "Sesi SSH selesai."
  pause
}

# ─────────────────────────────────────────
remote_send_file() {
  section "Kirim File HP → Laptop"
  check_tool scp || return

  echo -ne "${WHITE}  File yang mau dikirim${NC}: "
  read -r filepath
  [[ ! -f "$filepath" ]] && { err "File tidak ada!"; pause; return; }

  echo -ne "${WHITE}  IP laptop${NC}: "
  read -r host
  [[ -z "$host" ]] && { err "IP kosong!"; pause; return; }

  echo -ne "${WHITE}  Username laptop${NC}: "
  read -r user

  echo -ne "${WHITE}  Tujuan di laptop${NC} (contoh: /home/user/Downloads/): "
  read -r dest
  dest=${dest:-"~/"}

  echo -ne "${WHITE}  Port SSH${NC} [default 22]: "
  read -r port
  port=${port:-22}

  info "Mengirim $(basename "$filepath") ke $user@$host:$dest ..."
  scp -P "$port" "$filepath" "$user@$host:$dest"
  [[ $? -eq 0 ]] && ok "File berhasil dikirim!" || err "Gagal kirim file."
  pause
}

# ─────────────────────────────────────────
remote_get_file() {
  section "Ambil File Laptop → HP"
  check_tool scp || return

  echo -ne "${WHITE}  IP laptop${NC}: "
  read -r host
  [[ -z "$host" ]] && { err "IP kosong!"; pause; return; }

  echo -ne "${WHITE}  Username laptop${NC}: "
  read -r user

  echo -ne "${WHITE}  Path file di laptop${NC} (contoh: /home/user/file.txt): "
  read -r remotefile
  [[ -z "$remotefile" ]] && { err "Path kosong!"; pause; return; }

  echo -ne "${WHITE}  Simpan di HP${NC} [default: folder sekarang]: "
  read -r dest
  dest=${dest:-.}

  echo -ne "${WHITE}  Port SSH${NC} [default 22]: "
  read -r port
  port=${port:-22}

  info "Mengambil $remotefile dari $host ..."
  scp -P "$port" "$user@$host:$remotefile" "$dest"
  [[ $? -eq 0 ]] && ok "File berhasil diambil → $dest" || err "Gagal ambil file."
  pause
}

# ─────────────────────────────────────────
remote_start_server() {
  section "SSH Server di HP"

  # cek openssh
  if ! command -v sshd &>/dev/null; then
    warn "OpenSSH belum terinstall."
    info "Install sekarang? (butuh koneksi internet)"
    echo -ne "${WHITE}  Install? [y/N]${NC}: "
    read -r yn
    if [[ "$yn" =~ ^[Yy]$ ]]; then
      pkg install -y openssh
    else
      pause; return
    fi
  fi

  # setup password kalau belum
  echo ""
  info "SSH server butuh password buat login."
  echo -ne "${WHITE}  Set/ganti password SSH${NC}: "
  passwd
  echo ""

  # generate host key kalau belum ada
  if [[ ! -f "$HOME/.ssh/ssh_host_rsa_key" ]]; then
    info "Generate SSH host key..."
    ssh-keygen -A -f "$HOME" 2>/dev/null || \
    ssh-keygen -t rsa -f "$HOME/.ssh/ssh_host_rsa_key" -N "" 2>/dev/null
  fi

  # jalankan sshd
  sshd 2>/dev/null
  if pgrep sshd > /dev/null; then
    ok "${BOLD}SSH server aktif!${NC}"
    echo ""
    # tampil info koneksi
    remote_server_info_inline
  else
    err "Gagal start SSH server."
    warn "Coba: ${CYAN}pkill sshd && sshd${NC}"
  fi
  pause
}

# ─────────────────────────────────────────
remote_server_info_inline() {
  # ambil IP
  LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
  [[ -z "$LOCAL_IP" ]] && LOCAL_IP=$(ifconfig 2>/dev/null | grep -oP '(?<=inet )[\d.]+' | grep -v 127 | head -1)
  [[ -z "$LOCAL_IP" ]] && LOCAL_IP=$(termux-wifi-connectioninfo 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('ip','?'))" 2>/dev/null)

  PORT=8022  # default Termux SSH port

  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  ${GREEN}IP HP lo  :${NC} ${BOLD}$LOCAL_IP${NC}"
  echo -e "  ${GREEN}Port      :${NC} ${BOLD}$PORT${NC}"
  echo -e "  ${GREEN}Username  :${NC} ${BOLD}$(whoami)${NC}"
  echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo -e "  ${YELLOW}Command di laptop buat konek:${NC}"
  echo -e "  ${BOLD}ssh $(whoami)@$LOCAL_IP -p $PORT${NC}"
}

remote_server_info() {
  section "Info SSH Server HP"
  if ! pgrep sshd > /dev/null; then
    warn "SSH server belum aktif."
    info "Jalankan menu [4] dulu."
    pause; return
  fi
  ok "SSH server sedang aktif."
  echo ""
  remote_server_info_inline
  pause
}

# ─────────────────────────────────────────
remote_stop_server() {
  section "Stop SSH Server"
  if pgrep sshd > /dev/null; then
    pkill sshd
    ok "SSH server dihentikan."
  else
    warn "SSH server tidak sedang aktif."
  fi
  pause
}

# ─────────────────────────────────────────
remote_tunnel_phone() {
  section "Reverse Tunnel — Akses HP dari Mana Aja"
  check_tool ssh || return

  echo -e "  ${DIM}Cara kerja: HP konek ke server relay, laptop konek ke relay itu${NC}"
  echo -e "  ${DIM}buat masuk ke HP. Berguna kalau beda WiFi / internet.${NC}\n"

  echo -e "  ${YELLOW}Butuh 1 server/VPS sebagai relay (bisa pakai laptop lo sendiri${NC}"
  echo -e "  ${YELLOW}kalau satu jaringan, atau VPS kalau beda jaringan).${NC}\n"

  echo -ne "${WHITE}  IP relay server / laptop${NC}: "
  read -r relay
  [[ -z "$relay" ]] && { err "IP kosong!"; pause; return; }

  echo -ne "${WHITE}  Username di relay${NC}: "
  read -r relayuser
  [[ -z "$relayuser" ]] && { err "Username kosong!"; pause; return; }

  echo -ne "${WHITE}  Port relay SSH${NC} [default 22]: "
  read -r relayport
  relayport=${relayport:-22}

  echo -ne "${WHITE}  Port remote yang dibuka di relay${NC} [default 2222]: "
  read -r remoteport
  remoteport=${remoteport:-2222}

  info "Membuat reverse tunnel ke $relayuser@$relay ..."
  info "Laptop bisa masuk ke HP dengan: ${CYAN}ssh $(whoami)@$relay -p $remoteport${NC}"
  warn "Tekan Ctrl+C untuk stop tunnel"
  echo ""

  # -N = no command, -R = reverse, -o = keep alive
  ssh -N -R "${remoteport}:localhost:8022" \
      -p "$relayport" \
      -o ServerAliveInterval=30 \
      -o ServerAliveCountMax=3 \
      -o ExitOnForwardFailure=yes \
      "$relayuser@$relay"

  warn "Tunnel terputus."
  pause
}

# ─────────────────────────────────────────
remote_tunnel_laptop() {
  section "Reverse Tunnel — Akses Laptop dari Mana Aja"
  check_tool ssh || return

  echo -e "  ${DIM}Cara kerja: Laptop harus jalanin command ini dulu supaya${NC}"
  echo -e "  ${DIM}HP lo bisa remote masuk ke laptop dari mana aja.${NC}\n"

  echo -ne "${WHITE}  IP laptop${NC}: "
  read -r laptop_ip
  [[ -z "$laptop_ip" ]] && { err "IP kosong!"; pause; return; }

  echo -ne "${WHITE}  Username laptop${NC}: "
  read -r laptop_user
  [[ -z "$laptop_user" ]] && { err "Username kosong!"; pause; return; }

  echo -ne "${WHITE}  Port SSH laptop${NC} [default 22]: "
  read -r laptop_port
  laptop_port=${laptop_port:-22}

  echo -ne "${WHITE}  Port yang dibuka di HP${NC} [default 2222]: "
  read -r localport
  localport=${localport:-2222}

  echo ""
  echo -e "  ${YELLOW}${BOLD}Command yang harus dijalankan di LAPTOP:${NC}"
  echo -e "  ${CYAN}${BOLD}ssh -N -R ${localport}:localhost:${laptop_port} $(whoami)@<IP_HP> -p 8022${NC}"
  echo ""
  echo -e "  Setelah laptop jalanin command itu, lo bisa masuk ke laptop"
  echo -e "  dari HP dengan:"
  echo -e "  ${CYAN}${BOLD}ssh ${laptop_user}@localhost -p ${localport}${NC}"
  echo ""
  echo -ne "${WHITE}  Konek ke laptop sekarang (laptop sudah setup tunnel)? [y/N]${NC}: "
  read -r yn
  if [[ "$yn" =~ ^[Yy]$ ]]; then
    info "Connecting ke laptop via tunnel..."
    ssh "$laptop_user@localhost" -p "$localport"
  fi
  pause
}
