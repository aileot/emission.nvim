local _local_1_ = require("emission.utils.stack")
local Stack = _local_1_["Stack"]
local _local_2_ = require("emission.utils.logger")
local set_debug_config_21 = _local_2_["set-debug-config!"]
local debug_config = _local_2_["debug-config"]
local trace_21 = _local_2_["trace!"]
local debug_21 = _local_2_["debug!"]
local uv = (vim.uv or vim.loop)
local default_config
local function _3_()
  return true
end
default_config = {debug = debug_config, attach = {delay = 150, excluded_filetypes = {}, excluded_buftypes = {"help", "nofile", "terminal", "prompt"}}, highlight = {duration = 300, min_byte = 2, filter = _3_, additional_recache_events = {"InsertLeave"}, delay = 10}, added = {priority = 102, hl_map = {default = true, bold = true, fg = "#dcd7ba", bg = "#2d4f67"}}, removed = {priority = 101, hl_map = {default = true, bold = true, fg = "#dcd7ba", bg = "#672d2d"}}}
local cache
local function _4_(t, k)
  t[k] = Stack.new()
  return rawget(t, k)
end
cache = {config = vim.deepcopy(default_config), namespace = vim.api.nvim_create_namespace("emission"), ["timer-to-highlight"] = uv.new_timer(), ["timer-to-clear-highlight"] = uv.new_timer(), ["buf->pending-highlights"] = setmetatable({}, {__index = _4_}), ["hl-group"] = {added = "EmissionAdded", removed = "EmissionRemoved"}, ["last-editing-position"] = {0, 0}, ["buf->detach?"] = {}, ["last-recache-time"] = 0, ["buf->old-texts"] = {}}
local vim_2fhl = (vim.hl or vim.highlight)
local function inc(x)
  return (x + 1)
end
local function dec(x)
  return (x - 1)
end
local function buf_has_cursor_3f(buf)
  return (buf == vim.api.nvim_win_get_buf(0))
end
local function cache_old_texts(buf)
  debug_21("attempt to cache texts", buf)
  cache["buf->old-texts"][buf] = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  assert(cache["buf->old-texts"][buf], "Failed to cache lines on attaching to buffer")
  return debug_21("cached texts", buf)
end
local function open_folds_at_cursor_21()
  local foldopen = vim.opt.foldopen:get()
  if (vim.list_contains(foldopen, "undo") or vim.list_contains(foldopen, "all")) then
    return vim.cmd("silent! . foldopen!")
  else
    return nil
  end
end
local function clear_highlights_21(buf)
  vim.api.nvim_buf_clear_namespace(buf, cache.namespace, 0, -1)
  return debug_21("cleared highlights", buf)
end
local function request_to_clear_highlights_21(buf)
  local duration = cache.config.highlight.duration
  local cb
  local function _6_()
    if vim.api.nvim_buf_is_valid(buf) then
      debug_21("clearing namespace after duration", buf)
      return clear_highlights_21(buf)
    else
      return nil
    end
  end
  cb = _6_
  local function _8_()
    return vim.schedule(cb)
  end
  return cache["timer-to-clear-highlight"]:start(duration, 0, _8_)
end
local function discard_pending_highlights_21(buf)
  cache["buf->pending-highlights"][buf] = nil
  return debug_21("discarded highlight stack", buf)
end
local function request_to_highlight_21(buf, callback)
  debug_21("reserving new highlights", buf)
  assert(("function" == type(callback)), ("expected function, got " .. type(callback)))
  local pending_highlights = cache["buf->pending-highlights"][buf]
  pending_highlights["push!"](pending_highlights, callback)
  local timer_cb
  local function _9_()
    if (not cache["buf->detach?"][buf] and vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf)) then
      debug_21(("executing a series of pending %d highlight(s)"):format(#pending_highlights:get()), buf)
      while not pending_highlights["empty?"](pending_highlights) do
        local hl_cb = pending_highlights["pop!"](pending_highlights)
        hl_cb()
      end
      cache_old_texts(buf)
      return request_to_clear_highlights_21(buf)
    else
      return nil
    end
  end
  timer_cb = _9_
  local function _11_()
    return vim.schedule(timer_cb)
  end
  return cache["timer-to-highlight"]:start(cache.config.highlight.delay, 0, _11_)
end
local function dismiss_deprecated_highlight_21(buf, _12_)
  local start_row0 = _12_[1]
  local start_col0 = _12_[2]
  do
    local _13_ = cache["last-editing-position"]
    if ((_G.type(_13_) == "table") and (_13_[1] == start_row0) and (_13_[2] == start_col0)) then
      debug_21(("dismissing all the buf highlights due to the duplicated positioning {row0: %d, col0: %d}"):format(start_row0, start_col0), buf)
      clear_highlights_21(buf)
    else
      local _ = _13_
    end
  end
  cache["last-editing-position"] = {start_row0, start_col0}
  return nil
end
local function dismiss_deprecated_highlights_21(buf, _15_)
  local start_row0 = _15_[1]
  local start_col0 = _15_[2]
  return dismiss_deprecated_highlight_21(buf, {start_row0, start_col0})
end
local function highlight_added_texts_21(buf, start_row0, start_col0, new_end_row_offset, new_end_col_offset)
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
  local function _17_()
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf)) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(buf, {start_row0, start_col0})
      debug_21(("highlighting `added` range {row0: %d, col0: %d} to {row: %d, col: %d}"):format(start_row0, start_col0, end_row, end_col), buf)
      return vim_2fhl.range(buf, cache.namespace, hl_group, {start_row0, start_col0}, {end_row, end_col}, hl_opts)
    else
      return nil
    end
  end
  return vim.schedule(_17_)
end
local function extend_chunk_to_win_width_21(chunk)
  local max_col = vim.api.nvim_win_get_width(0)
  local blank_chunk = {string.rep(" ", max_col)}
  table.insert(chunk, blank_chunk)
  return chunk
end
local function highlight_removed_texts_21(buf, start_row0, start_col0, old_end_row_offset, old_end_col_offset)
  debug_21(("highlighting `removed` range {row0: %d, col0: %d} by the offsets {row: %d, col: %d}"):format(start_row0, start_col0, old_end_row_offset, old_end_col_offset), buf)
  local hl_group = cache["hl-group"].removed
  local old_texts = assert(cache["buf->old-texts"][buf], "expected string[], got `nil `or `false`")
  local old_end_row = #old_texts
  local start_row = math.min(inc(start_row0), old_end_row)
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
  local function _20_()
    if (0 == old_end_row_offset) then
      return (start_col0 + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = string.sub(old_texts[start_row], inc(start_col0), _20_())
  local _3fmiddle_removed_lines
  if (1 < old_end_row_offset) then
    _3fmiddle_removed_lines = vim.list_slice(old_texts, inc(start_row), removed_end_row)
  else
    _3fmiddle_removed_lines = nil
  end
  local _3flast_removed_line
  if ((0 < old_end_row_offset) and (0 < old_end_col_offset)) then
    _3flast_removed_line = string.sub(old_texts[removed_end_row], 1, old_end_col_offset)
  else
    _3flast_removed_line = nil
  end
  local _3ffirst_line_chunk = {{first_removed_line, hl_group}}
  local _3frest_line_chunks
  if _3fmiddle_removed_lines then
    table.insert(_3fmiddle_removed_lines, _3flast_removed_line)
    local function _23_(_241)
      return {{_241, hl_group}}
    end
    _3frest_line_chunks = vim.tbl_map(_23_, _3fmiddle_removed_lines)
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
  local extmark_opts = {hl_eol = true, priority = cache.config.removed.priority, virt_text_pos = "overlay", strict = false}
  local function _26_()
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf)) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(buf, {start_row0, start_col0})
      if can_virt_text_display_first_line_removed_3f then
        if (next(fitted_chunks) or next(exceeded_chunks)) then
          extmark_opts.virt_text = extend_chunk_to_win_width_21(_3ffirst_line_chunk)
        else
          extmark_opts.virt_text = _3ffirst_line_chunk
        end
        debug_21(("set `virt_text` for first line at {row0: %d, col0: %d}"):format(start_row0, start_col0), buf)
        vim.api.nvim_buf_set_extmark(buf, cache.namespace, start_row0, start_col0, extmark_opts)
      elseif next(fitted_chunks) then
        table.insert(fitted_chunks, 1, _3ffirst_line_chunk)
      else
        table.insert(exceeded_chunks, 1, _3ffirst_line_chunk)
      end
      if next(fitted_chunks) then
        for i, chunk in ipairs(fitted_chunks) do
          local row0 = (start_row0 + i)
          extmark_opts.virt_text = extend_chunk_to_win_width_21(chunk)
          debug_21(("set `virt_text` for `fitted-chunk` at the row %d"):format(row0))
          vim.api.nvim_buf_set_extmark(buf, cache.namespace, row0, 0, extmark_opts)
        end
      else
      end
      if next(exceeded_chunks) then
        extmark_opts.virt_text = nil
        extmark_opts.virt_lines = vim.tbl_map(extend_chunk_to_win_width_21, exceeded_chunks)
        local new_end_row0 = dec(new_end_row)
        debug_21(("set `virt_lines` for `exceeded-chunks` at the row %d"):format(new_end_row0))
        return vim.api.nvim_buf_set_extmark(buf, cache.namespace, new_end_row0, 0, extmark_opts)
      else
        return nil
      end
    else
      return nil
    end
  end
  return vim.schedule(_26_)
end
local function on_bytes(_string_bytes, buf, _changedtick, start_row0, start_col0, _byte_offset, old_end_row_offset, old_end_col_offset, old_end_byte_offset, new_end_row_offset, new_end_col_offset, new_end_byte_offset)
  if cache["buf->detach?"][buf] then
    cache["buf->detach?"][buf] = nil
    debug_21("detached from buf", buf)
    return true
  else
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf) and (cache.config.highlight.min_byte <= math.max(old_end_byte_offset, new_end_byte_offset)) and cache.config.highlight.filter(buf)) then
      local function _32_()
        local display_start_row = vim.fn.line("w0")
        local display_offset = vim.api.nvim_win_get_height(0)
        local display_end_row = (display_start_row + display_offset)
        if ((start_row0 < display_end_row) or (display_start_row < (start_row0 + old_end_row_offset)) or (display_start_row < (start_row0 + new_end_row_offset))) then
          debug_21(("start row0: " .. start_row0), buf)
          debug_21(("display start row: " .. display_start_row))
          debug_21(("display end row: " .. display_end_row))
          debug_21(("old row offset: " .. old_end_row_offset))
          debug_21(("new row offset: " .. new_end_row_offset))
          local display_row_offset = (display_end_row - display_start_row)
          local start_row0_2a = math.max(start_row0, dec(display_start_row))
          if ((old_end_row_offset < new_end_row_offset) or (((0 == old_end_row_offset) and (old_end_row_offset == new_end_row_offset)) and (0 < new_end_col_offset))) then
            local row_exceeded_3f = (display_row_offset < new_end_row_offset)
            local row_offset
            if row_exceeded_3f then
              row_offset = display_row_offset
            else
              row_offset = new_end_row_offset
            end
            local col_offset
            if row_exceeded_3f then
              col_offset = 0
            else
              col_offset = new_end_col_offset
            end
            return highlight_added_texts_21(buf, start_row0_2a, start_col0, row_offset, col_offset)
          else
            local row_exceeded_3f = (display_row_offset < old_end_row_offset)
            local row_offset
            if row_exceeded_3f then
              row_offset = display_row_offset
            else
              row_offset = old_end_row_offset
            end
            local col_offset
            if row_exceeded_3f then
              col_offset = 0
            else
              col_offset = old_end_col_offset
            end
            return highlight_removed_texts_21(buf, start_row0_2a, start_col0, row_offset, col_offset)
          end
        else
          return nil
        end
      end
      request_to_highlight_21(buf, _32_)
      return nil
    else
      return nil
    end
  end
end
local function excluded_buf_3f(buf)
  return (vim.list_contains(cache.config.attach.excluded_buftypes, vim.bo[buf].buftype) or vim.list_contains(cache.config.attach.excluded_filetypes, vim.bo[buf].filetype))
end
local function request_to_attach_buf_21(buf)
  debug_21("requested to attach buf", buf)
  local function _41_()
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf) and not excluded_buf_3f(buf)) then
      cache_old_texts(buf)
      vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes})
      return debug_21("attached to buf", buf)
    else
      return debug_21("the buf did not meet the requirements to be attached", buf)
    end
  end
  vim.defer_fn(_41_, cache.config.attach.delay)
  return nil
end
local function request_to_detach_buf_21(buf)
  debug_21("requested to detach buf", buf)
  clear_highlights_21(buf, 0)
  discard_pending_highlights_21(buf)
  cache["buf->detach?"][buf] = true
  return nil
end
local function setup(opts)
  local id = vim.api.nvim_create_augroup("Emission", {})
  cache.config = vim.tbl_deep_extend("keep", (opts or {}), default_config)
  set_debug_config_21(cache.config.debug)
  trace_21(("merged config: " .. vim.inspect(cache.config)))
  vim.api.nvim_set_hl(0, cache["hl-group"].added, cache.config.added.hl_map)
  vim.api.nvim_set_hl(0, cache["hl-group"].removed, cache.config.removed.hl_map)
  request_to_attach_buf_21(vim.api.nvim_get_current_buf())
  for _, event in ipairs(cache.config.highlight.additional_recache_events) do
    local function _43_(_241)
      return cache_old_texts(_241.buf)
    end
    vim.api.nvim_create_autocmd(event, {group = id, callback = _43_})
  end
  local function _44_(_241)
    return request_to_attach_buf_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _44_})
  local function _45_(_241)
    return request_to_detach_buf_21(_241.buf)
  end
  return vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _45_})
end
return {setup = setup}
