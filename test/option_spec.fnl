(import-macros {: before-each : describe* : it*} :test.helper.busted-macros)

(local emission (require :emission))

(it* "setup without any args does not cause error"
  (emission.setup))

(describe* "option"
  (before_each (fn []
                 ;; Reset to default config.
                 (emission.setup)))
  (it* "`{added,removed}.hl_map` overrides hl-Emission{Added,Removed}"
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

(describe* "emission.override()"
  (it* "overrides only given key values."
    (let [base-opts {:attach {:excluded_filetypes [:foobar]}
                     :added {:hl_map {:reverse true}}}
          overriding-opts {:attach {:excluded_filetypes [:foo]}}]
      (emission.setup base-opts)
      (let [new-config (emission.override overriding-opts)]
        (assert.is_same new-config.attach.excluded_filetypes
                        overriding-opts.attach.excluded_filetypes)
        (assert.is_not_same new-config.attach.excluded_filetypes
                            base-opts.attach.excluded_filetypes)
        (assert.is_same new-config.added.hl_map base-opts.added.hl_map)))))
