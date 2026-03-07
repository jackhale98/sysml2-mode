;;; sysml2-snippets.el --- Yasnippet snippets for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Registers yasnippet snippets for SysML v2 common patterns.
;; Snippets are also available as files in snippets/sysml2-mode/.
;; Yasnippet is an optional dependency — this file does nothing if
;; yasnippet is not installed.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-snippets-initialize' -- Register snippet directory with yasnippet

(require 'sysml2-lang)

(declare-function yas-load-directory "yasnippet")
(declare-function yas--table-put-value "yasnippet")

(defconst sysml2--snippets-dir
  (expand-file-name "snippets"
                    (file-name-directory
                     (or load-file-name buffer-file-name
                         default-directory)))
  "Directory containing yasnippet snippet files for sysml2-mode.")

(defun sysml2-snippets-initialize ()
  "Register sysml2-mode snippets with yasnippet.
This adds the snippet directory to `yas-snippet-dirs' and loads it."
  (when (and (fboundp 'yas-load-directory)
             (file-directory-p sysml2--snippets-dir))
    (when (boundp 'yas-snippet-dirs)
      (add-to-list 'yas-snippet-dirs sysml2--snippets-dir))
    (yas-load-directory sysml2--snippets-dir)))

(with-eval-after-load 'yasnippet
  (sysml2-snippets-initialize))

(provide 'sysml2-snippets)
;;; sysml2-snippets.el ends here
