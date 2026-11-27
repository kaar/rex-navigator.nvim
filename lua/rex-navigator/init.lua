-- The Neovim half of the vim-tmux-navigator pattern for Rex: navigate()
-- moves between Neovim windows, then runs the companion's
-- rex_navigator_<direction> action via `rex do` at the layout edge. The Rex
-- half (rex/rex-navigator.lua) passes ctrl+h/j/k/l through to Neovim.
-- CLI invocations never pass keys through and only move Rex pane focus.
local M = {}

-- Notify about a failure to start rex once per session.
local spawn_failure_notified = false

local wincmds = {
  left = "h",
  down = "j",
  up = "k",
  right = "l",
}

--- The argv run at the layout edge.
function M.command(direction)
  return {
    "rex",
    "--autostart=false",
    "do",
    "-b",
    vim.env.REX_BLOCK or "",
    "rex_navigator_" .. direction,
  }
end

local function on_exit(result)
  if result.code == 0 then
    return
  end
  local detail = vim.trim(result.stderr or "")
  if detail == "" then
    detail = ("exit code %d"):format(result.code)
  end
  vim.schedule(function()
    vim.notify(("rex-navigator: rex do failed: %s"):format(detail), vim.log.levels.ERROR)
  end)
end

--- Move to the Neovim window in `direction` ("left"|"down"|"up"|"right"),
--- or to the neighbouring Rex pane when already at Neovim's layout edge.
function M.navigate(direction)
  local wincmd = wincmds[direction]
  if not wincmd then
    error(("rex-navigator: invalid direction %q"):format(tostring(direction)))
  end

  local win = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(wincmd)
  if vim.api.nvim_get_current_win() ~= win then
    return
  end

  -- Run the companion action asynchronously. --autostart=false keeps
  -- a handoff from starting a server.
  local ok, err = pcall(vim.system, M.command(direction), { text = true }, on_exit)
  if not ok and not spawn_failure_notified then
    spawn_failure_notified = true
    vim.notify(
      ("rex-navigator: could not run rex (%s). See :checkhealth rex-navigator"):format(err),
      vim.log.levels.ERROR
    )
  end
end

return M
