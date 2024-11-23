local plugin_name = "emission"
local debug_config = {enabled = vim.env.DEBUG_EMISSION, level = vim.log.levels.DEBUG, notifier = vim.notify}
local function set_debug_config_21(opts)
  if opts then
    for k, v in pairs(opts) do
      debug_config[k] = v
    end
    return nil
  else
    return nil
  end
end
local function log_msg_21(msg, log_level, _3fbuf)
  if (debug_config.enabled and (debug_config.level <= log_level)) then
    local buf_info
    if _3fbuf then
      buf_info = (" @ buf=%d, bufname=%s"):format(_3fbuf, vim.api.nvim_buf_get_name(_3fbuf))
    else
      buf_info = ""
    end
    local new_msg = ("[%s] %s%s"):format(plugin_name, msg, buf_info)
    local function _3_()
      return debug_config.notifier(new_msg, log_level, {title = plugin_name})
    end
    return vim.schedule(_3_)
  else
    return nil
  end
end
local function trace_21(msg, _3fbuf)
  return log_msg_21(msg, vim.log.levels.TRACE, _3fbuf)
end
local function debug_21(msg, _3fbuf)
  return log_msg_21(msg, vim.log.levels.DEBUG, _3fbuf)
end
local function info_21(msg, _3fbuf)
  return log_msg_21(msg, vim.log.levels.INFO, _3fbuf)
end
local function warn_21(msg, _3fbuf)
  return log_msg_21(msg, vim.log.levels.WARN, _3fbuf)
end
local function error_21(msg, _3fbuf)
  return log_msg_21(msg, vim.log.levels.ERROR, _3fbuf)
end
return {["set-debug-config!"] = set_debug_config_21, ["debug-config"] = debug_config, ["trace!"] = trace_21, ["info!"] = info_21, ["debug!"] = debug_21, ["warn!"] = warn_21, ["error!"] = error_21}
