;;; sysml2-flymake.el --- Flymake backend for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

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

;; --- Flymake backend ---

(defun sysml2--flymake-backend (report-fn &rest _args)
  "Flymake backend for SysML v2 syntax checking.
Calls REPORT-FN with collected diagnostics from all checks."
  (let ((diagnostics (append (sysml2--check-unmatched-delimiters)
                             (sysml2--check-unknown-keywords)
                             (sysml2--check-missing-semicolons))))
    (funcall report-fn diagnostics)))

;; --- Setup ---

(defun sysml2-flymake-setup ()
  "Set up the Flymake backend for the current SysML v2 buffer."
  (add-hook 'flymake-diagnostic-functions #'sysml2--flymake-backend nil t))

(provide 'sysml2-flymake)
;;; sysml2-flymake.el ends here
