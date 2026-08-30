---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "kitty"
local fileManager = "nautilus --new-window"
local menu = "rofi -show drun"
local notiCenter = "swaync"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

---------------------
----   utility   ----
---------------------

hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))

hl.bind("CTRL + SHIFT + R", hl.dsp.exec_cmd("~/.config/waybar/scripts/launch.sh"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshot -f myshot-$(date +%Y%m%d-%H%M%S).png"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshot -f temshot.png --clipboard-only"))

-- conectivity

hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("kitty --class bluetui -e bluetui"))
hl.bind(mainMod .. " + SHIFT + N", hl.dsp.exec_cmd("kitty --class impala -e impala"))
