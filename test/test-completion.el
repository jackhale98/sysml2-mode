;;; test-completion.el --- Completion tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-mode completion-at-point functionality.

;;; Code:

(require 'ert)
(require 'sysml2-mode)

(defun sysml2-test--complete-at (str pos)
  "Get completion candidates at POS in STR in sysml2-mode.
Returns the list of candidates or nil."
  (with-temp-buffer
    (sysml2-mode)
    (insert str)
    (goto-char pos)
    (let ((result (sysml2-completion-at-point)))
      (when result
        (let ((start (nth 0 result))
              (end (nth 1 result))
              (table (nth 2 result)))
          (cond
           ((functionp table)
            (funcall table (buffer-substring start end) nil t))
           ((listp table)
            table)
           (t nil)))))))

;; --- Keyword completion at line start ---

(ert-deftest sysml2-test-completion-line-start ()
  "Test that keyword completion works at the beginning of a line."
  (let ((candidates (sysml2-test--complete-at "par" 4)))
    (should candidates)
    (should (member "part" candidates))
    (should (member "part def" candidates))))

;; --- Keyword completion inside block ---

(ert-deftest sysml2-test-completion-inside-block ()
  "Test completion inside a definition block."
  (let ((candidates (sysml2-test--complete-at
                     "part def Foo {\n    att" 22)))
    (should candidates)
    (should (member "attribute" candidates))))

;; --- Import completion ---

(ert-deftest sysml2-test-completion-after-import ()
  "Test completion after `import' keyword."
  (let ((candidates (sysml2-test--complete-at "import IS" 10)))
    (should candidates)
    (should (member "ISQ" candidates))))

;; --- No completion in comments ---

(ert-deftest sysml2-test-completion-no-comment ()
  "Test that completion returns nil inside comments."
  (let ((candidates (sysml2-test--complete-at "// part" 8)))
    (should-not candidates)))

;; --- No completion in strings ---

(ert-deftest sysml2-test-completion-no-string ()
  "Test that completion returns nil inside strings."
  (let ((candidates (sysml2-test--complete-at "\"part\"" 5)))
    (should-not candidates)))

;; --- Completion includes definition names for type position ---

(ert-deftest sysml2-test-completion-type-position ()
  "Test completion after `:' includes buffer definition names."
  (let ((candidates (sysml2-test--complete-at
                     "part def Vehicle {}\npart engine : " 35)))
    (should candidates)
    ;; Standard library packages should be included
    (should (member "ISQ" candidates))))

;; --- Completion context detection ---

(ert-deftest sysml2-test-completion-context-line-start ()
  "Test that line-start context is detected."
  (with-temp-buffer
    (sysml2-mode)
    (insert "    par")
    (goto-char (point-max))
    (should (eq (sysml2--completion-context) 'line-start))))

(ert-deftest sysml2-test-completion-context-after-import ()
  "Test that after-import context is detected."
  (with-temp-buffer
    (sysml2-mode)
    (insert "import ISQ")
    (goto-char (point-max))
    (should (eq (sysml2--completion-context) 'after-import))))

(ert-deftest sysml2-test-completion-context-after-hash ()
  "Test that after-hash context is detected."
  (with-temp-buffer
    (sysml2-mode)
    (insert "#Meta")
    (goto-char (point-max))
    (should (eq (sysml2--completion-context) 'after-hash))))

;; --- Buffer definition extraction ---

(ert-deftest sysml2-test-completion-buffer-defs ()
  "Test extraction of definition names from buffer."
  (with-temp-buffer
    (sysml2-mode)
    (insert "part def Vehicle {}\npart def Engine {}\naction def Drive {}")
    (let ((names (sysml2--buffer-definition-names)))
      (should (member "Vehicle" names))
      (should (member "Engine" names))
      (should (member "Drive" names)))))

(provide 'test-completion)
;;; test-completion.el ends here
