local logger = require("emission.utils.logger")

local M = {}
local user_config

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
    min_row_offset = 0,
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
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- texts
    filter = function(ctx)
      return true
    end,
  },
  ---@class emission.Config.Removed
  removed = {
    priority = 101,
    ---@type HlMap options for the 3rd arg of `nvim_set_hl()`
    hl_map = { default = true, bold = true, fg = "#dcd7ba", bg = "#672d2d" },
    ---@param ctx emission.Filter.Context
    ---@return boolean Return false or nil to ignore; otherwise, highlight
    --- texts
    filter = function(ctx)
      return true
    end,
  },
}

M.merge = function(opts)
  user_config = vim.tbl_deep_extend("keep", opts or {}, default_config)
  return user_config
end

return M
