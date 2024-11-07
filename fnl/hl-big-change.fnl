(local M {:config {:attach_delay 100
                   :duration 400
                   :excluded_filetypes []
                   :hlgroup {:added :HlBigChangeAdded
                             :removed :HlBigChangeRemoved}}
          :timer (vim.uv.new_timer)})

(local namespace (vim.api.nvim_create_namespace :HlBigChange))

(fn open-folds-on-undo []
  (let [foldopen (vim.opt.foldopen:get)]
    (when (or (vim.list_contains foldopen :undo)
              (vim.list_contains foldopen :all))
      (vim.cmd "normal! zv"))))

(fn clear-highlights [bufnr]
  (M.timer:stop)
  (M.timer:start M.config.duration 0
                 #(-> (fn []
                        (when (vim.api.nvim_buf_is_valid bufnr)
                          (vim.api.nvim_buf_clear_namespace bufnr namespace 0
                                                            -1)))
                      (vim.schedule))))

(fn glow-added-texts [bufnr
                      [start-row0 start-col]
                      [new-end-row-offset new-end-col-offset]]
  (let [hlgroup M.config.hlgroup.added
        num-lines (vim.api.nvim_buf_line_count bufnr)
        end-row (+ start-row0 new-end-row-offset)
        end-col (if (< end-row num-lines)
                    (+ start-col new-end-col-offset)
                    (-> (vim.api.nvim_buf_get_lines bufnr -2 -1 false)
                        (. 1)
                        (length)))]
    (-> #(when (vim.api.nvim_buf_is_valid bufnr)
           (open-folds-on-undo)
           (vim.highlight.range bufnr namespace hlgroup [start-row0 start-col]
                                [end-row end-col])
           (clear-highlights bufnr))
        (vim.schedule))))

(fn on-bytes [_string-bytes
              bufnr
              _changedtick
              start-row0
              start-col
              _byte-offset
              old-end-row-offset
              old-end-col-offset
              _old-end-byte-offset
              new-end-row-offset
              new-end-col-offset
              _new-end-byte-offset]
  ;; (vim.print {: _string-bytes
  ;;             : bufnr
  ;;             : _changedtick
  ;;             : start-row0
  ;;             : start-col
  ;;             : _byte-offset
  ;;             : old-end-row-offset
  ;;             : old-end-col-offset
  ;;             : _old-end-byte-offset
  ;;             : new-end-row-offset
  ;;             : new-end-col-offset
  ;;             : _new-end-byte-offset})
  (when (and (vim.api.nvim_buf_is_valid bufnr)
             (-> (vim.api.nvim_get_mode)
                 (. :mode)
                 ;; TODO: Configurable modes to highlight?
                 (: :find :n)))
    ;; TODO: Highlight removed texts by extmarks.
    (if (or (< old-end-row-offset new-end-row-offset)
            (and (= 0 old-end-row-offset new-end-row-offset) ;
                 (< old-end-col-offset new-end-col-offset)))
        (glow-added-texts bufnr [start-row0 start-col]
                          [new-end-row-offset new-end-col-offset]))))

(var biggest-bufnr -1)

(local wipedout-bufnrs {})

(fn excluded-buffer? [buf]
  (not (vim.tbl_contains M.config.excluded_filetypes ;
                         (. vim.bo buf :filetype))))

(fn setup [opts]
  (let [id (vim.api.nvim_create_augroup :HlBigChange {})]
    (set M.config (vim.tbl_deep_extend :keep (or opts {}) M.config))
    (vim.api.nvim_set_hl 0 :HlBigChangeAdded
                         {:default true :bg "#2d4f67" :fg "#dcd7ba"})
    (vim.api.nvim_set_hl 0 :HlBigChangeRemoved
                         {:default true :bg "#dcd7ba" :fg "#2d4f67"})
    (vim.api.nvim_create_autocmd :BufWipeout
      {:group id
       :callback (fn [a]
                   (tset wipedout-bufnrs a.buf true))})
    (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
      (vim.api.nvim_buf_attach buf false {:on_bytes on-bytes}))
    (vim.api.nvim_create_autocmd :BufWinEnter
      {:group id
       :callback (fn [a]
                   (if (. wipedout-bufnrs a.buf)
                       (tset wipedout-bufnrs a.buf nil)
                       (and (< biggest-bufnr a.buf) ;
                            (excluded-buffer? a.buf))
                       (-> (fn []
                             (set biggest-bufnr a.buf)
                             (when (and (vim.api.nvim_buf_is_valid a.buf))
                               (vim.api.nvim_buf_attach a.buf false
                                                        {:on_bytes on-bytes})))
                           (vim.defer_fn M.config.attach_delay)))
                   ;; HACK: Keep the `nil` to resist autocmd deletion.
                   nil)})))

{: setup}
