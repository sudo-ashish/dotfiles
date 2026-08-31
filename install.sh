#!/usr/bin/env bash
# Install this repository's Arch Linux dotfiles.
# Run as a normal user: ./install.sh

set -Eeuo pipefail
IFS=$'\n\t'

# -----------------------------------------------------------------------------
# Editable package and font definitions
# -----------------------------------------------------------------------------
core_packages=(
  impala
  bluetui
  btop
  hyprland
  hyprshot
  hyprlock
  qt5-wayland
  qt6-wayland
  polkit-kde-agent
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
  awww
  swayosd
  nautilus
  wl-clipboard
  kitty
  neovim
  rofi
  brightnessctl
  jq
  swaync
  waybar
  zsh
)

# Font families used by the repository and available from Arch's official repos.
pacman_fonts=(
  ttf-jetbrains-mono-nerd # JetBrainsMono Nerd Font (kitty, hyprlock, rofi, swaync, waybar)
  ttf-cascadia-code-nerd  # CaskaydiaCove Nerd Font (swaync)
  ttf-iosevka-nerd        # Iosevka Nerd Font (rofi launcher type 2)
  noto-fonts-cjk          # Noto Sans CJK JP/KR (waybar fallback)
)

# Font families used by the repository that are currently supplied through AUR.
aur_fonts=(
  ttf-rubik-vf # Rubik (waybar)
)

# Fontconfig family|download URL|repository files that use it.
download_fonts=(
  'Deutschlander|https://dl.dafont.com/dl/?f=deutschlander|hypr/hyprlock.conf'
)

# Fontconfig family|repository fonts/ subpath|repository files that use it.
# These font files ship inside this repository (fonts/) and are copied
# directly to the user's local font directory — no download, no AUR.
bundled_fonts=(
  'feather|Icomoon-Feather.ttf|rofi/powermenu/type-1/style-*.rasi and type-2/style.rasi'
)

# Repository directory -> destination directory below ~/.config.  The zsh
# directory is installed as ~/.config/zsh; this script never modifies ~/.zshrc.
config_sources=(hypr kitty rofi swaync waybar zsh)
config_destinations=(hypr kitty rofi swaync waybar zsh)

# -----------------------------------------------------------------------------
# Runtime state
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
TEMP_DIR=''
yay_available=false

apps_installed=()
apps_present=()
apps_skipped=()
fonts_pacman_installed=()
fonts_pacman_present=()
fonts_aur_installed=()
fonts_aur_present=()
manual_fonts_needed=()
configs_installed=()
configs_present=()
configs_skipped=()
backups_created=()
configs_backed_up=()

if [[ -t 1 ]]; then
  C_OK=$'\033[0;32m'
  C_INFO=$'\033[0;36m'
  C_WARN=$'\033[0;33m'
  C_ERROR=$'\033[0;31m'
  C_RESET=$'\033[0m'
else
  C_OK='' C_INFO='' C_WARN='' C_ERROR='' C_RESET=''
fi

cleanup() {
  if [[ -n ${TEMP_DIR} && -d ${TEMP_DIR} && ${TEMP_DIR} == /tmp/* ]]; then
    rm -rf -- "${TEMP_DIR}"
  fi
}
trap cleanup EXIT

ok() { printf '%s[OK]%s %s\n' "${C_OK}" "${C_RESET}" "$*"; }
info() { printf '%s[INFO]%s %s\n' "${C_INFO}" "${C_RESET}" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "${C_WARN}" "${C_RESET}" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "${C_ERROR}" "${C_RESET}" "$*" >&2; }
skip() { printf '[SKIP] %s\n' "$*"; }
heading() { printf '\n==> %s\n' "$*"; }

is_installed() {
  # pacman -Q returns non-zero for a package that is not installed; that is an
  # expected result, so it is deliberately used in a conditional.
  pacman -Q "$1" &>/dev/null
}

confirm() {
  local prompt=$1 answer

  while true; do
    printf '%s [Y/n]: ' "${prompt}"
    if ! IFS= read -r answer; then
      printf '\n'
      return 1
    fi

    case ${answer,,} in
    '' | y | yes) return 0 ;;
    n | no) return 1 ;;
    *) warn 'Please answer yes or no.' ;;
    esac
  done
}

confirm_strict() {
  local prompt=$1 answer

  while true; do
    printf '%s [y/n]: ' "${prompt}"
    if ! IFS= read -r answer; then
      printf '\n'
      return 1
    fi

    case ${answer,,} in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) warn 'Please answer y or n.' ;;
    esac
  done
}

print_items() {
  local item
  for item in "$@"; do
    printf '  %s\n' "${item}"
  done
}

collect_missing_packages() {
  local input_name=$1 output_name=$2 package
  local -n input_ref=${input_name}
  local -n output_ref=${output_name}

  output_ref=()
  for package in "${input_ref[@]}"; do
    if ! is_installed "${package}"; then
      output_ref+=("${package}")
    fi
  done
}

install_pacman_packages() {
  local description=$1
  shift
  local -a packages=("$@")

  ((${#packages[@]})) || return 0

  info "Installing ${description}: ${packages[*]}"
  if ! sudo pacman -S --needed "${packages[@]}"; then
    error "Failed to install ${description}."
    return 1
  fi
}

install_yay() {
  local -a prerequisites=(git base-devel)
  local -a missing_prerequisites=()

  if command -v yay &>/dev/null; then
    ok 'yay already installed'
    return 0
  fi

  collect_missing_packages prerequisites missing_prerequisites
  if ((${#missing_prerequisites[@]})); then
    info 'Installing the missing yay build prerequisites:'
    print_items "${missing_prerequisites[@]}"
    if ! install_pacman_packages 'yay build prerequisites' "${missing_prerequisites[@]}"; then
      return 1
    fi
  fi

  TEMP_DIR="$(mktemp -d /tmp/dotfile-yay.XXXXXX)"
  info "Building yay in temporary directory ${TEMP_DIR}"
  if ! git clone https://aur.archlinux.org/yay.git "${TEMP_DIR}/yay"; then
    error 'Failed to clone yay from the AUR.'
    return 1
  fi

  # makepkg refuses to run as root.  This script has already refused root, and
  # makepkg requests sudo itself only for the final package installation.
  if ! (
    cd -- "${TEMP_DIR}/yay"
    makepkg -si
  ); then
    error 'yay installation failed.'
    return 1
  fi

  if ! command -v yay &>/dev/null; then
    error 'yay was built but is not available on PATH.'
    return 1
  fi

  ok 'yay installed'
}

install_aur_packages() {
  local -a packages=("$@")

  ((${#packages[@]})) || return 0
  if ! command -v yay &>/dev/null; then
    error 'yay is not available; cannot install AUR fonts.'
    return 1
  fi

  info "Installing AUR fonts: ${packages[*]}"
  if ! yay -S --needed --noconfirm "${packages[@]}"; then
    error 'Failed to install required AUR fonts.'
    return 1
  fi
}

aur_font_manual_note() {
  case $1 in
  ttf-rubik-vf)
    printf '%s\n' 'Rubik (AUR package: ttf-rubik-vf) -> waybar/style.css'
    ;;
  *)
    printf '%s\n' "$1 (AUR package)"
    ;;
  esac
}

mark_aur_fonts_manual() {
  local package
  for package in "$@"; do
    manual_fonts_needed+=("$(aur_font_manual_note "${package}")")
  done
}

font_family_available() {
  local family=$1

  command -v fc-list &>/dev/null || return 1
  # Fontconfig separates alternate family names with commas.  Exact matching
  # prevents a fallback font from being mistaken for the requested family.
  fc-list : family 2>/dev/null | tr ',' '\n' | grep -Fxi -- "${family}" &>/dev/null
}

install_downloaded_fonts() {
  local entry family url usage font_directory archive extract_directory file_list font_file
  local entry_number=0 workspace_ready=false installed_any=false
  local -a font_files=()

  ((${#download_fonts[@]})) || return 0

  if ! command -v unzip &>/dev/null; then
    warn 'unzip is not available; downloaded fonts must be installed manually.'
    for entry in "${download_fonts[@]}"; do
      IFS='|' read -r family url usage <<<"${entry}"
      manual_fonts_needed+=("${family} -> ${usage} (unzip is not installed)")
    done
    return 0
  fi

  font_directory="${HOME}/.local/share/fonts"
  for entry in "${download_fonts[@]}"; do
    IFS='|' read -r family url usage <<<"${entry}"
    if font_family_available "${family}"; then
      ok "${family} is available"
      continue
    fi

    if [[ ${workspace_ready} != true ]]; then
      if ! TEMP_DIR="$(mktemp -d /tmp/dotfile-font.XXXXXX)"; then
        error "Could not create a temporary directory for ${family}."
        manual_fonts_needed+=("${family} -> ${usage} (temporary directory creation failed)")
        continue
      fi
      workspace_ready=true
    fi

    entry_number=$((entry_number + 1))
    archive="${TEMP_DIR}/font-${entry_number}.zip"
    extract_directory="${TEMP_DIR}/font-${entry_number}"
    file_list="${TEMP_DIR}/font-${entry_number}.files"
    if ! mkdir -p -- "${extract_directory}"; then
      error "Could not prepare the extraction directory for ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (extraction directory creation failed)")
      continue
    fi

    info "Downloading ${family}"
    if ! curl -fsSL -o "${archive}" -- "${url}"; then
      error "Failed to download ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (download failed)")
      continue
    fi

    if ! unzip -q "${archive}" -d "${extract_directory}"; then
      error "Failed to extract ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (zip extraction failed)")
      continue
    fi

    if ! find "${extract_directory}" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -print0 >"${file_list}"; then
      error "Could not find extracted font files for ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (font file search failed)")
      continue
    fi

    font_files=()
    while IFS= read -r -d '' font_file; do
      font_files+=("${font_file}")
    done <"${file_list}"
    if !((${#font_files[@]})); then
      error "No TTF or OTF files were found for ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (no TTF or OTF files found)")
      continue
    fi

    if ! mkdir -p -- "${font_directory}"; then
      error "Could not create ${font_directory}."
      manual_fonts_needed+=("${family} -> ${usage} (font directory creation failed)")
      continue
    fi

    if ! cp -- "${font_files[@]}" "${font_directory}/"; then
      error "Failed to install ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (font copy failed)")
      continue
    fi

    ok "Installed ${family} to ${font_directory}"
    installed_any=true
  done

  if [[ ${installed_any} == true ]] && command -v fc-cache &>/dev/null; then
    if ! fc-cache -f "${font_directory}"; then
      warn "Failed to refresh the font cache for ${font_directory}."
    fi
  fi
}

install_bundled_fonts() {
  local entry family filename usage font_directory source_file
  local installed_any=false

  ((${#bundled_fonts[@]})) || return 0

  font_directory="${HOME}/.local/share/fonts"
  for entry in "${bundled_fonts[@]}"; do
    IFS='|' read -r family filename usage <<<"${entry}"
    if font_family_available "${family}"; then
      ok "${family} is available"
      continue
    fi

    source_file="${SCRIPT_DIR}/fonts/${filename}"
    if [[ ! -f ${source_file} ]]; then
      error "Font file for ${family} is missing from the repository."
      manual_fonts_needed+=("${family} -> ${usage} (font file missing from repo)")
      continue
    fi

    if ! mkdir -p -- "${font_directory}"; then
      error "Could not create ${font_directory}."
      manual_fonts_needed+=("${family} -> ${usage} (font directory creation failed)")
      continue
    fi

    if ! cp -- "${source_file}" "${font_directory}/"; then
      error "Failed to install ${family}."
      manual_fonts_needed+=("${family} -> ${usage} (font copy failed)")
      continue
    fi

    ok "Installed ${family} to ${font_directory}"
    installed_any=true
  done

  if [[ ${installed_any} == true ]] && command -v fc-cache &>/dev/null; then
    if ! fc-cache -f "${font_directory}"; then
      warn "Failed to refresh the font cache for ${font_directory}."
    fi
  fi
}

directories_match() {
  local source=$1 destination=$2
  [[ -d ${destination} ]] && diff -qr -- "${source}" "${destination}" &>/dev/null
}

source_tree_matches() {
  local source_root=$1 destination_root=$2 source_path relative destination_path

  [[ -d ${destination_root} ]] || return 1
  while IFS= read -r -d '' source_path; do
    relative=${source_path#"${source_root}/"}
    destination_path="${destination_root}/${relative}"
    if [[ -L ${source_path} ]]; then
      [[ -L ${destination_path} ]] || return 1
      [[ $(readlink -- "${source_path}") == $(readlink -- "${destination_path}") ]] || return 1
    elif [[ -d ${source_path} ]]; then
      [[ -d ${destination_path} && ! -L ${destination_path} ]] || return 1
    elif [[ -f ${source_path} ]]; then
      [[ -f ${destination_path} && ! -L ${destination_path} ]] || return 1
      cmp -s -- "${source_path}" "${destination_path}" || return 1
    else
      return 1
    fi
  done < <(find "${source_root}" -mindepth 1 -print0)
}

check_core_packages() {
  local package
  local -a missing=()

  heading 'Checking required applications'
  for package in "${core_packages[@]}"; do
    if is_installed "${package}"; then
      ok "${package} already installed"
      apps_present+=("${package}")
    else
      printf '[MISSING] %s\n' "${package}"
      missing+=("${package}")
    fi
  done

  if !((${#missing[@]})); then
    info 'All required packages are already installed.'
    return 0
  fi

  printf 'The following packages are missing:\n'
  print_items "${missing[@]}"
  if install_pacman_packages 'required applications' "${missing[@]}"; then
    apps_installed+=("${missing[@]}")
  else
    apps_skipped+=("${missing[@]}")
    return 1
  fi
}

check_pacman_fonts() {
  local package
  local -a missing=()

  heading 'Checking official repository fonts'
  for package in "${pacman_fonts[@]}"; do
    if is_installed "${package}"; then
      ok "${package} already installed"
      fonts_pacman_present+=("${package}")
    else
      printf '[MISSING] %s\n' "${package}"
      missing+=("${package}")
    fi
  done

  if !((${#missing[@]})); then
    info 'All required official repository fonts are already installed.'
    return 0
  fi

  info 'The following official repository fonts are missing:'
  print_items "${missing[@]}"
  if install_pacman_packages 'official repository fonts' "${missing[@]}"; then
    fonts_pacman_installed+=("${missing[@]}")
  else
    warn 'Skipping the remaining official-font installation after the failure.'
  fi
}

check_yay() {
  heading 'Checking AUR helper'
  if command -v yay &>/dev/null; then
    yay_available=true
    ok 'yay already installed'
    return 0
  fi

  printf 'yay is not installed.\n'
  if install_yay; then
    yay_available=true
  else
    warn 'yay installation failed; AUR packages will be listed for manual installation if needed.'
  fi
}

check_aur_fonts() {
  local package
  local -a missing=()

  heading 'Checking AUR fonts'
  for package in "${aur_fonts[@]}"; do
    if is_installed "${package}"; then
      ok "${package} already installed"
      fonts_aur_present+=("${package}")
    else
      printf '[MISSING] %s\n' "${package}"
      missing+=("${package}")
    fi
  done

  ((${#missing[@]})) || {
    info 'All required AUR fonts are already installed.'
    return 0
  }

  if [[ ${yay_available} != true ]]; then
    warn 'yay is unavailable; AUR fonts must be installed manually.'
    mark_aur_fonts_manual "${missing[@]}"
    return 0
  fi

  if install_aur_packages "${missing[@]}"; then
    fonts_aur_installed+=("${missing[@]}")
  else
    warn 'AUR font installation failed; install these packages manually.'
    mark_aur_fonts_manual "${missing[@]}"
  fi
}

setup_sddm() {
  heading 'Display Manager'
  if ! confirm_strict 'Install and enable sddm as your display manager?'; then
    info 'sddm setup was skipped.'
    return 0
  fi

  if ! is_installed sddm; then
    if ! install_pacman_packages 'sddm' sddm; then
      error 'sddm installation failed; it was not enabled.'
      return 1
    fi
  fi

  if ! sudo systemctl enable sddm; then
    error 'Failed to enable sddm.'
    return 1
  fi

  ok 'sddm is enabled.'
}

install_dotfiles() {
  local index source destination label timestamp backup_root
  local -a pending_indices=()
  local -a backup_indices=()

  heading 'Installing dotfiles'
  for index in "${!config_sources[@]}"; do
    source="${SCRIPT_DIR}/${config_sources[index]}"
    destination="${HOME}/.config/${config_destinations[index]}"
    label=${config_destinations[index]}

    if [[ ! -d ${source} ]]; then
      skip "${label} config directory not found"
      configs_skipped+=("${label} (source missing)")
    elif directories_match "${source}" "${destination}"; then
      ok "${destination} already matches the repository"
      configs_present+=("${label}")
    else
      ok "Found ${label} config"
      pending_indices+=("${index}")
      if [[ -e ${destination} || -L ${destination} ]]; then
        backup_indices+=("${index}")
      fi
    fi
  done

  if !((${#pending_indices[@]})); then
    info 'All available configs already match the repository.'
    return 0
  fi

  printf 'The following configs will be installed:\n'
  for index in "${pending_indices[@]}"; do
    printf '  %s -> %s/.config/%s\n' \
      "${config_sources[index]}" "${HOME}" "${config_destinations[index]}"
  done
  if ((${#backup_indices[@]})); then
    printf 'Existing differing configs will be moved to one backup folder before installation.\n'
  fi

  if ((${#backup_indices[@]})); then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_root="${HOME}/.config/dotfile-backup-${timestamp}"
    while [[ -e ${backup_root} || -L ${backup_root} ]]; do
      timestamp="${timestamp}-1"
      backup_root="${HOME}/.config/dotfile-backup-${timestamp}"
    done

    if ! mkdir -p -- "${backup_root}"; then
      error "Could not create backup folder: ${backup_root}"
      return 1
    fi
    backups_created+=("${backup_root}")

    for index in "${backup_indices[@]}"; do
      destination="${HOME}/.config/${config_destinations[index]}"
      if ! mv -- "${destination}" "${backup_root}/${config_destinations[index]}"; then
        error "Could not move ${destination} into the backup folder."
        return 1
      fi
      configs_backed_up+=("${config_destinations[index]}")
      ok "Moved existing ${config_destinations[index]} config to ${backup_root}"
    done
  fi

  for index in "${pending_indices[@]}"; do
    source="${SCRIPT_DIR}/${config_sources[index]}"
    destination="${HOME}/.config/${config_destinations[index]}"
    label=${config_destinations[index]}

    if ! mkdir -p -- "${destination}" || ! cp -a -- "${source}/." "${destination}/"; then
      error "Failed to install ${label} config; its previous version remains in the backup folder when applicable."
      configs_skipped+=("${label} (copy failed)")
      continue
    fi

    ok "Installed ${label} config to ${destination}"
    configs_installed+=("${label}")
  done
}

ensure_local_bin_path() {
  local path_rule='export PATH="$HOME/.local/bin:$PATH"'
  local shell_file shell_tmp first_line match_count timestamp backup

  for shell_file in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
    if [[ -e ${shell_file} || -L ${shell_file} ]]; then
      if [[ ! -f ${shell_file} ]]; then
        error "Cannot update PATH because ${shell_file} is not a regular file."
        return 1
      fi
      first_line=''
      IFS= read -r first_line <"${shell_file}" || true
      match_count="$(grep -Fxc -- "${path_rule}" "${shell_file}" || true)"
      if [[ ${first_line} == "${path_rule}" && ${match_count} -eq 1 ]]; then
        ok "${shell_file} already adds ~/.local/bin to PATH at the top"
        continue
      fi
      timestamp="$(date +%Y%m%d-%H%M%S)"
      backup="${shell_file}.bak.${timestamp}"
      while [[ -e ${backup} || -L ${backup} ]]; do
        timestamp="${timestamp}-1"
        backup="${shell_file}.bak.${timestamp}"
      done
      if ! cp -aT -- "${shell_file}" "${backup}"; then
        error "Could not back up ${shell_file}."
        return 1
      fi
      backups_created+=("${backup}")
      if ! shell_tmp="$(mktemp "${shell_file}.tmp.XXXXXX")"; then
        error "Could not stage the PATH update for ${shell_file}."
        return 1
      fi
      if ! printf '%s\n' "${path_rule}" >"${shell_tmp}"; then
        rm -f -- "${shell_tmp}"
        error "Could not stage the PATH rule for ${shell_file}."
        return 1
      fi
      grep -Fvx -- "${path_rule}" "${shell_file}" >>"${shell_tmp}" || true
      if ! command cat -- "${shell_tmp}" >"${shell_file}"; then
        rm -f -- "${shell_tmp}"
        error "Could not add ~/.local/bin to PATH in ${shell_file}."
        return 1
      fi
      rm -f -- "${shell_tmp}"
    elif ! printf '%s\n' "${path_rule}" >"${shell_file}"; then
      error "Could not create ${shell_file}."
      return 1
    fi
    ok "Added ~/.local/bin to PATH at the top of ${shell_file}"
  done
}

install_theme_switcher() {
  local themes_source="${SCRIPT_DIR}/themes"
  local themes_destination="${HOME}/.config/themes"
  local bin_source="${SCRIPT_DIR}/bin"
  local bin_destination="${HOME}/.local/bin"
  local setup_script="${HOME}/.local/bin/theme-switch-setup"
  local script_name source destination script_tmp timestamp backup
  local -a scripts=(theme-switch theme-switch-setup)

  heading 'Installing theme switcher'
  if [[ ! -d ${themes_source} ]]; then
    error "Theme source directory is missing: ${themes_source}"
    return 1
  fi
  for script_name in "${scripts[@]}"; do
    if [[ ! -f ${bin_source}/${script_name} ]]; then
      error "Theme-switcher script is missing: ${bin_source}/${script_name}"
      return 1
    fi
  done

  if source_tree_matches "${themes_source}" "${themes_destination}"; then
    ok "${themes_destination} already contains the repository themes"
    configs_present+=(themes)
  else
    if [[ -e ${themes_destination} || -L ${themes_destination} ]]; then
      if [[ ! -d ${themes_destination} || -L ${themes_destination} ]]; then
        error "Cannot install themes because ${themes_destination} is not a directory."
        return 1
      fi
      timestamp="$(date +%Y%m%d-%H%M%S)"
      backup="${themes_destination}.bak.${timestamp}"
      while [[ -e ${backup} || -L ${backup} ]]; do
        timestamp="${timestamp}-1"
        backup="${themes_destination}.bak.${timestamp}"
      done
      if ! cp -aT -- "${themes_destination}" "${backup}"; then
        error "Could not back up ${themes_destination}."
        return 1
      fi
      backups_created+=("${backup}")
      configs_backed_up+=(themes)
    elif ! mkdir -p -- "${themes_destination}"; then
      error "Could not create ${themes_destination}."
      return 1
    fi

    if ! cp -a -- "${themes_source}/." "${themes_destination}/"; then
      error "Failed to copy themes to ${themes_destination}."
      return 1
    fi
    ok "Installed themes to ${themes_destination}"
    configs_installed+=(themes)
  fi

  if ! mkdir -p -- "${bin_destination}"; then
    error "Could not create ${bin_destination}."
    return 1
  fi
  for script_name in "${scripts[@]}"; do
    source="${bin_source}/${script_name}"
    destination="${bin_destination}/${script_name}"
    if [[ -f ${destination} && ! -L ${destination} && -x ${destination} ]] &&
      cmp -s -- "${source}" "${destination}"; then
      ok "${destination} already matches the repository"
      continue
    fi

    if ! script_tmp="$(mktemp "${bin_destination}/.${script_name}.XXXXXX")"; then
      error "Could not stage ${destination}."
      return 1
    fi
    if ! cp -aT -- "${source}" "${script_tmp}" ||
      ! mv -fT -- "${script_tmp}" "${destination}"; then
      rm -f -- "${script_tmp}"
      error "Failed to install ${destination}."
      return 1
    fi
    ok "Installed ${destination}"
  done

  ensure_local_bin_path || return 1
  if ! "${setup_script}"; then
    error 'Theme-switcher initial setup failed.'
    return 1
  fi
  ok 'Theme-switcher initial setup completed.'
}

install_backgrounds() {
  local source destination timestamp backup_root

  heading 'Installing backgrounds'
  if ! command -v xdg-user-dirs-update &>/dev/null; then
    warn 'xdg-user-dirs-update is not installed; the Pictures directory location cannot be guaranteed.'
  elif ! xdg-user-dirs-update; then
    warn 'xdg-user-dirs-update failed; using ~/Pictures.'
  fi

  source="${SCRIPT_DIR}/Background"
  destination="${HOME}/Pictures/Background"
  if [[ ! -d ${source} ]]; then
    skip 'Background directory not found'
    return 0
  fi

  if directories_match "${source}" "${destination}"; then
    ok "${destination} already matches the repository"
    return 0
  fi

  if [[ -e ${destination} || -L ${destination} ]]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_root="${HOME}/Pictures/Background-backup-${timestamp}"
    while [[ -e ${backup_root} || -L ${backup_root} ]]; do
      timestamp="${timestamp}-1"
      backup_root="${HOME}/Pictures/Background-backup-${timestamp}"
    done

    if ! mv -- "${destination}" "${backup_root}"; then
      error "Could not move ${destination} to the backup folder."
      return 1
    fi
    ok "Backed up existing Background folder to ${backup_root}"
  fi

  if ! mkdir -p -- "${HOME}/Pictures"; then
    error "Could not create ${HOME}/Pictures."
    return 1
  fi

  if ! cp -a -- "${source}/." "${destination}/"; then
    error "Failed to install backgrounds to ${destination}."
    return 1
  fi

  ok "Installed backgrounds to ${destination}"
}

install_lazyvim() {
  heading 'Installing LazyVim'
  if ! mkdir -p -- "${HOME}/.config"; then
    error "Could not create ${HOME}/.config."
    return 1
  fi

  if [[ -e ${HOME}/.config/nvim || -L ${HOME}/.config/nvim ]]; then
    ok 'An nvim config already exists; leaving it unchanged.'
    return 0
  fi

  info 'Cloning the LazyVim starter config.'
  if ! git clone https://github.com/LazyVim/starter "${HOME}/.config/nvim"; then
    error 'Failed to clone the LazyVim starter config.'
    return 1
  fi

  if ! rm -rf -- "${HOME}/.config/nvim/.git"; then
    error 'Failed to remove the LazyVim starter Git metadata.'
    return 1
  fi

  ok "Installed LazyVim to ${HOME}/.config/nvim"
}

install_nvim_plugins() {
  if [[ ! -d ${SCRIPT_DIR}/nvim/plugins ]]; then
    skip 'nvim plugins directory not found'
    return 0
  fi

  if directories_match "${SCRIPT_DIR}/nvim/plugins" "${HOME}/.config/nvim/lua/plugins"; then
    ok "${HOME}/.config/nvim/lua/plugins already matches the repository"
    return 0
  fi

  if ! mkdir -p -- "${HOME}/.config/nvim/lua"; then
    error "Could not create ${HOME}/.config/nvim/lua."
    return 1
  fi

  if ! cp -a -- "${SCRIPT_DIR}/nvim/plugins" "${HOME}/.config/nvim/lua/"; then
    error "Failed to install nvim plugins to ${HOME}/.config/nvim/lua/plugins."
    return 1
  fi

  ok "Installed nvim plugins to ${HOME}/.config/nvim/lua/plugins"
}

apply_theme() {
  local theme_switch_bin="${HOME}/.local/bin/theme-switch"

  heading 'Applying Theme'
  if [[ ! -x ${theme_switch_bin} ]]; then
    warn 'theme-switch is not installed; the theme was not applied.'
    return 0
  fi

  if ! "${theme_switch_bin}" gruvbox; then
    warn 'theme-switch exited with an error.'
  fi
  return 0
}

summary_list() {
  local title=$1
  shift
  local -a entries=("$@")

  printf '%s\n' "${title}"
  if ((${#entries[@]})); then
    print_items "${entries[@]}"
  else
    printf '  None\n'
  fi
}

print_summary() {
  heading 'Installation Summary'
  printf '%s\n' '=================================================='
  summary_list 'Applications installed:' "${apps_installed[@]}"
  summary_list 'Applications already installed:' "${apps_present[@]}"
  summary_list 'Applications not installed:' "${apps_skipped[@]}"
  summary_list 'Fonts installed with pacman:' "${fonts_pacman_installed[@]}"
  summary_list 'Fonts already installed with pacman:' "${fonts_pacman_present[@]}"
  summary_list 'Fonts installed with yay:' "${fonts_aur_installed[@]}"
  summary_list 'Fonts already installed with yay:' "${fonts_aur_present[@]}"
  summary_list 'Configs installed:' "${configs_installed[@]}"
  summary_list 'Configs already matching the repository:' "${configs_present[@]}"
  summary_list 'Configs skipped:' "${configs_skipped[@]}"
  summary_list 'Backups created:' "${backups_created[@]}"
  summary_list 'Configs moved into backup:' "${configs_backed_up[@]}"

  printf '\n%s\n' '=================================================='
  printf '%s\n' 'Manual Font Installation Required'
  printf '%s\n' '=================================================='
  if ((${#manual_fonts_needed[@]})); then
    printf '%s\n' 'The following fonts could not be installed automatically:'
    print_items "${manual_fonts_needed[@]}"
  else
    printf '%s\n' 'Manual font installation required:'
    printf '  None\n'
  fi
}

main() {
  if [[ ${EUID} -eq 0 ]]; then
    error 'Do not run this installer as root. Run it as your normal user; it requests sudo only for pacman.'
    exit 1
  fi

  if ! command -v pacman &>/dev/null || [[ ! -f /etc/arch-release ]]; then
    error 'This installer requires Arch Linux (pacman and /etc/arch-release were not both found).'
    exit 1
  fi

  info "Repository: ${SCRIPT_DIR}"
  check_core_packages || warn 'One or more required applications could not be installed.'
  check_pacman_fonts
  check_yay
  check_aur_fonts
  setup_sddm || warn 'sddm setup encountered an error; sddm may not be enabled.'
  install_downloaded_fonts
  install_bundled_fonts
  install_dotfiles || warn 'Dotfile installation encountered an error; some configs may not have been installed.'
  install_theme_switcher || warn 'Theme-switcher installation or initial setup encountered an error.'
  install_backgrounds || warn 'Background installation encountered an error; backgrounds may not have been installed.'
  install_lazyvim || warn 'LazyVim installation encountered an error.'
  install_nvim_plugins || warn 'nvim plugin installation encountered an error.'
  print_summary
  apply_theme
  heading 'Restart Required'
  if confirm 'Restart the system now?'; then
    if ! sudo systemctl reboot; then
      error 'Failed to restart the system. Please restart manually.'
    fi
  else
    info 'Restart the system before using the newly installed configuration.'
  fi
}

main "$@"
