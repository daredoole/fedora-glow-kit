#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/audit-public.sh
python3 -m unittest discover -s tests -p 'test_*.py'
bash tests/run-shell-tests.sh
bash manage.sh --dry-run --profile minimal --desktop kde
bash manage.sh --dry-run --profile daily --desktop kde
bash manage.sh --dry-run --profile daily --desktop gnome
bash manage.sh --dry-run --profile dev --desktop kde
bash manage.sh --dry-run --profile full-send --desktop kde
bash manage.sh --dry-run --profile full-send --desktop gnome
bash bin/glow-kit status --json
bash bin/glow-kit diagnostics --json
bash bin/glow-kit update --json

if command -v bats >/dev/null 2>&1; then
  bats tests/*.bats
fi
