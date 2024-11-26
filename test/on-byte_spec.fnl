(import-macros {: before-each : after-each : describe* : it*}
               :test.helper.busted-macros)

(local emission (require :emission))

(fn feedkeys! [keys ?flags ?escape]
  "A wrapper of `nvim_feedkeys. Any mappings are ignored by default."
  (vim.api.nvim_feedkeys (vim.api.nvim_replace_termcodes keys true true true)
                         (or ?flags :ni) ;
                         (if (= ?escape false) false true)))

(fn each-scenario [cb]
  "Apply `cb` to combinations of buffer rows and cursor positions.
  @param cb function"
  (let [context-lines {:zero-line []
                       :one-line [:foo]
                       :two-lines [:foo :bar]
                       :three-lines [:foo :bar :baz]
                       :many-lines [:foo :bar :baz :qux]}
        vertical-ranges [:1 :2 :3 "$"]
        horizontal-motions [:0 :M "$"]]
    (each [_ lines (pairs context-lines)]
      (each [_ ver (ipairs vertical-ranges)]
        (each [_ hor (ipairs horizontal-motions)]
          (vim.cmd "% delete _")
          (vim.api.nvim_buf_set_lines 0 0 -1 true lines)
          (vim.cmd ver)
          (feedkeys! hor)
          (cb))))))

(describe* "the helper `each-scenario`"
  (before-each (fn []
                 (vim.cmd.new)))
  (after-each (fn []
                (vim.cmd :q!)))
  (it* "could throws error"
    (each-scenario #(assert.has_error #(error :bar)))
    (each-scenario #(assert.has_error #(vim.fn.error :foo)))
    (each-scenario #(assert.has_error #(vim.cmd "throw 'foo'")))))

(describe* "on-byte does not cause error"
  (before-each (fn []
                 (vim.cmd.new)
                 (emission.setup)))
  (after-each (fn []
                (vim.cmd :q!)))
  (it* "on inserting texts"
    (each-scenario #(assert.has_no_error #(feedkeys! :o)))
    (each-scenario #(assert.has_no_error #(feedkeys! :u)))
    (each-scenario #(assert.has_no_error #(feedkeys! :O)))
    (each-scenario #(assert.has_no_error #(feedkeys! :yyp)))
    (each-scenario #(assert.has_no_error #(feedkeys! :yyP)))
    (each-scenario #(assert.has_no_error #(feedkeys! :s)))
    (each-scenario #(assert.has_no_error #(feedkeys! :>G)))
    (each-scenario #(assert.has_no_error #(feedkeys! "<<")))
    (each-scenario #(assert.has_no_error #(vim.cmd "1 delete _")))
    (each-scenario #(assert.has_no_error #(vim.cmd "$ delete _")))
    (each-scenario #(assert.has_no_error #(vim.cmd "% delete _")))))
