{ xsh, universe, openssh, ... }:
let
  _x = 42;
in
{
  script = xsh.write-script {
    name = "keys.xsh";
    vars = { nahuales = universe.nahuales; };
    script = { vars, ... }: ''
      from os import path
      import base64
      from random import randbytes

      def init_keys_for(tikal, name, nahual):

        private_keys_dir = tikal.get_directory(nahual.private.tikal_keys.root, create=True)
        public_keys_dir = tikal.get_directory(nahual.public.tikal_keys.root, create=True)
        tikal_main = tikal.get_file(nahual.private.tikal_keys.tikal_main)
        tikal_main_pass = tikal.get_file(nahual.private.tikal_keys.tikal_main_pass)

        tikal_main_enc = tikal.get_file(nahual.public.tikal_keys.tikal_main_enc)
        tikal_main_pub = tikal.get_file(nahual.public.tikal_keys.tikal_main_pub)
        tikal_main_pub_base = path.basename(tikal_main_pub)

        # If a private key is present, the creation can be skipped as
        # tikal is meant to be usable even if only public data is available.
        # However, the encrypted private key is also expected to be present
        # as it is needed to generate the final image.
        if path.isfile(tikal_main_pub) and path.isfile(tikal_main_enc):
          tikal.log_info(f"Found public keys for {name} at '{tikal_main_pub}'. Skipping creation.")
          return
        elif path.isfile(tikal_main_pub):
          raise Exception(f"""
              Missing ecrypted private key for {name} at '{tikal_main_enc}'.
              To proceed, you must either delete the public key at '{tikal_main_pub}'
              or supply the corresponding encrypted private key at '{tikal_main_enc}'
              """
          )

        # Fresh set of keys will be created as public keys are not available
        tikal.log_info(f"Creating fresh tikal keys for {name}")
        ${openssh}/bin/ssh-keygen -t ed25519 -f f"{tikal_main}" -N ""
        mv f"{private_keys_dir}/{tikal_main_pub_base}" f"{public_keys_dir}/"

        # Now we create the encrypted private key
        password = base64.b64encode(randbytes(18)).decode()
        with open(tikal_main_pass, 'w') as pf:
          pf.write(password)
        cp f"{tikal_main}" f"{tikal_main_enc}"
        ssh-keygen -p -f f"{tikal_main_enc}" -N f"{password}"

      def init_keys(tikal):
        nahuales = ${vars.nahuales}
        for name,nahual in nahuales.items():
          init_keys_for(tikal, name, nahual)
    '';
  };
}

