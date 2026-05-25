;;; test-autoload.el --- Autoload-cookie coverage tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Verifies that user-facing interactive commands carry `;;;###autoload'
;; cookies so they are usable before the owning module is loaded.

;;; Code:

(require 'ert)
(require 'test-helper)

(defvar sysml2-test--repo-root
  (file-name-as-directory
   (file-name-directory
    (directory-file-name
     (file-name-directory
      (directory-file-name sysml2-test-fixtures-dir)))))
  "Path to the sysml2-mode project root.")

(defun sysml2-test--has-autoload-p (defun-name file)
  "Return non-nil if FILE defines DEFUN-NAME with a `;;;###autoload' cookie."
  (let ((path (expand-file-name file sysml2-test--repo-root)))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (when (re-search-forward
             (format "^;;;###autoload\\s-*\n(defun %s\\b"
                     (regexp-quote defun-name))
             nil t)
        t))))

(ert-deftest sysml2-autoload-diagram-commands ()
  "Top-level diagram commands must be autoloaded."
  (dolist (cmd '("sysml2-diagram-tree" "sysml2-diagram-ibd"
                 "sysml2-diagram-state-machine" "sysml2-diagram-action-flow"
                 "sysml2-diagram-requirement" "sysml2-diagram-use-case"
                 "sysml2-diagram-package" "sysml2-diagram-view"
                 "sysml2-diagram-preview" "sysml2-diagram-export"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-diagram.el"))))

(ert-deftest sysml2-autoload-scaffold-commands ()
  "Scaffold commands must be autoloaded."
  (dolist (cmd '("sysml2-scaffold" "sysml2-scaffold-model"
                 "sysml2-scaffold-package" "sysml2-scaffold-part-def"
                 "sysml2-scaffold-port-def" "sysml2-scaffold-requirement-def"
                 "sysml2-scaffold-state-def" "sysml2-scaffold-action-def"
                 "sysml2-scaffold-enum-def" "sysml2-scaffold-use-case-def"
                 "sysml2-scaffold-calc-def"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-completion.el"))))

(ert-deftest sysml2-autoload-connect-commands ()
  "Connection-insertion commands must be autoloaded."
  (dolist (cmd '("sysml2-connect" "sysml2-insert-flow" "sysml2-insert-binding"
                 "sysml2-insert-interface" "sysml2-insert-allocation"
                 "sysml2-insert-satisfy" "sysml2-insert-verify"
                 "sysml2-insert-subject"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-completion.el"))))

(ert-deftest sysml2-autoload-navigation-commands ()
  "Navigation commands must be autoloaded."
  (dolist (cmd '("sysml2-goto-definition" "sysml2-rename-symbol"
                 "sysml2-find-references"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-navigation.el"))))

(ert-deftest sysml2-autoload-lsp-commands ()
  "LSP user commands must be autoloaded."
  (dolist (cmd '("sysml2-lsp-ensure" "sysml2-lsp-restart"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-lsp.el"))))

(ert-deftest sysml2-autoload-outline-commands ()
  "Outline toggle and refresh must be autoloaded."
  (dolist (cmd '("sysml2-outline-toggle" "sysml2-outline-refresh"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-outline.el"))))

(ert-deftest sysml2-autoload-api-commands ()
  "API user commands must be autoloaded."
  (dolist (cmd '("sysml2-api-list-projects" "sysml2-api-query"))
    (should (sysml2-test--has-autoload-p cmd "sysml2-api.el"))))

(ert-deftest sysml2-autoload-doctor-command ()
  "Doctor must be autoloaded."
  (should (sysml2-test--has-autoload-p "sysml2-doctor" "sysml2-doctor.el")))

(provide 'test-autoload)
;;; test-autoload.el ends here
