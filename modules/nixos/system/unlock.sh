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

decrypt_tikal_master_key() {
  TMP_KEY=$(mktemp)
  
  echo "Attempt decryption of ${tikal-main-enc.source}"
  PASSPHRASE="$1" ${openssl} enc -d -aes-128-cbc \
      -pass "env:PASSPHRASE" -iter 600000 -base64 -pbkdf2 \
      -in "${tikal-main-enc.source}" -out "$TMP_KEY"
  RESULT="$?"

  if [ "$RESULT" == "0" ]; then
    mkdir -p "${tikal-decrypt-keys-directory}"
    mv "$TMP_KEY" "${tikal-decrypt-master-key-file}"
    echo "Success! Decrypted key to ${tikal-decrypt-master-key-file}"
    return 0
  else
    echo "Incorrect password was supplied. Try again"
    return 1
  fi
}

decrypt_main() {
  PASSPHRASE="$(try_get_passphrase_from_cmdline)"
  success="$?"

  bash

  if [[ "$success" == 0 ]]; then
    decrypt_tikal_master_key "$PASSPHRASE"
    success="$?"
  else
    echo "This Tikal image has not been unlocked. Please enter the unlock key when prompted"
    success="1"
  fi

  while [[ "$success" != "0" ]]; do
    read -sr -p "Enter master key passphrase: " PASSPHRASE
    decrypt_tikal_master_key "$PASSPHRASE"
    success="$?"

    if [[ "$success" == "0" ]]; then
      read -sr -p "Press enter to continue: " X
      echo "$X"
    fi
  done
}

if [ ! -f "${tikal-paths.tikal-main}" ]; then
  decrypt_main
fi
