;;; test-helper.el --- Shared test utilities for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Shared utilities, macros, and fixture paths for all sysml2-mode test files.

;;; Code:

(require 'ert)
(require 'sysml2-mode)

(defvar sysml2-test-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Directory containing test fixtures.")

(defmacro sysml2-test--with-sysml-buffer (text &rest body)
  "Insert TEXT into a temp buffer, activate `sysml2-mode', execute BODY.
The buffer is fontified before BODY runs."
  (declare (indent 1) (debug t))
  `(with-temp-buffer
     (insert ,text)
     (sysml2-mode)
     (font-lock-ensure)
     ,@body))

(defun sysml2-test--fontify-string (str)
  "Fontify STR in a temporary sysml2-mode buffer and return it."
  (with-temp-buffer
    (insert str)
    (sysml2-mode)
    (font-lock-ensure)
    (buffer-string)))

(defun sysml2-test--face-at (str pos)
  "Return the face at POS in STR after fontification in sysml2-mode."
  (let ((fontified (sysml2-test--fontify-string str)))
    (get-text-property (1- pos) 'face fontified)))

(defun sysml2-test--face-at-search (str search-string)
  "Return the face at the start of SEARCH-STRING in STR after fontification."
  (let ((fontified (sysml2-test--fontify-string str)))
    (with-temp-buffer
      (insert fontified)
      (goto-char (point-min))
      (when (search-forward search-string nil t)
        (get-text-property (match-beginning 0) 'face)))))

(defun sysml2-test--with-fixture (name fn)
  "Load fixture NAME into a temp buffer in sysml2-mode and call FN."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name sysml2-test-fixtures-dir))
    (sysml2-mode)
    (funcall fn)))

(provide 'test-helper)
;;; test-helper.el ends here
