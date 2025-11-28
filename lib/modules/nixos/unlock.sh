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
  PASSPHRASE="$1"

  AGE_SCRIPT='
  spawn ${age} -d -o '"$TMP_KEY"' "${tikal-main-enc.source}"
  expect "Enter passphrase"
  send "'"$PASSPHRASE"'\r"
  expect {
    "error" {
      expect eof
      exit 1
    } eof {
      exit 0
    }
  }
  '

  echo "DEBUG age script: $AGE_SCRIPT"
  ${expect} -c "$AGE_SCRIPT"
  RESULT="$?"

  if [ "$RESULT" == "0" ]; then
    mkdir -p "${tikal-decrypt-keys-directory}"
    mv "$TMP_KEY" "${tikal-decrypt-master-key-file}"
    echo "Success! Decrypted key to /run/keys/tikal/id_tikal"
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
  else
    echo "This Tikal image has not been unlocked. Please enter the unlock key when prompted"
    success="1"
  fi

  while [[ "$success" != "0" ]]; do
    read -sr -p "Enter SSH key passphrase: " PASSPHRASE
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
