-- Neovim mappings for split and Rex pane navigation.
-- See lua/rex-navigator/init.lua for the navigation logic.
if vim.g.loaded_rex_navigator then
  return
end
vim.g.loaded_rex_navigator = 1

-- No-op outside Rex. REX_BLOCK identifies the source pane.
if (vim.env.REX_BLOCK or "") == "" then
  return
end

for direction, key in pairs({
  left = "<C-h>",
  down = "<C-j>",
  up = "<C-k>",
  right = "<C-l>",
}) do
  vim.keymap.set("n", key, function()
    require("rex-navigator").navigate(direction)
  end, {
    silent = true,
    desc = "Go to window / Rex pane " .. direction,
  })
end
