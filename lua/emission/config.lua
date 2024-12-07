local logger = require("emission.utils.logger")

local M = {}
local user_config, last_config

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
    filter = function(_buf)
      return true
    end,
    ---@type string[] Autocmd events
    additional_recache_events = { "InsertLeave" },
    delay = 10,
  },
  ---@class emission.Config.Added
  added = {
    priority = 102,
    ---@type HlMap options for the 3rd arg of `nvim_set_hl()`
    hl_map = { default = true, bold = true, fg = "#dcd7ba", bg = "#2d4f67" },
  },
  ---@class emission.Config.Removed
  removed = {
    priority = 101,
    ---@type HlMap options for the 3rd arg of `nvim_set_hl()`
    hl_map = { default = true, bold = true, fg = "#dcd7ba", bg = "#672d2d" },
  },
}

last_config = default_config

--- Make sure to override table config, which does not make sense to be
--- merged.
---@param opts emission.Config
---@return emission.Config
local function override_table_opts(opts)
  if opts.added and opts.added.hl_map then
    user_config.added.hl_map = opts.added.hl_map
  end
  if opts.removed and opts.removed.hl_map then
    user_config.removed.hl_map = opts.removed.hl_map
  end
  return user_config
end

--- Merge given `opts` into default config.
---@param opts? emission.Config
---@return emission.Config
M.merge = function(opts)
  opts = opts or {}
  user_config = vim.tbl_deep_extend("keep", opts, default_config)
  user_config = override_table_opts(opts)
  last_config = user_config
  return user_config
end

--- Override current config with given `opts`.
---@param opts emission.Config
---@return emission.Config
M.override = function(opts)
  user_config = vim.tbl_deep_extend("keep", opts or {}, user_config)
  user_config = override_table_opts(opts)
  return user_config
end

--- Reset current config to the last config determined by .merge().
---@return emission.Config
M.reset = function()
  user_config = last_config
  return user_config
end

return M
