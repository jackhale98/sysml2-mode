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

;; --- Doom Emacs load order (evil loaded BEFORE sysml2-mode) ---
;;
;; Regression test for a real bug: `sysml2-evil' was required inside
;; `sysml2-mode.el' before `sysml2-mode-map' was defvar'd. Its
;; `with-eval-after-load' body runs SYNCHRONOUSLY when `evil' is
;; already a loaded feature (true in Doom Emacs, which loads evil
;; before user packages), so the require chain hit `sysml2-mode-map'
;; while it was still void: "void-variable sysml2-mode-map".
;;
;; That ordering cannot be reproduced within this test process — by
;; the time any test runs, `make test' has already `-l sysml2-mode'd,
;; and `require' is a no-op for an already-loaded feature. This spawns
;; a genuinely fresh Emacs, with a stub `evil' feature pre-loaded
;; before `sysml2-mode' is required, matching Doom's order exactly.

(ert-deftest sysml2-test-loads-cleanly-when-evil-preloaded ()
  "`sysml2-mode' must load with `evil' already present (Doom order)."
  (let* ((repo-dir (file-name-directory (locate-library "sysml2-mode")))
         (stub-dir (make-temp-file "sysml2-evil-stub" t))
         (stub-file (expand-file-name "evil.el" stub-dir)))
    (unwind-protect
        (progn
          (with-temp-file stub-file
            (insert ";; Stub `evil' feature: enough for `with-eval-after-load'\n"
                    ";; to fire synchronously, like a real evil-core would.\n"
                    "(defun evil-define-key* (&rest _args) nil)\n"
                    "(provide 'evil)\n"))
          ;; `--eval' reads and evaluates exactly ONE top-level form, so
          ;; the whole sequence must be one `progn' — left as separate
          ;; top-level forms, only the first (`add-to-list') would run
          ;; and the rest would be silently ignored (exit 0, no output).
          (let* ((script (format "(progn (add-to-list 'load-path %S)\
 (add-to-list 'load-path %S)\
 (require 'evil)\
 (require 'sysml2-mode)\
 (message \"sysml2-mode-loaded-ok\"))"
                                 repo-dir stub-dir))
                 (result
                  (with-temp-buffer
                    (let ((status (call-process
                                   (car command-line-args) nil t nil
                                   "-Q" "--batch" "--eval" script)))
                      (cons status (buffer-string))))))
            (should (= (car result) 0))
            (should (string-match-p "sysml2-mode-loaded-ok" (cdr result)))
            (should-not (string-match-p "void-variable" (cdr result)))))
      (delete-directory stub-dir t))))

(provide 'test-evil)
;;; test-evil.el ends here
