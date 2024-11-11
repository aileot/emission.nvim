local cache
local function _1_()
end
local function _2_()
end
cache = {config = {excluded_filetypes = {"lazy", "oil"}, min_recache_interval = 50, added = {hlgroup = "EmissionAdded", duration = 400, filter = _1_}, removed = {hlgroup = "EmissionRemoved", duration = 300, filter = _2_}}, timer = vim.uv.new_timer(), ["last-duration"] = 0, ["last-editing-position"] = {0, 0}, ["attached-buffer"] = nil, ["buffer->detach"] = {}, ["last-recache-time"] = 0, ["last-texts"] = nil}
local namespace = vim.api.nvim_create_namespace("emission")
local vim_2fhl = (vim.hl or vim.highlight)
local function inc(x)
  return (x + 1)
end
local function dec(x)
  return (x - 1)
end
local function cache_last_texts(bufnr)
  local now = vim.uv.now()
  if ((bufnr ~= cache["attached-buffer"]) or (cache.config.min_recache_interval < (now - cache["last-recache-time"]))) then
    cache["last-recache-time"] = now
    cache["last-texts"] = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    cache["attached-buffer"] = bufnr
    return nil
  else
    return nil
  end
end
local function open_folds_at_cursor_21()
  local foldopen = vim.opt.foldopen:get()
  if (vim.list_contains(foldopen, "undo") or vim.list_contains(foldopen, "all")) then
    return vim.cmd("silent! . foldopen!")
  else
    return nil
  end
end
local function dismiss_deprecated_highlight_21(buf, _5_)
  local start_row0 = _5_[1]
  local start_col = _5_[2]
  do
    local _6_ = cache["last-editing-position"]
    if ((_G.type(_6_) == "table") and (_6_[1] == start_row0) and (_6_[2] == start_col)) then
      vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    else
      local _ = _6_
    end
  end
  cache["last-editing-position"] = {start_row0, start_col}
  return nil
end
local function dismiss_deprecated_highlights_21(buf, _8_)
  local start_row0 = _8_[1]
  local start_col = _8_[2]
  return dismiss_deprecated_highlight_21(buf, {start_row0, start_col})
end
local function clear_highlights(bufnr, duration)
  cache["last-duration"] = duration
  local function _9_()
    local function _10_()
      if vim.api.nvim_buf_is_valid(bufnr) then
        return vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      else
        return nil
      end
    end
    return vim.schedule(_10_)
  end
  return cache.timer:start(duration, 0, _9_)
end
local function glow_added_texts(bufnr, _12_, _13_)
  local start_row0 = _12_[1]
  local start_col = _12_[2]
  local new_end_row_offset = _13_[1]
  local new_end_col_offset = _13_[2]
  local hlgroup = cache.config.added.hlgroup
  local num_lines = vim.api.nvim_buf_line_count(bufnr)
  local end_row = (start_row0 + new_end_row_offset)
  local end_col
  if (end_row < num_lines) then
    end_col = (start_col + new_end_col_offset)
  else
    end_col = #vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
  end
  local function _15_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(bufnr, {start_row0, start_col})
      vim_2fhl.range(bufnr, namespace, hlgroup, {start_row0, start_col}, {end_row, end_col})
      clear_highlights(bufnr, cache.config.added.duration)
      return cache_last_texts(bufnr)
    else
      return nil
    end
  end
  return vim.schedule(_15_)
end
local function glow_removed_texts(bufnr, _17_, _18_)
  local start_row0 = _17_[1]
  local start_col = _17_[2]
  local old_end_row_offset = _18_[1]
  local old_end_col_offset = _18_[2]
  local hlgroup = cache.config.removed.hlgroup
  local last_texts = assert(cache["last-texts"], "expected string[], got `nil `or `false`")
  local start_row = inc(start_row0)
  local ends_with_newline_3f = (0 == old_end_col_offset)
  local old_end_row_offset_2a
  if ends_with_newline_3f then
    old_end_row_offset_2a = dec(old_end_row_offset)
  else
    old_end_row_offset_2a = old_end_row_offset
  end
  local removed_last_row = (start_row + old_end_row_offset_2a)
  local current_last_row = vim.api.nvim_buf_line_count(bufnr)
  local end_of_file_removed_3f = (current_last_row < removed_last_row)
  local should_virt_lines_include_first_line_removed_3f = (end_of_file_removed_3f and (0 < start_row0))
  local first_removed_line
  local function _20_()
    if (0 == old_end_row_offset) then
      return (start_col + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = last_texts[start_row]:sub(inc(start_col), _20_())
  local _3fmiddle_removed_lines
  if (1 < old_end_row_offset) then
    _3fmiddle_removed_lines = vim.list_slice(last_texts, inc(start_row), removed_last_row)
  else
    _3fmiddle_removed_lines = nil
  end
  local _3flast_removed_line
  if (0 < old_end_row_offset) then
    _3flast_removed_line = last_texts[removed_last_row]:sub(1, old_end_col_offset)
  else
    _3flast_removed_line = nil
  end
  local _3ffirst_line_chunk
  if not should_virt_lines_include_first_line_removed_3f then
    _3ffirst_line_chunk = {{first_removed_line, hlgroup}}
  else
    _3ffirst_line_chunk = nil
  end
  local _3frest_line_chunks
  if _3fmiddle_removed_lines then
    table.insert(_3fmiddle_removed_lines, _3flast_removed_line)
    local function _24_(_241)
      return {{_241, hlgroup}}
    end
    _3frest_line_chunks = vim.tbl_map(_24_, _3fmiddle_removed_lines)
  elseif _3flast_removed_line then
    _3frest_line_chunks = {{{_3flast_removed_line, hlgroup}}}
  else
    _3frest_line_chunks = nil
  end
  local _
  if (should_virt_lines_include_first_line_removed_3f and _3frest_line_chunks) then
    _ = table.insert(_3frest_line_chunks, 1, {{first_removed_line, hlgroup}})
  else
    _ = nil
  end
  local row0
  if should_virt_lines_include_first_line_removed_3f then
    row0 = dec(start_row0)
  else
    row0 = start_row0
  end
  local col0 = start_col
  local extmark_opts
  local _28_
  if _3frest_line_chunks then
    _28_ = "overlay"
  else
    _28_ = "inline"
  end
  extmark_opts = {hl_eol = true, virt_text = _3ffirst_line_chunk, virt_lines = _3frest_line_chunks, virt_text_pos = _28_, strict = false}
  local function _30_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(bufnr, {start_row0, start_col})
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row0, col0, extmark_opts)
      return clear_highlights(bufnr, cache.config.removed.duration)
    else
      return nil
    end
  end
  return vim.schedule(_30_)
end
local function on_bytes(_string_bytes, bufnr, _changedtick, start_row0, start_col, _byte_offset, old_end_row_offset, old_end_col_offset, _old_end_byte_offset, new_end_row_offset, new_end_col_offset, _new_end_byte_offset)
  if cache["buffer->detach"][bufnr] then
    cache["buffer->detach"][bufnr] = nil
  else
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    if ((old_end_row_offset < new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (old_end_col_offset < new_end_col_offset))) then
      if cache.config.added.filter(bufnr) then
        return glow_added_texts(bufnr, {start_row0, start_col}, {new_end_row_offset, new_end_col_offset})
      else
        return nil
      end
    else
      if cache.config.removed.filter(bufnr) then
        return glow_removed_texts(bufnr, {start_row0, start_col}, {old_end_row_offset, old_end_col_offset})
      else
        return nil
      end
    end
  else
    return nil
  end
end
local function excluded_buffer_3f(buf)
  return vim.list_contains(cache.config.excluded_filetypes, vim.bo[buf].filetype)
end
local function attach_buffer_21(buf)
  cache["buffer->detach"][buf] = nil
  cache_last_texts(buf)
  return vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
end
local function request_to_attach_buffer_21(buf)
  if not excluded_buffer_3f(buf) then
    local function _37_()
      if vim.api.nvim_buf_is_valid(buf) then
        return attach_buffer_21(buf)
      else
        return nil
      end
    end
    vim.schedule(_37_)
  else
  end
  return nil
end
local function request_to_detach_buffer_21(buf)
  if not (buf == cache["attached-buffer"]) then
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
  assert(cache["last-texts"], "Failed to cache lines on attaching to buffer")
  local function _41_(_241)
    return request_to_attach_buffer_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _41_})
  local function _42_(_241)
    return request_to_detach_buffer_21(_241.buf)
  end
  return vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _42_})
end
return {setup = setup}
