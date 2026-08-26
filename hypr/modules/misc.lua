hl.layer_rule({
  match        = { namespace = "rofi" },
  blur         = true,
  ignore_alpha = 0.5,
})----------------
----  MISC  ----
----------------

hl.config({
  misc = {
    force_default_wallpaper = 0,    -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo   = true, -- If true disables the random hyprland logo / anime girl background. :(
  },
})