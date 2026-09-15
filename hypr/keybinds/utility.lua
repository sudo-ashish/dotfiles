---------------------
----   utility   ----
---------------------

hl.bind("SUPER + E", hl.dsp.exec_cmd("nautilus --new-window"))
hl.bind("SUPER + N", hl.dsp.exec_cmd("swaync-client -t"))

hl.bind("CTRL + SHIFT + R", hl.dsp.exec_cmd("~/.config/waybar/scripts/launch.sh"))
hl.bind("PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshot -f myshot-$(date +%Y%m%d-%H%M%S).png"))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd("hyprshot -m region -o ~/Pictures/Screenshot -f temshot.png --clipboard-only"))

-- conectivity

hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("tui-launch bluetui"))
hl.bind("SUPER + SHIFT + N", hl.dsp.exec_cmd("tui-launch impala"))

---- APPS ----

hl.bind("SUPER + SHIFT + B", hl.dsp.exec_cmd("default-browser"))
hl.bind("SUPER + SHIFT + T", hl.dsp.exec_cmd("tui-launch webapp-create"))