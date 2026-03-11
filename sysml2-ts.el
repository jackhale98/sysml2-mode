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
(defvar hs-special-modes-alist)

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
(declare-function sysml2-ts--search-definition-in-buffer "sysml2-ts")
(declare-function sysml2-ts--rename-symbol "sysml2-ts")
(declare-function sysml2-completion-at-point "sysml2-completion")
(declare-function hs-minor-mode "hideshow")
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
       ;; Closing delimiters align with opening line
       ((node-is "}") parent-bol 0)
       ((node-is "]") parent-bol 0)
       ((node-is ")") parent-bol 0)

       ;; Top-level: no indentation
       ((parent-is "source_file") column-0 0)

       ;; ── Body blocks (all braced containers) ──
       ;; These 6 node types are the ONLY brace-delimited body nodes in
       ;; the grammar.  Every definition and usage that has a `{...}` body
       ;; uses one of these, so these rules cover ~95% of indentation.
       ((parent-is "package_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "definition_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "enumeration_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "state_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "requirement_body") parent-bol ,sysml2-indent-offset)
       ((parent-is "constraint_body") parent-bol ,sysml2-indent-offset)

       ;; ── Multi-line statements (no braces, but children span lines) ──
       ;; Transitions: `transition NAME first X accept Y if Z do W then X;`
       ((parent-is "transition_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "succession_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "then_succession") parent-bol ,sysml2-indent-offset)

       ;; Connection/flow/allocation: `end = ...; end = ...;`
       ((parent-is "connection_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "flow_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "allocation_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "interface_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "binding_usage") parent-bol ,sysml2-indent-offset)

       ;; Satisfy/verify/assert statements
       ((parent-is "satisfy_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "verify_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "bind_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "assert_statement") parent-bol ,sysml2-indent-offset)

       ;; Control flow actions
       ((parent-is "if_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "while_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "for_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "loop_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "assign_action") parent-bol ,sysml2-indent-offset)

       ;; Fork/join/merge/decide nodes
       ((parent-is "fork_node") parent-bol ,sysml2-indent-offset)
       ((parent-is "join_node") parent-bol ,sysml2-indent-offset)
       ((parent-is "merge_node") parent-bol ,sysml2-indent-offset)
       ((parent-is "decide_node") parent-bol ,sysml2-indent-offset)

       ;; State entry/do/exit actions
       ((parent-is "entry_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "do_action") parent-bol ,sysml2-indent-offset)
       ((parent-is "exit_action") parent-bol ,sysml2-indent-offset)

       ;; Perform/exhibit/include statements
       ((parent-is "perform_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "exhibit_statement") parent-bol ,sysml2-indent-offset)
       ((parent-is "include_statement") parent-bol ,sysml2-indent-offset)

       ;; Metadata annotations
       ((parent-is "metadata_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "metadata_annotation_list") parent-bol ,sysml2-indent-offset)

       ;; ── Parenthesized expressions (multi-line argument lists) ──
       ((parent-is "paren_expression") parent-bol ,sysml2-indent-offset)
       ((parent-is "invocation_expression") parent-bol ,sysml2-indent-offset)

       ;; ── Usage types with potential multi-line content ──
       ((parent-is "action_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "state_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "part_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "port_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "requirement_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "constraint_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "calc_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "use_case_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "analysis_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "verification_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "view_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "concern_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "item_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "attribute_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "occurrence_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "snapshot_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "timeslice_usage") parent-bol ,sysml2-indent-offset)
       ((parent-is "ref_usage") parent-bol ,sysml2-indent-offset)

       ;; ── Definitions with multi-line headers ──
       ;; (rare, but e.g. `part def Vehicle :> Base` spanning lines)
       ((parent-is "part_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "action_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "state_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "requirement_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "use_case_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "verification_case_definition") parent-bol ,sysml2-indent-offset)
       ((parent-is "analysis_case_definition") parent-bol ,sysml2-indent-offset)

       ;; ── Catch-all: same indentation as parent ──
       ;; This avoids spurious indentation for nodes we haven't matched.
       (no-node parent-bol 0)
       (catch-all parent-bol 0)))
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

  (defvar sysml2-ts--context-node-alist
    '(("typed_by"           . typed-by)
      ("specialization"     . specialization)
      ("connect_clause"     . connect)
      ("allocate_clause"    . allocate)
      ("allocation_usage"   . allocate)
      ("satisfy_statement"  . satisfy)
      ("flow_usage"         . flow))
    "Alist mapping tree-sitter node types to completion context symbols.
Used by `sysml2-ts--parent-context' to determine what completions to offer.")

  (defun sysml2-ts--parent-context ()
    "Determine the completion context by examining the tree-sitter node at point.
Walks up the tree (max 5 levels) looking for context-significant ancestor
nodes.  Returns one of: `typed-by', `specialization', `body', `connect',
`allocate', `satisfy', `flow', or nil."
    (let* ((node (treesit-node-at (point)))
           (ancestor node)
           (levels 0)
           (context nil))
      ;; Walk up max 5 ancestor levels looking for a context node
      (while (and ancestor (< levels 5) (not context))
        (let ((node-type (treesit-node-type ancestor)))
          (let ((match (assoc node-type sysml2-ts--context-node-alist)))
            (when match
              (setq context (cdr match))))
          ;; Check body node types
          (when (and (not context)
                     (member node-type sysml2-ts--body-node-types))
            (setq context 'body)))
        (setq ancestor (treesit-node-parent ancestor))
        (setq levels (1+ levels)))
      context))

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
        ('allocate
         ;; Inside allocate clause or allocation_usage — suggest usage names
         (let ((candidates (sysml2-ts--collect-usage-names)))
           (when candidates
             (list start end candidates
                   :exclusive 'no
                   :annotation-function
                   (lambda (_cand) " <usage>")))))
        ('satisfy
         ;; Inside satisfy statement — suggest requirement and part names
         (let ((candidates (append (sysml2-ts--collect-definition-names)
                                   (sysml2-ts--collect-usage-names))))
           (when candidates
             (list start end candidates
                   :exclusive 'no
                   :annotation-function
                   (lambda (cand)
                     (if (member cand (sysml2-ts--collect-definition-names))
                         " <def>"
                       " <usage>"))))))
        ('flow
         ;; Inside flow usage — suggest port/part names
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

  ;; --- Go to Definition (tree-sitter) ---

  (defun sysml2-ts--search-definition-in-buffer (sym)
    "Search for a definition of SYM in the current buffer using tree-sitter.
Query all definition node types and `package_declaration' for a
node whose `name' field matches SYM.  Return the position
\(`treesit-node-start') of the first match, or nil."
    (let ((root (treesit-buffer-root-node))
          (all-types (cons "package_declaration"
                           sysml2-ts--definition-node-types))
          (result nil))
      (catch 'found
        (dolist (node-type all-types)
          (let ((query (format "((%s name: (identifier) @name))" node-type)))
            (condition-case nil
                (let ((captures (treesit-query-capture root query)))
                  (dolist (cap captures)
                    (when (and (eq (car cap) 'name)
                               (string= (treesit-node-text (cdr cap) t) sym))
                      (setq result (treesit-node-start (cdr cap)))
                      (throw 'found result))))
              (treesit-query-error nil)))))
      result))

  ;; --- Rename Symbol (tree-sitter) ---

  (defun sysml2-ts--rename-symbol ()
    "Rename the symbol at point in the current buffer using tree-sitter.
Finds all `identifier' nodes whose text matches the old name and
replaces them, working backwards from the end of the buffer to
preserve positions.  Prompts for the new name interactively."
    (let ((old-name (thing-at-point 'symbol t)))
      (unless old-name
        (user-error "No symbol at point"))
      (let ((new-name (read-string
                       (format "Rename `%s' to: " old-name)
                       old-name)))
        (when (string-empty-p new-name)
          (user-error "New name must not be empty"))
        (when (string= old-name new-name)
          (user-error "New name is the same as the old name"))
        (let* ((root (treesit-buffer-root-node))
               (query "((identifier) @id)")
               (captures (condition-case nil
                             (treesit-query-capture root query)
                           (treesit-query-error nil)))
               (matches nil)
               (count 0))
          ;; Collect all identifier nodes matching old-name
          (dolist (cap captures)
            (when (and (eq (car cap) 'id)
                       (string= (treesit-node-text (cdr cap) t) old-name))
              (push (cdr cap) matches)))
          ;; Sort by position descending so replacements don't shift later positions
          (setq matches (sort matches
                              (lambda (a b)
                                (> (treesit-node-start a)
                                   (treesit-node-start b)))))
          ;; Replace each match
          (dolist (node matches)
            (let ((start (treesit-node-start node))
                  (end (treesit-node-end node)))
              (goto-char start)
              (delete-region start end)
              (insert new-name)
              (setq count (1+ count))))
          (message "Renamed `%s' -> `%s' (%d occurrence%s)"
                   old-name new-name count
                   (if (= count 1) "" "s"))))))

  ;; --- Code folding (tree-sitter) ---

  (defvar sysml2-ts--fold-node-types
    '("package_body" "definition_body" "enumeration_body"
      "state_body" "requirement_body" "constraint_body"
      "block_comment" "doc_comment")
    "Tree-sitter node types that can be folded.")

  (defun sysml2-ts--hs-forward-sexp (&optional _arg)
    "Move forward over a foldable block using tree-sitter.
For use as `hs-forward-sexp-func' in `hs-minor-mode'."
    (let* ((node (treesit-node-at (point)))
           (body (treesit-parent-until
                  node
                  (lambda (n)
                    (member (treesit-node-type n)
                            sysml2-ts--fold-node-types)))))
      (if body
          (goto-char (treesit-node-end body))
        ;; Fallback: use forward-sexp
        (forward-sexp 1))))

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

    ;; Code folding (hideshow with tree-sitter)
    (add-to-list 'hs-special-modes-alist
                 '(sysml2-ts-mode "{" "}" "/[*/]"
                   sysml2-ts--hs-forward-sexp nil))
    (hs-minor-mode 1)

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
