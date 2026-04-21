#!/bin/bash
# modules/pwstrength.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

pwstrength_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔒 Password Strength Checker${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Cek kekuatan password"
    echo -e "  ${GREEN}[2]${NC} Cek banyak password sekaligus"
    echo -e "  ${GREEN}[3]${NC} Generate password kuat"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) pws_check_single ;;
      2) pws_check_bulk   ;;
      3) pws_generate     ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

pws_analyze() {
  local pw="$1"
  python3 - "$pw" << 'PYEOF'
import sys, re, math, string

pw = sys.argv[1]
RED    = '\033[0;31m'
GREEN  = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN   = '\033[0;36m'
WHITE  = '\033[1;37m'
DIM    = '\033[2m'
BOLD   = '\033[1m'
NC     = '\033[0m'

# ── Charset analysis ─────────────────────────
has_lower  = bool(re.search(r'[a-z]', pw))
has_upper  = bool(re.search(r'[A-Z]', pw))
has_digit  = bool(re.search(r'\d', pw))
has_symbol = bool(re.search(r'[^a-zA-Z0-9]', pw))
has_space  = ' ' in pw

charset = 0
if has_lower:  charset += 26
if has_upper:  charset += 26
if has_digit:  charset += 10
if has_symbol: charset += 32
if has_space:  charset += 1

# ── Entropy ───────────────────────────────────
entropy = len(pw) * math.log2(charset) if charset > 0 else 0

# ── Common patterns ───────────────────────────
patterns = []
if re.search(r'(.)\1{2,}', pw):
    patterns.append("Karakter berulang")
if re.search(r'(012|123|234|345|456|567|678|789|890|abc|bcd|cde|def|efg|fgh|ghi|hij|ijk|jkl|klm|lmn|mno|nop|opq|pqr|qrs|rst|stu|tuv|uvw|vwx|wxy|xyz)', pw.lower()):
    patterns.append("Urutan keyboard/alfabet")
if re.search(r'^[A-Z][a-z]+\d+[!@#$%]?$', pw):
    patterns.append("Pola umum (Kata+Angka+Simbol)")
if re.search(r'(password|passwd|admin|user|login|welcome|qwerty|abc123|letmein|monkey|dragon|master|shadow|sunshine)', pw.lower()):
    patterns.append("Kata umum / default password")
if re.search(r'\b(19|20)\d{2}\b', pw):
    patterns.append("Mengandung tahun")
if len(pw) < 8:
    patterns.append("Terlalu pendek")

# ── Crack time estimation ─────────────────────
# asumsi: 10 billion guesses/second (GPU cracking)
SPEED = 10_000_000_000
combos = charset ** len(pw) if charset > 0 else 1
seconds = combos / SPEED / 2  # average case

def format_time(s):
    if s < 1:          return f"{GREEN}< 1 detik{NC}", "INSTANT"
    elif s < 60:       return f"{RED}{s:.0f} detik{NC}", "SANGAT LEMAH"
    elif s < 3600:     return f"{RED}{s/60:.0f} menit{NC}", "SANGAT LEMAH"
    elif s < 86400:    return f"{RED}{s/3600:.0f} jam{NC}", "LEMAH"
    elif s < 2592000:  return f"{YELLOW}{s/86400:.0f} hari{NC}", "LEMAH"
    elif s < 31536000: return f"{YELLOW}{s/2592000:.0f} bulan{NC}", "SEDANG"
    elif s < 3153600000: return f"{GREEN}{s/31536000:.0f} tahun{NC}", "KUAT"
    else:              return f"{GREEN}{s/31536000/1000:.0f}K tahun{NC}", "SANGAT KUAT"

crack_time, level = format_time(seconds)

# ── Score ─────────────────────────────────────
score = 0
if len(pw) >= 8:   score += 1
if len(pw) >= 12:  score += 1
if len(pw) >= 16:  score += 1
if has_lower:      score += 1
if has_upper:      score += 1
if has_digit:      score += 1
if has_symbol:     score += 1
if has_space:      score += 1
score -= len(patterns)
score = max(0, min(8, score))

bar_filled = score
bar = '█' * bar_filled + '░' * (8 - bar_filled)
if score <= 2:     bar_col = RED
elif score <= 4:   bar_col = YELLOW
elif score <= 6:   bar_col = f'\033[0;33m'
else:              bar_col = GREEN

# ── Output ────────────────────────────────────
print(f"\n  {CYAN}Password  :{NC} {'*' * len(pw)}  {DIM}({len(pw)} karakter){NC}")
print(f"  {CYAN}Score     :{NC} {bar_col}[{bar}] {score}/8{NC}")
print(f"  {CYAN}Level     :{NC} {bar_col}{BOLD}{level}{NC}")
print(f"  {CYAN}Entropy   :{NC} {entropy:.1f} bits")
print(f"  {CYAN}Crack time:{NC} {crack_time}  {DIM}(GPU 10B/s){NC}")

print(f"\n  {CYAN}{BOLD}── Analisis ──{NC}")
checks = [
    (len(pw) >= 8,   "Minimal 8 karakter"),
    (len(pw) >= 12,  "Minimal 12 karakter"),
    (len(pw) >= 16,  "Minimal 16 karakter (recommended)"),
    (has_lower,      "Huruf kecil (a-z)"),
    (has_upper,      "Huruf besar (A-Z)"),
    (has_digit,      "Angka (0-9)"),
    (has_symbol,     "Simbol (!@#$%^&*)"),
]
for passed, label in checks:
    icon = f"{GREEN}✓{NC}" if passed else f"{RED}✗{NC}"
    print(f"  {icon} {label}")

if patterns:
    print(f"\n  {YELLOW}{BOLD}── Kelemahan ──{NC}")
    for p in patterns:
        print(f"  {YELLOW}[!]{NC} {p}")

print(f"\n  {CYAN}{BOLD}── Rekomendasi ──{NC}")
if score < 6:
    if len(pw) < 16:
        print(f"  → Tambah panjang hingga 16+ karakter")
    if not has_upper:
        print(f"  → Tambahkan huruf kapital")
    if not has_symbol:
        print(f"  → Tambahkan simbol (!@#$%)")
    if patterns:
        print(f"  → Hindari pola yang mudah ditebak")
else:
    print(f"  {GREEN}Password sudah kuat!{NC}")
PYEOF
}

pws_check_single() {
  banner
  echo -e "${CYAN}${BOLD}  🔒 Password Checker${NC}\n"
  echo -ne "${WHITE}  Password${NC}: "
  # disable echo biar ga keliatan
  read -rs pw
  echo ""
  [[ -z "$pw" ]] && { err "Kosong!"; pause; return; }
  pws_analyze "$pw"
  pause
}

pws_check_bulk() {
  banner
  echo -e "${CYAN}${BOLD}  🔒 Bulk Password Check${NC}\n"
  echo -e "  ${DIM}Masukkan password satu per baris, ketik END setelah selesai${NC}\n"
  i=1
  while true; do
    echo -ne "  Password $i: "
    read -rs pw
    echo ""
    [[ "$pw" == "END" || -z "$pw" ]] && break
    section "Password $i"
    pws_analyze "$pw"
    ((i++))
  done
  pause
}

pws_generate() {
  section "Password Generator"
  echo -ne "${WHITE}  Panjang${NC} [default 20]: "
  read -r len; len=${len:-20}
  echo -e "\n  ${CYAN}Generating 5 password kuat...${NC}\n"
  python3 -c "
import random, string, secrets
chars = string.ascii_letters + string.digits + '!@#\$%^&*()-_=+'
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
for i in range(5):
    # pastiin ada semua jenis karakter
    pw = [
        secrets.choice(string.ascii_lowercase),
        secrets.choice(string.ascii_uppercase),
        secrets.choice(string.digits),
        secrets.choice('!@#\$%^&*()-_=+'),
    ]
    pw += [secrets.choice(chars) for _ in range($len - 4)]
    random.shuffle(pw)
    pw = ''.join(pw)
    print(f'  {GREEN}[{i+1}]{NC} {CYAN}{pw}{NC}')
" 2>/dev/null
  pause
}
