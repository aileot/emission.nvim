-- This module highlights reference usages and the corresponding
-- definition on cursor hold.

local M = {
  config = {
    attach_delay = 100,
    duration = 400,
    hlgroup = { added = "HlBigChangeAdded", removed = "HlBigChangeRemoved" },
  },
  timer = (vim.uv or vim.loop).new_timer(),
}

local namespace = vim.api.nvim_create_namespace("HlBigChange")

---makes highlight-undo respect `foldopen=undo` (#18)
local function open_folds_on_undo()
  if vim.tbl_contains(vim.opt.foldopen:get(), "undo") then
    vim.cmd.normal({ "zv", bang = true })
  end
end

local function on_bytes(
  ignored, ---@diagnostic disable-line
  bufnr, ---@diagnostic disable-line
  changedtick, ---@diagnostic disable-line
  start_row, ---@diagnostic disable-line
  start_col, ---@diagnostic disable-line
  byte_offset, ---@diagnostic disable-line
  old_end_row, ---@diagnostic disable-line
  old_end_col, ---@diagnostic disable-line
  old_end_byte, ---@diagnostic disable-line
  new_end_row, ---@diagnostic disable-line
  new_end_col, ---@diagnostic disable-line
  new_end_byte ---@diagnostic disable-line
)
  -- vim.print(
  --   {
  --     ignored = ignored,
  --     bufnr = bufnr,
  --     changedtick = changedtick,
  --     start_row = start_row,
  --     start_col = start_col,
  --     byte_off = byte_offset,
  --     old_end_row = old_end_row,
  --     old_end_col = old_end_col,
  --     old_end_byte = old_end_byte,
  --     new_end_row = new_end_row,
  --     new_end_col = new_end_col,
  --     new_end_byte = new_end_byte,
  --   }
  -- )
  if not vim.api.nvim_buf_is_valid(bufnr) then
    -- Return true to detach.
    return true
  elseif
    not vim.api.nvim_get_mode().mode:find("n")
    -- (old_end_row < start_row and new_end_row < start_row)
    or (
      old_end_row == start_row
      and new_end_row == start_row
      and old_end_col <= new_end_col + 1
    )
  then
    -- Skip if single char change
    return
  end
  -- defer highlight till after changes take place..
  local end_row = start_row + new_end_row
  local end_col = start_col + new_end_col
  local num_lines = vim.api.nvim_buf_line_count(0)
  if end_row >= num_lines then
    -- we are past the last line. highlight till the last column
    end_col = #vim.api.nvim_buf_get_lines(0, -2, -1, false)[1]
  end
  open_folds_on_undo()
  local hlgroup = M.config.hlgroup.added
  -- TODO: Show extmark for Removed texts.
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    vim.highlight.range(
      bufnr,
      namespace,
      hlgroup,
      { start_row, start_col },
      { end_row, end_col }
    )
    M.clear_highlights(bufnr)
  end)
end

function M.clear_highlights(bufnr)
  M.timer:stop()
  M.timer:start(
    M.config.duration,
    0,
    vim.schedule_wrap(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      end
    end)
  )
end

function M.setup(config)
  vim.api.nvim_set_hl(0, "HlBigChangeAdded", {
    fg = "#dcd7ba",
    bg = "#2d4f67",
    default = true,
  })
  vim.api.nvim_set_hl(0, "HlBigChangeRemoved", {
    fg = "#2d4f67",
    bg = "#dcd7ba",
    default = true,
  })
  M.config = vim.tbl_deep_extend("keep", config or {}, M.config)
  local id = vim.api.nvim_create_augroup("HlBigChangeAdded", {})
  vim.api.nvim_create_autocmd("BufWinEnter", {
    group = id,
    callback = function(a)
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(a.buf) then
          vim.api.nvim_buf_attach(a.buf, false, {
            on_bytes = on_bytes,
          })
        end
      end, M.config.attach_delay)
    end,
  })
end

return M
