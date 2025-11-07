{ lib, tikal, pkgs, ... }:
let
  inherit (tikal.prelude) do;
  inherit (tikal.prelude.test) with-tests;
  inherit (tikal.syslog) with-logger;
  post-decrypt-scripts-directory = "post_decrypt";
  set-ownership =
    { user ? null, group ? null, logger ? null }: { name, ... }:
    let
      log = with-logger logger;
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
        ${log} --tag=secrets -d "Setting ownership of ${name} to ${owner}" 
      '';
      script = do [
        ownership
        "$>" lib.map to-ownership-script
        "|>" lib.concatStringsSep "\n"
      ];
    in
      pkgs.writeScript "post-decrypt-${name}" script
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
        ''ln -s ${script} "$out/${post-decrypt-scripts-directory}/"''
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
        WORKDIR=$(mktemp -d)
        PUBLIC="$WORKDIR/public"
        PRIVATE="$WORKDIR/private"
        out="$WORKDIR" public="$PUBLIC" private="$PRIVATE" ${mk-secret}
        mkdir -p "$out"
        ${pkgs.gnutar}/bin/tar -cC "$PRIVATE" . | \
          ${pkgs.age}/bin/age -R "${tikal-key}" -o "$out/private" 
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
          -d "Running post-decrtyp scripts at $DIR"

        for script in "$DIR"/*; do
        	if [[ -f "$script" && -x "$script" ]]; then
        		private="${dest}" "$script"
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
      ${pkgs.age}/bin/age -d -i "${tikal-private-key}" "${secret}/private" \
        | ${pkgs.gnutar}/bin/tar -xC "${dest}"

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
    inherit to-nahual-secret to-decrypt-script set-ownership;
  }
  {
    tikal.store.secrets = {};
  }
