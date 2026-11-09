#!/bin/bash
# Compiles Sources/Web to WebAssembly with Embedded Swift (in Docker) and leaves in assets/swift/ what the browser loads.
set -euo pipefail
cd "$(dirname "$0")/.."

docker build -q -t holaswift-wasm -f scripts/Dockerfile scripts >/dev/null
rm -rf assets/swift
# on Linux (GitHub Actions) the container writes as root: when done, it hands what it created back to whoever runs the script
docker run --rm -v "$PWD":/web -w /web holaswift-wasm bash -c '
  swift package --scratch-path .build-wasm --swift-sdk swift-6.4.1-RELEASE_wasm-embedded \
    --allow-writing-to-directory assets/swift \
    js --product Web --output assets/swift -c release
  status=$?
  chown -R "$1" assets/swift .build-wasm
  exit $status' _ "$(id -u):$(id -g)"

# the exact version JavaScriptKit asks for, verified against its npm integrity hash
SHIM=0.3.0
SHIM_SHA512=FlRBYttPRLcWORzBe6g8nmYTafBkOEFeOqMYM4tAHJzFsQy4+xJA94z85a9BCs8S+Uzfh9LrkpII7DXr2iUVFg==
grep -q "\"@bjorn3/browser_wasi_shim\": \"$SHIM\"" assets/swift/package.json \
  || { echo "JavaScriptKit asks for a different browser_wasi_shim version: update SHIM and SHIM_SHA512" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/shim.tgz" "https://registry.npmjs.org/@bjorn3/browser_wasi_shim/-/browser_wasi_shim-$SHIM.tgz"
[ "$(openssl dgst -sha512 -binary "$tmp/shim.tgz" | base64 | tr -d '\n')" = "$SHIM_SHA512" ] \
  || { echo "browser_wasi_shim $SHIM doesn't have the expected hash" >&2; exit 1; }
tar -xzf "$tmp/shim.tgz" -C "$tmp"
mkdir -p assets/swift/vendor/browser_wasi_shim
cp "$tmp"/package/dist/*.js "$tmp"/package/LICENSE* assets/swift/vendor/browser_wasi_shim/ 2>/dev/null || cp "$tmp"/package/dist/*.js assets/swift/vendor/browser_wasi_shim/

rm -f assets/swift/*.d.ts assets/swift/platforms/*.d.ts assets/swift/platforms/node.js assets/swift/package.json

ls -lh assets/swift assets/swift/platforms
echo "Web.wasm compressed (as GitHub Pages serves it): $(gzip -9c assets/swift/Web.wasm | wc -c | awk '{printf "%.2f MB", $1/1048576}')"
