#!/usr/bin/env bash

WALLPAPERS_DIR="$HOME/.config/themes/current/backgrounds/"
LINK_DIR="$HOME/Pictures/Wallpaper"
LINK_PATH="$LINK_DIR/default.png"
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

  mkdir -p "$LINK_DIR" || {
    rofi -e "Failed to create $LINK_DIR"
    exit 1
  }
  ln -sfn "$selected_file" "$LINK_PATH" || {
    rofi -e "Failed to symlink $LINK_PATH"
    exit 1
  }

  echo "$(date): [type-2/$STYLE] Selected '$chosen'" >>/tmp/wallpaper.log
  echo "$(date): [type-2/$STYLE] Full path: '$selected_file'" >>/tmp/wallpaper.log
  echo "$(date): [type-2/$STYLE] Symlinked to '$LINK_PATH'" >>/tmp/wallpaper.log

  # ── Daemon detection ──────────────────────────────────────────────────────
  if command -v awww >/dev/null 2>&1; then
    echo "$(date): Using awww" >>/tmp/wallpaper.log
    awww daemon >/dev/null 2>&1 &
    sleep 0.5
    awww img "$LINK_PATH" --transition-type grow --transition-duration 1.5

  elif command -v swaybg >/dev/null 2>&1; then
    echo "$(date): Using swaybg" >>/tmp/wallpaper.log
    killall swaybg >/dev/null 2>&1
    nohup swaybg -i "$LINK_PATH" -m fill >/tmp/swaybg.log 2>&1 &
    disown

  elif command -v hyprpaper >/dev/null 2>&1; then
    echo "$(date): Using hyprpaper" >>/tmp/wallpaper.log
    hyprctl hyprpaper preload "$LINK_PATH"
    hyprctl hyprpaper wallpaper ",$LINK_PATH"

  else
    echo "$(date): No daemon found!" >>/tmp/wallpaper.log
    rofi -e "No wallpaper daemon (awww, swaybg, hyprpaper) found!"
  fi
fi
