# ✨ emission.nvim

A generalized fork of
[tzachar/highlight-undo.nvim]
rewritten in Fennel with
[antifennel].

## Features

- Highlights for **added** texts
- Highlights for **removed** texts
- **No** keymap conflicts

NOTE: Unlike `highlight-undo.nvim` does, `emission.nvim` does NOT distinguish
`undo`/`redo`, but only `added`/`removed`.

## Demo

<!-- TODO: Replace demo with asciinema -->

![recording](https://github.com/tzachar/highlight-undo.nvim/assets/4946827/81b85a3b-b563-4e97-b4e1-7a48d0d2f912)

## Requirements

- Neovim >= 0.9.5

## Installation

Install the plugin with your favorite plugin-manger.

With [folke/lazy.nvim],

```lua
  {
    "aileot/emission.nvim",
    event = "VeryLazy",
    opts = {},
  },
```

## Setup

Just set up the plugin as follows:

```lua
require("emission").setup()
```

The default settings:

```lua
require("emission").setup({
  attach = {
    -- Useful to avoid extra attaching attempts in simultaneous buffer editing
    -- such as `:bufdo` or `:cdo`.
    delay = 150,
    excluded_filetypes = {
      -- NOTE: Nothing is excluded by default. Add any as you need, but check
      -- the 'buftype' at first.
      -- "oil",
    },
    excluded_buftypes = {
      "help",
      "nofile",
      "terminal",
      "prompt"
    },
  },
  highlight = {
    duration = 300, -- milliseconds
    min_byte = 2, -- minimum bytes to highlight texts
    filter = function(buf) -- See below for examples.
      return true
    end,
    -- NOTE: Buffer texts watched by emission.nvim are cached for the removed
    -- text highlight feature when the buffer is attached and after each
    -- set of highlight emissions.
    -- However, `min_byte` and `filter` options are likely to prevent
    -- necessary recaches. The default value "InsertLeave" forces texts to
    -- be re-cached regardless of the option values.
    -- Please add |autocmd-events| properly if emitted highlight texts are
    -- outdated with your filter settings.
    additional_recache_events = { "InsertLeave" },
  },
  added = {
    priority = 102,
    -- The same options for `nvim_set_hl()` at `{val}` is available.
    -- NOTE: With "default" key set to `true`, you can arrange the highlight
    -- groups `EmissionAdded` and `EmissionRemoved` highlight groups
    -- respectively, based on your colorscheme.
    hl_map = {
      default = true,
      bold = true,
      fg = "#dcd7ba",
      bg = "#2d4f67",
    },
  },
  -- The same options as `added` are available.
  -- Note that the default values might be different from `added` ones.
  removed = {
    priority = 101,
    hl_map = {
      default = true,
      bold = true,
      fg = "#dcd7ba",
      bg = "#672d2d",
    },
  },
})
```

### Recommended filter settings

In the following example, highlighting is restricted to `normal` mode.
Additionally, it will never highlight during recorded macro execution.

```lua
---@param buf number attached buffer handle
---@return boolean Return false or nil to ignore; otherwise, highlight texts
local filter = function(buf)
  -- Do not highlight during executing macro.
  if vim.fn.reg_executing() ~= "" then
    return false
  end
  -- Do not highlight except in Normal mode.
  if not vim.api.nvim_get_mode().mode:find("n") then
    return false
  end
  return true
end

require("emission").setup({
  -- Set other options...
  highlight = {
    -- Set other options at `highlight`...
    filter = filter,
  },
})
```

## Highlights

### hl-EmissionAdded

The highlight group used to highlight added texts.
As you can see in the `setup` snippet above, you can override the highlight
using `added.hl_map` field in `setup()`.
You can also customize the highlight with `vim.api.nvim_set_hl()`
to adapt the color to your favorite colorscheme.

### hl-EmissionRemoved

The highlight group used to highlight removed texts.
As you can see in the `setup` snippet above, you can override the highlight
using `removed.hl_map` field in `setup()`.
You can also customize the highlight with `vim.api.nvim_set_hl()`
to adapt the color to your favorite colorscheme.

## Related Projects

- [tzachar/highlight-undo.nvim]
  highlights texts added by pre-registered mappings.
- [yuki-yano/highlight-undo.nvim]
  works on [denops.vim].

[antifennel]: https://git.sr.ht/~technomancy/antifennel
[denops.vim]: https://github.com/vim-denops/denops.vim
[folke/lazy.nvim]: https://github.com/folke/lazy.nvim
[tzachar/highlight-undo.nvim]: https://github.com/tzachar/highlight-undo.nvim
[yuki-yano/highlight-undo.nvim]: https://github.com/yuki-yano/highlight-undo.nvim
