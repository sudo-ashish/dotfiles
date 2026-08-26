-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume raise"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume lower"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness +5"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness -5"), { locked = true, repeating = true })

-- Laptop multimedia keys for volume and LCD brightness
hl.bind(
	"ALT + XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume +1"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86AudioLowerVolume",
	hl.dsp.exec_cmd("swayosd-client --output-volume -1"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86MonBrightnessUp",
	hl.dsp.exec_cmd("swayosd-client --brightness +1"),
	{ locked = true, repeating = true }
)
hl.bind(
	"ALT + XF86MonBrightnessDown",
	hl.dsp.exec_cmd("swayosd-client --brightness -1"),
	{ locked = true, repeating = true }
)

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("swayosd-client --playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("swayosd-client --playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("swayosd-client --playerctl previous"), { locked = true })

hl.bind("XF86Calculator", hl.dsp.exec_cmd("gnome-calculator"))
