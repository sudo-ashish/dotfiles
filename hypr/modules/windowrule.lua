--------------------------------
---- WINDOWS AND WORKSPACES ----
--------------------------------
local suppressMaximizeRule = hl.window_rule({
	-- Ignore maximize requests from all apps. You'll probably like this.
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})
-- suppressMaximizeRule:set_enabled(false)

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

-- Layer rules also return a handle.
-- local overlayLayerRule = hl.layer_rule({
--     name  = "no-anim-overlay",
--     match = { namespace = "^my-overlay$" },
--     no_anim = true,
-- })
-- overlayLayerRule:set_enabled(false)

-- Hyprland-run windowrule
hl.window_rule({
	name = "move-hyprland-run",
	match = { class = "hyprland-run" },

	move = "20 monitor_h-120",
	float = true,
})

hl.window_rule({
	name = "float-tui",
	match = { class = "^(custom_tui_floating)$" },
	float = true,
	center = true,
	pin = true,
	workspace = "unset",
	size = "960 650",
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
	match = { class = "localsend" },
	float = true,
	center = true,
	size = "960 650",
})

hl.window_rule({
	name = "pavucontrol-rule",
	match = { class = "org.pulseaudio.pavucontrol" },
	float = true,
	center = true,
	size = "960 650",
})

hl.window_rule({
	name = "tui-float",
	match = { class = "^(btop|impala|bluetui)" },
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

-- hl.window_rule({
-- 	name = "zen-swift",
-- 	match = { class = "zen"},
-- 	workspace = "1",
-- })
--
-- hl.window_rule({
-- 	name = "termial-workspace",
-- 	match = { class = "kitty"},
-- 	workspace = "2",
-- })
--
-- hl.window_rule({
-- 	name = "codium-swift",
-- 	match = { class = "codium"},
-- 	workspace = "3",
-- })
--
-- hl.window_rule({
-- 	name = "file-workspace",
-- 	match = { class = "org.gnome.Nautilus"},
-- 	workspace = "4",
-- })

hl.layer_rule({ match = { namespace = "rofi" }, blur = true, ignore_alpha = 0 })
hl.window_rule({ match = { class = "org.gnome.Calculator" }, float = true, center = true })
