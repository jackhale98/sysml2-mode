;;; sysml2-ts.el --- Tree-sitter support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tree-sitter powered major mode for SysML v2 / KerML.
;; Provides enhanced font-lock, indentation, and navigation using
;; the tree-sitter incremental parser.
;;
;; Requires:
;;   - Emacs 29.1+ with tree-sitter support compiled in
;;   - The `sysml' tree-sitter grammar installed
;;
;; When tree-sitter is available and the grammar is installed,
;; `sysml2-ts-mode' automatically remaps `sysml2-mode'.

;;; Code:

(require 'sysml2-vars)
(require 'sysml2-lang)

;; Forward-declare variables defined in sysml2-mode.el
(defvar sysml2-mode-syntax-table)
(defvar sysml2-mode-map)

;; Only define the tree-sitter mode when tree-sitter is available
(when (and (fboundp 'treesit-available-p)
           (treesit-available-p))

  (require 'treesit)

  ;; --- Font-lock settings ---

  (defvar sysml2-ts--font-lock-settings
    (treesit-font-lock-rules
     :language 'sysml
     :feature 'comment
     '((line_comment) @font-lock-comment-face
       (block_comment) @font-lock-comment-face
       (doc_comment) @font-lock-doc-face)

     :language 'sysml
     :feature 'string
     '((string_literal) @font-lock-string-face)

     :language 'sysml
     :feature 'keyword
     '(["package" "import" "alias" "comment" "doc" "about" "rep"
        "language" "library" "filter" "standard"
        "entry" "exit" "do" "first" "then" "accept" "send" "assign"
        "if" "else" "while" "for" "loop" "merge" "decide" "join" "fork"
        "transition" "trigger" "guard" "effect"
        "specialization" "subset" "redefines" "references" "chains"
        "conjugates" "inverse" "featured" "typing" "satisfy"
        "assert" "assume" "require" "subject" "objective"
        "stakeholder" "actor" "bind" "connect" "to" "from"
        "end" "all" "default"
        "public" "private" "protected"
        "abstract" "variation" "variant" "individual" "readonly"
        "derived" "nonunique" "ordered" "in" "out" "inout" "return"
        "def"] @font-lock-keyword-face)

     :language 'sysml
     :feature 'definition
     :override t
     '((part_definition name: (identifier) @sysml2-definition-name-face)
       (action_definition name: (identifier) @sysml2-definition-name-face)
       (state_definition name: (identifier) @sysml2-definition-name-face)
       (port_definition name: (identifier) @sysml2-definition-name-face)
       (connection_definition name: (identifier) @sysml2-definition-name-face)
       (attribute_definition name: (identifier) @sysml2-definition-name-face)
       (item_definition name: (identifier) @sysml2-definition-name-face)
       (requirement_definition name: (identifier) @sysml2-definition-name-face)
       (constraint_definition name: (identifier) @sysml2-definition-name-face)
       (view_definition name: (identifier) @sysml2-definition-name-face)
       (viewpoint_definition name: (identifier) @sysml2-definition-name-face)
       (rendering_definition name: (identifier) @sysml2-definition-name-face)
       (concern_definition name: (identifier) @sysml2-definition-name-face)
       (use_case_definition name: (identifier) @sysml2-definition-name-face)
       (analysis_case_definition name: (identifier) @sysml2-definition-name-face)
       (verification_case_definition name: (identifier) @sysml2-definition-name-face)
       (allocation_definition name: (identifier) @sysml2-definition-name-face)
       (interface_definition name: (identifier) @sysml2-definition-name-face)
       (enumeration_definition name: (identifier) @sysml2-definition-name-face)
       (occurrence_definition name: (identifier) @sysml2-definition-name-face)
       (metadata_definition name: (identifier) @sysml2-definition-name-face)
       (calc_definition name: (identifier) @sysml2-definition-name-face)
       (package_declaration name: (identifier) @sysml2-definition-name-face))

     :language 'sysml
     :feature 'type
     '((typed_by type: (qualified_name) @font-lock-type-face)
       (specialization target: (qualified_name) @font-lock-type-face))

     :language 'sysml
     :feature 'literal
     '((number_literal) @font-lock-number-face
       (boolean_literal) @font-lock-constant-face
       (null_literal) @font-lock-constant-face)

     :language 'sysml
     :feature 'operator
     '([":>" ":>>" "~" "::" "==" "!=" "<=" ">="
        "+" "-" "*" "/" "%" "**" "=" ":="
        "not" "or" "and" "xor" "implies"
        "hastype" "istype" "as" "meta" "@"] @font-lock-operator-face)

     :language 'sysml
     :feature 'variable
     '((part_usage name: (identifier) @font-lock-variable-name-face)
       (attribute_usage name: (identifier) @font-lock-variable-name-face)
       (port_usage name: (identifier) @font-lock-variable-name-face)
       (action_usage name: (identifier) @font-lock-variable-name-face)
       (state_usage name: (identifier) @font-lock-variable-name-face)
       (item_usage name: (identifier) @font-lock-variable-name-face)
       (connection_usage name: (identifier) @font-lock-variable-name-face)
       (constraint_usage name: (identifier) @font-lock-variable-name-face)
       (requirement_usage name: (identifier) @font-lock-variable-name-face)))
    "Tree-sitter font-lock settings for SysML v2.")

  ;; --- Indentation rules ---

  (defvar sysml2-ts--indent-rules
    `((sysml
       ((node-is "}") parent-bol 0)
       ((node-is "]") parent-bol 0)
       ((node-is ")") parent-bol 0)
       ((parent-is "source_file") column-0 0)
       ((parent-is "package_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "definition_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "usage_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "enumeration_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "state_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "action_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "requirement_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "constraint_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "block") parent-bol ,sysml2-indent-offset)
       (no-node parent-bol ,sysml2-indent-offset)))
    "Tree-sitter indentation rules for SysML v2.")

  ;; --- Navigation ---

  (defvar sysml2-ts--defun-type-regexp
    (regexp-opt '("package_declaration"
                  "part_definition" "action_definition"
                  "state_definition" "port_definition"
                  "connection_definition" "attribute_definition"
                  "item_definition" "requirement_definition"
                  "constraint_definition" "view_definition"
                  "viewpoint_definition" "rendering_definition"
                  "concern_definition" "use_case_definition"
                  "analysis_case_definition" "verification_case_definition"
                  "allocation_definition" "interface_definition"
                  "enumeration_definition" "occurrence_definition"
                  "metadata_definition" "calc_definition"))
    "Regexp matching tree-sitter node types that are defun-like.")

  ;; --- Imenu ---

  (defvar sysml2-ts--imenu-settings
    '(("Package" "\\`package_declaration\\'" nil nil)
      ("Part" "\\`part_definition\\'" nil nil)
      ("Action" "\\`action_definition\\'" nil nil)
      ("State" "\\`state_definition\\'" nil nil)
      ("Port" "\\`port_definition\\'" nil nil)
      ("Requirement" "\\`requirement_definition\\'" nil nil)
      ("Constraint" "\\`constraint_definition\\'" nil nil)
      ("Attribute" "\\`attribute_definition\\'" nil nil))
    "Imenu category settings for tree-sitter SysML v2 mode.")

  ;; --- Mode definition ---

  ;;;###autoload
  (define-derived-mode sysml2-ts-mode prog-mode "SysML2[TS]"
    "Major mode for SysML v2 files using tree-sitter.

Provides syntax highlighting, indentation, and navigation using
the tree-sitter incremental parser for better accuracy.

\\{sysml2-mode-map}"
    :syntax-table sysml2-mode-syntax-table
    :group 'sysml2

    ;; Comments
    (setq-local comment-start "// ")
    (setq-local comment-end "")
    (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s-*")

    ;; Tree-sitter parser
    (treesit-parser-create 'sysml)

    ;; Font-lock
    (setq-local treesit-font-lock-settings sysml2-ts--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment string)
                  (keyword definition type)
                  (literal operator variable)))

    ;; Indentation
    (setq-local treesit-simple-indent-rules sysml2-ts--indent-rules)
    (setq-local indent-tabs-mode nil)

    ;; Navigation
    (setq-local treesit-defun-type-regexp sysml2-ts--defun-type-regexp)
    (setq-local treesit-defun-name-function #'sysml2-ts--defun-name)

    ;; Imenu
    (setq-local treesit-simple-imenu-settings sysml2-ts--imenu-settings)

    ;; Electric
    (setq-local electric-indent-chars
                (append '(?{ ?} ?\; ?\n) electric-indent-chars))

    ;; Keymap
    (use-local-map sysml2-mode-map)

    ;; Finalize
    (treesit-major-mode-setup))

  (defun sysml2-ts--defun-name (node)
    "Return the name of the defun NODE for imenu/which-function."
    (treesit-node-text
     (treesit-node-child-by-field-name node "name")
     t))

  ;; --- Auto-remap when grammar is available ---

  (when (treesit-ready-p 'sysml t)
    (add-to-list 'major-mode-remap-alist '(sysml2-mode . sysml2-ts-mode))))

(provide 'sysml2-ts)
;;; sysml2-ts.el ends here
