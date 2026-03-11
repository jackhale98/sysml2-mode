;;; sysml2-format.el --- SysML v2 source formatting via sysml CLI -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Source formatting for SysML v2 files using the `sysml fmt' command.
;; The formatter uses tree-sitter CST analysis for correct indentation
;; while preserving comments and string content.
;;
;; Provides:
;;   - `sysml2-format-buffer' — Format the current buffer in-place
;;   - `sysml2-format-region' — Format the selected region
;;   - `sysml2-format-on-save-mode' — Auto-format on save
;;
;; Requires `sysml' CLI (v0.3.0+) on exec-path.

;;; Code:

(require 'sysml2-vars)

;;; Public API:
;;
;; Functions:
;;   `sysml2-format-buffer'       -- Format the current buffer
;;   `sysml2-format-region'       -- Format the selected region
;;   `sysml2-format-diff'         -- Show formatting diff without applying
;;   `sysml2-format-on-save-mode' -- Minor mode to auto-format on save

(defcustom sysml2-format-indent-width nil
  "Indent width for the sysml formatter.
When nil, uses the formatter's default (4 spaces).
When set, passes `--indent-width' to `sysml fmt'."
  :type '(choice (const :tag "Default (4)" nil)
                 (integer :tag "Spaces"))
  :group 'sysml2)

;; --- Internal helpers ---

(defun sysml2-format--exe-name ()
  "Return the CLI executable name for formatting."
  (or sysml2-cli-executable "sysml"))

(defun sysml2-format--check-executable ()
  "Check that the sysml CLI is available.  Signal an error if not found."
  (unless (sysml2--find-executable (sysml2-format--exe-name))
    (user-error "Cannot find `%s' on exec-path.  Install from https://github.com/jackhale98/sysml-cli"
                (sysml2-format--exe-name))))

(defun sysml2-format--resolve-executable ()
  "Return the full path to the sysml CLI."
  (or (sysml2--find-executable (sysml2-format--exe-name))
      (sysml2--platform-exe-name (sysml2-format--exe-name))))

;; --- Commands ---

;;;###autoload
(defun sysml2-format-buffer ()
  "Format the current SysML v2 buffer using `sysml fmt'.
Preserves point position.  The buffer must be visiting a file."
  (interactive)
  (sysml2-format--check-executable)
  (let* ((file (or buffer-file-name
                    (user-error "Buffer is not visiting a file")))
         (exe (sysml2-format--resolve-executable))
         (args (list "fmt"))
         (original-point (point))
         (original-window-start (window-start)))
    ;; Save first so the formatter operates on the current content
    (save-buffer)
    (when sysml2-format-indent-width
      (setq args (append args (list "--indent-width"
                                    (number-to-string sysml2-format-indent-width)))))
    (setq args (append args (list file)))
    (let ((exit-code (apply #'call-process exe nil nil nil args)))
      (if (zerop exit-code)
          (progn
            (revert-buffer t t t)
            (goto-char (min original-point (point-max)))
            (set-window-start (selected-window)
                              (min original-window-start (point-max)))
            (message "Formatted %s" (file-name-nondirectory file)))
        (message "sysml fmt failed (exit %d)" exit-code)))))

;;;###autoload
(defun sysml2-format-region (beg end)
  "Format the SysML v2 code in the region BEG..END.
Writes the region to a temp file, formats it, and replaces the region."
  (interactive "r")
  (sysml2-format--check-executable)
  (let* ((exe (sysml2-format--resolve-executable))
         (tmp (make-temp-file "sysml2-fmt-" nil ".sysml"))
         (region-text (buffer-substring-no-properties beg end))
         (args (list "fmt")))
    (unwind-protect
        (progn
          (with-temp-file tmp
            (insert region-text))
          (when sysml2-format-indent-width
            (setq args (append args (list "--indent-width"
                                          (number-to-string sysml2-format-indent-width)))))
          (setq args (append args (list tmp)))
          (let ((exit-code (apply #'call-process exe nil nil nil args)))
            (if (zerop exit-code)
                (let ((formatted (with-temp-buffer
                                   (insert-file-contents tmp)
                                   (buffer-string))))
                  (unless (string= region-text formatted)
                    (delete-region beg end)
                    (goto-char beg)
                    (insert formatted))
                  (message "Region formatted"))
              (message "sysml fmt failed (exit %d)" exit-code))))
      (ignore-errors (delete-file tmp)))))

;;;###autoload
(defun sysml2-format-diff ()
  "Show a diff of what `sysml fmt' would change in the current buffer.
Does not modify the buffer."
  (interactive)
  (sysml2-format--check-executable)
  (let* ((file (or buffer-file-name
                    (user-error "Buffer is not visiting a file")))
         (exe (sysml2-format--resolve-executable))
         (args (list "fmt" "--diff")))
    (save-buffer)
    (when sysml2-format-indent-width
      (setq args (append args (list "--indent-width"
                                    (number-to-string sysml2-format-indent-width)))))
    (setq args (append args (list file)))
    (let ((output-buf (get-buffer-create "*SysML Format Diff*")))
      (with-current-buffer output-buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (apply #'call-process exe nil t nil args)))
      (with-current-buffer output-buf
        (if (= (buffer-size) 0)
            (progn
              (let ((inhibit-read-only t))
                (insert "No formatting changes needed.\n"))
              (message "Already formatted"))
          (diff-mode))
        (special-mode)
        (goto-char (point-min)))
      (display-buffer output-buf '((display-buffer-reuse-window
                                    display-buffer-below-selected)
                                   (window-height . 0.4))))))

;; --- Format on save ---

;;;###autoload
(define-minor-mode sysml2-format-on-save-mode
  "Minor mode to auto-format SysML v2 buffers on save.
When enabled, runs `sysml fmt' before each save."
  :lighter " FmtSysML"
  :group 'sysml2
  (if sysml2-format-on-save-mode
      (add-hook 'before-save-hook #'sysml2-format--before-save nil t)
    (remove-hook 'before-save-hook #'sysml2-format--before-save t)))

(defun sysml2-format--before-save ()
  "Format the buffer before save if the sysml CLI is available."
  (when (and (sysml2--find-executable (sysml2-format--exe-name))
             buffer-file-name)
    (let* ((exe (sysml2-format--resolve-executable))
           (tmp (make-temp-file "sysml2-fmt-" nil ".sysml"))
           (args (list "fmt")))
      (unwind-protect
          (progn
            (write-region (point-min) (point-max) tmp nil 'nomessage)
            (when sysml2-format-indent-width
              (setq args (append args (list "--indent-width"
                                            (number-to-string
                                             sysml2-format-indent-width)))))
            (setq args (append args (list tmp)))
            (when (zerop (apply #'call-process exe nil nil nil args))
              (let ((original-point (point)))
                (insert-file-contents tmp nil nil nil t)
                (goto-char (min original-point (point-max))))))
        (ignore-errors (delete-file tmp))))))

(provide 'sysml2-format)
;;; sysml2-format.el ends here
