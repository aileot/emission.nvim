# ✨ emission.nvim

A fork of [tzachar/highlight-undo.nvim](https://github/tzachar/highlight-undo.nvim).

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
  duration = 400, -- milliseconds
  excluded_filetypes = {
    "lazy",
    "oil",
  },
  added = {
    hlgroup = "EmissionAdded",
    modes = { "n", "no", "nov", "noV", "no\\22" },
    priority = 100,
    duration = 400, -- milliseconds
  },
  removed = {
    hlgroup = "EmissionRemoved",
    modes = { "n", "no", "nov", "noV", "no\\22" },
    priority = 100,
    duration = 300, -- milliseconds
  },
})
```