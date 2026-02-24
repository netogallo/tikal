from subprocess import CalledProcessError

$RAISE_SUBPROC_ERROR = True

# ------------------------------------------------
# Nix template variable replacements go here
# Avoid using them afterwards for easier editing
# ------------------------------------------------

nahual = "${nahual}"
platform_name = "${platform-name}"
boot_device = "${default-boot-device}"
install_device = "${default-root-device}"
boot_part_guid = "${bootfs.partuuid}"
root_part_guid = "${rootfs.partuuid}"
swap_part_guid = "${swapfs.partuuid}"
flake = "${flake}"
sgdisk = "${sgdisk}"
curl = "${curl}"
bootloader_installer = "${bootloader-installer}"

tikal_main_pub = "${tikal_main_pub}"
tikal_keys_directory = "${tikal-decrypt-keys-directory}"
tikal_master_key_file = "${tikal-decrypt-master-key-file}"

# ------------------------------------------------
# End of nixos variable declarations
# ------------------------------------------------

# Todo: configure cmdline args

try:
  # Check internet connectivity
  @(curl) --silent --head --fail "https://cache.nixos.org" >  /dev/null
except CalledProcessError:
  raise Exception("You must be connected to the internet to run this installer")

print("\n".join([
  f"Welcome to the Tikal installer for the Nahual '{nahual}'.",
  f"This installer will operate on the disk device '{install_device}'.",
  f"ALL DATA WILL ON THAT DRIVE WILL BE DESTROYED. To proceed, please",
  f"type 'YES' followed by enter."]))
response = input()

if response != "YES":
  raise Exception("Installation aborted by the user ({response} != 'YES'). No changes were done!")

print("\n".join([
  f"To proceed, the Tikal master key for '{nahual}' must be decrypted.",
  f"Please enter the decryption password when prompted"
]))

retries = 0

# Ensure the keys directory exists
mkdir -p @(tikal_keys_directory)

while True:
  try:
    # Attempt to decrypt the key with age
    # Todo: ideally, additional approaches to obtain the key
    #       should be supported. ie. OpenTofu
    @(age) -d -o @(tikal_master_key_file) @(tikal_main_pub)

    # Success! Key has been decrypted
    break
  except CalledProcessError as e:
    retries += 1
    if retries > 5:
      raise Exception("The user has failed to decrypt the key after 5 attempts. Aborting installation. This incident will be reported.")

print(f"Formatting the drive {boot_device}")

# Create a new set of partitions in the target
# installation device
@(sgdisk) --zap-all f"{boot_device}"
@(sgdisk) --clear f"{boot_device}"

# Create the boot partition. Leave a conservative 32MB margin
# before the parition for uboot
@(sgdisk) \
  --new=1:32MiB:+1GiB \
  f"--partition-guid=1:{boot_part_guid}" \
  --typecode=1:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
  --change-name=1:"tikal-boot" \
  f"{boot_device}"

partition_offset = 2

if boot_device != install_device:
  partition_offset = 1
  print(f"Formatting the drive {install_device}")
  @(sgdisk) --zap-all @(install_device)
  @(sgdisk) --clear @(install_device)

swap_offset = partition_offset
root_offset = swap_offset + 1

# Create the swap partition
# Todo: make it configurable for multiple devices
@(sgdisk) \
  f"--new={swap_offset}:0:+32GiB" \
  f"--partition-guid={swap_offset}:{swap_part_guid}" \
  f"--typecode={swap_offset}:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F" \
  f"--change-name={swap_offset}:\"tikal-swap\"" \
  f"{install_device}"

# Create the root partition
@(sgdisk) \
  f"--new={root_offset}:0:0" \
  f"--partition-guid={root_offset}:{root_part_guid}" \
  f"--typecode={root_offset}:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709" \
  f"--change-name={root_offset}:\"tikal-root\"" \
  f"{install_device}"

partprobe f"{install_device}"

# Todo: set fiesystem types based on the partition spec
mkfs.ext4 -F f"/dev/disk/by-partuuid/{boot_part_guid}"
mkswap f"/dev/disk/by-partuuid/{swap_part_guid}"
mkfs.btrfs -f f"/dev/disk/by-partuuid/{root_part_guid}"

print("Final partition table:")
@(sgdisk) -p f"{install_device}"

print(f"Installing bootloader on device {install_device}")

import json
bootloader_spec = json.dumps({ 'config': { 'bootDevice': boot_device } })
echo @(bootloader_spec) | @(bootloader_installer)

print("Finished installing bootloader")

print("Begin Tikal installation")

# Mount the filesystems and create fresh directories
mount f"/dev/disk/by-partuuid/{root_part_guid}" /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/etc/nixos/
mount f"/dev/disk/by-partuuid/{boot_part_guid}" /mnt/boot
swapon f"/dev/disk/by-partuuid/{swap_part_guid}"

cp f"{flake}" /mnt/etc/nixos/flake.nix
nixos-install --flake f"/mnt/etc/nixos#{nahual}"

