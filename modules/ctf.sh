#!/bin/bash
# modules/ctf.sh

ctf_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🚩 CTF Tools${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC}  Strings — Extract teks dari binary"
    echo -e "  ${GREEN}[2]${NC}  Binwalk — Analisis / extract file"
    echo -e "  ${GREEN}[3]${NC}  Exiftool — Baca metadata file"
    echo -e "  ${GREEN}[4]${NC}  Steghide — Embed / extract stego"
    echo -e "  ${GREEN}[5]${NC}  ROT / Caesar cipher (brute semua shift)"
    echo -e "  ${GREEN}[6]${NC}  Base64 encode / decode"
    echo -e "  ${GREEN}[7]${NC}  Hex encode / decode"
    echo -e "  ${GREEN}[8]${NC}  URL encode / decode"
    echo -e "  ${GREEN}[9]${NC}  XOR brute force (single byte)"
    echo -e "  ${GREEN}[10]${NC} Binary → Teks"
    echo -e "  ${GREEN}[11]${NC} Hash file (MD5/SHA256)"
    echo -e "  ${GREEN}[12]${NC} File magic / type checker"
    echo -e "  ${RED}[0]${NC}  ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        echo -ne "${WHITE}  File${NC}: "
        read -r file
        [[ ! -f "$file" ]] && { err "File tidak ada!"; continue; }
        section "Strings → $file"
        echo -ne "${WHITE}  Min length${NC} [default 4]: "
        read -r minlen
        minlen=${minlen:-4}
        strings -n "$minlen" "$file" | less
        pause ;;
      2)
        check_tool binwalk || continue
        echo -ne "${WHITE}  File${NC}: "
        read -r file
        [[ ! -f "$file" ]] && { err "File tidak ada!"; continue; }
        echo -ne "${WHITE}  Mode${NC} [1=analisis 2=extract]: "
        read -r mode
        section "Binwalk → $file"
        if [[ "$mode" == "2" ]]; then
          binwalk -e "$file"
          ok "Hasil extract di folder: ${CYAN}_${file}.extracted/${NC}"
        else
          binwalk "$file"
        fi
        pause ;;
      3)
        check_tool exiftool || continue
        echo -ne "${WHITE}  File${NC}: "
        read -r file
        [[ ! -f "$file" ]] && { err "File tidak ada!"; continue; }
        section "Exiftool → $file"
        exiftool "$file"
        pause ;;
      4)
        check_tool steghide || continue
        echo -ne "${WHITE}  Mode${NC} [1=embed 2=extract]: "
        read -r mode
        if [[ "$mode" == "1" ]]; then
          echo -ne "${WHITE}  Cover file (jpg/bmp)${NC}: "
          read -r cover
          echo -ne "${WHITE}  Secret file${NC}: "
          read -r secret
          [[ ! -f "$cover" || ! -f "$secret" ]] && { err "File tidak ada!"; continue; }
          section "Steghide Embed"
          steghide embed -cf "$cover" -sf "$secret"
          ok "Berhasil! Data tersembunyi di $cover"
        else
          echo -ne "${WHITE}  Stego file${NC}: "
          read -r stfile
          [[ ! -f "$stfile" ]] && { err "File tidak ada!"; continue; }
          section "Steghide Extract"
          steghide extract -sf "$stfile"
        fi
        pause ;;
      5)
        echo -ne "${WHITE}  Teks${NC}: "
        read -r teks
        [[ -z "$teks" ]] && { err "Kosong!"; continue; }
        section "Caesar / ROT Brute Force"
        python3 - <<PYEOF
text = """$teks"""
for shift in range(1, 26):
    result = ""
    for c in text:
        if c.isalpha():
            base = ord('A') if c.isupper() else ord('a')
            result += chr((ord(c) - base + shift) % 26 + base)
        else:
            result += c
    print(f"  ROT{shift:2d} (shift {shift:2d}): {result}")
PYEOF
        pause ;;
      6)
        echo -ne "${WHITE}  Mode${NC} [1=encode 2=decode]: "
        read -r mode
        echo -ne "${WHITE}  Input${NC}: "
        read -r input
        section "Base64"
        if [[ "$mode" == "1" ]]; then
          ok "Encoded: ${CYAN}$(echo -n "$input" | base64)${NC}"
        else
          result=$(echo "$input" | base64 -d 2>/dev/null)
          if [[ $? -eq 0 ]]; then
            ok "Decoded: ${CYAN}$result${NC}"
          else
            err "Gagal decode — bukan format base64 valid"
          fi
        fi
        pause ;;
      7)
        echo -ne "${WHITE}  Mode${NC} [1=encode 2=decode]: "
        read -r mode
        echo -ne "${WHITE}  Input${NC}: "
        read -r input
        section "Hex"
        if [[ "$mode" == "1" ]]; then
          ok "Hex: ${CYAN}$(echo -n "$input" | xxd -p | tr -d '\n')${NC}"
        else
          result=$(echo "$input" | xxd -r -p 2>/dev/null)
          if [[ $? -eq 0 ]]; then
            ok "Decoded: ${CYAN}$result${NC}"
          else
            err "Gagal decode — pastikan input hex valid"
          fi
        fi
        pause ;;
      8)
        echo -ne "${WHITE}  Mode${NC} [1=encode 2=decode]: "
        read -r mode
        echo -ne "${WHITE}  Input${NC}: "
        read -r input
        section "URL Encode/Decode"
        python3 -c "
import urllib.parse, sys
mode = '$mode'
inp  = '$input'
if mode == '1':
    print('  Encoded:', urllib.parse.quote(inp))
else:
    print('  Decoded:', urllib.parse.unquote(inp))
"
        pause ;;
      9)
        echo -ne "${WHITE}  Hex string${NC} (contoh: 1a2b3c4d): "
        read -r hexstr
        [[ -z "$hexstr" ]] && { err "Kosong!"; continue; }
        section "XOR Brute Force (single byte)"
        python3 - <<PYEOF
hexstr = "$hexstr".replace(" ","")
try:
    data = bytes.fromhex(hexstr)
except ValueError:
    print("  Error: hex string tidak valid")
    exit()
print(f"  {'Key':<8} {'Hex':>6}  Result")
print("  " + "-"*50)
for key in range(256):
    result = bytes([b ^ key for b in data])
    try:
        decoded = result.decode('ascii')
        if all(32 <= c < 127 for c in result):
            print(f"  key=0x{key:02X} ({key:3d})  {decoded}")
    except:
        pass
PYEOF
        pause ;;
      10)
        echo -ne "${WHITE}  Binary string${NC} (contoh: 01001000 01101001): "
        read -r binstr
        section "Binary → Teks"
        python3 -c "
b = '$binstr'.split()
try:
    result = ''.join(chr(int(x,2)) for x in b)
    print(f'  Result: {result}')
except:
    print('  Error: binary string tidak valid')
"
        pause ;;
      11)
        echo -ne "${WHITE}  File${NC}: "
        read -r file
        [[ ! -f "$file" ]] && { err "File tidak ada!"; continue; }
        section "File Hash → $file"
        echo -e "  ${CYAN}MD5:   ${NC} $(md5sum    "$file" | awk '{print $1}')"
        echo -e "  ${CYAN}SHA1:  ${NC} $(sha1sum   "$file" | awk '{print $1}')"
        echo -e "  ${CYAN}SHA256:${NC} $(sha256sum "$file" | awk '{print $1}')"
        pause ;;
      12)
        echo -ne "${WHITE}  File${NC}: "
        read -r file
        [[ ! -f "$file" ]] && { err "File tidak ada!"; continue; }
        section "File Type → $file"
        # baca magic bytes
        magic=$(xxd -l 16 "$file" | head -1)
        echo -e "  ${CYAN}Magic bytes:${NC} $magic"
        echo ""
        # cek signature umum
        sig=$(xxd -l 4 -p "$file" 2>/dev/null)
        case "$sig" in
          "ffd8ff"*)      ok "JPEG Image" ;;
          "89504e47")     ok "PNG Image" ;;
          "47494638")     ok "GIF Image" ;;
          "25504446")     ok "PDF Document" ;;
          "504b0304")     ok "ZIP / Office / APK" ;;
          "7f454c46")     ok "ELF Executable (Linux/Android)" ;;
          "4d5a"*)        ok "Windows PE Executable" ;;
          "1f8b"*)        ok "Gzip compressed" ;;
          "425a68"*)      ok "Bzip2 compressed" ;;
          "52617221")     ok "RAR Archive" ;;
          "cafebabe")     ok "Java Class / Mach-O Fat Binary" ;;
          *)              warn "Unknown magic: $sig" ;;
        esac
        file "$file" 2>/dev/null && echo ""
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
