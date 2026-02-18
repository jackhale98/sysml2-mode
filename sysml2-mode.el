;;; sysml2-mode.el --- Major mode for SysML v2 / KerML -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Major mode for editing SysML v2 (.sysml) and KerML (.kerml) textual
;; notation files.  Provides syntax highlighting, indentation, completion,
;; navigation, and snippet support.
;;
;; Entry point for the sysml2-mode package.  Requires all internal modules
;; and defines the mode, syntax table, and keymap.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-mode' -- Major mode for SysML v2 files
;;   `kerml-mode' -- Major mode for KerML files
;;   `sysml2-version' -- Return the sysml2-mode version string

;; --- Internal Module Requires ---

(require 'sysml2-vars)
(require 'sysml2-lang)
(require 'sysml2-font-lock)
(require 'sysml2-indent)
(require 'sysml2-completion)
(require 'sysml2-navigation)
(require 'sysml2-snippets)
(require 'sysml2-project)
(require 'sysml2-lsp)
(require 'sysml2-flymake)
(require 'sysml2-plantuml)
(require 'sysml2-diagram)
(require 'sysml2-api)
(require 'sysml2-evil)

;; --- Version ---

(defconst sysml2-mode-version "0.1.0"
  "Version of sysml2-mode.")

(defun sysml2-version ()
  "Return the sysml2-mode version string."
  (interactive)
  (message "sysml2-mode %s" sysml2-mode-version)
  sysml2-mode-version)

;; --- Syntax Table ---

(defvar sysml2-mode-syntax-table
  (let ((table (make-syntax-table)))
    ;; C-style comments: // and /* ... */
    (modify-syntax-entry ?/ ". 124" table)
    (modify-syntax-entry ?* ". 23b" table)
    (modify-syntax-entry ?\n ">" table)
    ;; Strings
    (modify-syntax-entry ?\" "\"" table)
    (modify-syntax-entry ?\' "\"" table)
    ;; Paired delimiters
    (modify-syntax-entry ?\( "()" table)
    (modify-syntax-entry ?\) ")(" table)
    (modify-syntax-entry ?\[ "(]" table)
    (modify-syntax-entry ?\] ")[" table)
    (modify-syntax-entry ?\{ "(}" table)
    (modify-syntax-entry ?\} "){" table)
    ;; Punctuation
    (modify-syntax-entry ?: "." table)
    (modify-syntax-entry ?\; "." table)
    (modify-syntax-entry ?, "." table)
    (modify-syntax-entry ?= "." table)
    (modify-syntax-entry ?< "." table)
    (modify-syntax-entry ?> "." table)
    (modify-syntax-entry ?+ "." table)
    (modify-syntax-entry ?- "." table)
    (modify-syntax-entry ?# "." table)
    (modify-syntax-entry ?@ "." table)
    (modify-syntax-entry ?~ "." table)
    ;; Identifiers: underscore is word constituent
    (modify-syntax-entry ?_ "w" table)
    table)
  "Syntax table for `sysml2-mode'.")

;; --- Keymap ---

(defvar sysml2-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation
    (define-key map (kbd "C-c C-n o") #'imenu)
    ;; LSP
    (define-key map (kbd "C-c C-l s") #'sysml2-lsp-ensure)
    (define-key map (kbd "C-c C-l r") #'sysml2-lsp-restart)
    ;; Diagram
    (define-key map (kbd "C-c C-d p") #'sysml2-diagram-preview)
    (define-key map (kbd "C-c C-d b") #'sysml2-diagram-preview-buffer)
    (define-key map (kbd "C-c C-d e") #'sysml2-diagram-export)
    (define-key map (kbd "C-c C-d t") #'sysml2-diagram-type)
    (define-key map (kbd "C-c C-d o") #'sysml2-diagram-open-plantuml)
    (define-key map (kbd "C-c C-d r") #'sysml2-diagram-render-examples)
    (define-key map (kbd "C-c C-d g") #'sysml2-diagram-generate-examples)
    ;; API
    (define-key map (kbd "C-c C-a l") #'sysml2-api-list-projects)
    (define-key map (kbd "C-c C-a q") #'sysml2-api-query)
    map)
  "Keymap for `sysml2-mode'.")

;; --- Tree-sitter mode (loaded after syntax table and keymap) ---

(require 'sysml2-ts)

;; --- Outline Regexp ---

(defconst sysml2--outline-regexp
  (concat "\\s-*\\(?:package\\|"
          (regexp-opt (seq-filter
                       (lambda (kw) (string-suffix-p "def" kw))
                       sysml2-definition-keywords))
          "\\)")
  "Regexp matching lines that are outline headings in SysML v2.")

;; --- Mode Definition ---

;;;###autoload
(define-derived-mode sysml2-mode prog-mode "SysML2"
  "Major mode for editing SysML v2 textual notation files.

\\{sysml2-mode-map}"
  :syntax-table sysml2-mode-syntax-table
  :group 'sysml2

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s-*")

  ;; Font lock
  (sysml2-font-lock-setup)

  ;; Indentation
  (setq-local indent-line-function #'sysml2-indent-line)
  (setq-local indent-tabs-mode nil)

  ;; Electric
  (setq-local electric-indent-chars
              (append '(?{ ?} ?\; ?\n) electric-indent-chars))

  ;; Navigation / imenu
  (setq-local imenu-create-index-function #'sysml2-imenu-create-index)

  ;; Completion
  (add-hook 'completion-at-point-functions
            #'sysml2-completion-at-point nil t)

  ;; Paragraph
  (setq-local paragraph-start (concat "$\\|" page-delimiter))
  (setq-local paragraph-separate paragraph-start)

  ;; Outline
  (setq-local outline-regexp sysml2--outline-regexp)
  (setq-local outline-level #'sysml2-outline-level)

  ;; Which-function
  (add-hook 'which-func-functions #'sysml2-which-function nil t)

  ;; Beginning/end of defun
  (setq-local beginning-of-defun-function #'sysml2-beginning-of-defun)
  (setq-local end-of-defun-function #'sysml2-end-of-defun)

  ;; Electric pairs
  (setq-local electric-pair-pairs
              (append '((?{ . ?}) (?\( . ?\)) (?\[ . ?\]))
                      (when (boundp 'electric-pair-pairs)
                        electric-pair-pairs)))

  ;; Flymake
  (sysml2-flymake-setup)

  ;; LSP (may start server if available)
  (sysml2-lsp-setup))

;; --- KerML Mode ---

;;;###autoload
(define-derived-mode kerml-mode sysml2-mode "KerML"
  "Major mode for editing KerML textual notation files.
Derived from `sysml2-mode' with the same features.

\\{sysml2-mode-map}"
  :group 'sysml2)

;; --- Auto-mode-alist ---

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sysml\\'" . sysml2-mode))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.kerml\\'" . kerml-mode))

(provide 'sysml2-mode)
;;; sysml2-mode.el ends here
