;;; test-indent.el --- Indentation tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-mode indentation engine.
;; Tests all indentation cases from the specification.

;;; Code:

(require 'ert)
(require 'sysml2-mode)

(defun sysml2-test--indent-string (str)
  "Re-indent STR in sysml2-mode and return the result."
  (with-temp-buffer
    (sysml2-mode)
    (insert str)
    (indent-region (point-min) (point-max))
    (buffer-string)))

(defun sysml2-test--indent-line-at (str line-num)
  "Return the indentation of LINE-NUM (1-indexed) after indenting STR."
  (with-temp-buffer
    (sysml2-mode)
    (insert str)
    (indent-region (point-min) (point-max))
    (goto-char (point-min))
    (forward-line (1- line-num))
    (current-indentation)))

;; --- Case 1: Basic block indentation ---

(ert-deftest sysml2-test-indent-basic-block ()
  "Test basic block indentation with braces."
  (let ((result (sysml2-test--indent-string
                 "package Foo {\npart def Bar {\nattribute x;\n}\n}")))
    (should (string-match-p "^package Foo {" result))
    (should (string-match-p "^    part def Bar {" result))
    (should (string-match-p "^        attribute x;" result))))

;; --- Case 2: Nested blocks ---

(ert-deftest sysml2-test-indent-nested-blocks ()
  "Test nested block indentation."
  (should (= 0 (sysml2-test--indent-line-at
                 "part def Vehicle {\npart engine : Engine {\nport fuelIn;\n}\n}" 1)))
  (should (= 4 (sysml2-test--indent-line-at
                 "part def Vehicle {\npart engine : Engine {\nport fuelIn;\n}\n}" 2)))
  (should (= 8 (sysml2-test--indent-line-at
                 "part def Vehicle {\npart engine : Engine {\nport fuelIn;\n}\n}" 3)))
  (should (= 4 (sysml2-test--indent-line-at
                 "part def Vehicle {\npart engine : Engine {\nport fuelIn;\n}\n}" 4)))
  (should (= 0 (sysml2-test--indent-line-at
                 "part def Vehicle {\npart engine : Engine {\nport fuelIn;\n}\n}" 5))))

;; --- Case 3: Closing brace alignment ---

(ert-deftest sysml2-test-indent-closing-brace ()
  "Test that closing braces align with their opening line."
  (let ((result (sysml2-test--indent-string
                 "package Foo {\n    part def Bar {\n    }\n}")))
    (with-temp-buffer
      (insert result)
      (goto-char (point-min))
      ;; Line 3: closing brace of Bar should be at 4
      (forward-line 2)
      (should (= 4 (current-indentation)))
      ;; Line 4: closing brace of Foo should be at 0
      (forward-line 1)
      (should (= 0 (current-indentation))))))

;; --- Case 4: Import statements inside package ---

(ert-deftest sysml2-test-indent-imports ()
  "Test indentation of import statements inside package."
  (should (= 4 (sysml2-test--indent-line-at
                 "package Foo {\nimport ISQ::*;\nimport SI::*;\n}" 2)))
  (should (= 4 (sysml2-test--indent-line-at
                 "package Foo {\nimport ISQ::*;\nimport SI::*;\n}" 3))))

;; --- Case 5: Semicolon-terminated lines stay at same level ---

(ert-deftest sysml2-test-indent-semicolon-lines ()
  "Test that lines after semicolon-terminated lines stay at same level."
  (should (= 4 (sysml2-test--indent-line-at
                 "part def Sys {\npart a : A;\npart b : B;\n}" 2)))
  (should (= 4 (sysml2-test--indent-line-at
                 "part def Sys {\npart a : A;\npart b : B;\n}" 3))))

;; --- Case 6: Action succession ---

(ert-deftest sysml2-test-indent-action-succession ()
  "Test indentation of action definitions with succession."
  (should (= 4 (sysml2-test--indent-line-at
                 "action def Drive {\naction start : Start;\nfirst start then accel;\n}" 2)))
  (should (= 4 (sysml2-test--indent-line-at
                 "action def Drive {\naction start : Start;\nfirst start then accel;\n}" 3))))

;; --- Case 7: Empty block ---

(ert-deftest sysml2-test-indent-empty-block ()
  "Test indentation with empty blocks."
  (should (= 0 (sysml2-test--indent-line-at
                 "part def Empty {\n}" 2))))

;; --- Case 8: Top-level (no indent) ---

(ert-deftest sysml2-test-indent-top-level ()
  "Test that top-level declarations have no indentation."
  (should (= 0 (sysml2-test--indent-line-at
                 "part def A;\npart def B;\nimport Base::*;" 1)))
  (should (= 0 (sysml2-test--indent-line-at
                 "part def A;\npart def B;\nimport Base::*;" 2)))
  (should (= 0 (sysml2-test--indent-line-at
                 "part def A;\npart def B;\nimport Base::*;" 3))))

;; --- Case 9: Deep nesting ---

(ert-deftest sysml2-test-indent-deep-nesting ()
  "Test deep nesting (3+ levels)."
  (should (= 12 (sysml2-test--indent-line-at
                  "package A {\npackage B {\npart def C {\nattr x;\n}\n}\n}" 4))))

;; --- Case 10: Re-indentation preserves correct indentation ---

(ert-deftest sysml2-test-indent-re-indent ()
  "Test that re-indenting correctly-indented code is idempotent."
  (let* ((correct "package Foo {\n    part def Bar {\n        attribute x;\n    }\n}")
         (result (sysml2-test--indent-string correct)))
    (should (string= correct result))))

;; --- Case 11: Mis-indented code gets fixed ---

(ert-deftest sysml2-test-indent-fix-misindent ()
  "Test that mis-indented code gets corrected."
  (let ((result (sysml2-test--indent-string
                 "package Foo {\n  part def Bar {\n      attribute x;\n  }\n}")))
    (should (string-match-p "^    part def Bar {" result))
    (should (string-match-p "^        attribute x;" result))))

(provide 'test-indent)
;;; test-indent.el ends here
