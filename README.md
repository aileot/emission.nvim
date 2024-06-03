# highlight-undo.nvim

A fork of [tzachar/highlight-undo.nvim](https://github/tzachar/highlight-undo.nvim).

Highlight added/removed texts in current buffer, anywhere, anytime, as well as
undo/redo.
You can filter the highlight occasions by changed text length, Vim's mode,
etc.

Note: Unlike `highlight-undo.nvim` does, `hl-big-change.nvim` does not let you
alter `hlgroup`s for undo/redo, but only for added/removed.

## In Action

![recording](https://github.com/tzachar/highlight-undo.nvim/assets/4946827/81b85a3b-b563-4e97-b4e1-7a48d0d2f912)

## Installation

Install the plugin with your favorite plugin-manger.

With [folke/lazy.nvim](https://github/folke/lazy.nvim),

```lua
  {
    "aileot/hl-big-change.nvim",
    opts = {},
  },
```

## Setup

```lua
require("hl-big-change").setup({
  duration = 400,
  added = {
    hlgroup = "HlBigChangeAdded",
  },
  redo = {
    hlgroup = "HlBigChangeRemoved",
  },
})
```

## `duration`

The duration (in milliseconds) to highlight changes. Default is 300.

## `hlgroup`

The highlighting group to use.

## How the Plugin Works

Unlike `highlight-undo`, `hl-big-change` does not work on keymaps, but just on
`nvim_buf_attach`.
