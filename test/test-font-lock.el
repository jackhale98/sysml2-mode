;;; test-font-lock.el --- Font-lock tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-mode font-lock highlighting.
;; Tests all font-lock rule categories across fixture files.

;;; Code:

(require 'ert)
(require 'test-helper)

;; --- Multi-word definition keywords ---

(ert-deftest sysml2-test-font-lock-part-def-keyword ()
  "Test that `part def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "part def Vehicle {}" "part def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-action-def-keyword ()
  "Test that `action def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "action def Drive {}" "action def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-state-def-keyword ()
  "Test that `state def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "state def EngineStates {}" "state def")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- Definition names ---

(ert-deftest sysml2-test-font-lock-definition-name ()
  "Test that definition names get the definition-name face."
  (let ((face (sysml2-test--face-at-search
               "part def Vehicle { }" "Vehicle")))
    (should (memq face '(sysml2-definition-name-face)))))

;; --- Usage keywords ---

(ert-deftest sysml2-test-font-lock-usage-keyword ()
  "Test that usage keywords are highlighted."
  (let ((face (sysml2-test--face-at-search
               "    part engine : Engine;" "part")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- Structural keywords ---

(ert-deftest sysml2-test-font-lock-package-keyword ()
  "Test that `package' is highlighted as builtin."
  (let ((face (sysml2-test--face-at-search "package Foo {}" "package")))
    (should (memq face '(sysml2-builtin-face)))))

(ert-deftest sysml2-test-font-lock-import-keyword ()
  "Test that `import' is highlighted as builtin."
  (let ((face (sysml2-test--face-at-search "import ISQ::*;" "import")))
    (should (memq face '(sysml2-builtin-face)))))

;; --- Behavioral keywords ---

(ert-deftest sysml2-test-font-lock-behavioral-keyword ()
  "Test that behavioral keywords like `first' and `then' are highlighted."
  (let ((face (sysml2-test--face-at-search
               "first start then accelerate;" "first")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- Visibility keywords ---

(ert-deftest sysml2-test-font-lock-visibility ()
  "Test that visibility keywords are highlighted."
  (let ((face (sysml2-test--face-at-search "public part x;" "public")))
    (should (memq face '(sysml2-visibility-face)))))

;; --- Modifier keywords ---

(ert-deftest sysml2-test-font-lock-modifier ()
  "Test that modifier keywords are highlighted."
  (let ((face (sysml2-test--face-at-search "abstract part def Base {}" "abstract")))
    (should (memq face '(sysml2-modifier-face)))))

;; --- Literal keywords ---

(ert-deftest sysml2-test-font-lock-literal-true ()
  "Test that `true' is highlighted as literal."
  (let ((face (sysml2-test--face-at-search "attribute x = true;" "true")))
    (should (memq face '(sysml2-literal-face)))))

(ert-deftest sysml2-test-font-lock-literal-false ()
  "Test that `false' is highlighted as literal."
  (let ((face (sysml2-test--face-at-search "attribute x = false;" "false")))
    (should (memq face '(sysml2-literal-face)))))

;; --- Numeric literals ---

(ert-deftest sysml2-test-font-lock-numeric ()
  "Test that numeric literals are highlighted."
  (let ((face (sysml2-test--face-at-search "mass <= 2000" "2000")))
    (should (memq face '(sysml2-literal-face)))))

;; --- Short name identifiers ---

(ert-deftest sysml2-test-font-lock-short-name ()
  "Test that short name identifiers <R1> are highlighted."
  (let ((face (sysml2-test--face-at-search "part <R1> engine;" "R1")))
    (should (memq face '(sysml2-short-name-face)))))

;; --- Metadata annotations ---

(ert-deftest sysml2-test-font-lock-metadata ()
  "Test that @SysML qualified name is highlighted."
  (let ((face (sysml2-test--face-at-search "filter @SysML::PartUsage;" "SysML")))
    (should (memq face '(sysml2-package-face sysml2-operator-face)))))

;; --- Comments ---

(ert-deftest sysml2-test-font-lock-line-comment ()
  "Test that line comments are highlighted."
  (with-temp-buffer
    (insert "// This is a comment\npart def Foo {}")
    (sysml2-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    ;; The // delimiter gets font-lock-comment-delimiter-face,
    ;; the text gets font-lock-comment-face.  Both are valid.
    (let ((face (get-text-property (point) 'face)))
      (should (memq face '(font-lock-comment-face
                            font-lock-comment-delimiter-face))))))

(ert-deftest sysml2-test-font-lock-block-comment ()
  "Test that block comments are highlighted."
  (with-temp-buffer
    (insert "/* block comment */\npart def Foo {}")
    (sysml2-mode)
    (font-lock-ensure)
    (goto-char (point-min))
    (let ((face (get-text-property (point) 'face)))
      (should (memq face '(font-lock-comment-face
                            font-lock-comment-delimiter-face))))))

;; --- Package face in qualified names ---

(ert-deftest sysml2-test-font-lock-qualified-package ()
  "Test that package prefix in qualified names is highlighted."
  (let ((face (sysml2-test--face-at-search "ISQ::MassValue" "ISQ")))
    (should (memq face '(sysml2-package-face)))))

;; --- Fixture file loading ---

(ert-deftest sysml2-test-font-lock-fixture-loads ()
  "Test that the fixture file loads in sysml2-mode without errors."
  (let ((fixture (expand-file-name "simple-vehicle.sysml"
                                   sysml2-test-fixtures-dir)))
    (skip-unless (file-exists-p fixture))
    (with-temp-buffer
      (insert-file-contents fixture)
      (sysml2-mode)
      (font-lock-ensure)
      (should (eq major-mode 'sysml2-mode)))))

(ert-deftest sysml2-test-font-lock-kerml-loads ()
  "Test that the KerML fixture loads in kerml-mode without errors."
  (let ((fixture (expand-file-name "kerml-basic.kerml"
                                   sysml2-test-fixtures-dir)))
    (skip-unless (file-exists-p fixture))
    (with-temp-buffer
      (insert-file-contents fixture)
      (kerml-mode)
      (font-lock-ensure)
      (should (eq major-mode 'kerml-mode)))))

;; --- BNF-corrected keywords ---

(ert-deftest sysml2-test-font-lock-enum-def-keyword ()
  "Test that `enum def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "enum def Colors {}" "enum def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-flow-def-keyword ()
  "Test that `flow def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "flow def DataFlow {}" "flow def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-analysis-def-keyword ()
  "Test that `analysis def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "analysis def ThermalAnalysis {}" "analysis def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-verification-def-keyword ()
  "Test that `verification def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "verification def TestPlan {}" "verification def")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- KerML definition keywords ---

(ert-deftest sysml2-test-font-lock-class-def-keyword ()
  "Test that `class def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "class def MyClass {}" "class def")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-struct-def-keyword ()
  "Test that `struct def' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "struct def MyStruct {}" "struct def")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- Multi-word keyword priority ---

(ert-deftest sysml2-test-font-lock-part-in-part-def ()
  "Test that `part' in `part def' gets keyword face, not usage face."
  (let ((face (sysml2-test--face-at-search "part def Vehicle {}" "part def")))
    (should (memq face '(sysml2-keyword-face)))))

;; --- New behavioral keywords ---

(ert-deftest sysml2-test-font-lock-event-keyword ()
  "Test that `event' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "    event occurrence;" "event")))
    (should (memq face '(sysml2-keyword-face)))))

(ert-deftest sysml2-test-font-lock-parallel-keyword ()
  "Test that `parallel' is highlighted as a keyword."
  (let ((face (sysml2-test--face-at-search "    parallel {}" "parallel")))
    (should (memq face '(sysml2-keyword-face)))))

(provide 'test-font-lock)
;;; test-font-lock.el ends here
