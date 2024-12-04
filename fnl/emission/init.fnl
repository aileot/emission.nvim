(local {: Stack} (require :emission.utils.stack))
(local {: set-debug-config! : trace! : debug!} (require :emission.utils.logger))

(local config (require :emission.config))

(local cache {:config (setmetatable {}
                        {:__index (fn [_t k]
                                    (. config._config k))
                         :__newindex (fn []
                                       (error "No new entry is allowed"))})
              :namespace (vim.api.nvim_create_namespace :emission)
              :buf->pending-highlights (setmetatable {}
                                         {:__index (fn [t k]
                                                     (tset t k (Stack.new))
                                                     (rawget t k))})
              :hl-group {:added :EmissionAdded :removed :EmissionRemoved}
              :last-editing-position [0 0]
              :buf->detach? {}
              :last-recache-time 0
              :buf->old-texts {}})

(local vim/hl (or vim.hl vim.highlight))

(macro when-not [cond ...]
  `(when (not ,cond)
     ,...))

(fn inc [x]
  (+ x 1))

(fn dec [x]
  (- x 1))

(fn buf-has-cursor? [buf]
  ;; NOTE: Typically avoid atttaching to scratch bufs created in background
  ;; by some plugins, but does this work as expected?
  (= buf (vim.api.nvim_win_get_buf 0)))

(fn cache-old-texts [buf]
  (debug! "attempt to cache texts" buf)
  (tset cache.buf->old-texts buf ;
        (vim.api.nvim_buf_get_lines buf 0 -1 false))
  (assert (. cache.buf->old-texts buf)
          "Failed to cache lines on attaching to buffer")
  (debug! "cached texts" buf))

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

(fn clear-highlights! [buf]
  "Immediately clear all the emission highlights in `buf`.
  @param buf number"
  (vim.api.nvim_buf_clear_namespace buf cache.namespace 0 -1)
  (debug! "cleared highlights" buf))

(fn request-to-clear-highlights! [buf]
  "Clear highlights in `buf` after `duration` in milliseconds.
  @param buf number"
  (-> #(when (vim.api.nvim_buf_is_valid buf)
         (debug! "clearing namespace after duration" buf)
         (clear-highlights! buf))
      (vim.defer_fn cache.config.highlight.duration)))

(fn discard-pending-highlights! [buf]
  (tset cache.buf->pending-highlights buf nil)
  (debug! "discarded highlight stack" buf))

(fn request-to-highlight! [buf callback]
  "Reserve the highlight callback to execute at once all the callbacks stacked
  during a highlight delay.
  @param buf number
  @param callback function"
  (debug! "reserving new highlights" buf)
  (assert (= :function (type callback))
          (.. "expected function, got " (type callback)))
  (let [pending-highlights (. cache.buf->pending-highlights buf)]
    (pending-highlights:push! callback)
    (-> #(when (and (not (. cache.buf->detach? buf))
                    (vim.api.nvim_buf_is_valid buf) ;
                    (buf-has-cursor? buf))
           (debug! (: "executing a series of pending %d highlight(s)" :format
                      (length (pending-highlights:get))) buf)
           (while (not (pending-highlights:empty?))
             (let [hl-cb (pending-highlights:pop!)]
               (hl-cb)))
           (cache-old-texts buf)
           (request-to-clear-highlights! buf))
        (vim.defer_fn cache.config.highlight.delay))))

(fn dismiss-deprecated-highlight! [buf [start-row0 start-col0]]
  "Immediately dismiss emission highlights set at the same position.
  @param buf number
  @param [start-row0 start-col0] number[]"
  (match cache.last-editing-position
    [start-row0 start-col0]
    ;; NOTE: For the maintainability, prefer the simplisity of dismissing all
    ;; the highlights over lines to the exactness with specifying the range.
    (do
      (debug! (: "dismissing all the buf highlights due to the duplicated positioning {row0: %d, col0: %d}"
                 :format start-row0 start-col0) ;
              buf)
      (clear-highlights! buf))
    _
    false)
  (set cache.last-editing-position [start-row0 start-col0]))

(fn dismiss-deprecated-highlights! [buf [start-row0 start-col0]]
  "Immediately dismiss emission highlights at the same position.
  @param buf number
  @param [start-row0 start-col0] number[]"
  ;; TODO: (Low priority) Iterate over the changes considering the option
  ;; value continuous_editing_time.
  (dismiss-deprecated-highlight! buf [start-row0 start-col0]))

(fn highlight-added-texts! [buf
                            start-row0
                            start-col0
                            new-end-row-offset
                            new-end-col-offset]
  (let [hl-group cache.hl-group.added
        num-lines (vim.api.nvim_buf_line_count buf)
        end-row (+ start-row0 new-end-row-offset)
        end-col (if (< end-row num-lines)
                    (+ start-col0 new-end-col-offset)
                    (-> (vim.api.nvim_buf_get_lines buf -2 -1 false)
                        (. 1)
                        (length)))
        hl-opts {:priority cache.config.added.priority}]
    (-> #(when (and (vim.api.nvim_buf_is_valid buf) ;
                    (buf-has-cursor? buf))
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! buf [start-row0 start-col0])
           (debug! (: "highlighting `added` range {row0: %d, col0: %d} to {row: %d, col: %d}"
                      :format start-row0 start-col0 end-row end-col)
                   buf)
           (vim/hl.range buf cache.namespace hl-group [start-row0 start-col0]
                         [end-row end-col] hl-opts))
        (vim.schedule))))

(fn extend-chunk-to-win-width! [chunk]
  "Extend `chunk` to conceal actual texts under highlights."
  (let [max-col (vim.api.nvim_win_get_width 0)
        blank-chunk [(string.rep " " max-col)]]
    (table.insert chunk blank-chunk)
    chunk))

(fn highlight-removed-texts! [buf
                              start-row0
                              start-col0
                              old-end-row-offset
                              old-end-col-offset]
  (debug! (: "highlighting `removed` range {row0: %d, col0: %d} by the offsets {row: %d, col: %d}"
             :format start-row0 start-col0 old-end-row-offset old-end-col-offset)
          buf)
  (let [hl-group cache.hl-group.removed
        old-texts (assert (. cache.buf->old-texts buf)
                          "expected string[], got `nil `or `false`")
        old-end-row (length old-texts)
        start-row (math.min (inc start-row0) old-end-row)
        ends-with-newline? (= 0 old-end-col-offset)
        old-end-row-offset* (if ends-with-newline?
                                ;; NOTE: "\n" at the last line is counted as
                                ;; an extra offset.
                                (dec old-end-row-offset)
                                old-end-row-offset)
        removed-end-row (+ start-row old-end-row-offset*)
        new-end-row (vim.api.nvim_buf_line_count buf)
        can-virt_text-display-first-line-removed? (< start-row0 new-end-row)
        ;; NOTE: first-removed-line will compose `virt_text` unless the EOF
        ;; is removed.
        first-removed-line (-> (. old-texts start-row)
                               (string.sub (inc start-col0)
                                           (when (= 0 old-end-row-offset)
                                             (+ start-col0 old-end-col-offset))))
        ;; NOTE: The rest ?middle-removed-lines and ?last-removed-line will
        ;; compose `virt_lines`.
        ?middle-removed-lines (when (< 1 old-end-row-offset)
                                (vim.list_slice old-texts (inc start-row)
                                                removed-end-row))
        ?last-removed-line (when (and (< 0 old-end-row-offset)
                                      ;; NOTE: When col-offset is 0, the last
                                      ;; row is only composed by a `\n`, which
                                      ;; should not be counted.
                                      (< 0 old-end-col-offset))
                             (-> (. old-texts removed-end-row)
                                 (string.sub 1 old-end-col-offset)))
        ?first-line-chunk [[first-removed-line hl-group]]
        ?rest-line-chunks (if ?middle-removed-lines
                              (do
                                (table.insert ?middle-removed-lines
                                              ?last-removed-line)
                                (->> ?middle-removed-lines
                                     (vim.tbl_map #[[$ hl-group]])))
                              ?last-removed-line
                              [[[?last-removed-line hl-group]]])
        removed-end-row (+ start-row old-end-row-offset*)
        (fitted-chunks exceeded-chunks) (if (= nil ?rest-line-chunks)
                                            (values [] [])
                                            (< removed-end-row new-end-row)
                                            (values ?rest-line-chunks [])
                                            (let [offset (- new-end-row
                                                            start-row)]
                                              (values (-> ?rest-line-chunks
                                                          (vim.list_slice 1
                                                                          offset))
                                                      (-> ?rest-line-chunks
                                                          (vim.list_slice (inc offset))))))
        extmark-opts {:hl_eol true
                      :strict false
                      :priority cache.config.removed.priority
                      :virt_text_pos :overlay}]
    (-> #(when (and (vim.api.nvim_buf_is_valid buf) ;
                    (buf-has-cursor? buf))
           (open-folds-at-cursor!)
           (dismiss-deprecated-highlights! buf [start-row0 start-col0])
           (if can-virt_text-display-first-line-removed?
               (do
                 (set extmark-opts.virt_text
                      (if (or (next fitted-chunks) (next exceeded-chunks))
                          ;; When the text is removed to the end of the line.
                          (extend-chunk-to-win-width! ?first-line-chunk)
                          ;; When the text is removed in the middle of the
                          ;; line.
                          ?first-line-chunk))
                 (debug! (: "set `virt_text` for first line at {row0: %d, col0: %d}"
                            :format start-row0 start-col0)
                         buf)
                 (vim.api.nvim_buf_set_extmark buf cache.namespace start-row0
                                               start-col0 extmark-opts))
               ;; NOTE: To insert first chunk here with few manipulations,
               ;; make sure rest-chunks is not nil, but a sequence.
               (next fitted-chunks)
               (table.insert fitted-chunks 1 ?first-line-chunk)
               (table.insert exceeded-chunks 1 ?first-line-chunk))
           (when (next fitted-chunks)
             (each [i chunk (ipairs fitted-chunks)]
               (let [row0 (+ start-row0 i)]
                 (set extmark-opts.virt_text (extend-chunk-to-win-width! chunk))
                 (debug! (: "set `virt_text` for `fitted-chunk` at the row %d"
                            :format row0))
                 (vim.api.nvim_buf_set_extmark buf cache.namespace ;
                                               row0 0 extmark-opts))))
           (when (next exceeded-chunks)
             (set extmark-opts.virt_text nil)
             (set extmark-opts.virt_lines
                  (vim.tbl_map extend-chunk-to-win-width! exceeded-chunks))
             (let [new-end-row0 (dec new-end-row)]
               (debug! (: "set `virt_lines` for `exceeded-chunks` at the row %d"
                          :format new-end-row0))
               (vim.api.nvim_buf_set_extmark buf cache.namespace ;
                                             new-end-row0 0 extmark-opts))))
        (vim.schedule))))

(fn on-bytes [_string-bytes
              buf
              _changedtick
              start-row0
              start-col0
              _byte-offset
              old-end-row-offset
              old-end-col-offset
              old-end-byte-offset
              new-end-row-offset
              new-end-col-offset
              new-end-byte-offset]
  (if (. cache.buf->detach? buf)
      true
      ;; NOTE: Return a truthy value to detach.
      ;; NOTE: `on_bytes` would be called before buf becomes valid; therefore,
      ;; check to detach should only be managed by `buf->detach` value.
      (when (and (vim.api.nvim_buf_is_valid buf) ;
                 (buf-has-cursor? buf) ;
                 (<= cache.config.highlight.min_byte
                     (math.max old-end-byte-offset new-end-byte-offset))
                 (cache.config.highlight.filter buf))
        ;; NOTE: When col-offset is 0, the last row is only composed by
        ;; a `\n`, which should not be counted.
        (->> #(let [display-start-row (vim.fn.line :w0)
                    display-offset (vim.api.nvim_win_get_height 0)
                    display-end-row (+ display-start-row display-offset)]
                (when (or (< start-row0 display-end-row)
                          (< display-start-row
                             (+ start-row0 old-end-row-offset))
                          (< display-start-row
                             (+ start-row0 new-end-row-offset)))
                  (debug! (.. "start row0: " start-row0) buf)
                  (debug! (.. "display start row: " display-start-row))
                  (debug! (.. "display end row: " display-end-row))
                  (debug! (.. "old row offset: " old-end-row-offset))
                  (debug! (.. "new row offset: " new-end-row-offset))
                  (let [display-row-offset (- display-end-row display-start-row)
                        start-row0* (math.max start-row0
                                              (dec display-start-row))]
                    (if (or (< old-end-row-offset new-end-row-offset)
                            (and (= 0 old-end-row-offset new-end-row-offset)
                                 (< 0 new-end-col-offset)))
                        (when (<= cache.config.added.min_row_offset
                                  (+ new-end-row-offset
                                     ;; NOTE: Reduce offset by 1 if col-offset
                                     ;; is 0; otherwise, keep the row-offset.
                                     (- -1 (math.min 1 new-end-col-offset))))
                          (let [row-exceeded? (< display-row-offset
                                                 new-end-row-offset)
                                row-offset (if row-exceeded?
                                               display-row-offset
                                               new-end-row-offset)
                                col-offset (if row-exceeded? 0
                                               new-end-col-offset)]
                            (highlight-added-texts! buf start-row0* start-col0
                                                    row-offset col-offset)))
                        (when (<= cache.config.removed.min_row_offset
                                  (+ old-end-row-offset
                                     ;; NOTE: Reduce offset by 1 if col-offset
                                     ;; is 0; otherwise, keep the row-offset.
                                     (- -1 (math.min 1 old-end-col-offset))))
                          (let [row-exceeded? (< display-row-offset
                                                 old-end-row-offset)
                                row-offset (if row-exceeded?
                                               display-row-offset
                                               old-end-row-offset)
                                col-offset (if row-exceeded? 0
                                               old-end-col-offset)]
                            (highlight-removed-texts! buf start-row0*
                                                      start-col0 row-offset
                                                      col-offset)))))))
             (request-to-highlight! buf))
        ;; HACK: Keep the `nil` to make sure not to detach unexpectedly.
        nil)))

(fn on-detach [_string-detach buf]
  (tset cache.buf->detach? buf nil)
  (debug! "detached from buf" buf))

(fn excluded-buf? [buf]
  (or (vim.list_contains cache.config.attach.excluded_buftypes
                         (. vim.bo buf :buftype))
      (vim.list_contains cache.config.attach.excluded_filetypes
                         (. vim.bo buf :filetype))))

(fn request-to-attach-buf! [buf]
  ;; NOTE: The option `attach.delay` helps avoid the following issues:
  ;; 1. Unexpected attaching to bufs before the filetype of a buf is not
  ;;    determined; the event fired order of FileType and BufEnter is not
  ;;    guaranteed.
  ;; 2. Extra attaching attempts to a series of bufs with rapid firing
  ;;    BufEnter events like sequential editing with `:cdo`.
  ;; 3. Extra attaching attempts to scratch bufs created in background by
  ;;    such plugins as formatters, linters, and completions, though they
  ;;    should be efficiently excluded by `excluded_buftypes`.
  ;; Therefore, `excluded-buf?` check must be included in `vim.defer_fn`.
  (debug! "requested to attach buf" buf)
  (-> #(if (and (vim.api.nvim_buf_is_valid buf) ;
                (buf-has-cursor? buf) ;
                (not (excluded-buf? buf)))
           (do
             (cache-old-texts buf)
             (vim.api.nvim_buf_attach buf false
                                      {:on_bytes on-bytes :on_detach on-detach})
             (debug! "attached to buf" buf))
           (debug! "the buf did not meet the requirements to be attached" buf))
      (vim.defer_fn cache.config.attach.delay))
  ;; HACK: Keep the `nil` to make sure to resist autocmd
  ;; deletion with any future updates.
  nil)

(fn request-to-detach-buf! [buf]
  (debug! "requested to detach buf" buf)
  ;; Make sure to clear highlights on the buf.
  (clear-highlights! buf 0)
  (discard-pending-highlights! buf)
  ;; NOTE: On neovim 0.10.2, there is no function to detach buf directly.
  (tset cache.buf->detach? buf true))

(lua "
---@param opts? emission.Config
--- Initialize emission.
--- Your options are always merged into the default config,
--- not the current config.")

(fn setup [opts]
  (let [opts (or opts {})
        id (vim.api.nvim_create_augroup :Emission {})]
    ;; NOTE: Every `cache.config` value should be got via metatable.
    (config.merge opts)
    (set-debug-config! cache.config.debug)
    (trace! (.. "merged config: " (vim.inspect cache.config)))
    ;; NOTE: `vim.api.nvim_set_hl` always returns `nil`; to get the hl-group
    ;; id, `vim.api.nvim_get_hl` is additionally required.
    (vim.api.nvim_set_hl 0 cache.hl-group.added cache.config.added.hl_map)
    (vim.api.nvim_set_hl 0 cache.hl-group.removed cache.config.removed.hl_map)
    (request-to-attach-buf! (vim.api.nvim_get_current_buf))
    (each [_ event (ipairs cache.config.highlight.additional_recache_events)]
      (vim.api.nvim_create_autocmd event
        {:group id :callback #(cache-old-texts $.buf)}))
    (vim.api.nvim_create_autocmd :BufEnter
      {:group id :callback #(request-to-attach-buf! $.buf)})
    (vim.api.nvim_create_autocmd :BufLeave
      {:group id :callback #(request-to-detach-buf! $.buf)})
    nil))

;; NOTE: For end-users, the documentation is slightly different from
;; `config.reset` which internaly correlates with `config.merge`.
(lua "
--- Reset current config to the last config determined by `emission.setup()`.
---@return emission.Config")

(fn reset []
  (config.reset))

{: setup :override config.override : reset}
