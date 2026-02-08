#!/bin/bash
# Build webview native extensions for Linux via Docker
# Usage: ./scripts/build-linux-extensions.sh [arch]
#   arch: x86_64 (default), arm64, or all

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_DIR="${HOME}/.scarpe/packager-cache/webview-ext"
WORK_DIR="/tmp/webview-build-$$"

mkdir -p "$CACHE_DIR"
mkdir -p "$WORK_DIR"

# Download and extract webview_ruby source
echo "📦 Downloading webview_ruby source..."
curl -sL https://rubygems.org/downloads/webview_ruby-0.1.2.gem -o "$WORK_DIR/webview_ruby.gem"
cd "$WORK_DIR"
tar xf webview_ruby.gem
tar xf data.tar.gz

build_glibc() {
    local arch="$1"
    local platform="${2:-linux/amd64}"
    local output="libwebview-ext-linux-${arch}.so"
    
    echo "🔨 Building Linux (glibc) extension for $arch..."
    docker run --rm --platform "$platform" \
        -v "$WORK_DIR/ext/webview:/work" \
        ubuntu:22.04 bash -c '
            apt-get update -qq
            apt-get install -qq -y build-essential libgtk-3-dev libwebkit2gtk-4.1-dev pkg-config >/dev/null 2>&1
            cd /work
            c++ -shared -fPIC -O2 \
                $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
                -DWEBVIEW_GTK \
                -o '"$output"' \
                webview.cpp \
                $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        '
    cp "$WORK_DIR/ext/webview/$output" "$CACHE_DIR/"
    echo "   ✅ Created $CACHE_DIR/$output ($(du -h "$CACHE_DIR/$output" | cut -f1))"
}

build_musl() {
    local arch="$1"
    local platform="${2:-linux/amd64}"
    local output="libwebview-ext-linux-musl-${arch}.so"
    
    echo "🔨 Building Linux (musl/Alpine) extension for $arch..."
    docker run --rm --platform "$platform" \
        -v "$WORK_DIR/ext/webview:/work" \
        alpine:3.19 sh -c '
            apk add --no-cache build-base gtk+3.0-dev webkit2gtk-4.1-dev pkgconf >/dev/null 2>&1
            cd /work
            c++ -shared -fPIC -O2 \
                $(pkg-config --cflags gtk+-3.0 webkit2gtk-4.1) \
                -DWEBVIEW_GTK \
                -o '"$output"' \
                webview.cpp \
                $(pkg-config --libs gtk+-3.0 webkit2gtk-4.1) 2>&1
        '
    cp "$WORK_DIR/ext/webview/$output" "$CACHE_DIR/"
    echo "   ✅ Created $CACHE_DIR/$output ($(du -h "$CACHE_DIR/$output" | cut -f1))"
}

ARCH="${1:-x86_64}"

case "$ARCH" in
    x86_64)
        build_glibc x86_64 linux/amd64
        build_musl x86_64 linux/amd64
        ;;
    arm64)
        echo "⚠️  ARM64 builds use QEMU emulation and are SLOW (10-15 minutes)"
        build_glibc arm64 linux/arm64
        build_musl arm64 linux/arm64
        ;;
    all)
        build_glibc x86_64 linux/amd64
        build_musl x86_64 linux/amd64
        echo ""
        echo "⚠️  ARM64 builds use QEMU emulation and are SLOW (10-15 minutes)"
        build_glibc arm64 linux/arm64
        build_musl arm64 linux/arm64
        ;;
    *)
        echo "Usage: $0 [x86_64|arm64|all]"
        exit 1
        ;;
esac

# Cleanup
rm -rf "$WORK_DIR"

echo ""
echo "📋 Extension cache contents:"
ls -lh "$CACHE_DIR/"
