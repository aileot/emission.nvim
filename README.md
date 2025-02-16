<div align="center">

# ✨ emission.nvim

[![badge/test][]][url/to/workflow/test]
[![badge/semver][]][url/to/semver]
[![badge/license][]][url/to/license]\
[![badge/lua][]][url/to/lua]
[![badge/fennel][]][url/to/fennel]

<!--
NOTE: The colors come from the palette of catppuccin-mocha:
https://github.com/catppuccin/catppuccin/tree/v0.2.0?tab=readme-ov-file#-palettes
-->

[badge/test]: https://img.shields.io/github/actions/workflow/status/aileot/emission.nvim/test.yml?branch=main&label=Test&logo=github&style=for-the-badge&logo=neovim&logoColor=CDD6F4&labelColor=1E1E2E&color=a6e3a1
[badge/semver]: https://img.shields.io/github/v/release/aileot/emission.nvim?style=for-the-badge&logo=starship&logoColor=CDD6F4&labelColor=1E1E2E&&color=cdd6f4&include_prerelease&sort=semver
[badge/license]: https://img.shields.io/github/license/aileot/emission.nvim?style=for-the-badge&logoColor=CDD6F4&labelColor=1E1E2E&color=eba0ac
[badge/lua]: https://img.shields.io/badge/Powered_by_Lua-030281?&style=for-the-badge&logo=lua&logoColor=CDD6F4&label=Lua&labelColor=1E1E2E&color=cba6f7
[badge/fennel]: https://img.shields.io/badge/&_Fennel-030281?&style=for-the-badge&logo=lua&logoColor=cdd6f4&label=Lua&labelColor=1E1E2E&color=cba6f7
[url/to/workflow/test]: https://github.com/aileot/emission.nvim/actions/workflows/test.yml
[url/to/license]: ./LICENSE
[url/to/semver]: https://github.com/aileot/emission.nvim/releases/latest
[url/to/lua]: https://www.lua.org/
[url/to/fennel]: https://fennel-lang.org/

_A generalized fork of
[tzachar/highlight-undo.nvim]
rewritten in Fennel with
[antifennel]._

</div>

## Features

- Highlights for **added** texts.
- Highlights for **removed** texts like afterimage.
- **No** keymap conflicts.

<details>
<summary>
The differences from
<a href=https://github.com/tzachar/highlight-undo.nvim>
highlight-undo.nvim</a>
</summary>
Since the
<a href=https://github.com/tzachar/highlight-undo.nvim/commit/cc802af09bc2bb1e018b9cd5325647d771aed807>
commit</a>,
highlight-undo.nvim
has discarded the previous highlight occasions
limited to undo/redo,
and highlight any text changes as
<a href=https://github.com/aileot/emission.nvim>
emission.nvim</a>
does.
Now, the differences are only

- Tested
- Provided options
  - Different highlight settings for "added" or "removed" respectively.
  - Filters (with sane defaults)
    - by changed byte size
    - by changed row offset
    - by modes (not limited to Normal mode)
    - ...

</details>

<!-- panvimdoc-ignore-start -->

## Demo

![demo-emission.nvim](https://github.com/user-attachments/assets/31abf6b7-f970-4afa-990f-6547d774999c)

<!-- panvimdoc-ignore-end -->

## Requirements

- Neovim >= 0.10.2

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
    excluded_buftypes = {
      "help",
      "nofile",
      "terminal",
      "prompt",
    },
    -- NOTE: Nothing is excluded by default. Add any as you need, but check
    -- the 'buftype' at first.
    excluded_filetypes = {
      -- "oil",
    },
  },
  highlight = {
    duration = 300, -- milliseconds
    ---@deprecated Use {added,removed}.min_byte instead
    min_byte = 2, -- minimum bytes to highlight texts
    ---@deprecated Use {added,removed}.filter instead
    filter = function(buf)
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
    -- Set it to false to disable highlights on added texts regardless of
    -- the other filter options.
    enabled = true,
    priority = 102,
    -- The options for `vim.api.nvim_set_hl(0, "EmissionAdded", {hl_map})`.
    -- NOTE: If you keep "default" key set to `true`, you can arrange the
    -- highlight groups hl-EmissionAdded by nvim_set_hl(), based on your
    -- colorscheme.
    -- NOTE: You can use "link" key to link the highlight settings to an
    -- existing highlight group like hl-DiffAdd.
    hl_map = {
      default = true,
      bold = true,
      fg = "#dcd7ba",
      bg = "#2d4f67",
    },
    min_byte = 2, -- minimum bytes to highlight texts
    min_row_offset = 0, -- minimum row offset to highlight texts
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- added texts.
    filter = function(ctx)
      -- See below for examples.
      assert(type(ctx.buf) == "number")
      return true
    end,
  },
  -- The same options as `added` are available.
  -- Note that the default values might be different from `added` ones.
  removed = {
    -- Set it to false to disable highlights on removed texts regardless of
    -- the other filter options.
    enabled = true,
    priority = 101,
    -- The options for `vim.api.nvim_set_hl(0, "EmissionRemoved", {hl_map})`.
    hl_map = {
      default = true,
      bold = true,
      fg = "#dcd7ba",
      bg = "#672d2d",
    },
    min_byte = 2, -- minimum bytes to highlight texts
    min_row_offset = 0, -- minimum row offset to highlight texts
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- removed texts.
    filter = function(ctx)
      -- See below for examples.
      assert(type(ctx.buf) == "number")
      return true
    end,
  },
  --- A option to help create autocmds dedicated to emission.
  --- See below for examples.
  on_events = {},
})
```

### Recommended Filter Settings

In the following example, `added`/`removed` highlights are restricted to
`normal` mode. Additionally, it will never highlight during recorded macro
execution.

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
  added = {
    -- Set other options at `added`...
    filter = filter,
  },
  removed = {
    -- Set other options at `removed`...
    -- You can also set another filter apart from `added` one.
    filter = filter,
  },
})
```

### Modify Options on Autocmd Events

Emission provides an helper interface `on_events`
to manage emission options on autocmd events.

For the purpose, there are the functions
`require("emission").override({})`
and
`require("emission").reset()`
are provided,
since `require("emission").setup()` is always merged with the default config.

#### on_events

```lua
require("emission").setup({
  on_events = {
    ModeChanged = {
      {
        desc = "Disable emission in certain occasions",
        pattern = "*",
        callback = function(a)
          local old_mode, new_mode = a.match:match("(.+):(.+)")
          if old_mode == "no" then
            -- Do not emit highlights for texts removed within 1 row via
            -- Operator-pending mode.
            require("emission").override({
              removed = {
                min_row_offset = 1,
              },
            })
            return
          elseif old_mode:find("[vV\22]") then
            -- Disable emissions on texts removed from Visual mode.
            require("emission").override({
              removed = {
                enabled = false,
              },
            })
            return
          else
            require("emission").reset()
            return
          end
        end,
      },
    },
  },
})
```

## Highlights

### hl-EmissionAdded

The highlight group used to highlight added texts.
As you can see in the [Setup](#setup) snippet above, you can override the highlight
using `added.hl_map` field in `setup()`.
You can also customize the highlight with `vim.api.nvim_set_hl()` directly
to adapt the color to your favorite colorscheme.

### hl-EmissionRemoved

The highlight group used to highlight removed texts.
As you can see in the [Setup](#setup) snippet above, you can override the highlight
using `removed.hl_map` field in `setup()`.
You can also customize the highlight with `vim.api.nvim_set_hl()` directly
to adapt the color to your favorite colorscheme.

## Related Projects

- [tzachar/highlight-undo.nvim]
  highlights texts added by pre-registered mappings.
- [yuki-yano/highlight-undo.nvim]
  works on [denops.vim].
- [machakann/vim-highlightedundo]
  is written in Vimscript.

[antifennel]: https://git.sr.ht/~technomancy/antifennel
[denops.vim]: https://github.com/vim-denops/denops.vim
[folke/lazy.nvim]: https://github.com/folke/lazy.nvim
[tzachar/highlight-undo.nvim]: https://github.com/tzachar/highlight-undo.nvim
[yuki-yano/highlight-undo.nvim]: https://github.com/yuki-yano/highlight-undo.nvim
[machakann/vim-highlightedundo]: https://github.com/machakann/vim-highlightedundo
