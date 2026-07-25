#!/usr/bin/env bash
#
# Set these dotfiles up on a fresh machine (macOS or Linux).
#
# Neovim only, by default: installs the dependencies, links ~/.config/nvim into
# this repo, prepares the python3 provider and installs the plugins. Shell and
# git files are opt-in, see --help.
#
# Safe to re-run. Anything it would replace is moved to <path>.backup.<n>.
#
# Written for bash 3.2, which is what macOS ships. No associative arrays,
# no mapfile, no ${var,,}.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DRY_RUN=0
SKIP_DEPS=0
WITH_LSP=0
LINK_SHELL=0
LINK_GIT=0
LINK_KITTY=0
LINK_I3=0
STATUS_ONLY=0
ASSUME_YES=0

# OS_NAME/PKG_MGR are normally detected. DOTFILES_FORCE_OS and
# DOTFILES_FORCE_PKG override them so the non-native paths can be exercised
# under --dry-run from any machine.
OS_NAME=""
PKG_MGR=""

RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  RED="$(printf '\033[31m')"; GREEN="$(printf '\033[32m')"
  YELLOW="$(printf '\033[33m')"; BLUE="$(printf '\033[34m')"
  BOLD="$(printf '\033[1m')"; RESET="$(printf '\033[0m')"
fi

info()  { printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"; }
ok()    { printf '%s  ok%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()  { printf '%s warn%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
err()   { printf '%serror%s %s\n' "$RED" "$RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry%s %s\n' "$YELLOW" "$RESET" "$*"
  else
    "$@"
  fi
}

usage() {
  cat <<'EOF'
Usage: ./install.sh [options]

Installs the Neovim setup from this repo. Re-runnable; replaced files are
backed up rather than deleted.

Options:
  -s, --status       Show which managed paths are linked to this repo, then exit.
  -n, --dry-run      Print what would happen, change nothing.
      --no-deps      Skip package installation, only link and bootstrap.
      --with-lsp     Also install the language servers the config looks for
                     (pylsp, typescript-language-server, gopls).
      --link-shell   Also link .zshrc and .aliases into $HOME.
                     Read the warning it prints first: this repo is public and
                     tracks .zshrc.
      --link-git     Also link .gitconfig into $HOME. Needs git-lfs, which is
                     added to the dependency list when this is passed.
      --link-kitty   Also link .config/kitty/kitty.conf into $HOME.
      --link-i3      Also link .config/i3 and .config/i3blocks (Linux only).
      --all          Every group above, plus --with-lsp.
  -y, --yes          Do not prompt; assume yes. Prompts are skipped anyway when
                     stdin is not a terminal.
  -h, --help         This text.

Everything is applied as a symlink, so a linked path *is* the file in this repo:
edit either side and there is no copy to keep in sync. Machine-specific shell
config belongs in ~/.zshrc.local and secrets in ~/.privatealiases; both are
sourced by the tracked .zshrc and neither is in git.

Supported: macOS (Homebrew), Arch (pacman), Debian/Ubuntu (apt), Fedora (dnf).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run)  DRY_RUN=1 ;;
    --no-deps)     SKIP_DEPS=1 ;;
    --with-lsp)    WITH_LSP=1 ;;
    --link-shell)  LINK_SHELL=1 ;;
    --link-git)    LINK_GIT=1 ;;
    --link-kitty)  LINK_KITTY=1 ;;
    --link-i3)     LINK_I3=1 ;;
    -s|--status)   STATUS_ONLY=1 ;;
    --all)         WITH_LSP=1; LINK_SHELL=1; LINK_GIT=1; LINK_KITTY=1; LINK_I3=1 ;;
    -y|--yes)      ASSUME_YES=1 ;;
    -h|--help)     usage; exit 0 ;;
    *)             err "unknown option: $1"; echo; usage; exit 2 ;;
  esac
  shift
done

confirm() {
  # Default no. Non-interactive runs never block.
  if [ "$ASSUME_YES" -eq 1 ]; then
    return 0
  fi
  if [ ! -t 0 ]; then
    warn "not a terminal, assuming no: $1"
    return 1
  fi
  printf '%s%s%s [y/N] ' "$BOLD" "$1" "$RESET"
  local reply=""
  read -r reply || true
  case "$reply" in
    y|Y|yes|YES) return 0 ;;
    *)           return 1 ;;
  esac
}

# ---------------------------------------------------------------- detect ----

detect_platform() {
  OS_NAME="${DOTFILES_FORCE_OS:-}"
  if [ -z "$OS_NAME" ]; then
    case "$(uname -s)" in
      Darwin) OS_NAME="macos" ;;
      Linux)  OS_NAME="linux" ;;
      *)      die "unsupported OS: $(uname -s)" ;;
    esac
  fi

  PKG_MGR="${DOTFILES_FORCE_PKG:-}"
  if [ -z "$PKG_MGR" ]; then
    if [ "$OS_NAME" = "macos" ]; then
      PKG_MGR="brew"
    elif command -v pacman >/dev/null 2>&1; then
      PKG_MGR="pacman"
    elif command -v apt-get >/dev/null 2>&1; then
      PKG_MGR="apt"
    elif command -v dnf >/dev/null 2>&1; then
      PKG_MGR="dnf"
    else
      die "no supported package manager found (pacman, apt-get, dnf). Use --no-deps and install neovim, fd, fzf, ripgrep, bat and git-delta yourself."
    fi
  fi

  info "platform: $OS_NAME, packages via $PKG_MGR"
}

# Package names differ per distro. Echo the name for the current manager, or
# nothing when that manager has no such package.
pkg_name() {
  local generic="$1"
  case "$generic" in
    neovim)   echo "neovim" ;;
    git)      echo "git" ;;
    curl)     echo "curl" ;;
    fzf)      echo "fzf" ;;
    ripgrep)  echo "ripgrep" ;;
    fd)
      case "$PKG_MGR" in
        apt|dnf) echo "fd-find" ;;   # binary is fdfind on Debian
        *)       echo "fd" ;;
      esac ;;
    bat)      echo "bat" ;;
    delta)
      case "$PKG_MGR" in
        brew|pacman) echo "git-delta" ;;
        apt)         echo "git-delta" ;;
        dnf)         echo "git-delta" ;;
      esac ;;
    git-lfs)  echo "git-lfs" ;;
    node)
      case "$PKG_MGR" in
        brew)   echo "node" ;;
        pacman) echo "nodejs npm" ;;
        apt)    echo "nodejs npm" ;;
        dnf)    echo "nodejs npm" ;;
      esac ;;
    python)
      case "$PKG_MGR" in
        brew)   echo "python@3" ;;
        pacman) echo "python" ;;
        apt)    echo "python3 python3-venv python3-pip" ;;
        dnf)    echo "python3 python3-pip" ;;
      esac ;;
    pylsp)
      case "$PKG_MGR" in
        brew)   echo "python-lsp-server" ;;
        pacman) echo "python-lsp-server" ;;
        *)      echo "" ;;   # pip fallback
      esac ;;
    gopls)
      case "$PKG_MGR" in
        brew)   echo "gopls" ;;
        pacman) echo "gopls" ;;
        *)      echo "" ;;
      esac ;;
    *)        echo "" ;;
  esac
}

APT_UPDATED=0

pkg_run_install() {
  case "$PKG_MGR" in
    brew)   run brew install "$@" ;;
    pacman) run sudo pacman -S --needed --noconfirm "$@" ;;
    apt)    run sudo apt-get install -y "$@" ;;
    dnf)    run sudo dnf install -y "$@" ;;
    *)      die "cannot install packages with '$PKG_MGR'" ;;
  esac
}

pkg_install() {
  # Takes generic names, maps them, installs the ones that map to something.
  local generic mapped list="" pkg
  for generic in "$@"; do
    mapped="$(pkg_name "$generic")"
    if [ -n "$mapped" ]; then
      list="$list $mapped"
    else
      warn "no $PKG_MGR package known for '$generic', skipping"
    fi
  done

  # shellcheck disable=SC2086  # deliberate word splitting of the package list
  set -- $list
  if [ $# -eq 0 ]; then
    return 0
  fi

  if [ "$PKG_MGR" = "apt" ] && [ "$APT_UPDATED" -eq 0 ]; then
    run sudo apt-get update -qq || warn "apt-get update failed, continuing anyway"
    APT_UPDATED=1
  fi

  if pkg_run_install "$@"; then
    return 0
  fi

  # One package missing from this distro's repos should not take the whole run
  # down with it, so retry individually and report what actually failed.
  warn "installing the group failed; retrying one package at a time"
  for pkg in "$@"; do
    pkg_run_install "$pkg" || warn "could not install '$pkg', install it manually"
  done
  return 0
}

check_prereqs() {
  if [ "$OS_NAME" = "macos" ] && [ "$PKG_MGR" = "brew" ] && ! command -v brew >/dev/null 2>&1; then
    err "Homebrew is not installed, and it is how everything else gets installed."
    err "Install it first, then re-run this script:"
    # shellcheck disable=SC2016  # printing the command verbatim, not running it
    err '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    exit 1
  fi

  if ! command -v git >/dev/null 2>&1; then
    die "git is required to bootstrap the plugin manager."
  fi

  # nvim-treesitter compiles parsers, so a C compiler has to exist.
  if ! command -v cc >/dev/null 2>&1 && ! command -v gcc >/dev/null 2>&1 && ! command -v clang >/dev/null 2>&1; then
    warn "no C compiler found; nvim-treesitter cannot build parsers."
    if [ "$OS_NAME" = "macos" ]; then
      warn "install the command line tools with: xcode-select --install"
    else
      warn "install your distro's base build packages (base-devel, build-essential, ...)"
    fi
  fi
}

# ------------------------------------------------------------------ link ----

# Move an existing path out of the way, never delete it.
backup_path() {
  local target="$1" n=1 candidate
  candidate="$target.backup"
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$target.backup.$n"
    n=$((n + 1))
  done
  warn "$(basename "$target") exists, moving it to $(basename "$candidate")"
  run mv "$target" "$candidate"
}

link_path() {
  local src="$1" dest="$2"

  [ -e "$src" ] || die "missing in repo: $src"

  # Already pointing where we want it.
  if [ -L "$dest" ]; then
    local current
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      ok "$dest -> $src (already linked)"
      return 0
    fi
  fi

  if [ -e "$dest" ] || [ -L "$dest" ]; then
    backup_path "$dest"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -sfn "$src" "$dest"
  ok "$dest -> $src"
}

# Everything this repo can own, as "group|path-in-repo|path-in-HOME". This is the
# list that makes the repo the single source of truth: adding a dotfile means
# adding one line here, and --status reports against it.
#
# Only the nvim group is applied by default. The rest is opt-in because it either
# replaces machine-specific files or is platform-specific.
manifest() {
  cat <<EOF
nvim|.config/nvim|$HOME/.config/nvim
shell|.zshrc|$HOME/.zshrc
shell|.aliases|$HOME/.aliases
git|.gitconfig|$HOME/.gitconfig
kitty|.config/kitty/kitty.conf|$HOME/.config/kitty/kitty.conf
i3|.config/i3|$HOME/.config/i3
i3|.config/i3blocks|$HOME/.config/i3blocks
EOF
}

# Link every entry of one group. Returns 1 if the group has nothing in it.
link_group() {
  local want="$1" group src dest found=1
  while IFS='|' read -r group src dest; do
    [ "$group" = "$want" ] || continue
    found=0
    link_path "$REPO_DIR/$src" "$dest"
  done <<EOF
$(manifest)
EOF
  return $found
}

# What the repo owns versus what is actually on this machine.
HOME_ABBREV='~'

show_status() {
  local group src dest state link_target shown
  printf '\n%s%-7s %-28s %s%s\n' "$BOLD" "GROUP" "PATH IN HOME" "STATE" "$RESET"

  while IFS='|' read -r group src dest; do
    if [ ! -e "$REPO_DIR/$src" ]; then
      state="${YELLOW}not in repo${RESET}"
    elif [ -L "$dest" ]; then
      link_target="$(readlink "$dest")"
      if [ "$link_target" = "$REPO_DIR/$src" ]; then
        state="${GREEN}linked${RESET}"
      else
        state="${YELLOW}linked elsewhere -> $link_target${RESET}"
      fi
    elif [ -e "$dest" ]; then
      state="${YELLOW}own copy, not linked${RESET}"
    else
      state="absent"
    fi
    # Show ~/… rather than the absolute path, so the column stays narrow. The
    # tilde comes from a variable so it is never a quoted literal to expand.
    case "$dest" in
      "$HOME"/*) shown="$HOME_ABBREV/${dest#"$HOME"/}" ;;
      *)         shown="$dest" ;;
    esac
    printf '%-7s %-28s %s\n' "$group" "$shown" "$state"
  done <<EOF
$(manifest)
EOF

  printf '\nlinked = that path is this repo. Edit either side, same file.\n'
  printf 'Apply a group with --link-shell / --link-git / --link-kitty / --link-i3, or --all.\n'
}

# The repo is public and tracks .zshrc. Refuse to link a shell rc that has
# secrets in it, because the next `git add` in this repo would publish them.
shell_secret_check() {
  local target="$HOME/.zshrc"
  [ -f "$target" ] || return 0
  if grep -Eq '(ghp_|github_pat_|ddpat_|cfut_|AKIA|xox[baprs]-|sk-[A-Za-z0-9]{16,})' "$target" 2>/dev/null; then
    err "$target contains what look like API tokens."
    err "This repo is public and tracks .zshrc, so linking it would stage those"
    err "tokens for commit. Move them into ~/.privatealiases first (.zshrc already"
    err "sources it when present), then re-run with --link-shell."
    return 1
  fi
  return 0
}

link_shell() {
  info "linking the shell config"

  cat <<EOF
${BOLD}Before this replaces your ~/.zshrc:${RESET}
  - your current one is backed up, not deleted
  - anything machine specific in it (PATH entries, tokens, work aliases) is
    not in this repo and will stop being loaded
  - this repo is public and tracks .zshrc; keep secrets in ~/.privatealiases
EOF

  if ! shell_secret_check; then
    warn "skipping the shell config"
    return 0
  fi

  if ! confirm "Replace ~/.zshrc and ~/.aliases with links into this repo?"; then
    warn "skipping the shell config"
    return 0
  fi

  link_group shell

  command -v zsh >/dev/null 2>&1 || warn "zsh is not installed"
  for tool in starship zoxide pet; do
    command -v "$tool" >/dev/null 2>&1 || warn ".zshrc uses $tool, which is not installed (it is guarded, so this is not fatal)"
  done
}

link_git() {
  info "linking the git config"
  if ! command -v git-lfs >/dev/null 2>&1; then
    warn "git-lfs is missing and .gitconfig sets filter.lfs.required, so LFS repos would fail to check out"
  fi
  if ! command -v delta >/dev/null 2>&1; then
    warn "delta is missing and .gitconfig sets it as the pager, so git diff would fail"
  fi
  if confirm "Replace ~/.gitconfig (user.name becomes 'Chau Giang') with a link into this repo?"; then
    link_group git
  else
    warn "skipping the git config"
  fi
}

link_kitty() {
  info "linking the kitty config"
  # The repo's kitty.conf includes a theme.conf that is not tracked, and binds
  # alt+N for tabs, which is a poor fit on macOS where alt is a compose key.
  if [ "$OS_NAME" = "macos" ]; then
    warn "this replaces macOS-friendly bindings (cmd+N tabs) with alt+N ones"
  fi
  if [ ! -f "$REPO_DIR/.config/kitty/theme.conf" ]; then
    warn "kitty.conf includes ./theme.conf, which is not in the repo; kitty will warn at startup"
  fi
  if confirm "Replace ~/.config/kitty/kitty.conf with a link into this repo?"; then
    link_group kitty
  else
    warn "skipping the kitty config"
  fi
}

link_i3() {
  if [ "$OS_NAME" = "macos" ]; then
    warn "i3 is an X11 window manager; skipping on macOS"
    return 0
  fi
  info "linking the i3 config"
  link_group i3
}

# --------------------------------------------------------------- neovim ----

nvim_data_dir() {
  # Ask nvim so this keeps working if XDG_DATA_HOME is set, but with -u NONE:
  # loading the real config on a fresh machine prints plugin-install output,
  # which would otherwise end up concatenated into the path.
  if command -v nvim >/dev/null 2>&1; then
    local dir
    dir="$(nvim --headless -u NONE --cmd 'lua io.stdout:write(vim.fn.stdpath("data"))' -c 'quit' 2>/dev/null | tr -d '\r\n')"
    case "$dir" in
      /*) echo "$dir"; return 0 ;;   # only trust an absolute path
    esac
  fi
  echo "${XDG_DATA_HOME:-$HOME/.local/share}/nvim"
}

# UltiSnips needs pynvim. Pinning the provider to its own venv means activating
# a conda env or virtualenv later cannot break it (core/globals.lua looks here).
setup_python_provider() {
  info "setting up the Neovim python3 provider"

  local data_dir venv venv_py
  data_dir="$(nvim_data_dir)"
  venv="$data_dir/venv"
  venv_py="$venv/bin/python3"

  if [ -x "$venv_py" ] && "$venv_py" -c 'import pynvim' >/dev/null 2>&1; then
    ok "provider venv already has pynvim"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry%s create venv at %s and pip install pynvim\n' "$YELLOW" "$RESET" "$venv"
    return 0
  fi

  # Homebrew's python 3.14 currently fails ensurepip, so try the candidates in
  # turn rather than assuming `python3` can build a venv.
  local candidate created=""
  for candidate in python3 /usr/bin/python3 "$HOME/miniconda3/bin/python3" /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    command -v "$candidate" >/dev/null 2>&1 || continue
    rm -rf "$venv"
    if "$candidate" -m venv "$venv" >/dev/null 2>&1 && [ -x "$venv_py" ]; then
      created="$candidate"
      break
    fi
  done

  if [ -z "$created" ]; then
    rm -rf "$venv"
    warn "could not create a python venv; UltiSnips will not work."
    warn "install a python3 with working venv support, then re-run."
    return 0
  fi

  if "$venv_py" -m pip install --quiet --upgrade pynvim >/dev/null 2>&1; then
    ok "provider venv ready ($created), pynvim installed"
  else
    warn "venv created but pynvim failed to install; UltiSnips will not work"
  fi
}

# The config used packer until it went unmaintained. Leaving its tree behind
# means those plugins stay on the runtimepath and shadow the lazy.nvim copies.
cleanup_packer() {
  local data_dir packer_dir compiled
  data_dir="$(nvim_data_dir)"
  packer_dir="$data_dir/site/pack/packer"
  compiled="$HOME/.config/nvim/plugin/packer_compiled.lua"

  if [ -d "$packer_dir" ]; then
    info "removing the old packer plugin tree"
    run rm -rf "$packer_dir"
    ok "removed $packer_dir"
  fi

  # Generated file; it lived inside the config directory, so inside the repo.
  if [ -f "$compiled" ]; then
    run rm -f "$compiled"
    ok "removed packer_compiled.lua"
  fi
}

install_plugins() {
  info "installing Neovim plugins with lazy.nvim"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry%s nvim --headless "+Lazy! sync" +qa\n' "$YELLOW" "$RESET"
    return 0
  fi

  command -v nvim >/dev/null 2>&1 || { warn "nvim is not installed, skipping plugin install"; return 0; }

  # `Lazy! sync` is the documented headless form: the bang makes it run to
  # completion instead of returning while the UI is still working.
  nvim --headless "+Lazy! sync" +qa 2>&1 | grep -vE 'is deprecated|^$' || true
  ok "plugins synced"
}

install_lsp_servers() {
  info "installing language servers"

  local pkgs=""
  command -v pylsp >/dev/null 2>&1 || pkgs="$pkgs pylsp"
  command -v gopls >/dev/null 2>&1 || pkgs="$pkgs gopls"

  if [ -n "$pkgs" ]; then
    # shellcheck disable=SC2086  # deliberate word splitting
    pkg_install $pkgs
  fi

  # apt and dnf have no gopls package; the Go toolchain can install it.
  if ! command -v gopls >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
    if command -v go >/dev/null 2>&1; then
      warn "no gopls package for $PKG_MGR, installing it with go install"
      run go install golang.org/x/tools/gopls@latest || warn "gopls install failed"
    else
      warn "gopls not installed and no Go toolchain to build it; nvim will warn about this at startup"
    fi
  fi

  # pylsp has no distro package on apt/dnf; fall back to the provider venv.
  if ! command -v pylsp >/dev/null 2>&1 && [ "$DRY_RUN" -eq 0 ]; then
    local venv_py
    venv_py="$(nvim_data_dir)/venv/bin/python3"
    if [ -x "$venv_py" ]; then
      warn "no pylsp package for $PKG_MGR, installing it into the provider venv"
      run "$venv_py" -m pip install --quiet python-lsp-server || warn "pylsp install failed"
    fi
  fi

  if command -v npm >/dev/null 2>&1; then
    if ! command -v typescript-language-server >/dev/null 2>&1; then
      run npm i -g typescript typescript-language-server
    else
      ok "typescript-language-server already installed"
    fi
  else
    warn "npm not found, skipping typescript-language-server"
  fi
}

verify() {
  info "verifying"

  if [ "$DRY_RUN" -eq 1 ]; then
    printf '%s  dry%s start nvim and report loaded plugins\n' "$YELLOW" "$RESET"
    return 0
  fi

  command -v nvim >/dev/null 2>&1 || { warn "nvim is not installed"; return 0; }

  local missing=""
  for tool in nvim rg fd fzf bat; do
    command -v "$tool" >/dev/null 2>&1 || missing="$missing $tool"
  done
  [ -z "$missing" ] || warn "not on PATH:$missing"

  # Only modules that are loaded eagerly. Lazily loaded ones (cmp, lspconfig)
  # are not on the runtimepath at startup, so requiring them proves nothing.
  # has("python3") only reports that a provider is configured, not that it
  # works, so import pynvim for real: that is what UltiSnips needs.
  nvim --headless \
    -c 'lua local mods = { "telescope.builtin", "lualine", "ibl", "nvim-tree" }
        local bad = {}
        for _, m in ipairs(mods) do if not pcall(require, m) then table.insert(bad, m) end end
        if #bad == 0 then
          print("plugins load: ok")
        else
          print("plugins FAILED to load: " .. table.concat(bad, ", "))
        end
        if pcall(vim.cmd, "py3 import pynvim") then
          print("python3 provider: ok")
        else
          print("python3 provider: BROKEN (UltiSnips will not work)")
        end' \
    -c 'quit' 2>&1 | grep -vE 'is deprecated|checkhealth' || true
}

# ------------------------------------------------------------------ main ----

main() {
  printf '%sdotfiles installer%s  (%s)\n' "$BOLD" "$RESET" "$REPO_DIR"

  if [ "$STATUS_ONLY" -eq 1 ]; then
    detect_platform
    show_status
    exit 0
  fi

  printf '\n'
  [ "$DRY_RUN" -eq 0 ] || warn "dry run, nothing will be changed"

  detect_platform
  check_prereqs

  if [ "$SKIP_DEPS" -eq 0 ]; then
    info "installing dependencies"
    local deps="neovim git curl fd fzf ripgrep bat delta node python"
    [ "$LINK_GIT" -eq 0 ] || deps="$deps git-lfs"
    # shellcheck disable=SC2086  # deliberate word splitting
    pkg_install $deps
  else
    warn "skipping dependency installation"
  fi

  info "linking the Neovim config"
  link_group nvim
  cleanup_packer
  setup_python_provider
  install_plugins

  [ "$WITH_LSP" -eq 0 ]   || install_lsp_servers
  [ "$LINK_SHELL" -eq 0 ] || link_shell
  [ "$LINK_GIT" -eq 0 ]   || link_git
  [ "$LINK_KITTY" -eq 0 ] || link_kitty
  [ "$LINK_I3" -eq 0 ]    || link_i3

  verify
  show_status

  printf '\n%sdone%s\n' "$GREEN$BOLD" "$RESET"
  if [ "$WITH_LSP" -eq 0 ]; then
    echo "Language servers were not installed; re-run with --with-lsp for pylsp, ts and gopls."
  fi
  echo "Shell and git files are opt-in: --link-shell, --link-git (see MAC.md first)."
}

main "$@"
