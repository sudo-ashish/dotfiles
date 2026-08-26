mkcd() {
  mkdir -p "$1" && cd "$1"
}

gitcd() {
  git clone "$@" || return
  local dir="${2:-$(basename "$1" .git)}"
  cd "$dir" || return
}

gctmp() {
  cd /tmp || return
  git clone "$@" || return
  local dir="${2:-$(basename "$1" .git)}"
  cd "$dir" || return
}
