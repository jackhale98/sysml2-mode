;;; test-flymake.el --- Flymake backend tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-flymake.el: delimiter matching, unknown keywords,
;; and missing semicolons.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
(require 'sysml2-flymake)

;; --- Helpers ---

(defun sysml2-test--flymake-diagnostics (str)
  "Run the Flymake backend on STR and return collected diagnostics."
  (with-temp-buffer
    (insert str)
    (sysml2-mode)
    (let (result)
      (sysml2--flymake-backend (lambda (diags) (setq result diags)))
      result)))

(defun sysml2-test--diagnostic-messages (str)
  "Return list of diagnostic message strings for STR."
  (mapcar (lambda (d) (flymake-diagnostic-text d))
          (sysml2-test--flymake-diagnostics str)))

;; --- Valid code: no diagnostics ---

(ert-deftest sysml2-test-flymake-valid-code ()
  "Test that valid code produces no diagnostics."
  (should (null (sysml2-test--flymake-diagnostics
                 "package Foo {\n    part def Bar {\n        attribute x;\n    }\n}"))))

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
  "Test that balanced delimiters produce no diagnostics."
  (should (null (sysml2-test--flymake-diagnostics
                 "part def Foo {\n    attribute x [0..1];\n}"))))

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
