#!/bin/bash
# Usage: ./update-repo.sh [--channel <channel>]
# Updates Release dates, hashes and Packages.gz for a channel
set -e

VALID_CHANNELS="stable unstable dev libs community community-unstable community-dev community-libs"
CHANNEL="stable"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            exit 1
            ;;
    esac
done

if ! echo "$VALID_CHANNELS" | grep -qw "$CHANNEL"; then
    echo "Unknown channel: $CHANNEL"
    echo "Available channels: $VALID_CHANNELS"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
POOL_DIR="$REPO_ROOT/pool/$CHANNEL"
DISTS_DIR="$REPO_ROOT/dists/$CHANNEL/main/binary-amd64"
API_JSON="$REPO_ROOT/json/api.json"

# Read version from api.json
REPO_VERSION=$(python3 -c "import json; print(json.load(open('$API_JSON'))['version'])")

if [[ ! -d "$POOL_DIR" ]]; then
    echo "Error: pool/$CHANNEL does not exist"
    exit 1
fi

if [[ ! -d "$REPO_ROOT/dists/$CHANNEL" ]]; then
    echo "Error: dists/$CHANNEL does not exist"
    exit 1
fi

# Regenerate Packages.gz
gzip -9 -c "$DISTS_DIR/Packages" > "$DISTS_DIR/Packages.gz"

# Regenerate Release
cd "$REPO_ROOT"
cat > "dists/$CHANNEL/Release" <<EOF
Origin: barsik0396
Label: $(basename "$REPO_ROOT")
Suite: $CHANNEL
Codename: $CHANNEL
Version: $REPO_VERSION
Architectures: amd64
Components: main
Description: Custom APT repository
Date: $(date -Ru)
Valid-Until: $(date -Ru -d "+30 days")
EOF

echo "MD5Sum:" >> "dists/$CHANNEL/Release"
for f in "dists/$CHANNEL/main/binary-amd64/Packages" "dists/$CHANNEL/main/binary-amd64/Packages.gz"; do
    echo " $(md5sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/$CHANNEL/}" >> "dists/$CHANNEL/Release"
done

echo "SHA256:" >> "dists/$CHANNEL/Release"
for f in "dists/$CHANNEL/main/binary-amd64/Packages" "dists/$CHANNEL/main/binary-amd64/Packages.gz"; do
    echo " $(sha256sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/$CHANNEL/}" >> "dists/$CHANNEL/Release"
done

echo "Channel '$CHANNEL' updated."

# Update JSON endpoints
JSON_DIR="$REPO_ROOT/json"

if [[ -d "$JSON_DIR" ]]; then
    # pkg-versions-endpoint: total number of .deb files across all pool/
    PKG_VERSIONS=$(find "$REPO_ROOT/pool" -name "*.deb" | wc -l)

    # packages-endpoint: unique package names (strip version and arch)
    PACKAGES=$(find "$REPO_ROOT/pool" -name "*.deb" -printf "%f\n" \
        | sed 's/_[^_]*_[^_]*\.deb$//' \
        | sort -u \
        | wc -l)

    sed -i "s/\"message\": \"[^\"]*\"/\"message\": \"$PKG_VERSIONS\"/" "$JSON_DIR/pkg-versions-endpoint.json"
    sed -i "s/\"message\": \"[^\"]*\"/\"message\": \"$PACKAGES\"/" "$JSON_DIR/packages-endpoint.json"

    echo "JSON endpoints updated (packages: $PACKAGES, versions: $PKG_VERSIONS)."

    # Update api.json
    NOW=$(date +"%d.%m.%Y %H:%M")
    VALID_UNTIL=$(date -d "+30 days" +"%d.%m.%Y %H:%M")

    # Pool size
    POOL_BYTES=$(du -sb "$REPO_ROOT/pool" | cut -f1)
    if   (( POOL_BYTES >= 1073741824 )); then
        POOL_SIZE="$(echo "scale=1; $POOL_BYTES/1073741824" | bc)gb"
    elif (( POOL_BYTES >= 1048576 )); then
        POOL_SIZE="$(echo "scale=1; $POOL_BYTES/1048576" | bc)mb"
    elif (( POOL_BYTES >= 1024 )); then
        POOL_SIZE="$(echo "scale=1; $POOL_BYTES/1024" | bc)kb"
    else
        POOL_SIZE="${POOL_BYTES}b"
    fi

    # Build packages-list: group by package name, 5 versions per line
    python3 - "$REPO_ROOT/pool" "$API_JSON" "$PACKAGES" "$PKG_VERSIONS" "$NOW" "$VALID_UNTIL" "$POOL_SIZE" "$REPO_VERSION" <<'PYEOF'
import json, sys, re
from pathlib import Path
from collections import defaultdict

pool_dir   = Path(sys.argv[1])
api_file   = Path(sys.argv[2])
packages   = sys.argv[3]
pkg_vers   = sys.argv[4]
now        = sys.argv[5]
valid_until= sys.argv[6]
pool_size  = sys.argv[7]
version    = sys.argv[8]

# Collect all .deb files
entries = defaultdict(list)
for deb in sorted(pool_dir.rglob("*.deb")):
    m = re.match(r'^(.+)_([^_]+)_[^_]+\.deb$', deb.name)
    if m:
        entries[m.group(1)].append(m.group(2))

# Build packages-list: 5 versions per line per package
packages_list = []
for pkg, versions in sorted(entries.items()):
    for i in range(0, len(versions), 5):
        chunk = [f"{pkg}={v}" for v in versions[i:i+5]]
        packages_list.extend(chunk)

# Load existing api.json to preserve "api" field
with open(api_file) as f:
    data = json.load(f)

data["version"] = version
data["repo"]["packages"] = packages
data["repo"]["pkg-versions"] = pkg_vers
data["repo"]["last-update"] = now
data["repo"]["valid-until"] = valid_until
data["repo"]["size"] = pool_size
data["packages-list"] = packages_list

with open(api_file, "w") as f:
    json.dump(data, f, indent=4, ensure_ascii=False)

print(f"api.json updated.")
PYEOF
else
    echo "Warning: json/ directory not found, skipping JSON update."
fi