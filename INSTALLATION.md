# Tool Installation Guide

This repository includes an automated installation script for Debian Trixie that installs the following development tools:

## Tools Installed

1. **oh-my-posh** - Modern shell prompt
2. **pass** - Password store (via apt)
3. **zellij** - Terminal multiplexer
4. **nvim** - Neovim editor (prefers apt, falls back to GitHub)
5. **bat** - Cat alternative with syntax highlighting (via apt)
6. **eza** - Modern ls replacement
7. **ripgrep** - Fast grep alternative (via apt)
8. **entr** - File watcher (via apt)
9. **fzf** - Fuzzy finder (prefers apt, falls back to GitHub)
10. **zoxide** - Smart cd replacement
11. **tlrc** - tldr client

## How It Works

The script `run_once_install-tools.sh` is automatically executed by chezmoi when you run `chezmoi apply` or `chezmoi init --apply`.

### Installation Methods

- **APT packages**: Tools available in Debian repositories are installed via `apt-get`
- **GitHub releases**: Tools not in repositories are downloaded from GitHub releases
- **Idempotent**: The script checks if tools are already installed before attempting installation

### Requirements

- Debian Trixie (or compatible Debian-based system)
- sudo access
- Internet connection
- Architecture: amd64 or arm64

## Manual Execution

If you need to run the installation script manually:

```bash
bash ~/.local/share/chezmoi/run_once_install-tools.sh
```

Or if you've cloned this repo directly:

```bash
bash run_once_install-tools.sh
```

## Troubleshooting

### Tools not found after installation

Make sure `~/.local/bin` is in your PATH. This is automatically added to `.zshrc`, but you may need to:

```bash
export PATH="$HOME/.local/bin:$PATH"
source ~/.zshrc
```

### GitHub download failures

Some tools may fail to download if:
- GitHub API rate limits are hit
- Network connectivity issues
- Release asset naming changes

In these cases, you can manually install the tool or retry the script.

### Architecture not supported

The script currently supports:
- `amd64` / `x86_64`
- `arm64` / `aarch64`

For other architectures, you'll need to modify the script or install tools manually.
