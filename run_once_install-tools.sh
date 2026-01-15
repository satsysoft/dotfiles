#!/bin/bash
# Install development tools on Debian Trixie
# This script runs once when chezmoi apply is executed

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Debian
if [ ! -f /etc/debian_version ]; then
    log_error "This script is designed for Debian systems only"
    exit 1
fi

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) ARCH="amd64"; ARCH_ALT="x86_64" ;;
    aarch64|arm64) ARCH="arm64"; ARCH_ALT="aarch64" ;;
    *) log_error "Unsupported architecture: $ARCH"; exit 1 ;;
esac

# Create local bin directory
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    export PATH="$LOCAL_BIN:$PATH"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install from GitHub release (improved with better pattern matching)
install_from_github() {
    local repo=$1
    local binary_name=$2
    local install_name=${3:-$binary_name}
    local patterns=${4:-""}
    
    if command_exists "$install_name"; then
        log_info "$install_name is already installed"
        return 0
    fi
    
    log_info "Installing $install_name from GitHub ($repo)..."
    
    # Get latest release info
    local release_info
    release_info=$(curl -s "https://api.github.com/repos/$repo/releases/latest")
    
    # Check if API call succeeded
    if [ -z "$release_info" ] || echo "$release_info" | jq -e '.message' >/dev/null 2>&1; then
        log_error "Failed to fetch release info from GitHub API"
        return 1
    fi
    
    local download_url=""
    
    # If patterns provided, try them in order
    if [ -n "$patterns" ]; then
        # Split patterns by | and try each one
        IFS='|' read -ra PATTERN_ARRAY <<< "$patterns"
        for pattern in "${PATTERN_ARRAY[@]}"; do
            download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name | test(\"$pattern\"; \"i\")) | .browser_download_url" | head -1)
            if [ -n "$download_url" ] && [ "$download_url" != "null" ]; then
                break
            fi
        done
    fi
    
    # If still no match, try common patterns
    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        # Build list of architecture patterns to try
        local arch_patterns=(
            "${ARCH_ALT}-unknown-linux-musl"
            "${ARCH_ALT}-unknown-linux-gnu"
            "${ARCH_ALT}-linux-musl"
            "${ARCH_ALT}-linux-gnu"
            "linux-${ARCH_ALT}"
            "linux_${ARCH_ALT}"
            "linux-${ARCH}"
            "linux_${ARCH}"
        )
        
        for arch_pattern in "${arch_patterns[@]}"; do
            download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name | contains(\"$arch_pattern\")) | .browser_download_url" | \
                grep -vE "\.(deb|rpm|pkg|msi|exe|dmg|AppImage)$" | head -1)
            if [ -n "$download_url" ] && [ "$download_url" != "null" ]; then
                break
            fi
        done
    fi
    
    # Last resort: list available assets for debugging
    if [ -z "$download_url" ] || [ "$download_url" = "null" ]; then
        log_warn "Could not find matching asset. Available assets:"
        echo "$release_info" | jq -r ".assets[].name" | head -10 | while read -r asset; do
            log_warn "  - $asset"
        done
        log_error "Could not find download URL for $install_name"
        return 1
    fi
    
    log_info "Downloading from: $download_url"
    local temp_file
    temp_file=$(mktemp)
    
    if ! curl -fsSL "$download_url" -o "$temp_file"; then
        log_error "Failed to download $install_name"
        rm -f "$temp_file"
        return 1
    fi
    
    # Extract and install based on file type
    local temp_dir
    temp_dir=$(mktemp -d)
    
    if [[ "$download_url" == *.tar.gz ]] || [[ "$download_url" == *.tgz ]]; then
        if ! tar -xzf "$temp_file" -C "$temp_dir" 2>/dev/null; then
            log_error "Failed to extract tar.gz archive"
            rm -rf "$temp_dir" "$temp_file"
            return 1
        fi
    elif [[ "$download_url" == *.tar.xz ]]; then
        if ! tar -xJf "$temp_file" -C "$temp_dir" 2>/dev/null; then
            log_error "Failed to extract tar.xz archive"
            rm -rf "$temp_dir" "$temp_file"
            return 1
        fi
    elif [[ "$download_url" == *.zip ]]; then
        if ! unzip -q "$temp_file" -d "$temp_dir" 2>/dev/null; then
            log_error "Failed to extract zip archive"
            rm -rf "$temp_dir" "$temp_file"
            return 1
        fi
    else
        # Assume it's a binary file
        mv "$temp_file" "$LOCAL_BIN/$install_name"
        chmod +x "$LOCAL_BIN/$install_name"
        rm -rf "$temp_dir"
        log_info "$install_name installed successfully"
        return 0
    fi
    
    # Find the binary in extracted files
    local found_binary
    found_binary=$(find "$temp_dir" -name "$binary_name" -type f 2>/dev/null | head -1)
    
    if [ -z "$found_binary" ]; then
        # Try finding any executable with similar name
        found_binary=$(find "$temp_dir" -type f -executable -name "*${binary_name}*" 2>/dev/null | head -1)
    fi
    
    if [ -z "$found_binary" ]; then
        # Last resort: find any executable
        found_binary=$(find "$temp_dir" -type f -executable 2>/dev/null | head -1)
    fi
    
    if [ -n "$found_binary" ]; then
        cp "$found_binary" "$LOCAL_BIN/$install_name"
        chmod +x "$LOCAL_BIN/$install_name"
        log_info "$install_name installed successfully"
    else
        log_error "Could not find binary $binary_name in downloaded archive"
        log_warn "Contents of archive:"
        find "$temp_dir" -type f | head -10 | while read -r file; do
            log_warn "  - $file"
        done
        rm -rf "$temp_dir" "$temp_file"
        return 1
    fi
    
    rm -rf "$temp_dir" "$temp_file"
}

# Function to install nvim from GitHub
install_nvim() {
    if command_exists nvim; then
        log_info "nvim is already installed"
        return 0
    fi
    
    # Try apt first
    if sudo apt-get install -y -qq neovim 2>/dev/null; then
        log_info "nvim installed via apt"
        return 0
    fi
    
    log_info "Installing nvim from GitHub..."
    local nvim_url
    nvim_url=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | \
        jq -r ".assets[] | select(.name | test(\"linux64.tar.gz\")) | .browser_download_url" | head -1)
    
    if [ -n "$nvim_url" ] && [ "$nvim_url" != "null" ]; then
        local temp_dir
        temp_dir=$(mktemp -d)
        curl -fsSL "$nvim_url" | tar -xz -C "$temp_dir"
        
        # Copy nvim binary and runtime files
        if [ -d "$temp_dir/nvim-linux64" ]; then
            cp "$temp_dir/nvim-linux64/bin/nvim" "$LOCAL_BIN/"
            chmod +x "$LOCAL_BIN/nvim"
            log_info "nvim installed successfully"
        else
            log_error "Failed to extract nvim"
            rm -rf "$temp_dir"
            return 1
        fi
        rm -rf "$temp_dir"
    else
        log_error "Failed to find nvim download URL"
        return 1
    fi
}

# =============================================================================
# Main Installation
# =============================================================================

log_info "Starting tool installation on Debian Trixie..."
log_info "Architecture: $ARCH ($ARCH_ALT)"

log_info "Updating package lists..."
sudo apt-get update -qq

log_info "Installing dependencies..."
sudo apt-get install -y -qq \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    unzip \
    tar \
    gzip \
    jq \
    zsh

# 1. Install pass (password-store) via apt
log_info "Installing pass (password-store)..."
if ! command_exists pass; then
    sudo apt-get install -y -qq pass
else
    log_info "pass is already installed"
fi

# 2. Install ripgrep via apt
log_info "Installing ripgrep..."
if ! command_exists rg; then
    sudo apt-get install -y -qq ripgrep
else
    log_info "ripgrep is already installed"
fi

# 3. Install entr via apt
log_info "Installing entr..."
if ! command_exists entr; then
    sudo apt-get install -y -qq entr
else
    log_info "entr is already installed"
fi

# 4. Install bat via apt (as batcat on Debian)
log_info "Installing bat..."
if ! command_exists bat && ! command_exists batcat; then
    sudo apt-get install -y -qq bat
else
    log_info "bat is already installed"
fi

# 5. Install fzf
log_info "Installing fzf..."
if ! command_exists fzf; then
    if sudo apt-get install -y -qq fzf 2>/dev/null; then
        log_info "fzf installed via apt"
    else
        log_info "Installing fzf from GitHub..."
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf 2>/dev/null || true
        ~/.fzf/install --all --no-update-rc --no-bash --no-fish 2>/dev/null || true
    fi
else
    log_info "fzf is already installed"
fi

# 6. Install oh-my-posh
log_info "Installing oh-my-posh..."
if ! command_exists oh-my-posh; then
    curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$LOCAL_BIN" || {
        install_from_github "JanDeDobbeleer/oh-my-posh" "posh-linux-$ARCH" "oh-my-posh" "posh-linux-$ARCH"
    }
else
    log_info "oh-my-posh is already installed"
fi

# 7. Install zellij
log_info "Installing zellij..."
if ! command_exists zellij; then
    install_from_github "zellij-org/zellij" "zellij" "zellij" "zellij.*${ARCH_ALT}.*linux.*musl.*tar\\.gz|zellij.*${ARCH_ALT}.*linux.*tar\\.gz" || {
        log_warn "Failed to install zellij from GitHub releases"
    }
else
    log_info "zellij is already installed"
fi

# 8. Install nvim (Neovim)
log_info "Installing nvim..."
install_nvim

# 9. Install eza
log_info "Installing eza..."
if ! command_exists eza; then
    install_from_github "eza-community/eza" "eza" "eza" "eza.*${ARCH_ALT}.*linux.*gnu.*tar\\.gz|eza.*${ARCH_ALT}.*linux.*tar\\.gz|eza_.*${ARCH_ALT}.*tar\\.gz" || {
        log_warn "Failed to install eza from GitHub releases"
    }
else
    log_info "eza is already installed"
fi

# 10. Install zoxide
log_info "Installing zoxide..."
if ! command_exists zoxide; then
    # Try apt first (available in Debian Trixie)
    if sudo apt-get install -y -qq zoxide 2>/dev/null; then
        log_info "zoxide installed via apt"
    else
        # Fallback to GitHub
        install_from_github "ajeetdsouza/zoxide" "zoxide" "zoxide" "zoxide.*${ARCH_ALT}.*linux.*musl.*tar\\.gz|zoxide.*${ARCH_ALT}.*linux.*tar\\.gz" || {
            log_warn "Failed to install zoxide from GitHub releases"
        }
    fi
else
    log_info "zoxide is already installed"
fi

# 11. Install tlrc
log_info "Installing tlrc..."
if ! command_exists tlrc; then
    install_from_github "tldr-pages/tlrc" "tlrc" "tlrc" "tlrc.*${ARCH_ALT}.*linux.*musl.*tar\\.gz|tlrc.*${ARCH_ALT}.*linux.*tar\\.gz|tlrc.*linux.*${ARCH_ALT}.*tar\\.gz" || {
        log_warn "Failed to install tlrc from GitHub releases"
    }
else
    log_info "tlrc is already installed"
fi

# 12. Install zinit (zsh plugin manager) - directory setup
log_info "Setting up zinit directory..."
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
if [[ ! -d "$ZINIT_HOME" ]]; then
    mkdir -p "$(dirname "$ZINIT_HOME")"
    git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME" && \
        log_info "zinit installed successfully" || \
        log_warn "Failed to install zinit"
else
    log_info "zinit is already installed"
fi

# =============================================================================
# Post-installation
# =============================================================================

# Create XDG directories
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
mkdir -p "${XDG_DATA_HOME:-$HOME/.local/share}"
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}"

# Set zsh as default shell if not already
if [ "$SHELL" != "$(which zsh)" ]; then
    log_info "Setting zsh as default shell..."
    chsh -s "$(which zsh)" || log_warn "Could not change default shell to zsh"
fi

log_info "============================================="
log_info "Installation complete!"
log_info "Installed binaries are in: $LOCAL_BIN"
log_info "============================================="
log_info "Tools installed:"
log_info "  - pass (password-store)"
log_info "  - ripgrep (rg)"
log_info "  - entr"
log_info "  - bat/batcat"
log_info "  - fzf"
log_info "  - oh-my-posh"
log_info "  - zellij"
log_info "  - nvim (neovim)"
log_info "  - eza"
log_info "  - zoxide"
log_info "  - tlrc"
log_info "  - zinit (zsh plugin manager)"
log_info "============================================="
log_info "Please log out and back in, or run: exec zsh"
