;; REF: fidget/logger.lua

(local plugin-name :emission)

(local debug-config {:enabled vim.env.DEBUG_EMISSION
                     :level vim.log.levels.DEBUG
                     :notifier vim.notify})

(fn set-debug-config! [opts]
  (when opts
    (each [k v (pairs opts)]
      (tset debug-config k v))))

(fn log-msg! [msg log-level]
  (when (and debug-config.enabled ;
             (<= debug-config.level log-level))
    (let [new-msg (: "[%s] %s @ buf=%d, bufname=%s" :format plugin-name msg
                     (vim.api.nvim_get_current_buf)
                     (vim.api.nvim_buf_get_name 0))]
      (-> #(debug-config.notifier new-msg log-level {:title plugin-name})
          (vim.schedule)))))

(fn trace! [msg]
  (log-msg! msg vim.log.levels.TRACE))

(fn debug! [msg]
  (log-msg! msg vim.log.levels.DEBUG))

(fn info! [msg]
  (log-msg! msg vim.log.levels.INFO))

(fn warn! [msg]
  (log-msg! msg vim.log.levels.WARN))

(fn error! [msg]
  (log-msg! msg vim.log.levels.ERROR))

{: set-debug-config! : debug-config : trace! : info! : debug! : warn! : error!}
