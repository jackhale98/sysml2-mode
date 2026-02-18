;;; sysml2-font-lock.el --- Font-lock support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Font-lock keywords computed from `sysml2-lang.el' data tables.
;; Supports three font-lock decoration levels.
;; Multi-word keywords are matched before single-word keywords to
;; prevent partial matching (e.g., `part def' before `part').

;;; Code:

;;; Public API:
;;
;; Variables:
;;   `sysml2-font-lock-keywords-1' -- Level 1: keywords only
;;   `sysml2-font-lock-keywords-2' -- Level 2: keywords + names + types
;;   `sysml2-font-lock-keywords-3' -- Level 3: everything
;;   `sysml2-font-lock-keywords' -- Default (level 3)
;;
;; Functions:
;;   `sysml2-font-lock-setup' -- Configure font-lock in a buffer

(require 'sysml2-lang)

;; --- Internal Regexps ---

(defconst sysml2--font-lock-def-kw-re
  (regexp-opt sysml2-definition-keywords t)
  "Regexp matching definition keywords for font-lock.")

(defconst sysml2--font-lock-usage-kw-re
  (regexp-opt sysml2-usage-keywords 'words)
  "Regexp matching usage keywords for font-lock.")

(defconst sysml2--font-lock-struct-kw-re
  (regexp-opt sysml2-structural-keywords 'words)
  "Regexp matching structural keywords for font-lock.")

(defconst sysml2--font-lock-behav-kw-re
  (regexp-opt sysml2-behavioral-keywords 'words)
  "Regexp matching behavioral keywords for font-lock.")

(defconst sysml2--font-lock-rel-kw-re
  (regexp-opt sysml2-relationship-keywords 'words)
  "Regexp matching relationship keywords for font-lock.")

;; --- Font-Lock Level 1: Keywords only ---

(defconst sysml2-font-lock-keywords-1
  `(;; Multi-word keywords FIRST (prevents partial matches)
    (,(regexp-opt sysml2-multi-word-keywords 'words)
     . 'sysml2-keyword-face)
    ;; Single-word usage keywords
    (,sysml2--font-lock-usage-kw-re . 'sysml2-keyword-face)
    ;; Structural keywords
    (,sysml2--font-lock-struct-kw-re . 'sysml2-builtin-face)
    ;; Behavioral keywords
    (,sysml2--font-lock-behav-kw-re . 'sysml2-keyword-face)
    ;; Relationship keywords
    (,sysml2--font-lock-rel-kw-re . 'sysml2-keyword-face))
  "Level 1 font-lock keywords: keywords only.")

;; --- Font-Lock Level 2: Keywords + Names + Types ---

(defconst sysml2-font-lock-keywords-2
  (append
   sysml2-font-lock-keywords-1
   `(;; Definition name capture: "part def Vehicle" -> "Vehicle"
     (,(concat "\\(?:" (regexp-opt sysml2-definition-keywords t)
               "\\)\\s-+\\(" sysml2--identifier-regexp "\\)")
      (2 'sysml2-definition-name-face))
     ;; Usage name capture: "part engine" -> "engine" (before : or ; or {)
     (,(concat "\\(?:" (regexp-opt sysml2-usage-keywords 'words)
               "\\)\\s-+\\(" sysml2--identifier-regexp "\\)")
      (1 'sysml2-usage-name-face))
     ;; Package name: "package Foo" -> "Foo"
     (,(concat "\\bpackage\\s-+\\(" sysml2--identifier-regexp "\\)")
      (1 'sysml2-definition-name-face))
     ;; Type reference after ":"  (but not :: or :> or :>>)
     (":\\(?:[^:>]\\)\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)"
      (1 'sysml2-type-reference-face))
     ;; Specialization after ":>"
     (":>\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)"
      (1 'sysml2-specialization-face))
     ;; Redefinition after ":>>"
     (":>>\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)"
      (1 'sysml2-type-reference-face))))
  "Level 2 font-lock keywords: keywords + names + types.")

;; --- Font-Lock Level 3: Everything ---

(defconst sysml2-font-lock-keywords-3
  (append
   sysml2-font-lock-keywords-2
   `(;; Visibility keywords
     (,sysml2-visibility-keywords-regexp . 'sysml2-visibility-face)
     ;; Modifier keywords
     (,sysml2-modifier-keywords-regexp . 'sysml2-modifier-face)
     ;; Literal keywords (true, false, null)
     (,sysml2-literal-keywords-regexp . 'sysml2-literal-face)
     ;; Operator keywords (not, or, and, xor, implies, etc.)
     (,sysml2-operator-keywords-regexp . 'sysml2-operator-face)
     ;; Short name identifiers: <R1>, <'name'>
     ("<\\([^>\n]+\\)>" (1 'sysml2-short-name-face))
     ;; Metadata/annotation: #MetadataName
     ("#\\([A-Za-z_][A-Za-z0-9_:]*\\)" (1 'sysml2-metadata-face))
     ;; Numeric literals
     ("\\b[0-9]+\\.?[0-9]*\\(?:[eE][+-]?[0-9]+\\)?\\b"
      . 'sysml2-literal-face)
     ;; Qualified name prefix: Package:: -> package face
     ("\\b\\([A-Za-z_][A-Za-z0-9_]*\\)::" (1 'sysml2-package-face))))
  "Level 3 font-lock keywords: everything including operators and literals.")

;; --- Default Keywords ---

(defvar sysml2-font-lock-keywords sysml2-font-lock-keywords-3
  "Default font-lock keywords for `sysml2-mode' (level 3).")

;; --- Setup Function ---

(defun sysml2-font-lock-setup ()
  "Set up font-lock for the current SysML v2 buffer.
Configures `font-lock-defaults' with multi-level support."
  (setq-local font-lock-defaults
              '((sysml2-font-lock-keywords-1
                 sysml2-font-lock-keywords-2
                 sysml2-font-lock-keywords-3)
                nil nil nil nil))
  (setq-local font-lock-multiline t))

(provide 'sysml2-font-lock)
;;; sysml2-font-lock.el ends here
