try_get_passphrase_from_cmdline() {

  success=1
  for arg in $(cat /proc/cmdline); do
  	case $arg in
  		tikal.debug.master-key=*)
  			master_key=''${arg#tikal.debug.master-key=}
  			echo "$master_key"
        success=0
        break
  			;;
  	esac
  done

  return $success
}

try_get_passphrase_from_filesystem() {
  PASSPHRASE_FILE="/var/tikal/id_master_passphrase"

  if [ -f "$PASSPHRASE_FILE" ]; then
    cat "$PASSPHRASE_FILE"
    return 0
  fi

  return 1
}

decrypt_tikal_master_key() {
  TMP_KEY=$(mktemp)
  
  echo "Attempt decryption of ${tikal-secrets.tikal-private-key-enc}"
  PASSPHRASE="$1" ${openssl} enc -d -aes-128-cbc \
      -pass "env:PASSPHRASE" -iter 600000 -base64 -pbkdf2 \
      -in "${tikal-secrets.tikal-private-key-enc}" -out "$TMP_KEY"
  RESULT="$?"

  if [ "$RESULT" == "0" ]; then

    key_dir=$(dirname "${tikal-secrets.tikal-private-key}")
    mkdir -p "$key_dir"
    mv "$TMP_KEY" "${tikal-secrets.tikal-private-key}"

    chown -R "${tikal-user}:${tikal-group}" "$key_dir"
    chmod 700 "$key_dir"
    chmod 600 "${tikal-secrets.tikal-private-key}"
    echo "Success! Decrypted key to ${tikal-secrets.tikal-private-key}"
    return 0
  else
    echo "Incorrect password was supplied. Try again"
    return 1
  fi
}

decrypt_main() {
  PASSPHRASE="$(try_get_passphrase_from_cmdline)"
  success="$?"

  if [[ "$success" == 0 ]]; then
    decrypt_tikal_master_key "$PASSPHRASE"
    success="$?"
  fi

  if [[ "$success" != 0 ]]; then
    PASSPHRASE="$(try_get_passphrase_from_filesystem)"
    success="$?"

    if [[ "$success" == 0 ]]; then
      decrypt_tikal_master_key "$PASSPHRASE"
      success="$?"
    fi
  fi

  if [[ "$success" != 0 ]]; then
    echo "This Tikal image has not been unlocked. Please enter the unlock key when prompted"
  fi

  attempts=0
  while [[ "$success" != "0" ]]; do
    if [[ "$attempts" -ge 10 ]]; then
      ${log} --tag=unlock -d "Unlocking failed. Tikal functionality will be unavailable."
      return 1
    fi

    read -sr -p "Enter master key passphrase: " PASSPHRASE
    decrypt_tikal_master_key "$PASSPHRASE"
    success="$?"
    attempts=$((attempts + 1))
  done
}

if [ ! -f "${tikal-secrets.tikal-private-key}" ]; then
  ${log} --tag=unlock -d "Attempting decryption of '${tikal-secrets.tikal-private-key}'"
  decrypt_main
else
  ${log} --tag=unlock -d "The key '${tikal-secrets.tikal-private-key}' is ready."
fi
