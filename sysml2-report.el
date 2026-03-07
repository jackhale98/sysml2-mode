;;; sysml2-report.el --- Model statistics and traceability for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Model reporting for SysML v2 files:
;;
;; - `sysml2-report-summary' -- display a model statistics buffer
;;   counting definitions, usages, relationships, packages, imports,
;;   and requirement coverage (satisfied / verified).
;;
;; - `sysml2-report-traceability' -- display a traceability matrix
;;   linking requirements to their satisfy and verify statements
;;   using `tabulated-list-mode' for sortable columns.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-report-summary' -- Show model statistics in a summary buffer
;;   `sysml2-report-traceability' -- Show requirement traceability matrix
;;   `sysml2-report-export-markdown' -- Export model report as Markdown file
;;   `sysml2-report-export' -- Export via Pandoc (PDF/HTML/DOCX)

(require 'sysml2-lang)
(require 'sysml2-vars)

;; Forward declarations for plantuml extractors
(declare-function sysml2--puml-extract-part-defs "sysml2-plantuml")
(declare-function sysml2--puml-extract-typed-defs "sysml2-plantuml")
(declare-function sysml2--puml-extract-enum-defs "sysml2-plantuml")
(declare-function sysml2--puml-extract-port-usages "sysml2-plantuml")
(declare-function sysml2--puml-extract-connections "sysml2-plantuml")
(declare-function sysml2--puml-extract-requirements "sysml2-plantuml")
(declare-function sysml2--puml-extract-requirement-usages "sysml2-plantuml")
(declare-function sysml2--puml-extract-states "sysml2-plantuml")
(declare-function sysml2--puml-extract-transitions "sysml2-plantuml")
(declare-function sysml2--puml-extract-actions "sysml2-plantuml")
(declare-function sysml2--puml-extract-successions "sysml2-plantuml")
(declare-function sysml2--puml-extract-satisfactions "sysml2-plantuml")
(declare-function sysml2--puml-find-def-bounds "sysml2-plantuml")

;; ---------------------------------------------------------------------------
;; Helper: comment/string check
;; ---------------------------------------------------------------------------

(defun sysml2--report-in-comment-or-string-p ()
  "Return non-nil if point is inside a comment or string."
  (let ((state (syntax-ppss)))
    (or (nth 3 state) (nth 4 state))))

;; ---------------------------------------------------------------------------
;; Collect definitions
;; ---------------------------------------------------------------------------

(defun sysml2--report-collect-definitions ()
  "Collect all definition names by type from the current buffer.
Returns an alist of (KEYWORD . (NAME ...)) pairs, sorted by keyword.
Only definitions outside comments and strings are counted."
  (let ((result nil)
        (def-re (concat "\\b\\("
                        (regexp-opt sysml2-definition-keywords t)
                        "\\)\\s-+\\("
                        sysml2--identifier-regexp
                        "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward def-re nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (let ((kw (match-string-no-properties 1))
                (name (match-string-no-properties 3)))
            (let ((entry (assoc kw result)))
              (if entry
                  (setcdr entry (cons name (cdr entry)))
                (push (cons kw (list name)) result)))))))
    ;; Reverse each name list to preserve file order, sort by keyword
    (mapcar (lambda (pair)
              (cons (car pair) (nreverse (cdr pair))))
            (sort result (lambda (a b) (string< (car a) (car b)))))))

;; ---------------------------------------------------------------------------
;; Collect usages
;; ---------------------------------------------------------------------------

(defun sysml2--report-count-usages ()
  "Count usage statements by type from the current buffer.
Returns an alist of (KEYWORD . COUNT) pairs.
Usages that are actually part of definition keywords (e.g. the `part'
in `part def') are excluded."
  (let ((result nil)
        ;; Match usage keyword followed by whitespace and an identifier.
        ;; The manual check below filters out "keyword def" patterns.
        (usage-re (concat "\\_<\\("
                          (regexp-opt sysml2-usage-keywords t)
                          "\\)\\s-+"
                          "\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward usage-re nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (let ((kw (match-string-no-properties 1)))
            ;; Verify the word after the keyword is not "def"
            (save-excursion
              (goto-char (match-end 1))
              (skip-chars-forward " \t")
              (unless (looking-at-p "\\_<def\\_>")
                (let ((entry (assoc kw result)))
                  (if entry
                      (setcdr entry (1+ (cdr entry)))
                    (push (cons kw 1) result)))))))))
    (sort result (lambda (a b) (string< (car a) (car b))))))

;; ---------------------------------------------------------------------------
;; Collect satisfy statements
;; ---------------------------------------------------------------------------

(defun sysml2--report-collect-satisfy ()
  "Collect satisfy statements from the current buffer.
Returns a list of (REQUIREMENT-NAME . TARGET-NAME) pairs from
statements like `satisfy requirement ReqName by TargetName'."
  (let ((result nil)
        (satisfy-re (concat "\\bsatisfy\\s-+requirement\\s-+"
                            "\\(" sysml2--qualified-name-regexp "\\)"
                            "\\s-+by\\s-+"
                            "\\(" sysml2--qualified-name-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward satisfy-re nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (let ((req (match-string-no-properties 1))
                (target (match-string-no-properties 2)))
            (push (cons req target) result)))))
    (nreverse result)))

;; ---------------------------------------------------------------------------
;; Collect verify statements
;; ---------------------------------------------------------------------------

(defun sysml2--report-collect-verify ()
  "Collect verify statements from the current buffer.
Returns a list of (REQUIREMENT-NAME . VERIFICATION-DEF-NAME) pairs.
Looks for `verify requirement ReqName' inside `verification def VerifName'
blocks, as well as standalone `verify requirement ReqName' statements."
  (let ((result nil)
        (verif-def-re (concat "\\bverification\\s-+def\\s-+"
                              "\\(" sysml2--identifier-regexp "\\)"))
        (verify-re (concat "\\bverify\\s-+requirement\\s-+"
                           "\\(" sysml2--qualified-name-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      ;; Strategy: find each verification def, then look for verify statements
      ;; inside its body.
      (while (re-search-forward verif-def-re nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (let ((verif-name (match-string-no-properties 1))
                (block-start nil)
                (block-end nil))
            ;; Find the opening brace
            (when (re-search-forward "{" nil t)
              (setq block-start (point))
              (backward-char 1)
              (condition-case nil
                  (progn
                    (forward-sexp 1)
                    (setq block-end (point)))
                (scan-error
                 (setq block-end (point-max)))))
            (when (and block-start block-end)
              (save-excursion
                (goto-char block-start)
                (while (re-search-forward verify-re block-end t)
                  (unless (sysml2--report-in-comment-or-string-p)
                    (let ((req-name (match-string-no-properties 1)))
                      (push (cons req-name verif-name) result)))))))))
      ;; Also find standalone verify statements (outside verification defs)
      (goto-char (point-min))
      (while (re-search-forward verify-re nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (let ((req-name (match-string-no-properties 1)))
            ;; Only add if not already captured from a verification def block
            (unless (assoc req-name result)
              (push (cons req-name nil) result))))))
    (nreverse result)))

;; ---------------------------------------------------------------------------
;; Count relationships
;; ---------------------------------------------------------------------------

(defun sysml2--report-count-relationships ()
  "Count relationship statements from the current buffer.
Returns an alist of (TYPE . COUNT) for connections, flows, bindings,
allocations, satisfy statements, and verify statements."
  (let ((counts nil))
    (save-excursion
      ;; connection (usage, not "connection def")
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<connection\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (save-excursion
              (goto-char (match-end 0))
              (skip-chars-forward " \t")
              (unless (looking-at-p "\\_<def\\_>")
                (setq n (1+ n))))))
        (when (> n 0) (push (cons "connection" n) counts)))
      ;; flow (usage, not "flow def")
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<flow\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (save-excursion
              (goto-char (match-end 0))
              (skip-chars-forward " \t")
              (unless (looking-at-p "\\_<def\\_>")
                (setq n (1+ n))))))
        (when (> n 0) (push (cons "flow" n) counts)))
      ;; binding
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<binding\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (setq n (1+ n))))
        (when (> n 0) (push (cons "binding" n) counts)))
      ;; allocation (usage, not "allocation def")
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<allocation\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (save-excursion
              (goto-char (match-end 0))
              (skip-chars-forward " \t")
              (unless (looking-at-p "\\_<def\\_>")
                (setq n (1+ n))))))
        (when (> n 0) (push (cons "allocation" n) counts)))
      ;; satisfy
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<satisfy\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (setq n (1+ n))))
        (when (> n 0) (push (cons "satisfy" n) counts)))
      ;; verify
      (goto-char (point-min))
      (let ((n 0))
        (while (re-search-forward "\\_<verify\\_>" nil t)
          (unless (sysml2--report-in-comment-or-string-p)
            (setq n (1+ n))))
        (when (> n 0) (push (cons "verify" n) counts))))
    (sort counts (lambda (a b) (string< (car a) (car b))))))

;; ---------------------------------------------------------------------------
;; Count packages and imports
;; ---------------------------------------------------------------------------

(defun sysml2--report-count-packages ()
  "Count package declarations in the current buffer."
  (let ((n 0))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward
              (concat "\\_<package\\s-+" sysml2--identifier-regexp) nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (setq n (1+ n)))))
    n))

(defun sysml2--report-count-imports ()
  "Count import statements in the current buffer."
  (let ((n 0))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward "\\_<import\\_>" nil t)
        (unless (sysml2--report-in-comment-or-string-p)
          (setq n (1+ n)))))
    n))

;; ---------------------------------------------------------------------------
;; Summary buffer
;; ---------------------------------------------------------------------------

;;;###autoload
(defun sysml2-report-summary ()
  "Display a model statistics summary for the current SysML v2 buffer.
Creates a `*SysML2 Summary*' buffer with counts of definitions, usages,
relationships, packages, imports, and requirement coverage analysis."
  (interactive)
  (let* ((source-buf (current-buffer))
         (file-name (or (buffer-file-name) (buffer-name)))
         (definitions (with-current-buffer source-buf
                        (sysml2--report-collect-definitions)))
         (usages (with-current-buffer source-buf
                   (sysml2--report-count-usages)))
         (relationships (with-current-buffer source-buf
                          (sysml2--report-count-relationships)))
         (satisfy-pairs (with-current-buffer source-buf
                          (sysml2--report-collect-satisfy)))
         (verify-pairs (with-current-buffer source-buf
                         (sysml2--report-collect-verify)))
         (pkg-count (with-current-buffer source-buf
                      (sysml2--report-count-packages)))
         (import-count (with-current-buffer source-buf
                         (sysml2--report-count-imports)))
         ;; Coverage computation
         (req-defs (cdr (assoc "requirement def" definitions)))
         (req-total (length req-defs))
         (satisfied-reqs (delete-dups (mapcar #'car satisfy-pairs)))
         (verified-reqs (delete-dups (mapcar #'car verify-pairs)))
         (num-satisfied (length satisfied-reqs))
         (num-verified (length verified-reqs))
         ;; Allocation counting
         (alloc-defs (cdr (assoc "allocation def" definitions)))
         (alloc-count (or (cdr (assoc "allocation" relationships)) 0))
         (buf (get-buffer-create "*SysML2 Summary*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "=== SysML v2 Model Summary ===\n")
        (insert (format "File: %s\n" (file-name-nondirectory file-name)))
        ;; Definitions section
        (insert "\n--- Definitions ---\n")
        (let ((def-total 0))
          (dolist (entry definitions)
            (let ((count (length (cdr entry))))
              (setq def-total (+ def-total count))
              (insert (format "  %-20s %d\n" (concat (car entry) ":") count))))
          (when (> def-total 0)
            (insert (format "  %-20s %d\n" "Total:" def-total)))
          (when (null definitions)
            (insert "  (none)\n")))
        ;; Usages section
        (insert "\n--- Usages ---\n")
        (let ((usage-total 0))
          (dolist (entry usages)
            (setq usage-total (+ usage-total (cdr entry)))
            (insert (format "  %-20s %d\n" (concat (car entry) ":") (cdr entry))))
          (when (> usage-total 0)
            (insert (format "  %-20s %d\n" "Total:" usage-total)))
          (when (null usages)
            (insert "  (none)\n")))
        ;; Relationships section
        (insert "\n--- Relationships ---\n")
        (if relationships
            (dolist (entry relationships)
              (insert (format "  %-20s %d\n" (concat (car entry) ":") (cdr entry))))
          (insert "  (none)\n"))
        ;; Coverage section
        (insert "\n--- Coverage ---\n")
        (if (> req-total 0)
            (let ((sat-pct (/ (* 100.0 num-satisfied) req-total))
                  (ver-pct (/ (* 100.0 num-verified) req-total)))
              (insert (format "  Requirements:     %d defined, %d satisfied (%.0f%%), %d verified (%.0f%%)\n"
                              req-total num-satisfied sat-pct num-verified ver-pct)))
          (insert "  Requirements:     0 defined\n"))
        (when (or alloc-defs (> alloc-count 0))
          (insert (format "  Allocations:      %d defined, %d usages\n"
                          (length alloc-defs) alloc-count)))
        ;; Structure section
        (insert "\n--- Structure ---\n")
        (insert (format "  %-20s %d\n" "Packages:" pkg-count))
        (insert (format "  %-20s %d\n" "Imports:" import-count)))
      (goto-char (point-min))
      (special-mode))
    (display-buffer buf)
    buf))

;; ---------------------------------------------------------------------------
;; Traceability matrix (tabulated-list-mode)
;; ---------------------------------------------------------------------------

(define-derived-mode sysml2-report-traceability-mode tabulated-list-mode
  "SysML2-Trace"
  "Major mode for the SysML v2 traceability matrix.
Provides a sortable table of requirements with their satisfy and verify
relationships."
  (setq tabulated-list-format
        [("Requirement" 20 t)
         ("Satisfied By" 20 t)
         ("Verified By" 20 t)
         ("Status" 12 t)])
  (setq tabulated-list-padding 2)
  (tabulated-list-init-header))

;;;###autoload
(defun sysml2-report-traceability ()
  "Display a traceability matrix for the current SysML v2 buffer.
Creates a `*SysML2 Traceability*' buffer showing requirements, their
satisfy and verify relationships, and coverage status.  The buffer uses
`tabulated-list-mode' so columns are sortable by clicking headers."
  (interactive)
  (let* ((source-buf (current-buffer))
         (definitions (with-current-buffer source-buf
                        (sysml2--report-collect-definitions)))
         (satisfy-pairs (with-current-buffer source-buf
                          (sysml2--report-collect-satisfy)))
         (verify-pairs (with-current-buffer source-buf
                         (sysml2--report-collect-verify)))
         (req-names (or (cdr (assoc "requirement def" definitions)) '()))
         ;; Build lookup tables: req-name -> list of targets / verifiers
         (satisfy-map (make-hash-table :test 'equal))
         (verify-map (make-hash-table :test 'equal))
         (entries nil)
         (buf (get-buffer-create "*SysML2 Traceability*")))
    ;; Populate satisfy map
    (dolist (pair satisfy-pairs)
      (let ((req (car pair))
            (target (cdr pair)))
        (puthash req (cons target (gethash req satisfy-map)) satisfy-map)))
    ;; Populate verify map
    (dolist (pair verify-pairs)
      (let ((req (car pair))
            (verifier (cdr pair)))
        (puthash req (cons verifier (gethash req verify-map)) verify-map)))
    ;; Build table entries
    (dolist (req-name req-names)
      (let* ((satisfied-by (gethash req-name satisfy-map))
             (verified-by (gethash req-name verify-map))
             (sat-str (if satisfied-by
                         (mapconcat #'identity (nreverse satisfied-by) ", ")
                       "\u2014"))
             (ver-str (if verified-by
                         (mapconcat (lambda (v) (or v "standalone"))
                                    (nreverse verified-by) ", ")
                       "\u2014"))
             (status (cond
                      ((and satisfied-by verified-by) "\u2713 Full")
                      (satisfied-by                   "\u25B3 No test")
                      (t                              "\u2717 Gap"))))
        (push (list req-name (vector req-name sat-str ver-str status))
              entries)))
    (setq entries (nreverse entries))
    (with-current-buffer buf
      (sysml2-report-traceability-mode)
      (setq tabulated-list-entries entries)
      (tabulated-list-print t)
      ;; Insert header above the table
      (let ((inhibit-read-only t))
        (goto-char (point-min))
        (insert "=== SysML v2 Traceability Matrix ===\n\n")))
    (display-buffer buf)
    buf))

;; ---------------------------------------------------------------------------
;; Markdown export — section renderers
;; ---------------------------------------------------------------------------

(defconst sysml2--report-md-sections
  '(("summary"        . "Model Summary")
    ("part-decomp"    . "Part Decomposition (BOM)")
    ("interfaces"     . "Interface Table")
    ("connections"    . "Connection Matrix")
    ("requirements"   . "Requirements Specification")
    ("traceability"   . "Traceability Matrix")
    ("states"         . "State Machines")
    ("actions"        . "Action Flows")
    ("enumerations"   . "Enumerations"))
  "Available Markdown report sections as (ID . TITLE) pairs.")

(defun sysml2--report-md-heading (level text)
  "Return a Markdown heading at LEVEL with TEXT."
  (concat (make-string level ?#) " " text "\n\n"))

(defun sysml2--report-md-summary (source-buf)
  "Render the Model Summary section from SOURCE-BUF."
  (with-current-buffer source-buf
    (let* ((definitions (sysml2--report-collect-definitions))
           (usages (sysml2--report-count-usages))
           (relationships (sysml2--report-count-relationships))
           (satisfy-pairs (sysml2--report-collect-satisfy))
           (verify-pairs (sysml2--report-collect-verify))
           (pkg-count (sysml2--report-count-packages))
           (import-count (sysml2--report-count-imports))
           (req-defs (cdr (assoc "requirement def" definitions)))
           (req-total (length req-defs))
           (num-satisfied (length (delete-dups (mapcar #'car satisfy-pairs))))
           (num-verified (length (delete-dups (mapcar #'car verify-pairs))))
           (lines nil))
      (push (sysml2--report-md-heading 2 "Model Summary") lines)
      ;; Definitions table
      (push "### Definitions\n\n" lines)
      (push "| Type | Count |\n|------|-------|\n" lines)
      (let ((def-total 0))
        (dolist (entry definitions)
          (let ((count (length (cdr entry))))
            (setq def-total (+ def-total count))
            (push (format "| %s | %d |\n" (car entry) count) lines)))
        (push (format "| **Total** | **%d** |\n" def-total) lines))
      ;; Usages table
      (push "\n### Usages\n\n" lines)
      (push "| Type | Count |\n|------|-------|\n" lines)
      (let ((usage-total 0))
        (dolist (entry usages)
          (setq usage-total (+ usage-total (cdr entry)))
          (push (format "| %s | %d |\n" (car entry) (cdr entry)) lines))
        (push (format "| **Total** | **%d** |\n" usage-total) lines))
      ;; Relationships
      (when relationships
        (push "\n### Relationships\n\n" lines)
        (push "| Type | Count |\n|------|-------|\n" lines)
        (dolist (entry relationships)
          (push (format "| %s | %d |\n" (car entry) (cdr entry)) lines)))
      ;; Coverage
      (push "\n### Coverage\n\n" lines)
      (if (> req-total 0)
          (let ((sat-pct (/ (* 100.0 num-satisfied) req-total))
                (ver-pct (/ (* 100.0 num-verified) req-total)))
            (push (format "- **Requirements:** %d defined, %d satisfied (%.0f%%), %d verified (%.0f%%)\n"
                          req-total num-satisfied sat-pct num-verified ver-pct) lines))
        (push "- **Requirements:** 0 defined\n" lines))
      (push (format "- **Packages:** %d\n" pkg-count) lines)
      (push (format "- **Imports:** %d\n" import-count) lines)
      (push "\n" lines)
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-part-decomp (source-buf)
  "Render the Part Decomposition / BOM section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((part-defs (sysml2--puml-extract-part-defs))
          (lines nil))
      (push (sysml2--report-md-heading 2 "Part Decomposition (BOM)") lines)
      (if (null part-defs)
          (push "*No part definitions found.*\n\n" lines)
        (dolist (def part-defs)
          (let ((name (plist-get def :name))
                (super (plist-get def :super))
                (abstract (plist-get def :abstract))
                (attrs (plist-get def :attributes))
                (parts (plist-get def :parts)))
            (push (format "### %s%s\n\n"
                          (if abstract "*abstract* " "")
                          name) lines)
            (when super
              (push (format "- **Specializes:** %s\n" super) lines))
            ;; Attributes
            (when attrs
              (push "\n**Attributes:**\n\n" lines)
              (dolist (attr attrs)
                (push (format "- `%s`\n" attr) lines)))
            ;; Sub-parts (BOM entries)
            (when parts
              (push "\n**Parts (BOM):**\n\n" lines)
              (push "| Part | Type | Multiplicity |\n|------|------|------|\n" lines)
              (dolist (p parts)
                (push (format "| %s | %s | %s |\n"
                              (plist-get p :name)
                              (plist-get p :type)
                              (or (plist-get p :multiplicity) "1")) lines)))
            (push "\n" lines))))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-interfaces (source-buf)
  "Render the Interface Table section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((part-defs (sysml2--puml-extract-part-defs))
          (lines nil)
          (found nil))
      (push (sysml2--report-md-heading 2 "Interface Table") lines)
      ;; For each part def, extract its ports
      (dolist (def part-defs)
        (let* ((name (plist-get def :name))
               (bounds (sysml2--puml-find-def-bounds "part def" name))
               (ports (when bounds
                        (sysml2--puml-extract-port-usages (car bounds) (cdr bounds)))))
          (when ports
            (setq found t)
            (push (format "### %s\n\n" name) lines)
            (push "| Port | Type | Conjugated | Direction |\n" lines)
            (push "|------|------|------------|----------|\n" lines)
            (dolist (p ports)
              (push (format "| %s | %s | %s | %s |\n"
                            (plist-get p :name)
                            (plist-get p :type)
                            (if (plist-get p :conjugated) "~" "")
                            (or (plist-get p :direction) "—")) lines))
            (push "\n" lines))))
      ;; Also check port defs at top level
      (let ((port-defs (sysml2--puml-extract-typed-defs "port def" "port")))
        (when port-defs
          (setq found t)
          (push "### Port Definitions\n\n" lines)
          (push "| Name | Attributes |\n|------|------------|\n" lines)
          (dolist (pd port-defs)
            (push (format "| %s | %s |\n"
                          (plist-get pd :name)
                          (if (plist-get pd :attributes)
                              (mapconcat #'identity (plist-get pd :attributes) ", ")
                            "—")) lines))
          (push "\n" lines)))
      (unless found
        (push "*No ports or interfaces found.*\n\n" lines))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-connections (source-buf)
  "Render the Connection Matrix section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((connections (sysml2--puml-extract-connections))
          (lines nil))
      (push (sysml2--report-md-heading 2 "Connection Matrix") lines)
      (if (null connections)
          (push "*No connections found.*\n\n" lines)
        (push "| Connection | Source | Target |\n" lines)
        (push "|------------|--------|--------|\n" lines)
        (dolist (c connections)
          (push (format "| %s | %s | %s |\n"
                        (plist-get c :name)
                        (plist-get c :source)
                        (plist-get c :target)) lines))
        (push "\n" lines))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-requirements (source-buf)
  "Render the Requirements Specification section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((req-defs (sysml2--puml-extract-requirements))
          (req-usages (sysml2--puml-extract-requirement-usages))
          (lines nil))
      (push (sysml2--report-md-heading 2 "Requirements Specification") lines)
      (if (and (null req-defs) (null req-usages))
          (push "*No requirements found.*\n\n" lines)
        ;; Requirement definitions
        (when req-defs
          (push "### Requirement Definitions\n\n" lines)
          (dolist (r req-defs)
            (let ((name (plist-get r :name))
                  (doc (plist-get r :doc))
                  (subject (plist-get r :subject)))
              (push (format "#### %s\n\n" name) lines)
              (when doc
                (push (format "> %s\n\n" doc) lines))
              (when subject
                (push (format "- **Subject:** %s\n" subject) lines))
              (push "\n" lines))))
        ;; Requirement usages (instances with hierarchy)
        (when req-usages
          (push "### Requirement Instances\n\n" lines)
          (push "| Requirement | Type | Description |\n" lines)
          (push "|-------------|------|-------------|\n" lines)
          (dolist (r req-usages)
            (let ((name (plist-get r :name))
                  (type (plist-get r :type))
                  (doc (plist-get r :doc))
                  (children (plist-get r :children)))
              (push (format "| **%s** | %s | %s |\n"
                            name
                            (or type "—")
                            (or doc "—")) lines)
              (dolist (child children)
                (push (format "| &nbsp;&nbsp;%s | %s | %s |\n"
                              (plist-get child :name)
                              (or (plist-get child :type) "—")
                              (or (plist-get child :doc) "—")) lines))))
          (push "\n" lines)))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-traceability (source-buf)
  "Render the Traceability Matrix section from SOURCE-BUF."
  (with-current-buffer source-buf
    (let* ((definitions (sysml2--report-collect-definitions))
           (satisfy-pairs (sysml2--report-collect-satisfy))
           (verify-pairs (sysml2--report-collect-verify))
           (req-names (or (cdr (assoc "requirement def" definitions)) '()))
           (satisfy-map (make-hash-table :test 'equal))
           (verify-map (make-hash-table :test 'equal))
           (lines nil))
      ;; Build lookup tables
      (dolist (pair satisfy-pairs)
        (puthash (car pair) (cons (cdr pair) (gethash (car pair) satisfy-map))
                 satisfy-map))
      (dolist (pair verify-pairs)
        (puthash (car pair) (cons (cdr pair) (gethash (car pair) verify-map))
                 verify-map))
      (push (sysml2--report-md-heading 2 "Traceability Matrix") lines)
      (if (null req-names)
          (push "*No requirement definitions found.*\n\n" lines)
        (push "| Requirement | Satisfied By | Verified By | Status |\n" lines)
        (push "|-------------|-------------|-------------|--------|\n" lines)
        (dolist (req-name req-names)
          (let* ((satisfied-by (gethash req-name satisfy-map))
                 (verified-by (gethash req-name verify-map))
                 (sat-str (if satisfied-by
                              (mapconcat #'identity (nreverse satisfied-by) ", ")
                            "—"))
                 (ver-str (if verified-by
                              (mapconcat (lambda (v) (or v "standalone"))
                                         (nreverse verified-by) ", ")
                            "—"))
                 (status (cond
                          ((and satisfied-by verified-by) "✓ Full")
                          (satisfied-by                   "△ No test")
                          (t                              "✗ Gap"))))
            (push (format "| %s | %s | %s | %s |\n"
                          req-name sat-str ver-str status) lines)))
        (push "\n" lines))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-states (source-buf)
  "Render the State Machines section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((definitions (sysml2--report-collect-definitions))
          (lines nil)
          (found nil))
      (push (sysml2--report-md-heading 2 "State Machines") lines)
      ;; Find state defs and extract their states/transitions
      (let ((state-def-names (cdr (assoc "state def" definitions))))
        (dolist (sname state-def-names)
          (let ((bounds (sysml2--puml-find-def-bounds "state def" sname)))
            (when bounds
              (setq found t)
              (let ((states (sysml2--puml-extract-states (car bounds) (cdr bounds)))
                    (transitions (sysml2--puml-extract-transitions (car bounds) (cdr bounds))))
                (push (format "### %s\n\n" sname) lines)
                (when states
                  (push "**States:**\n\n" lines)
                  (dolist (s states)
                    (push (format "- %s\n" (plist-get s :name)) lines))
                  (push "\n" lines))
                (when transitions
                  (push "**Transitions:**\n\n" lines)
                  (push "| Name | From | Trigger | To |\n" lines)
                  (push "|------|------|---------|----|\n" lines)
                  (dolist (tr transitions)
                    (push (format "| %s | %s | %s | %s |\n"
                                  (plist-get tr :name)
                                  (plist-get tr :from)
                                  (or (plist-get tr :trigger) "—")
                                  (plist-get tr :to)) lines))
                  (push "\n" lines)))))))
      (unless found
        (push "*No state machine definitions found.*\n\n" lines))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-extract-successions (beg end)
  "Extract all `first X then Y' successions in region BEG..END.
Unlike the plantuml extractor, this does not filter by brace depth,
making it suitable for successions nested inside action def bodies."
  (let ((results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bfirst[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]+then[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
              end t)
        (unless (sysml2--report-in-comment-or-string-p)
          (push (list :from (match-string-no-properties 1)
                      :to (match-string-no-properties 2))
                results))))
    (nreverse results)))

(defun sysml2--report-md-actions (source-buf)
  "Render the Action Flows section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((definitions (sysml2--report-collect-definitions))
          (lines nil)
          (found nil))
      (push (sysml2--report-md-heading 2 "Action Flows") lines)
      (let ((action-def-names (cdr (assoc "action def" definitions))))
        (dolist (aname action-def-names)
          (let ((bounds (sysml2--puml-find-def-bounds "action def" aname)))
            (when bounds
              (setq found t)
              (let ((actions (sysml2--puml-extract-actions (car bounds) (cdr bounds)))
                    (successions (sysml2--report-extract-successions (car bounds) (cdr bounds))))
                (push (format "### %s\n\n" aname) lines)
                (when actions
                  (push "**Actions:**\n\n" lines)
                  (push "| Action | Type |\n|--------|------|\n" lines)
                  (dolist (a actions)
                    (push (format "| %s | %s |\n"
                                  (plist-get a :name)
                                  (plist-get a :type)) lines))
                  (push "\n" lines))
                (when successions
                  (push "**Sequence:**\n\n" lines)
                  (dolist (s successions)
                    (push (format "- %s → %s\n"
                                  (plist-get s :from)
                                  (plist-get s :to)) lines))
                  (push "\n" lines)))))))
      (unless found
        (push "*No action definitions found.*\n\n" lines))
      (apply #'concat (nreverse lines)))))

(defun sysml2--report-md-enumerations (source-buf)
  "Render the Enumerations section from SOURCE-BUF."
  (require 'sysml2-plantuml)
  (with-current-buffer source-buf
    (let ((enum-defs (sysml2--puml-extract-enum-defs))
          (lines nil))
      (push (sysml2--report-md-heading 2 "Enumerations") lines)
      (if (null enum-defs)
          (push "*No enumerations found.*\n\n" lines)
        (dolist (def enum-defs)
          (let ((name (plist-get def :name))
                (super (plist-get def :super))
                (literals (plist-get def :attributes)))
            (push (format "### %s\n\n" name) lines)
            (when super
              (push (format "- **Specializes:** %s\n" super) lines))
            (if literals
                (progn
                  (push "\n**Literals:**\n\n" lines)
                  (dolist (lit literals)
                    (push (format "- `%s`\n" lit) lines)))
              (push "*No literals defined.*\n" lines))
            (push "\n" lines))))
      (apply #'concat (nreverse lines)))))

;; ---------------------------------------------------------------------------
;; Section dispatcher
;; ---------------------------------------------------------------------------

(defun sysml2--report-md-render-section (section-id source-buf)
  "Render SECTION-ID from SOURCE-BUF and return a Markdown string."
  (pcase section-id
    ("summary"      (sysml2--report-md-summary source-buf))
    ("part-decomp"  (sysml2--report-md-part-decomp source-buf))
    ("interfaces"   (sysml2--report-md-interfaces source-buf))
    ("connections"   (sysml2--report-md-connections source-buf))
    ("requirements" (sysml2--report-md-requirements source-buf))
    ("traceability" (sysml2--report-md-traceability source-buf))
    ("states"       (sysml2--report-md-states source-buf))
    ("actions"      (sysml2--report-md-actions source-buf))
    ("enumerations" (sysml2--report-md-enumerations source-buf))
    (_ (format "<!-- Unknown section: %s -->\n\n" section-id))))

;; ---------------------------------------------------------------------------
;; Interactive Markdown export
;; ---------------------------------------------------------------------------

;;;###autoload
(defun sysml2-report-export-markdown (output-file sections)
  "Export a model report as a Markdown file.
OUTPUT-FILE is the path to write.  SECTIONS is a list of section IDs
to include (see `sysml2--report-md-sections' for valid IDs).
When called interactively, prompts for sections and output file."
  (interactive
   (let* ((all-ids (mapcar #'car sysml2--report-md-sections))
          (all-labels (mapcar (lambda (s)
                                (format "%s (%s)" (cdr s) (car s)))
                              sysml2--report-md-sections))
          (chosen (completing-read-multiple
                   "Sections (comma-separated, RET for all): "
                   all-labels))
          (selected (if (null chosen)
                        all-ids
                      (mapcar (lambda (label)
                                (car (seq-find
                                      (lambda (s)
                                        (string= label
                                                 (format "%s (%s)" (cdr s) (car s))))
                                      sysml2--report-md-sections)))
                              chosen)))
          (default-name (concat (file-name-sans-extension
                                 (or (buffer-file-name)
                                     (buffer-name)))
                                "-report.md"))
          (out (read-file-name "Output file: " nil default-name nil
                               (file-name-nondirectory default-name))))
     (list out selected)))
  (let* ((source-buf (current-buffer))
         (file-name (or (buffer-file-name) (buffer-name)))
         (md (concat
              (sysml2--report-md-heading 1
                                         (format "SysML v2 Model Report — %s"
                                                 (file-name-nondirectory file-name)))
              (format "*Generated: %s*\n\n---\n\n"
                      (format-time-string "%Y-%m-%d %H:%M"))
              ;; Table of contents
              "## Table of Contents\n\n"
              (mapconcat
               (lambda (id)
                 (let ((title (cdr (assoc id sysml2--report-md-sections))))
                   (format "- [%s](#%s)" title
                           (replace-regexp-in-string
                            "[^a-z0-9 -]" ""
                            (replace-regexp-in-string
                             " " "-" (downcase title))))))
               sections "\n")
              "\n\n---\n\n"
              ;; Render each section
              (mapconcat
               (lambda (id)
                 (sysml2--report-md-render-section id source-buf))
               sections ""))))
    (with-temp-file output-file
      (insert md))
    (message "Report written to %s" output-file)
    (find-file-other-window output-file)))

;; ---------------------------------------------------------------------------
;; Pandoc export wrapper
;; ---------------------------------------------------------------------------

;;;###autoload
(defun sysml2-report-export (format)
  "Export the model report via Pandoc to FORMAT.
FORMAT is one of \"pdf\", \"html\", or \"docx\".
First generates a Markdown report in a temp file, then converts
it using Pandoc.  Requires Pandoc to be installed."
  (interactive
   (list (completing-read "Export format: " '("pdf" "html" "docx") nil t)))
  (let* ((pandoc (or sysml2-report-pandoc-executable
                     (executable-find "pandoc")))
         (base (file-name-sans-extension
                (or (buffer-file-name) (buffer-name))))
         (output-file (concat base "-report." format))
         (md-file (make-temp-file "sysml2-report-" nil ".md"))
         (all-ids (mapcar #'car sysml2--report-md-sections)))
    (unless pandoc
      (user-error "Pandoc not found; install it or set `sysml2-report-pandoc-executable'"))
    ;; Generate the Markdown first
    (sysml2-report-export-markdown md-file all-ids)
    ;; Kill the temp markdown buffer that export-markdown opened
    (when-let ((md-buf (get-file-buffer md-file)))
      (kill-buffer md-buf))
    ;; Convert with Pandoc
    (let ((exit-code
           (call-process pandoc nil "*SysML2 Pandoc*" nil
                         md-file "-o" output-file
                         "--standalone"
                         (format "--metadata=title:%s"
                                 (file-name-nondirectory
                                  (or (buffer-file-name) (buffer-name)))))))
      (delete-file md-file)
      (if (= exit-code 0)
          (progn
            (message "Report exported to %s" output-file)
            (when (string= format "html")
              (browse-url (concat "file://" (expand-file-name output-file)))))
        (pop-to-buffer "*SysML2 Pandoc*")
        (user-error "Pandoc conversion failed (exit code %d)" exit-code)))))

(provide 'sysml2-report)
;;; sysml2-report.el ends here
