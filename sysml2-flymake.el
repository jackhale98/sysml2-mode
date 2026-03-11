;;; sysml2-flymake.el --- Flymake backend for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Lightweight regexp-based Flymake diagnostics for SysML v2 files.
;; No external process required — all checks run in-buffer.
;;
;; Checks:
;;   - Unmatched delimiters ({}/[]/())
;;   - Unknown definition keywords ("prat def Foo")
;;   - Missing semicolons on single-line usage patterns

;;; Code:

(require 'sysml2-vars)
(require 'sysml2-lang)

(declare-function flymake-make-diagnostic "flymake")
(declare-function flymake-diagnostic-functions "flymake")

;; Tree-sitter forward declarations
(declare-function treesit-available-p "treesit")
(declare-function treesit-ready-p "treesit")
(declare-function treesit-buffer-root-node "treesit")
(declare-function treesit-query-capture "treesit")
(declare-function treesit-node-start "treesit")
(declare-function treesit-node-end "treesit")
(declare-function treesit-node-type "treesit")
(declare-function treesit-node-parent "treesit")

;; --- Delimiter matching ---

(defun sysml2--check-unmatched-delimiters ()
  "Check for unmatched delimiters in the current buffer.
Returns a list of Flymake diagnostics for mismatched {}/[]/() pairs.
Uses `syntax-ppss' to skip strings and comments."
  (let ((stack nil)
        (diagnostics nil)
        (openers '((?{ . ?}) (?\( . ?\)) (?\[ . ?\])))
        (closers '((?} . ?{) (?\) . ?\() (?\] . ?\[))))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((ppss (syntax-ppss))
              (ch (char-after)))
          (unless (or (nth 3 ppss) (nth 4 ppss))  ; skip strings/comments
            (cond
             ;; Opening delimiter
             ((assq ch openers)
              (push (cons ch (point)) stack))
             ;; Closing delimiter
             ((assq ch closers)
              (let ((expected-open (cdr (assq ch closers))))
                (if (and stack (eq (caar stack) expected-open))
                    (pop stack)
                  (push (flymake-make-diagnostic
                         (current-buffer)
                         (point) (1+ (point))
                         :error
                         (format "Unmatched `%c'" ch))
                        diagnostics)))))))
        (forward-char 1)))
    ;; Report unclosed openers
    (dolist (open stack)
      (push (flymake-make-diagnostic
             (current-buffer)
             (cdr open) (1+ (cdr open))
             :error
             (format "Unmatched `%c'" (car open)))
            diagnostics))
    diagnostics))

;; --- Unknown definition keywords ---

(defconst sysml2--valid-def-prefixes
  (let ((prefixes nil))
    (dolist (kw sysml2-definition-keywords)
      (when (string-match "\\`\\(.+\\) def\\'" kw)
        (push (match-string 1 kw) prefixes)))
    prefixes)
  "List of valid prefixes that can appear before `def'.
Extracted from `sysml2-definition-keywords'.")

(defconst sysml2--valid-def-prefix-regexp
  (concat "\\<" (regexp-opt sysml2--valid-def-prefixes t) "\\s-+def\\>")
  "Regexp matching valid `PREFIX def' patterns.")

(defun sysml2--check-unknown-keywords ()
  "Check for unknown definition keyword patterns.
Scans for `WORD def NAME' where WORD is not a recognized definition prefix.
Returns a list of Flymake diagnostics."
  (let ((diagnostics nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\<\\([a-z]+\\)[ \t]+def\\>" nil t)
        (let ((beg (match-beginning 0))
              (end (match-end 0))
              (prefix (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (unless (member prefix sysml2--valid-def-prefixes)
                  (push (flymake-make-diagnostic
                         (current-buffer) beg end
                         :warning
                         (format "Unknown definition keyword `%s def'" prefix))
                        diagnostics))))))))
    diagnostics))

;; --- Missing semicolons ---

(defconst sysml2--semicolon-usage-regexp
  (concat "^[ \t]*"
          (regexp-opt '("attribute" "part" "port" "item" "ref"
                        "connection" "constraint" "requirement"
                        "allocation" "dependency")
                      t)
          "[ \t]+[A-Za-z_][A-Za-z0-9_]*"
          "[ \t]*:[ \t]*[A-Za-z_][A-Za-z0-9_:.*]*"
          "[ \t]*$")
  "Regexp matching single-line usage patterns that need a semicolon.
Matches: KEYWORD NAME : TYPE at end of line (no semicolon or brace).")

(defun sysml2--check-missing-semicolons ()
  "Check for missing semicolons on single-line usage declarations.
Returns a list of Flymake diagnostics."
  (let ((diagnostics nil))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward sysml2--semicolon-usage-regexp nil t)
        (let ((beg (match-beginning 0))
              (end (match-end 0)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push (flymake-make-diagnostic
                       (current-buffer) beg end
                       :warning
                       "Missing semicolon at end of declaration")
                      diagnostics)))))))
    diagnostics))

;; --- Standard library reference validation ---

(defun sysml2--check-library-references ()
  "Check that qualified references to ISQ, SI, and ScalarValues are valid.
Returns a list of Flymake diagnostics for unknown library members."
  (let ((diagnostics nil)
        ;; Match ISQ::Name, SI::Name, ScalarValues::Name
        (lib-ref-re (concat "\\b\\(ISQ\\|SI\\|ScalarValues\\)"
                            "::\\([A-Za-z_][A-Za-z0-9_°μ]*\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward lib-ref-re nil t)
        (let ((beg (match-beginning 0))
              (end (match-end 0))
              (lib (match-string-no-properties 1))
              (member-name (match-string-no-properties 2)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                ;; Skip wildcard imports like ISQ::*
                (unless (string= member-name "*")
                  (let ((valid-members
                         (cond
                          ((string= lib "ISQ") sysml2-isq-types)
                          ((string= lib "SI") sysml2-si-units)
                          ((string= lib "ScalarValues") sysml2-scalar-value-types))))
                    (when (and valid-members
                               (not (member member-name valid-members)))
                      (push (flymake-make-diagnostic
                             (current-buffer) beg end
                             :warning
                             (format "Unknown %s member `%s'" lib member-name))
                            diagnostics))))))))))
    diagnostics))

;; --- Tree-sitter Flymake backend ---

(defun sysml2-ts--error-message-for-parent (parent-node)
  "Return a context-aware error message based on PARENT-NODE type.
Examines the parent of an ERROR node to provide more specific diagnostics."
  (let ((parent-type (and parent-node (treesit-node-type parent-node))))
    (cond
     ((equal parent-type "definition_body")
      "Unexpected syntax in definition body")
     ((equal parent-type "package_body")
      "Unexpected syntax in package")
     ((equal parent-type "state_body")
      "Unexpected syntax in state body")
     ((equal parent-type "requirement_body")
      "Unexpected syntax in requirement body")
     ((equal parent-type "constraint_body")
      "Unexpected syntax in constraint body")
     ((equal parent-type "enumeration_body")
      "Unexpected syntax in enumeration body")
     (t
      "Tree-sitter syntax error"))))

(defun sysml2-ts--flymake-backend (report-fn &rest _args)
  "Flymake backend using tree-sitter to report syntax errors.
Queries the tree-sitter parse tree for ERROR and MISSING nodes
and reports them as Flymake diagnostics via REPORT-FN.

ERROR nodes are reported as errors with context-aware messages based
on their parent node type.  MISSING nodes are reported as warnings
indicating the expected node type."
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-ready-p 'sysml t))
    (let* ((root (treesit-buffer-root-node 'sysml))
           (errors (condition-case nil
                       (treesit-query-capture root '((ERROR) @error))
                     (treesit-query-error nil)))
           (missing (condition-case nil
                        (treesit-query-capture root '((MISSING) @missing))
                      (treesit-query-error nil)))
           (diagnostics nil))
      ;; Process ERROR nodes with context-aware messages
      (dolist (err errors)
        (when (eq (car err) 'error)
          (let* ((node (cdr err))
                 (parent (treesit-node-parent node))
                 (msg (sysml2-ts--error-message-for-parent parent)))
            (push (flymake-make-diagnostic
                   (current-buffer)
                   (treesit-node-start node)
                   (max (1+ (treesit-node-start node))
                        (treesit-node-end node))
                   :error
                   msg)
                  diagnostics))))
      ;; Process MISSING nodes as warnings
      (dolist (miss missing)
        (when (eq (car miss) 'missing)
          (let* ((node (cdr miss))
                 (node-type (treesit-node-type node)))
            (push (flymake-make-diagnostic
                   (current-buffer)
                   (treesit-node-start node)
                   (max (1+ (treesit-node-start node))
                        (treesit-node-end node))
                   :warning
                   (format "Missing expected node: %s" node-type))
                  diagnostics))))
      (funcall report-fn diagnostics))))

;; --- Semantic checks ---

(defun sysml2--check-unsatisfied-requirements ()
  "Check for requirement defs that have no matching satisfy statement.
Returns a list of Flymake diagnostics at :note level."
  (let ((req-defs nil)
        (satisfied nil)
        (diagnostics nil)
        (req-def-re (concat "\\brequirement\\s-+def\\s-+"
                            "\\(" sysml2--identifier-regexp "\\)"))
        (satisfy-re (concat "\\bsatisfy\\s-+\\(?:requirement\\s-+\\)?"
                            "\\(" sysml2--identifier-regexp "\\)")))
    ;; Collect requirement def names and positions
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward req-def-re nil t)
        (let ((beg (match-beginning 0))
              (name (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push (cons name beg) req-defs)))))))
    ;; Collect satisfied requirement names
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward satisfy-re nil t)
        (let ((beg (match-beginning 0))
              (name (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push name satisfied)))))))
    ;; Report unsatisfied
    (dolist (rd req-defs)
      (unless (member (car rd) satisfied)
        (push (flymake-make-diagnostic
               (current-buffer)
               (cdr rd) (+ (cdr rd) (length (car rd))
                           (length "requirement def "))
               :note
               (format "Requirement `%s' has no satisfy statement" (car rd)))
              diagnostics)))
    diagnostics))

(defun sysml2--check-unverified-requirements ()
  "Check for requirement defs that have no matching verify statement.
Returns a list of Flymake diagnostics at :note level."
  (let ((req-defs nil)
        (verified nil)
        (diagnostics nil)
        (req-def-re (concat "\\brequirement\\s-+def\\s-+"
                            "\\(" sysml2--identifier-regexp "\\)"))
        (verify-re (concat "\\bverify\\s-+\\(?:requirement\\s-+\\)?"
                           "\\(" sysml2--identifier-regexp "\\)")))
    ;; Collect requirement def names and positions
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward req-def-re nil t)
        (let ((beg (match-beginning 0))
              (name (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push (cons name beg) req-defs)))))))
    ;; Collect verified requirement names
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward verify-re nil t)
        (let ((beg (match-beginning 0))
              (name (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push name verified)))))))
    ;; Report unverified
    (dolist (rd req-defs)
      (unless (member (car rd) verified)
        (push (flymake-make-diagnostic
               (current-buffer)
               (cdr rd) (+ (cdr rd) (length (car rd))
                           (length "requirement def "))
               :note
               (format "Requirement `%s' has no verify statement" (car rd)))
              diagnostics)))
    diagnostics))

(defun sysml2--check-unused-definitions ()
  "Check for definitions that are never referenced elsewhere in the buffer.
Returns a list of Flymake diagnostics at :note level.
Skips package declarations."
  (let ((defs nil)
        (diagnostics nil)
        (def-re (concat "\\b\\(?:part\\|action\\|state\\|port\\|connection"
                        "\\|attribute\\|item\\|requirement\\|constraint"
                        "\\|view\\|viewpoint\\|rendering\\|concern"
                        "\\|allocation\\|interface\\|enum\\|enumeration"
                        "\\|occurrence\\|metadata\\|calc\\|flow"
                        "\\|analysis\\|verification"
                        "\\|use case\\|case"
                        "\\|assoc\\|assoc struct\\|behavior\\|class"
                        "\\|classifier\\|connector\\|datatype\\|expr"
                        "\\|feature\\|function\\|interaction\\|metaclass"
                        "\\|predicate\\|step\\|struct\\|type"
                        "\\)\\s-+def\\s-+"
                        "\\(" sysml2--identifier-regexp "\\)")))
    ;; Collect all definitions (name, position)
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward def-re nil t)
        (let ((beg (match-beginning 0))
              (name (match-string-no-properties 1)))
          (save-excursion
            (let ((ppss (syntax-ppss beg)))
              (unless (or (nth 3 ppss) (nth 4 ppss))
                (push (cons name beg) defs)))))))
    ;; Check each definition for references
    (dolist (def defs)
      (let* ((name (car def))
             (name-re (concat "\\b" (regexp-quote name) "\\b"))
             (count 0))
        (save-excursion
          (goto-char (point-min))
          (while (re-search-forward name-re nil t)
            (save-excursion
              (let ((ppss (syntax-ppss (match-beginning 0))))
                (unless (or (nth 3 ppss) (nth 4 ppss))
                  (setq count (1+ count)))))))
        ;; If only appears once (its own declaration), it's unused
        (when (<= count 1)
          (push (flymake-make-diagnostic
                 (current-buffer)
                 (cdr def) (+ (cdr def) (length name))
                 :note
                 (format "Definition `%s' is never referenced" name))
                diagnostics))))
    diagnostics))

;; --- In-process Flymake backend ---

(defun sysml2--flymake-backend (report-fn &rest _args)
  "Flymake backend for SysML v2 syntax checking.
Calls REPORT-FN with collected diagnostics from all in-process checks."
  (let ((diagnostics (append (sysml2--check-unmatched-delimiters)
                             (sysml2--check-unknown-keywords)
                             (sysml2--check-missing-semicolons)
                             (sysml2--check-unsatisfied-requirements)
                             (sysml2--check-unverified-requirements)
                             (sysml2--check-unused-definitions)
                             (sysml2--check-library-references))))
    (funcall report-fn diagnostics)))

;; --- External CLI Flymake backend ---

(defvar-local sysml2--flymake-cli-process nil
  "Current `sysml lint' process for Flymake.")

(defun sysml2-cli--flymake-backend (report-fn &rest _args)
  "Flymake backend using `sysml lint' for validation.
Runs `sysml lint -f json' asynchronously and parses JSON diagnostics.
Checks: syntax (E001), duplicates (E002), unused (W001),
unsatisfied (W002), unverified (W003), unresolved (W004/W005),
port-types (W006), constraints (W007), calculations (W008).

Falls back silently if the sysml CLI is not available.
Calls REPORT-FN with the collected diagnostics."
  (let* ((exe-name (or (bound-and-true-p sysml2-cli-executable) "sysml"))
         (exe (sysml2--find-executable exe-name)))
    (unless exe
      (funcall report-fn nil)
      (cl-return-from sysml2-cli--flymake-backend))
    ;; Kill any in-progress process
    (when (and sysml2--flymake-cli-process
               (process-live-p sysml2--flymake-cli-process))
      (kill-process sysml2--flymake-cli-process))
    (let* ((source-buf (current-buffer))
           (file buffer-file-name)
           (tmp (when file
                  (make-temp-file "sysml2-lint-" nil ".sysml"))))
      (unless file
        (funcall report-fn nil)
        (cl-return-from sysml2-cli--flymake-backend))
      ;; Write current buffer content to temp file for unsaved changes
      (write-region (point-min) (point-max) tmp nil 'nomessage)
      (let* ((output-buf (generate-new-buffer " *sysml-lint*"))
             (proc (start-process "sysml-lint" output-buf
                                  exe "-f" "json" "lint" tmp)))
        (setq sysml2--flymake-cli-process proc)
        (set-process-sentinel
         proc
         (lambda (p _event)
           (unwind-protect
               (when (and (eq (process-status p) 'exit)
                          (buffer-live-p source-buf))
                 (with-current-buffer source-buf
                   (let ((diagnostics
                          (sysml2--flymake-parse-cli-json
                           output-buf source-buf file tmp)))
                     (funcall report-fn diagnostics))))
             (ignore-errors (delete-file tmp))
             (when (buffer-live-p output-buf)
               (kill-buffer output-buf)))))))))

(defun sysml2--flymake-parse-cli-json (output-buf source-buf
                                                   _orig-file _tmp-file)
  "Parse JSON diagnostics from OUTPUT-BUF for SOURCE-BUF.
_ORIG-FILE is the real file path, _TMP-FILE is the temp file used.
Returns a list of Flymake diagnostics."
  (let ((diagnostics nil))
    (with-current-buffer output-buf
      (goto-char (point-min))
      (condition-case nil
          (let ((json-data (json-parse-buffer
                            :object-type 'alist :array-type 'list)))
            (dolist (item (if (listp json-data) json-data nil))
              (let* ((msg (alist-get 'message item))
                     (code (alist-get 'code item))
                     (severity-str (alist-get 'severity item))
                     (span (alist-get 'span item))
                     (start-row (alist-get 'start_row span))
                     (start-col (alist-get 'start_col span))
                     (end-row (alist-get 'end_row span))
                     (end-col (alist-get 'end_col span))
                     (severity (pcase severity-str
                                 ("error" :error)
                                 ("warning" :warning)
                                 (_ :note)))
                     (label (if code (format "[%s] %s" code msg) msg)))
                (with-current-buffer source-buf
                  (save-excursion
                    (let ((beg (sysml2--flymake-row-col-to-pos
                                start-row start-col))
                          (end (sysml2--flymake-row-col-to-pos
                                end-row end-col)))
                      ;; Ensure at least 1 character span
                      (when (= beg end)
                        (setq end (min (1+ beg) (point-max))))
                      (push (flymake-make-diagnostic
                             source-buf beg end severity label)
                            diagnostics)))))))
        (error nil)))
    (nreverse diagnostics)))

(defun sysml2--flymake-row-col-to-pos (row col)
  "Convert 0-based ROW and COL to a buffer position."
  (save-excursion
    (goto-char (point-min))
    (forward-line (or row 0))
    (let ((line-end (line-end-position)))
      (forward-char (min (or col 0) (- line-end (point))))
      (point))))

;; --- Setup ---

(defun sysml2-flymake-setup ()
  "Set up the Flymake backend for the current SysML v2 buffer.
Registers the in-process regexp-based backend unconditionally,
the tree-sitter backend when available, and the external `sysml lint'
backend when the CLI is installed."
  (add-hook 'flymake-diagnostic-functions #'sysml2--flymake-backend nil t)
  (when (and (fboundp 'treesit-available-p)
             (treesit-available-p)
             (treesit-ready-p 'sysml t))
    (add-hook 'flymake-diagnostic-functions
              #'sysml2-ts--flymake-backend nil t))
  ;; External CLI backend (runs async, provides deeper analysis)
  (when (sysml2--find-executable
         (or (bound-and-true-p sysml2-cli-executable) "sysml"))
    (add-hook 'flymake-diagnostic-functions
              #'sysml2-cli--flymake-backend nil t)))

(provide 'sysml2-flymake)
;;; sysml2-flymake.el ends here
