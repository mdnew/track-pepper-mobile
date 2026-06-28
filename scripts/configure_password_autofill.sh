#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEFINES="$ROOT/dart_defines.json"
ENTITLEMENTS="$ROOT/ios/Runner/Runner.entitlements"

if [[ ! -f "$DEFINES" ]]; then
  echo "Missing dart_defines.json. Copy dart_defines.example.json first." >&2
  exit 1
fi

DOMAIN="$(python3 - <<'PY'
import json
from pathlib import Path
data = json.loads(Path("dart_defines.json").read_text())
print((data.get("PASSWORD_AUTOFILL_DOMAIN") or "").strip())
PY
)"

cd "$ROOT"

if [[ -z "$DOMAIN" ]]; then
  echo "PASSWORD_AUTOFILL_DOMAIN is not set in dart_defines.json."
  echo "Skipping associated-domains update. iOS autofill still works with 1Password."
  exit 0
fi

# Associated Domains requires a paid Apple Developer Program membership.
# Personal/free teams (e.g. mdnew@yahoo.com) cannot use this capability.
if [[ "${SKIP_ASSOCIATED_DOMAINS:-1}" == "1" ]]; then
  echo "Skipping associated-domains (requires paid Apple Developer Program)."
  echo "1Password autofill still works; web/mobile credential sync is disabled."
  exit 0
fi

DOMAIN="${DOMAIN#https://}"
DOMAIN="${DOMAIN#http://}"
DOMAIN="${DOMAIN%%/*}"

cat > "$ENTITLEMENTS" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.associated-domains</key>
	<array>
		<string>webcredentials:${DOMAIN}</string>
	</array>
</dict>
</plist>
EOF

echo "Updated $ENTITLEMENTS with webcredentials:${DOMAIN}"
