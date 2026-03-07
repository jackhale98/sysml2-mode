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

(require 'sysml2-lang)

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

(provide 'sysml2-report)
;;; sysml2-report.el ends here
