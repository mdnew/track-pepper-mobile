#!/usr/bin/env bash
# Generate dart_defines.json from track-pepper-web/.env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/../track-pepper-web/.env"
OUT="$ROOT/dart_defines.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: $ENV_FILE not found." >&2
  echo "Copy track-pepper-web/.env.example to .env and add your Supabase credentials." >&2
  exit 1
fi

ENV_FILE="$ENV_FILE" OUT="$OUT" python3 - <<'PY'
import json
import os
import re
from pathlib import Path

env_path = Path(os.environ["ENV_FILE"])
out_path = Path(os.environ["OUT"])
values = {}

for line in env_path.read_text().splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip().strip('"').strip("'")

supabase_url = values.get("VITE_SUPABASE_URL", "")
supabase_key = values.get("VITE_SUPABASE_ANON_KEY", "")
site_url = values.get("VITE_SITE_URL", "")

if not supabase_url or not supabase_key:
    raise SystemExit("VITE_SUPABASE_URL and VITE_SUPABASE_ANON_KEY are required in .env")

domain = re.sub(r"^https?://", "", site_url).split("/")[0]

payload = {
    "SUPABASE_URL": supabase_url,
    "SUPABASE_ANON_KEY": supabase_key,
}
if domain:
    payload["PASSWORD_AUTOFILL_DOMAIN"] = domain

out_path.write_text(json.dumps(payload, indent=2) + "\n")
print(f"Wrote {out_path}")
PY
