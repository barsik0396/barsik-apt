#!/bin/bash
# Usage: ./add-package.sh <path-to.deb>
set -e

DEB_FILE="$1"

if [[ -z "$DEB_FILE" ]]; then
    echo "Usage: $0 <path-to.deb>"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
POOL_DIR="$REPO_ROOT/pool/main"
DISTS_DIR="$REPO_ROOT/dists/stable/main/binary-amd64"

mkdir -p "$POOL_DIR"
mkdir -p "$DISTS_DIR"

FILENAME=$(basename "$DEB_FILE")
cp "$DEB_FILE" "$POOL_DIR/$FILENAME"

# Extract metadata
PKG_INFO=$(dpkg-deb -f "$POOL_DIR/$FILENAME")
SIZE=$(wc -c < "$POOL_DIR/$FILENAME")
MD5=$(md5sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)
SHA1=$(sha1sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)
SHA256=$(sha256sum "$POOL_DIR/$FILENAME" | cut -d' ' -f1)

PACKAGE_NAME=$(echo "$PKG_INFO" | grep '^Package:' | awk '{print $2}')
ARCH=$(echo "$PKG_INFO" | grep '^Architecture:' | awk '{print $2}')

# Remove old entry for same Package+Architecture
if [[ -f "$DISTS_DIR/Packages" ]]; then
    python3 - "$DISTS_DIR/Packages" "$PACKAGE_NAME" "$ARCH" <<'EOF'
import sys

packages_file = sys.argv[1]
pkg_name = sys.argv[2]
pkg_arch = sys.argv[3]

with open(packages_file, 'r') as f:
    content = f.read()

blocks = content.strip().split('\n\n')
filtered = []
for block in blocks:
    if not block.strip():
        continue
    name, arch = None, None
    for line in block.splitlines():
        if line.startswith('Package:'):
            name = line.split(':', 1)[1].strip()
        if line.startswith('Architecture:'):
            arch = line.split(':', 1)[1].strip()
    if not (name == pkg_name and arch == pkg_arch):
        filtered.append(block)

with open(packages_file, 'w') as f:
    f.write('\n\n'.join(filtered))
    if filtered:
        f.write('\n\n')
EOF
fi

# Append new entry
cat >> "$DISTS_DIR/Packages" <<EOF
$PKG_INFO
Filename: pool/main/$FILENAME
Size: $SIZE
MD5sum: $MD5
SHA1: $SHA1
SHA256: $SHA256

EOF

# Regenerate Packages.gz
gzip -9 -c "$DISTS_DIR/Packages" > "$DISTS_DIR/Packages.gz"

# Regenerate Release
cd "$REPO_ROOT"
cat > dists/stable/Release <<EOF
Origin: $(basename "$REPO_ROOT")
Label: $(basename "$REPO_ROOT")
Suite: stable
Codename: stable
Architectures: amd64
Components: main
Description: Custom APT repository
Date: $(date -Ru)
EOF

echo "MD5Sum:" >> dists/stable/Release
for f in dists/stable/main/binary-amd64/Packages dists/stable/main/binary-amd64/Packages.gz; do
    echo " $(md5sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/stable/}" >> dists/stable/Release
done

echo "SHA256:" >> dists/stable/Release
for f in dists/stable/main/binary-amd64/Packages dists/stable/main/binary-amd64/Packages.gz; do
    echo " $(sha256sum "$f" | cut -d' ' -f1) $(wc -c < "$f") ${f#dists/stable/}" >> dists/stable/Release
done

echo "Added $FILENAME to repository index."