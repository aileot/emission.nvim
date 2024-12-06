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
