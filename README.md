# ✨ emission.nvim

A generalized fork of
[tzachar/highlight-undo.nvim](https://github.com/tzachar/highlight-undo.nvim)
rewritten in Fennel with
[antifennel](https://git.sr.ht/~technomancy/antifennel).

Highlight added/removed texts in current buffer as well as undo/redo.

Unlike `highlight-undo.nvim` does, `emission.nvim` does NOT distinguish
`undo`/`redo`, but only `added`/`removed`.

_However, **no need** to worry about keymap conflicts anymore for the
highlighting features!_

## In Action

<!-- TODO: Replace demo with asciinema -->
![recording](https://github.com/tzachar/highlight-undo.nvim/assets/4946827/81b85a3b-b563-4e97-b4e1-7a48d0d2f912)

## Installation

Install the plugin with your favorite plugin-manger.

With [folke/lazy.nvim](https://github/folke/lazy.nvim),

```lua
  {
    "aileot/emission.nvim",
    opts = {},
  },
```

## Setup

defaults:

```lua
require("emission").setup({
  min_recache_interval = 50,
  excluded_filetypes = {
    "lazy",
    "oil",
  },
  added = {
    priority = 100,
    duration = 400, -- milliseconds
    -- The same options for `nvim_set_hl()` at `{val}` is available.
    -- NOTE: With "default" key set to `true`, you can arrange the highlight
    -- groups `EmissionAdded` and `EmissionRemoved` highlight groups
    -- respectively, based on your colorscheme.
    hl_map = { default = true, fg = "#dcd7ba", bg = "#2d4f67" },
    filter = function(bufnr) end, -- See below for examples.
  },
  removed = {
    -- The same options as `added` are available.
    -- Note that the default values might be different from `added` ones.
    priority = 100,
    duration = 300,
    hl_map = { default = true, fg = "#dcd7ba", bg = "#672d2d" },
    filter = function(bufnr) end,
  },
})
```

### Recommended filter settings

```lua
---@param buf number attached buffer handle
---@return boolean true to highlight, false to ignore
local filter = function(buf)
  if not vim.api.nvim_get_mode().mode:find("n") then
    return false
  end
  if vim.fn.reg_executing() ~= "" then
    return false
  end
  return true
end

require("emission").setup({
  ...
  added = {
    ...
    filter = filter,
  },
  removed = {
    ...
    filter = filter,
  },
})
```

Note: For performance reason, it is recommended to use the
`excluded_filetypes` option to exclude specific filetype buffers.
