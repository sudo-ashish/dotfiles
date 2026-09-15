#!/usr/bin/env bash

# Define the directory containing wallpapers
WALLPAPERS_DIR="$HOME/.config/themes/current/backgrounds/"

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

  if ! "$HOME/.local/bin/wallpaper-switch" "$selected_file"; then
    rofi -e "Failed to set wallpaper"
    exit 1
  fi
fi
