# File system
if command -v eza &> /dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='eza -lha --group-directories-first --icons=auto'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi

alias ff="fzf --preview 'bat --style=numbers --color=always {} 2>/dev/null || cat {}'"
alias eff='file=$(ff) && [ -n "$file" ] && ${EDITOR:-nvim} "$file"'

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git
alias gs='git status'
alias ga='git add .'
alias gpull='git pull'
alias gpush='git push'
alias gcl='git clone'
alias g='git'
alias gc='git commit -m'

#package mgr - pacman
alias pcy='sudo pacman -S'
alias pcs='pacman -Ss'
alias pcr='pacman -Rns'
alias pcq='pacman -Q'

#package mgr - yay
alias yy='yay -S'
alias ys='yay -Ss'
alias yr='yay -Rns'
alias yq='yay -Q'

#package mgr - paru
alias pry='paru -S'
alias prs='paru -Ss'
alias prr='paru -Rns'
alias prq='paru -Q'
