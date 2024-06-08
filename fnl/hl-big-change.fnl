(local M {:config {:attach_delay 100
                   :duration 400
                   :hlgroup {:added :HlBigChangeAdded
                             :removed :HlBigChangeRemoved}}
          :timer ((. (or vim.uv vim.loop) :new_timer))})

(local namespace (vim.api.nvim_create_namespace :HlBigChange))

(fn open-folds-on-undo []
  (when (vim.tbl_contains (vim.opt.foldopen:get) :undo)
    (vim.cmd.normal {1 :zv :bang true})))

(fn on-bytes [ignored
              bufnr
              changedtick
              start-row
              start-col
              byte-offset
              old-end-row
              old-end-col
              old-end-byte
              new-end-row
              new-end-col
              new-end-byte]
  (if (not (vim.api.nvim_buf_is_valid bufnr)) (lua "return true")
      (or (not (: (. (vim.api.nvim_get_mode) :mode) :find :n))
          (and (and (= old-end-row start-row) (= new-end-row start-row))
               (<= old-end-col (+ new-end-col 1)))) (lua "return "))
  (local end-row (+ start-row new-end-row))
  (var end-col (+ start-col new-end-col))
  (local num-lines (vim.api.nvim_buf_line_count 0))
  (when (>= end-row num-lines)
    (set end-col
         (length (. (vim.api.nvim_buf_get_lines 0 (- 2) (- 1) false) 1))))
  (open-folds-on-undo)
  (local hlgroup M.config.hlgroup.added)
  (vim.schedule (fn []
                  (when (not (vim.api.nvim_buf_is_valid bufnr)) (lua "return "))
                  (vim.highlight.range bufnr namespace hlgroup
                                       [start-row start-col] [end-row end-col])
                  (M.clear_highlights bufnr))))

(fn M.clear_highlights [bufnr]
  (M.timer:stop)
  (M.timer:start M.config.duration 0
                 (vim.schedule_wrap (fn []
                                      (when (vim.api.nvim_buf_is_valid bufnr)
                                        (vim.api.nvim_buf_clear_namespace bufnr
                                                                          namespace
                                                                          0
                                                                          (- 1)))))))

(var last-bufnr (- 1))

(local wipedout-bufnrs {})

(fn M.setup [config]
  (vim.api.nvim_set_hl 0 :HlBigChangeAdded
                       {:bg "#2d4f67" :default true :fg "#dcd7ba"})
  (vim.api.nvim_set_hl 0 :HlBigChangeRemoved
                       {:bg "#dcd7ba" :default true :fg "#2d4f67"})
  (set M.config (vim.tbl_deep_extend :keep (or config {}) M.config))
  (local id (vim.api.nvim_create_augroup :HlBigChange {}))
  (vim.api.nvim_create_autocmd :BufWipeout
                               {:callback (fn [a]
                                            (tset wipedout-bufnrs a.buf true))
                                :group id})
  (vim.api.nvim_create_autocmd :BufWinEnter
                               {:callback (fn [a]
                                            (if (. wipedout-bufnrs a.buf)
                                                (tset wipedout-bufnrs a.buf nil)
                                                (< a.buf last-bufnr)
                                                (lua "return "))
                                            (set last-bufnr a.buf)
                                            (vim.defer_fn (fn []
                                                            (when (vim.api.nvim_buf_is_valid a.buf)
                                                              (vim.api.nvim_buf_attach a.buf
                                                                                       false
                                                                                       {:on_bytes on-bytes})))
                                              M.config.attach_delay))
                                :group id}))

M
