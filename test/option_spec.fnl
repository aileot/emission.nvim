(import-macros {: before-each : describe* : it*} :test.helper.busted-macros)

(local emission (require :emission))

(it* "setup without any args does not cause error"
  (emission.setup))

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
