#!/bin/bash
# modules/password.sh

password_menu() {
  while true; do
    banner
    echo -e "${CYAN}${BOLD}  🔑 Password & Hash Tools${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Generate hash (MD5 / SHA1 / SHA256 / SHA512)"
    echo -e "  ${GREEN}[2]${NC} Identify hash type"
    echo -e "  ${GREEN}[3]${NC} John the Ripper — Crack hash"
    echo -e "  ${GREEN}[4]${NC} Hydra — Brute force SSH"
    echo -e "  ${GREEN}[5]${NC} Hydra — Brute force FTP"
    echo -e "  ${GREEN}[6]${NC} Hydra — Brute force HTTP login"
    echo -e "  ${GREEN}[7]${NC} Generate password acak"
    echo -e "  ${GREEN}[8]${NC} Generate wordlist custom (cupp-style)"
    echo -e "  ${RED}[0]${NC} ← Kembali"
    echo ""
    echo -ne "${WHITE}  Pilih${NC}: "
    read -r opt
    case $opt in
      1)
        echo -ne "${WHITE}  Teks${NC}: "
        read -r teks
        [[ -z "$teks" ]] && { err "Teks kosong!"; continue; }
        section "Hash Generator"
        echo -e "  ${CYAN}MD5:   ${NC} $(echo -n "$teks" | md5sum    | awk '{print $1}')"
        echo -e "  ${CYAN}SHA1:  ${NC} $(echo -n "$teks" | sha1sum   | awk '{print $1}')"
        echo -e "  ${CYAN}SHA256:${NC} $(echo -n "$teks" | sha256sum | awk '{print $1}')"
        echo -e "  ${CYAN}SHA512:${NC} $(echo -n "$teks" | sha512sum | awk '{print $1}')"
        pause ;;
      2)
        echo -ne "${WHITE}  Hash${NC}: "
        read -r hash
        [[ -z "$hash" ]] && { err "Hash kosong!"; continue; }
        len=${#hash}
        section "Hash Identifier"
        echo -e "  Length  : ${YELLOW}$len chars${NC}"
        case $len in
          32)  echo -e "  Possible: ${GREEN}MD5 / MD4 / NTLM${NC}" ;;
          40)  echo -e "  Possible: ${GREEN}SHA-1 / MySQL5${NC}" ;;
          56)  echo -e "  Possible: ${GREEN}SHA-224${NC}" ;;
          64)  echo -e "  Possible: ${GREEN}SHA-256 / Keccak-256${NC}" ;;
          96)  echo -e "  Possible: ${GREEN}SHA-384${NC}" ;;
          128) echo -e "  Possible: ${GREEN}SHA-512 / Whirlpool${NC}" ;;
          60)  echo -e "  Possible: ${GREEN}bcrypt (starts with \$2)${NC}" ;;
          *)   echo -e "  Possible: ${YELLOW}Unknown / custom format${NC}" ;;
        esac
        # cek prefix
        [[ "$hash" == "\$2"* ]]  && echo -e "  Prefix  : ${GREEN}bcrypt detected${NC}"
        [[ "$hash" == "\$1\$"* ]] && echo -e "  Prefix  : ${GREEN}MD5crypt detected${NC}"
        [[ "$hash" == "\$6\$"* ]] && echo -e "  Prefix  : ${GREEN}SHA-512crypt detected${NC}"
        pause ;;
      3)
        check_tool john || continue
        echo -ne "${WHITE}  File hash${NC}: "
        read -r hashfile
        [[ ! -f "$hashfile" ]] && { err "File tidak ditemukan!"; continue; }
        echo -ne "${WHITE}  Wordlist${NC} (Enter untuk default): "
        read -r wordlist
        if [[ -z "$wordlist" ]]; then
          # cari rockyou
          for w in \
            "$HOME/../usr/share/wordlists/rockyou.txt" \
            "/usr/share/wordlists/rockyou.txt" \
            "$HOME/wordlists/rockyou.txt"; do
            [[ -f "$w" ]] && wordlist="$w" && break
          done
        fi
        if [[ -z "$wordlist" || ! -f "$wordlist" ]]; then
          warn "Wordlist tidak ditemukan."
          echo -ne "${WHITE}  Path wordlist${NC}: "
          read -r wordlist
          [[ ! -f "$wordlist" ]] && { err "File tidak ada!"; continue; }
        fi
        section "John the Ripper → $hashfile"
        john "$hashfile" --wordlist="$wordlist"
        echo ""
        info "Hasil crack:"
        john "$hashfile" --show
        pause ;;
      4)
        check_tool hydra || continue
        get_target || continue
        echo -ne "${WHITE}  Username / file user${NC}: "
        read -r user
        echo -ne "${WHITE}  Wordlist password${NC}: "
        read -r passlist
        [[ ! -f "$passlist" ]] && { err "Wordlist tidak ada!"; continue; }
        echo -ne "${WHITE}  Port SSH${NC} [default 22]: "
        read -r port
        port=${port:-22}
        section "Hydra SSH → $TARGET:$port"
        hydra -l "$user" -P "$passlist" -t 4 -s "$port" ssh://"$TARGET"
        pause ;;
      5)
        check_tool hydra || continue
        get_target || continue
        echo -ne "${WHITE}  Username / file user${NC}: "
        read -r user
        echo -ne "${WHITE}  Wordlist password${NC}: "
        read -r passlist
        [[ ! -f "$passlist" ]] && { err "Wordlist tidak ada!"; continue; }
        section "Hydra FTP → $TARGET"
        hydra -l "$user" -P "$passlist" -t 4 ftp://"$TARGET"
        pause ;;
      6)
        check_tool hydra || continue
        echo -ne "${WHITE}  URL login${NC} (contoh http://site.com/login): "
        read -r url
        echo -ne "${WHITE}  Form data${NC} (contoh user=^USER^&pass=^PASS^): "
        read -r formdata
        echo -ne "${WHITE}  String gagal login${NC} (contoh: Invalid): "
        read -r failstr
        echo -ne "${WHITE}  Username${NC}: "
        read -r user
        echo -ne "${WHITE}  Wordlist${NC}: "
        read -r passlist
        [[ ! -f "$passlist" ]] && { err "Wordlist tidak ada!"; continue; }
        section "Hydra HTTP POST → $url"
        hydra -l "$user" -P "$passlist" "$url" \
          http-post-form "${url##http*://*/}:${formdata}:${failstr}"
        pause ;;
      7)
        echo -ne "${WHITE}  Panjang${NC} [default 16]: "
        read -r len
        len=${len:-16}
        echo -ne "${WHITE}  Karakter${NC} [1=alphanumeric 2=+simbol]: "
        read -r copt
        section "Password Generator"
        if [[ "$copt" == "2" ]]; then
          pass=$(cat /dev/urandom | tr -dc 'A-Za-z0-9!@#$%^&*()-_=+' | head -c "$len")
        else
          pass=$(cat /dev/urandom | tr -dc 'A-Za-z0-9' | head -c "$len")
        fi
        ok "Password: ${WHITE}${BOLD}$pass${NC}"
        pause ;;
      8)
        section "Wordlist Generator"
        echo -ne "${WHITE}  Nama target${NC}: "
        read -r name
        echo -ne "${WHITE}  Tanggal lahir${NC} (DDMMYYYY): "
        read -r dob
        echo -ne "${WHITE}  Kata favorit / nama hewan peliharaan${NC}: "
        read -r word
        echo -ne "${WHITE}  Output file${NC} [default wordlist.txt]: "
        read -r outfile
        outfile=${outfile:-wordlist.txt}

        info "Generating wordlist..."
        > "$outfile"
        name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
        name_upper=$(echo "$name" | tr '[:lower:]' '[:upper:]')
        word_lower=$(echo "$word" | tr '[:upper:]' '[:lower:]')

        for base in "$name" "$name_lower" "$name_upper" "$word" "$word_lower" \
                    "${name}${dob}" "${name_lower}123" "${name}${word}" \
                    "${name}${dob:4:4}" "${word}${dob:0:4}" \
                    "${name_lower}${word_lower}" "${name}!" "${name}@" \
                    "admin" "password" "123456" "${name}2024" "${name}2025"; do
          echo "$base" >> "$outfile"
        done

        ok "Wordlist disimpan di: ${CYAN}$outfile${NC} ($(wc -l < "$outfile") entries)"
        pause ;;
      0) break ;;
      *) err "Pilihan tidak valid!"; sleep 1 ;;
    esac
  done
}
