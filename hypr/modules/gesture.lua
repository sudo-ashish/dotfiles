hl.gesture({
	fingers = 3,
	direction = "horizontal",
	action = "workspace",
})

hl.gesture({
	fingers = 4,
	direction = "up",
	action = function()
		hl.exec_cmd("swayosd-client --output-volume raise")
	end,
})

hl.gesture({
	fingers = 4,
	direction = "down",
	action = function()
		hl.exec_cmd("swayosd-client --output-volume lower")
	end,
})
