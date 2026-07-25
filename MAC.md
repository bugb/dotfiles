# Using these dotfiles on macOS

These dotfiles were written for Arch Linux. This file records what is safe to
use on a Mac, what is deliberately *not* symlinked, and why.

Verified on macOS 26.1 (Apple Silicon), Neovim 0.12.4, zsh 5.9.

## What is active on the Mac

Only Neovim. `~/.config/nvim` is a symlink into this repo:

```bash
ln -sfn "$PWD/.config/nvim" ~/.config/nvim
```

Everything else in this repo is left alone on macOS — see the next section.

### Dependencies

```bash
brew install neovim fd fzf ripgrep bat git-delta
brew install python-lsp-server            # pylsp
npm i -g typescript typescript-language-server
```

The python3 provider (needed by UltiSnips) is pinned to a dedicated venv so that
activating a conda env cannot break it — see `core/globals.lua`:

```bash
python3 -m venv ~/.local/share/nvim/venv
~/.local/share/nvim/venv/bin/python3 -m pip install pynvim
```

Homebrew's python3 could not build the venv (`ensurepip` fails on 3.14), so it
was created with `~/miniconda3/bin/python3`. If miniconda is ever removed,
recreate the venv with any working python3.

Plugins are managed by packer. First run bootstraps it; then `:PackerSync`.
`gopls` is not installed, so Neovim prints one `gopls not found!` warning at
startup. `brew install go && go install golang.org/x/tools/gopls@latest` clears it.

## What is NOT symlinked on macOS, and why

| File | Why not |
| --- | --- |
| `.zshrc` | Would replace the Mac's own `~/.zshrc`, which carries Homebrew's PATH, nvm, conda, the VS Code CLI, Webots, cargo and several private tokens. Adopt by merging, never by symlink — see below. |
| `.aliases` | Only reachable via this repo's `.zshrc`. Safe to source on its own once that file is merged. |
| `.gitconfig` | Sets `core.pager = delta` and `filter.lfs.required = true`. `delta` is now installed, but `git-lfs` is not — install it first (`brew install git-lfs && git lfs install`) or LFS repos will fail to check out. It also changes `user.name` from "Chau Giang Local" to "Chau Giang". |
| `.config/i3`, `.config/i3blocks` | i3 is an X11 window manager. Inert on macOS. |
| `.config/kitty/kitty.conf` | The Mac already has a different one: font size 18 vs 14, `cmd+N` tab switching (option is a compose key on macOS, so the repo's `alt+N` bindings are a poor fit) and `allow_remote_control`. The repo version also `include`s a `theme.conf` that is gitignored and absent, and hardcodes `/usr/bin/fzf` where Homebrew installs `/opt/homebrew/bin/fzf`. |
| `.config/vscode/editor.json` | Not a path VS Code reads. Real location is `~/Library/Application Support/Code/User/settings.json`. Reference copy only. |

## Before adopting `.zshrc`

⚠️ **This repo is public and tracks `.zshrc`.** The Mac's current `~/.zshrc`
contains live GitHub, Datadog and Cloudflare tokens in plaintext. If you symlink
`~/.zshrc` into this repo, the next `git add .` publishes them.

This file already sources `~/.privatealiases` if it exists — put secrets there
and keep it out of git. Rotate anything that has been sitting in a shell rc.

The Arch-only lines have been made conditional rather than removed, so the file
behaves identically on Arch and no longer breaks on macOS:

- `ibus-daemon` and the `*_IM_MODULE` exports only run on Linux
- `export TERM=rxvt` only applies when the terminfo entry exists and the
  terminal has not identified itself
- conda and `GOROOT` are probed instead of hardcoded to `/opt`, `/home/kai` and
  `/usr/lib/go`
- Homebrew's `shellenv` is evaluated first on macOS
- `starship`, `zoxide` and `pet` are guarded by `command -v`
