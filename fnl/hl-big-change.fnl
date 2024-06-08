(local M {:config {:attach_delay 100
                   :duration 400
                   :hlgroup {:added :HlBigChangeAdded
                             :removed :HlBigChangeRemoved}}
          :timer ((. (or vim.uv vim.loop) :new_timer))})

(local namespace (vim.api.nvim_create_namespace :HlBigChange))

(fn open-folds-on-undo []
  (when (vim.tbl_contains (vim.opt.foldopen:get) :undo)
    (vim.cmd "normal! zv")))

(fn on-bytes [_ignored
              bufnr
              _changedtick
              start-row
              start-col
              _byte-offset
              old-end-row
              old-end-col
              _old-end-byte
              new-end-row
              new-end-col
              _new-end-byte]
  (when (and (vim.api.nvim_buf_is_valid bufnr)
             (-> (vim.api.nvim_get_mode)
                 (. :mode)
                 ;; TODO: Configurable modes to highlight?
                 (: :find :n)))
    ;; TODO: Highlight removed texts by extmarks.
    (if (and (= old-end-row start-row) ;
             (= new-end-row start-row) ;
             (<= old-end-col (+ new-end-col 1)))
        (let [hlgroup M.config.hlgroup.added
              num-lines (vim.api.nvim_buf_line_count 0)
              end-row (+ start-row new-end-row)
              end-col (if (< num-lines end-row)
                          (length (. (vim.api.nvim_buf_get_lines 0 -2 -1 false)
                                     1))
                          (+ start-col new-end-col))]
          (open-folds-on-undo)
          (-> (fn []
                (when (vim.api.nvim_buf_is_valid bufnr)
                  (vim.highlight.range bufnr namespace hlgroup
                                       [start-row start-col] [end-row end-col])
                  (M.clear_highlights bufnr)))
              (vim.schedule))))))

(fn M.clear_highlights [bufnr]
  (M.timer:stop)
  (M.timer:start M.config.duration 0
                 #(-> (fn []
                        (when (vim.api.nvim_buf_is_valid bufnr)
                          (vim.api.nvim_buf_clear_namespace bufnr namespace 0
                                                            -1)))
                      (vim.schedule))))

(var last-bufnr -1)

(local wipedout-bufnrs {})

(fn M.setup [config]
  (let [id (vim.api.nvim_create_augroup :HlBigChange {})]
    (set M.config (vim.tbl_deep_extend :keep (or config {}) M.config))
    (vim.api.nvim_set_hl 0 :HlBigChangeAdded
                         {:default true :bg "#2d4f67" :fg "#dcd7ba"})
    (vim.api.nvim_set_hl 0 :HlBigChangeRemoved
                         {:default true :bg "#dcd7ba" :fg "#2d4f67"})
    (vim.api.nvim_create_autocmd :BufWipeout
      {:group id
       :callback (fn [a]
                   (tset wipedout-bufnrs a.buf true))})
    (vim.api.nvim_create_autocmd :BufWinEnter
      {:group id
       :callback (fn [a]
                   (if (. wipedout-bufnrs a.buf)
                       (tset wipedout-bufnrs a.buf nil)
                       (< a.buf last-bufnr)
                       (lua "return "))
                   (set last-bufnr a.buf)
                   (-> (fn []
                         (when (vim.api.nvim_buf_is_valid a.buf)
                           (vim.api.nvim_buf_attach a.buf false
                                                    {:on_bytes on-bytes})))
                       (vim.defer_fn M.config.attach_delay)))})))

M
