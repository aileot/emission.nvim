(import-macros {: it*} :test.helper.busted-macros)

(it* "`error` causes error"
  (assert.has_error #(error "expected error")))
