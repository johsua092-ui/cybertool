#!/bin/bash
# modules/deviceinfo.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

deviceinfo_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📱 Device Info${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Info lengkap device"
    echo -e "  ${GREEN}[2]${NC} Hardware & sensor"
    echo -e "  ${GREEN}[3]${NC} Network interfaces"
    echo -e "  ${GREEN}[4]${NC} Battery & storage"
    echo -e "  ${GREEN}[5]${NC} Running processes"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) device_full    ;;
      2) device_hardware ;;
      3) device_network ;;
      4) device_battery ;;
      5) device_procs   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

device_full() {
  section "Device Info Lengkap"
  spinner_start "Collecting info"

  # Android props via getprop
  BRAND=$(getprop ro.product.brand 2>/dev/null || echo "?")
  MODEL=$(getprop ro.product.model 2>/dev/null || echo "?")
  DEVICE=$(getprop ro.product.device 2>/dev/null || echo "?")
  ANDROID=$(getprop ro.build.version.release 2>/dev/null || echo "?")
  SDK=$(getprop ro.build.version.sdk 2>/dev/null || echo "?")
  BUILD=$(getprop ro.build.display.id 2>/dev/null || echo "?")
  ARCH=$(getprop ro.product.cpu.abi 2>/dev/null || echo "?")
  KERNEL=$(uname -r 2>/dev/null || echo "?")
  HOSTNAME=$(hostname 2>/dev/null || echo "?")
  UPTIME=$(uptime -p 2>/dev/null || cat /proc/uptime | awk '{print int($1/3600)"h "int(($1%3600)/60)"m"}')

  spinner_stop "Done"

  echo -e "  ${CYAN}${BOLD}── Device ──────────────────────${NC}"
  echo -e "  Brand      : ${WHITE}$BRAND${NC}"
  echo -e "  Model      : ${WHITE}$MODEL${NC}"
  echo -e "  Device     : $DEVICE"
  echo -e "  Android    : ${GREEN}$ANDROID${NC} (SDK $SDK)"
  echo -e "  Build      : ${DIM}$BUILD${NC}"
  echo -e "  CPU Arch   : $ARCH"
  echo -e "  Kernel     : ${DIM}$KERNEL${NC}"
  echo -e "  Hostname   : $HOSTNAME"
  echo -e "  Uptime     : $UPTIME"

  # CPU info
  echo -e "\n  ${CYAN}${BOLD}── CPU ─────────────────────────${NC}"
  CPU_MODEL=$(cat /proc/cpuinfo 2>/dev/null | grep -m1 "Hardware\|model name\|Processor" | cut -d: -f2 | xargs)
  CPU_CORES=$(nproc 2>/dev/null || grep -c "^processor" /proc/cpuinfo 2>/dev/null || echo "?")
  CPU_FREQ=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq 2>/dev/null)
  [[ -n "$CPU_FREQ" ]] && CPU_FREQ_GHZ=$(echo "scale=2; $CPU_FREQ/1000000" | bc 2>/dev/null || echo "$((CPU_FREQ/1000000))")GHz || CPU_FREQ_GHZ="?"
  echo -e "  Processor  : ${CPU_MODEL:-Unknown}"
  echo -e "  Cores      : $CPU_CORES"
  echo -e "  Max Freq   : $CPU_FREQ_GHZ"

  # RAM
  echo -e "\n  ${CYAN}${BOLD}── Memory ──────────────────────${NC}"
  python3 -c "
with open('/proc/meminfo') as f: m = dict(l.split(':') for l in f.readlines() if ':' in l)
total = int(m.get('MemTotal','0 kB').split()[0])//1024
free  = int(m.get('MemAvailable','0 kB').split()[0])//1024
used  = total - free
pct   = used*100//total if total else 0
bar   = '█'*(pct//5) + '░'*(20-pct//5)
col   = '\033[0;32m' if pct<70 else '\033[1;33m' if pct<85 else '\033[0;31m'
print(f'  Total RAM  : {total} MB')
print(f'  Used       : {col}{used} MB ({pct}%)\033[0m')
print(f'  Free       : {free} MB')
print(f'  Usage      : {col}[{bar}] {pct}%\033[0m')
" 2>/dev/null
  pause
}

device_hardware() {
  section "Hardware & Sensor"
  echo -e "  ${CYAN}${BOLD}── Sensors ─────────────────────${NC}"
  if command -v termux-sensor &>/dev/null; then
    termux-sensor -l 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    for s in d: print(f'  • {s}')
except:
    for l in sys.stdin: print(f'  {l.strip()}')
" 2>/dev/null || warn "Termux:API diperlukan untuk sensor info"
  else
    # fallback: baca dari /sys
    echo -e "  ${DIM}Sensor dari /sys:${NC}"
    find /sys/class/input/ -name "name" 2>/dev/null | while read f; do
      name=$(cat "$f" 2>/dev/null)
      [[ -n "$name" ]] && echo -e "  • $name"
    done | head -20
  fi

  echo -e "\n  ${CYAN}${BOLD}── Display ─────────────────────${NC}"
  WIDTH=$(getprop ro.sf.lcd_width 2>/dev/null || getprop ro.product.displayresolution 2>/dev/null || echo "?")
  DPI=$(getprop ro.sf.lcd_density 2>/dev/null || echo "?")
  echo -e "  Resolution : $WIDTH"
  echo -e "  DPI        : $DPI"

  echo -e "\n  ${CYAN}${BOLD}── Camera ──────────────────────${NC}"
  CAM_COUNT=$(getprop ro.camera.number 2>/dev/null || ls /dev/video* 2>/dev/null | wc -l || echo "?")
  echo -e "  Cameras    : $CAM_COUNT"
  pause
}

device_network() {
  section "Network Interfaces"
  ip addr 2>/dev/null | python3 -c "
import sys, re
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
content = sys.stdin.read()
ifaces  = re.split(r'\n(?=\d+:)', content)
for iface in ifaces:
    lines = iface.strip().splitlines()
    if not lines: continue
    header = lines[0]
    m = re.match(r'\d+: (\S+):', header)
    if not m: continue
    name = m.group(1)
    state = 'UP' if 'UP' in header else 'DOWN'
    col   = GREEN if state=='UP' else RED
    print(f'  {col}[{state}]{NC} {CYAN}{name}{NC}')
    for l in lines[1:]:
        if 'inet ' in l:
            ip = re.search(r'inet (\S+)', l)
            print(f'    IPv4 : {ip.group(1) if ip else \"?\"}')
        elif 'inet6' in l:
            ip = re.search(r'inet6 (\S+)', l)
            print(f'    IPv6 : {DIM}{ip.group(1) if ip else \"?\"}{NC}')
        elif 'link/ether' in l:
            mac = re.search(r'link/ether (\S+)', l)
            print(f'    MAC  : {mac.group(1) if mac else \"?\"}')
" 2>/dev/null
  pause
}

device_battery() {
  section "Battery & Storage"
  echo -e "  ${CYAN}${BOLD}── Battery ─────────────────────${NC}"
  if command -v termux-battery-status &>/dev/null; then
    termux-battery-status 2>/dev/null | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    pct    = d.get('percentage',0)
    status = d.get('status','?')
    health = d.get('health','?')
    temp   = d.get('temperature','?')
    col    = '\033[0;32m' if pct>50 else '\033[1;33m' if pct>20 else '\033[0;31m'
    bar    = '█'*(pct//5) + '░'*(20-pct//5)
    print(f'  Level  : {col}{pct}% [{bar}]\033[0m')
    print(f'  Status : {status}')
    print(f'  Health : {health}')
    print(f'  Temp   : {temp}°C')
except: print('  Tidak bisa baca battery info')
" 2>/dev/null
  else
    BAT=$(cat /sys/class/power_supply/battery/capacity 2>/dev/null || echo "?")
    STATUS=$(cat /sys/class/power_supply/battery/status 2>/dev/null || echo "?")
    echo -e "  Level  : ${GREEN}$BAT%${NC}"
    echo -e "  Status : $STATUS"
  fi

  echo -e "\n  ${CYAN}${BOLD}── Storage ─────────────────────${NC}"
  df -h 2>/dev/null | grep -E "^/|Filesystem" | python3 -c "
import sys
lines = sys.stdin.readlines()
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
for l in lines[1:]:
    parts = l.split()
    if len(parts) >= 5:
        fs, size, used, avail, pct = parts[0], parts[1], parts[2], parts[3], parts[4]
        p = int(pct.strip('%')) if pct.strip('%').isdigit() else 0
        col = GREEN if p<70 else YELLOW if p<85 else RED
        print(f'  {CYAN}{fs:<25}{NC} {size:>6} total  {col}{used:>6} used ({pct}){NC}  {avail:>6} free')
" 2>/dev/null
  pause
}

device_procs() {
  section "Top Processes"
  python3 -c "
import os, re
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'
procs = []
for pid in os.listdir('/proc'):
    if not pid.isdigit(): continue
    try:
        with open(f'/proc/{pid}/status') as f: stat = dict(l.split(':') for l in f if ':' in l)
        name = stat.get('Name','?').strip()
        vmrss = int(stat.get('VmRSS','0 kB').split()[0])//1024
        procs.append((vmrss, int(pid), name))
    except: pass
procs.sort(reverse=True)
print(f'  {CYAN}{\"PID\":<8} {\"Name\":<25} {\"RAM (MB)\"}{NC}')
print('  ' + '─'*45)
for mem, pid, name in procs[:20]:
    col = RED if mem>100 else GREEN if mem<30 else ''
    print(f'  {pid:<8} {name:<25} {col}{mem} MB{NC}')
" 2>/dev/null
  pause
}
