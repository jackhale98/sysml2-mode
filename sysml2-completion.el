;;; sysml2-completion.el --- Completion support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Completion-at-point-functions (CAPF) backend for SysML v2.
;; Provides context-aware completion based on cursor position.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-completion-at-point' -- CAPF backend for SysML v2

(require 'sysml2-lang)

(defun sysml2--completion-context ()
  "Determine the completion context at point.
Returns one of: `line-start', `after-colon', `after-specialization',
`after-redefinition', `after-import', `after-modifier', `after-hash',
`in-block', `general'."
  (save-excursion
    (let ((case-fold-search nil)
          (line-start (line-beginning-position)))
      (cond
       ;; Inside a comment or string
       ((nth 4 (syntax-ppss)) nil)
       ((nth 3 (syntax-ppss)) nil)

       ;; After # (metadata)
       ((looking-back "#\\([A-Za-z_]*\\)" line-start)
        'after-hash)

       ;; After import keyword
       ((looking-back "\\bimport\\s-+\\([A-Za-z_:.*]*\\)" line-start)
        'after-import)

       ;; After :>> (redefinition)
       ((looking-back ":>>\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-redefinition)

       ;; After :> (specialization)
       ((looking-back ":>\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-specialization)

       ;; After : (type position) — not :: or :> or :>>
       ((looking-back ":\\(?:[^:>]\\|^\\)\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-colon)

       ;; After in/out/inout modifier
       ((looking-back "\\b\\(?:in\\|out\\|inout\\)\\s-+\\([A-Za-z_]*\\)" line-start)
        'after-modifier)

       ;; Beginning of line (possibly after whitespace or visibility)
       ((looking-back "^\\s-*\\(?:public\\s-+\\|private\\s-+\\|protected\\s-+\\)?\\([A-Za-z_]*\\)" line-start)
        'line-start)

       ;; Default
       (t 'general)))))

(defun sysml2--buffer-definition-names ()
  "Extract all definition names from the current buffer.
Scans for patterns like `KEYWORD def NAME' and returns a list of NAME strings."
  (let ((names nil)
        (def-re (concat "\\b\\(?:part\\|action\\|state\\|port\\|connection"
                        "\\|attribute\\|item\\|requirement\\|constraint"
                        "\\|view\\|viewpoint\\|rendering\\|concern"
                        "\\|allocation\\|interface\\|enumeration"
                        "\\|occurrence\\|metadata\\|calc"
                        "\\|use case\\|analysis case\\|verification case"
                        "\\|flow connection\\)\\s-+def\\s-+"
                        "\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward def-re nil t)
        (unless (sysml2--in-comment-or-string-p)
          (push (match-string-no-properties 1) names))))
    (delete-dups (nreverse names))))

(defun sysml2--in-comment-or-string-p ()
  "Return non-nil if point is inside a comment or string."
  (let ((state (syntax-ppss)))
    (or (nth 3 state) (nth 4 state))))

(defun sysml2--completion-candidates (context)
  "Return completion candidates for CONTEXT."
  (pcase context
    ('line-start
     (append sysml2-definition-keywords
             sysml2-usage-keywords
             sysml2-structural-keywords
             sysml2-behavioral-keywords))

    ('after-import
     (append sysml2-standard-library-packages '("*")))

    ('after-colon
     (append (sysml2--buffer-definition-names)
             sysml2-standard-library-packages))

    ('after-specialization
     (append (sysml2--buffer-definition-names)
             sysml2-standard-library-packages))

    ('after-redefinition
     (sysml2--buffer-definition-names))

    ('after-modifier
     sysml2-usage-keywords)

    ('after-hash
     '("Metadata"))

    ('in-block
     (append sysml2-usage-keywords
             sysml2-behavioral-keywords
             sysml2-modifier-keywords))

    ('general
     sysml2-all-keywords)

    (_ nil)))

(defun sysml2-completion-at-point ()
  "Completion-at-point function for SysML v2 buffers.
Returns a completion table based on the context at point."
  (let ((context (sysml2--completion-context)))
    (when context
      (let* ((end (point))
             (start (save-excursion
                      (skip-chars-backward "A-Za-z0-9_:.*")
                      (point)))
             (candidates (sysml2--completion-candidates context)))
        (when candidates
          (list start end candidates
                :exclusive 'no
                :annotation-function
                (lambda (cand)
                  (cond
                   ((member cand sysml2-definition-keywords) " <def>")
                   ((member cand sysml2-usage-keywords) " <usage>")
                   ((member cand sysml2-structural-keywords) " <struct>")
                   ((member cand sysml2-behavioral-keywords) " <behav>")
                   ((member cand sysml2-standard-library-packages) " <lib>")
                   (t nil)))))))))

(provide 'sysml2-completion)
;;; sysml2-completion.el ends here
