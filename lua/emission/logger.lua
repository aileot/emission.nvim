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
local function log_msg_21(msg, log_level)
  if (debug_config.enabled and (debug_config.level <= log_level)) then
    local new_msg = ("[%s] %s @ buf=%d, bufname=%s"):format(plugin_name, msg, vim.api.nvim_get_current_buf(), vim.api.nvim_buf_get_name(0))
    local function _2_()
      return debug_config.notifier(new_msg, log_level, {title = plugin_name})
    end
    return vim.schedule(_2_)
  else
    return nil
  end
end
local function trace_21(msg)
  return log_msg_21(msg, vim.log.levels.TRACE)
end
local function debug_21(msg)
  return log_msg_21(msg, vim.log.levels.DEBUG)
end
local function info_21(msg)
  return log_msg_21(msg, vim.log.levels.INFO)
end
local function warn_21(msg)
  return log_msg_21(msg, vim.log.levels.WARN)
end
local function error_21(msg)
  return log_msg_21(msg, vim.log.levels.ERROR)
end
return {["set-debug-config!"] = set_debug_config_21, ["debug-config"] = debug_config, ["trace!"] = trace_21, ["info!"] = info_21, ["debug!"] = debug_21, ["warn!"] = warn_21, ["error!"] = error_21}
