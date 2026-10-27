#!/bin/bash
# Compila Sources/Web a WebAssembly con Embedded Swift (en Docker) y deja en assets/swift/ lo que carga el navegador.
set -euo pipefail
cd "$(dirname "$0")/.."

docker build -q -t holaswift-wasm -f scripts/Dockerfile scripts >/dev/null
rm -rf assets/swift
# en Linux (GitHub Actions) el contenedor escribe como root: al acabar devuelve lo creado a quien lanza el script
docker run --rm -v "$PWD":/web -w /web holaswift-wasm bash -c '
  swift package --scratch-path .build-wasm --swift-sdk swift-6.4.1-RELEASE_wasm-embedded \
    --allow-writing-to-directory assets/swift \
    js --product Web --output assets/swift -c release
  estado=$?
  chown -R "$1" assets/swift .build-wasm
  exit $estado' _ "$(id -u):$(id -g)"

# la versión exacta que pide JavaScriptKit, comprobada con su huella de npm
SHIM=0.3.0
SHIM_SHA512=FlRBYttPRLcWORzBe6g8nmYTafBkOEFeOqMYM4tAHJzFsQy4+xJA94z85a9BCs8S+Uzfh9LrkpII7DXr2iUVFg==
grep -q "\"@bjorn3/browser_wasi_shim\": \"$SHIM\"" assets/swift/package.json \
  || { echo "JavaScriptKit pide otra versión de browser_wasi_shim: actualiza SHIM y SHIM_SHA512" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
curl -fsSL -o "$tmp/shim.tgz" "https://registry.npmjs.org/@bjorn3/browser_wasi_shim/-/browser_wasi_shim-$SHIM.tgz"
[ "$(openssl dgst -sha512 -binary "$tmp/shim.tgz" | base64 | tr -d '\n')" = "$SHIM_SHA512" ] \
  || { echo "browser_wasi_shim $SHIM no tiene la huella esperada" >&2; exit 1; }
tar -xzf "$tmp/shim.tgz" -C "$tmp"
mkdir -p assets/swift/vendor/browser_wasi_shim
cp "$tmp"/package/dist/*.js "$tmp"/package/LICENSE* assets/swift/vendor/browser_wasi_shim/ 2>/dev/null || cp "$tmp"/package/dist/*.js assets/swift/vendor/browser_wasi_shim/

rm -f assets/swift/*.d.ts assets/swift/platforms/*.d.ts assets/swift/platforms/node.js assets/swift/package.json

ls -lh assets/swift assets/swift/platforms
echo "Web.wasm comprimido (como lo sirve GitHub Pages): $(gzip -9c assets/swift/Web.wasm | wc -c | awk '{printf "%.2f MB", $1/1048576}')"
