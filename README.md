# rex-navigator.nvim

Use `ctrl+h/j/k/l` to move between Neovim splits and [Rex](https://www.superlogical.com/rex) panes.

For requirements and troubleshooting, see `:h rex-navigator`.


## Installation

### 1. Install the Neovim plugin

With `vim.pack` (Neovim ≥ 0.12):

```lua
vim.pack.add({ "https://github.com/kaar/rex-navigator.nvim" })
```

### 2. Load the Rex companion

After the plugin loads, run this in Neovim:

```vim
:lua print(vim.api.nvim_get_runtime_file('rex/rex-navigator.lua', false)[1])
```

Add this to `~/.config/rex/init.lua` and replace the example path with the printed path:

```lua
local ok, err = pcall(function()
  dofile("/absolute/path/to/rex-navigator.nvim/rex/rex-navigator.lua").setup()
end)
if not ok then
  rex.log("warn", "rex-navigator not loaded: " .. tostring(err))
end
```

Remove existing Rex bindings for `ctrl+h/j/k/l`. Shortcuts set in the Rex app override `init.lua`, so remove any conflicts there too.

Check and reload:

```sh
rex config check
rex config reload
```

Open Neovim inside Rex and run `:checkhealth rex-navigator`.


## Usage

| Focused pane | `ctrl+h/j/k/l` |
| --- | --- |
| Neovim | Move between splits in normal mode. At the edge of the Neovim layout, move to the next Rex pane. |
| Shell, Vim, or another program | Move between Rex panes. |

Focus stops at the outer edge of the Rex layout.


## Development

Run the formatting check from the checkout:

```sh
stylua --check lua plugin rex
```

For manual checks, see `:h rex-navigator-development`.


## Credits

- [christoomey/vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator): the pattern, the process matching, and the ergonomics this plugin mirrors.
- [kaar/nvim-herdr-navigator](https://github.com/kaar/nvim-herdr-navigator): the design this plugin ports from herdr to Rex.
