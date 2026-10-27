#!/usr/bin/env bash
set -euo pipefail

source_dir=${1:?usage: $0 /path/to/facebook-homebrew-fb}
expected_source_head=400157f24674b4015d2639646030807e0997bb83
expected_zip_sha256=badb94e4ab43e7ea3c6b02e6fb0b0f4d7a2df8a1286088a9226018fce134ba87
artifact_url=https://github.com/facebook/watchman/releases/download/v2020.08.17.00/watchman-v2020.08.17.00-macos.zip
victim=wmvictim
attacker=wmattacker
victim_uid=2801
attacker_uid=2802
proof_root=/Users/Shared/homebrew-fb-watchman-proof
victim_created=0
attacker_created=0

cleanup() {
  if [[ $attacker_created == 1 ]]; then
    sudo dscl . -delete "/Users/$attacker" >/dev/null 2>&1 || true
  fi
  if [[ $victim_created == 1 ]]; then
    sudo dscl . -delete "/Users/$victim" >/dev/null 2>&1 || true
  fi
  if [[ -d $proof_root ]]; then
    sudo mv "$proof_root" "$RUNNER_TEMP/homebrew-fb-watchman-proof-preserved" 2>/dev/null || true
  fi
}
trap cleanup EXIT

[[ $(git -C "$source_dir" rev-parse HEAD) == "$expected_source_head" ]]
grep -F 'mkdir_p "/usr/local/var/run/watchman"' "$source_dir/watchman.rb"
grep -F 'chmod 0o2777, "/usr/local/var/run/watchman"' "$source_dir/watchman.rb"

for account in "$victim" "$attacker"; do
  if dscl . -read "/Users/$account" >/dev/null 2>&1; then
    echo "unexpected pre-existing account: $account" >&2
    exit 1
  fi
done

sudo dscl . -create "/Users/$victim"
victim_created=1
sudo dscl . -create "/Users/$victim" RealName "Watchman proof victim"
sudo dscl . -create "/Users/$victim" UniqueID "$victim_uid"
sudo dscl . -create "/Users/$victim" PrimaryGroupID 20
sudo dscl . -create "/Users/$victim" NFSHomeDirectory "$proof_root/victim-home"
sudo dscl . -create "/Users/$victim" UserShell /bin/bash

sudo dscl . -create "/Users/$attacker"
attacker_created=1
sudo dscl . -create "/Users/$attacker" RealName "Watchman proof attacker"
sudo dscl . -create "/Users/$attacker" UniqueID "$attacker_uid"
sudo dscl . -create "/Users/$attacker" PrimaryGroupID 20
sudo dscl . -create "/Users/$attacker" NFSHomeDirectory "$proof_root/attacker-home"
sudo dscl . -create "/Users/$attacker" UserShell /bin/bash

sudo mkdir -p "$proof_root/release" "$proof_root/state-parent" \
  "$proof_root/victim-target" "$proof_root/victim-home" "$proof_root/attacker-home"
sudo chown root:staff "$proof_root" "$proof_root/release" "$proof_root/state-parent"
sudo chown "$victim":staff "$proof_root/victim-target" "$proof_root/victim-home"
sudo chown "$attacker":staff "$proof_root/attacker-home"
sudo chmod 0755 "$proof_root" "$proof_root/release"
sudo chmod 02777 "$proof_root/state-parent"
sudo chmod 0755 "$proof_root/victim-target"

archive="$RUNNER_TEMP/watchman-v2020.08.17.00-macos.zip"
curl --fail --location --silent --show-error \
  --output "$archive" "$artifact_url"
actual_zip_sha256=$(shasum -a 256 "$archive" | awk '{print $1}')
[[ $actual_zip_sha256 == "$expected_zip_sha256" ]]
sudo ditto -x -k "$archive" "$proof_root/release"
release_root="$proof_root/release/watchman-v2020.08.17.00-macos"
sudo chmod -R a+rX "$proof_root/release"

sudo -u "$attacker" ln -s "$proof_root/victim-target" \
  "$proof_root/state-parent/$victim-state"

if sudo -u "$attacker" chmod 0700 "$proof_root/victim-target" 2>/dev/null; then
  echo 'attacker unexpectedly changed the target directly' >&2
  exit 1
fi

before_mode=$(stat -f '%Lp' "$proof_root/victim-target")
before_owner=$(stat -f '%Su' "$proof_root/victim-target")
link_owner=$(stat -f '%Su' "$proof_root/state-parent/$victim-state")
printf 'before_mode=%s before_owner=%s link_owner=%s\n' \
  "$before_mode" "$before_owner" "$link_owner"
[[ $before_mode == 755 ]]
[[ $before_owner == "$victim" ]]
[[ $link_owner == "$attacker" ]]

sudo -u "$victim" /usr/bin/env \
  DYLD_LIBRARY_PATH="$release_root/lib" \
  "$release_root/bin/watchman" \
  --test-state-dir="$proof_root/state-parent" \
  --no-spawn get-sockname | tee "$RUNNER_TEMP/watchman-output.json"

after_mode=$(stat -f '%Lp' "$proof_root/victim-target")
after_symbolic_mode=$(stat -f '%Sp' "$proof_root/victim-target")
after_owner=$(stat -f '%Su' "$proof_root/victim-target")
printf 'after_mode=%s after_symbolic_mode=%s after_owner=%s\n' \
  "$after_mode" "$after_symbolic_mode" "$after_owner"

[[ $after_mode == 700 ]]
[[ $after_owner == "$victim" ]]
grep -F "$proof_root/state-parent/$victim-state/sock" \
  "$RUNNER_TEMP/watchman-output.json"
echo 'cross_user_symlink_chmod=true'
