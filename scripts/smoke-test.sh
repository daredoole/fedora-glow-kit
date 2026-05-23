#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash scripts/audit-public.sh
bash manage.sh --dry-run --profile minimal
bash manage.sh --dry-run --profile daily
bash manage.sh --dry-run --profile dev
bash manage.sh --dry-run --profile full-send
