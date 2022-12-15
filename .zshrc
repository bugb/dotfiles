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

export PATH="$PATH:/home/$USER/.local/bin"
export NPM_CONFIG_PREFIX=~/.npm-global
export PATH=$PATH:~/.npm-global/bin

export GOPATH="$HOME/go"
export GOBIN="$HOME/go/bin"
export GOROOT="/usr/lib/go"
export PATH="$PATH:$GOBIN:$GOROOT/bin"

autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search


bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
