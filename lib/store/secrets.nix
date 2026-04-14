{ lib, tikal, pkgs, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal.syslog) with-logger;
  post-decrypt-scripts-directory = "post_decrypt";
  set-ownership =
    { user ? null, group ? null, logger ? null }: { name, ... }:
    let
      # If a specific user/group is supplied, the
      # decrypted directory's ownership is changed
      # to reflect said user/group combination.
      ownership =
        if user != null && group != null
        then [ "${user}:${group}" ]
        else if user != null
        then [ "${user}" ]
        else if group != null
        then [ ":${group}" ]
        else []
      ;
      to-ownership-script = owner: ''
        chown -R ${owner} "$private"
        $log --tag=secrets -d "Setting ownership of ${name} to ${owner}" 
      '';
      script = do [
        ownership
        "$>" lib.map to-ownership-script
        "|>" lib.concatStringsSep "\n"
      ];
    in
      pkgs.writeScript "post-decrypt-${name}" script
  ;

  to-post-decrypt-script = { name, text }: args:
    let
      script = pkgs.writeScript "post-decrypt-${name}-${args.name}" text;
    in
      script
  ;
  # Create a derivation containing an encrypted secret. This function
  # accepts a public key and a procedure to generate a secret. It then
  # creates a derivation that uses the procedure to generate a secret
  # and then encrypts it using the public key before it gets saved
  # to the nix store.
  #
  # Optionally, this function accepts a list of scripts to be called
  # once the nixos activation script is used to decrypt these secrets.
  to-nahual-secret = { name, tikal-key, text, post-decrypt ? [] }:
    let
      mk-secret = pkgs.writeScript name text;
      link-post-decrypt-scripts = script:
        # Todo: ideally, we should use symlinks, but
        # this is tricky as the system running sync
        # might not be the one running the post-decrypt
        # stages. Therefore, we must copy.
        ''
        cp ${script} "$out/${post-decrypt-scripts-directory}/"
        chmod +x "$out/${post-decrypt-scripts-directory}/"
        ''
      ;
      post-decrypt-text = do [
        post-decrypt
        "$>" map (mk-script: mk-script { inherit name; })
        "|>" map link-post-decrypt-scripts
        "|>" lib.concatStringsSep "\n"
      ];
    in
      pkgs.runCommandLocal name {}
        ''
        export PATH="${pkgs.openssl}/bin/:$PATH"
        WORKDIR=$(mktemp -d)
        PUBLIC="$WORKDIR/public"
        PRIVATE="$WORKDIR/private"

        out="$WORKDIR" public="$PUBLIC" private="$PRIVATE" ${mk-secret}
        mkdir -p "$out"
        # Hybrid key encryption
        # Generate the AES random key
        openssl rand -hex 32 > aes_key.bin

        # Encrypt the symmetric key using the public key
        openssl pkeyutl -encrypt -pubin \
            -inkey "${tikal-key}" -in aes_key.bin \
            -out "$out/key.bin"

        # Encrypt the data using the symmetric key
        ${pkgs.gnutar}/bin/tar -cC "$PRIVATE" . | \
          openssl enc -aes-256-cbc -out "$out/private" \
          -pass file:aes_key.bin -pbkdf2 -nosalt

        # Delete the symmetric un-encrypted symmetric key
        rm aes_key.bin

        mv "$WORKDIR/public" "$out/public"
        mkdir "$out/${post-decrypt-scripts-directory}"
        ${post-decrypt-text}
        rm -rf "$WORKDIR"
        ''
  ;

  to-decrypt-script = { tikal-private-key, secret, dest, logger ? null }:
    let
      log = with-logger logger;
      post-decrypt = pkgs.writeScript "post-decrypt"
        ''
        DIR="${secret}/${post-decrypt-scripts-directory}"
        ${log} --tag=secrets \
          -d "Running post-decrypt scripts at $DIR"

        for script_ref in "$DIR"/*; do
          script=$(readlink -f "$script_ref")
        	if [[ -f "$script" && -x "$script" ]]; then
        		private="${dest}" public="${secret}/public" log="${log}" "$script"
        	else
            ${log} --tag=secrets \
              -e "The script '$script' is not executable. Skipping"
        	fi
        done
        ''
      ;
    in
      pkgs.writeScript "decrypt-script"
      ''
      rm -rf "${dest}"
      mkdir -p "${dest}"

      # Log message
      ${log} --tag=secrets \
        -d "Decrypging '${dest}' from '${secret}/private' using '${tikal-private-key}'"

      # Perform decryption
      # First, the symmetric key is decrypted using the
      # tikal master key. This key is used to decrypt
      # the payload, which will be a tar archive.
      # The archive then gets extracted to the target
      # destination
      ${pkgs.openssl}/bin/openssl pkeyutl -decrypt \
        -inkey "${tikal-private-key}" \
        -in "${secret}/key.bin" | \
      ${pkgs.openssl}/bin/openssl enc -d -aes-256-cbc -pass stdin \
        -pbkdf2 -nosalt -in "${secret}/private" | \
      ${pkgs.gnutar}/bin/tar -xC "${dest}"

      # Check if decryption was successful
      if [ "$?" != 0 ]; then
        # Log error if decryption failed
        ${log} --tag=secrets \
          -e "Decryption failed for '${dest}' using key '${tikal-private-key}'"
        read -sr -p "Press enter to continue: " X
      else
        (cd "${dest}"; ${post-decrypt})
      fi
      ''
  ;

in
  with-tests
  {
    inherit to-nahual-secret to-decrypt-script set-ownership to-post-decrypt-script;
  }
  {
    tikal.store.secrets = {
      "It can encrypt and decrypt successfully" = { _assert, ... }:
        let
          expected = "expected-private";
          expected-public = "expected-public";
          make-secret = ''
            mkdir -p "$private"
            mkdir -p "$public"
            echo "${expected}" > "$private/expected.txt"
            echo "${expected-public}" > "$public/expected.txt"
          '';
          keys = pkgs.runCommandLocal "gen-keys" {} ''
            mkdir "$out"
            ${pkgs.openssl}/bin/openssl genrsa -out "$out/key.pem"
            ${pkgs.openssl}/bin/openssl rsa -pubout -in "$out/key.pem" -out "$out/pubkey.pem"
          '';
          secret = to-nahual-secret {
            name = "test-dummy";
            tikal-key = "${keys}/pubkey.pem";
            text = make-secret;
          };
          decrypt-script = to-decrypt-script {
            tikal-private-key = "${keys}/key.pem";
            inherit secret;
            dest = "$out";
          };
          decrypted = pkgs.runCommandLocal "decrypted" {} ''
            ${decrypt-script}
          '';
          actual = builtins.readFile "${decrypted}/expected.txt";
        in
          _assert.eq "${expected}\n" actual
      ;
    };
  }
