local default_modes = {"n", "no", "nov", "noV", "no\\22"}
local cache = {config = {excluded_filetypes = {"lazy", "oil"}, min_recache_interval = 50, added = {hlgroup = "EmissionAdded", modes = default_modes, duration = 400}, removed = {hlgroup = "EmissionRemoved", modes = default_modes, duration = 300}}, timer = vim.uv.new_timer(), ["attached-buffer"] = nil, ["buffer->detach"] = {}, ["last-recache-time"] = 0, ["last-texts"] = nil}
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
local function open_folds_on_undo()
  local foldopen = vim.opt.foldopen:get()
  if (vim.list_contains(foldopen, "undo") or vim.list_contains(foldopen, "all")) then
    return vim.cmd("normal! zv")
  else
    return nil
  end
end
local function clear_highlights(bufnr, duration)
  cache.timer:stop()
  local function _3_()
    local function _4_()
      if vim.api.nvim_buf_is_valid(bufnr) then
        return vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
      else
        return nil
      end
    end
    return vim.schedule(_4_)
  end
  return cache.timer:start(duration, 0, _3_)
end
local function glow_added_texts(bufnr, _6_, _7_)
  local start_row0 = _6_[1]
  local start_col = _6_[2]
  local new_end_row_offset = _7_[1]
  local new_end_col_offset = _7_[2]
  local hlgroup = cache.config.added.hlgroup
  local num_lines = vim.api.nvim_buf_line_count(bufnr)
  local end_row = (start_row0 + new_end_row_offset)
  local end_col
  if (end_row < num_lines) then
    end_col = (start_col + new_end_col_offset)
  else
    end_col = #vim.api.nvim_buf_get_lines(bufnr, -2, -1, false)[1]
  end
  local function _9_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_on_undo()
      vim_2fhl.range(bufnr, namespace, hlgroup, {start_row0, start_col}, {end_row, end_col})
      clear_highlights(bufnr, cache.config.added.duration)
      return cache_last_texts(bufnr)
    else
      return nil
    end
  end
  return vim.schedule(_9_)
end
local function glow_removed_texts(bufnr, _11_, _12_)
  local start_row0 = _11_[1]
  local start_col = _11_[2]
  local old_end_row_offset = _12_[1]
  local old_end_col_offset = _12_[2]
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
  local first_removed_line
  local function _14_()
    if (0 == old_end_row_offset) then
      return (start_col + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = last_texts[start_row]:sub(inc(start_col), _14_())
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
  local first_line_chunk = {{first_removed_line, hlgroup}}
  local _3frest_line_chunks
  if _3fmiddle_removed_lines then
    table.insert(_3fmiddle_removed_lines, _3flast_removed_line)
    local function _17_(_241)
      return {{_241, hlgroup}}
    end
    _3frest_line_chunks = vim.tbl_map(_17_, _3fmiddle_removed_lines)
  else
    _3frest_line_chunks = {{{_3flast_removed_line, hlgroup}}}
  end
  local row0 = start_row0
  local col0 = start_col
  local extmark_opts = {hl_eol = true, virt_text = first_line_chunk, virt_lines = _3frest_line_chunks, virt_text_pos = "overlay", strict = false}
  local function _19_()
    if vim.api.nvim_buf_is_valid(bufnr) then
      open_folds_on_undo()
      vim.api.nvim_buf_set_extmark(bufnr, namespace, row0, col0, extmark_opts)
      return clear_highlights(bufnr, cache.config.removed.duration)
    else
      return nil
    end
  end
  return vim.schedule(_19_)
end
local function on_bytes(_string_bytes, bufnr, _changedtick, start_row0, start_col, _byte_offset, old_end_row_offset, old_end_col_offset, _old_end_byte_offset, new_end_row_offset, new_end_col_offset, _new_end_byte_offset)
  if cache["buffer->detach"][bufnr] then
    cache["buffer->detach"][bufnr] = nil
  else
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    local mode = vim.api.nvim_get_mode().mode
    if ((old_end_row_offset < new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (old_end_col_offset < new_end_col_offset))) then
      if vim.list_contains(cache.config.added.modes, mode) then
        return glow_added_texts(bufnr, {start_row0, start_col}, {new_end_row_offset, new_end_col_offset})
      else
        return nil
      end
    else
      if vim.list_contains(cache.config.removed.modes, mode) then
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
    local function _26_()
      if vim.api.nvim_buf_is_valid(buf) then
        return attach_buffer_21(buf)
      else
        return nil
      end
    end
    vim.schedule(_26_)
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
  local function _30_(_241)
    return request_to_attach_buffer_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _30_})
  local function _31_(_241)
    return request_to_detach_buffer_21(_241.buf)
  end
  return vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _31_})
end
return {setup = setup}
