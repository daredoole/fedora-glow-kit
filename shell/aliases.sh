# shellcheck shell=bash
# Portable shell aliases for Fedora.

if command -v eza >/dev/null 2>&1; then
  alias ls='eza -l --icons=auto --git'
  alias ll='eza -la --icons=auto --git'
  alias la='eza -a --icons=auto'
  alias tree='eza --tree --icons=auto'
else
  alias ll='ls -lah'
  alias la='ls -A'
fi

if command -v bat >/dev/null 2>&1; then
  alias cat='bat --style=plain --paging=never'
fi

alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'
alias h='history'
alias df='df -h'
alias free='free -h'
alias ports='ss -tulpn'
alias path='printf "%s\n" "$PATH" | tr ":" "\n"'

alias update='glow_update'
alias cleanup='glow_cleanup'
alias pkg-search='dnf search'
alias pkg-install='sudo dnf install'
alias pkg-remove='sudo dnf remove'

alias ff='fastfetch'
alias reload='exec "$SHELL" -l'
alias zconf='${EDITOR:-nano} "$HOME/.zshrc"'
alias aliases='${EDITOR:-nano} "$HOME/.config/shell/aliases.sh"'
alias helpme='halp'
alias edit='qedit'

alias gs='git status'
alias ga='git add -A'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi

alias reboot-now='sudo reboot'
alias poweroff-now='sudo poweroff'
alias suspend-now='systemctl suspend'
alias jlog='journalctl -xe'
alias jlogf='journalctl -xe -f'
alias failed-units='systemctl --failed'
alias service-enable='sudo systemctl enable'
alias service-disable='sudo systemctl disable'
alias service-restart='sudo systemctl restart'
alias service-status='sudo systemctl status'

if command -v nvtop >/dev/null 2>&1; then
  alias gpu='nvtop'
fi

if command -v iotop >/dev/null 2>&1; then
  alias diskio='sudo iotop -oPa'
fi

if command -v sar >/dev/null 2>&1; then
  alias sysday='sar -A'
  alias sarcpu='sar -u 1 5'
fi

if command -v iostat >/dev/null 2>&1; then
  alias sario='iostat -xz 1'
fi

if command -v vdpauinfo >/dev/null 2>&1; then
  alias vdpau-check='vdpauinfo'
fi

if command -v vainfo >/dev/null 2>&1; then
  alias vaapi-check='vainfo'
fi

if command -v distrobox >/dev/null 2>&1; then
  alias dbx='distrobox'
fi

if command -v podman-compose >/dev/null 2>&1; then
  alias pc='podman-compose'
fi

if command -v just >/dev/null 2>&1; then
  alias j='just'
fi

if command -v asciiquarium >/dev/null 2>&1; then
  alias aquarium='asciiquarium'
fi

if command -v cmatrix >/dev/null 2>&1; then
  alias matrix='cmatrix -s -C cyan'
  alias matrix-rain='cmatrix -s -C green'
fi

if command -v cbonsai >/dev/null 2>&1; then
  alias bonsai='cbonsai -l -t 0.03'
  alias bonsai-fast='cbonsai'
fi

if command -v pipes.sh >/dev/null 2>&1; then
  alias pipes='pipes.sh -t 0'
  alias pipes-curved='pipes.sh -t 1'
  alias pipes-angled='pipes.sh -t 2'
fi

if command -v tty-clock >/dev/null 2>&1; then
  alias clock='tty-clock -c -C 4'
fi

if command -v nyancat >/dev/null 2>&1; then
  alias nyan='nyancat'
fi

if command -v sl >/dev/null 2>&1; then
  alias train='sl'
fi

if command -v lolcat >/dev/null 2>&1; then
  alias rainbow='lolcat'
fi

if command -v figlet >/dev/null 2>&1; then
  alias say='figlet -f slant'
fi

if command -v toilet >/dev/null 2>&1; then
  alias sayb='toilet -f future --gay'
fi

if command -v fortune >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
  alias rfortune='fortune | lolcat'
fi

if command -v fortune >/dev/null 2>&1 && command -v cowsay >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
  alias prettycow='fortune | cowsay | lolcat'
fi
