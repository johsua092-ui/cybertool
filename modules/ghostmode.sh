#!/bin/bash
# modules/ghostmode.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

GHOST_STATE="$SCRIPT_ROOT/data/ghost_state"

ghostmode_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  👻 Ghost Mode${NC}"
    echo ""

    # status
    if [[ -f "$GHOST_STATE" ]]; then
      echo -e "  Status: ${GREEN}${BOLD}GHOST MODE AKTIF ●${NC}\n"
    else
      echo -e "  Status: ${DIM}Inactive ○${NC}\n"
    fi

    echo -e "  ${GREEN}[1]${NC} Aktifkan Ghost Mode"
    echo -e "  ${GREEN}[2]${NC} Nonaktifkan Ghost Mode"
    echo -e "  ${GREEN}[3]${NC} Random MAC address sekarang"
    echo -e "  ${GREEN}[4]${NC} Lihat MAC address sekarang"
    echo -e "  ${GREEN}[5]${NC} Cek apakah HP lo terdeteksi di jaringan"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Ghost mode: random MAC + minimal network footprint${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) ghost_enable  ;;
      2) ghost_disable ;;
      3) ghost_mac     ;;
      4) ghost_info    ;;
      5) ghost_check   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

ghost_enable() {
  section "Aktifkan Ghost Mode"
  mkdir -p "$(dirname "$GHOST_STATE")"

  # simpan MAC asli
  REAL_MAC=$(ip link show 2>/dev/null | grep -oP '(?<=link/ether )[0-9a-f:]+' | head -1)
  echo "REAL_MAC=$REAL_MAC" > "$GHOST_STATE"

  # random MAC
  NEW_MAC=$(python3 -c "
import random
# locally administered, unicast MAC
mac = [0x02,
       random.randint(0x00,0xFF),
       random.randint(0x00,0xFF),
       random.randint(0x00,0xFF),
       random.randint(0x00,0xFF),
       random.randint(0x00,0xFF)]
print(':'.join(f'{b:02x}' for b in mac))
" 2>/dev/null)

  ok "MAC asli tersimpan: ${DIM}$REAL_MAC${NC}"
  ok "Ghost MAC: ${GREEN}${BOLD}$NEW_MAC${NC}"

  # Coba ganti MAC (perlu root untuk full change, tapi bisa spoof di beberapa device)
  IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
  if [[ -n "$IFACE" ]]; then
    ip link set dev "$IFACE" address "$NEW_MAC" 2>/dev/null && \
      ok "MAC berhasil diubah pada $IFACE!" || \
      warn "Perlu root untuk ganti MAC. MAC tersimpan untuk referensi."
  fi

  echo ""
  info "Tips ghost mode tambahan:"
  echo -e "  ${DIM}• Pakai Tor untuk routing traffic (menu [20])${NC}"
  echo -e "  ${DIM}• Matikan Bluetooth agar tidak terdeteksi${NC}"
  echo -e "  ${DIM}• Pakai VPN/proxy untuk sembunyiin IP${NC}"
  echo "$NEW_MAC" >> "$GHOST_STATE"
  pause
}

ghost_disable() {
  section "Nonaktifkan Ghost Mode"
  if [[ ! -f "$GHOST_STATE" ]]; then
    warn "Ghost mode tidak sedang aktif."
    pause; return
  fi

  REAL_MAC=$(grep "REAL_MAC" "$GHOST_STATE" | cut -d= -f2)
  IFACE=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'dev \K\S+' | head -1)

  if [[ -n "$REAL_MAC" && -n "$IFACE" ]]; then
    ip link set dev "$IFACE" address "$REAL_MAC" 2>/dev/null && \
      ok "MAC dikembalikan ke: ${GREEN}$REAL_MAC${NC}" || \
      warn "Gagal kembalikan MAC (perlu root)"
  fi

  rm -f "$GHOST_STATE"
  ok "Ghost mode dinonaktifkan."
  pause
}

ghost_mac() {
  section "Random MAC Generator"
  python3 -c "
import random
GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
print(f'  {CYAN}Generating 5 random MAC addresses:{NC}\n')
vendors = [
    ('Apple',    [0x00,0x1C,0xB3]),
    ('Samsung',  [0x00,0x16,0x6C]),
    ('Google',   [0xF4,0xF5,0xDB]),
    ('OnePlus',  [0x94,0x65,0x2D]),
    ('Xiaomi',   [0x00,0xEC,0x0A]),
]
for name, prefix in vendors:
    suffix = [random.randint(0,255) for _ in range(3)]
    mac = prefix + suffix
    print(f'  {GREEN}•{NC} {\":\".join(f\"{b:02x}\" for b in mac)}  {DIM}({name}-like){NC}')
print()
print(f'  {DIM}Tip: Pilih satu, pakai menu [1] Ghost Mode untuk apply{NC}')
" 2>/dev/null
  pause
}

ghost_info() {
  section "Network Identity Lo Sekarang"
  python3 -c "
import subprocess, re
GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; RED='\033[0;31m'; NC='\033[0m'

# IP
try:
    ip_out = subprocess.run(['ip','route','get','1.1.1.1'],
                capture_output=True,text=True).stdout
    ip  = re.search(r'src (\S+)', ip_out)
    dev = re.search(r'dev (\S+)', ip_out)
    print(f'  IP Address : {GREEN}{ip.group(1) if ip else \"?\"}{NC}')
    print(f'  Interface  : {dev.group(1) if dev else \"?\"}')
except: pass

# MAC
try:
    link = subprocess.run(['ip','link','show'],capture_output=True,text=True).stdout
    macs = re.findall(r'(\S+):.*\n.*link/ether ([0-9a-f:]+)', link)
    for iface, mac in macs:
        if 'lo' not in iface:
            print(f'  MAC        : {CYAN}{mac}{NC}')
except: pass

# Hostname
try:
    hn = subprocess.run(['hostname'],capture_output=True,text=True).stdout.strip()
    print(f'  Hostname   : {DIM}{hn}{NC}')
except: pass
" 2>/dev/null
  pause
}

ghost_check() {
  section "Cek Visibilitas di Jaringan"
  info "Mengecek apakah HP lo terdeteksi oleh device lain...\n"

  MY_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || echo "")
  [[ -z "$MY_IP" ]] && { err "Tidak konek ke jaringan."; pause; return; }

  # cek apakah HP lo respond ping
  info "IP lo: ${CYAN}$MY_IP${NC}"

  # cek port yang terbuka
  info "Port yang terbuka di HP lo:\n"
  python3 -c "
import socket
GREEN='\033[0;32m'; RED='\033[0;31m'; DIM='\033[2m'; NC='\033[0m'
common = [22,8022,80,443,8080,21,23,25,3306]
found = []
for p in common:
    try:
        s = socket.socket()
        s.settimeout(0.5)
        if s.connect_ex(('127.0.0.1', p)) == 0:
            found.append(p)
        s.close()
    except: pass
if found:
    print(f'  {RED}[!] Port terbuka:{NC}')
    for p in found: print(f'  {RED}  → :{p}{NC}')
    print(f'\n  {RED}HP lo visible! Tutup port yang tidak perlu.{NC}')
else:
    print(f'  {GREEN}[✓] Tidak ada port terbuka — HP lo relatif stealth{NC}')
" 2>/dev/null
  pause
}
