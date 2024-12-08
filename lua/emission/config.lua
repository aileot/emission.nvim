local logger = require("emission.utils.logger")

local M = {
  _config = {},
}
local last_config

---@class emission.Filter.Context
---@field buf integer

---@alias HlMap table<string,any> options for the 3rd arg of `nvim_set_hl()`

---@class emission.Config
local default_config = {
  debug = logger["debug-config"],
  ---@class emission.Config.Attach
  attach = {
    delay = 150,
    ---@type string[]
    excluded_filetypes = {},
    ---@type string[]
    excluded_buftypes = { "help", "nofile", "terminal", "prompt" },
  },
  ---@class emission.Config.Highlight
  highlight = {
    duration = 300,
    min_byte = 2,
    ---@deprecated Use {added,removed}.filter instead
    filter = function(_buf)
      return true
    end,
    ---@type string[] Autocmd events
    additional_recache_events = { "InsertLeave" },
    delay = 10,
  },
  ---@class emission.Config.Added
  added = {
    -- Set it to false to disable highlights on added texts regardless of the
    -- other filter options.
    enabled = true,
    priority = 102,
    ---@type HlMap options for the 3rd arg of `nvim_set_hl()`
    hl_map = { default = true, bold = true, fg = "#dcd7ba", bg = "#2d4f67" },
    min_byte = 2,
    min_row_offset = 0,
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- added texts.
    filter = function(ctx)
      assert(type(ctx.buf) == "number")
      return true
    end,
  },
  ---@class emission.Config.Removed
  removed = {
    -- Set it to false to disable highlights on removed texts regardless of
    -- the other filter options.
    enabled = true,
    priority = 101,
    ---@type HlMap options for the 3rd arg of `nvim_set_hl()`
    hl_map = { default = true, bold = true, fg = "#dcd7ba", bg = "#672d2d" },
    min_byte = 2,
    min_row_offset = 0,
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- removed texts.
    filter = function(ctx)
      assert(type(ctx.buf) == "number")
      return true
    end,
  },
  ---@alias AutocmdEvent string|string[] the 1st arg of `nvim_create_autocmd()
  ---@alias AutocmdOpts table the 2nd arg of `nvim_create_autocmd()`
  ---@alias emission.Config.OnEvents table<AutocmdEvent,AutocmdOpts[]>
  --- A option to help create autocmds dedicated to emission.
  ---@type emission.Config.OnEvents
  on_events = {},
}

M._config = default_config
last_config = M._config

--- Make sure to override table config, which does not make sense to be
--- merged.
---@param opts emission.Config
---@return emission.Config
local function override_table_opts(opts)
  if opts.added and opts.added.hl_map then
    M._config.added.hl_map = opts.added.hl_map
  end
  if opts.removed and opts.removed.hl_map then
    M._config.removed.hl_map = opts.removed.hl_map
  end
  return M._config
end

--- Merge given `opts` into default config.
---@param opts? emission.Config
---@return emission.Config
M.merge = function(opts)
  opts = opts or {}
  M._config = vim.tbl_deep_extend("keep", opts, default_config)
  M._config = override_table_opts(opts)
  if M._config.highlight.filter ~= default_config.highlight.filter then
    vim.deprecate(
      "highlight.filter",
      "{added,removed}.filter",
      "2.0.0",
      "emission.nvim"
    )
  end
  last_config = M._config
  return M._config
end

--- Override current config with given `opts`.
---@param opts emission.Config
---@return emission.Config
M.override = function(opts)
  M._config = vim.tbl_deep_extend("keep", opts or {}, M._config)
  M._config = override_table_opts(opts)
  return M._config
end

--- Reset current config to the last config determined by .merge().
---@return emission.Config
M.reset = function()
  M._config = last_config
  return M._config
end

return M
