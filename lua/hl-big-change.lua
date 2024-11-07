local M = {config = {attach_delay = 100, duration = 400, excluded_filetypes = {}, hlgroup = {added = "HlBigChangeAdded", removed = "HlBigChangeRemoved"}}, timer = vim.uv.new_timer()}
local namespace = vim.api.nvim_create_namespace("HlBigChange")
local function open_folds_on_undo()
  local foldopen = vim.opt.foldopen:get()
  if (vim.list_contains(foldopen, "undo") or vim.list_contains(foldopen, "all")) then
    return vim.cmd("normal! zv")
  else
    return nil
  end
end
local function clear_highlights(bufnr)
  M.timer:stop()
  local function _2_()
    local function _3_()
      if vim.api.nvim_buf_is_valid(bufnr) then
        return vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      else
        return nil
      end
    end
    return vim.schedule(_3_)
  end
  return M.timer:start(M.config.duration, 0, _2_)
end
local function glow_added_texts(bufnr, _5_, _6_)
  local start_row0 = _5_[1]
  local start_col = _5_[2]
  local new_end_row_offset = _6_[1]
  local new_end_col_offset = _6_[2]
  local hlgroup = M.config.hlgroup.added
  local num_lines = vim.api.nvim_buf_line_count(bufnr)
  local end_row = (start_row0 + new_end_row_offset)
  local end_col
  if (end_row < num_lines) then
    end_col = (start_col + new_end_col_offset)
  else
    end_col = #vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
  end
  local function _8_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_on_undo()
      vim.highlight.range(bufnr, namespace, hlgroup, {start_row0, start_col}, {end_row, end_col})
      return clear_highlights(bufnr)
    else
      return nil
    end
  end
  return vim.schedule(_8_)
end
local function on_bytes(_string_bytes, bufnr, _changedtick, start_row0, start_col, _byte_offset, old_end_row_offset, old_end_col_offset, _old_end_byte_offset, new_end_row_offset, new_end_col_offset, _new_end_byte_offset)
  local and_10_ = vim.api.nvim_buf_is_valid(bufnr)
  if and_10_ then
    and_10_ = vim.api.nvim_get_mode().mode:find("n")
  end
  if and_10_ then
    if ((old_end_row_offset < new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (old_end_col_offset < new_end_col_offset))) then
      return glow_added_texts(bufnr, {start_row0, start_col}, {new_end_row_offset, new_end_col_offset})
    else
      return nil
    end
  else
    return nil
  end
end
local biggest_bufnr = -1
local wipedout_bufnrs = {}
local function excluded_buffer_3f(buf)
  return vim.list_contains(M.config.excluded_filetypes, vim.bo[buf].filetype)
end
local function attach_buffer_21(buf)
  return vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
end
local function setup(opts)
  local id = vim.api.nvim_create_augroup("HlBigChange", {})
  M.config = vim.tbl_deep_extend("keep", (opts or {}), M.config)
  vim.api.nvim_set_hl(0, "HlBigChangeAdded", {default = true, fg = "#dcd7ba", bg = "#2d4f67"})
  vim.api.nvim_set_hl(0, "HlBigChangeRemoved", {default = true, fg = "#dcd7ba", bg = "#672d2d"})
  local function _21_(a)
    wipedout_bufnrs[a.buf] = true
    return nil
  end
  vim.api.nvim_create_autocmd("BufWipeout", {group = id, callback = _13_})
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not excluded_buffer_3f(buf) then
      attach_buffer_21(buf)
    else
    end
  end
  local function _15_(a)
    if wipedout_bufnrs[a.buf] then
      wipedout_bufnrs[a.buf] = nil
    elseif ((biggest_bufnr < a.buf) and excluded_buffer_3f(a.buf)) then
      local function _16_()
        biggest_bufnr = a.buf
        if vim.api.nvim_buf_is_valid(a.buf) then
          return attach_buffer_21(a.buf)
        else
          return nil
        end
      end
      vim.defer_fn(_16_, M.config.attach_delay)
    else
    end
    return nil
  end
  return vim.api.nvim_create_autocmd("BufWinEnter", {group = id, callback = _15_})
end
return {setup = setup}
