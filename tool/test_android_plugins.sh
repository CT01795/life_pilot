#!/usr/bin/env bash
set -euo pipefail

plugin_test_device="${1:?Usage: bash tool/test_android_plugins.sh <Android-device-id>}"
plugin_test_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_test_flutter="${FLUTTER_BIN:-flutter}"
cd "$plugin_test_root"

# Flutter otherwise uninstalls the app (and its local data) after integration tests.
exec "$plugin_test_flutter" test integration_test/android_plugin_migration_test.dart \
  --no-uninstall -d "$plugin_test_device"
