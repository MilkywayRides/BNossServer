# ~/.bashrc — BlazeNeuro default configuration

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# History settings
HISTCONTROL=ignoreboth
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s histappend

# Window size check
shopt -s checkwinsize

# Color prompt
if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    PS1='\[\033[01;34m\][\[\033[01;36m\]\u\[\033[01;37m\]@\[\033[01;35m\]\h\[\033[01;34m\]]\[\033[00m\] \[\033[01;33m\]\w\[\033[00m\]\n\[\033[01;36m\]❯\[\033[00m\] '
else
    PS1='[\u@\h] \w\n❯ '
fi

# Color support
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias dir='dir --color=auto'
    alias vdir='vdir --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias cls='clear'

# Enable programmable completion
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Welcome message on first terminal
if [ -z "$BLAZENEURO_WELCOMED" ]; then
    export BLAZENEURO_WELCOMED=1
    if command -v neofetch &>/dev/null; then
        neofetch
    fi
fi
