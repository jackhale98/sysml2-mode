;;; sysml2-format.el --- SysML v2 source formatting -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
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

(provide 'sysml2-format)
;;; sysml2-format.el ends here
