;;; sysml2-format.el --- SysML v2 source formatting -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.4.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Source formatting for SysML v2 files using the built-in indentation
;; engine.  When tree-sitter is available, uses CST-aware indent rules
;; for accurate formatting.  Falls back to the regex-based indenter.
;;
;; No external tools required — all formatting runs in-process.
;;
;; Provides:
;;   - `sysml2-format-buffer'       — Re-indent the entire buffer
;;   - `sysml2-format-region'       — Re-indent the selected region
;;   - `sysml2-format-on-save-mode' — Auto-format on save

;;; Code:

(require 'sysml2-vars)

(declare-function sysml2-cli--ensure-file "sysml2-cli-commands")
(declare-function sysml2-cli--run "sysml2-cli-commands")
(declare-function sysml2-cli--parse-json "sysml2-cli-commands")
(declare-function sysml2-cli--check-executable "sysml2-cli-commands")
(declare-function sysml2-cli--with-project-flags "sysml2-cli-commands")

(defcustom sysml2-format-check-on-save nil
  "When non-nil, run `sysml fmt --check' on save and warn if not formatted.
This does NOT modify the buffer — it merely reports whether the CLI
formatter would change the file, like a CI gate.  Useful when you want
to be told about formatting drift without auto-applying changes.

To auto-apply CLI formatting on save instead, enable
`sysml2-format-on-save-mode' (which uses in-process tree-sitter indent
for speed)."
  :type 'boolean
  :group 'sysml2)

;;; Public API:
;;
;; Functions:
;;   `sysml2-format-buffer'       -- Format the current buffer
;;   `sysml2-format-region'       -- Format the selected region
;;   `sysml2-format-on-save-mode' -- Minor mode to auto-format on save

;; --- Commands ---

;;;###autoload
(defun sysml2-format-buffer ()
  "Format the current SysML v2 buffer by re-indenting all lines.
Uses tree-sitter indent rules when available, otherwise the
regex-based indentation engine.  Also cleans up trailing whitespace."
  (interactive)
  (let ((original-point (point))
        (original-window-start (window-start)))
    (indent-region (point-min) (point-max))
    (delete-trailing-whitespace)
    (goto-char (min original-point (point-max)))
    (set-window-start (selected-window)
                      (min original-window-start (point-max)))
    (message "Formatted buffer")))

;;;###autoload
(defun sysml2-format-region (beg end)
  "Format the SysML v2 code in the region BEG..END.
Re-indents all lines in the region."
  (interactive "r")
  (indent-region beg end)
  (message "Region formatted"))

;; --- Format on save ---

;;;###autoload
(define-minor-mode sysml2-format-on-save-mode
  "Minor mode to auto-format SysML v2 buffers on save.
When enabled, re-indents the buffer before each save."
  :lighter " FmtSysML"
  :group 'sysml2
  (if sysml2-format-on-save-mode
      (add-hook 'before-save-hook #'sysml2-format--before-save nil t)
    (remove-hook 'before-save-hook #'sysml2-format--before-save t)))

(defun sysml2-format--before-save ()
  "Re-indent the buffer before save."
  (indent-region (point-min) (point-max))
  (delete-trailing-whitespace))

;; --- CLI-backed format check ---------------------------------------

;;;###autoload
(defun sysml2-format-check-via-cli ()
  "Run `sysml fmt --check' on the current file and report drift.

Unlike `sysml2-format-buffer' (which re-indents in-process), this
delegates to the sysml CLI's authoritative formatter and reports
whether running it would change anything — without modifying the
file.  Useful as a CI / save-hook gate.

Returns the message string (used by tests)."
  (interactive)
  (require 'sysml2-cli-commands)
  (let* ((file (sysml2-cli--ensure-file))
         (args (sysml2-cli--with-project-flags
                (list "fmt" file)
                (list "--check" "-f" "json")))
         (output (sysml2-cli--run args nil))
         (parsed (sysml2-cli--parse-json output)))
    (cond
     ((null parsed)
      (message "sysml fmt: could not parse JSON output"))
     (t
      (let* ((files (alist-get 'files parsed))
             (dirty (cl-remove-if-not
                     (lambda (f) (eq (alist-get 'would_change f) t))
                     files)))
        (if dirty
            (message "%s would change formatting (sysml fmt -f json --check)"
                     (mapconcat
                      (lambda (f) (file-name-nondirectory (alist-get 'file f)))
                      dirty ", "))
          (message "%s already formatted" (file-name-nondirectory file))))))))

(defun sysml2-format--check-on-save ()
  "Save-hook helper that runs `sysml2-format-check-via-cli' when configured."
  (when sysml2-format-check-on-save
    (condition-case _
        (sysml2-format-check-via-cli)
      (error nil))))

;; Install the save-hook globally — it's a no-op unless the user has
;; flipped `sysml2-format-check-on-save'.
(add-hook 'after-save-hook #'sysml2-format--check-on-save)

(provide 'sysml2-format)
;;; sysml2-format.el ends here
