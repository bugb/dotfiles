# Using these dotfiles on macOS

These dotfiles were written for Arch Linux. This file records what is safe to
use on a Mac, what is deliberately *not* symlinked, and why.

Verified on macOS 26.1 (Apple Silicon), Neovim 0.12.4, zsh 5.9.

## How this repo relates to the machine

The repo is the source of truth and `install.sh` applies it. Everything is
applied as a **symlink**, so a managed path *is* the file in the repo — there is
no copy anywhere that can drift, and editing `~/.config/nvim/init.lua` and
editing `.config/nvim/init.lua` in the repo are the same write.

```bash
./install.sh --status    # what is linked, what is a local copy, what is missing
./install.sh             # apply: dependencies, the nvim symlink, plugins
./install.sh --all       # every group, including shell, git, kitty and i3
```

`install.sh` reads one manifest (the `manifest()` function) listing
`group|path-in-repo|path-in-HOME`. Managing a new dotfile is one line there.
Groups other than `nvim` are opt-in, because they replace files that are
machine-specific or platform-specific.

The parts that genuinely cannot be shared between machines have somewhere to
live, which is what lets the shared files be symlinked at all:

| Path | Tracked | Holds |
| --- | --- | --- |
| repo `.zshrc`, `.aliases` | yes | everything shared between machines |
| `~/.zshrc.d/*.zsh` | **no** | per-machine PATH, tool setup, local aliases |
| `~/.privatealiases` | **no** | tokens and secrets, mode 600 |

`~/.zshrc.d` is the scalable half: the tracked `.zshrc` sources every
`~/.zshrc.d/*.zsh` in name order, last, so machine-local config is a **new file**
rather than an edit to a shared file. Nothing to merge, nothing to guard against
committing by accident. Numeric prefixes order it:

```bash
mkdir -m 700 -p ~/.zshrc.d
cat > ~/.zshrc.d/00-path.zsh <<'EOF'
export PATH="/opt/homebrew/bin:$PATH"
EOF
```

Secrets deliberately do **not** go in `~/.zshrc.d`. They stay in the single
`~/.privatealiases`, because one well-known path is easier to keep at mode 600,
easier to exclude from backups and sync, and easier to audit than one file among
many in a directory you add to routinely. `./install.sh --status` reports the
mode of both and warns if either is readable by other users.

To move this Mac onto the shared `.zshrc`: the tokens are already split out, so
what is left is moving Homebrew/nvm/conda/Webots/VS Code setup and the work
aliases into `~/.zshrc.d/`, then `./install.sh --link-shell`. It refuses to link
while `~/.zshrc` still contains anything token-shaped.

### If you want stronger than a 0600 file

A plaintext file readable only by you is a real improvement over an inline
`export` in a world-readable rc, but the values are still on disk and still in
the environment of every process the shell starts. Two upgrades, in order of
effort:

- **Scope them per project.** `NPM_TOKEN`, `DD_PAT` and `CF_API_TOKEN` are for
  particular repos, not for every shell. `direnv` with a gitignored `.envrc`
  keeps them out of unrelated processes entirely.
- **Keep them in the OS keystore.** On macOS, `security add-generic-password -s
  GH_TOKEN -a "$USER" -w`, then in `~/.privatealiases`:

  ```bash
  export GH_TOKEN="$(security find-generic-password -s GH_TOKEN -a "$USER" -w 2>/dev/null)"
  ```

  Nothing is plaintext at rest, at the cost of a keychain call per secret per
  shell. The Linux equivalent is `secret-tool` or `pass`, so the same
  `~/.privatealiases` can branch on `$OSTYPE` and stay one file.

## What is active on the Mac

Only Neovim. `~/.config/nvim` is a symlink into this repo. Run the installer:

```bash
./install.sh              # deps + link + plugins
./install.sh --with-lsp   # and the language servers
./install.sh --dry-run    # show what it would do, change nothing
```

It is re-runnable and backs up anything it would replace. Everything else in
this repo is left alone unless you pass `--link-shell` / `--link-git` — see the
next section for why.

Doing it by hand instead:

```bash
ln -sfn "$PWD/.config/nvim" ~/.config/nvim
brew install neovim fd fzf ripgrep bat git-delta
brew install python-lsp-server            # pylsp
npm i -g typescript typescript-language-server
```

Plugins are managed by lazy.nvim, which bootstraps itself: launching `nvim` once
on a new machine installs everything. `lazy-lock.json` is committed, so a fresh
machine gets the same plugin revisions this one runs. `:Lazy` for the UI, and
the old packer abbreviations still work (`ps` -> `Lazy sync`, `pud` ->
`Lazy update`, `pi`, `pc`).

The python3 provider (needed by UltiSnips) is pinned to a dedicated venv so that
activating a conda env cannot break it — see `core/globals.lua`. `install.sh`
creates it; by hand it is:

```bash
python3 -m venv ~/.local/share/nvim/venv
~/.local/share/nvim/venv/bin/python3 -m pip install pynvim
```

Homebrew's python3 could not build the venv (`ensurepip` fails on 3.14), so it
was created with `~/miniconda3/bin/python3`; the installer tries several
interpreters for this reason. If miniconda is ever removed, recreate the venv
with any working python3. Without it, UltiSnips fails at startup with
"Failed to load python3 host".

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
