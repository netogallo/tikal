from os import path
import tempfile

nahual = ${nahual}
image = ${disk-image}
ssh_private_key = ${ssh-private-key}
ssh_public_key = ${ssh-public-key}
output_directory = $(pwd)
output_name = ${output-image-name}
image_root_partition = ${image-root-partition}

# Todo: Parse CMD args, override variables above with appropiate values
# based on the args
output = path.join(output_directory, output_name)

print("\n".join([
  f"Welcome to the installation media generator for the nahual '{nahual}'.",
  f"This will generate an installation image at '{output}'. Please type (YES)",
  "followed by Enter to proceed."]))
proceed = input()

if proceed != "YES":
  raise Exception("Aborted by user ({proceed} != 'YES')!")

if ssh_private_key.startswith('/nix'):
  ssh_private_key = path.join($(pwd), *ssh_private_key.split(path.sep)[4:])

if not path.isfile(ssh_private_key):
  raise Exception("\n".join([
  f"Could not locate the private key for nahual '{nahual}'. Searched",
  f"the location {ssh_private_key}. Please ensure:",
  f"(1) The Tikal configuration is up-to date. Run the 'sync' command to be sure."
  f"(2) You are running this command from the falke's root directory."]))

rm -rf f"{output}"
cp f"{image}" f"{output}"
chmod +w f"{output}"

loop_device = $(${losetup} --find --show f"{output}")
${kpartx} -a f"{loop_device}"
loop_device_basename = $(basename f"{loop_device}")
loop_root = f"/dev/mapper/{loop_device_basename}{image_root_partition}"
mnt_root = tempfile.mkdtemp()

mount f"{loop_root}" f"{mnt_root}"

ssh_root = f"{mnt_root}/root/.ssh"
mkdir -p f"{ssh_root}"
cp f"{ssh_private_key}" f"{ssh_root}/id_ed25519" 
cp f"{ssh_public_key}" f"{ssh_root}/id_ed25519.pub"
chown -R root:root f"{ssh_root}"
chmod 644 f"{ssh_root}"

for file in $(ls f"{ssh_root}").splitlines():
  chmod 600 f"{ssh_root}/{file}"

umount f"{mnt_root}"
${kpartx} -d f"{loop_device}"
${losetup} -d f"{loop_device}"

print(f"Installation media successfully created at {output}")
