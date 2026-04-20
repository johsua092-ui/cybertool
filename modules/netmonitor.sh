#!/bin/bash
# modules/netmonitor.sh

netmonitor_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📡 Network Monitor${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Scan device di jaringan sekarang"
    echo -e "  ${GREEN}[2]${NC} Monitor device — alert kalau ada yang baru masuk"
    echo -e "  ${GREEN}[3]${NC} Lihat ARP table (device yang pernah konek)"
    echo -e "  ${GREEN}[4]${NC} Cek koneksi aktif di HP lo"
    echo -e "  ${GREEN}[5]${NC} Ping monitor — pantau device tetap online"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  No root. Butuh koneksi WiFi aktif.${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) netmon_scan        ;;
      2) netmon_watch       ;;
      3) netmon_arp         ;;
      4) netmon_connections ;;
      5) netmon_ping        ;;
      0) break              ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}

# ─────────────────────────────────────────
# helper: get current subnet
get_subnet() {
  # coba dari ip route
  SUBNET=$(ip route 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+/\d+' | grep -v "^169\|^127" | head -1)
  if [[ -z "$SUBNET" ]]; then
    # fallback: build dari IP
    LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+')
    [[ -z "$LOCAL_IP" ]] && LOCAL_IP=$(ifconfig 2>/dev/null | grep -oP '(?<=inet )[\d.]+' | grep -v 127 | head -1)
    if [[ -n "$LOCAL_IP" ]]; then
      SUBNET=$(echo "$LOCAL_IP" | cut -d. -f1-3).0/24
    fi
  fi
  echo "$SUBNET"
}

# ─────────────────────────────────────────
netmon_scan() {
  check_tool nmap || return
  section "Scan Device di Jaringan"

  SUBNET=$(get_subnet)
  if [[ -z "$SUBNET" ]]; then
    err "Tidak bisa detect subnet. Pastikan WiFi aktif."
    pause; return
  fi

  info "Subnet terdeteksi: ${CYAN}$SUBNET${NC}"
  info "Scanning... (biasanya 10-30 detik)\n"

  SCAN=$(nmap -sn "$SUBNET" 2>/dev/null)

  echo "$SCAN" | python3 -c "
import sys, re, subprocess

output = sys.stdin.read()

GREEN  = '\033[0;32m'
CYAN   = '\033[0;36m'
YELLOW = '\033[1;33m'
DIM    = '\033[2m'
NC     = '\033[0m'

# parse nmap output
devices = []
current = {}
for line in output.splitlines():
    line = line.strip()
    if 'Nmap scan report for' in line:
        if current: devices.append(current)
        ip_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', line)
        hostname = ''
        if '(' in line:
            hostname = line.split('(')[0].replace('Nmap scan report for','').strip()
        current = {'ip': ip_match.group(1) if ip_match else '?', 'hostname': hostname, 'mac': '', 'vendor': ''}
    elif 'MAC Address:' in line:
        mac_match = re.search(r'([0-9A-F:]{17})', line)
        vendor_match = re.search(r'\((.+)\)', line)
        current['mac']    = mac_match.group(1) if mac_match else ''
        current['vendor'] = vendor_match.group(1) if vendor_match else ''

if current: devices.append(current)

# ambil IP sendiri
try:
    import subprocess
    my_ip = subprocess.run(['ip','route','get','1.1.1.1'], capture_output=True, text=True).stdout
    my_ip = re.search(r'src (\S+)', my_ip)
    my_ip = my_ip.group(1) if my_ip else ''
except:
    my_ip = ''

print(f'  {\"No\":<4} {\"IP Address\":<18} {\"MAC Address\":<20} {\"Vendor / Hostname\"}')
print('  ' + '-'*70)
for i, d in enumerate(devices, 1):
    ip      = d['ip']
    mac     = d['mac'] or 'N/A (gateway/self)'
    vendor  = d['vendor'] or d['hostname'] or '-'
    me      = f'  {CYAN}← lo{NC}' if ip == my_ip else ''
    gw      = f'  {YELLOW}← gateway{NC}' if i == 1 and not d['mac'] else ''
    print(f'  {i:<4} {GREEN}{ip:<18}{NC} {mac:<20} {DIM}{vendor}{NC}{me}{gw}')

print(f'\n  Total: {GREEN}{len(devices)} device{NC} ditemukan di jaringan')
print(f'  {DIM}Tip: MAC dengan vendor dikenal = aman. MAC tidak dikenal = perlu dicek.{NC}')
" 2>/dev/null

  pause
}

# ─────────────────────────────────────────
netmon_watch() {
  check_tool nmap || return
  section "Monitor Device — Alert Device Baru"

  SUBNET=$(get_subnet)
  if [[ -z "$SUBNET" ]]; then
    err "Tidak bisa detect subnet."
    pause; return
  fi

  echo -ne "${WHITE}  Interval scan${NC} (detik, default 30): "
  read -r interval
  interval=${interval:-30}

  info "Mulai monitoring ${CYAN}$SUBNET${NC} setiap ${interval}s"
  warn "Tekan Ctrl+C untuk stop\n"

  # scan pertama sebagai baseline
  BASELINE=$(nmap -sn "$SUBNET" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | sort)
  KNOWN=$(echo "$BASELINE")
  COUNT=$(echo "$BASELINE" | wc -l)
  ok "Baseline: ${CYAN}$COUNT device${NC} aktif saat ini"
  echo -e "  ${DIM}$(echo "$BASELINE" | tr '\n' ' ')${NC}\n"

  ROUND=1
  while true; do
    sleep "$interval"
    CURRENT=$(nmap -sn "$SUBNET" 2>/dev/null | grep -oP '\d+\.\d+\.\d+\.\d+' | sort)
    CURRENT_COUNT=$(echo "$CURRENT" | wc -l)

    # device baru
    NEW=$(comm -13 <(echo "$KNOWN") <(echo "$CURRENT"))
    # device disconnect
    LEFT=$(comm -23 <(echo "$KNOWN") <(echo "$CURRENT"))

    TIMESTAMP=$(date '+%H:%M:%S')

    if [[ -n "$NEW" ]]; then
      echo -e "\n  ${RED}${BOLD}[!] $TIMESTAMP — DEVICE BARU MASUK:${NC}"
      for ip in $NEW; do
        VENDOR=$(nmap -sn "$ip" 2>/dev/null | grep "MAC" | grep -oP '\(.*\)' | tr -d '()')
        echo -e "  ${RED}  → $ip${NC}  ${DIM}$VENDOR${NC}"
      done
    fi

    if [[ -n "$LEFT" ]]; then
      echo -e "\n  ${YELLOW}[-] $TIMESTAMP — Device disconnect:${NC}"
      for ip in $LEFT; do
        echo -e "  ${YELLOW}  ← $ip${NC}"
      done
    fi

    if [[ -z "$NEW" && -z "$LEFT" ]]; then
      echo -ne "\r  ${DIM}[$ROUND] $TIMESTAMP — $CURRENT_COUNT device, tidak ada perubahan${NC}   "
    fi

    KNOWN="$CURRENT"
    ((ROUND++))
  done
}

# ─────────────────────────────────────────
netmon_arp() {
  section "ARP Table"
  info "Device yang pernah konek ke jaringan ini:\n"

  if command -v arp &>/dev/null; then
    arp -a 2>/dev/null | python3 -c "
import sys, re
GREEN = '\033[0;32m'
CYAN  = '\033[0;36m'
DIM   = '\033[2m'
NC    = '\033[0m'
lines = [l for l in sys.stdin.read().splitlines() if l.strip()]
print(f'  {\"IP Address\":<20} {\"MAC Address\":<20} Interface')
print('  ' + '-'*55)
for line in lines:
    ip  = re.search(r'\((\d+\.\d+\.\d+\.\d+)\)', line)
    mac = re.search(r'([0-9a-f:]{17})', line.lower())
    iface = line.split()[-1] if line.split() else ''
    if ip and mac:
        print(f'  {GREEN}{ip.group(1):<20}{NC} {mac.group(1):<20} {DIM}{iface}{NC}')
" 2>/dev/null
  else
    # fallback: baca /proc/net/arp
    python3 -c "
GREEN = '\033[0;32m'
CYAN  = '\033[0;36m'
DIM   = '\033[2m'
NC    = '\033[0m'
try:
    with open('/proc/net/arp') as f:
        lines = f.readlines()[1:]  # skip header
    print(f'  {\"IP Address\":<20} {\"MAC Address\":<20} Interface')
    print('  ' + '-'*55)
    for line in lines:
        parts = line.split()
        if len(parts) >= 6 and parts[2] != '0x0':
            ip, mac, iface = parts[0], parts[3], parts[5]
            print(f'  {GREEN}{ip:<20}{NC} {mac:<20} {DIM}{iface}{NC}')
except Exception as e:
    print(f'  Error: {e}')
" 2>/dev/null
  fi
  pause
}

# ─────────────────────────────────────────
netmon_connections() {
  section "Koneksi Aktif di HP Lo"

  python3 -c "
GREEN  = '\033[0;32m'
RED    = '\033[0;31m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
DIM    = '\033[2m'
NC     = '\033[0m'

import socket

common_ports = {
    '22':'SSH','23':'Telnet','25':'SMTP','53':'DNS','80':'HTTP',
    '110':'POP3','143':'IMAP','443':'HTTPS','3306':'MySQL',
    '5432':'PostgreSQL','6379':'Redis','8080':'HTTP-Alt','8443':'HTTPS-Alt',
    '27017':'MongoDB','3389':'RDP','21':'FTP'
}

try:
    with open('/proc/net/tcp') as f:
        tcp4 = f.readlines()[1:]
    with open('/proc/net/tcp6') as f:
        tcp6 = f.readlines()[1:]
except:
    print('  Tidak bisa baca /proc/net/tcp')
    exit()

def hex_to_ip(h):
    try:
        parts = [str(int(h[i:i+2],16)) for i in range(6,-2,-2)]
        return '.'.join(parts)
    except: return '?'

def hex_to_port(h):
    try: return int(h,16)
    except: return 0

states = {'01':'ESTABLISHED','02':'SYN_SENT','03':'SYN_RECV',
          '04':'FIN_WAIT1','05':'FIN_WAIT2','06':'TIME_WAIT',
          '07':'CLOSE','08':'CLOSE_WAIT','09':'LAST_ACK',
          '0A':'LISTEN','0B':'CLOSING'}

conns = []
for line in tcp4:
    p = line.split()
    if len(p) < 4: continue
    l_ip, l_port = p[1].split(':')
    r_ip, r_port = p[2].split(':')
    state = states.get(p[3].upper(), p[3])
    lip  = hex_to_ip(l_ip)
    lp   = hex_to_port(l_port)
    rip  = hex_to_ip(r_ip)
    rp   = hex_to_port(r_port)
    if state == 'ESTABLISHED' and rip != '0.0.0.0':
        svc = common_ports.get(str(rp), '')
        conns.append((lip, lp, rip, rp, state, svc))

if conns:
    print(f'  {\"Local\":<22} {\"Remote\":<22} {\"Port\":<8} Service')
    print('  ' + '-'*62)
    for lip,lp,rip,rp,st,svc in conns:
        col = GREEN if svc in ['HTTPS','SSH'] else YELLOW if not svc else CYAN
        print(f'  {lip}:{lp:<10} {RED}{rip}{NC}:{rp:<10} {col}{svc or \"-\"}{NC}')
    print(f'\n  Total: {len(conns)} koneksi aktif')
else:
    print(f'  {DIM}Tidak ada koneksi TCP aktif saat ini{NC}')

# listening ports
listening = []
for line in tcp4:
    p = line.split()
    if len(p) < 4: continue
    state = states.get(p[3].upper(), p[3])
    if state == 'LISTEN':
        l_ip, l_port = p[1].split(':')
        lp = hex_to_port(l_port)
        svc = common_ports.get(str(lp), '')
        listening.append((lp, svc))

if listening:
    print(f'\n  {YELLOW}Port yang sedang LISTEN di HP lo:{NC}')
    for port, svc in sorted(set(listening)):
        print(f'  {YELLOW}  :{port:<8}{NC} {DIM}{svc or \"unknown\"}{NC}')
" 2>/dev/null

  pause
}

# ─────────────────────────────────────────
netmon_ping() {
  section "Ping Monitor"
  check_tool ping || return

  echo -ne "${WHITE}  IP yang mau dipantau${NC} (pisah spasi, contoh: 192.168.1.1 8.8.8.8): "
  read -r targets
  [[ -z "$targets" ]] && { err "Target kosong!"; pause; return; }

  echo -ne "${WHITE}  Interval${NC} (detik, default 5): "
  read -r interval
  interval=${interval:-5}

  warn "Tekan Ctrl+C untuk stop\n"

  declare -A STATUS

  while true; do
    TIMESTAMP=$(date '+%H:%M:%S')
    LINE="  [$TIMESTAMP]"
    for ip in $targets; do
      if ping -c1 -W2 "$ip" &>/dev/null; then
        RTT=$(ping -c1 -W2 "$ip" 2>/dev/null | grep -oP 'time=\K[\d.]+')
        LINE+="  ${GREEN}$ip ✓ ${RTT}ms${NC}"
        if [[ "${STATUS[$ip]}" == "DOWN" ]]; then
          echo -e "\n  ${GREEN}[+] $TIMESTAMP — $ip kembali ONLINE${NC}"
        fi
        STATUS[$ip]="UP"
      else
        LINE+="  ${RED}$ip ✗${NC}"
        if [[ "${STATUS[$ip]}" != "DOWN" ]]; then
          echo -e "\n  ${RED}[!] $TIMESTAMP — $ip OFFLINE!${NC}"
        fi
        STATUS[$ip]="DOWN"
      fi
    done
    echo -ne "\r$LINE   "
    sleep "$interval"
  done
}
