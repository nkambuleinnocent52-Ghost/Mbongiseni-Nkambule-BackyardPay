#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter_bin="${FLUTTER_BIN:-flutter}"
"$flutter_bin" clean
"$flutter_bin" pub get --enforce-lockfile
"$flutter_bin" test --no-pub
"$flutter_bin" build web --release --no-pub --csp --pwa-strategy=none --no-web-resources-cdn --no-wasm-dry-run
python3 tool/validate_web_release.py build/web
python3 tool/package_netlify.py
python3 tool/validate_web_release.py downloads/BackyardPay-Netlify-web.zip
