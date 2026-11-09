# Swift 6.4.1 with its WebAssembly SDK (they must be exactly the same version).
# The SDK is downloaded with curl and verified with sha256sum: `swift sdk install <url>` installs it fine but on Linux
# it hangs when finishing (a bug in its download client), and that breaks the build.
FROM swift:6.4.1
ARG SDK=https://download.swift.org/swift-6.4.1-release/wasm-sdk/swift-6.4.1-RELEASE/swift-6.4.1-RELEASE_wasm.artifactbundle.tar.gz
ARG SDK_SHA256=783e6128d174d9f975b4eda68be02a5960681b723ef372e6876a7c2543a365d8
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates binaryen && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/wasm-sdk.tar.gz "$SDK" \
 && echo "$SDK_SHA256  /tmp/wasm-sdk.tar.gz" | sha256sum -c - \
 && swift sdk install /tmp/wasm-sdk.tar.gz \
 && rm /tmp/wasm-sdk.tar.gz \
 && swift sdk list
