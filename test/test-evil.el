;;; test-evil.el --- Evil-mode integration tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-evil.el.  Verifies that evil-mode bindings are
;; registered correctly and that the module loads safely without evil
;; or general.el present.

;;; Code:

(require 'ert)
(require 'sysml2-mode)

;; --- Loading without evil ---

(ert-deftest sysml2-test-evil-not-required ()
  "Verify sysml2-evil loads without evil present.
The `with-eval-after-load' should not error when evil is absent."
  ;; sysml2-mode already loaded above; if we got here, it worked.
  (should (featurep 'sysml2-evil))
  (should (featurep 'sysml2-mode)))

(ert-deftest sysml2-test-evil-general-not-required ()
  "Verify sysml2-evil loads without general.el present.
The nested `with-eval-after-load' for general should be inert."
  ;; general should not be loaded by our code
  (should-not (featurep 'general))
  ;; sysml2-evil should still be loaded
  (should (featurep 'sysml2-evil)))

(ert-deftest sysml2-test-evil-bindings-loaded ()
  "Verify that after loading evil + sysml2-evil, keys are bound.
This test simulates evil being loaded by running the deferred forms."
  (skip-unless (locate-library "evil"))
  (require 'evil)
  ;; Re-evaluate sysml2-evil to trigger the with-eval-after-load body
  (load "sysml2-evil")
  ;; Check that localleader bindings exist in the normal-state map
  (let ((bound (lookup-key sysml2-mode-map
                           (vconcat [?, ?d ?p]))))
    (should (eq bound 'sysml2-diagram-preview))))

(provide 'test-evil)
;;; test-evil.el ends here
