This is my minimal and fast Neovim config (borrow lots of things and heavily inspired from https://github.com/jdhao/nvim-config)

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

Use Packer to manage plugins

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
