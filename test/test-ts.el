;;; test-ts.el --- Tree-sitter mode tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-ts.el.  All tests are guarded by
;; `treesit-ready-p' and will skip when the grammar is not installed.

;;; Code:

(require 'ert)
(require 'test-helper)

;; --- Guard: skip all if tree-sitter grammar not available ---

(defun sysml2-test--ts-available-p ()
  "Return non-nil if tree-sitter SysML grammar is available."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (treesit-ready-p 'sysml t)))

;; --- Mode activation ---

(ert-deftest sysml2-test-ts-mode-activates ()
  "Test that `sysml2-ts-mode' activates when grammar is available."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (sysml2-ts-mode)
    (should (eq major-mode 'sysml2-ts-mode))))

;; --- Font-lock ---

(ert-deftest sysml2-test-ts-font-lock-keyword ()
  "Test that tree-sitter font-lock highlights `part' as a keyword."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "part def Vehicle {}")
    (sysml2-ts-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (let ((face (get-text-property (point) 'face)))
      (should face))))

(ert-deftest sysml2-test-ts-font-lock-def-name ()
  "Test that tree-sitter highlights definition names."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "part def Vehicle {}")
    (sysml2-ts-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (search-forward "Vehicle")
    (let ((face (get-text-property (match-beginning 0) 'face)))
      (should (eq face 'sysml2-definition-name-face)))))

;; --- Imenu ---

(ert-deftest sysml2-test-ts-imenu ()
  "Test that tree-sitter imenu returns categories."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "part def A {}\npart def B {}")
    (sysml2-ts-mode)
    (let ((index (funcall imenu-create-index-function)))
      (should index))))

;; --- Navigation ---

(ert-deftest sysml2-test-ts-defun-navigation ()
  "Test tree-sitter defun navigation."
  (skip-unless (sysml2-test--ts-available-p))
  (require 'sysml2-ts)
  (with-temp-buffer
    (insert "part def A {}\npart def B {}")
    (sysml2-ts-mode)
    (goto-char (point-max))
    (beginning-of-defun)
    (should (looking-at-p "part def B"))))

(provide 'test-ts)
;;; test-ts.el ends here
