(local {: Stack} (require :emission.utils.stack))
(local {: set-debug-config! : debug-config : trace! : debug!}
       (require :emission.utils.logger))

(local uv (or vim.uv vim.loop))

(local default-config ;
       {:debug debug-config
        :attach {:delay 150
                 :excluded_filetypes []
                 :excluded_buftypes [:help :nofile :terminal :prompt]}
        :highlight {:duration 300
                    :min_byte 2
                    :filter #true
                    ;; NOTE: Should the option `delay` be exposed to users?
                    :delay 10}
        :added {:priority 102
                :hl_map {:default true :bold true :fg "#dcd7ba" :bg "#2d4f67"}}
        :removed {:priority 101
                  :hl_map {:default true
                           :bold true
                           :fg "#dcd7ba"
                           :bg "#672d2d"}}})

(local cache {:config (vim.deepcopy default-config)
              :namespace (vim.api.nvim_create_namespace :emission)
              :timer-to-highlight (uv.new_timer)
              :timer-to-clear-highlight (uv.new_timer)
              :pending-highlights (Stack.new)
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
  ;; by some plugins.
  (and (vim.api.nvim_buf_is_valid buf) ;
       (= buf (vim.api.nvim_win_get_buf 0))))

(fn cache-old-texts [buf]
  (debug! "attempt to cache texts" buf)
  (tset cache.buf->old-texts buf ;
        (vim.api.nvim_buf_get_lines buf 0 -1 false))
  (assert (. cache.buf->old-texts buf)
          "Failed to cache lines on attaching to buffer")
  (debug! "cached texts" buf))

(fn get-greedy-inline-diff [line1 line2]
  "Compare two strings and return the indices of the first greedy inline-diff.
  The same parts between the indices are ignored.
  @return number the index where the difference starts.
  @return number the larger index where the difference ends."
  (var i 1)
  (var j (length line1))
  (var k (length line2))
  (while (and (<= i j) (<= i k)
              (= (string.sub line1 i i) ;
                 (string.sub line2 i i)))
    (set i (inc i)))
  (while (and (< i j) (< i k)
              (= (string.sub line1 j j) ;
                 (string.sub line2 k k)))
    (set j (dec j))
    (set k (dec k)))
  (let [start-idx i
        end-idx (math.max j k)]
    (assert (<= start-idx end-idx)
            (: "expected `start-idx <= end-idx`, got {start: %d, end: %d}"
               :format start-idx end-idx))
    (values start-idx end-idx)))

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
  (vim.api.nvim_buf_clear_namespace buf cache.namespace 0 -1))

(fn request-to-clear-highlights! [buf]
  "Clear highlights in `buf` after `duration` in milliseconds.
  @param buf number"
  (let [duration cache.config.highlight.duration
        cb #(when (vim.api.nvim_buf_is_valid buf)
              (debug! "clearing namespace after duration" buf)
              (clear-highlights! buf))]
    (cache.timer-to-clear-highlight:start duration 0 #(vim.schedule cb))))

(fn request-to-highlight! [buf callback]
  "Reserve the highlight callback to execute at once all the callbacks stacked
  during a highlight delay.
  @param buf number
  @param callback function"
  (debug! "reserving new highlights" buf)
  (assert (= :function (type callback))
          (.. "expected function, got " (type callback)))
  (cache.pending-highlights:push! callback)
  (let [timer-cb #(when (and (not (. cache.buf->detach? buf))
                             (buf-has-cursor? buf))
                    (debug! (: "executing a series of pending %d highlight(s)"
                               :format (length (cache.pending-highlights:get)))
                            buf)
                    (while (not (cache.pending-highlights:empty?))
                      (let [hl-cb (cache.pending-highlights:pop!)]
                        (hl-cb)))
                    (cache-old-texts buf)
                    (request-to-clear-highlights! buf))]
    (cache.timer-to-highlight:start cache.config.highlight.delay 0
                                    #(vim.schedule timer-cb))))

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
    (-> #(when (buf-has-cursor? buf)
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
    (-> #(when (buf-has-cursor? buf)
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
  (if (. cache.buf->detach? buf) ;
      (do
        ;; Make sure to clear highlights on the detached buf.
        (clear-highlights! buf 0)
        (tset cache.buf->detach? buf nil)
        (debug! "detached from buf" buf)
        ;; NOTE: Return a truthy value to detach.
        true) ;
      ;; NOTE: `on_bytes` would be called before buf becomes valid; therefore,
      ;; check to detach should only be managed by `buf->detach` value.
      (when (and (buf-has-cursor? buf) ;
                 (<= cache.config.highlight.min_byte
                     (math.max old-end-byte-offset new-end-byte-offset))
                 (cache.config.highlight.filter buf))
        (->> #(if (or (< old-end-row-offset new-end-row-offset)
                      (and (= 0 old-end-row-offset new-end-row-offset)
                           (< 0 new-end-col-offset)))
                  (highlight-added-texts! buf start-row0 start-col0 ;
                                          new-end-row-offset new-end-col-offset)
                  (highlight-removed-texts! buf start-row0 start-col0 ;
                                            old-end-row-offset
                                            old-end-col-offset))
             (request-to-highlight! buf))
        ;; HACK: Keep the `nil` to make sure not to detach unexpectedly.
        nil)))

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
  (-> #(if (and (buf-has-cursor? buf) ;
                (not (excluded-buf? buf)))
           (do
             (cache-old-texts buf)
             (vim.api.nvim_buf_attach buf false {:on_bytes on-bytes})
             (debug! "attached to buf" buf))
           (debug! "the buf did not meet the requirements to be attached" buf))
      (vim.defer_fn cache.config.attach.delay))
  ;; HACK: Keep the `nil` to make sure to resist autocmd
  ;; deletion with any future updates.
  nil)

(fn request-to-detach-buf! [buf]
  (debug! "requested to detach buf" buf)
  ;; NOTE: On neovim 0.10.2, there is no function to detach buf directly.
  (tset cache.buf->detach? buf true))

(fn setup [opts]
  (let [id (vim.api.nvim_create_augroup :Emission {})]
    (set cache.config (vim.tbl_deep_extend :keep (or opts {}) cache.config))
    (set-debug-config! cache.config.debug)
    (trace! (.. "merged config: " (vim.inspect cache.config)))
    ;; NOTE: `vim.api.nvim_set_hl` always returns `nil`; to get the hl-group
    ;; id, `vim.api.nvim_get_hl` is additionally required.
    (vim.api.nvim_set_hl 0 cache.hl-group.added cache.config.added.hl_map)
    (vim.api.nvim_set_hl 0 cache.hl-group.removed cache.config.removed.hl_map)
    (request-to-attach-buf! (vim.api.nvim_get_current_buf))
    (vim.api.nvim_create_autocmd :BufEnter
      {:group id :callback #(request-to-attach-buf! $.buf)})
    (vim.api.nvim_create_autocmd :BufLeave
      {:group id :callback #(request-to-detach-buf! $.buf)})))

{: setup}
