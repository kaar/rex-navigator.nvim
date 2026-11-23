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
local history_limit = 256
local history = {}
local edge_tolerance = 1e-6
local direction_axes = { left = 1, right = 1, up = 2, down = 2 }

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

local function active_window(view)
  for _, window in ipairs(view.windows or {}) do
    if window.window_id ~= nil and window.window_id == view.active_window_id then
      return window
    end
  end
end

local function remember(block_id)
  for i, id in ipairs(history) do
    if id == block_id then
      table.remove(history, i)
      break
    end
  end
  table.insert(history, 1, block_id)
  history[history_limit + 1] = nil
end

local function collect_rects(node, rects)
  if not node then
    return
  end
  if node.split then
    collect_rects(node.split.before, rects)
    collect_rects(node.split.after, rects)
  elseif node.block_id then
    rects[node.block_id] = node.rect
  end
end

-- Select only from the active window snapshot, without changing history.
local function select_target(window, source_id, direction, recent)
  local axis = direction_axes[direction]
  if not axis or window.zoomed_block_id then
    return
  end

  local rects = {}
  for _, layer in ipairs(window.layers or {}) do
    if layer.kind == "tiled" then
      collect_rects(layer.layout, rects)
      break
    end
  end
  local source = rects[source_id]
  if not source then
    return
  end

  local cross = 3 - axis
  local negative = direction == "left" or direction == "up"
  for _, id in ipairs(recent) do
    local target = rects[id]
    if id ~= source_id and target then
      local before, after = source, target
      if negative then
        before, after = target, source
      end
      local gap = after[axis] - (before[axis] + before[axis + 2])
      local overlap = math.min(source[cross] + source[cross + 2], target[cross] + target[cross + 2])
        - math.max(source[cross], target[cross])
      if math.abs(gap) <= edge_tolerance and overlap > 0 then
        return id
      end
    end
  end
end

--- Move pane focus from ctx.block_id in `direction`. Does nothing unless the
--- source is the focused block of the active window, so a stale or repeated
--- handoff cannot move focus from the wrong pane. Raises if reading the
--- view or native directional focus fails.
function M.navigate(ctx, direction)
  if type(ctx) ~= "table" or not ctx.session_id or not ctx.block_id then
    return
  end

  local view, err = rex.session.view({ session_id = ctx.session_id })
  if not view then
    error(("rex-navigator: session.view failed: %s"):format(tostring(err)), 0)
  end
  local window = active_window(view)
  if not window or window.focused_block_id ~= ctx.block_id then
    return
  end

  remember(ctx.block_id)
  local target = select_target(window, ctx.block_id, direction, history)
  if target then
    local called, focused = pcall(rex.session.focus_block, {
      session_id = ctx.session_id,
      block_id = target,
    })
    if called and focused then
      return
    end
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
