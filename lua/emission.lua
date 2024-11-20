local _local_1_ = require("emission.utils")
local Stack = _local_1_["Stack"]
local cache
local function _2_()
end
local function _3_()
end
cache = {config = {attach = {delay = 100, excluded_filetypes = {}, excluded_buftypes = {"help", "nofile", "terminal", "prompt"}}, highlight_delay = 10, added = {hl_map = {default = true, fg = "#dcd7ba", bg = "#2d4f67"}, priority = 102, duration = 300, filter = _2_}, removed = {hl_map = {default = true, fg = "#dcd7ba", bg = "#672d2d"}, priority = 101, duration = 300, filter = _3_}}, namespace = vim.api.nvim_create_namespace("emission"), timer = vim.uv.new_timer(), ["pending-highlights"] = Stack.new(), ["hl-group"] = {added = "EmissionAdded", removed = "EmissionRemoved"}, ["last-duration"] = 0, ["last-editing-position"] = {0, 0}, ["attached-buffer"] = nil, ["buffer->detach"] = {}, ["last-recache-time"] = 0, ["old-texts"] = nil}
local vim_2fhl = (vim.hl or vim.highlight)
local function inc(x)
  return (x + 1)
end
local function dec(x)
  return (x - 1)
end
local function buf_has_cursor_3f(buf)
  return (vim.api.nvim_buf_is_valid(buf) and (buf == vim.api.nvim_win_get_buf(0)))
end
local function cache_old_texts(buf)
  local now = vim.uv.now()
  if ((buf ~= cache["attached-buffer"]) or (cache.config.highlight_delay < (now - cache["last-recache-time"]))) then
    cache["last-recache-time"] = now
    cache["old-texts"] = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    cache["attached-buffer"] = buf
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
local function dismiss_deprecated_highlight_21(buf, _6_)
  local start_row0 = _6_[1]
  local start_col0 = _6_[2]
  do
    local _7_ = cache["last-editing-position"]
    if ((_G.type(_7_) == "table") and (_7_[1] == start_row0) and (_7_[2] == start_col0)) then
      vim.api.nvim_buf_clear_namespace(buf, cache.namespace, 0, -1)
    else
      local _ = _7_
    end
  end
  cache["last-editing-position"] = {start_row0, start_col0}
  return nil
end
local function dismiss_deprecated_highlights_21(buf, _9_)
  local start_row0 = _9_[1]
  local start_col0 = _9_[2]
  return dismiss_deprecated_highlight_21(buf, {start_row0, start_col0})
end
local function clear_highlights_21(buf, duration)
  cache["last-duration"] = duration
  local function _10_()
    local function _11_()
      if vim.api.nvim_buf_is_valid(buf) then
        return vim.api.nvim_buf_clear_namespace(buf, cache.namespace, 0, -1)
      else
        return nil
      end
    end
    return vim.schedule(_11_)
  end
  return cache.timer:start(duration, 0, _10_)
end
local function reserve_highlight_21(buf, callback)
  assert(("function" == type(callback)), ("expected function, got " .. type(callback)))
  cache["pending-highlights"]["push!"](cache["pending-highlights"], callback)
  local function _13_()
    local function _14_()
      if ((buf == cache["attached-buffer"]) and buf_has_cursor_3f(buf)) then
        while not cache["pending-highlights"]["empty?"](cache["pending-highlights"]) do
          local cb = cache["pending-highlights"]["pop!"](cache["pending-highlights"])
          cb()
        end
        return nil
      else
        return nil
      end
    end
    return vim.schedule(_14_)
  end
  return cache.timer:start(cache.config.highlight_delay, 0, _13_)
end
local function highlight_added_texts_21(buf, _16_, _17_)
  local start_row0 = _16_[1]
  local start_col0 = _16_[2]
  local new_end_row_offset = _17_[1]
  local new_end_col_offset = _17_[2]
  local hl_group = cache["hl-group"].added
  local num_lines = vim.api.nvim_buf_line_count(buf)
  local end_row = (start_row0 + new_end_row_offset)
  local end_col
  if (end_row < num_lines) then
    end_col = (start_col0 + new_end_col_offset)
  else
    end_col = #vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1]
  end
  local hl_opts = {priority = cache.config.added.priority}
  local function _19_()
    if buf_has_cursor_3f(buf) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(buf, {start_row0, start_col0})
      vim_2fhl.range(buf, cache.namespace, hl_group, {start_row0, start_col0}, {end_row, end_col}, hl_opts)
      return cache_old_texts(buf)
    else
      return nil
    end
  end
  return vim.schedule(_19_)
end
local function highlight_removed_texts_21(buf, _21_, _22_)
  local start_row0 = _21_[1]
  local start_col0 = _21_[2]
  local old_end_row_offset = _22_[1]
  local old_end_col_offset = _22_[2]
  local hl_group = cache["hl-group"].removed
  local old_texts = assert(cache["old-texts"], "expected string[], got `nil `or `false`")
  local start_row = inc(start_row0)
  local ends_with_newline_3f = (0 == old_end_col_offset)
  local old_end_row_offset_2a
  if ends_with_newline_3f then
    old_end_row_offset_2a = dec(old_end_row_offset)
  else
    old_end_row_offset_2a = old_end_row_offset
  end
  local removed_end_row = (start_row + old_end_row_offset_2a)
  local new_end_row = vim.api.nvim_buf_line_count(buf)
  local can_virt_text_display_first_line_removed_3f = (start_row0 < new_end_row)
  local first_removed_line
  local function _24_()
    if (0 == old_end_row_offset) then
      return (start_col0 + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = old_texts[start_row]:sub(inc(start_col0), _24_())
  local _3fmiddle_removed_lines
  if (1 < old_end_row_offset) then
    _3fmiddle_removed_lines = vim.list_slice(old_texts, inc(start_row), removed_end_row)
  else
    _3fmiddle_removed_lines = nil
  end
  local _3flast_removed_line
  if ((0 < old_end_row_offset) and (0 < old_end_col_offset)) then
    _3flast_removed_line = old_texts[removed_end_row]:sub(1, old_end_col_offset)
  else
    _3flast_removed_line = nil
  end
  local _3ffirst_line_chunk = {{first_removed_line, hl_group}}
  local _3frest_line_chunks
  if _3fmiddle_removed_lines then
    table.insert(_3fmiddle_removed_lines, _3flast_removed_line)
    local function _27_(_241)
      return {{_241, hl_group}}
    end
    _3frest_line_chunks = vim.tbl_map(_27_, _3fmiddle_removed_lines)
  elseif _3flast_removed_line then
    _3frest_line_chunks = {{{_3flast_removed_line, hl_group}}}
  else
    _3frest_line_chunks = nil
  end
  local removed_end_row0 = (start_row + old_end_row_offset_2a)
  local fitted_chunks, exceeded_chunks = nil, nil
  if (nil == _3frest_line_chunks) then
    fitted_chunks, exceeded_chunks = {}, {}
  elseif (removed_end_row0 < new_end_row) then
    fitted_chunks, exceeded_chunks = _3frest_line_chunks, {}
  else
    local offset = (new_end_row - start_row)
    fitted_chunks, exceeded_chunks = vim.list_slice(_3frest_line_chunks, 1, offset), vim.list_slice(_3frest_line_chunks, inc(offset))
  end
  local extmark_opts = {hl_eol = true, virt_text = _3ffirst_line_chunk, priority = cache.config.removed.priority, virt_text_pos = "overlay", strict = false}
  local function _30_()
    if buf_has_cursor_3f(buf) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(buf, {start_row0, start_col0})
      if can_virt_text_display_first_line_removed_3f then
        vim.api.nvim_buf_set_extmark(buf, cache.namespace, start_row0, start_col0, extmark_opts)
      elseif next(fitted_chunks) then
        table.insert(fitted_chunks, 1, _3ffirst_line_chunk)
      else
        table.insert(exceeded_chunks, 1, _3ffirst_line_chunk)
      end
      if next(fitted_chunks) then
        for i, chunk in ipairs(fitted_chunks) do
          extmark_opts.virt_text = chunk
          vim.api.nvim_buf_set_extmark(buf, cache.namespace, (start_row0 + i), 0, extmark_opts)
        end
      else
      end
      if next(exceeded_chunks) then
        extmark_opts.virt_text = nil
        extmark_opts.virt_lines = exceeded_chunks
        local new_end_row0 = dec(new_end_row)
        return vim.api.nvim_buf_set_extmark(buf, cache.namespace, new_end_row0, 0, extmark_opts)
      else
        return nil
      end
    else
      return nil
    end
  end
  return vim.schedule(_30_)
end
local function on_bytes(_string_bytes, buf, _changedtick, start_row0, start_col0, _byte_offset, old_end_row_offset, old_end_col_offset, _old_end_byte_offset, new_end_row_offset, new_end_col_offset, _new_end_byte_offset)
  if cache["buffer->detach"][buf] then
    clear_highlights_21(buf, 0)
    cache["buffer->detach"][buf] = nil
    return true
  else
    if buf_has_cursor_3f(buf) then
      if ((old_end_row_offset < new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (old_end_col_offset <= new_end_col_offset))) then
        if cache.config.added.filter(buf) then
          local function _35_()
            highlight_added_texts_21(buf, {start_row0, start_col0}, {new_end_row_offset, new_end_col_offset})
            return clear_highlights_21(buf, cache.config.added.duration)
          end
          reserve_highlight_21(buf, _35_)
        else
        end
      else
        if cache.config.removed.filter(buf) then
          local function _37_()
            highlight_removed_texts_21(buf, {start_row0, start_col0}, {old_end_row_offset, old_end_col_offset})
            return clear_highlights_21(buf, cache.config.removed.duration)
          end
          reserve_highlight_21(buf, _37_)
        else
        end
      end
      return nil
    else
      return nil
    end
  end
end
local function excluded_buffer_3f(buf)
  return (vim.list_contains(cache.config.attach.excluded_buftypes, vim.bo[buf].buftype) or vim.list_contains(cache.config.attach.excluded_filetypes, vim.bo[buf].filetype))
end
local function request_to_attach_buffer_21(buf)
  local function _42_()
    if (buf_has_cursor_3f(buf) and not excluded_buffer_3f(buf)) then
      cache["attached-buffer"] = buf
      cache["buffer->detach"][buf] = nil
      cache_old_texts(buf)
      vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
      return assert(cache["old-texts"], "Failed to cache lines on attaching to buffer")
    else
      return nil
    end
  end
  vim.defer_fn(_42_, cache.config.attach.delay)
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
  vim.api.nvim_set_hl(0, cache["hl-group"].added, cache.config.added.hl_map)
  vim.api.nvim_set_hl(0, cache["hl-group"].removed, cache.config.removed.hl_map)
  request_to_attach_buffer_21(vim.api.nvim_get_current_buf())
  local function _45_(_241)
    return request_to_attach_buffer_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _45_})
  local function _46_(_241)
    return request_to_detach_buffer_21(_241.buf)
  end
  return vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _46_})
end
return {setup = setup}
