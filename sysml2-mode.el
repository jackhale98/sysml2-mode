;;; sysml2-mode.el --- Major mode for SysML v2 / KerML -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Major mode for editing SysML v2 (.sysml) and KerML (.kerml) textual
;; notation files per the OMG SysML v2 / KerML specifications.
;;
;; Features:
;; - Syntax highlighting (regex and tree-sitter backends)
;; - Indentation
;; - Context-aware completion (CAPF) with annotated candidates
;; - Smart connection editing (C-c C-c prefix) — select from existing
;;   parts/ports with type annotations, dot-path resolution
;; - Outline side panel with jump-to-definition (C-c C-n t)
;; - Navigation: imenu, which-function, beginning/end-of-defun
;; - PlantUML diagram generation (7 types: tree, IBD, state, action,
;;   requirement, use-case, package)
;; - LSP support (eglot + lsp-mode; pilot, syson servers)
;; - YASnippet snippets (32 templates)
;; - Org-Babel integration
;; - FMI 3.0 / co-simulation integration
;; - Evil mode / Doom Emacs support (SPC m prefix)
;;
;; Tree-sitter support:
;; When Emacs 29.1+ is compiled with tree-sitter and the `sysml'
;; grammar is installed, `sysml2-ts-mode' activates automatically
;; via `major-mode-remap-alist' for enhanced accuracy.
;;
;; Install the grammar:
;;   (add-to-list 'treesit-language-source-alist
;;                '(sysml "https://github.com/jackhale98/tree-sitter-sysml"
;;                        nil "src"))
;;   (treesit-install-language-grammar 'sysml)
;;
;; Quick start:
;;   (require 'sysml2-mode)
;;   ;; .sysml and .kerml files auto-activate the mode
;;
;; Doom Emacs:
;;   Add to packages.el:
;;     (package! sysml2-mode
;;       :recipe (:host github :repo "jackhale98/sysml2-mode"
;;                :files ("*.el" "snippets")))
;;   Add to config.el:
;;     (use-package! sysml2-mode
;;       :init (add-to-list 'auto-mode-alist
;;                          '("\\.sysml\\'" . sysml2-mode))
;;       :config (require 'sysml2-evil) (require 'sysml2-ts))

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
(require 'sysml2-model)
(require 'sysml2-svg)
(require 'sysml2-d2)
(require 'sysml2-plantuml)
(require 'sysml2-diagram)
(require 'sysml2-api)
(require 'sysml2-fmi)
(require 'sysml2-cosim)
(require 'sysml2-evil)
(require 'sysml2-outline)
(require 'sysml2-report)
(require 'sysml2-simulate)
(require 'sysml2-eldoc)

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

;; Forward declarations for functions used in keymap
(declare-function sysml2-goto-definition "sysml2-navigation")
(declare-function sysml2-rename-symbol "sysml2-navigation")
(declare-function hs-minor-mode "hideshow")
(declare-function hs-toggle-hiding "hideshow")
(declare-function hs-hide-block "hideshow")
(declare-function hs-show-block "hideshow")
(declare-function hs-hide-all "hideshow")
(declare-function hs-show-all "hideshow")
(declare-function hs-hide-level "hideshow")
(declare-function sysml2-report-summary "sysml2-report")
(declare-function sysml2-report-traceability "sysml2-report")
(declare-function sysml2-report-export-markdown "sysml2-report")
(declare-function sysml2-report-export "sysml2-report")
(declare-function sysml2-insert-verify "sysml2-completion")
(declare-function sysml2-insert-subject "sysml2-completion")
(declare-function sysml2-diagram-open-in-playground "sysml2-diagram")
(declare-function sysml2-simulate "sysml2-simulate")
(declare-function sysml2-simulate-list "sysml2-simulate")
(declare-function sysml2-simulate-eval "sysml2-simulate")
(declare-function sysml2-simulate-state-machine "sysml2-simulate")
(declare-function sysml2-simulate-action-flow "sysml2-simulate")
(declare-function sysml2-scaffold "sysml2-completion")
(declare-function sysml2-scaffold-model "sysml2-completion")
(declare-function sysml2-scaffold-package "sysml2-completion")
(declare-function sysml2-scaffold-part-def "sysml2-completion")
(declare-function sysml2-scaffold-port-def "sysml2-completion")
(declare-function sysml2-scaffold-requirement-def "sysml2-completion")
(declare-function sysml2-scaffold-state-def "sysml2-completion")
(declare-function sysml2-scaffold-action-def "sysml2-completion")
(declare-function sysml2-scaffold-enum-def "sysml2-completion")
(declare-function sysml2-scaffold-use-case-def "sysml2-completion")
(declare-function sysml2-scaffold-calc-def "sysml2-completion")
(defvar hs-special-modes-alist)

;; --- Keymap ---

(defvar sysml2-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Navigation
    (define-key map (kbd "C-c C-n o") #'imenu)
    (define-key map (kbd "C-c C-n t") #'sysml2-outline-toggle)
    (define-key map (kbd "M-.") #'sysml2-goto-definition)
    (define-key map (kbd "C-c C-r") #'sysml2-rename-symbol)
    ;; LSP
    (define-key map (kbd "C-c C-l s") #'sysml2-lsp-ensure)
    (define-key map (kbd "C-c C-l r") #'sysml2-lsp-restart)
    ;; Diagram — direct type commands
    (define-key map (kbd "C-c C-d t") #'sysml2-diagram-tree)
    (define-key map (kbd "C-c C-d i") #'sysml2-diagram-ibd)
    (define-key map (kbd "C-c C-d s") #'sysml2-diagram-state-machine)
    (define-key map (kbd "C-c C-d a") #'sysml2-diagram-action-flow)
    (define-key map (kbd "C-c C-d r") #'sysml2-diagram-requirement)
    (define-key map (kbd "C-c C-d u") #'sysml2-diagram-use-case)
    (define-key map (kbd "C-c C-d k") #'sysml2-diagram-package)
    ;; Diagram — view-filtered
    (define-key map (kbd "C-c C-d v") #'sysml2-diagram-view)
    ;; Diagram — general
    (define-key map (kbd "C-c C-d p") #'sysml2-diagram-preview)
    (define-key map (kbd "C-c C-d b") #'sysml2-diagram-preview-buffer)
    (define-key map (kbd "C-c C-d e") #'sysml2-diagram-export)
    (define-key map (kbd "C-c C-d o") #'sysml2-diagram-open-plantuml)
    (define-key map (kbd "C-c C-d w") #'sysml2-diagram-open-in-playground)
    ;; Smart Connection / Relationship Insertion
    (define-key map (kbd "C-c C-c c") #'sysml2-connect)
    (define-key map (kbd "C-c C-c f") #'sysml2-insert-flow)
    (define-key map (kbd "C-c C-c b") #'sysml2-insert-binding)
    (define-key map (kbd "C-c C-c i") #'sysml2-insert-interface)
    (define-key map (kbd "C-c C-c a") #'sysml2-insert-allocation)
    (define-key map (kbd "C-c C-c s") #'sysml2-insert-satisfy)
    (define-key map (kbd "C-c C-c v") #'sysml2-insert-verify)
    (define-key map (kbd "C-c C-c u") #'sysml2-insert-subject)
    ;; Model Scaffolding (C-c m prefix — lowercase m)
    (define-key map (kbd "C-c m m") #'sysml2-scaffold)
    (define-key map (kbd "C-c m M") #'sysml2-scaffold-model)
    (define-key map (kbd "C-c m p") #'sysml2-scaffold-package)
    (define-key map (kbd "C-c m d") #'sysml2-scaffold-part-def)
    (define-key map (kbd "C-c m o") #'sysml2-scaffold-port-def)
    (define-key map (kbd "C-c m r") #'sysml2-scaffold-requirement-def)
    (define-key map (kbd "C-c m s") #'sysml2-scaffold-state-def)
    (define-key map (kbd "C-c m a") #'sysml2-scaffold-action-def)
    (define-key map (kbd "C-c m e") #'sysml2-scaffold-enum-def)
    (define-key map (kbd "C-c m u") #'sysml2-scaffold-use-case-def)
    (define-key map (kbd "C-c m c") #'sysml2-scaffold-calc-def)
    ;; API
    (define-key map (kbd "C-c C-a l") #'sysml2-api-list-projects)
    (define-key map (kbd "C-c C-a q") #'sysml2-api-query)
    ;; Simulation / FMI
    (define-key map (kbd "C-c C-s i") #'sysml2-fmi-inspect-fmu)
    (define-key map (kbd "C-c C-s e") #'sysml2-fmi-extract-interfaces)
    (define-key map (kbd "C-c C-s m") #'sysml2-fmi-generate-modelica)
    (define-key map (kbd "C-c C-s v") #'sysml2-fmi-validate-interfaces)
    (define-key map (kbd "C-c C-s g") #'sysml2-cosim-generate-ssp)
    (define-key map (kbd "C-c C-s r") #'sysml2-cosim-run)
    (define-key map (kbd "C-c C-s p") #'sysml2-cosim-results)
    (define-key map (kbd "C-c C-s c") #'sysml2-cosim-verify-requirements)
    ;; Simulation (sysml-lint simulate)
    (define-key map (kbd "C-c C-x s") #'sysml2-simulate)
    (define-key map (kbd "C-c C-x l") #'sysml2-simulate-list)
    (define-key map (kbd "C-c C-x e") #'sysml2-simulate-eval)
    (define-key map (kbd "C-c C-x m") #'sysml2-simulate-state-machine)
    (define-key map (kbd "C-c C-x a") #'sysml2-simulate-action-flow)
    ;; Inspect / Report
    (define-key map (kbd "C-c C-i s") #'sysml2-report-summary)
    (define-key map (kbd "C-c C-i t") #'sysml2-report-traceability)
    (define-key map (kbd "C-c C-i a") #'sysml2-impact-analysis)
    (define-key map (kbd "C-c C-i m") #'sysml2-report-export-markdown)
    (define-key map (kbd "C-c C-i e") #'sysml2-report-export)
    ;; Code folding
    (define-key map (kbd "C-c C-f t") #'hs-toggle-hiding)
    (define-key map (kbd "C-c C-f h") #'hs-hide-block)
    (define-key map (kbd "C-c C-f s") #'hs-show-block)
    (define-key map (kbd "C-c C-f H") #'hs-hide-all)
    (define-key map (kbd "C-c C-f S") #'hs-show-all)
    (define-key map (kbd "C-c C-f l") #'hs-hide-level)
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

  ;; Code folding (hideshow)
  (add-to-list 'hs-special-modes-alist
               '(sysml2-mode "{" "}" "/[*/]" nil nil))
  (hs-minor-mode 1)

  ;; ElDoc
  (sysml2-eldoc-setup)

  ;; Flymake (skip in batch/noninteractive to avoid timer hangs)
  (unless noninteractive
    (sysml2-flymake-setup))

  ;; LSP (may start server if available)
  (unless noninteractive
    (sysml2-lsp-setup)))

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
