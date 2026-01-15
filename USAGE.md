# Usage Instructions

## Important: Local Machine Safety

**This repository is configured to NOT affect your local machine.** It's designed exclusively for remote server initialization.

## Setting Up on Remote Servers

1. **Install chezmoi** (if not already installed):
   ```bash
   sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin
   ```

2. **Initialize dotfiles on remote server**:
   ```bash
   chezmoi init --apply https://github.com/yourusername/dotfiles.git
   ```
   
   Or with SSH:
   ```bash
   chezmoi init --apply git@github.com:yourusername/dotfiles.git
   ```

3. **Verify installation**:
   ```bash
   ls -la ~ | grep zshrc
   source ~/.zshrc
   ```

4. **Tools installation**: The installation script (`run_once_install-tools.sh`) will automatically run during `chezmoi apply` and install all configured tools on Debian Trixie systems.

## Repository Structure

- `dot_zshrc` → becomes `~/.zshrc` on remote servers
- `dot_zprofile` → becomes `~/.zprofile` on remote servers
- `dot_zsh/` → directory for additional zsh configs (if needed)

## Customization

Edit the files in this repository (with `dot_` prefix), commit, and push. On remote servers, run:
```bash
chezmoi update
```

This will pull the latest changes and apply them.
