#!/bin/sh
# NullJS installer — https://github.com/tothalex/nulljs-public
#
#   curl -fsSL https://raw.githubusercontent.com/tothalex/nulljs-public/main/install.sh | sh
#
# Downloads the latest nulljs binary for your platform and installs it to
# /usr/local/bin (or ~/.local/bin if that isn't writable). NULLJS_VERSION=vX.Y.Z
# pins a specific release; NULLJS_INSTALL_DIR overrides the destination.

set -eu

REPO="tothalex/nulljs-public"

# Persist PATH in the login shell's profile (guarded against duplicates), like other
# single-binary installers. $SHELL names the login shell even when piped through sh.
add_to_path() {
    dir="$1"
    line="export PATH=\"$dir:\$PATH\""

    case "$(basename "${SHELL:-sh}")" in
        zsh)  profile="$HOME/.zshrc" ;;
        bash) profile="$HOME/.bashrc" ;;
        fish)
            mkdir -p "$HOME/.config/fish"
            profile="$HOME/.config/fish/config.fish"
            line="fish_add_path $dir"
            ;;
        *)    profile="$HOME/.profile" ;;
    esac

    if [ -f "$profile" ] && grep -Fq "$dir" "$profile" 2>/dev/null; then
        return
    fi

    mkdir -p "$(dirname "$profile")"

    printf '\n# nulljs\n%s\n' "$line" >> "$profile"
    echo ""
    echo "Added $dir to PATH in $profile"
    echo "Restart your shell, or run now:"
    echo "  $line"
}

main() {
    os="$(uname -s)"
    arch="$(uname -m)"

    case "$os-$arch" in
        Darwin-arm64)          target="darwin-arm64" ;;
        Linux-x86_64)          target="linux-x64" ;;
        Linux-aarch64|Linux-arm64) target="linux-arm64" ;;
        *)
            echo "error: unsupported platform: $os $arch" >&2
            echo "supported: macOS arm64, Linux x64, Linux arm64" >&2
            exit 1
            ;;
    esac

    if [ -n "${NULLJS_VERSION:-}" ]; then
        base="https://github.com/$REPO/releases/download/$NULLJS_VERSION"
    else
        base="https://github.com/$REPO/releases/latest/download"
    fi

    asset="nulljs-$target"
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT

    echo "Downloading $asset..."
    curl -fSL --progress-bar "$base/$asset" -o "$tmp/nulljs"

    # Verify the checksum when one is published and a sha256 tool exists
    if curl -fsSL "$base/$asset.sha256" -o "$tmp/nulljs.sha256" 2>/dev/null; then
        expected="$(cut -d' ' -f1 < "$tmp/nulljs.sha256")"
        if command -v sha256sum >/dev/null 2>&1; then
            actual="$(sha256sum "$tmp/nulljs" | cut -d' ' -f1)"
        elif command -v shasum >/dev/null 2>&1; then
            actual="$(shasum -a 256 "$tmp/nulljs" | cut -d' ' -f1)"
        else
            actual="$expected"
        fi
        if [ "$expected" != "$actual" ]; then
            echo "error: checksum mismatch (expected $expected, got $actual)" >&2
            exit 1
        fi
    fi

    chmod +x "$tmp/nulljs"

    dir="${NULLJS_INSTALL_DIR:-/usr/local/bin}"
    if [ ! -w "$dir" ]; then
        if [ -d "$dir" ] && command -v sudo >/dev/null 2>&1 && [ -t 0 ]; then
            echo "Installing to $dir (needs sudo)..."
            sudo mv "$tmp/nulljs" "$dir/nulljs"
        else
            dir="$HOME/.local/bin"
            mkdir -p "$dir"
            mv "$tmp/nulljs" "$dir/nulljs"
        fi
    else
        mv "$tmp/nulljs" "$dir/nulljs"
    fi

    echo ""
    echo "✓ nulljs installed to $dir/nulljs"
    "$dir/nulljs" --version || true

    case ":$PATH:" in
        *":$dir:"*) ;;
        *) add_to_path "$dir" ;;
    esac

    echo ""
    echo "Get started:"
    echo "  nulljs create my-app && cd my-app && nulljs dev"
}

main
