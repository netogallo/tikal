def init_keys_for(tikal, name, nahual):

  tikal_main_pass = tikal.get_file(nahual.private.tikal_keys.tikal_main_pass, create_directory=True)
  tikal_main_enc = tikal.get_file(nahual.public.tikal_keys.tikal_main_enc, create_directory=True)
  tikal_main_pub = tikal.get_file(nahual.public.tikal_keys.tikal_main_pub, create_directory=True)

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

  master_keys = ${vars.nahual-master-keys}
  master_key = master_keys[name]
  # Write the public key
  tikal.log_info(f"Writing public key for {name} to {tikal_main_pub}")
  with open(tikal_main_pub, 'w') as ostream:
    ostream.write(master_key.public_key)

  # Write the encrypted master key
  tikal.log_info(f"Writing the encrypted master key for {name} to {tikal_main_enc}")
  with open(tikal_main_enc, 'w') as ostream:
    ostream.write(master_key.private_key_enc)

  # Export the master key passphrase to the private
  # directory
  tikal.log_info(f"Writing the master key passphrase for {name} to {tikal_main_pass}")
  @(f"{master_key.passphrase_export}/bin/passphrase-export") f"{tikal_main_pass}"

def init_keys(tikal):
  nahuales = ${vars.nahuales}
  for name,nahual in nahuales.items():
    init_keys_for(tikal, name, nahual)
