# Ensure commands that don't exit with 0 status fail.
$RAISE_SUBPROC_ERROR=True

from os import path
import json
from subprocess import CalledProcessError

tikal = ${tikal-context}
universe = ${tikal-universe}

lock_directory_path = path.join(universe.public_dir, "tikal_store_lock")
lock_store_directory_path = path.join(lock_directory_path, "store")

# Load the existing store lockfile. Load an empty dictionary if missing
lock_directory = tikal.get_directory(lock_directory_path, create=True)
lock_store_directory = tikal.get_directory(lock_store_directory_path, create=True)
lock_file = path.join(lock_directory, "tikal_store_lock.json")

tikal.log.log_debug(
  "Lock Paths",
  lock_directory = lock_directory,
  lock_store_directory = lock_store_directory,
  lock_file = lock_file
)

try:
    with open(lock_file, 'r') as lock_fp:
        store_lock = json.load(lock_fp)
except FileNotFoundError:
    store_lock = {}
except Exception:
    tikal.log_error(f"Failed to read store lock file at '{lock_file}'. Assuming corrupt. Overwriting with fresh file.")
    store_lock = {}

locks = ${locks}

def is_lockpath_available(key):

    # The key is not present in the store lockfile. Proceed
    # to add the store path to the locked store paths.
    if key not in store_lock:
        return False

    dest_name = store_locks[key]
    dest_path = path.join(lock_store_directory, dest_name)

    # Key is already in the store lockfile. Check
    # if the path exists in the store lock. If path
    # exists, nothing needs to be done
    if path.exists(dest_path):
        return True

    # Key is in the lockfile but path is missing from
    # the locked store paths. We attempt to recover
    # the path.
    dest_store_path = path.join("nix","store", current)
    try:
        cp -r f"{dest_store_path}" f"{dest_path}"
        return True
    except CalledProcessError:
        tikal.log_warning(f"The store lockfile contains a reference to '{dest_store_path}', which is not present in the store lock nor the nix store. Lockfile will be updated.")
    
    # It was not possible to recover the path referenced in the store lockfile.
    # Proceed to overwrite with a new path.
    return False

for key,lock in locks.items():

    if not is_lockpath_available(key):
        src = lock.derive
        dest_name = path.basename(src)
        dest = path.join(lock_store_directory, dest_name)
        cp -r f"{src}" f"{dest}"
        store_lock[key] = dest_name
        tikal.log_info(f"Added '{dest}' to the store lock with key '{key}'")

# Write the updated store lockfile
with open(lock_file, 'w') as lock_fp:
    json.dump(store_lock, lock_fp, indent=4)
