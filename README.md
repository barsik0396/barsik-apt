# Barsik-apt
`apt`-сервер Барсика.

[![endpoint: packages](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/packages-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)
[![endpoint: pkg-versions](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/pkg-versions-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)

# Установка
```bash
for channel in stable unstable dev libs community community-unstable community-dev community-libs; do
    echo "deb [arch=amd64 trusted=yes] https://barsik0396.github.io/barsik-apt $channel main" | sudo tee /etc/apt/sources.list.d/barsik-apt-$channel.list
done
sudo apt update
```

# Бейджи
packages:
```markdown
[![endpoint: packages](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/packages-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)
```
pkg versions:
```markdown
[![endpoint: pkg-versions](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/pkg-versions-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)
```