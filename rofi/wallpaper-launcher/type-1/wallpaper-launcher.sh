#!/usr/bin/env bash

# Define the directory containing wallpapers
WALLPAPERS_DIR="$HOME/.config/themes/current/backgrounds/"
LINK_DIR="$HOME/Pictures/Wallpaper"
LINK_PATH="$LINK_DIR/default.png"

# Check if directory exists
if [ ! -d "$WALLPAPERS_DIR" ]; then
  rofi -e "Directory not found: $WALLPAPERS_DIR"
  exit 1
fi

# Generate list of options with thumbnails and pipe directly into rofi
# Format for rofi icons: 'Entry Name\0icon\x1f/path/to/image.png'
# We CANNOT store this in a bash variable first because bash strips \0 characters!
chosen=$(find -L "$WALLPAPERS_DIR" -type f \( -iname \*.jpg -o -iname \*.png -o -iname \*.jpeg -o -iname \*.webp -o -iname \*.gif \) | sort | while read -r file; do
  filename=$(basename "$file")
  echo -en "$filename\0icon\x1f${file}\n"
done | rofi -dmenu -i -show-icons -theme ~/.config/rofi/wallpaper-launcher/type-1/style-1.rasi -p "Wallpaper")

# Apply wallpaper if an option was selected
if [ -n "$chosen" ]; then
  selected_file="$WALLPAPERS_DIR/$chosen"

  # Symlink workflow: point default.png at whatever was picked.
  # mkdir -p is a no-op if the dir already exists.
  # ln -sfn atomically replaces any existing symlink (or stale file) at LINK_PATH.
  mkdir -p "$LINK_DIR" || {
    rofi -e "Failed to create $LINK_DIR"
    exit 1
  }
  ln -sfn "$selected_file" "$LINK_PATH" || {
    rofi -e "Failed to symlink $LINK_PATH"
    exit 1
  }

  echo "$(date): Selected '$chosen'" >>/tmp/wallpaper.log
  echo "$(date): Full path: '$selected_file'" >>/tmp/wallpaper.log
  echo "$(date): Symlinked to '$LINK_PATH'" >>/tmp/wallpaper.log

  # Check for wallpaper daemons
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
