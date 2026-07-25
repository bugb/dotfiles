# Using these dotfiles on macOS

These dotfiles were originally written for Arch Linux, then made to work on macOS
as well. This file covers what applies cleanly on a Mac, what is worth leaving
alone, and why.

For the general design — the symlink model, the manifest, how one repo serves two
operating systems — see [`ARCHITECTURE.md`](ARCHITECTURE.md).

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

### Adopting the shared `.zshrc` on a machine that already has one

Do this in two steps, or you will lose the setup that makes that machine work:

1. Move anything machine-specific out of `~/.zshrc` into a drop-in — package
   manager paths, version manager setup, tool-specific environment, local
   aliases. Move any `export` of an API token into `~/.privatealiases`.
2. `./install.sh --link-shell`.

Step 2 refuses to run while `~/.zshrc` still contains anything token-shaped, so
you cannot skip step 1 by accident.

### If you want stronger than a 0600 file

A plaintext file readable only by you is a real improvement over an inline
`export` in a world-readable rc, but the values are still on disk and still in
the environment of every process the shell starts. Two upgrades, in order of
effort:

- **Scope tokens per project.** A token used by one repository does not need to be
  in every shell. `direnv` with a gitignored `.envrc` keeps it out of unrelated
  processes entirely.
- **Keep them in the OS keystore.** On macOS, store the value once:

  ```bash
  security add-generic-password -s MY_TOKEN -a "$USER" -w
  ```

  then read it back in `~/.privatealiases`:

  ```bash
  export MY_TOKEN="$(security find-generic-password -s MY_TOKEN -a "$USER" -w 2>/dev/null)"
  ```

  Nothing is plaintext at rest, at the cost of a keystore call per secret per
  shell. The Linux equivalent is `secret-tool` or `pass`, so the same
  `~/.privatealiases` can branch on `$OSTYPE` and stay a single file.

## Setting it up

By default only Neovim is applied: `~/.config/nvim` becomes a symlink into this
repo. Run the installer:

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
on a new machine installs everything. `lazy-lock.json` is tracked, so every
machine gets the same plugin revisions. `:Lazy` opens the UI, and the old packer
abbreviations still work (`ps` → `Lazy sync`, `pud` → `Lazy update`, `pi`, `pc`).

The python3 provider, which UltiSnips needs, is pinned to a dedicated venv so
that activating a conda env or virtualenv cannot break it — see
`core/globals.lua`. `install.sh` creates it; by hand it is:

```bash
python3 -m venv ~/.local/share/nvim/venv
~/.local/share/nvim/venv/bin/python3 -m pip install pynvim
```

Watch out for one thing here: Homebrew's python 3.14 fails to build a venv,
because its `ensurepip` is broken. The installer tries several interpreters for
this reason, so it usually finds a working one — but if you build the venv by
hand and it fails, try a different python3. Without a working venv, UltiSnips
fails at startup with "Failed to load python3 host".

If a language server the config looks for is missing, Neovim prints one warning
per server at startup. `./install.sh --with-lsp` installs `pylsp` and
`typescript-language-server`. `gopls` needs a Go toolchain:
`brew install go && go install golang.org/x/tools/gopls@latest`.

## What is left opt-in on macOS, and why

| File | Consider before linking |
| --- | --- |
| `.zshrc` | Replaces your own `~/.zshrc` wholesale. Anything machine-specific in it — package manager paths, version managers, tool environment, local aliases — is not in this repo and stops being loaded. Split those into `~/.zshrc.d/` first. |
| `.aliases` | Only reachable via this repo's `.zshrc`, so link it together with that. |
| `.gitconfig` | Sets `core.pager = delta` and `filter.lfs.required = true`, so it needs both installed (`brew install git-delta git-lfs && git lfs install`) or `git diff` and LFS checkouts will fail. It also sets a `user.name` and `user.email` that are almost certainly not yours. |
| `.config/i3`, `.config/i3blocks` | i3 is an X11 window manager, so this is inert on macOS. |
| `.config/kitty/kitty.conf` | Binds `alt+N` to switch tabs, which is awkward on macOS where alt is a compose key — `cmd+N` is the native idiom. It also `include`s a `theme.conf` that is gitignored and absent, so kitty warns at startup, and hardcodes `/usr/bin/fzf` where Homebrew installs `/opt/homebrew/bin/fzf`. |
| `.config/vscode/editor.json` | Not a path VS Code reads. The real location is `~/Library/Application Support/Code/User/settings.json`, so this is a reference copy only. |

## Before linking `.zshrc`: secrets

⚠️ **This repo tracks `.zshrc`.** If your fork is public and you symlink
`~/.zshrc` into it, anything in that file is one `git add .` away from being
published.

Shell rc files are a common place for API tokens to accumulate as inline
`export` lines. Before linking, move them to `~/.privatealiases`, which the
tracked `.zshrc` sources and git never sees:

```bash
touch ~/.privatealiases && chmod 600 ~/.privatealiases
# then move each `export SOME_TOKEN=…` line out of ~/.zshrc into it
```

`./install.sh --link-shell` refuses to run while `~/.zshrc` still contains
anything token-shaped, and `--status` warns if `~/.privatealiases` is readable by
other users. Also check the mode on `~/.zshrc` itself — a shell rc holding
credentials at the default `0644` is readable by every account on the machine.

If a token has been sitting in a world-readable file, in shell history, or in a
backup, treat it as exposed and rotate it. Moving a credential does not un-expose
it.

## What was made portable

The Linux-only lines are conditional rather than removed, so `.zshrc` behaves
exactly as before on Linux and no longer breaks on macOS:

- `ibus-daemon` and the `*_IM_MODULE` exports only run on Linux
- `export TERM=rxvt` applies only when the terminfo entry exists and the terminal
  has not already identified itself, since overriding `TERM` breaks colours and
  keys in Terminal.app, iTerm2 and kitty — and follows you over ssh and tmux
- conda and `GOROOT` are probed rather than hardcoded to Linux paths
- Homebrew's `shellenv` is evaluated first on macOS, or nothing installed through
  it is on `PATH`
- `starship`, `zoxide` and `pet` are guarded by `command -v`, so a machine
  missing them still gets a working shell

The clipboard aliases are the one to know about: `.aliases` only maps
`pbcopy`/`pbpaste` to `xsel` when `xsel` actually exists. Unconditionally, those
aliases shadow the real macOS commands and every clipboard pipe breaks silently.

[`ISSUES.md`](ISSUES.md) has the full list, with what each symptom looked like.
