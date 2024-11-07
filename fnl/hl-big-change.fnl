(local M {:config {:attach_delay 100
                   :duration 400
                   :excluded_filetypes []
                   :hlgroup {:added :HlBigChangeAdded
                             :removed :HlBigChangeRemoved}}
          :timer (vim.uv.new_timer)
          :last-texts {}})

(local namespace (vim.api.nvim_create_namespace :HlBigChange))

(macro when-not [cond ...]
  `(when (not ,cond)
     ,...))

(fn inc [x]
  (+ x 1))

(fn dec [x]
  (- x 1))

(fn cache-last-texts [bufnr]
  (tset M.last-texts bufnr ;
        (vim.api.nvim_buf_get_lines bufnr 0 -1 false)))

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

(fn glow-removed-texts [bufnr
                        [start-row0 start-col]
                        [old-end-row-offset old-end-col-offset]]
  (let [hlgroup M.config.hlgroup.removed
        last-texts (. M.last-texts bufnr)
        start-row (inc start-row0)
        first-removed-line (-> (. last-texts start-row)
                               (: :sub (inc start-col)
                                  (when (= 0 old-end-row-offset)
                                    (+ start-col old-end-col-offset))))
        ?middle-removed-lines (when (< 1 old-end-row-offset)
                                (vim.list_slice last-texts (inc start-row)
                                                (+ start-row old-end-row-offset
                                                   -1)))
        ?last-removed-line (when (< 0 old-end-row-offset)
                             (-> (. last-texts (+ start-row old-end-row-offset))
                                 (: :sub 1 old-end-col-offset)))
        removed-lines (if ?middle-removed-lines
                          (-> [first-removed-line
                               ?middle-removed-lines
                               ?last-removed-line]
                              (vim.iter)
                              (: :flatten)
                              (: :totable))
                          ?last-removed-line
                          [first-removed-line ?last-removed-line]
                          [first-removed-line])]
    (-> #(when (vim.api.nvim_buf_is_valid bufnr)
           (open-folds-on-undo)
           (let [start-col0 (dec start-col)
                 max-idx (if (= 0 old-end-col-offset)
                             (+ 2 old-end-row-offset)
                             (inc old-end-row-offset))]
             (for [i 1 max-idx]
               (let [line (. removed-lines i)
                     chunks (if (and (= i max-idx) (= 0 old-end-col-offset))
                                [[""]]
                                [[line hlgroup]])
                     row0 (+ start-row0 i -1)
                     col0 (if (= i 1) (inc start-col0)
                              (< i old-end-row-offset) 1
                              old-end-col-offset)
                     extmark-opts {:hl_eol true
                                   :strict false
                                   :virt_text chunks
                                   :virt_text_pos :inline}]
                 (vim.api.nvim_buf_set_extmark bufnr namespace row0 col0
                                               extmark-opts))))
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
    (if (or (<= old-end-row-offset new-end-row-offset)
            (and (= 0 old-end-row-offset new-end-row-offset) ;
                 (<= old-end-col-offset new-end-col-offset)))
        (glow-added-texts bufnr [start-row0 start-col]
                          [new-end-row-offset new-end-col-offset])
        (glow-removed-texts bufnr [start-row0 start-col]
                            [old-end-row-offset old-end-col-offset]))
    (cache-last-texts bufnr)))

(var biggest-bufnr -1)

(local wipedout-bufnrs {})

(fn excluded-buffer? [buf]
  (vim.list_contains M.config.excluded_filetypes ;
                     (. vim.bo buf :filetype)))

(fn attach-buffer! [buf]
  (cache-last-texts buf)
  (vim.api.nvim_buf_attach buf false {:on_bytes on-bytes}))

(fn setup [opts]
  (let [id (vim.api.nvim_create_augroup :HlBigChange {})]
    (set M.config (vim.tbl_deep_extend :keep (or opts {}) M.config))
    (vim.api.nvim_set_hl 0 :HlBigChangeAdded
                         {:default true :fg "#dcd7ba" :bg "#2d4f67"})
    (vim.api.nvim_set_hl 0 :HlBigChangeRemoved
                         {:default true :fg "#dcd7ba" :bg "#672d2d"})
    (vim.api.nvim_create_autocmd :BufWipeout
      {:group id
       :callback (fn [a]
                   (tset wipedout-bufnrs a.buf true))})
    (each [_ buf (ipairs (vim.api.nvim_list_bufs))]
      (when-not (excluded-buffer? buf)
        (attach-buffer! buf)))
    (vim.api.nvim_create_autocmd :BufWinEnter
      {:group id
       :callback (fn [a]
                   (if (. wipedout-bufnrs a.buf)
                       (tset wipedout-bufnrs a.buf nil)
                       (and (< biggest-bufnr a.buf) ;
                            (not (excluded-buffer? a.buf)))
                       (-> (fn []
                             (set biggest-bufnr a.buf)
                             (when (and (vim.api.nvim_buf_is_valid a.buf))
                               (attach-buffer! a.buf)))
                           (vim.defer_fn M.config.attach_delay)))
                   ;; HACK: Keep the `nil` to resist autocmd deletion.
                   nil)})))

{: setup}
