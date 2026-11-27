local M = {}

local directions = { "left", "down", "up", "right" }

local function run(argv)
  local ok, res = pcall(function()
    return vim.system(argv, { text = true }):wait(2000)
  end)
  if not ok then
    return nil, tostring(res)
  end
  if res.code ~= 0 then
    local detail = vim.trim(res.stderr or "")
    return nil, detail ~= "" and detail or ("exit code %s"):format(tostring(res.code))
  end
  return res.stdout or ""
end

local function check_actions()
  local out, err = run({ "rex", "--autostart=false", "actions", "--json" })
  if not out then
    vim.health.error("`rex actions` failed", { err })
    return
  end
  local ok, decoded = pcall(vim.json.decode, out)
  if not ok or type(decoded) ~= "table" then
    vim.health.error("`rex actions --json` returned unreadable output")
    return
  end
  local present = {}
  for _, action in ipairs(decoded.actions or {}) do
    present[action.name] = true
  end
  local missing = {}
  for _, direction in ipairs(directions) do
    if not present["rex_navigator_" .. direction] then
      table.insert(missing, "rex_navigator_" .. direction)
    end
  end
  if #missing == 0 then
    vim.health.ok("The Rex companion actions are loaded: rex_navigator_{left,down,up,right}")
  else
    vim.health.error(("Rex companion actions are missing: %s"):format(table.concat(missing, ", ")), {
      "Load the companion in the Rex config, then run `rex config reload`.",
      "See :h rex-navigator-installation",
    })
  end
end

function M.check()
  vim.health.start("rex-navigator")

  local block = vim.env.REX_BLOCK or ""
  if block ~= "" then
    vim.health.ok(("Running inside Rex (REX_BLOCK=%s)"):format(block))
  else
    vim.health.warn("REX_BLOCK is not set. The plugin is inactive", {
      "Start Neovim inside a Rex pane to activate the mappings.",
    })
  end

  if vim.fn.executable("rex") == 1 then
    vim.health.ok("`rex` is executable")
  else
    vim.health.error("`rex` is not executable", {
      "Make sure that Rex is installed and `rex` is on Neovim's $PATH.",
    })
    return
  end

  if block == "" then
    return
  end

  local _, err = run({ "rex", "--autostart=false", "whoami", "--json" })
  if err then
    vim.health.error("`rex whoami` failed. The Rex server is not reachable", { err })
    return
  end
  vim.health.ok("`rex whoami` succeeded. The Rex server is reachable")

  check_actions()
end

return M
