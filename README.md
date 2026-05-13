# Barsik-apt
`apt`-сервер Барсика.

[![endpoint: packages](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/packages-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)
[![endpoint: pkg-versions](https://img.shields.io/endpoint?url=https://barsik0396.github.io/barsik-apt/json/pkg-versions-endpoint.json&cacheSeconds=1)](https://github.com/barsik0396/barsik-apt)

# Установка
```bash
echo "deb [arch=amd64 trusted=yes] https://barsik0396.github.io/barsik-apt stable main" | sudo tee /etc/apt/sources.list.d/barsik-apt.list
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