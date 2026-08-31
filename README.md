# Arch Linux + Hyprland Dotfiles

Personal Arch Linux desktop configuration for Hyprland, Waybar, Kitty, Rofi,
SwayNotificationCenter, Zsh, Neovim/LazyVim, and a shared theme system.

> [!IMPORTANT]
> Run the installer as your normal user. Do **not** run `sudo ./install.sh`.
> The script refuses to run as root and requests `sudo` itself only when it
> needs to install packages, enable SDDM, or reboot.

## Quick Installation

```bash
git clone --depth=1 https://github.com/sudo-ashish/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

`install.sh` is executable in the repository. If that permission was lost
while copying or extracting the project, restore it before running the script:

```bash
chmod +x install.sh
./install.sh
```

The installer is interactive: `pacman`, the `yay` build, SDDM setup, and the
final reboot prompt may request input or authentication.

## Features

- Modular Hyprland configuration written in Lua, with keybindings, gestures,
  animations, window rules, autostart commands, and environment settings.
- Waybar, Kitty, Rofi, SwayNC, and Zsh configuration files.
- Rofi application, wallpaper, power, and theme menus.
- Five coordinated theme bundles with wallpapers and application-specific
  colors.
- A `theme-switch` command that coordinates Waybar, Kitty, btop, Neovim,
  supported editors, and the current wallpaper.
- Package, font, AUR helper, and optional SDDM setup for Arch Linux.
- Existing top-level configuration directories are moved into timestamped
  backups before replacement.

## Screenshots

Screenshots are not currently included in the repository.

## Requirements

| Requirement | Details |
| --- | --- |
| Distribution | Arch Linux. The installer requires both `pacman` and `/etc/arch-release`. |
| Hyprland version | **Hyprland 0.55 or newer** is required. This repository uses `hyprland.lua`; native Lua configuration was introduced in [Hyprland 0.55](https://hypr.land/news/update55/). Older releases expect the legacy `hyprland.conf` format and will not load this configuration. The installer checks whether the `hyprland` package is installed but does not enforce a minimum version. |
| User | A normal, non-root account with `sudo` access. |
| Shell | Bash; the installer uses Bash arrays, namerefs, and strict mode. |
| Network | Required for packages, AUR access, the Deutschlander font, LazyVim, and optional editor extensions. |
| Git | Needed for the initial clone. The installer can install `git` later as a `yay` build prerequisite if necessary. |
| Font download tools | `curl` and `unzip` are needed for the downloaded Deutschlander font. Neither is installed by this installer. |

The script expects standard Arch/base utilities such as `sudo`, `systemctl`,
`find`, `diff`, `grep`, `sed`, `awk`, and `mktemp`. Theme setup installs `jq`
and `util-linux` (for `flock`) with `pacman` if their commands are missing.

## What the Installer Does

The installer performs these operations in order:

1. Refuses root execution and verifies that the system is Arch Linux.
2. Checks the required packages with `pacman -Q` and installs only missing
   packages with `sudo pacman -S --needed`.
3. Checks the official-repository fonts and installs missing packages.
4. Installs `yay` from the AUR when it is absent, then uses it to install the
   Rubik font.
5. Offers to install and enable SDDM.
6. Installs downloaded and repository-bundled fonts.
7. Copies the Hyprland, Kitty, Rofi, SwayNC, Waybar, and Zsh directories into
   `~/.config`, backing up differing destinations first.
8. Copies themes to `~/.config/themes`, installs theme commands to
   `~/.local/bin`, updates shell `PATH` rules, and runs theme integration setup.
9. Runs the standalone background step. There is currently no repository-level
   `Background/` directory, so no `~/Pictures/Background` content is copied.
10. Attempts to install the LazyVim starter when `~/.config/nvim` does not
    exist, then copies the repository's Neovim plugin specs.
11. Prints an installation summary and attempts to apply `gruvbox`.
12. Prompts to reboot. The `[Y/n]` prompt defaults to **yes** when Enter is
    pressed without an answer.

Most high-level failures are reported and the installer continues to the next
section. Applying the theme is deliberately non-fatal and never prevents the
reboot prompt.

### Packages

The following packages are checked and installed from the official Arch
repositories when missing:

| Category | Packages |
| --- | --- |
| Desktop and shell | `hyprland`, `hyprlock`, `kitty`, `nautilus`, `neovim`, `rofi`, `swaync`, `waybar`, `zsh` |
| Desktop services | `awww`, `polkit-kde-agent`, `swayosd`, `xdg-desktop-portal-gtk`, `xdg-desktop-portal-hyprland` |
| Utilities | `bluetui`, `brightnessctl`, `btop`, `hyprshot`, `impala`, `jq`, `wl-clipboard` |
| Qt/Wayland | `qt5-wayland`, `qt6-wayland` |

> [!NOTE]
> The package list contains `bluetui`, not `bluetoothctl`. Some commands used
> by the configuration—such as `pavucontrol`, `pamixer`, `playerctl`,
> `gnome-calculator`, the Bibata cursor theme, `qt5ct`, and the Numix Circle
> icon theme—are not installed by `install.sh`.

If `yay` is unavailable, the installer:

1. Installs missing `git` and `base-devel` prerequisites.
2. Clones `https://aur.archlinux.org/yay.git` into a temporary directory.
3. Builds and installs it with `makepkg -si` as the normal user.

Missing AUR fonts are then installed with:

```bash
yay -S --needed --noconfirm ttf-rubik-vf
```

If `yay` setup or the AUR installation fails, Rubik is listed for manual
installation in the final summary.

### Fonts

| Source | Font/package | Destination or use |
| --- | --- | --- |
| Official repositories | `ttf-jetbrains-mono-nerd` | Kitty, Hyprlock, Rofi, SwayNC, and Waybar |
| Official repositories | `ttf-cascadia-code-nerd` | SwayNC |
| Official repositories | `ttf-iosevka-nerd` | Rofi launcher styles |
| Official repositories | `noto-fonts-cjk` | Waybar fallback text |
| AUR | `ttf-rubik-vf` | Waybar |
| Download | Deutschlander from dafont.com | `~/.local/share/fonts`; used by Hyprlock |
| Repository | `fonts/Icomoon-Feather.ttf` | `~/.local/share/fonts`; used by Rofi power menus |

Fontconfig is used to avoid reinstalling already available families. After a
local font copy, the script runs `fc-cache -f` when `fc-cache` is available.
If `unzip` is unavailable or a download/copy fails, the font is reported for
manual installation instead of stopping the entire installer.

### SDDM

The installer asks:

```text
Install and enable sddm as your display manager? [y/n]
```

An explicit answer is required. Choosing yes installs `sddm` when necessary
and runs `sudo systemctl enable sddm`. It enables the service for future boots;
the installer does not start SDDM immediately.

## Included Configurations

| Repository path | Installed path | Contents |
| --- | --- | --- |
| `hypr/` | `~/.config/hypr/` | Modular Lua config, window rules, keybindings, gestures, autostart, environment settings, and Hyprlock styling |
| `kitty/` | `~/.config/kitty/` | Terminal settings and a theme-controlled `color.conf` include |
| `rofi/` | `~/.config/rofi/` | Application launchers, wallpaper menus, power menus, theme selector, images, and styles |
| `swaync/` | `~/.config/swaync/` | Notification daemon layout and static Gruvbox-style CSS |
| `waybar/` | `~/.config/waybar/` | Bar modules, theme import, CSS, and a restart script |
| `zsh/` | `~/.config/zsh/` | Alias and helper-function fragments |
| `nvim/plugins/` | `~/.config/nvim/lua/plugins/` | Lazy plugin specs for Snacks and the active theme loader |
| `themes/` | `~/.config/themes/` | Theme bundles and wallpapers |
| `bin/` | `~/.local/bin/` | `theme-switch` and `theme-switch-setup` |

The Zsh fragments are copied but are **not automatically sourced**. The
installer does not change the login shell and does not add a source command for
`~/.config/zsh/aliases.zsh` or `functions.zsh`.

### Selected Hyprland Keybindings

| Shortcut | Action |
| --- | --- |
| `Super` + `Return` | Open Kitty |
| `Super` + `E` | Open Nautilus |
| `Alt` + `Space` | Open the type-1 Rofi application launcher |
| `Super` + `Space` | Open the type-2 wallpaper picker |
| `Super` + `Alt` + `Space` | Open the Rofi theme selector |
| `Super` + `Escape` | Open the type-1 power menu |
| `Super` + `L` | Run Hyprlock |
| `Super` + `N` | Toggle the SwayNC control center |
| `Print` | Save a region screenshot under `~/Pictures/Screenshot` |
| `Shift` + `Print` | Copy a region screenshot to the clipboard |
| `Ctrl` + `Shift` + `R` | Restart Waybar, SwayNC, and SwayOSD |

The Hyprland config also defines workspace navigation, window movement and
resizing, grouping, multimedia keys, touchpad gestures, and floating rules for
several utilities.

## Theme Switching

Themes are installed in:

```text
~/.config/themes/<theme-name>/
```

The active theme is represented by this symlink:

```text
~/.config/themes/current -> ~/.config/themes/<theme-name>
```

Switch from a terminal with exactly one theme name:

```bash
theme-switch gruvbox
```

If the current shell has not reloaded the new `PATH` entry yet, use the full
path:

```bash
~/.local/bin/theme-switch gruvbox
```

The Rofi theme selector is available through `Super` + `Alt` + `Space`. It
discovers theme directories under `~/.config/themes`, shows the first available
wallpaper as a preview, and calls the same `theme-switch` command.

The installer attempts to activate `gruvbox` after installation. A failure is
reported as a warning and does not stop the restart prompt.

### Applications Updated by `theme-switch`

| Component | Behavior |
| --- | --- |
| Waybar | `waybar/style.css` imports `themes/current/waybar.css`. On a theme change, running Waybar processes receive `SIGUSR2`. If Waybar is not running, including when the requested theme is already active, the switcher starts and disowns it in the background. |
| Kitty | `~/.config/kitty/color.conf` becomes a symlink to the selected theme's `color.conf`. Running Kitty processes receive `SIGUSR1` when the link changes. |
| btop | Setup creates `~/.config/btop/themes/current.theme` pointing through the active-theme symlink and sets `color_theme = "current"` in `btop.conf`. Restart btop to refresh it. |
| Neovim | A Lazy plugin spec loads `~/.config/themes/current/neovim.lua`. Restart Neovim sessions to load the selected scheme/plugin. |
| VS Code/VSCodium | If `code` or `codium` is installed, the script validates strict-JSON settings, attempts to install the theme extension, and sets `workbench.colorTheme`. It does not explicitly restart the editor. |
| Rofi | Theme-aware styles import the active theme's `color.rasi`; new Rofi windows read the current link. See the hard-coded-path note below. |
| Wallpaper | On an actual theme change, the first supported image in the theme's `backgrounds/` directory is passed to `awww img`. `awww-daemon` must already be running. |

The switcher does **not** dynamically update SwayNC colors, Hyprland border or
Hyprlock colors, `icons.theme`, or `colors.toml`. Those files are either static
configuration or currently unused by the switching scripts.

> [!WARNING]
> Successful editor updates remove `workbench.colorCustomizations` and
> `editor.tokenColorCustomizations` from the selected settings file. Settings
> that are not strict JSON (for example, JSON with comments) are skipped. The
> switcher uses temporary rollback copies during the operation, but it does not
> keep a persistent backup after a successful Kitty or editor update.

### Available Themes

| Command name | VS Code/VSCodium theme | Extension | Neovim colorscheme |
| --- | --- | --- | --- |
| `catppuccin` | Catppuccin Mocha | `catppuccin.catppuccin-vsc` | `catppuccin-nvim` |
| `everforest` | Everforest Night Hard | `jarith.everforest-night-vscode` | `everforest` |
| `gruvbox` | Gruvbox Dark Medium | `jdinhlife.gruvbox` | `gruvbox` |
| `nord` | Nord | `arcticicestudio.nord-visual-studio-code` | `nordfox` |
| `tokyo-night` | Tokyo Night | `enkia.tokyo-night` | `tokyonight-night` |

Every current theme includes Waybar, btop, Kitty, Rofi, Neovim, editor, icon
metadata, terminal-color metadata, and one or more wallpapers.

### Wallpaper Picker

Use `Super` + `Space` to choose a wallpaper from the active theme. The picker:

1. Reads images from `~/.config/themes/current/backgrounds/`.
2. Replaces `~/Pictures/Wallpaper/default.png` with a symlink to the selected
   image.
3. Tries `awww`, then `swaybg`, then `hyprpaper`.
4. Appends diagnostic output to `/tmp/wallpaper.log`.

The normal installation includes `awww`, and Hyprland autostart launches
`awww-daemon`. The direct `theme-switch` command uses the selected image path
without updating `~/Pictures/Wallpaper/default.png`.

## Repository Structure

```text
dotfiles/
├── bin/                    # Theme setup and switching commands
├── fonts/                  # Bundled Feather icon font
├── hypr/                   # Hyprland Lua modules, keybindings, and Hyprlock
├── kitty/                  # Kitty terminal configuration
├── nvim/
│   └── plugins/            # LazyVim plugin specs and theme loader
├── rofi/                   # Launchers, menus, images, and Rasi styles
├── swaync/                 # Notification center configuration and CSS
├── themes/                 # Five theme bundles and their wallpapers
├── waybar/                 # Waybar config, CSS, and restart script
├── zsh/                    # Alias and function fragments
└── install.sh              # Arch Linux installer
```

## Updating

For an existing clone:

```bash
cd ~/dotfiles
git pull
./install.sh
```

A repository initially cloned with `--depth=1` can normally pull newer commits
without any extra steps. If you later want the complete historical commit
graph, expand the clone with:

```bash
git fetch --unshallow
```

Review the backup behavior below before rerunning the installer if you have
made local changes under `~/.config`.

## Backup and Safety Behavior

> [!WARNING]
> The installer installs system packages, can enable a systemd service, edits
> shell startup files, replaces or merges user configuration, changes the
> active wallpaper/theme, and offers to reboot. Read this section before
> running it on an existing desktop.

| Target | Actual behavior |
| --- | --- |
| `~/.config/{hypr,kitty,rofi,swaync,waybar,zsh}` | Exact matches are skipped. Differing existing files, directories, or symlinks are moved into one `~/.config/dotfile-backup-YYYYMMDD-HHMMSS/` directory, then repository content is copied into newly created destinations. |
| `~/.config/themes` | If repository theme files do not already match, an existing directory is copied to `~/.config/themes.bak.YYYYMMDD-HHMMSS` and repository themes are merged into it. Existing extra files are not removed. A non-directory or symlink destination causes this step to fail safely. |
| `~/.local/bin/theme-switch*` | Identical executable files are skipped. Different files are replaced through temporary files; no persistent backup is kept. |
| `~/.bashrc` and `~/.zshrc` | The exact line `export PATH="$HOME/.local/bin:$PATH"` is placed at the top and duplicate exact copies are removed. Existing files are backed up as `.bak.YYYYMMDD-HHMMSS`; missing files are created. |
| btop integration | Existing `btop.conf` and `themes/current.theme` content is backed up as `.bak.<timestamp>` before setup changes it. Repeated identical backups are avoided. |
| Neovim theme integration | `lua/plugins/theme.lua` may be created or replaced, and an obsolete exact `require("theme-loader")` line may be removed from `init.lua`. Changed existing files receive `.bak.<timestamp>` backups. |
| Neovim repository plugins | `nvim/plugins` is copied into `~/.config/nvim/lua/`. Same-named files can be overwritten without a separate backup; unrelated plugin files are not removed. |
| Existing Neovim config | The LazyVim clone step never deletes or replaces an existing file, directory, or symlink at `~/.config/nvim`. Other theme/plugin setup steps can still modify the specific Neovim files described above. |
| Live Kitty/editor theme files | The theme switcher stages temporary rollback data and restores it if its commit fails, but keeps no persistent backup after success. |
| `~/Pictures/Background` | The installer can move a differing destination to `Background-backup-<timestamp>`, but the current repository has no top-level `Background/` source, so this copy is skipped. `xdg-user-dirs-update` is still called first when available. |

The theme switcher serializes operations with a lock and rolls back committed
editor/Kitty changes plus the active-theme symlink when its commit phase fails.
Wallpaper or reload failures are warnings and do not roll the selected theme
back. It also refuses to replace `~/.config/themes/current` when that path
already exists but is not a symlink.

## Useful Commands

```bash
# Apply a theme
theme-switch gruvbox

# Re-run/repair btop and Neovim theme integration
theme-switch-setup

# Restart Waybar, SwayNC, and SwayOSD using the installed helper
~/.config/waybar/scripts/launch.sh
```

Both theme commands accept strict argument counts: `theme-switch` requires one
theme name, while `theme-switch-setup` accepts no arguments.

## Troubleshooting and Current Notes

### Clean LazyVim installation order

The installer creates or repairs the LazyVim starter before copying plugin
specs and running `theme-switch-setup`. It also repairs the partial nvim
directory created by older installer versions, without replacing existing
files. The lazy.nvim plugin-manager checkout is validated separately; an
interrupted checkout that contains `.git` but lacks `lua/lazy/init.lua` is
replaced transactionally and restored if the new clone fails.

Do not remove an existing `~/.config/nvim` without first inspecting and backing
up your own configuration.

### User-specific paths and hardware assumptions

- Several Rofi shared color files import
  `/home/pear/.config/themes/current/color.rasi`. Users with another home path
  must replace that path before those styles can follow the active theme.
- The installer always writes configuration under `~/.config`, while the two
  theme commands honor `XDG_CONFIG_HOME`. A non-default `XDG_CONFIG_HOME` can
  therefore make the commands look in a different directory from the
  installer.
- `hypr/hyprlock.conf` uses the hard-coded wallpaper path
  `/home/pear/Pictures/Wallpaper/default.png` and targets monitor `eDP-1` for
  its input and clock widgets. Adjust both for the target account and display.
- Hyprland requests the `Bibata-Modern-Ice` cursor and `qt5ct`, while the
  installer does not install those packages.
- Hyprland autostart references
  `/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1`, but the installer
  installs `polkit-kde-agent`. Adjust the command or install the matching agent.

### Configuration-specific notes

- SwayNC uses its own static `swaync/colors/colors.css`; it is not linked to
  `~/.config/themes/current`.
- The type-1 power menu's lock option checks only `betterlockscreen` and
  `i3lock`; use `Super` + `L` for the configured Hyprlock command. Its logout
  cases do not include Hyprland.
- `rofi/launchers/type-2/launcher.sh` selects a missing `style-15.rasi`, and the
  type-4 launcher points to a non-existent `launchers/type-7` directory. The
  Hyprland keybinding uses the working type-1 launcher.
- Waybar click actions reference `pavucontrol` and `pamixer`, which are not in
  the installer package list.
- If the installer has just added `~/.local/bin` to `PATH`, open a new shell or
  use `~/.local/bin/theme-switch` until the startup file is reloaded.
