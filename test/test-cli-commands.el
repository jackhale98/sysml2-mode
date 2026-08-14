;;; test-cli-commands.el --- Tests for sysml CLI command wrappers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for sysml2-cli-commands.el — command-line argument construction
;; for both the existing analysis commands and the new commands
;; (rollup, interfaces, allocation, diff, index).
;;
;; Tests focus on the args list produced (capture call-process), not on
;; actually invoking the sysml binary, so they run in pure batch.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'test-helper)
(require 'sysml2-cli-commands)

(defvar sysml2-test--cli-captured-args nil
  "Most recent argument list captured from `sysml2-cli--run'.")

(defmacro sysml2-test--with-captured-args (&rest body)
  "Execute BODY with `sysml2-cli--run' stubbed to capture its ARGS."
  (declare (indent 0) (debug t))
  `(cl-letf* ((sysml2-test--cli-captured-args nil)
              ((symbol-function 'sysml2-cli--check-executable)
               (lambda () nil))
              ((symbol-function 'sysml2-cli--run)
               (lambda (args &optional _title)
                 (setq sysml2-test--cli-captured-args args)
                 "")))
     ,@body
     sysml2-test--cli-captured-args))

;; -- Project flag propagation ---------------------------------------

(ert-deftest sysml2-cli-list-passes-include-flag ()
  "When a project root is detected, list passes `-I <root>'."
  (let* ((root "/tmp/sample-project/")
         (args
          (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) root))
                    ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                    ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
            (sysml2-test--with-captured-args (sysml2-cli-list)))))
    (should (member "-I" args))
    (should (member root args))))

(ert-deftest sysml2-cli-list-passes-stdlib-path ()
  "When library path is configured, list passes `--stdlib-path'."
  (let* ((lib "/tmp/sample-lib/")
         (args
          (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                    ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) lib))
                    ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
            (sysml2-test--with-captured-args (sysml2-cli-list)))))
    (should (member "--stdlib-path" args))
    (should (member lib args))))

(ert-deftest sysml2-cli-check-passes-project-flags ()
  "check propagates both -I and --stdlib-path when available."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) "/tmp/p/"))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) "/tmp/lib/"))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-check)))))
    (should (equal (car args) "check"))
    (should (member "-I" args))
    (should (member "/tmp/p/" args))
    (should (member "--stdlib-path" args))
    (should (member "/tmp/lib/" args))))

(ert-deftest sysml2-cli-stats-omits-flags-when-unavailable ()
  "stats renders the ModelStats view; no -I without a project."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-stats)))))
    (should (equal (cl-subseq args 0 2) '("view" "ModelStats")))
    (should-not (member "-I" args))
    (should-not (member "--stdlib-path" args))))

;; -- New commands ---------------------------------------------------

(ert-deftest sysml2-cli-rollup-defined ()
  "`sysml2-cli-rollup' must be an interactive command."
  (should (commandp 'sysml2-cli-rollup)))

(ert-deftest sysml2-cli-rollup-compute-args ()
  "rollup compute mode produces `rollup compute <file> --root R --attr A'."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args
             (sysml2-cli-rollup "compute" "Vehicle" "mass")))))
    (should (equal (cl-subseq args 0 2) '("rollup" "compute")))
    (should (member "/tmp/x.sysml" args))
    (should (member "--root" args))
    (should (member "Vehicle" args))
    (should (member "--attr" args))
    (should (member "mass" args))))

(ert-deftest sysml2-cli-interfaces-defined ()
  "`sysml2-cli-interfaces' must be an interactive command."
  (should (commandp 'sysml2-cli-interfaces)))

(ert-deftest sysml2-cli-interfaces-args ()
  "interfaces renders PortTable; unconnected mode runs check (W016)."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-interfaces)))))
    (should (equal (cl-subseq args 0 2) '("view" "PortTable")))
    (should (member "/tmp/x.sysml" args)))
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-interfaces t)))))
    (should (equal (car args) "check"))))

(ert-deftest sysml2-cli-view-args ()
  "view renders a named view; empty name lists views."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-view "FmeaWorksheet")))))
    (should (equal (cl-subseq args 0 2) '("view" "FmeaWorksheet")))
    (should (member "/tmp/x.sysml" args)))
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-view "")))))
    (should (equal (car args) "view"))
    (should (member "/tmp/x.sysml" args))))

(ert-deftest sysml2-cli-analyze-run-args ()
  "analyze-run passes -n and optional --method."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args
             (sysml2-cli-analyze-run "gapAnalysis" "monte-carlo")))))
    (should (equal (cl-subseq args 0 2) '("analyze" "run")))
    (should (member "-n" args))
    (should (member "gapAnalysis" args))
    (should (member "--method" args))
    (should (member "monte-carlo" args))))

(ert-deftest sysml2-cli-allocation-defined ()
  "`sysml2-cli-allocation' must be an interactive command."
  (should (commandp 'sysml2-cli-allocation)))

(ert-deftest sysml2-cli-allocation-args ()
  "allocation forwards file and --unallocated flag when requested."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/x.sysml")))
           (sysml2-test--with-captured-args (sysml2-cli-allocation t)))))
    (should (equal (car args) "allocation"))
    (should (member "/tmp/x.sysml" args))
    (should (member "--unallocated" args))))

(ert-deftest sysml2-cli-diff-defined ()
  "`sysml2-cli-diff' must be an interactive command."
  (should (commandp 'sysml2-cli-diff)))

(ert-deftest sysml2-cli-diff-args ()
  "diff forwards two file arguments."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args
             (sysml2-cli-diff "/tmp/a.sysml" "/tmp/b.sysml")))))
    (should (equal (car args) "diff"))
    (should (member "/tmp/a.sysml" args))
    (should (member "/tmp/b.sysml" args))))

(ert-deftest sysml2-cli-index-defined ()
  "`sysml2-cli-index' must be an interactive command."
  (should (commandp 'sysml2-cli-index)))

(ert-deftest sysml2-cli-index-args-stats ()
  "index --stats produces `index --stats'."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) "/tmp/p/"))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args (sysml2-cli-index t)))))
    (should (equal (car args) "index"))
    (should (member "--stats" args))))

(ert-deftest sysml2-cli-index-no-file-arg ()
  "index runs without a file argument (uses project root)."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) "/tmp/p/"))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args (sysml2-cli-index nil)))))
    (should-not (cl-find-if (lambda (s) (string-suffix-p ".sysml" s)) args))))

(provide 'test-cli-commands)
;;; test-cli-commands.el ends here
