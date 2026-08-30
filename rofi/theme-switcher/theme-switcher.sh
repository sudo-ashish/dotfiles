#!/usr/bin/env bash

# ── Paths and Configuration ───────────────────────────────────────────────────
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
THEMES_DIR="$CONFIG_HOME/themes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME_PATH="$SCRIPT_DIR/style-1.rasi"


# ── Argument Handling ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --style)
            if [[ -f "$SCRIPT_DIR/style-$2.rasi" ]]; then
                THEME_PATH="$SCRIPT_DIR/style-$2.rasi"
            elif [[ -f "$SCRIPT_DIR/$2" ]]; then
                THEME_PATH="$SCRIPT_DIR/$2"
            fi
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# ── Sanity Checks ─────────────────────────────────────────────────────────────
if [[ ! -f "$THEME_PATH" ]]; then
    rofi -e "Theme configuration not found: $THEME_PATH"
    exit 1
fi

if [[ ! -d "$THEMES_DIR" ]]; then
    rofi -e "Themes directory not found: $THEMES_DIR"
    exit 1
fi

# ── Detect Active Theme ───────────────────────────────────────────────────────
current_theme=""
if [[ -L "$THEMES_DIR/current" ]]; then
    current_theme="$(basename "$(readlink -f "$THEMES_DIR/current")")"
fi

# ── Discover Themes & Build Selection List ────────────────────────────────────
theme_names=()
while IFS= read -r dir; do
    name="$(basename "$dir")"
    [[ "$name" == "current" || "$name" == .* ]] && continue
    theme_names+=("$name")
done < <(find "$THEMES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ ${#theme_names[@]} -eq 0 ]]; then
    rofi -e "No themes found in $THEMES_DIR"
    exit 1
fi

selected_row=0
rofi_input=""

for i in "${!theme_names[@]}"; do
    theme="${theme_names[$i]}"
    if [[ "$theme" == "$current_theme" ]]; then
        selected_row=$i
    fi

    # Find background preview thumbnail
    preview_img=""
    if [[ -d "$THEMES_DIR/$theme/backgrounds" ]]; then
        preview_img=$(find -L "$THEMES_DIR/$theme/backgrounds" -maxdepth 1 -type f \
            \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) \
            ! -iname "omarchy*" 2>/dev/null | sort | head -n 1)

        if [[ -z "$preview_img" ]]; then
            preview_img=$(find -L "$THEMES_DIR/$theme/backgrounds" -maxdepth 1 -type f \
                \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.jpeg" -o -iname "*.webp" \) \
                2>/dev/null | sort | head -n 1)
        fi
    fi

    if [[ -n "$preview_img" ]]; then
        rofi_input+="${theme}\0icon\x1f${preview_img}\n"
    else
        rofi_input+="${theme}\n"
    fi
done

# ── Launch Rofi Menu ──────────────────────────────────────────────────────────
chosen=$(printf "%b" "$rofi_input" | rofi -dmenu -i -show-icons \
    -theme "$THEME_PATH" \
    -p "Theme" \
    -selected-row "$selected_row")

# ── Apply Selected Theme ──────────────────────────────────────────────────────
if [[ -n "$chosen" ]]; then
    chosen="$(echo "$chosen" | xargs)" # Trim whitespace

    if [[ ! -d "$THEMES_DIR/$chosen" ]]; then
        rofi -e "Theme '$chosen' does not exist in $THEMES_DIR"
        exit 1
    fi

    if command -v theme-switch >/dev/null 2>&1; then
        theme-switch "$chosen"
    elif [[ -x "$HOME/.local/bin/theme-switch" ]]; then
        "$HOME/.local/bin/theme-switch" "$chosen"
    elif [[ -x "$CONFIG_HOME/theme-switcher/theme-switch" ]]; then
        "$CONFIG_HOME/theme-switcher/theme-switch" "$chosen"
    else
        theme-switch "$chosen"
    fi
fi
