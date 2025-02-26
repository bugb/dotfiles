# Created by newuser for 5.9
eval "$(starship init zsh)"

export GTK_IM_MODULE=ibus
export XMODIFIERS=@im=ibus
export QT_IM_MODULE=ibus
ibus-daemon -drx


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

[ -f /opt/miniconda3/etc/profile.d/conda.sh ] && source /opt/miniconda3/etc/profile.d/conda.sh

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
export GOROOT="/usr/lib/go"
export PATH="$PATH:$LOCALBIN:$GOBIN:$GOROOT/bin:$NPM_CONFIG_PREFIX/bin"

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
eval "$(zoxide init zsh)"
autoload -U compinit
compinit
fpath=($fpath ~/.zsh/completion)


# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/kai/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/kai/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/kai/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/kai/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export TERM=rxvt

