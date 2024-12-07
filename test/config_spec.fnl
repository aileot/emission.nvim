(import-macros {: describe* : it*} :test.helper.busted-macros)

(local emission-config (require :emission.config))

(describe* "config.merge()"
  (it* "shares the same pointer between given options and merged config"
    (let [filter #true
          new-config (emission-config.merge {:added {:filter filter}})]
      (assert.equals filter new-config.added.filter))))
