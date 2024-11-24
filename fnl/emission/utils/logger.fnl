;; REF: fidget/logger.lua

(local plugin-name :emission)

(local debug-config {:enabled vim.env.EMISSION_DEBUG
                     :level (or vim.env.EMISSION_DEBUG_LEVEL
                                vim.log.levels.DEBUG)
                     :short_path (not= :0 vim.env.EMISSION_DEBUG_SHORT_PATH)
                     :notifier vim.notify})

(fn set-debug-config! [opts]
  (when opts
    (each [k v (pairs opts)]
      (tset debug-config k v))))

(fn log-msg! [msg log-level ?buf]
  (when (and debug-config.enabled ;
             (<= debug-config.level log-level))
    (let [buf-info (if ?buf
                       (let [buf-name (vim.api.nvim_buf_get_name ?buf)]
                         (: " @ buf=%d, bufname=%s" :format ?buf
                            (if debug-config.short_path
                                (vim.fn.pathshorten buf-name)
                                buf-name)))
                       "")
          new-msg (: "[%s] %s%s" :format plugin-name msg buf-info)]
      (-> #(debug-config.notifier new-msg log-level {:title plugin-name})
          (vim.schedule)))))

(fn trace! [msg ?buf]
  (log-msg! msg vim.log.levels.TRACE ?buf))

(fn debug! [msg ?buf]
  (log-msg! msg vim.log.levels.DEBUG ?buf))

(fn info! [msg ?buf]
  (log-msg! msg vim.log.levels.INFO ?buf))

(fn warn! [msg ?buf]
  (log-msg! msg vim.log.levels.WARN ?buf))

(fn error! [msg ?buf]
  (log-msg! msg vim.log.levels.ERROR ?buf))

{: set-debug-config! : debug-config : trace! : info! : debug! : warn! : error!}
