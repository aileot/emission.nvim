local cache = {config = {duration = 400, excluded_filetypes = {"lazy", "oil"}, added = {hlgroup = "EmissionAdded"}, removed = {hlgroup = "EmissionRemoved"}}, timer = vim.uv.new_timer(), ["attached-buffer"] = nil, ["buffer->detach"] = {}, ["last-texts"] = nil}
local namespace = vim.api.nvim_create_namespace("Emission")
local function inc(x)
  return (x + 1)
end
local function dec(x)
  return (x - 1)
end
local function cache_last_texts(bufnr)
  cache["last-texts"] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
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
  cache.timer:stop()
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
  return cache.timer:start(cache.config.duration, 0, _2_)
end
local function glow_added_texts(bufnr, _5_, _6_)
  local start_row0 = _5_[1]
  local start_col = _5_[2]
  local new_end_row_offset = _6_[1]
  local new_end_col_offset = _6_[2]
  local hlgroup = cache.config.added.hlgroup
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
  local hlgroup = cache.config.removed.hlgroup
  local last_texts = cache["last-texts"]
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
  if cache["buffer->detach"][bufnr] then
    cache["buffer->detach"][bufnr] = nil
  else
  end
  local and_22_ = vim.api.nvim_buf_is_valid(bufnr)
  if and_22_ then
    and_22_ = vim.api.nvim_get_mode().mode:find("n")
  end
  if and_22_ then
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
local function excluded_buffer_3f(buf)
  return vim.list_contains(cache.config.excluded_filetypes, vim.bo[buf].filetype)
end
local function attach_buffer_21(buf)
  cache["attached-buffer"] = buf
  cache["buffer->detach"][buf] = nil
  cache_last_texts(buf)
  return vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
end
local function request_to_attach_buffer_21(buf)
  if not excluded_buffer_3f(buf) then
    local function _25_()
      if vim.api.nvim_buf_is_valid(buf) then
        return attach_buffer_21(buf)
      else
        return nil
      end
    end
    vim.schedule(_25_)
  else
  end
  return nil
end
local function request_to_detach_buffer_21(buf)
  if not cache["attached-buffer"][buf] then
    cache["buffer->detach"][buf] = true
    return nil
  else
    return nil
  end
end
local function setup(opts)
  local id = vim.api.nvim_create_augroup("Emission", {})
  cache.config = vim.tbl_deep_extend("keep", (opts or {}), cache.config)
  vim.api.nvim_set_hl(0, "EmissionAdded", {default = true, fg = "#dcd7ba", bg = "#2d4f67"})
  vim.api.nvim_set_hl(0, "EmissionRemoved", {default = true, fg = "#dcd7ba", bg = "#672d2d"})
  attach_buffer_21(vim.api.nvim_get_current_buf())
  local function _29_(_241)
    return request_to_attach_buffer_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _29_})
  local function _30_(_241)
    return request_to_detach_buffer_21(_241.buf)
  end
  return vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _30_})
end
return {setup = setup}
