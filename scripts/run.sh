#!/usr/bin/env bash
# Run the iOS app with Supabase credentials from track-pepper-web/.env
set -euo pipefail

cd "$(dirname "$0")/.."

./scripts/sync_dart_defines.sh
./scripts/configure_password_autofill.sh

exec flutter run --dart-define-from-file=dart_defines.json "$@"
