#!/bin/zsh
# Skip if not interactive (only skip for non-interactive invocations, not sourced)
[[ $- != *i* ]] && return

# Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

# Plugins must be defined BEFORE sourcing oh-my-zsh.sh
plugins=(git docker fzf zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# FZF setup - disable ctrl-t by setting FZF_CTRL_T_COMMAND to empty string
FZF_CTRL_T_COMMAND=""
FZF_ALT_C_COMMAND=""
eval "$(fzf --zsh)"

# Unbind ctrl+t and ctrl+w so they pass to ghostty
bindkey -r "^T"
bindkey -r "^W"

# History
export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=~/.zsh_history
setopt SHARE_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt APPEND_HISTORY
setopt HIST_REDUCE_BLANKS

# Completion
autoload -Uz compinit
compinit

# Colors
export CLICOLOR=1
export LSCOLORS=ExFxCxDxBxegedabagacad

# Keybindings
bindkey "^[[A" history-beginning-search-backward
bindkey "^[[B" history-beginning-search-forward

# Aliases
[[ -f ~/.config/aliasrc ]] && source ~/.config/aliasrc

# PATH
export PATH="$HOME/.local/bin:$PATH"