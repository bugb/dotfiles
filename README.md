# dotfiles

Neovim, zsh and terminal config, shared between an Arch Linux desktop and a macOS
laptop from a single tracked source.

## Quick start

```bash
git clone https://github.com/bugb/dotfiles.git
cd dotfiles
./install.sh              # dependencies, symlinks, Neovim plugins
./install.sh --with-lsp   # and the language servers
./install.sh --status     # what is linked on this machine
./install.sh --dry-run    # show every action, change nothing
```

Works on macOS (Homebrew), Arch (pacman), Debian/Ubuntu (apt) and Fedora (dnf).
Re-runnable; anything it would replace is backed up rather than deleted.

By default only Neovim is applied. Shell, git, kitty and i3 are opt-in
(`--link-shell`, `--link-git`, `--link-kitty`, `--link-i3`, or `--all`) because
they replace files that are often machine-specific.

## How it works

The repo is the source of truth and is applied as **symlinks**, so a managed path
*is* the file in this repo — edit either side, there is no copy to keep in sync.

Machine-specific config goes in `~/.zshrc.d/*.zsh` and secrets in
`~/.privatealiases` (mode 0600). Neither is tracked, which is what keeps the
shared `.zshrc` safe to symlink out of a public repo.

Full detail, with diagrams: **[ARCHITECTURE.md](ARCHITECTURE.md)**.

## Contents

| Path | What |
| --- | --- |
| `.config/nvim/` | Neovim config, plugins via [lazy.nvim](https://github.com/folke/lazy.nvim) |
| `.zshrc`, `.aliases` | zsh setup and shared aliases |
| `.gitconfig` | git, with delta as the pager |
| `.config/kitty/` | terminal |
| `.config/i3/`, `.config/i3blocks/` | window manager, Linux only |
| `install.sh` | the installer |

## Docs

- **[ARCHITECTURE.md](ARCHITECTURE.md)** — the symlink model, the three shell
  config layers, install flow, Neovim load order, how one repo serves two OSes
- **[ISSUES.md](ISSUES.md)** — defects found in this config and how each was
  fixed, including the bootstrap deadlock and the Neovim 0.12 API removals
- **[MAC.md](MAC.md)** — macOS specifics and what is deliberately not linked there
- **[.config/nvim/README.md](.config/nvim/README.md)** — Neovim setup notes

## Notes

Plugin revisions are pinned in `lazy-lock.json`, which is tracked, so a second
machine installs the same versions. Updating plugins with `:Lazy` leaves the repo
dirty by design — commit the lockfile.

Because the config is symlinked live, a `git pull` here changes the running editor
immediately. There is no apply step, and no staging step either.
