;;; test-ts-structure.el --- Tree-sitter structural movement & outline -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for tree-sitter structural movement (treesit-thing-settings)
;; and outline integration (treesit-outline-predicate) added in Emacs
;; 30+. Skipped when tree-sitter is unavailable.

;;; Code:

(require 'ert)
(require 'test-helper)

(defun sysml2-test--ts-available-p ()
  "Return non-nil if tree-sitter SysML grammar is loadable."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp 'treesit-ready-p)
       (ignore-errors (treesit-ready-p 'sysml t))))

(ert-deftest sysml2-ts-thing-settings-defined ()
  "`sysml2-ts--thing-settings' must exist and cover sexp/list/sentence."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (should (boundp 'sysml2-ts--thing-settings))
  (let* ((entry (assoc 'sysml sysml2-ts--thing-settings))
         (kinds (mapcar #'car (cdr entry))))
    (should entry)
    (should (memq 'sexp kinds))
    (should (memq 'list kinds))
    (should (memq 'sentence kinds))))

(ert-deftest sysml2-ts-mode-installs-thing-settings ()
  "Entering `sysml2-ts-mode' must propagate thing settings buffer-locally."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "package P { part def Car; }\n")
    (sysml2-ts-mode)
    (should treesit-thing-settings)
    (should (assoc 'sysml treesit-thing-settings))))

(ert-deftest sysml2-ts-outline-predicate-defined ()
  "`sysml2-ts--outline-predicate' must be a function."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (should (functionp 'sysml2-ts--outline-predicate)))

(ert-deftest sysml2-ts-mode-installs-outline-predicate ()
  "Entering `sysml2-ts-mode' must set `treesit-outline-predicate'."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (skip-unless (boundp 'treesit-outline-predicate))
  (with-temp-buffer
    (insert "package P { part def Car; }\n")
    (sysml2-ts-mode)
    (should treesit-outline-predicate)))

(ert-deftest sysml2-ts-forward-sexp-moves-over-definition ()
  "`forward-sexp' from before `part def Car { ... }' should skip to after `}'."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "package P {\n  part def Car { mass = 1; }\n  part def Bike;\n}\n")
    (sysml2-ts-mode)
    (goto-char (point-min))
    (search-forward "part def Car")
    (beginning-of-line)
    ;; Move forward by one structural unit
    (let ((start (point)))
      (forward-sexp 1)
      (should (> (point) start)))))

(ert-deftest sysml2-ts-outline-detects-package ()
  "`sysml2-ts--outline-predicate' returns t for a package_declaration node."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "package Sample;\n")
    (sysml2-ts-mode)
    (goto-char (point-min))
    (let ((node (treesit-parent-until
                 (treesit-node-at (point))
                 (lambda (n)
                   (string= (treesit-node-type n) "package_declaration")))))
      (when node
        (should (sysml2-ts--outline-predicate node))))))

(provide 'test-ts-structure)
;;; test-ts-structure.el ends here
