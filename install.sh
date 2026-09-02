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
  gnome-calculator
  uzip
)

# Applications supplied through the AUR. Add package names here; the installer
# skips packages already present and installs only the missing ones with yay.
aur_packages=(
  localsend-bin
  vscodium-bin
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
SUDO_KEEPALIVE_PID=''
TEMP_DIRS=()
yay_available=false

apps_installed=()
apps_present=()
apps_skipped=()
aur_apps_installed=()
aur_apps_present=()
aur_apps_skipped=()
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
  local temporary_directory

  for temporary_directory in "${TEMP_DIRS[@]}"; do
    [[ -n ${temporary_directory} && -d ${temporary_directory} ]] || continue
    case ${temporary_directory} in
    /tmp/dotfile-* | "${HOME}/.config/".dotfile-* | "${HOME}/Pictures/".dotfile-*)
      rm -rf -- "${temporary_directory}" || true
      ;;
    esac
  done

  if [[ -n ${SUDO_KEEPALIVE_PID} ]]; then
    kill "${SUDO_KEEPALIVE_PID}" &>/dev/null || true
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
    y | yes) return 0 ;;
    n | no) return 1 ;;
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
  if ! sudo pacman -S --needed --noconfirm "${packages[@]}"; then
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
  TEMP_DIRS+=("${TEMP_DIR}")
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
  local description=$1
  shift
  local -a packages=("$@")

  ((${#packages[@]})) || return 0
  if ! command -v yay &>/dev/null; then
    error "yay is not available; cannot install ${description}."
    return 1
  fi

  info "Installing ${description}: ${packages[*]}"
  if ! yay -S --needed --noconfirm "${packages[@]}"; then
    error "Failed to install ${description}."
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
      TEMP_DIRS+=("${TEMP_DIR}")
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
  [[ -d ${destination} && ! -L ${destination} ]] &&
    diff -qr -- "${source}" "${destination}" &>/dev/null
}

theme_directories_match() {
  local source=$1 destination=$2

  # current is runtime state, not repository content. Everything else must
  # match in both directions so stale or user-added files are not mistaken for
  # an exact installation.
  [[ -d ${destination} && ! -L ${destination} ]] &&
    [[ ! -e ${destination}/current || -L ${destination}/current ]] &&
    diff -qr --exclude=current -- "${source}" "${destination}" &>/dev/null
}

next_backup_path() {
  local base=$1 timestamp candidate

  timestamp="$(date +%Y%m%d-%H%M%S)"
  candidate="${base}.bak.${timestamp}"
  while [[ -e ${candidate} || -L ${candidate} ]]; do
    candidate="${candidate}-1"
  done
  printf '%s\n' "${candidate}"
}

make_staging_directory() {
  local parent=$1 label=$2 output_name=$3 staging_directory
  local -n output_ref="${output_name}"

  staging_directory="$(mktemp -d "${parent}/.dotfile-${label}.XXXXXX")" || return 1
  TEMP_DIRS+=("${staging_directory}")
  output_ref=${staging_directory}
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

check_aur_packages() {
  local package
  local -a missing=()

  heading 'Checking AUR applications'
  for package in "${aur_packages[@]}"; do
    if is_installed "${package}"; then
      ok "${package} already installed"
      aur_apps_present+=("${package}")
    else
      printf '[MISSING] %s\n' "${package}"
      missing+=("${package}")
    fi
  done

  if !((${#missing[@]})); then
    info 'All required AUR applications are already installed.'
    return 0
  fi

  printf 'The following AUR applications are missing:\n'
  print_items "${missing[@]}"
  if [[ ${yay_available} != true ]]; then
    warn 'yay is unavailable; these AUR applications were skipped.'
    aur_apps_skipped+=("${missing[@]}")
    return 0
  fi

  if install_aur_packages 'AUR applications' "${missing[@]}"; then
    aur_apps_installed+=("${missing[@]}")
  else
    aur_apps_skipped+=("${missing[@]}")
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

  if install_aur_packages 'AUR fonts' "${missing[@]}"; then
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
  local index source destination label timestamp backup_root='' staging_root
  local had_existing install_failed=false
  local -a pending_indices=()
  local -a backup_indices=()

  heading 'Installing dotfiles'
  if ! mkdir -p -- "${HOME}/.config"; then
    error "Could not create ${HOME}/.config."
    return 1
  fi

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

  if ! make_staging_directory "${HOME}/.config" configs staging_root; then
    error 'Could not create a staging directory for dotfiles.'
    return 1
  fi
  for index in "${pending_indices[@]}"; do
    source="${SCRIPT_DIR}/${config_sources[index]}"
    label=${config_destinations[index]}
    if ! cp -aT -- "${source}" "${staging_root}/${label}"; then
      error "Failed to stage the ${label} config; installed configs were not changed."
      return 1
    fi
  done

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

  fi

  for index in "${pending_indices[@]}"; do
    destination="${HOME}/.config/${config_destinations[index]}"
    label=${config_destinations[index]}
    had_existing=false

    if [[ -e ${destination} || -L ${destination} ]]; then
      if [[ -z ${backup_root} ]]; then
        error "${destination} appeared after the installation plan was prepared; leaving it unchanged."
        configs_skipped+=("${label} (destination changed)")
        install_failed=true
        continue
      fi
      if ! mv -T -- "${destination}" "${backup_root}/${label}"; then
        error "Could not move ${destination} into the backup folder."
        configs_skipped+=("${label} (backup failed)")
        install_failed=true
        continue
      fi
      had_existing=true
      ok "Moved existing ${label} config to ${backup_root}"
    fi

    if ! mv -T -- "${staging_root}/${label}" "${destination}"; then
      if [[ ${had_existing} == true ]] &&
        ! mv -T -- "${backup_root}/${label}" "${destination}"; then
        error "Failed to restore ${destination} from ${backup_root}/${label}."
      fi
      error "Failed to install ${label} config; its previous version was restored when possible."
      configs_skipped+=("${label} (install failed)")
      install_failed=true
      continue
    fi

    if [[ ${had_existing} == true ]]; then
      configs_backed_up+=("${label}")
    fi
    ok "Installed ${label} config to ${destination}"
    configs_installed+=("${label}")
  done

  rm -rf -- "${staging_root}"
  [[ ${install_failed} == false ]]
}

ensure_local_bin_path() {
  local path_rule='export PATH="$HOME/.local/bin:$PATH"'
  local shell_file shell_tmp first_line match_count backup grep_status

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
      backup="$(next_backup_path "${shell_file}")"
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
      grep_status=0
      grep -Fvx -- "${path_rule}" "${shell_file}" >>"${shell_tmp}" || grep_status=$?
      if ((grep_status > 1)); then
        rm -f -- "${shell_tmp}"
        error "Could not read ${shell_file} while staging its PATH update."
        return 1
      fi
      if ! chmod --reference="${shell_file}" "${shell_tmp}" ||
        ! mv -fT -- "${shell_tmp}" "${shell_file}"; then
        rm -f -- "${shell_tmp}"
        error "Could not add ~/.local/bin to PATH in ${shell_file}."
        return 1
      fi
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
  local script_name source destination script_tmp backup
  local themes_stage_root staged_themes current_target active_theme
  local destination_was_moved=false
  local -a scripts=(theme-switch theme-switch-setup)

  heading 'Installing theme switcher'
  if [[ ! -d ${themes_source} ]]; then
    error "Theme source directory is missing: ${themes_source}"
    return 1
  fi
  for script_name in "${scripts[@]}"; do
    if [[ ! -f ${bin_source}/${script_name} || ! -x ${bin_source}/${script_name} ]]; then
      error "Theme-switcher script is missing: ${bin_source}/${script_name}"
      return 1
    fi
  done

  if ! mkdir -p -- "${HOME}/.config"; then
    error "Could not create ${HOME}/.config."
    return 1
  fi

  if theme_directories_match "${themes_source}" "${themes_destination}"; then
    ok "${themes_destination} already exactly matches the repository themes"
    configs_present+=(themes)
  else
    if ! make_staging_directory "${HOME}/.config" theme-install themes_stage_root; then
      error 'Could not create a staging directory for themes.'
      return 1
    fi
    staged_themes="${themes_stage_root}/themes"
    if ! cp -aT -- "${themes_source}" "${staged_themes}"; then
      error 'Failed to stage the repository themes; installed themes were not changed.'
      return 1
    fi

    # Preserve runtime state only when it points at a theme that still exists
    # in the repository. Custom or stale themes remain available in the backup.
    if [[ -d ${themes_destination} && ! -L ${themes_destination} &&
      -L ${themes_destination}/current ]]; then
      current_target="$(readlink -- "${themes_destination}/current")" || {
        error "Could not read ${themes_destination}/current."
        return 1
      }
      active_theme=${current_target%/}
      active_theme=${active_theme##*/}
      if [[ -n ${active_theme} && -d ${themes_source}/${active_theme} &&
        ! -L ${themes_source}/${active_theme} ]]; then
        if ! ln -s -- "${themes_destination}/${active_theme}" "${staged_themes}/current"; then
          error 'Could not preserve the active-theme link in the staged themes.'
          return 1
        fi
      else
        warn "The active theme is not in the repository; it will remain in the themes backup."
      fi
    fi

    if [[ -e ${themes_destination} || -L ${themes_destination} ]]; then
      backup="$(next_backup_path "${themes_destination}")"
      if ! mv -T -- "${themes_destination}" "${backup}"; then
        error "Could not move ${themes_destination} to ${backup}."
        return 1
      fi
      destination_was_moved=true
      backups_created+=("${backup}")
      configs_backed_up+=(themes)
      ok "Moved existing themes to ${backup}"
    fi

    if ! mv -T -- "${staged_themes}" "${themes_destination}"; then
      if [[ ${destination_was_moved} == true ]] &&
        ! mv -T -- "${backup}" "${themes_destination}"; then
        error "Failed to restore ${themes_destination} from ${backup}."
      fi
      error 'Failed to install the staged themes; previous themes were restored when possible.'
      return 1
    fi
    rm -rf -- "${themes_stage_root}"
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
    if ! cp -aT -- "${source}" "${script_tmp}"; then
      rm -f -- "${script_tmp}"
      error "Failed to stage ${destination}."
      return 1
    fi

    backup=''
    if [[ -e ${destination} || -L ${destination} ]]; then
      backup="$(next_backup_path "${destination}")"
      if [[ -d ${destination} && ! -L ${destination} ]]; then
        if ! mv -T -- "${destination}" "${backup}"; then
          rm -f -- "${script_tmp}"
          error "Could not back up unexpected directory ${destination}."
          return 1
        fi
      elif ! cp -aT -- "${destination}" "${backup}"; then
        rm -f -- "${script_tmp}"
        error "Could not back up ${destination}."
        return 1
      fi
      backups_created+=("${backup}")
    fi

    if ! mv -fT -- "${script_tmp}" "${destination}"; then
      rm -f -- "${script_tmp}"
      if [[ -n ${backup} && -d ${backup} && ! -L ${backup} ]] &&
        ! mv -T -- "${backup}" "${destination}"; then
        error "Failed to restore ${destination} from ${backup}."
      fi
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
  local source destination timestamp backup_root='' staging_root staged_backgrounds
  local destination_was_moved=false

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

  if ! mkdir -p -- "${HOME}/Pictures"; then
    error "Could not create ${HOME}/Pictures."
    return 1
  fi
  if ! make_staging_directory "${HOME}/Pictures" background-install staging_root; then
    error 'Could not create a staging directory for backgrounds.'
    return 1
  fi
  staged_backgrounds="${staging_root}/Background"
  if ! cp -aT -- "${source}" "${staged_backgrounds}"; then
    error 'Failed to stage backgrounds; installed backgrounds were not changed.'
    return 1
  fi

  if [[ -e ${destination} || -L ${destination} ]]; then
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_root="${HOME}/Pictures/Background-backup-${timestamp}"
    while [[ -e ${backup_root} || -L ${backup_root} ]]; do
      timestamp="${timestamp}-1"
      backup_root="${HOME}/Pictures/Background-backup-${timestamp}"
    done

    if ! mv -T -- "${destination}" "${backup_root}"; then
      error "Could not move ${destination} to the backup folder."
      return 1
    fi
    destination_was_moved=true
    backups_created+=("${backup_root}")
    ok "Backed up existing Background folder to ${backup_root}"
  fi

  if ! mv -T -- "${staged_backgrounds}" "${destination}"; then
    if [[ ${destination_was_moved} == true ]] &&
      ! mv -T -- "${backup_root}" "${destination}"; then
      error "Failed to restore ${destination} from ${backup_root}."
    fi
    error "Failed to install backgrounds to ${destination}; previous backgrounds were restored when possible."
    return 1
  fi

  rm -rf -- "${staging_root}"
  ok "Installed backgrounds to ${destination}"
}

install_lazyvim() {
  local nvim_dir="${HOME}/.config/nvim"
  local lazy_config="${HOME}/.config/nvim/lua/config/lazy.lua"
  local clone_tmp

  heading 'Installing LazyVim'
  if ! mkdir -p -- "${HOME}/.config"; then
    error "Could not create ${HOME}/.config."
    return 1
  fi

  if [[ -e ${nvim_dir} || -L ${nvim_dir} ]]; then
    if [[ -f ${lazy_config} ]]; then
      ok 'An nvim config already exists; leaving it unchanged.'
      return 0
    fi

    if [[ -d ${nvim_dir} && ! -L ${nvim_dir} && ! -e ${nvim_dir}/init.lua ]]; then
      info 'An incomplete nvim config exists; adding the missing LazyVim starter files.'
      if ! clone_tmp="$(mktemp -d "${HOME}/.config/.lazyvim-starter.XXXXXX")"; then
        error 'Could not create a temporary directory for the LazyVim starter.'
        return 1
      fi
      if ! git clone https://github.com/LazyVim/starter "${clone_tmp}"; then
        rm -rf -- "${clone_tmp}"
        error 'Failed to clone the LazyVim starter config.'
        return 1
      fi
      rm -rf -- "${clone_tmp}/.git"
      if ! cp -an -- "${clone_tmp}/." "${nvim_dir}/"; then
        rm -rf -- "${clone_tmp}"
        error 'Failed to merge the missing LazyVim starter files.'
        return 1
      fi
      rm -rf -- "${clone_tmp}"
      if [[ ! -f ${lazy_config} ]]; then
        error 'The repaired nvim config is still missing lua/config/lazy.lua.'
        return 1
      fi
      ok "Repaired the incomplete LazyVim config at ${nvim_dir}"
      return 0
    fi

    ok 'An nvim config already exists; leaving it unchanged.'
    return 0
  fi

  info 'Cloning the LazyVim starter config.'
  if ! git clone https://github.com/LazyVim/starter "${nvim_dir}"; then
    error 'Failed to clone the LazyVim starter config.'
    return 1
  fi

  if ! rm -rf -- "${nvim_dir}/.git"; then
    error 'Failed to remove the LazyVim starter Git metadata.'
    return 1
  fi

  ok "Installed LazyVim to ${nvim_dir}"
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

install_lazy_nvim_plugin_manager() {
  local lazy_root="${XDG_DATA_HOME:-${HOME}/.local/share}/nvim/lazy"
  local lazy_dir="${lazy_root}/lazy.nvim"
  local lazy_entry="${lazy_dir}/lua/lazy/init.lua"
  local broken_dir=''

  if [[ ! -f ${HOME}/.config/nvim/lua/config/lazy.lua ]]; then
    skip 'LazyVim config is unavailable; lazy.nvim bootstrap skipped'
    return 0
  fi

  if [[ -f ${lazy_entry} ]]; then
    ok 'lazy.nvim is already installed'
    return 0
  fi

  if ! mkdir -p -- "${lazy_root}"; then
    error "Could not create ${lazy_root}."
    return 1
  fi

  if [[ -e ${lazy_dir} || -L ${lazy_dir} ]]; then
    broken_dir="${lazy_dir}.incomplete.$(date +%Y%m%d-%H%M%S)"
    while [[ -e ${broken_dir} || -L ${broken_dir} ]]; do
      broken_dir="${broken_dir}-1"
    done
    warn 'The lazy.nvim directory is incomplete; replacing the interrupted clone.'
    if ! mv -- "${lazy_dir}" "${broken_dir}"; then
      error 'Could not move the incomplete lazy.nvim directory aside.'
      return 1
    fi
  else
    info 'Installing lazy.nvim plugin manager.'
  fi

  if ! git clone --filter=blob:none --branch=stable \
    https://github.com/folke/lazy.nvim.git "${lazy_dir}"; then
    rm -rf -- "${lazy_dir}"
    if [[ -n ${broken_dir} ]]; then
      mv -- "${broken_dir}" "${lazy_dir}" ||
        error "Could not restore the incomplete lazy.nvim directory from ${broken_dir}."
    fi
    error 'Failed to install lazy.nvim.'
    return 1
  fi

  if [[ ! -f ${lazy_entry} ]]; then
    rm -rf -- "${lazy_dir}"
    if [[ -n ${broken_dir} ]]; then
      mv -- "${broken_dir}" "${lazy_dir}" ||
        error "Could not restore the incomplete lazy.nvim directory from ${broken_dir}."
    fi
    error 'The lazy.nvim clone completed without lua/lazy/init.lua.'
    return 1
  fi

  if [[ -n ${broken_dir} ]]; then
    rm -rf -- "${broken_dir}"
  fi
  ok "Installed lazy.nvim to ${lazy_dir}"
}

install_theme_apply_once() {
  local wrapper_path="${HOME}/.local/bin/theme-apply-once"
  local unit_dir="${HOME}/.config/systemd/user"
  local unit_path="${unit_dir}/theme-apply-once.service"

  heading 'Scheduling First-Boot Theme'
  if ! mkdir -p -- "${HOME}/.local/bin"; then
    error "Could not create ${HOME}/.local/bin."
    return 1
  fi

  if ! cat >"${wrapper_path}" <<'THEME_APPLY_ONCE_EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

theme_switch="${HOME}/.local/bin/theme-switch"
unit_name='theme-apply-once.service'
unit_path="${HOME}/.config/systemd/user/${unit_name}"
self_path="${HOME}/.local/bin/theme-apply-once"

if [[ -x ${theme_switch} ]]; then
  "${theme_switch}" gruvbox || true
fi

systemctl --user disable "${unit_name}" &>/dev/null || true
rm -f -- "${unit_path}"
rm -f -- "${self_path}"
systemctl --user daemon-reload &>/dev/null || true
THEME_APPLY_ONCE_EOF
  then
    error "Could not write ${wrapper_path}."
    return 1
  fi

  if ! chmod +x -- "${wrapper_path}"; then
    error "Could not make ${wrapper_path} executable."
    return 1
  fi

  if ! mkdir -p -- "${unit_dir}"; then
    error "Could not create ${unit_dir}."
    return 1
  fi

  if ! cat >"${unit_path}" <<'THEME_APPLY_ONCE_UNIT_EOF'
[Unit]
Description=Apply the default theme after first boot, then self-remove

[Service]
Type=oneshot
ExecStart=%h/.local/bin/theme-apply-once

[Install]
WantedBy=default.target
THEME_APPLY_ONCE_UNIT_EOF
  then
    error "Could not write ${unit_path}."
    return 1
  fi

  if ! systemctl --user daemon-reload; then
    error 'Could not reload systemd user units.'
    return 1
  fi

  if ! systemctl --user enable theme-apply-once.service; then
    error 'Could not enable theme-apply-once.service.'
    return 1
  fi

  ok 'The default theme will be applied automatically after the next restart.'
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
  summary_list 'AUR applications installed with yay:' "${aur_apps_installed[@]}"
  summary_list 'AUR applications already installed:' "${aur_apps_present[@]}"
  summary_list 'AUR applications not installed:' "${aur_apps_skipped[@]}"
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
  local theme_switcher_ready=false

  if [[ ${EUID} -eq 0 ]]; then
    error 'Do not run this installer as root. Run it as your normal user; it requests sudo only for pacman.'
    exit 1
  fi

  if ! command -v pacman &>/dev/null || [[ ! -f /etc/arch-release ]]; then
    error 'This installer requires Arch Linux (pacman and /etc/arch-release were not both found).'
    exit 1
  fi

  heading 'Restart Required'
  info 'Installation will finish with an automatic system restart.'
  if ! confirm 'Continue? The system will restart automatically when installation finishes.'; then
    info 'Nothing was changed.'
    exit 0
  fi

  info 'Requesting sudo access once, up front, for the rest of the install.'
  if ! sudo -v; then
    error 'Could not obtain sudo access; installation cannot continue.'
    exit 1
  fi
  (while kill -0 "$$" 2>/dev/null; do
    sudo -n true
    sleep 60
  done) &>/dev/null &
  SUDO_KEEPALIVE_PID=$!

  info "Repository: ${SCRIPT_DIR}"
  check_core_packages || warn 'One or more required applications could not be installed.'
  check_pacman_fonts
  check_yay
  check_aur_packages
  check_aur_fonts
  setup_sddm || warn 'sddm setup encountered an error; sddm may not be enabled.'
  install_downloaded_fonts
  install_bundled_fonts
  install_dotfiles || warn 'Dotfile installation encountered an error; some configs may not have been installed.'
  install_lazyvim || warn 'LazyVim installation encountered an error.'
  install_nvim_plugins || warn 'nvim plugin installation encountered an error.'
  install_lazy_nvim_plugin_manager || warn 'lazy.nvim installation encountered an error.'
  if install_theme_switcher; then
    theme_switcher_ready=true
  else
    warn 'Theme-switcher installation or initial setup encountered an error.'
  fi
  install_backgrounds || warn 'Background installation encountered an error; backgrounds may not have been installed.'
  print_summary
  if [[ ${theme_switcher_ready} == true ]]; then
    install_theme_apply_once || warn 'The installer continued, but first-boot theme application was not scheduled.'
  else
    warn 'Skipping first-boot theme scheduling because theme-switcher setup did not complete.'
  fi
  heading 'Restarting'
  info 'Restarting the system now.'
  if ! sudo systemctl reboot; then
    error 'Failed to restart the system automatically. Please restart manually.'
  fi
}

main "$@"
