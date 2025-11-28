from subprocess import CalledProcessError

nahual = ${nahual}
install_device = ${install-device}
boot_part_guid = ${boot-partuuid}
root_part_guid = ${root-partuuid}
swap_part_guid = ${swap-partuuid}
uboot_bin_root = ${uboot-bin-root}
tikal_keys_directory = ${tikal-decrypt-keys-directory}
tikal_master_key_file = ${tikal-decrypt-master-key-file}
flake = ${flake}

# Todo: configure cmdline args

try:
  # Check internet connectivity
  ${curl} --silent --head --fail "https://cache.nixos.org" >  /dev/null
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

# Copy the nahual's key to the Tikal keys directory
# This will allow the setup to decrypt the store secrets.
mkdir -p f"{tikal_keys_directory}"
cp /root/.ssh/id_ed25519 f"{tikal_master_key_file}"

print(f"Formatting the drive {install_device}")

# Create a new set of partitions in the target
# installation device
${sgdisk} --zap-all f"{install_device}"
${sgdisk} --clear f"{install_device}"

# Create the boot partition. Leave a conservative 32MB margin
# before the parition for uboot
${sgdisk} \
  --new=1:32MiB:+1GiB \
  f"--partition-guid=1:{boot_part_guid}" \
  --typecode=1:0FC63DAF-8483-4772-8E79-3D69D8477DE4 \
  --change-name=1:"tikal-boot" \
  f"{install_device}"

# Create the swap partition
# Todo: make it configurable for multiple devices
${sgdisk} \
  --new=2:0:+32GiB \
  f"--partition-guid=2:{swap_part_guid}" \
  --typecode=2:0657FD6D-A4AB-43C4-84E5-0933C84B4F4F \
  --change-name=2:"tikal-swap" \
  f"{install_device}"

# Create the root partition
${sgdisk} \
  --new=3:0:0 \
  f"--partition-guid=3:{root_part_guid}" \
  --typecode=3:4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709 \
  --change-name=3:"tikal-root" \
  f"{install_device}"

partprobe f"{install_device}"

mkfs.ext4 -F f"/dev/disk/by-partuuid/{boot_part_guid}"
mkswap f"/dev/disk/by-partuuid/{swap_part_guid}"
mkfs.btrfs -f f"/dev/disk/by-partuuid/{root_part_guid}"

print("Final partition table:")
${sgdisk} -p f"{install_device}"

print(f"Flashing u-boot to {install_device}")

# For rockchip, u-boot is flashed at a 32KiB offset.
# Todo: support more devices
dd f"if={uboot_bin_root}/u-boot-rockchip.bin" \
  f"of={install_device}" bs=512 seek=64 conv=sync,fsync
sync

print("U-Boot has been flashed successfully")

print("Begin Tikal installation")

# Mount the filesystems and create fresh directories
mount f"/dev/disk/by-partuuid/{root_part_guid}" /mnt
mkdir -p /mnt/boot
mkdir -p /mnt/etc/nixos/
mount f"/dev/disk/by-partuuid/{boot_part_guid}" /mnt/boot
swapon f"/dev/disk/by-partuuid/{swap_part_guid}"

cp f"{flake}" /mnt/etc/nixos/flake.nix
nixos-install --flake f"/mnt/etc/nixos#{nahual}"

