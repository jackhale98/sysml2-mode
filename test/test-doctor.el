;;; test-doctor.el --- Tests for sysml2-doctor health-check -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for `sysml2-doctor', `sysml2-doctor-check', and supporting
;; predicates.  The doctor probes external tooling (sysml CLI, D2,
;; tree-sitter grammar, LSP server, PlantUML, Pandoc) and produces a
;; structured report.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'test-helper)
(require 'sysml2-doctor)

(ert-deftest sysml2-doctor-checks-defined ()
  "`sysml2-doctor--all-checks' must list checks for every key tool."
  (let ((labels (mapcar #'sysml2-doctor-check-label
                        (sysml2-doctor--all-checks))))
    (should (member "sysml CLI" labels))
    (should (member "D2 binary" labels))
    (should (member "Tree-sitter grammar" labels))
    (should (member "LSP server" labels))
    (should (member "PlantUML" labels))
    (should (member "Pandoc" labels))))

(ert-deftest sysml2-doctor-run-returns-results ()
  "`sysml2-doctor-run' returns a list of result plists."
  (let ((results (sysml2-doctor-run)))
    (should (listp results))
    (should (cl-every (lambda (r) (plist-member r :label)) results))
    (should (cl-every (lambda (r) (plist-member r :status)) results))))

(ert-deftest sysml2-doctor-status-is-ok-warn-missing ()
  "Each result :status must be one of (ok warn missing skipped)."
  (let ((results (sysml2-doctor-run)))
    (dolist (r results)
      (should (memq (plist-get r :status) '(ok warn missing skipped))))))

(ert-deftest sysml2-doctor-missing-when-exe-absent ()
  "A check for a non-existent executable reports `missing'."
  (cl-letf (((symbol-function 'sysml2--find-executable)
             (lambda (&rest _) nil)))
    (let* ((check (make-sysml2-doctor-check
                   :label "Bogus"
                   :probe (lambda () (sysml2--find-executable "bogus-bin"))
                   :severity 'warn))
           (result (sysml2-doctor--run-one check)))
      (should (eq (plist-get result :status) 'missing)))))

(ert-deftest sysml2-doctor-ok-when-exe-present ()
  "A check that finds its target reports `ok'."
  (let* ((check (make-sysml2-doctor-check
                 :label "AlwaysFound"
                 :probe (lambda () "/usr/bin/true")
                 :severity 'warn))
         (result (sysml2-doctor--run-one check)))
    (should (eq (plist-get result :status) 'ok))
    (should (equal (plist-get result :detail) "/usr/bin/true"))))

(ert-deftest sysml2-doctor-warn-severity-not-missing ()
  "A failed probe with :severity 'warn reports `missing'; this is symbolic."
  (let* ((check (make-sysml2-doctor-check
                 :label "Required"
                 :probe (lambda () nil)
                 :severity 'error))
         (result (sysml2-doctor--run-one check)))
    (should (eq (plist-get result :status) 'missing))
    (should (eq (plist-get result :severity) 'error))))

(ert-deftest sysml2-doctor-buffer-output-format ()
  "Calling `sysml2-doctor' must populate the doctor buffer."
  (let ((buf (sysml2-doctor)))
    (should (bufferp buf))
    (with-current-buffer buf
      (let ((contents (buffer-string)))
        (should (string-match-p "SysML2 Doctor" contents))
        (should (string-match-p "sysml CLI" contents))))))

(ert-deftest sysml2-doctor-interactive ()
  "`sysml2-doctor' must be an interactive command."
  (should (commandp 'sysml2-doctor)))

(provide 'test-doctor)
;;; test-doctor.el ends here
