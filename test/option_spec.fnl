(import-macros {: before-each : describe* : it*} :test.helper.busted-macros)

(local emission (require :emission))

(it* "setup without any args does not cause error"
  (fn []
    (emission.setup)))
