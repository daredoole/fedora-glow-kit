#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE=""
ARCHIVE="$ROOT_DIR/dist/fedora-glow-kit-1.0.0.tar.gz"
DESKTOP="all"
KEEP=0
WORK_BASE="${XDG_CACHE_HOME:-$HOME/.cache}/fedora-glow-kit/vm-tests"
EXPECTED_SHA256="28680fe5b371a5a82ebf43a31926e086a168e59949d03969c5093e7071f90b7f"
IMAGE_URL="https://download.fedoraproject.org/pub/fedora/linux/releases/44/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-44-1.7.x86_64.qcow2"

usage() {
  cat <<USAGE
Usage: bash scripts/vm-release-test.sh --image PATH [options]

Options:
  --image PATH       Verified Fedora 44 Cloud Base qcow2 image (required)
  --archive PATH     Source archive to test (default: dist release archive)
  --desktop TARGET   kde, gnome, or all (default: all)
  --work-dir PATH    Disk-backed workspace parent (default: $WORK_BASE)
  --keep             Preserve temporary disks and logs
  -h, --help         Show this help

Official image:
  $IMAGE_URL
  SHA-256: $EXPECTED_SHA256
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
  --image)
    IMAGE="${2:-}"
    shift
    ;;
  --archive)
    ARCHIVE="${2:-}"
    shift
    ;;
  --desktop)
    DESKTOP="${2:-}"
    shift
    ;;
  --work-dir)
    WORK_BASE="${2:-}"
    shift
    ;;
  --keep) KEEP=1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf 'Unknown option: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
  esac
  shift
done

case "$DESKTOP" in
kde | gnome | all) ;;
*)
  printf 'Unknown desktop target: %s\n' "$DESKTOP" >&2
  exit 2
  ;;
esac

[ -n "$IMAGE" ] || {
  usage >&2
  exit 2
}
[ -f "$IMAGE" ] || {
  printf 'Image not found: %s\n' "$IMAGE" >&2
  exit 2
}
[ -f "$ARCHIVE" ] || {
  printf 'Archive not found: %s\n' "$ARCHIVE" >&2
  exit 2
}

for command in genisoimage qemu-img qemu-system-x86_64 sha256sum ssh ssh-keygen scp; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$command" >&2
    exit 2
  }
done
[ -r /dev/kvm ] || {
  printf 'KVM is unavailable to the current user.\n' >&2
  exit 2
}

printf '%s  %s\n' "$EXPECTED_SHA256" "$IMAGE" | sha256sum --check --status || {
  printf 'Fedora image checksum mismatch.\n' >&2
  exit 1
}

mkdir -p "$WORK_BASE"
WORK_BASE="$(cd "$WORK_BASE" && pwd)"
available_kib="$(df -Pk "$WORK_BASE" | awk 'NR == 2 {print $4}')"
required_kib=$((16 * 1024 * 1024))
if [ "$DESKTOP" = "all" ] && [ "$KEEP" -eq 1 ]; then
  required_kib=$((28 * 1024 * 1024))
fi
if [ "$available_kib" -lt "$required_kib" ]; then
  printf 'Insufficient VM workspace capacity in %s: need at least %s GiB free.\n' \
    "$WORK_BASE" "$((required_kib / 1024 / 1024))" >&2
  exit 2
fi

QA_ROOT="$(mktemp -d "$WORK_BASE/run.XXXXXX")"
cleanup() {
  local pid_file
  for pid_file in "$QA_ROOT"/*.pid; do
    [ -f "$pid_file" ] || continue
    kill "$(cat "$pid_file")" 2>/dev/null || true
  done
  if [ "$KEEP" -eq 1 ]; then
    printf 'Preserved VM workspace: %s\n' "$QA_ROOT"
  else
    rm -rf "$QA_ROOT"
  fi
}
trap cleanup EXIT INT TERM

ssh-keygen -q -t ed25519 -N "" -f "$QA_ROOT/id_ed25519"
SSH_PUBLIC_KEY="$(<"$QA_ROOT/id_ed25519.pub")"

run_target() {
  local target="$1" port="$2" pid attempt
  local target_dir="$QA_ROOT/$target"
  mkdir -p "$target_dir"

  cat >"$target_dir/meta-data" <<EOF
instance-id: fedora-glow-kit-$target
local-hostname: glowqa
EOF
  cat >"$target_dir/user-data" <<EOF
#cloud-config
users:
  - default
  - name: glowqa
    groups: [wheel]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - $SSH_PUBLIC_KEY
ssh_pwauth: false
disable_root: true
growpart:
  mode: auto
  devices: ['/']
runcmd:
  - [systemctl, enable, --now, sshd]
EOF

  genisoimage -quiet -output "$target_dir/seed.iso" -volid cidata \
    -joliet -rock "$target_dir/user-data" "$target_dir/meta-data"
  qemu-img create -q -f qcow2 -F qcow2 -b "$IMAGE" "$target_dir/disk.qcow2" 32G

  qemu-system-x86_64 \
    -machine q35,accel=kvm \
    -cpu host \
    -smp 4 \
    -m 6144 \
    -drive "file=$target_dir/disk.qcow2,if=virtio,format=qcow2,cache=none" \
    -drive "file=$target_dir/seed.iso,media=cdrom,readonly=on" \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$port-:22" \
    -device virtio-net-pci,netdev=net0 \
    -display none \
    -monitor none \
    -serial "file:$target_dir/serial.log" \
    >"$target_dir/qemu.log" 2>&1 &
  pid=$!
  printf '%s\n' "$pid" >"$target_dir.pid"

  printf 'Waiting for Fedora 44 %s guest on port %s' "$target" "$port"
  for attempt in $(seq 1 90); do
    if ssh -q \
      -i "$QA_ROOT/id_ed25519" \
      -p "$port" \
      -o BatchMode=yes \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=2 \
      glowqa@127.0.0.1 true 2>/dev/null; then
      printf ' ready.\n'
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      printf '\nGuest exited before SSH became ready: %s\n' "$target_dir/serial.log" >&2
      return 1
    fi
    [ "$attempt" -lt 90 ] || {
      printf '\nTimed out waiting for SSH: %s\n' "$target_dir/serial.log" >&2
      return 1
    }
    printf '.'
    sleep 2
  done

  scp -q \
    -i "$QA_ROOT/id_ed25519" \
    -P "$port" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$ARCHIVE" \
    glowqa@127.0.0.1:/tmp/fedora-glow-kit.tar.gz
  scp -q \
    -i "$QA_ROOT/id_ed25519" \
    -P "$port" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "$ROOT_DIR/tests/vm/guest-release-gate.sh" \
    glowqa@127.0.0.1:/tmp/guest-release-gate.sh

  if ! ssh \
    -i "$QA_ROOT/id_ed25519" \
    -p "$port" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    glowqa@127.0.0.1 \
    "bash /tmp/guest-release-gate.sh '$target' /tmp/fedora-glow-kit.tar.gz" |
    tee "$target_dir/release-gate.log"; then
    printf 'Guest release gate failed: %s\n' "$target_dir/release-gate.log" >&2
    return 1
  fi

  scp -q -r \
    -i "$QA_ROOT/id_ed25519" \
    -P "$port" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    glowqa@127.0.0.1:glow-kit-qa-results "$target_dir/results"

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  rm -f "$target_dir.pid"
  if [ "$KEEP" -eq 0 ]; then
    rm -rf "$target_dir"
  fi
}

case "$DESKTOP" in
kde) run_target kde 22220 ;;
gnome) run_target gnome 22221 ;;
all)
  run_target kde 22220
  run_target gnome 22221
  ;;
esac

printf 'PASS: requested Fedora 44 VM release matrix completed.\n'
