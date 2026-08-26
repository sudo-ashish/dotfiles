---------------------
---- MY PROGRAMS ----
---------------------

-- Set programs that you use
local terminal = "kitty"
local fileManager = "nautilus --new-window"
local menu = "rofi -show drun"

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER" -- Sets "Windows" key as main modifier

hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
local closeWindowBind = hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
)
hl.bind(mainMod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mainMod .. " + ALT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))
-- Move focus with mainMod + arrow keys
hl.bind(mainMod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down", hl.dsp.focus({ direction = "down" }))

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 10 do
	local key = i % 10 -- 10 maps to key 0
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
	hl.bind(mainMod .. " + ALT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Example special workspace (scratchpad)
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mainMod .. " + ALT + grave", hl.dsp.window.move({ workspace = "special:scratchpad" }))
hl.bind(mainMod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

hl.bind(mainMod .. " + CTRL + TAB", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + TAB", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + TAB", hl.dsp.focus({ workspace = "previous" }))

hl.bind(mainMod .. " + SHIFT + LEFT", hl.dsp.window.swap({ direction = "l" }))
hl.bind(mainMod .. " + SHIFT + RIGHT", hl.dsp.window.swap({ direction = "r" }))
hl.bind(mainMod .. " + SHIFT + UP", hl.dsp.window.swap({ direction = "u" }))
hl.bind(mainMod .. " + SHIFT + DOWN", hl.dsp.window.swap({ direction = "d" }))

hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))
hl.bind("ALT + TAB", hl.dsp.window.bring_to_top())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.bring_to_top())

hl.bind(mainMod .. " + code:20", hl.dsp.window.resize({ x = -100, y = 0, relative = true }))
hl.bind(mainMod .. " + code:21", hl.dsp.window.resize({ x = 100, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + code:20", hl.dsp.window.resize({ x = 0, y = -100, relative = true }))
hl.bind(mainMod .. " + SHIFT + code:21", hl.dsp.window.resize({ x = 0, y = 100, relative = true }))

hl.bind(mainMod .. " + ALT + code:20", hl.dsp.window.resize({ x = -25, y = 0, relative = true }))
hl.bind(mainMod .. " + ALT + code:21", hl.dsp.window.resize({ x = 25, y = 0, relative = true }))
hl.bind(mainMod .. " + SHIFT + ALT + code:20", hl.dsp.window.resize({ x = 0, y = -25, relative = true }))
hl.bind(mainMod .. " + SHIFT + ALT + code:21", hl.dsp.window.resize({ x = 0, y = 25, relative = true }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Window Grouping
hl.bind(mainMod .. " + G", hl.dsp.group.toggle())
hl.bind(mainMod .. " + ALT + G", hl.dsp.window.move({ out_of_group = true }))
hl.bind(mainMod .. " + ALT + LEFT", hl.dsp.window.move({ into_group = "l" }))
hl.bind(mainMod .. " + ALT + RIGHT", hl.dsp.window.move({ into_group = "r" }))
hl.bind(mainMod .. " + ALT + UP", hl.dsp.window.move({ into_group = "u" }))
hl.bind(mainMod .. " + ALT + DOWN", hl.dsp.window.move({ into_group = "d" }))

hl.bind(mainMod .. " + ALT + TAB", hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + SHIFT + TAB", hl.dsp.group.prev())

hl.bind(mainMod .. " + CTRL + LEFT", hl.dsp.group.prev())
hl.bind(mainMod .. " + CTRL + RIGHT", hl.dsp.group.next())

hl.bind(mainMod .. " + ALT + mouse_down", hl.dsp.group.next())
hl.bind(mainMod .. " + ALT + mouse_up", hl.dsp.group.prev())

hl.bind("CTRL + SHIFT + W", hl.dsp.exec_cmd("killall -SIGUSR1 waybar"))
