# Dotfiles Repository

This is a chezmoi dotfile management repository designed for remote server setup.

## Usage on Remote Servers

To initialize your dotfiles on a remote server:

```bash
chezmoi init --apply https://github.com/yourusername/dotfiles.git
```

Or if using SSH:

```bash
chezmoi init --apply git@github.com:yourusername/dotfiles.git
```

## What's Included

- Basic zsh configuration (.zshrc) with tool integrations
- Automated installation script for development tools:
  - oh-my-posh (prompt)
  - pass (password-store)
  - zellij (terminal multiplexer)
  - nvim (Neovim editor)
  - bat (cat alternative)
  - eza (ls replacement)
  - ripgrep (grep alternative)
  - entr (file watcher)
  - fzf (fuzzy finder)
  - zoxide (smart cd)
  - tlrc (tldr client)

## Local Development

This repository is NOT meant to be used on your local machine. It's designed to be cloned and applied on remote servers only.
