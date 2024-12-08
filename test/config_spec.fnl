(import-macros {: before-each : describe* : it*} :test.helper.busted-macros)

(local emission (require :emission))

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

(describe* "emission.reset()"
  (it* "resets config to the last config determined by emission.setup()"
    ;; NOTE: What value .setup() should return is undetermined yet.
    (emission.setup {:attach {:excluded_filetypes [:foo]}})
    (let [another-config (emission.override {:attach {:excluded_filetypes [:bar]}})
          new-config (emission.reset)]
      (assert.is_not_same another-config new-config)
      (assert.is_same [:foo] new-config.attach.excluded_filetypes))))
