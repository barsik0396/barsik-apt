#!/bin/bash
# Usage: ./add-package.sh <pkg1.deb> [pkg2.deb ...] [--channel <channel>]
# Channels: stable (default), unstable, dev, libs,
#           community, community-unstable, community-dev, community-libs
set -e

VALID_CHANNELS="stable unstable dev libs community community-unstable community-dev community-libs"
CHANNEL="stable"
DEB_FILES=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --channel)
            CHANNEL="$2"
            shift 2
            ;;
        *)
            DEB_FILES+=("$1")
            shift
            ;;
    esac
done

if [[ ${#DEB_FILES[@]} -eq 0 ]]; then
    echo "Usage: $0 <pkg1.deb> [pkg2.deb ...] [--channel <channel>]"
    echo "Channels: $VALID_CHANNELS"
    exit 1
fi

if ! echo "$VALID_CHANNELS" | grep -qw "$CHANNEL"; then
    echo "Unknown channel: $CHANNEL"
    echo "Available channels: $VALID_CHANNELS"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
POOL_DIR="$REPO_ROOT/pool/$CHANNEL"
DISTS_DIR="$REPO_ROOT/dists/$CHANNEL/main/binary-amd64"

mkdir -p "$POOL_DIR"
mkdir -p "$DISTS_DIR"

add_package() {
    local DEB_FILE="$1"
    local FILENAME
    FILENAME=$(basename "$DEB_FILE")

    mv "$DEB_FILE" "$POOL_DIR/$FILENAME"

    local PKG_INFO SIZE MD5 SHA1 SHA256
    PKG_INFO=$(dpkg-deb -f "$POOL_DIR/$FILENAME")
    SIZE=$(wc -c < "$POOL_DIR/$FILENAME")
    MD5=$(md5sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)
    SHA1=$(sha1sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)
    SHA256=$(sha256sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)

    cat >> "$DISTS_DIR/Packages" <<EOF
$PKG_INFO
Filename: pool/$CHANNEL/$FILENAME
Size: $SIZE
MD5sum: $MD5
SHA1: $SHA1
SHA256: $SHA256

EOF

    echo "Added $FILENAME to channel '$CHANNEL'."
}

for DEB_FILE in "${DEB_FILES[@]}"; do
    add_package "$DEB_FILE"
done

# Regenerate Packages.gz
gzip -9 -c "$DISTS_DIR/Packages" > "$DISTS_DIR/Packages.gz"

# Regenerate Release
cd "$REPO_ROOT"
cat > "dists/$CHANNEL/Release" <<EOF
Origin: $(basename "$REPO_ROOT")
Label: $(basename "$REPO_ROOT")
Suite: $CHANNEL
Codename: $CHANNEL
Architectures: amd64
Components: main
Description: Custom APT repository
Date: $(date -Ru)
EOF

echo "MD5Sum:" >> "dists/$CHANNEL/Release"
for f in "dists/$CHANNEL/main/binary-amd64/Packages" "dists/$CHANNEL/main/binary-amd64/Packages.gz"; do
    echo " $(md5sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/$CHANNEL/}" >> "dists/$CHANNEL/Release"
done

echo "SHA256:" >> "dists/$CHANNEL/Release"
for f in "dists/$CHANNEL/main/binary-amd64/Packages" "dists/$CHANNEL/main/binary-amd64/Packages.gz"; do
    echo " $(sha256sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/$CHANNEL/}" >> "dists/$CHANNEL/Release"
done