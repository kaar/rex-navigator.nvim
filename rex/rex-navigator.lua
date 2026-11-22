-- Rex half of rex-navigator.nvim. Load it from the Rex config and call
-- setup() once:
--
--   dofile("/path/to/rex-navigator.nvim/rex/rex-navigator.lua").setup()
--
-- Key path: ctrl+h/j/k/l run function bindings. When the target block's
-- foreground process is Neovim, the binding returns false and Rex
-- delivers the key to that block. Otherwise it moves pane focus.
--
-- CLI path: Neovim runs `rex do -b $REX_BLOCK rex_navigator_<direction>` at
-- its window edge. The actions only move pane focus and never pass a key
-- through, which prevents a loop back into Neovim.
local M = {}

local terminal = "com.superlogical.terminal"

M.directions = { "left", "down", "up", "right" }

M.keys = {
  left = "ctrl+h",
  down = "ctrl+j",
  up = "ctrl+k",
  right = "ctrl+l",
}

--- True when `name` is Neovim, including nvimdiff and wrapped binaries.
function M.is_nvim(name)
  if type(name) ~= "string" then
    return false
  end
  local base = name:lower():gsub("^%.", ""):gsub("%-wrapped$", "")
  return base == "nvim" or base == "nvimdiff"
end

-- A failed process lookup counts as "not Neovim".
local function passes_through(block_id)
  local process = rex.block.call(terminal, "process", { block_id = block_id })
  local foreground = type(process) == "table" and process.foreground
  return type(foreground) == "table" and M.is_nvim(foreground.name)
end

local function active_focused_block(view)
  for _, window in ipairs(view.windows or {}) do
    if window.window_id ~= nil and window.window_id == view.active_window_id then
      return window.focused_block_id
    end
  end
end

--- Move pane focus from ctx.block_id in `direction`. Does nothing unless the
--- source is the focused block of the active window, so a stale or repeated
--- handoff cannot move focus from the wrong pane. Raises on API errors.
function M.navigate(ctx, direction)
  if type(ctx) ~= "table" or not ctx.session_id or not ctx.block_id then
    return
  end

  local view, err = rex.session.view({ session_id = ctx.session_id })
  if not view then
    error(("rex-navigator: session.view failed: %s"):format(tostring(err)), 0)
  end
  if active_focused_block(view) ~= ctx.block_id then
    return
  end

  -- Pass wrap explicitly: servers that ignore it always wrap.
  local ok, focus_err = rex.session.focus_direction({
    session_id = ctx.session_id,
    direction = direction,
    wrap = false,
  })
  if not ok then
    error(("rex-navigator: session.focus_direction failed: %s"):format(tostring(focus_err)), 0)
  end
end

--- Key binding handler: pass the key through to Neovim, otherwise
--- move pane focus. Rex decided the key's block before this runs, so
--- returning false delivers it to ctx.block_id.
function M.on_key(ctx, direction)
  if passes_through(ctx and ctx.block_id) then
    return false
  end
  M.navigate(ctx, direction)
  return true
end

--- Register the four rex_navigator_<direction> actions and the
--- ctrl+h/j/k/l function bindings. Call once per config load.
function M.setup()
  for _, direction in ipairs(M.directions) do
    rex.action({
      name = "rex_navigator_" .. direction,
      title = ("Navigate %s (Neovim/Rex)"):format(direction),
      description = ("Move pane focus %s from the given block. Neovim calls this at its window edge."):format(
        direction
      ),
      category = "Navigation",
      run = function(ctx)
        M.navigate(ctx, direction)
      end,
    })

    rex.bind(M.keys[direction], function(ctx)
      return M.on_key(ctx, direction)
    end)
  end
end

return M
