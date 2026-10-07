#!/usr/bin/env bash
set -euo pipefail

cd /workspace/roblox-game

# Official Rojo release. Keep TLS and the published SHA256 verification enabled.
rojo_version=7.7.1
rojo_sha256=00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4
rojo_directory="/workspace/.tools/rojo-${rojo_version}"
setup_directory=$(mktemp -d /tmp/roblox-cloud-setup.XXXXXX)
trap 'rm -rf "$setup_directory"' EXIT

curl --fail --silent --show-error --location --max-time 60 \
  "https://github.com/rojo-rbx/rojo/releases/download/v${rojo_version}/rojo-${rojo_version}-linux-x86_64.zip" \
  --output "$setup_directory/rojo.zip"
printf '%s  %s\n' "$rojo_sha256" "$setup_directory/rojo.zip" | sha256sum --check -
unzip -q "$setup_directory/rojo.zip" rojo -d "$setup_directory"
mkdir -p "$rojo_directory"
install -m 0755 "$setup_directory/rojo" "$rojo_directory/rojo"
"$rojo_directory/rojo" --version

npm --cache /tmp/roblox-game-npm-cache ci --ignore-scripts --no-audit --no-fund
ROJO_BIN="$rojo_directory/rojo" npm run build
