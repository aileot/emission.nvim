(local cache {:config {:duration 400
                       :excluded_filetypes [:lazy :oil]
                       :added {:hlgroup :EmissionAdded}
                       :removed {:hlgroup :EmissionRemoved}}
              :timer (vim.uv.new_timer)
              :attached-buffer nil
              :buffer->detach {}
              :last-texts nil})

(local namespace (vim.api.nvim_create_namespace :Emission))

(macro when-not [cond ...]
  `(when (not ,cond)
     ,...))

(fn inc [x]
  (+ x 1))

(fn dec [x]
  (- x 1))

(fn cache-last-texts [bufnr]
  (set cache.last-texts ;
       (vim.api.nvim_buf_get_lines bufnr 0 -1 false)))

(fn open-folds-on-undo []
  (let [foldopen (vim.opt.foldopen:get)]
    (when (or (vim.list_contains foldopen :undo)
              (vim.list_contains foldopen :all))
      (vim.cmd "normal! zv"))))

(fn clear-highlights [bufnr]
  (cache.timer:stop)
  (cache.timer:start cache.config.duration 0
                     #(-> (fn []
                            (when (vim.api.nvim_buf_is_valid bufnr)
                              (vim.api.nvim_buf_clear_namespace bufnr namespace
                                                                0 -1)))
                          (vim.schedule))))

(fn glow-added-texts [bufnr
                      [start-row0 start-col]
                      [new-end-row-offset new-end-col-offset]]
  (let [hlgroup cache.config.added.hlgroup
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
  (let [hlgroup cache.config.removed.hlgroup
        last-texts cache.last-texts
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
  (when (. cache.buffer->detach bufnr)
    (tset cache.buffer->detach bufnr nil)
    ;; NOTE: Return a truthy value to detach.
    true)
  (when (and (vim.api.nvim_buf_is_valid bufnr)
             (-> (vim.api.nvim_get_mode)
                 (. :mode)
                 ;; TODO: Configurable modes to highlight?
                 (: :find :n)))
    (if (or (< old-end-row-offset new-end-row-offset)
            (and (= 0 old-end-row-offset new-end-row-offset) ;
                 (< old-end-col-offset new-end-col-offset)))
        (glow-added-texts bufnr [start-row0 start-col]
                          [new-end-row-offset new-end-col-offset])
        (glow-removed-texts bufnr [start-row0 start-col]
                            [old-end-row-offset old-end-col-offset]))
    (cache-last-texts bufnr)))

(fn excluded-buffer? [buf]
  (vim.list_contains cache.config.excluded_filetypes ;
                     (. vim.bo buf :filetype)))

(fn attach-buffer! [buf]
  "Attach to `buf`. This function should not be called directly other than
  `request-to-attach-buffer!`."
  (set cache.attached-buffer buf)
  (tset cache.buffer->detach buf nil)
  (cache-last-texts buf)
  (vim.api.nvim_buf_attach buf false {:on_bytes on-bytes}))

(fn request-to-attach-buffer! [buf]
  (when-not (excluded-buffer? buf)
    (-> #(when (vim.api.nvim_buf_is_valid buf)
           (attach-buffer! buf))
        (vim.schedule)))
  ;; HACK: Keep the `nil` to make sure to resist autocmd
  ;; deletion with any future updates.
  nil)

(fn request-to-detach-buffer! [buf]
  ;; NOTE: On neovim 0.10.2, there is no function to detach buffer directly.
  (when-not (= buf cache.attached-buffer)
    (tset cache.buffer->detach buf true)))

(fn setup [opts]
  (let [id (vim.api.nvim_create_augroup :Emission {})]
    (set cache.config (vim.tbl_deep_extend :keep (or opts {}) cache.config))
    (vim.api.nvim_set_hl 0 :EmissionAdded
                         {:default true :fg "#dcd7ba" :bg "#2d4f67"})
    (vim.api.nvim_set_hl 0 :EmissionRemoved
                         {:default true :fg "#dcd7ba" :bg "#672d2d"})
    (attach-buffer! (vim.api.nvim_get_current_buf))
    (vim.api.nvim_create_autocmd :BufEnter
      {:group id :callback #(request-to-attach-buffer! $.buf)})
    (vim.api.nvim_create_autocmd :BufLeave
      {:group id :callback #(request-to-detach-buffer! $.buf)})))

{: setup}
