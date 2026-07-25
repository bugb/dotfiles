This is my minimal and fast Neovim config (borrow lots of things and heavily inspired from https://github.com/jdhao/nvim-config)

## 0. Quick start

From the repo root, on macOS or Linux:

```bash
./install.sh              # dependencies, symlink, plugins
./install.sh --with-lsp   # and the language servers below
```

Or by hand: symlink `.config/nvim` to `~/.config/nvim` and launch `nvim` once —
lazy.nvim bootstraps itself and installs every plugin. UltiSnips additionally
needs `pynvim` in the provider venv, which `install.sh` sets up.

## A. Shell and some useful programs 
- Setup zsh and oh-my-zsh
- Setup zinit for zsh plugins manager
- Setup `fd`, `fzf`, `bat` first
If you are using Arch Linux
```bash
sudo pacman -S fd fzf bat
```
- Setup pager took like: delta
- Setup forgit

## B. Setup Neovim plugins

Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim); the spec
lives in `lua/plugins.lua`. It replaced packer.nvim, which has been unmaintained
since 2023.

`lazy-lock.json` is committed, so a fresh machine installs the same revisions.
Use `:Lazy` for the UI. The old abbreviations still work: `ps` -> `Lazy sync`,
`pud` -> `Lazy update`, `pi` -> `Lazy install`, `pc` -> `Lazy clean`.

### 1. Code snippets 

### 2. LSP and code completion, syntax highlighting
Setup Python LSP Server with:
```bash
# if you use conda
# conda create --name boostai
# conda activate boostai
# conda install -c conda-forge pip
pip install pyright neovim python-lsp-server
```

Setup Typescript Language Server with:
```bash
npm i -g typescript typescript-language-server
```
### 3. Other plugins 
- Setup markdow live preview with plugins: "iamcco/markdown-preview.nvim"
- Setup fuzzy finder with "nvim-telescope/telescope.nvim"
