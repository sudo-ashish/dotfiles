#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/.config/themes/current/backgrounds/"
TYPE_DIR="$HOME/.config/rofi/wallpaper-launcher/type-2"

# ── Style selection ───────────────────────────────────────────────────────────
STYLE="style-1"

while [[ $# -gt 0 ]]; do
  case "$1" in
  --style)
    STYLE="style-$2"
    shift 2
    ;;
  *)
    shift
    ;;
  esac
done

THEME_PATH="$TYPE_DIR/${STYLE}.rasi"

if [ ! -f "$THEME_PATH" ]; then
  rofi -e "Theme not found: $THEME_PATH"
  exit 1
fi

# ── Wallpaper directory check ─────────────────────────────────────────────────
if [ ! -d "$WALLPAPERS_DIR" ]; then
  rofi -e "Directory not found: $WALLPAPERS_DIR"
  exit 1
fi

# ── Build rofi dmenu list and launch ─────────────────────────────────────────
chosen=$(find -L "$WALLPAPERS_DIR" -type f \
  \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg \
  -o -iname \*.webp -o -iname \*.gif \) | sort |
  while read -r file; do
    filename=$(basename "$file")
    echo -en "$filename\0icon\x1f${file}\n"
  done |
  rofi -dmenu -i -show-icons \
    -theme "$THEME_PATH" \
    -p "Wallpaper")

# ── Apply selected wallpaper ──────────────────────────────────────────────────
if [ -n "$chosen" ]; then
  selected_file="$WALLPAPERS_DIR/$chosen"

  if ! "$HOME/.local/bin/wallpaper-switch" "$selected_file"; then
    rofi -e "Failed to set wallpaper"
    exit 1
  fi
fi
