# Issues found and fixed

A record of concrete defects in this config, why each one happened, and how the
fix was verified. Written while porting the config to macOS in July 2026, on
Neovim 0.12.4 — but most of these were not macOS-specific at all.

Kept because several fixes look arbitrary without the reason: it explains why
`shellcmdflag` is conditional, why plugin modules are required inside callbacks,
and why the python3 provider is pinned to a venv.

---

## A. Bootstrap — the config could not set up a new machine

Three separate defects, all invisible on a machine that already had plugins
installed, and all fatal on a fresh one.

### A1. `init.lua` aborted before the plugin manager could bootstrap

`init.lua` called `require("ibl").setup()` — indent-blankline, a *plugin* —
before sourcing `plugins.vim`, which is what installs plugins. On a machine with
no plugins the require raised, `init.lua` stopped there, and the plugin manager
was never reached. The next launch failed identically.

```mermaid
flowchart TD
  subgraph before["before — deadlock"]
    B1([nvim starts]) --> B2["init.lua"]
    B2 --> B3["require ibl"]
    B3 --> B4["ERROR: module not found"]
    B4 --> B5["init.lua aborts"]
    B5 --> B6["plugins.vim never sourced<br/>→ no plugin manager<br/>→ no plugins, ever"]
    style B4 fill:#4a2b2b,stroke:#c86464,color:#f0d0d0
    style B6 fill:#4a2b2b,stroke:#c86464,color:#f0d0d0
  end

  subgraph after["after"]
    A1([nvim starts]) --> A2["init.lua"]
    A2 --> A3["source core files<br/>incl. plugins.vim"]
    A3 --> A4["lazy.nvim bootstraps<br/>and installs everything"]
    A4 --> A5["ibl configured by its own spec"]
    style A4 fill:#2b4a32,stroke:#64c878,color:#d0f0d8
  end
```

`core/options.lua` had the same shape: a top-level
`require('telescope.builtin')`.

**Verified** by running the pre-fix revision under an isolated `NVIM_APPNAME`: it
dies at `init.lua:23` and never clones the plugin manager. Confirmed 0 plugins
installed.

**Fixed** by configuring indent-blankline through its plugin spec instead, and by
requiring plugin modules inside keymap callbacks rather than at file scope. The
latter is also what lets lazy.nvim defer loading.

### A2. `fresh_install` was computed and never used

`packer_ensure_install()` returned a flag saying "this is a first run", assigned
it to `local fresh_install`, and nothing ever read it. So even once packer had
been cloned, the first launch installed **no plugins** — you had to know to run
`:PackerSync` by hand.

Wiring the flag up to `packer.sync()` then exposed a second problem: the
config's own sync raced `install.sh`'s `:PackerSync`, and neither completed.

**Fixed** by migrating to lazy.nvim, which installs missing plugins during
`setup()` with no separate step and no race.

**Verified** on an isolated `HOME`: a single `nvim` launch installs all 25
plugins. The same test under packer produced 0.

### A3. `PackerSync` deleted packer itself

packer was not listed in its own plugin spec, so `PackerClean` — which
`PackerSync` runs — treated it as an unmanaged plugin and removed it. Every
following startup re-cloned it.

**Fixed** by the lazy.nvim migration; lazy manages itself.

---

## B. Neovim 0.12 removed APIs this config used

Deprecated for several releases, but removed by the time this was run, so each
one was a hard error or a traceback on every startup.

| API | Status | Replacement |
| --- | --- | --- |
| `vim.pretty_print` | **gone** in 0.12 | `vim.print` |
| `vim.diagnostic.goto_prev` / `goto_next` | **gone** in 0.12 | `vim.diagnostic.jump { count = ±1 }` |
| `lspconfig.<server>.setup` framework | deprecated, prints a traceback | `vim.lsp.config` + `vim.lsp.enable` |
| `vim.lsp.with` | deprecated | pass opts to `vim.lsp.buf.hover` |
| `lspconfig.tsserver` | renamed | `lspconfig.ts_ls` |
| `float.source = "always"` | string form dropped | `source = true` |

Confirmed empirically rather than from release notes:
`vim.pretty_print ~= nil` is `false` on 0.12.4 while `vim.print` exists.

All of it is **version-gated**, not replaced outright, so an older Neovim on the
Arch box still takes the old path:

```lua
local use_native_lsp = vim.lsp.config ~= nil and vim.lsp.enable ~= nil
```

The lspconfig migration also changed how `custom_attach` runs: the builtin API
has no `on_attach`, so it is now driven by an `LspAttach` autocmd.

---

## C. Portability — Arch assumptions that break on macOS

| Assumption | Effect on macOS | Fix |
| --- | --- | --- |
| `xdg-open` for the search-under-cursor map | command not found | `open` when `vim.g.is_mac` |
| `shellcmdflag = '-ic'` | every `:!` re-runs the whole zsh profile — brew, conda, nvm, starship, zinit | skipped on macOS; it exists for vim-forgit, which is commented out |
| `ibus-daemon -drx` | errors on every shell start; ibus is X11 | Linux-only branch |
| `export TERM=rxvt` | wrong terminfo in Terminal.app, iTerm2, kitty; follows you over ssh and tmux | only when the terminal did not identify itself *and* the terminfo entry exists |
| conda at `/opt/miniconda3` and `/home/kai/miniconda3` | neither exists; macOS is `/Users/kai` | probe a list of prefixes |
| `GOROOT=/usr/lib/go` | Homebrew uses its own prefix | `go env GOROOT` when `go` is present |
| no `/opt/homebrew/bin` on `PATH` | every brew-installed tool missing | `brew shellenv` first, on darwin |
| `alias pbcopy='xsel …'` | **shadows the real `pbcopy`**, and `xsel` is X11-only, so every clipboard pipe breaks silently | only alias when `xsel` actually exists |
| `tr -dc` over `/dev/urandom` | BSD `tr` aborts with "Illegal byte sequence" | `LC_ALL=C tr` |
| `/home/$USER` in `rls` | macOS users live under `/Users` | `$HOME` |

`clipboard=unnamedplus` needed no change — Neovim finds `pbcopy` on its own.

---

## D. Correctness

### D1. Trailing-whitespace autocmd failed on read-only buffers

```lua
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
  pattern = { "*" },
  command = [[%s/\s\+$//e]],
})
```

Any write to a non-modifiable buffer raised
`E21: Cannot make changes, 'modifiable' is off`. Hit for real by writing
`:checkhealth` output to a file.

The substitution also clobbered the search register and cursor position on every
save.

**Fixed** with a callback that returns early on `nomodifiable`/`readonly`, uses
`keeppatterns`, and restores the view with `winsaveview`/`winrestview`.
**Verified** both ways: writing `:checkhealth` output now succeeds, and a file
with trailing whitespace still shrinks 16 → 12 bytes on save.

### D2. UltiSnips broke depending on `$PATH`

`vim.g.python3_host_prog = fn.exepath("python3")` resolves to whatever comes
first on `$PATH`. On this Mac that is conda's python, which has no `pynvim`, so
UltiSnips failed at startup with "Failed to load python3 host" — and it would
break again on any conda env switch.

**Fixed** by pinning the provider to `stdpath("data")/venv`, falling back to the
old behaviour when that venv is absent so the Arch box is unaffected.

Homebrew's python 3.14 could not create the venv — `ensurepip` fails — so
`install.sh` tries several interpreters rather than assuming `python3` works.

---

## E. Secrets

Six `export` lines in `~/.zshrc` held GitHub, Datadog and Cloudflare
credentials. Findings, in order of how much they mattered:

1. **`~/.zshrc` was mode `0644`** — world readable. Every token in it was
   readable by any local user or process. This was the real exposure, and it had
   nothing to do with git.
2. **The 6 exports were only 3 distinct secrets**, each duplicated under two
   names: `GH_TOKEN`/`NPM_TOKEN`, `DD_TOKEN`/`DD_PAT`, `CF_TOKEN`/`CF_API_TOKEN`.
3. **One token was also in `~/.zsh_history`**, from having been typed on a
   command line.
4. **Nothing ever reached GitHub.** All values were checked against every commit
   on every ref — 1.86 MB of diffs across 15 refs including 8 remote branches
   and a tag — and against all 381 tracked files. No match, and no token-shaped
   string anywhere in history. The repo tracks its *own* `.zshrc`, which is a
   different file from the live `~/.zshrc` and never held a credential.

**Fixed** by moving the exports to `~/.privatealiases` at mode 0600, sourced by
`.zshrc`; tightening `~/.zshrc` to 0600; and adding `~/.zshrc.d` so
machine-local config has a home that is not the tracked file. `install.sh
--link-shell` now refuses to link while `~/.zshrc` contains anything
token-shaped, and `--status` warns about loose permissions on either path.

A 0600 file is a floor, not a goal — the values are still plaintext at rest and
still in the environment of every child process. Stronger options, in
`ARCHITECTURE.md` terms: `direnv` for project-scoped tokens, or the OS keystore
(`security` on macOS, `secret-tool`/`pass` on Linux).

---

## F. Conflicts left unresolved on purpose

Not bugs — cases where the machine's own file was the better one. See
[`MAC.md`](MAC.md).

- **`kitty.conf`**: the repo binds `alt+N` for tabs, but alt is a compose key on
  macOS; the Mac's own config uses `cmd+N`. The repo version also `include`s a
  `theme.conf` that is gitignored and absent, and hardcodes `/usr/bin/fzf` where
  Homebrew installs to `/opt/homebrew/bin/fzf`.
- **`.gitconfig`**: sets `core.pager = delta` and `filter.lfs.required = true`.
  Without `git-lfs` installed, LFS repos fail to check out.
- **`.config/vscode/editor.json`**: not a path VS Code reads. Real location is
  `~/Library/Application Support/Code/User/settings.json`.
