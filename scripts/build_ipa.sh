#!/usr/bin/env bash
# Build a release IPA for TestFlight.
# Requires dart_defines.json (copy from dart_defines.example.json).

set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f dart_defines.json ]]; then
  echo "Error: dart_defines.json not found."
  echo "Copy dart_defines.example.json to dart_defines.json and fill in your Supabase credentials."
  exit 1
fi

flutter build ipa \
  --release \
  --dart-define-from-file=dart_defines.json

echo ""
echo "IPA ready: build/ios/ipa/"
ls -la build/ios/ipa/
