;;; sysml2-ts.el --- Tree-sitter support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tree-sitter powered major mode for SysML v2 / KerML.
;; Provides enhanced font-lock, indentation, and navigation using
;; the tree-sitter incremental parser.
;;
;; Requires:
;;   - Emacs 29.1+ with tree-sitter support compiled in
;;   - The `sysml' tree-sitter grammar from
;;     https://github.com/jackhale98/tree-sitter-sysml
;;
;; When tree-sitter is available and the grammar is installed,
;; `sysml2-ts-mode' automatically remaps `sysml2-mode'.

;;; Code:

(require 'sysml2-vars)
(require 'sysml2-lang)

;; Forward-declare variables defined in sysml2-mode.el
(defvar sysml2-mode-syntax-table)
(defvar sysml2-mode-map)

;; Silence byte-compiler warnings for treesit functions/variables
(declare-function treesit-ready-p "treesit")
(declare-function treesit-parser-create "treesit")
(declare-function treesit-font-lock-rules "treesit")
(declare-function treesit-node-text "treesit")
(declare-function treesit-node-child-by-field-name "treesit")
(declare-function treesit-major-mode-setup "treesit")
(declare-function treesit-node-at "treesit")
(declare-function treesit-node-parent "treesit")
(declare-function treesit-node-type "treesit")
(declare-function treesit-parent-until "treesit")
(declare-function treesit-buffer-root-node "treesit")
(declare-function treesit-node-start "treesit")
(declare-function treesit-node-end "treesit")
(declare-function treesit-query-capture "treesit")
(declare-function sysml2-ts--defun-name "sysml2-ts")
(declare-function sysml2-ts--which-function "sysml2-ts")
(declare-function sysml2-ts--completion-at-point "sysml2-ts")
(declare-function sysml2-ts--parent-context "sysml2-ts")
(declare-function sysml2-ts--collect-definition-names "sysml2-ts")
(declare-function sysml2-ts--collect-usage-names "sysml2-ts")
(declare-function sysml2-completion-at-point "sysml2-completion")
(defvar treesit-language-source-alist)

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
     '(;; Structural keywords
       ["package" "import" "alias" "comment" "doc" "about" "filter"
        ;; Definition keyword
        "def"
        ;; Usage/definition type keywords
        "part" "action" "state" "port" "connection" "attribute"
        "item" "requirement" "constraint" "view" "viewpoint"
        "rendering" "concern" "allocation" "interface"
        "occurrence" "metadata" "calc"
        "ref" "exhibit" "perform" "include"
        "enum" "enumeration" "flow"
        ;; KerML keywords
        "assoc" "behavior" "class" "connector"
        "datatype" "feature" "function" "interaction"
        "namespace" "predicate" "struct" "type"
        "classifier" "metaclass" "expr" "step"
        ;; Behavioral keywords
        "entry" "first" "then" "accept"
        "for" "transition" "loop" "until"
        "if" "else" "while" "do" "assign" "send"
        "merge" "decide" "fork" "join"
        ;; Relationship keywords
        "satisfy" "require" "subject" "objective"
        "actor" "connect" "to"
        "end" "all" "default" "by"
        "use" "case" "analysis" "verification"
        "snapshot" "timeslice"
        "render" "expose" "stakeholder" "frame"
        "event" "return" "redefines" "subsets" "via"
        "conjugates" "references" "chains" "inverse"
        "library" "standard"
        ;; Visibility
        "public" "private" "protected"
        ;; Modifiers
        "abstract" "variation" "variant" "individual" "readonly"
        "derived" "nonunique" "ordered" "in" "out" "inout"
        "composite" "conjugate" "const" "disjoint" "portion" "var"
        ] @font-lock-keyword-face)

     :language 'sysml
     :feature 'definition
     :override t
     '((part_definition name: (identifier) @sysml2-definition-name-face)
       (action_definition name: (identifier) @sysml2-definition-name-face)
       (state_definition name: (identifier) @sysml2-definition-name-face)
       (port_definition name: (identifier) @sysml2-definition-name-face)
       (connection_definition name: (identifier) @sysml2-definition-name-face)
       (flow_definition name: (identifier) @sysml2-definition-name-face)
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
       (individual_definition name: (identifier) @sysml2-definition-name-face)
       (occurrence_definition name: (identifier) @sysml2-definition-name-face)
       (metadata_definition name: (identifier) @sysml2-definition-name-face)
       (calc_definition name: (identifier) @sysml2-definition-name-face)
       ;; KerML definitions
       (case_definition name: (identifier) @sysml2-definition-name-face)
       (class_definition name: (identifier) @sysml2-definition-name-face)
       (struct_definition name: (identifier) @sysml2-definition-name-face)
       (assoc_definition name: (identifier) @sysml2-definition-name-face)
       (behavior_definition name: (identifier) @sysml2-definition-name-face)
       (datatype_definition name: (identifier) @sysml2-definition-name-face)
       (feature_definition name: (identifier) @sysml2-definition-name-face)
       (function_definition name: (identifier) @sysml2-definition-name-face)
       (predicate_definition name: (identifier) @sysml2-definition-name-face)
       (connector_definition name: (identifier) @sysml2-definition-name-face)
       (interaction_definition name: (identifier) @sysml2-definition-name-face)
       (type_definition name: (identifier) @sysml2-definition-name-face)
       (namespace_definition name: (identifier) @sysml2-definition-name-face)
       (classifier_definition name: (identifier) @sysml2-definition-name-face)
       (metaclass_definition name: (identifier) @sysml2-definition-name-face)
       (expr_definition name: (identifier) @sysml2-definition-name-face)
       (step_definition name: (identifier) @sysml2-definition-name-face)
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
     '(["~" "::" "==" "!=" "<=" ">="
        "+" "-" "*" "/" "%" "**" "=" ":="
        "not" "or" "and" "xor" "implies"
        "hastype" "istype" "as" "@"] @font-lock-operator-face)

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
       (requirement_usage name: (identifier) @font-lock-variable-name-face)
       (snapshot_usage name: (identifier) @font-lock-variable-name-face)
       (timeslice_usage name: (identifier) @font-lock-variable-name-face)
       (calc_usage name: (identifier) @font-lock-variable-name-face)
       (view_usage name: (identifier) @font-lock-variable-name-face)
       (viewpoint_usage name: (identifier) @font-lock-variable-name-face)
       (rendering_usage name: (identifier) @font-lock-variable-name-face)
       (concern_usage name: (identifier) @font-lock-variable-name-face)
       (use_case_usage name: (identifier) @font-lock-variable-name-face)
       (analysis_usage name: (identifier) @font-lock-variable-name-face)
       (verification_usage name: (identifier) @font-lock-variable-name-face)
       (metadata_usage name: (identifier) @font-lock-variable-name-face)
       (classifier_usage name: (identifier) @font-lock-variable-name-face)
       (metaclass_usage name: (identifier) @font-lock-variable-name-face)
       (expr_usage name: (identifier) @font-lock-variable-name-face)
       (step_usage name: (identifier) @font-lock-variable-name-face)))
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
       ((parent-is "enumeration_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "state_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "requirement_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "constraint_body") parent-bol ,sysml2-indent-offset)
       (no-node parent-bol ,sysml2-indent-offset)))
    "Tree-sitter indentation rules for SysML v2.")

  ;; --- Navigation ---

  (defvar sysml2-ts--defun-type-regexp
    (regexp-opt '("package_declaration"
                  "part_definition" "action_definition"
                  "state_definition" "port_definition"
                  "connection_definition" "flow_definition"
                  "attribute_definition"
                  "item_definition" "requirement_definition"
                  "constraint_definition" "view_definition"
                  "viewpoint_definition" "rendering_definition"
                  "concern_definition" "use_case_definition"
                  "analysis_case_definition" "verification_case_definition"
                  "allocation_definition" "interface_definition"
                  "enumeration_definition" "individual_definition"
                  "occurrence_definition"
                  "metadata_definition" "calc_definition"
                  "classifier_definition" "metaclass_definition"
                  "expr_definition" "step_definition"))
    "Regexp matching tree-sitter node types that are defun-like.")

  ;; --- Imenu ---

  (defvar sysml2-ts--imenu-settings
    '(("Package" "\\`package_declaration\\'" nil nil)
      ("Part" "\\`part_definition\\'" nil nil)
      ("Action" "\\`action_definition\\'" nil nil)
      ("State" "\\`state_definition\\'" nil nil)
      ("Port" "\\`port_definition\\'" nil nil)
      ("Connection" "\\`connection_definition\\'" nil nil)
      ("Flow" "\\`flow_definition\\'" nil nil)
      ("Attribute" "\\`attribute_definition\\'" nil nil)
      ("Item" "\\`item_definition\\'" nil nil)
      ("Requirement" "\\`requirement_definition\\'" nil nil)
      ("Constraint" "\\`constraint_definition\\'" nil nil)
      ("View" "\\`view_definition\\'" nil nil)
      ("Viewpoint" "\\`viewpoint_definition\\'" nil nil)
      ("Rendering" "\\`rendering_definition\\'" nil nil)
      ("Concern" "\\`concern_definition\\'" nil nil)
      ("Use Case" "\\`use_case_definition\\'" nil nil)
      ("Analysis" "\\`analysis_case_definition\\'" nil nil)
      ("Verification" "\\`verification_case_definition\\'" nil nil)
      ("Allocation" "\\`allocation_definition\\'" nil nil)
      ("Interface" "\\`interface_definition\\'" nil nil)
      ("Enumeration" "\\`enumeration_definition\\'" nil nil)
      ("Individual" "\\`individual_definition\\'" nil nil)
      ("Occurrence" "\\`occurrence_definition\\'" nil nil)
      ("Metadata" "\\`metadata_definition\\'" nil nil)
      ("Calculation" "\\`calc_definition\\'" nil nil)
      ("Classifier" "\\`classifier_definition\\'" nil nil)
      ("Metaclass" "\\`metaclass_definition\\'" nil nil)
      ("Expression" "\\`expr_definition\\'" nil nil)
      ("Step" "\\`step_definition\\'" nil nil))
    "Imenu category settings for tree-sitter SysML v2 mode.")

  ;; --- Which-function support ---

  (defun sysml2-ts--which-function ()
    "Return the name of the enclosing definition at point using tree-sitter.
Walks up from the current node to find the nearest defun-like node
and returns its name field."
    (let* ((node (treesit-node-at (point)))
           (defun-node
            (treesit-parent-until
             node
             (lambda (n)
               (string-match-p sysml2-ts--defun-type-regexp
                               (treesit-node-type n))))))
      (when defun-node
        (let ((name-node (treesit-node-child-by-field-name defun-node "name")))
          (when name-node
            (treesit-node-text name-node t))))))

  ;; --- Tree-sitter completion support ---

  (defvar sysml2-ts--definition-node-types
    '("part_definition" "action_definition" "state_definition"
      "port_definition" "connection_definition" "flow_definition"
      "attribute_definition" "item_definition" "requirement_definition"
      "constraint_definition" "view_definition" "viewpoint_definition"
      "rendering_definition" "concern_definition" "use_case_definition"
      "analysis_case_definition" "verification_case_definition"
      "allocation_definition" "interface_definition"
      "enumeration_definition" "individual_definition"
      "occurrence_definition" "metadata_definition" "calc_definition"
      "case_definition" "class_definition" "struct_definition"
      "assoc_definition" "behavior_definition" "datatype_definition"
      "feature_definition" "function_definition" "predicate_definition"
      "connector_definition" "interaction_definition" "type_definition"
      "namespace_definition" "classifier_definition"
      "metaclass_definition" "expr_definition" "step_definition")
    "Tree-sitter node types that represent definitions.")

  (defvar sysml2-ts--usage-node-types
    '("part_usage" "action_usage" "state_usage" "port_usage"
      "connection_usage" "attribute_usage" "item_usage"
      "requirement_usage" "constraint_usage" "view_usage"
      "viewpoint_usage" "rendering_usage" "concern_usage"
      "use_case_usage" "analysis_usage" "verification_usage"
      "snapshot_usage" "timeslice_usage" "calc_usage"
      "metadata_usage" "classifier_usage" "metaclass_usage"
      "expr_usage" "step_usage")
    "Tree-sitter node types that represent usages.")

  (defvar sysml2-ts--body-node-types
    '("definition_body" "state_body" "requirement_body"
      "constraint_body" "package_body" "enumeration_body")
    "Tree-sitter node types that represent body blocks.")

  (defun sysml2-ts--collect-definition-names ()
    "Collect all definition names from the tree-sitter parse tree.
Returns a list of name strings for all definition nodes in the buffer."
    (let ((root (treesit-buffer-root-node))
          (names nil))
      (dolist (node-type sysml2-ts--definition-node-types)
        (let ((query (format "((%s name: (identifier) @name))" node-type)))
          (condition-case nil
              (let ((captures (treesit-query-capture root query)))
                (dolist (cap captures)
                  (when (eq (car cap) 'name)
                    (let ((text (treesit-node-text (cdr cap) t)))
                      (unless (member text names)
                        (push text names))))))
            (treesit-query-error nil))))
      (nreverse names)))

  (defun sysml2-ts--collect-usage-names ()
    "Collect all named usage elements from the tree-sitter parse tree.
Returns a list of name strings for connectable elements (parts, ports, etc.)."
    (let ((root (treesit-buffer-root-node))
          (names nil))
      (dolist (node-type sysml2-ts--usage-node-types)
        (let ((query (format "((%s name: (identifier) @name))" node-type)))
          (condition-case nil
              (let ((captures (treesit-query-capture root query)))
                (dolist (cap captures)
                  (when (eq (car cap) 'name)
                    (let ((text (treesit-node-text (cdr cap) t)))
                      (unless (member text names)
                        (push text names))))))
            (treesit-query-error nil))))
      (nreverse names)))

  (defun sysml2-ts--parent-context ()
    "Determine the completion context by examining the tree-sitter node at point.
Returns one of: `typed-by', `specialization', `body', `connect', or nil."
    (let* ((node (treesit-node-at (point)))
           (parent (and node (treesit-node-parent node)))
           (grandparent (and parent (treesit-node-parent parent)))
           (parent-type (and parent (treesit-node-type parent)))
           (grandparent-type (and grandparent (treesit-node-type grandparent))))
      (cond
       ;; Inside a typed_by clause — suggest definition names
       ((or (equal parent-type "typed_by")
            (equal grandparent-type "typed_by"))
        'typed-by)
       ;; Inside a specialization clause — suggest definition names
       ((or (equal parent-type "specialization")
            (equal grandparent-type "specialization"))
        'specialization)
       ;; Inside a connect clause or after "to" — suggest usage names
       ((or (equal parent-type "connect_clause")
            (equal grandparent-type "connect_clause"))
        'connect)
       ;; Inside a body block — suggest usage keywords
       ((or (member parent-type sysml2-ts--body-node-types)
            (member grandparent-type sysml2-ts--body-node-types))
        'body)
       ;; Default — no special tree-sitter context
       (t nil))))

  (defun sysml2-ts--completion-at-point ()
    "Completion-at-point function using tree-sitter for SysML v2 buffers.
Provides context-aware completion by examining the parse tree.
Falls back to `sysml2-completion-at-point' when no tree-sitter
context is identified."
    (let ((context (sysml2-ts--parent-context))
          (end (point))
          (start (save-excursion
                   (skip-chars-backward "A-Za-z0-9_:.*")
                   (point))))
      (pcase context
        ('typed-by
         (let ((candidates (append (sysml2-ts--collect-definition-names)
                                   sysml2-standard-library-packages)))
           (when candidates
             (list start end candidates
                   :exclusive 'no
                   :annotation-function
                   (lambda (cand)
                     (if (member cand sysml2-standard-library-packages)
                         " <lib>"
                       " <def>"))))))
        ('specialization
         (let ((candidates (append (sysml2-ts--collect-definition-names)
                                   sysml2-standard-library-packages)))
           (when candidates
             (list start end candidates
                   :exclusive 'no
                   :annotation-function
                   (lambda (cand)
                     (if (member cand sysml2-standard-library-packages)
                         " <lib>"
                       " <def>"))))))
        ('connect
         (let ((candidates (sysml2-ts--collect-usage-names)))
           (when candidates
             (list start end candidates
                   :exclusive 'no
                   :annotation-function
                   (lambda (_cand) " <usage>")))))
        ('body
         (let ((candidates (append sysml2-usage-keywords
                                   sysml2-behavioral-keywords
                                   sysml2-modifier-keywords)))
           (list start end candidates
                 :exclusive 'no
                 :annotation-function
                 (lambda (cand)
                   (cond
                    ((member cand sysml2-usage-keywords) " <usage>")
                    ((member cand sysml2-behavioral-keywords) " <behav>")
                    ((member cand sysml2-modifier-keywords) " <mod>")
                    (t nil))))))
        (_
         ;; Fall back to the regex-based CAPF
         (sysml2-completion-at-point)))))

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

    ;; Which-function
    (add-hook 'which-func-functions #'sysml2-ts--which-function nil t)

    ;; Completion
    (add-hook 'completion-at-point-functions #'sysml2-ts--completion-at-point nil t)

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

  ;; --- Grammar source for treesit-install-language-grammar ---

  (add-to-list 'treesit-language-source-alist
               '(sysml "https://github.com/jackhale98/tree-sitter-sysml"
                       nil "src"))

  ;; --- Auto-remap when grammar is available ---

  (when (treesit-ready-p 'sysml t)
    (add-to-list 'major-mode-remap-alist '(sysml2-mode . sysml2-ts-mode))))

(provide 'sysml2-ts)
;;; sysml2-ts.el ends here
