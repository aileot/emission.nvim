local M = {config = {attach_delay = 100, duration = 400, excluded_filetypes = {"lazy", "oil"}, added = {hlgroup = "EmissionAdded"}, removed = {hlgroup = "EmissionRemoved"}}, timer = vim.uv.new_timer(), ["last-texts"] = {}}
local namespace = vim.api.nvim_create_namespace("Emission")
local function inc(x)
  return (x + 1)
end
local function dec(x)
  return (x - 1)
end
local function cache_last_texts(bufnr)
  M["last-texts"][bufnr] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return nil
end
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
  local hlgroup = M.config.added.hlgroup
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
local function glow_removed_texts(bufnr, _10_, _11_)
  local start_row0 = _10_[1]
  local start_col = _10_[2]
  local old_end_row_offset = _11_[1]
  local old_end_col_offset = _11_[2]
  local hlgroup = M.config.removed.hlgroup
  local last_texts = M["last-texts"][bufnr]
  local start_row = inc(start_row0)
  local first_removed_line
  local function _12_()
    if (0 == old_end_row_offset) then
      return (start_col + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = last_texts[start_row]:sub(inc(start_col), _12_())
  local _3fmiddle_removed_lines
  if (1 < old_end_row_offset) then
    _3fmiddle_removed_lines = vim.list_slice(last_texts, inc(start_row), (start_row + old_end_row_offset + -1))
  else
    _3fmiddle_removed_lines = nil
  end
  local _3flast_removed_line
  if (0 < old_end_row_offset) then
    _3flast_removed_line = last_texts[(start_row + old_end_row_offset)]:sub(1, old_end_col_offset)
  else
    _3flast_removed_line = nil
  end
  local removed_lines
  if _3fmiddle_removed_lines then
    removed_lines = vim.iter({first_removed_line, _3fmiddle_removed_lines, _3flast_removed_line}):flatten():totable()
  elseif _3flast_removed_line then
    removed_lines = {first_removed_line, _3flast_removed_line}
  else
    removed_lines = {first_removed_line}
  end
  local function _16_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_on_undo()
      do
        local start_col0 = dec(start_col)
        local max_idx
        if (0 == old_end_col_offset) then
          max_idx = (2 + old_end_row_offset)
        else
          max_idx = inc(old_end_row_offset)
        end
        for i = 1, max_idx do
          local line = removed_lines[i]
          local chunks
          if ((i == max_idx) and (0 == old_end_col_offset)) then
            chunks = {{""}}
          else
            chunks = {{line, hlgroup}}
          end
          local row0 = (start_row0 + i + -1)
          local col0
          if (i == 1) then
            col0 = inc(start_col0)
          elseif (i < old_end_row_offset) then
            col0 = 1
          else
            col0 = old_end_col_offset
          end
          local extmark_opts = {hl_eol = true, virt_text = chunks, virt_text_pos = "inline", strict = false}
          vim.api.nvim_buf_set_extmark(bufnr, namespace, row0, col0, extmark_opts)
        end
      end
      return clear_highlights(bufnr)
    else
      return nil
    end
  end
  return vim.schedule(_16_)
end
local function on_bytes(_string_bytes, bufnr, _changedtick, start_row0, start_col, _byte_offset, old_end_row_offset, old_end_col_offset, _old_end_byte_offset, new_end_row_offset, new_end_col_offset, _new_end_byte_offset)
  local and_21_ = vim.api.nvim_buf_is_valid(bufnr)
  if and_21_ then
    and_21_ = vim.api.nvim_get_mode().mode:find("n")
  end
  if and_21_ then
    if ((old_end_row_offset <= new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (old_end_col_offset <= new_end_col_offset))) then
      glow_added_texts(bufnr, {start_row0, start_col}, {new_end_row_offset, new_end_col_offset})
    else
      glow_removed_texts(bufnr, {start_row0, start_col}, {old_end_row_offset, old_end_col_offset})
    end
    return cache_last_texts(bufnr)
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
  cache_last_texts(buf)
  return vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
end
local function setup(opts)
  local id = vim.api.nvim_create_augroup("Emission", {})
  M.config = vim.tbl_deep_extend("keep", (opts or {}), M.config)
  vim.api.nvim_set_hl(0, "EmissionAdded", {default = true, fg = "#dcd7ba", bg = "#2d4f67"})
  vim.api.nvim_set_hl(0, "EmissionRemoved", {default = true, fg = "#dcd7ba", bg = "#672d2d"})
  local function _24_(a)
    wipedout_bufnrs[a.buf] = true
    return nil
  end
  vim.api.nvim_create_autocmd("BufWipeout", {group = id, callback = _24_})
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if not excluded_buffer_3f(buf) then
      attach_buffer_21(buf)
    else
    end
  end
  local function _26_(a)
    if wipedout_bufnrs[a.buf] then
      wipedout_bufnrs[a.buf] = nil
    elseif ((biggest_bufnr < a.buf) and not excluded_buffer_3f(a.buf)) then
      local function _27_()
        biggest_bufnr = a.buf
        if vim.api.nvim_buf_is_valid(a.buf) then
          return attach_buffer_21(a.buf)
        else
          return nil
        end
      end
      vim.defer_fn(_27_, M.config.attach_delay)
    else
    end
    return nil
  end
  return vim.api.nvim_create_autocmd("BufWinEnter", {group = id, callback = _26_})
end
return {setup = setup}
