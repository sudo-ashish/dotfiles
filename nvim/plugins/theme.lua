local theme_path = vim.fn.expand("~/.config/themes/current/neovim.lua")
local ok, spec = pcall(dofile, theme_path)

if not ok then
  vim.schedule(function()
    vim.notify("Failed to load active theme: " .. tostring(spec), vim.log.levels.ERROR)
  end)
  return {}
end

if type(spec) ~= "table" then
  vim.schedule(function()
    vim.notify("Active theme did not return a Lazy plugin spec", vim.log.levels.ERROR)
  end)
  return {}
end

return spec
