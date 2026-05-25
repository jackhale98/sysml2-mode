;;; test-flymake-codes.el --- Flymake CLI code surfacing tests -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests that `sysml2--flymake-cli-only-codes' covers every CLI-only
;; check code currently emitted by sysml-cli, and excludes only the
;; codes that the in-process backends already cover.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'sysml2-flymake)

;; In-process backends in sysml2-flymake.el cover:
;;   - delimiter mismatches / syntax → E001 family
;;   - duplicate definitions          → E002
;;   - unused defs                    → W001
;;   - unsatisfied requirements       → W002
;;   - unverified requirements        → W003
;; Everything else (W004+) requires cross-file or semantic analysis
;; that only the CLI can do.

(defconst sysml2-test--in-process-codes
  '("E001" "E002" "W001" "W002" "W003")
  "Diagnostic codes already covered by in-process flymake checkers.")

(defconst sysml2-test--cli-codes
  '("W004" "W005" "W006" "W007" "W008"
    "W009" "W010" "W011" "W012" "W013" "W014" "W015" "W016")
  "All CLI-emitted diagnostic codes that should reach Flymake.")

(ert-deftest sysml2-flymake-cli-only-includes-all-new-codes ()
  "`sysml2--flymake-cli-only-codes' must include every new W009-W016."
  (dolist (code '("W009" "W010" "W011" "W012" "W013" "W014" "W015" "W016"))
    (should
     (member code sysml2--flymake-cli-only-codes))))

(ert-deftest sysml2-flymake-cli-only-excludes-in-process-codes ()
  "Codes already covered in-process must NOT appear in the CLI-only list,
to avoid duplicate diagnostics in the buffer."
  (dolist (code sysml2-test--in-process-codes)
    (should-not (member code sysml2--flymake-cli-only-codes))))

(ert-deftest sysml2-flymake-keep-cli-diagnostic-p-accepts-new-codes ()
  "Predicate `sysml2--flymake-keep-cli-diagnostic-p' must return non-nil
for new lint codes."
  (should (sysml2--flymake-keep-cli-diagnostic-p "W012"))
  (should (sysml2--flymake-keep-cli-diagnostic-p "W014"))
  (should (sysml2--flymake-keep-cli-diagnostic-p "W016")))

(ert-deftest sysml2-flymake-keep-cli-diagnostic-p-rejects-in-process ()
  "Predicate rejects codes already covered in-process."
  (should-not (sysml2--flymake-keep-cli-diagnostic-p "E001"))
  (should-not (sysml2--flymake-keep-cli-diagnostic-p "W001"))
  (should-not (sysml2--flymake-keep-cli-diagnostic-p "W003")))

(provide 'test-flymake-codes)
;;; test-flymake-codes.el ends here
