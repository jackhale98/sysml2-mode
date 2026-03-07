;;; test-lang.el --- Language data integrity tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-lang.el: keyword completeness, correctness,
;; uniqueness, and regexp compilation.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'sysml2-lang)

;; --- No duplicate keywords ---

(ert-deftest sysml2-test-lang-no-duplicates ()
  "Test that no keyword appears in more than one category."
  (let ((all (append sysml2-definition-keywords
                     sysml2-usage-keywords
                     sysml2-structural-keywords
                     sysml2-behavioral-keywords
                     sysml2-relationship-keywords
                     sysml2-visibility-keywords
                     sysml2-modifier-keywords
                     sysml2-literal-keywords
                     sysml2-operator-keywords))
        (seen (make-hash-table :test 'equal))
        (dupes nil))
    (dolist (kw all)
      (if (gethash kw seen)
          (push kw dupes)
        (puthash kw t seen)))
    (should (null dupes))))

;; --- All definition keywords end with "def" ---

(ert-deftest sysml2-test-lang-def-keywords-end-with-def ()
  "Test that every definition keyword ends with `def'."
  (dolist (kw sysml2-definition-keywords)
    (should (string-suffix-p "def" kw))))

;; --- All regexp-opt constants compile ---

(ert-deftest sysml2-test-lang-regexps-compile ()
  "Test that all computed regexp constants compile without error."
  (dolist (sym '(sysml2-definition-keywords-regexp
                 sysml2-usage-keywords-regexp
                 sysml2-structural-keywords-regexp
                 sysml2-behavioral-keywords-regexp
                 sysml2-relationship-keywords-regexp
                 sysml2-visibility-keywords-regexp
                 sysml2-modifier-keywords-regexp
                 sysml2-literal-keywords-regexp
                 sysml2-operator-keywords-regexp
                 sysml2-all-keywords-regexp
                 sysml2-multi-word-keywords-regexp))
    (should (stringp (symbol-value sym)))
    (should (string-match-p "." (symbol-value sym)))))

;; --- All-keywords length consistency ---

(ert-deftest sysml2-test-lang-all-keywords-consistent ()
  "Test that `sysml2-all-keywords' length equals sum of category lengths."
  (let ((expected (+ (length sysml2-definition-keywords)
                     (length sysml2-usage-keywords)
                     (length sysml2-structural-keywords)
                     (length sysml2-behavioral-keywords)
                     (length sysml2-relationship-keywords)
                     (length sysml2-visibility-keywords)
                     (length sysml2-modifier-keywords)
                     (length sysml2-literal-keywords)
                     (length sysml2-operator-keywords))))
    (should (= (length sysml2-all-keywords) expected))))

;; --- BNF-correct multi-word keywords ---

(ert-deftest sysml2-test-lang-enum-def-not-enumeration-def ()
  "Test that `enum def' is used, not `enumeration def'."
  (should (member "enum def" sysml2-definition-keywords))
  (should-not (member "enumeration def" sysml2-definition-keywords)))

(ert-deftest sysml2-test-lang-flow-def-not-flow-connection-def ()
  "Test that `flow def' is used, not `flow connection def'."
  (should (member "flow def" sysml2-definition-keywords))
  (should-not (member "flow connection def" sysml2-definition-keywords)))

(ert-deftest sysml2-test-lang-analysis-def-not-analysis-case-def ()
  "Test that `analysis def' is used, not `analysis case def'."
  (should (member "analysis def" sysml2-definition-keywords))
  (should-not (member "analysis case def" sysml2-definition-keywords)))

(ert-deftest sysml2-test-lang-verification-def-not-verification-case-def ()
  "Test that `verification def' is used, not `verification case def'."
  (should (member "verification def" sysml2-definition-keywords))
  (should-not (member "verification case def" sysml2-definition-keywords)))

(ert-deftest sysml2-test-lang-no-succession-flow-connection-def ()
  "Test that `succession flow connection def' is removed."
  (should-not (member "succession flow connection def" sysml2-definition-keywords)))

;; --- BNF-correct usage keywords ---

(ert-deftest sysml2-test-lang-enum-usage ()
  "Test that `enum' is a usage keyword, not `enumeration'."
  (should (member "enum" sysml2-usage-keywords))
  (should-not (member "enumeration" sysml2-usage-keywords)))

(ert-deftest sysml2-test-lang-flow-usage ()
  "Test that `flow' is a usage keyword, not `flow connection'."
  (should (member "flow" sysml2-usage-keywords))
  (should-not (member "flow connection" sysml2-usage-keywords)))

(ert-deftest sysml2-test-lang-analysis-usage ()
  "Test that `analysis' is a usage keyword, not `analysis case'."
  (should (member "analysis" sysml2-usage-keywords))
  (should-not (member "analysis case" sysml2-usage-keywords)))

(ert-deftest sysml2-test-lang-verification-usage ()
  "Test that `verification' is a usage keyword, not `verification case'."
  (should (member "verification" sysml2-usage-keywords))
  (should-not (member "verification case" sysml2-usage-keywords)))

;; --- KerML definition keywords ---

(ert-deftest sysml2-test-lang-kerml-def-keywords ()
  "Test that KerML definition keywords are present."
  (dolist (kw '("assoc def" "behavior def" "class def" "connector def"
                "datatype def" "feature def" "function def" "interaction def"
                "metaclass def" "predicate def" "step def" "struct def"
                "type def"))
    (should (member kw sysml2-definition-keywords))))

;; --- KerML usage keywords ---

(ert-deftest sysml2-test-lang-kerml-usage-keywords ()
  "Test that KerML usage keywords are present."
  (dolist (kw '("assoc" "behavior" "class" "connector" "datatype"
                "feature" "function" "interaction" "metaclass"
                "predicate" "step" "struct" "type"))
    (should (member kw sysml2-usage-keywords))))

;; --- Multi-word keywords list consistency ---

(ert-deftest sysml2-test-lang-multi-word-keywords-have-spaces ()
  "Test that all multi-word keywords actually contain spaces."
  (dolist (kw sysml2-multi-word-keywords)
    (should (string-match-p " " kw))))

;; --- New behavioral keywords ---

(ert-deftest sysml2-test-lang-behavioral-additions ()
  "Test that new behavioral keywords are present."
  (dolist (kw '("after" "event" "message" "parallel" "terminate"
                "until" "when"))
    (should (member kw sysml2-behavioral-keywords))))

;; --- New modifier keywords ---

(ert-deftest sysml2-test-lang-modifier-additions ()
  "Test that new modifier keywords are present."
  (dolist (kw '("composite" "conjugate" "const" "disjoint" "portion" "var"))
    (should (member kw sysml2-modifier-keywords))))

;; --- New relationship keywords ---

(ert-deftest sysml2-test-lang-relationship-additions ()
  "Test that new relationship keywords are present."
  (dolist (kw '("by" "conjugation" "crosses" "differences" "disjoining"
                "featuring" "intersects" "inverting" "member" "multiplicity"
                "of" "redefinition" "specializes" "subclassifier" "subsets"
                "subtype" "typed" "unions"))
    (should (member kw sysml2-relationship-keywords))))

(provide 'test-lang)
;;; test-lang.el ends here
