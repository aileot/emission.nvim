;; REF: fidget/logger.lua

(local plugin-name :emission)

(local debug-config {:enabled vim.env.DEBUG_EMISSION
                     :level vim.log.levels.DEBUG
                     :notifier vim.notify})

(fn set-debug-config! [opts]
  (when opts
    (each [k v (pairs opts)]
      (tset debug-config k v))))

(fn log-msg! [msg log-level ?buf]
  (when (and debug-config.enabled ;
             (<= debug-config.level log-level))
    (let [buf-info (if ?buf
                       (: " @ buf=%d, bufname=%s" :format ?buf
                          (vim.api.nvim_buf_get_name ?buf))
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
