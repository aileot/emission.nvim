local M = {config = {attach_delay = 100, duration = 400, hlgroup = {added = "HlBigChangeAdded", removed = "HlBigChangeRemoved"}}, timer = (vim.uv or vim.loop).new_timer()}
local namespace = vim.api.nvim_create_namespace("HlBigChange")
local function open_folds_on_undo()
  if vim.tbl_contains((vim.opt.foldopen):get(), "undo") then
    return vim.cmd("normal! zv")
  else
    return nil
  end
end
local function on_bytes(_ignored, bufnr, _changedtick, start_row, start_col, _byte_offset, old_end_row, old_end_col, _old_end_byte, new_end_row, new_end_col, _new_end_byte)
  local function _2_(...)
    return (vim.api.nvim_get_mode().mode):find("n")
  end
  if (vim.api.nvim_buf_is_valid(bufnr) and _2_()) then
    if ((old_end_row == start_row) and (new_end_row == start_row) and (old_end_col <= (new_end_col + 1))) then
      local hlgroup = M.config.hlgroup.added
      local num_lines = vim.api.nvim_buf_line_count(0)
      local end_row = (start_row + new_end_row)
      local end_col
      if (num_lines < end_row) then
        end_col = #vim.api.nvim_buf_get_lines(0, -2, -1, false)[1]
      else
        end_col = (start_col + new_end_col)
      end
      open_folds_on_undo()
      local function _4_()
        if vim.api.nvim_buf_is_valid(bufnr) then
          vim.highlight.range(bufnr, namespace, hlgroup, {start_row, start_col}, {end_row, end_col})
          return M.clear_highlights(bufnr)
        else
          return nil
        end
      end
      return vim.schedule(_4_)
    else
      return nil
    end
  else
    return nil
  end
end
M.clear_highlights = function(bufnr)
  do end (M.timer):stop()
  local function _8_()
    local function _9_()
      if vim.api.nvim_buf_is_valid(bufnr) then
        return vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      else
        return nil
      end
    end
    return vim.schedule(_9_)
  end
  return (M.timer):start(M.config.duration, 0, _8_)
end
local last_bufnr = -1
local wipedout_bufnrs = {}
M.setup = function(config)
  local id = vim.api.nvim_create_augroup("HlBigChange", {})
  M.config = vim.tbl_deep_extend("keep", (config or {}), M.config)
  vim.api.nvim_set_hl(0, "HlBigChangeAdded", {default = true, bg = "#2d4f67", fg = "#dcd7ba"})
  vim.api.nvim_set_hl(0, "HlBigChangeRemoved", {default = true, bg = "#dcd7ba", fg = "#2d4f67"})
  local function _11_(a)
    wipedout_bufnrs[a.buf] = true
    return nil
  end
  vim.api.nvim_create_autocmd("BufWipeout", {group = id, callback = _11_})
  local function _12_(a)
    if wipedout_bufnrs[a.buf] then
      wipedout_bufnrs[a.buf] = nil
    elseif (a.buf < last_bufnr) then
      return 
    else
    end
    last_bufnr = a.buf
    local function _14_()
      if vim.api.nvim_buf_is_valid(a.buf) then
        return vim.api.nvim_buf_attach(a.buf, false, {on_bytes = on_bytes})
      else
        return nil
      end
    end
    return vim.defer_fn(_14_, M.config.attach_delay)
  end
  return vim.api.nvim_create_autocmd("BufWinEnter", {group = id, callback = _12_})
end
return M
