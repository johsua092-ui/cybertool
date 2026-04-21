#!/bin/bash
# modules/callerid.sh
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $(type -t banner) != "function" ]] && source "$SCRIPT_ROOT/lib/colors.sh"

callerid_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  📞 Caller ID Lookup${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Lookup nomor HP"
    echo -e "  ${GREEN}[2]${NC} Batch lookup banyak nomor"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -e "  ${DIM}ℹ  Sumber publik: GetContact, Truecaller web, NumVerify${NC}"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1) cid_single ;;
      2) cid_bulk   ;;
      0) break ;;
      *) err "Tidak valid!"; sleep 1 ;;
    esac
  done
}

cid_lookup() {
  local phone="$1"
  python3 - "$phone" << 'PYEOF'
import sys, re, urllib.request, urllib.parse, ssl, json

phone = sys.argv[1].strip().replace(' ','').replace('-','')
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; DIM='\033[2m'; NC='\033[0m'

# normalize
if not phone.startswith('+'):
    if phone.startswith('0'):
        phone = '+62' + phone[1:]
    else:
        phone = '+' + phone

ctx = ssl.create_default_context()
ctx.check_hostname = False; ctx.verify_mode = ssl.CERT_NONE

def fetch(url, headers={}):
    try:
        req = urllib.request.Request(url,
            headers={'User-Agent':'Mozilla/5.0 (Android 11)',**headers})
        resp = urllib.request.urlopen(req, timeout=10, context=ctx)
        return resp.read().decode('utf-8','ignore')
    except: return ''

# ── Country & operator detection ─────────────
COUNTRIES = {
    '+1':'🇺🇸 USA/Canada','+44':'🇬🇧 UK','+62':'🇮🇩 Indonesia',
    '+60':'🇲🇾 Malaysia','+65':'🇸🇬 Singapore','+63':'🇵🇭 Philippines',
    '+66':'🇹🇭 Thailand','+84':'🇻🇳 Vietnam','+82':'🇰🇷 Korea',
    '+81':'🇯🇵 Japan','+86':'🇨🇳 China','+91':'🇮🇳 India',
    '+61':'🇦🇺 Australia','+49':'🇩🇪 Germany','+55':'🇧🇷 Brazil',
}
ID_OPS = {
    ('0811','0812','0813','0821','0822','0851','0852','0853'):'Telkomsel',
    ('0814','0815','0816','0855','0856','0857','0858'):'Indosat IM3',
    ('0817','0818','0819','0859','0877','0878'):'XL Axiata',
    ('0895','0896','0897','0898','0899'):'Three (3)',
    ('0881','0882','0883','0884','0885','0886','0887','0888'):'Smartfren',
    ('0831','0832','0833','0838'):'Axis',
}

country = next((n for c,n in sorted(COUNTRIES.items(),key=lambda x:-len(x[0])) if phone.startswith(c)), 'Unknown')

print(f"\n  {CYAN}Nomor   :{NC} {GREEN}{phone}{NC}")
print(f"  {CYAN}Negara  :{NC} {country}")

if phone.startswith('+62'):
    local = '0' + phone[3:]
    pref  = local[:4]
    op    = next((op for prefs,op in ID_OPS.items() if pref in prefs), 'Unknown')
    print(f"  {CYAN}Lokal   :{NC} {local}")
    print(f"  {CYAN}Operator:{NC} {op}")

print(f"\n  {CYAN}{BOLD}── OSINT Results ──{NC}")

# NumVerify free tier
print(f"  {DIM}[1/3] NumVerify...{NC}", end='', flush=True)
body = fetch(f"https://numverify.com/php_helper_scripts/phone_api.php?secret_key=&phone={urllib.parse.quote(phone)}&country_code=&format=1")
if body and '"valid":true' in body:
    try:
        d = json.loads(body)
        print(f" {GREEN}✓{NC}")
        if d.get('carrier'):    print(f"  {GREEN}[+]{NC} Operator  : {d['carrier']}")
        if d.get('line_type'):  print(f"  {GREEN}[+]{NC} Line type : {d['line_type']}")
        if d.get('location'):   print(f"  {GREEN}[+]{NC} Location  : {d['location']}")
    except: print(f" {DIM}parse error{NC}")
else:
    print(f" {DIM}no result{NC}")

# OpenCNAM style lookup
print(f"  {DIM}[2/3] Carrier lookup...{NC}", end='', flush=True)
body = fetch(f"https://lookups.twilio.com/v1/PhoneNumbers/{urllib.parse.quote(phone)}?Type=carrier")
if body and 'carrier' in body:
    try:
        d = json.loads(body)
        carrier = d.get('carrier',{})
        if carrier.get('name'): print(f" {GREEN}✓{NC}")
        print(f"  {GREEN}[+]{NC} Carrier : {carrier.get('name','?')}")
        print(f"  {GREEN}[+]{NC} Type    : {carrier.get('type','?')}")
    except: print(f" {DIM}no result{NC}")
else:
    print(f" {DIM}no result{NC}")

# Link ke layanan populer
print(f"  {DIM}[3/3] External lookup links:{NC}")
clean = phone.lstrip('+')
print(f"  {CYAN}→{NC} Truecaller : {DIM}https://www.truecaller.com/search/id/{clean}{NC}")
print(f"  {CYAN}→{NC} GetContact  : {DIM}https://www.getcontact.com/en/phone/{phone}{NC}")
print(f"  {CYAN}→{NC} WhoCalledMe : {DIM}https://whocalledme.com/PhoneNumber/{clean}{NC}")
PYEOF
}

cid_single() {
  banner
  echo -e "${CYAN}${BOLD}  📞 Caller ID Lookup${NC}\n"
  echo -ne "${WHITE}  Nomor HP${NC} (contoh: 08123456789 atau +628123456789): "
  read -r phone
  [[ -z "$phone" ]] && { err "Kosong!"; pause; return; }
  spinner_start "Looking up"
  cid_lookup "$phone"
  spinner_stop "Done"
  pause
}

cid_bulk() {
  banner
  echo -e "${CYAN}${BOLD}  📞 Bulk Caller ID${NC}\n"
  echo -e "  ${DIM}Masukkan nomor satu per baris, ketik END setelah selesai${NC}\n"
  NUMS=()
  while true; do
    echo -ne "  Nomor: "
    read -r n
    [[ "$n" == "END" || -z "$n" ]] && break
    NUMS+=("$n")
  done
  [[ ${#NUMS[@]} -eq 0 ]] && { err "Kosong!"; pause; return; }
  for i in "${!NUMS[@]}"; do
    progress_bar $((i+1)) ${#NUMS[@]} "Looking up"
    section "Nomor $((i+1)): ${NUMS[$i]}"
    cid_lookup "${NUMS[$i]}"
  done
  pause
}
