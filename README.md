# ✨ emission.nvim

A fork of [tzachar/highlight-undo.nvim](https://github.com/tzachar/highlight-undo.nvim).

Highlight added/removed texts in current buffer, anywhere, anytime, as well as
undo/redo.
You can filter the highlight occasions by changed text length, Vim's mode,
etc.

Note: Unlike `highlight-undo.nvim` does, `emission.nvim` does not let you
alter `hlgroup`s for undo/redo, but only for added/removed.

## In Action

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
    hlgroup = "EmissionAdded",
    priority = 100,
    duration = 400, -- milliseconds
    filter = function(bufnr) end, -- See below for examples.
  },
  removed = {
    hlgroup = "EmissionRemoved",
    priority = 100,
    duration = 300, -- milliseconds
    filter = function(bufnr) end, -- See below for examples.
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
