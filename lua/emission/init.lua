local _local_1_ = require("emission.utils.stack")
local Stack = _local_1_["Stack"]
local _local_2_ = require("emission.utils.logger")
local set_debug_config_21 = _local_2_["set-debug-config!"]
local trace_21 = _local_2_["trace!"]
local debug_21 = _local_2_["debug!"]
local config = require("emission.config")
local cache
local function _3_(_t, k)
  return config._config[k]
end
local function _4_()
  return error("No new entry is allowed")
end
local function _5_(t, k)
  t[k] = Stack.new()
  return rawget(t, k)
end
cache = {config = setmetatable({}, {__index = _3_, __newindex = _4_}), namespace = vim.api.nvim_create_namespace("emission"), ["buf->pending-highlights"] = setmetatable({}, {__index = _5_}), ["hl-group"] = {added = "EmissionAdded", removed = "EmissionRemoved"}, ["last-editing-position"] = {0, 0}, ["buf->detach?"] = {}, ["last-recache-time"] = 0, ["buf->old-texts"] = {}}
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
  local function _7_()
    if vim.api.nvim_buf_is_valid(buf) then
      debug_21("clearing namespace after duration", buf)
      return clear_highlights_21(buf)
    else
      return nil
    end
  end
  return vim.defer_fn(_7_, cache.config.highlight.duration)
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
  return vim.defer_fn(_9_, cache.config.highlight.delay)
end
local function dismiss_deprecated_highlight_21(buf, _11_)
  local start_row0 = _11_[1]
  local start_col0 = _11_[2]
  do
    local _12_ = cache["last-editing-position"]
    if ((_G.type(_12_) == "table") and (_12_[1] == start_row0) and (_12_[2] == start_col0)) then
      debug_21(("dismissing all the buf highlights due to the duplicated positioning {row0: %d, col0: %d}"):format(start_row0, start_col0), buf)
      clear_highlights_21(buf)
    else
      local _ = _12_
    end
  end
  cache["last-editing-position"] = {start_row0, start_col0}
  return nil
end
local function dismiss_deprecated_highlights_21(buf, _14_)
  local start_row0 = _14_[1]
  local start_col0 = _14_[2]
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
  local function _16_()
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf)) then
      open_folds_at_cursor_21()
      dismiss_deprecated_highlights_21(buf, {start_row0, start_col0})
      debug_21(("highlighting `added` range {row0: %d, col0: %d} to {row: %d, col: %d}"):format(start_row0, start_col0, end_row, end_col), buf)
      return vim_2fhl.range(buf, cache.namespace, hl_group, {start_row0, start_col0}, {end_row, end_col}, hl_opts)
    else
      return nil
    end
  end
  return vim.schedule(_16_)
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
  local function _19_()
    if (0 == old_end_row_offset) then
      return (start_col0 + old_end_col_offset)
    else
      return nil
    end
  end
  first_removed_line = string.sub(old_texts[start_row], inc(start_col0), _19_())
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
    local function _22_(_241)
      return {{_241, hl_group}}
    end
    _3frest_line_chunks = vim.tbl_map(_22_, _3fmiddle_removed_lines)
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
  local function _25_()
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
  return vim.schedule(_25_)
end
local function on_bytes(_string_bytes, buf, _changedtick, start_row0, start_col0, _byte_offset, old_end_row_offset, old_end_col_offset, old_end_byte_offset, new_end_row_offset, new_end_col_offset, new_end_byte_offset)
  if cache["buf->detach?"][buf] then
    return true
  else
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf) and (cache.config.highlight.min_byte <= math.max(old_end_byte_offset, new_end_byte_offset)) and cache.config.highlight.filter(buf)) then
      local function _31_()
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
            if ((cache.config.added.min_row_offset <= (new_end_row_offset + (-1 - math.min(1, new_end_col_offset)))) and cache.config.added.filter({buf = buf})) then
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
              return nil
            end
          else
            if ((cache.config.removed.min_row_offset <= (old_end_row_offset + (-1 - math.min(1, old_end_col_offset)))) and cache.config.removed.filter({buf = buf})) then
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
            else
              return nil
            end
          end
        else
          return nil
        end
      end
      request_to_highlight_21(buf, _31_)
      return nil
    else
      return nil
    end
  end
end
local function on_detach(_string_detach, buf)
  cache["buf->detach?"][buf] = nil
  return debug_21("detached from buf", buf)
end
local function excluded_buf_3f(buf)
  return (vim.list_contains(cache.config.attach.excluded_buftypes, vim.bo[buf].buftype) or vim.list_contains(cache.config.attach.excluded_filetypes, vim.bo[buf].filetype))
end
local function request_to_attach_buf_21(buf)
  debug_21("requested to attach buf", buf)
  local function _42_()
    if (vim.api.nvim_buf_is_valid(buf) and buf_has_cursor_3f(buf) and not excluded_buf_3f(buf)) then
      cache_old_texts(buf)
      vim.api.nvim_buf_attach(buf, false, {on_bytes = on_bytes, on_detach = on_detach})
      return debug_21("attached to buf", buf)
    else
      return debug_21("the buf did not meet the requirements to be attached", buf)
    end
  end
  vim.defer_fn(_42_, cache.config.attach.delay)
  return nil
end
local function request_to_detach_buf_21(buf)
  debug_21("requested to detach buf", buf)
  clear_highlights_21(buf, 0)
  discard_pending_highlights_21(buf)
  cache["buf->detach?"][buf] = true
  return nil
end

---@param opts? emission.Config
--- Initialize emission.
--- Your options are always merged into the default config,
--- not the current config.
local function setup(opts)
  local opts0 = (opts or {})
  local id = vim.api.nvim_create_augroup("Emission", {})
  config.merge(opts0)
  set_debug_config_21(cache.config.debug)
  trace_21(("merged config: " .. vim.inspect(cache.config)))
  vim.api.nvim_set_hl(0, cache["hl-group"].added, cache.config.added.hl_map)
  vim.api.nvim_set_hl(0, cache["hl-group"].removed, cache.config.removed.hl_map)
  request_to_attach_buf_21(vim.api.nvim_get_current_buf())
  for _, event in ipairs(cache.config.highlight.additional_recache_events) do
    local function _44_(_241)
      return cache_old_texts(_241.buf)
    end
    vim.api.nvim_create_autocmd(event, {group = id, callback = _44_})
  end
  local function _45_(_241)
    return request_to_attach_buf_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufEnter", {group = id, callback = _45_})
  local function _46_(_241)
    return request_to_detach_buf_21(_241.buf)
  end
  vim.api.nvim_create_autocmd("BufLeave", {group = id, callback = _46_})
  return nil
end

--- Reset current config to the last config determined by `emission.setup()`.
---@return emission.Config
local function reset()
  return config.reset()
end
return {setup = setup, override = config.override, reset = reset}
