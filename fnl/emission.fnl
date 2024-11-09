(local cache {:config {:excluded_filetypes [:lazy :oil]
                       :min_recache_interval 50
                       :added {:hlgroup :EmissionAdded
                               :duration 400
                               :filter (fn [])}
                       :removed {:hlgroup :EmissionRemoved
                                 :duration 300
                                 :filter (fn [])}}
              :timer (vim.uv.new_timer)
              :last-duration 0
              :last-editing-position [0 0]
              :attached-buffer nil
              :buffer->detach {}
              :last-recache-time 0
              :last-texts nil})

(local namespace (vim.api.nvim_create_namespace :emission))

(local vim/hl (or vim.hl vim.highlight))

(macro when-not [cond ...]
  `(when (not ,cond)
     ,...))

(fn inc [x]
  (+ x 1))

(fn dec [x]
  (- x 1))

(fn cache-last-texts [bufnr]
  (let [now (vim.uv.now)]
    (when (or (not= bufnr cache.attached-buffer)
              (< cache.config.min_recache_interval
                 (- now cache.last-recache-time)))
      ;; NOTE: min_recache_interval for multi-line editing which sequentially
      ;; calls `on_bytes` line by line like `:substitute`.
      (set cache.last-recache-time now)
      (set cache.last-texts ;
           (vim.api.nvim_buf_get_lines bufnr 0 -1 false))
      (set cache.attached-buffer bufnr))))

(fn open-folds-at-cursor! []
  (let [foldopen (vim.opt.foldopen:get)]
    (when (or (vim.list_contains foldopen :undo)
              (vim.list_contains foldopen :all))
      ;; NOTE: `normal! zv` unexpectedly shifts cursor position.
      ;; NOTE: Tested by `nvim --clean` with manual `zf` folding, any
      ;; operations with `d`, `c`, or `s`, also removes all the folded lines
      ;; including the cursor line, regardless of the following, specified
      ;; range for the operators.
      (vim.cmd "silent! . foldopen!"))))

(fn dismiss-deprecated-highlight! [buf [start-row0 start-col]]
  "Dismiss highlights at the same position."
  (match cache.last-editing-position
    [start-row0 start-col]
    ;; NOTE: For the maintainability, prefer the simplisity of dismissing all
    ;; the highlights over lines to the exactness with specifying the range.
    (vim.api.nvim_buf_clear_namespace buf namespace 0 -1)
    _
    false)
  (set cache.last-editing-position [start-row0 start-col]))

(fn dismiss-deprecated-highlights! [buf [start-row0 start-col]]
  "Dismiss highlights at the same position."
  ;; TODO: (Low priority) Iterate over the changes considering the option
  ;; value continuous_editing_time.
  (dismiss-deprecated-highlight! buf [start-row0 start-col]))

(fn clear-highlights [bufnr duration]
  (set cache.last-duration duration)
  (cache.timer:start duration 0
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
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! bufnr [start-row0 start-col])
           (vim/hl.range bufnr namespace hlgroup [start-row0 start-col]
                         [end-row end-col])
           (clear-highlights bufnr cache.config.added.duration)
           (cache-last-texts bufnr))
        (vim.schedule))))

(fn glow-removed-texts [bufnr
                        [start-row0 start-col]
                        [old-end-row-offset old-end-col-offset]]
  (let [hlgroup cache.config.removed.hlgroup
        last-texts (assert cache.last-texts
                           "expected string[], got `nil `or `false`")
        start-row (inc start-row0)
        ends-with-newline? (= 0 old-end-col-offset)
        old-end-row-offset* (if ends-with-newline?
                                ;; NOTE: "\n" at the last line is counted as an extra offset.
                                (dec old-end-row-offset)
                                old-end-row-offset)
        removed-last-row (+ start-row old-end-row-offset*)
        current-last-row (vim.api.nvim_buf_line_count bufnr)
        end-of-file-removed? (< current-last-row removed-last-row)
        should-virt_lines-include-first-line-removed? (and end-of-file-removed?
                                                           (< 0 start-row0))
        ;; NOTE: first-removed-line will compose `virt_text` unless the EOF
        ;; is removed.
        first-removed-line (-> (. last-texts start-row)
                               (: :sub (inc start-col)
                                  (when (= 0 old-end-row-offset)
                                    (+ start-col old-end-col-offset))))
        ;; NOTE: The rest ?middle-removed-lines and ?last-removed-line will
        ;; compose `virt_lines`.
        ?middle-removed-lines (when (< 1 old-end-row-offset)
                                (vim.list_slice last-texts (inc start-row)
                                                removed-last-row))
        ?last-removed-line (when (< 0 old-end-row-offset)
                             (-> (. last-texts removed-last-row)
                                 (: :sub 1 old-end-col-offset)))
        ?first-line-chunk (when-not should-virt_lines-include-first-line-removed?
                            [[first-removed-line hlgroup]])
        ?rest-line-chunks (if ?middle-removed-lines
                              (do
                                (table.insert ?middle-removed-lines
                                              ?last-removed-line)
                                (->> ?middle-removed-lines
                                     (vim.tbl_map #[[$ hlgroup]])))
                              ?last-removed-line
                              [[[?last-removed-line hlgroup]]])
        _ (when should-virt_lines-include-first-line-removed?
            (table.insert ?rest-line-chunks 1 [[first-removed-line hlgroup]]))
        row0 (if should-virt_lines-include-first-line-removed?
                 (dec start-row0)
                 start-row0)
        col0 start-col
        extmark-opts {:hl_eol true
                      :strict false
                      :virt_text ?first-line-chunk
                      :virt_lines ?rest-line-chunks
                      :virt_text_pos :overlay}]
    (-> #(when (vim.api.nvim_buf_is_valid bufnr)
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! bufnr [start-row0 start-col])
           (vim.api.nvim_buf_set_extmark bufnr namespace row0 col0 extmark-opts)
           (clear-highlights bufnr cache.config.removed.duration))
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
  (when (. cache.buffer->detach bufnr)
    (tset cache.buffer->detach bufnr nil)
    ;; NOTE: Return a truthy value to detach.
    true)
  (when (vim.api.nvim_buf_is_valid bufnr)
    (if (or (< old-end-row-offset new-end-row-offset)
            (and (= 0 old-end-row-offset new-end-row-offset)
                 (< old-end-col-offset new-end-col-offset)))
        (when (cache.config.added.filter bufnr)
          (glow-added-texts bufnr [start-row0 start-col]
                            [new-end-row-offset new-end-col-offset]))
        (when (cache.config.removed.filter bufnr)
          (glow-removed-texts bufnr [start-row0 start-col]
                              [old-end-row-offset old-end-col-offset])))))

(fn excluded-buffer? [buf]
  (vim.list_contains cache.config.excluded_filetypes ;
                     (. vim.bo buf :filetype)))

(fn attach-buffer! [buf]
  "Attach to `buf`. This function should not be called directly other than
  `request-to-attach-buffer!`."
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
    (assert cache.last-texts "Failed to cache lines on attaching to buffer")
    (vim.api.nvim_create_autocmd :BufEnter
      {:group id :callback #(request-to-attach-buffer! $.buf)})
    (vim.api.nvim_create_autocmd :BufLeave
      {:group id :callback #(request-to-detach-buffer! $.buf)})))

{: setup}
