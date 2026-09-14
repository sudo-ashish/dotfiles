-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("awww-daemon")
	hl.exec_cmd("waybar & swaync & swayosd-server")
	hl.exec_cmd("systemctl --user start hyprpolkitagent.service")
end)
