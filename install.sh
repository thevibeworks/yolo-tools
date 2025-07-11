#!/bin/bash

# yolo-tools installer
# Installs barkme.sh to ~/.local/bin (default) or /usr/local/bin

set -euo pipefail

if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" || "$OSTYPE" == "cygwin" ]]; then
    echo "Error: Windows is not supported. Try ccyolo Docker, WSL or Linux/macOS." >&2
    exit 1
fi

INSTALL_DIR=""
FORCE=false
INTERACTIVE=true
TOOLS_TO_INSTALL=()
VERSION="latest"
REPO_URL="https://github.com/thevibeworks/yolo-tools"

show_help() {
    cat <<EOF
yolo-tools installer

USAGE:
    install.sh [OPTIONS]

OPTIONS:
    -d, --dir <path>    Install directory (default: ~/.local/bin)
    -s, --system        Install to /usr/local/bin (requires sudo)
    -f, --force         Overwrite existing files
    -a, --all           Install all tools (skip interactive selection)
    -v, --version <tag> Install specific version/tag (default: latest)
    -h, --help          Show this help

EXAMPLES:
    ./install.sh                    # Install to ~/.local/bin
    ./install.sh --system           # Install to /usr/local/bin
    ./install.sh -d /usr/bin        # Install to custom directory
    ./install.sh -v v1.0.0          # Install specific version
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
    -d | --dir)
        INSTALL_DIR="$2"
        shift 2
        ;;
    -s | --system)
        INSTALL_DIR="/usr/local/bin"
        shift
        ;;
    -f | --force)
        FORCE=true
        shift
        ;;
    -a | --all)
        INTERACTIVE=false
        shift
        ;;
    -v | --version)
        VERSION="$2"
        shift 2
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
done

# Default to ~/.local/bin if no directory specified
if [[ -z "$INSTALL_DIR" ]]; then
    INSTALL_DIR="$HOME/.local/bin"
fi

INSTALL_DIR="${INSTALL_DIR/#\~/$HOME}"

# Determine if we need to download or use local files
if [[ -d "src/bin" ]]; then
    # Local installation
    USE_LOCAL=true
    echo "Using local repository"
else
    # Remote installation
    USE_LOCAL=false
    echo "Downloading yolo-tools $VERSION"

    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    # Download and extract
    if [[ "$VERSION" == "latest" ]]; then
        DOWNLOAD_URL="$REPO_URL/archive/refs/heads/main.tar.gz"
    else
        DOWNLOAD_URL="$REPO_URL/archive/refs/tags/$VERSION.tar.gz"
    fi

    if ! curl -sL "$DOWNLOAD_URL" | tar -xz -C "$TEMP_DIR" --strip-components=1; then
        echo "Error: Failed to download $VERSION" >&2
        exit 1
    fi

    # Change to temp directory
    cd "$TEMP_DIR"

    if [[ ! -d "src/bin" ]]; then
        echo "Error: src/bin directory not found in downloaded archive" >&2
        exit 1
    fi
fi

# Discover available tools
AVAILABLE_TOOLS=()
for tool in src/bin/*.sh; do
    if [[ -f "$tool" ]]; then
        basename=$(basename "$tool" .sh)
        AVAILABLE_TOOLS+=("$basename")
    fi
done

if [[ ${#AVAILABLE_TOOLS[@]} -eq 0 ]]; then
    echo "Error: No tools found in src/bin/" >&2
    exit 1
fi

# Interactive tool selection
if [[ "$INTERACTIVE" == "true" ]]; then
    # Check if stdin is available (not piped)
    if [[ -t 0 ]]; then
        echo "Available tools:"
        for i in "${!AVAILABLE_TOOLS[@]}"; do
            echo "$((i + 1)). ${AVAILABLE_TOOLS[$i]}"
        done
        echo "a. Install all"
        echo

        while true; do
            read -p "Select tools to install (1-${#AVAILABLE_TOOLS[@]}, a for all, or comma-separated): " selection

            if [[ "$selection" == "a" ]]; then
                TOOLS_TO_INSTALL=("${AVAILABLE_TOOLS[@]}")
                break
            elif [[ "$selection" =~ ^[0-9,]+$ ]]; then
                IFS=',' read -ra INDICES <<<"$selection"
                TOOLS_TO_INSTALL=()
                valid=true

                for idx in "${INDICES[@]}"; do
                    idx=$((idx - 1))
                    if [[ $idx -ge 0 && $idx -lt ${#AVAILABLE_TOOLS[@]} ]]; then
                        TOOLS_TO_INSTALL+=("${AVAILABLE_TOOLS[$idx]}")
                    else
                        echo "Invalid selection: $((idx + 1))"
                        valid=false
                        break
                    fi
                done

                if [[ "$valid" == "true" ]]; then
                    break
                fi
            else
                echo "Invalid input. Use numbers, comma-separated numbers, or 'a' for all."
            fi
        done
    else
        # Piped execution - install all tools
        echo "Piped execution detected. Installing all tools."
        echo "Use 'curl ... | bash -s -- --help' to see options."
        TOOLS_TO_INSTALL=("${AVAILABLE_TOOLS[@]}")
    fi
else
    TOOLS_TO_INSTALL=("${AVAILABLE_TOOLS[@]}")
fi

echo "Installing yolo-tools $VERSION to $INSTALL_DIR"

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "Creating directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
    echo "Error: $INSTALL_DIR is not writable" >&2
    echo "Try running with sudo or use --dir to specify a different location" >&2
    exit 1
fi

# Install selected tools
for tool in "${TOOLS_TO_INSTALL[@]}"; do
    SRC_FILE="src/bin/$tool.sh"
    TARGET_FILE="$INSTALL_DIR/$tool.sh"

    if [[ ! -f "$SRC_FILE" ]]; then
        echo "Error: $SRC_FILE not found" >&2
        continue
    fi

    if [[ -f "$TARGET_FILE" && "$FORCE" == "false" ]]; then
        echo "Error: $TARGET_FILE already exists. Use --force to overwrite" >&2
        continue
    fi

    echo "Installing $tool.sh -> $TARGET_FILE"
    cp "$SRC_FILE" "$TARGET_FILE"
    chmod +x "$TARGET_FILE"
done

echo "✓ Installation complete"

if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
    echo "✓ $INSTALL_DIR is in your PATH"
else
    echo "⚠ $INSTALL_DIR is not in your PATH"
    echo "Add this to your shell profile:"
    echo "export PATH=\"$INSTALL_DIR:\$PATH\""
fi

echo
echo "Installed tools:"
for tool in "${TOOLS_TO_INSTALL[@]}"; do
    echo "  $tool"
done
