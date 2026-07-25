# Created by newuser for 5.9

# Homebrew is not on the default PATH on macOS, and everything below (starship,
# zoxide, nvim, ...) is installed through it.
if [[ "$OSTYPE" == darwin* ]]; then
  for brew_prefix in /opt/homebrew /usr/local; do
    [ -x "$brew_prefix/bin/brew" ] && eval "$("$brew_prefix/bin/brew" shellenv)" && break
  done
fi

command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# ibus is the Linux/X11 input method; macOS has its own and has no ibus-daemon.
if [[ "$OSTYPE" == linux* ]]; then
  export GTK_IM_MODULE=ibus
  export XMODIFIERS=@im=ibus
  export QT_IM_MODULE=ibus
  command -v ibus-daemon >/dev/null 2>&1 && ibus-daemon -drx
fi


HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt appendhistory
# Avoid duplicates
HISTCONTROL=ignoredups:erasedups # Ubuntu default is ignoreboth
# When the shell exits, append to the history file instead of overwriting it

# After each command, append to the history file and reread it
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND$'\n'}history -a; history -c; history -r"

export VISUAL=nvim
export EDITOR="$VISUAL"

zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# conda lives in a different prefix per machine (/opt on Arch, ~/miniconda3 on
# this Mac), so probe instead of hardcoding one path.
for conda_prefix in /opt/miniconda3 "$HOME/miniconda3" /opt/homebrew/Caskroom/miniconda/base; do
  if [ -f "$conda_prefix/etc/profile.d/conda.sh" ]; then
    source "$conda_prefix/etc/profile.d/conda.sh"
    break
  fi
done
unset conda_prefix

source ~/.aliases
[ -f ~/.privatealiases ] && source ~/.privatealiases

function pet-select() {
  BUFFER=$(pet search --query "$LBUFFER")
  CURSOR=$#BUFFER
  zle redisplay
}
zle -N pet-select
stty -ixon
bindkey '^s' pet-select
bindkey '^R' history-incremental-search-backward

bindkey -e

export NPM_CONFIG_PREFIX=~/.npm-global
export LOCALBIN="$HOME/.local/bin"
export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
# /usr/lib/go is the Arch layout; Homebrew keeps it under its own prefix.
if command -v go >/dev/null 2>&1; then
  export GOROOT="$(go env GOROOT)"
elif [ -d /usr/lib/go ]; then
  export GOROOT="/usr/lib/go"
fi
export PATH="$PATH:$LOCALBIN:$GOBIN:${GOROOT:+$GOROOT/bin:}$NPM_CONFIG_PREFIX/bin"

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search


bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word

plugins=(git)
export ZSH="$HOME/.oh-my-zsh"
. $ZSH/oh-my-zsh.sh



### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### End of Zinit's installer chunk

[ -f ~/.aws-fzf ] && source ~/.aws-fzf

function zle-keymap-select zle-line-init zle-line-finish
{
  case $KEYMAP in
      vicmd)      print -n '\033[1 q';; # block cursor
      viins|main) print -n '\033[5 q';; # line cursor
  esac
}

zle -N zle-line-init
zle -N zle-line-finish
zle -N zle-keymap-select

# User Space + Tab to select your folder
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
autoload -U compinit
compinit
fpath=($fpath ~/.zsh/completion)


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
# $HOME instead of the hardcoded /home/kai this was generated with, so it also
# resolves on macOS (/Users/kai).
__conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        . "$HOME/miniconda3/etc/profile.d/conda.sh"
    else
        [ -d "$HOME/miniconda3/bin" ] && export PATH="$HOME/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# Overriding TERM breaks colours, keys and clear in terminals that are not
# actually rxvt (Terminal.app, iTerm2, kitty), and follows you over ssh/tmux.
# Only set it if the terminfo entry exists and the terminal did not say better.
if [[ -z "$TERM_PROGRAM" ]] && [[ "$TERM" == "xterm" ]] && infocmp rxvt >/dev/null 2>&1; then
  export TERM=rxvt
fi

# Machine-local config goes in drop-ins, not in this file. Everything matching
# ~/.zshrc.d/*.zsh is sourced in name order, last, so it can override anything
# above. Adding local config is then a new file rather than an edit to this
# tracked one, which is what keeps this file mergeable across machines.
#
#   ~/.zshrc.d/00-path.zsh     PATH entries
#   ~/.zshrc.d/50-work.zsh     work aliases, project helpers
#   ~/.zshrc.d/90-secrets.zsh  tokens (chmod 600)
#
# Nothing under ~/.zshrc.d is tracked. That, plus ~/.privatealiases above, is
# what makes this file safe to symlink out of a public repo.
#
# (N) is the null_glob qualifier: expand to nothing rather than erroring when
# the directory is empty or absent.
for _zshrc_d in ~/.zshrc.d/*.zsh(N); do
  source "$_zshrc_d"
done
unset _zshrc_d

