# Swift 6.4.1 con su SDK de WebAssembly (tienen que ser exactamente la misma versión).
# El SDK se baja con curl y se comprueba con sha256sum: `swift sdk install <url>` lo instala bien pero en Linux
# se cuelga al terminar (fallo de su cliente de descargas), y eso rompe el build.
FROM swift:6.4.1
ARG SDK=https://download.swift.org/swift-6.4.1-release/wasm-sdk/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE_wasm.artifactbundle.tar.gz
ARG SDK_SHA256=783e6128d174d9f975b4eda68be02a5960681b723ef372e6876a7c2543a365d8
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates binaryen && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/wasm-sdk.tar.gz "$SDK" \
 && echo "$SDK_SHA256  /tmp/wasm-sdk.tar.gz" | sha256sum -c - \
 && swift sdk install /tmp/wasm-sdk.tar.gz \
 && rm /tmp/wasm-sdk.tar.gz \
 && swift sdk list
