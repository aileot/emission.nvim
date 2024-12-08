(import-macros {: before-each : describe* : it*} :test.helper.busted-macros)

(local emission (require :emission))
(local emission-config (require :emission.config))

(fn every-keys [tbl]
  (let [keys (icollect [k v (pairs tbl)]
               (values k v))]
    (var i 0)
    (fn []
      (set i (+ i 1))
      (let [key (. keys i)]
        (values key (. tbl key))))))

(it* "setup without any args does not cause error"
  (emission.setup))

(describe* "option must be named in snake_case"
  (λ assert/keys-are-in-snake_case [opts]
    (assert (= :table (type opts)) (.. "expected table, got " (type opts)))
    (each [key val (every-keys opts)]
      (assert.is_truthy (key:find "^[_a-z]+$"))
      (when (and (= :table (type val)) ;
                 (not (vim.islist val)))
        (assert/keys-are-in-snake_case val))))
  (assert.has_error #(assert/keys-are-in-snake_case {:FooBar :baz}))
  (assert.has_error #(assert/keys-are-in-snake_case {:foo-bar :baz}))
  (assert.has_error #(assert/keys-are-in-snake_case {:foo {:bar-baz :qux}}))
  (emission.setup)
  (let [config emission-config._config]
    (assert/keys-are-in-snake_case config)))

(describe* "option {added,removed}.hl_map"
  (it* "overrides hl-Emission{Added,Removed}"
    (emission.setup {:added {:hl_map {}}})
    (assert.is_same {} (vim.api.nvim_get_hl 0 {:name :EmissionAdded}))
    (emission.setup {:added {:hl_map {:reverse true}}})
    (assert.is_same {:reverse true :cterm {:reverse true}}
                    (vim.api.nvim_get_hl 0 {:name :EmissionAdded}))
    (emission.setup {:removed {:hl_map {}}})
    (assert.is_same {} (vim.api.nvim_get_hl 0 {:name :EmissionRemoved}))
    (emission.setup {:removed {:hl_map {:reverse true}}})
    (assert.is_same {:reverse true :cterm {:reverse true}}
                    (vim.api.nvim_get_hl 0 {:name :EmissionRemoved}))))

(describe* "option on_events"
  (it* "throws error if option format is wrong"
    (assert.has_error #(emission.setup {:on_events {:ModeChanged {:callback #:foo}}})))
  (it* "adds autocmds in augroup \"Emission\""
    (emission.setup)
    (let [default-autocmds (vim.api.nvim_get_autocmds {:group :Emission})]
      (emission.setup {:on_events {:ModeChanged [{:callback #:foo}
                                                 {:callback #:bar}]
                                   :CmdlineEnter [{:command :baz}]}})
      (let [new-autocmds (vim.api.nvim_get_autocmds {:group :Emission})]
        (assert.equals (+ 3 (length default-autocmds)) (length new-autocmds))))))
