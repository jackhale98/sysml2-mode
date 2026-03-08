;;; test-flymake.el --- Flymake backend tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-flymake.el: delimiter matching, unknown keywords,
;; and missing semicolons.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
;; Note: do NOT (require 'flymake) here — it hangs in batch mode
;; on Emacs 30.x.  The sysml2-flymake module uses declare-function
;; stubs so flymake need not be loaded for the checker functions.
(require 'sysml2-flymake)

;; --- Helpers ---

;; Provide lightweight stubs for batch mode to avoid loading flymake.el
;; (which hangs in Emacs 30.x batch).  We must use `fset' unconditionally
;; because `flymake-make-diagnostic' has an autoload entry — `fboundp'
;; returns t for autoloads, so a `defun' guarded by `fboundp' is skipped,
;; and the first real call then triggers the autoload (and the hang).
(fset 'flymake-make-diagnostic
      (lambda (buffer beg end type text &rest _)
        "Stub for batch testing — returns a simple plist."
        (list :buffer buffer :beg beg :end end :type type :text text)))

(fset 'flymake-diagnostic-text
      (lambda (diag)
        "Stub — extract text from a diagnostic plist."
        (plist-get diag :text)))

(defun sysml2-test--flymake-diagnostics (str)
  "Run the Flymake backend on STR and return collected diagnostics.
Uses the syntax table from `sysml2-mode' without activating the mode
itself, which avoids triggering flymake timers in batch."
  (with-temp-buffer
    (insert str)
    (set-syntax-table sysml2-mode-syntax-table)
    (let (result)
      (sysml2--flymake-backend (lambda (diags) (setq result diags)))
      result)))

(defun sysml2-test--diagnostic-messages (str)
  "Return list of diagnostic message strings for STR."
  (mapcar (lambda (d) (flymake-diagnostic-text d))
          (sysml2-test--flymake-diagnostics str)))

;; --- Valid code: no diagnostics ---

(ert-deftest sysml2-test-flymake-valid-code ()
  "Test that valid code produces no error/warning diagnostics.
Note: :note-level diagnostics (like unused definitions) are acceptable."
  (let ((diags (sysml2-test--flymake-diagnostics
                "package Foo {\n    part def Bar {\n        attribute x;\n    }\n}")))
    (should (not (cl-some (lambda (d)
                            (memq (plist-get d :type) '(:error :warning)))
                          diags)))))

;; --- Unmatched delimiters ---

(ert-deftest sysml2-test-flymake-unmatched-open-brace ()
  "Test detection of unmatched opening brace."
  (let ((diags (sysml2-test--flymake-diagnostics "package Foo {")))
    (should (= 1 (length diags)))
    (should (string-match-p "Unmatched.*{" (flymake-diagnostic-text (car diags))))))

(ert-deftest sysml2-test-flymake-unmatched-close-brace ()
  "Test detection of unmatched closing brace."
  (let ((diags (sysml2-test--flymake-diagnostics "}")))
    (should (= 1 (length diags)))
    (should (string-match-p "Unmatched.*}" (flymake-diagnostic-text (car diags))))))

(ert-deftest sysml2-test-flymake-balanced-delimiters ()
  "Test that balanced delimiters produce no error/warning diagnostics."
  (let ((diags (sysml2-test--flymake-diagnostics
                "part def Foo {\n    attribute x [0..1];\n}")))
    (should (not (cl-some (lambda (d)
                            (memq (plist-get d :type) '(:error :warning)))
                          diags)))))

;; --- Unknown definition keywords ---

(ert-deftest sysml2-test-flymake-unknown-def-keyword ()
  "Test detection of unknown definition keyword prefix."
  (let ((diags (sysml2-test--flymake-diagnostics "prat def Foo {}")))
    (should (cl-some (lambda (d)
                       (string-match-p "Unknown definition keyword.*prat def"
                                       (flymake-diagnostic-text d)))
                     diags))))

(ert-deftest sysml2-test-flymake-valid-def-keyword ()
  "Test that valid definition keywords produce no unknown-keyword diagnostic."
  (let ((msgs (sysml2-test--diagnostic-messages "part def Vehicle {}")))
    (should (not (cl-some (lambda (m) (string-match-p "Unknown definition" m))
                          msgs)))))

;; --- Missing semicolons ---

(ert-deftest sysml2-test-flymake-missing-semicolon ()
  "Test detection of missing semicolon on usage line."
  (let ((diags (sysml2-test--flymake-diagnostics
                 "part def Foo {\n    attribute x : Integer\n}")))
    (should (cl-some (lambda (d)
                       (string-match-p "Missing semicolon"
                                       (flymake-diagnostic-text d)))
                     diags))))

(ert-deftest sysml2-test-flymake-semicolon-present ()
  "Test that lines with semicolons produce no missing-semicolon diagnostic."
  (let ((msgs (sysml2-test--diagnostic-messages
               "part def Foo {\n    attribute x : Integer;\n}")))
    (should (not (cl-some (lambda (m) (string-match-p "Missing semicolon" m))
                          msgs)))))

(provide 'test-flymake)
;;; test-flymake.el ends here
