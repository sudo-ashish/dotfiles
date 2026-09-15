--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
local suppressMaximizeRule = hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

hl.window_rule({
	name = "imv-rule",
	match = { class = "imv" },
	float = true,
	center = true,
	content = "photo",
	size = "960 650",
	opacity = "1.0 override",
})

hl.window_rule({
	name = "localsend-rule",
	match = { class = "^(org.localsend.localsend_app|org.pulseaudio.pavucontrol)" },
	float = true,
	center = true,
	size = "960 650",
})

hl.window_rule({
	name = "tui-float",
	match = { class = "^(tui-btop|tui-impala|tui-bluetui)" },
	float = true,
	center = true,
	size = "960 650",
})

hl.window_rule({
	name = "custom-float",
	match = { title = "webapp-create" },
	float = true,
	center = true,
	size = "960 650",
})

hl.layer_rule({
	name = "notification-animation",
	match = { namespace = "swaync-control-center" },
	animation = "slide top",
})

hl.layer_rule({
	name = "osd-animation",
	match = { namespace = "swayosd" },
	animation = "slide bottom",
})

hl.window_rule({
	name = "zen-opac",
	match = { class = "zen" },
	opacity = "1.0 override",
	no_blur = false,
})

hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })
hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true, center = true })
