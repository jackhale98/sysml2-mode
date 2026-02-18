;;; sysml2-indent.el --- Indentation engine for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Indentation engine for SysML v2 files.  Handles brace-matching,
;; continuation lines, and closing-brace alignment.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-indent-line' -- Indent the current line
;;   `sysml2-indent-region' -- Indent a region (optimized)

(require 'sysml2-lang)

(defun sysml2--in-comment-or-string-p ()
  "Return non-nil if point is inside a comment or string."
  (let ((state (syntax-ppss)))
    (or (nth 3 state) (nth 4 state))))

(defun sysml2--previous-non-blank-line-indent ()
  "Return the indentation and content info of the previous non-blank line.
Returns a plist with :indent, :ends-with-open-brace, :ends-with-open-paren,
:ends-with-semicolon, :ends-with-comma, :is-continuation."
  (save-excursion
    (forward-line -1)
    (while (and (not (bobp))
                (or (looking-at-p "^\\s-*$")
                    (looking-at-p "^\\s-*//")))
      (forward-line -1))
    (let* ((indent (current-indentation))
           (line-end (line-end-position))
           (trimmed-end
            (save-excursion
              (goto-char line-end)
              (skip-chars-backward " \t" (line-beginning-position))
              ;; Skip past trailing comments
              (let ((state (syntax-ppss)))
                (when (nth 4 state)
                  (goto-char (nth 8 state))
                  (skip-chars-backward " \t" (line-beginning-position))))
              (skip-chars-backward " \t" (line-beginning-position))
              (point)))
           (last-char (when (> trimmed-end (line-beginning-position))
                        (char-before trimmed-end))))
      (list :indent indent
            :ends-with-open-brace (eq last-char ?{)
            :ends-with-open-paren (eq last-char ?\()
            :ends-with-open-bracket (eq last-char ?\[)
            :ends-with-semicolon (eq last-char ?\;)
            :ends-with-comma (eq last-char ?,)))))

(defun sysml2--matching-brace-indent (open-char close-char)
  "Find the indentation of the line containing the matching OPEN-CHAR.
Point should be on a line starting with CLOSE-CHAR."
  (save-excursion
    (let ((depth 1))
      (while (and (> depth 0) (not (bobp)))
        (forward-line -1)
        (let ((line-start (line-beginning-position))
              (line-end (line-end-position)))
          (save-excursion
            (goto-char line-start)
            (while (< (point) line-end)
              (cond
               ((sysml2--in-comment-or-string-p)
                (forward-char 1))
               ((eq (char-after) close-char)
                (setq depth (1+ depth))
                (forward-char 1))
               ((eq (char-after) open-char)
                (setq depth (1- depth))
                (forward-char 1))
               (t (forward-char 1)))))))
      (current-indentation))))

(defun sysml2--find-matching-open-paren-column ()
  "Find the column after the matching open paren/bracket for alignment.
Returns nil if no unclosed paren is found."
  (save-excursion
    (condition-case nil
        (progn
          (backward-up-list 1)
          (1+ (current-column)))
      (scan-error nil))))

(defun sysml2-indent-line ()
  "Indent the current line as SysML v2 code."
  (interactive)
  (let ((target-indent (sysml2--calculate-indent))
        (cur-indent (current-indentation)))
    (when target-indent
      (if (= target-indent cur-indent)
          ;; If already correct, move point past indentation if in it
          (when (< (current-column) cur-indent)
            (back-to-indentation))
        (save-excursion
          (indent-line-to target-indent))
        (when (< (current-column) target-indent)
          (back-to-indentation))))))

(defun sysml2--calculate-indent ()
  "Calculate the proper indentation for the current line.
Returns the target indentation column."
  (save-excursion
    (beginning-of-line)
    (cond
     ;; At the very start of the buffer
     ((bobp) 0)

     ;; Inside string or block comment — don't change
     ((sysml2--in-comment-or-string-p) nil)

     ;; Line starts with closing brace: match the opening brace's line
     ((looking-at-p "^\\s-*}")
      (sysml2--matching-brace-indent ?{ ?}))

     ;; Line starts with closing paren: match opening paren's line
     ((looking-at-p "^\\s-*)")
      (sysml2--matching-brace-indent ?\( ?\)))

     ;; Line starts with closing bracket: match opening bracket's line
     ((looking-at-p "^\\s-*\\]")
      (sysml2--matching-brace-indent ?\[ ?\]))

     ;; Normal indentation based on previous line
     (t
      (let ((prev (sysml2--previous-non-blank-line-indent)))
        (cond
         ;; Previous line ends with {: indent
         ((plist-get prev :ends-with-open-brace)
          (+ (plist-get prev :indent) sysml2-indent-offset))

         ;; Previous line ends with ( or [: align to after the opener
         ((or (plist-get prev :ends-with-open-paren)
              (plist-get prev :ends-with-open-bracket))
          (or (sysml2--find-matching-open-paren-column)
              (+ (plist-get prev :indent) sysml2-indent-offset)))

         ;; Previous line ends with semicolon: same level
         ((plist-get prev :ends-with-semicolon)
          (plist-get prev :indent))

         ;; Previous line ends with comma (multi-line list): same level
         ((plist-get prev :ends-with-comma)
          (plist-get prev :indent))

         ;; Check if we're inside a block but previous line didn't end
         ;; with { or ; — this is a continuation line
         (t
          (let ((in-block (sysml2--in-block-p)))
            (if (and in-block
                     (not (plist-get prev :ends-with-semicolon)))
                ;; Continuation: indent relative to previous
                (+ (plist-get prev :indent) sysml2-indent-offset)
              ;; Default: same as previous
              (plist-get prev :indent))))))))))

(defun sysml2--in-block-p ()
  "Return non-nil if point is inside a brace-delimited block."
  (save-excursion
    (condition-case nil
        (progn
          (backward-up-list 1)
          (eq (char-after) ?{))
      (scan-error nil))))

(defun sysml2-indent-region (start end)
  "Indent each line in the region from START to END."
  (interactive "r")
  (save-excursion
    (goto-char start)
    (while (< (point) end)
      (unless (looking-at-p "^\\s-*$")
        (sysml2-indent-line))
      (forward-line 1))))

(provide 'sysml2-indent)
;;; sysml2-indent.el ends here
