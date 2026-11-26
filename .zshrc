# load zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git python colored-man-pages zsh-syntax-highlighting zsh-autosuggestions zsh-fzf-history-search zsh-autocomplete)

source $ZSH/oh-my-zsh.sh

## load pk10
[[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]] && source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

##
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/root/.local/bin
export LANG=en_US.UTF-8
export UV_LINK_MODE=copy

## Alias
alias q="exit"
alias c="clear"

alias unzsh="bash ~/.oh-my-zsh/tools/uninstall.sh"
alias AU="apt update -y --fix-missing && apt upgrade -y"
alias AI="apt install -y "
alias AR="apt remove -y "


alias vsource="source ~/.venv/bin/activate"

alias gclone="git clone --depth=1 --filter=blob:none"


##

. "$HOME/.local/bin/env"

