#!/bin/bash

password=""
user=""
display=""
usage="Usage: tikal-vnc [-p vnc_password] [-u vnc_user] [-d wayland_display]"

while getopts "u:p:d:" opt; do
  case ${opt} in
    p )
      password=$OPTARG
      echo "parsed $OPTARG"
      ;;
    u )
      user=$OPTARG
      echo "parsed $OPTARG"
      ;;
    d )
      display=$OPTARG
      echo "parsed $OPTARG"
      ;;
    \? )
      echo $usage
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))

if [ -z "$user" ] || [ -z "$password" ] || [ -z "$display" ]; then
  echo $usage
  exit 1
fi

WORKING_DIR=$(mktemp -d)

PAM_DIR=$WORKING_DIR/pam.d
PAM_WESTON=$PAM_DIR/weston-remote-access
mkdir -p $PAM_DIR

CERTS_DIR=$WORKING_DIR/ssl
mkdir -p $CERTS_DIR

PASSDB=$WORKING_DIR/passdb
echo "$user:$password:weston-remote-access" > $PASSDB
PASSDB=$PASSDB envsubst -i $PAM_TEMPLATE -o $PAM_WESTON

TLS_KEY=$CERTS_DIR/tls.key
TLS_CSR=$CERTS_DIR/tls.csr
TLS_CRT=$CERTS_DIR/tls.crt
openssl genrsa -out $TLS_KEY 2048
openssl req -new -key $TLS_KEY -out $TLS_CSR
openssl x509 -req -days 365 -signkey $TLS_KEY -in $TLS_CSR -out $TLS_CRT

# LD_PRELOAD=libpam_wrapper.so:pam_matrix.so PAM_WRAPPER=1 PAM_WRAPPER_SERVICE_DIR=$PAM_DIR weston -B vnc -S $wayland_display \
#	--backend=vnc --vnc-tls-key=$TLS_KEY --vnc-tls-cert=$TLS_CRT --port 3000 --renderer gl

weston
