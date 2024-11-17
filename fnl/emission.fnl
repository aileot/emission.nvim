(local {: Stack} (require :emission.utils))

(local cache {:config {:attach_delay 100
                       :excluded_filetypes []
                       :highlight_delay 10
                       :added {:hl_map {:default true
                                        :fg "#dcd7ba"
                                        :bg "#2d4f67"}
                               :priority 102
                               :duration 400
                               :filter (fn [])}
                       :removed {:hl_map {:default true
                                          :fg "#dcd7ba"
                                          :bg "#672d2d"}
                                 :priority 101
                                 :duration 400
                                 :filter (fn [])}}
              :timer (vim.uv.new_timer)
              :pending-highlights (Stack.new)
              :hl-group {:added :EmissionAdded :removed :EmissionRemoved}
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

(fn cache-last-texts [buf]
  (let [now (vim.uv.now)]
    (when (or (not= buf cache.attached-buffer)
              (< cache.config.highlight_delay (- now cache.last-recache-time)))
      ;; NOTE: highlight_delay for multi-line editing which sequentially
      ;; calls `on_bytes` line by line like `:substitute`.
      (set cache.last-recache-time now)
      (set cache.last-texts ;
           (vim.api.nvim_buf_get_lines buf 0 -1 false))
      (set cache.attached-buffer buf))))

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

(fn clear-highlights! [buf duration]
  "Clear highlights in `buf` after `duration` in milliseconds.
  @param buf number
  @param duration number milliseconds"
  (set cache.last-duration duration)
  (cache.timer:start duration 0
                     #(-> (fn []
                            (when (vim.api.nvim_buf_is_valid buf)
                              (vim.api.nvim_buf_clear_namespace buf namespace 0
                                                                -1)))
                          (vim.schedule))))

(fn reserve-highlight! [buf callback]
  "Reserve the highlight callback to execute at once all the callbacks stacked
  during a highlight delay.
  @param buf number
  @param callback function"
  (assert (= :function (type callback))
          (.. "expected function, got " (type callback)))
  (cache.pending-highlights:push! callback)
  (cache.timer:start cache.config.highlight_delay 0
                     #(-> (fn []
                            (when (and (= buf cache.attached-buffer)
                                       (vim.api.nvim_buf_is_valid buf))
                              (while (not (cache.pending-highlights:empty?))
                                (let [cb (cache.pending-highlights:pop!)]
                                  (cb)))))
                          (vim.schedule))))

(fn highlight-added-texts! [buf
                            [start-row0 start-col]
                            [new-end-row-offset new-end-col-offset]]
  (let [hl-group cache.hl-group.added
        num-lines (vim.api.nvim_buf_line_count buf)
        end-row (+ start-row0 new-end-row-offset)
        end-col (if (< end-row num-lines)
                    (+ start-col new-end-col-offset)
                    (-> (vim.api.nvim_buf_get_lines buf -2 -1 false)
                        (. 1)
                        (length)))
        hl-opts {:priority cache.config.added.priority}]
    (-> #(when (vim.api.nvim_buf_is_valid buf)
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! buf [start-row0 start-col])
           (vim/hl.range buf namespace hl-group [start-row0 start-col]
                         [end-row end-col] hl-opts)
           (cache-last-texts buf))
        (vim.schedule))))

(fn compose-chunks [buf
                    [start-row0 start-col]
                    [old-end-row-offset old-end-col-offset]]
  "Compose chunks for virtual texts to be set by `vim.api.nvim_buf_set_extmark`.
  @param buf number
  @param [start-row0 start-col] number[]
  @param [old-end-row-offset old-end-row-offset] number[]
  @return table"
  (let [hl-group cache.hl-group.removed
        last-texts (assert cache.last-texts
                           "expected string[], got `nil `or `false`")
        start-row (inc start-row0)
        ends-with-newline? (= 0 old-end-col-offset)
        old-end-row-offset* (if ends-with-newline?
                                ;; NOTE: "\n" at the last line is counted as
                                ;; an extra offset.
                                (dec old-end-row-offset)
                                old-end-row-offset)
        removed-last-row (+ start-row old-end-row-offset*)
        current-last-row (vim.api.nvim_buf_line_count buf)
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
        ?last-removed-line (when (and (< 0 old-end-row-offset)
                                      ;; NOTE: When col-offset is 0, the last
                                      ;; row is only composed by a `\n`, which
                                      ;; should not be counted.
                                      (< 0 old-end-col-offset))
                             (-> (. last-texts removed-last-row)
                                 (: :sub 1 old-end-col-offset)))
        ?first-line-chunk (when-not should-virt_lines-include-first-line-removed?
                            [[first-removed-line hl-group]])
        ?rest-line-chunks (if ?middle-removed-lines
                              (do
                                (table.insert ?middle-removed-lines
                                              ?last-removed-line)
                                (->> ?middle-removed-lines
                                     (vim.tbl_map #[[$ hl-group]])))
                              ?last-removed-line
                              [[[?last-removed-line hl-group]]])
        _ (when (and should-virt_lines-include-first-line-removed?
                     ?rest-line-chunks)
            (table.insert ?rest-line-chunks 1 [[first-removed-line hl-group]]))
        row0 (if should-virt_lines-include-first-line-removed?
                 (dec start-row0)
                 start-row0)
        col0 start-col]
    {:virt_text ?first-line-chunk :virt_lines ?rest-line-chunks : row0 : col0}))

(fn highlight-removed-texts! [buf
                              [start-row0 start-col]
                              [old-end-row-offset old-end-col-offset]]
  (let [{: virt_text : virt_lines : row0 : col0} (compose-chunks buf
                                                                 [start-row0
                                                                  start-col]
                                                                 [old-end-row-offset
                                                                  old-end-col-offset])
        extmark-opts {:hl_eol true
                      :strict false
                      : virt_text
                      : virt_lines
                      :priority cache.config.removed.priority
                      :virt_text_pos :overlay}]
    (-> #(when (vim.api.nvim_buf_is_valid buf)
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! buf [start-row0 start-col])
           (if (= row0 start-row0)
               (do
                 (set extmark-opts.virt_lines nil)
                 (vim.api.nvim_buf_set_extmark buf namespace row0 col0
                                               extmark-opts)
                 (case (and virt_lines (length virt_lines))
                   (where new-end-row-offset (< 0 new-end-row-offset))
                   (for [offset 1 new-end-row-offset]
                     (set extmark-opts.virt_text (. virt_lines offset))
                     (vim.api.nvim_buf_set_extmark buf namespace
                                                   (+ row0 offset) 0
                                                   extmark-opts))))
               (vim.api.nvim_buf_set_extmark buf namespace row0 col0
                                             extmark-opts)))
        (vim.schedule))))

(fn on-bytes [_string-bytes
              buf
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
  (if (. cache.buffer->detach buf) ;
      (do
        ;; Make sure to clear highlights on the detached buffer.
        (clear-highlights! buf 0)
        (tset cache.buffer->detach buf nil)
        ;; NOTE: Return a truthy value to detach.
        true) ;
      ;; NOTE: `on_bytes` would be called before buf becomes valid; therefore,
      ;; check to detach should only be managed by `buffer->detach` value.
      (when (vim.api.nvim_buf_is_valid buf)
        (if (or (< old-end-row-offset new-end-row-offset)
                (and (= 0 old-end-row-offset new-end-row-offset)
                     (<= old-end-col-offset new-end-col-offset)))
            (when (cache.config.added.filter buf)
              (->> (fn []
                     (highlight-added-texts! buf [start-row0 start-col]
                                             [new-end-row-offset
                                              new-end-col-offset])
                     (clear-highlights! buf cache.config.added.duration))
                   (reserve-highlight! buf)))
            (when (cache.config.removed.filter buf)
              (->> (fn []
                     (highlight-removed-texts! buf [start-row0 start-col]
                                               [old-end-row-offset
                                                old-end-col-offset])
                     (clear-highlights! buf cache.config.removed.duration))
                   (reserve-highlight! buf))))
        ;; HACK: Keep the `nil` to make sure not to detach unexpectedly.
        nil)))

(fn excluded-buffer? [buf]
  (vim.list_contains cache.config.excluded_filetypes ;
                     (. vim.bo buf :filetype)))

(fn request-to-attach-buffer! [buf]
  ;; NOTE: The option `attach_delay` helps avoid the following issues:
  ;; 1. Unexpected attaching to buffers before the filetype of a buffer is not
  ;;    determined; the event fired order of FileType and BufEnter is not
  ;;    guaranteed.
  ;; 2. Extra attaching attempts to a series of buffers with rapid firing
  ;;    BufEnter events like sequential editing with `:cdo`.
  ;; Therefore, `excluded-buffer?` check must be included in `vim.defer_fn`.
  (-> #(when (and (vim.api.nvim_buf_is_valid buf) ;
                  (= buf (vim.api.nvim_win_get_buf 0))
                  (not (excluded-buffer? buf)))
         (set cache.attached-buffer buf)
         (tset cache.buffer->detach buf nil)
         (cache-last-texts buf)
         (vim.api.nvim_buf_attach buf false {:on_bytes on-bytes})
         (assert cache.last-texts "Failed to cache lines on attaching to buffer"))
      (vim.defer_fn cache.config.attach_delay))
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
    ;; NOTE: `vim.api.nvim_set_hl` always returns `nil`; to get the hl-group
    ;; id, `vim.api.nvim_get_hl` is additionally required.
    (vim.api.nvim_set_hl 0 cache.hl-group.added cache.config.added.hl_map)
    (vim.api.nvim_set_hl 0 cache.hl-group.removed cache.config.removed.hl_map)
    (request-to-attach-buffer! (vim.api.nvim_get_current_buf))
    (vim.api.nvim_create_autocmd :BufEnter
      {:group id :callback #(request-to-attach-buffer! $.buf)})
    (vim.api.nvim_create_autocmd :BufLeave
      {:group id :callback #(request-to-detach-buffer! $.buf)})))

{: setup}
