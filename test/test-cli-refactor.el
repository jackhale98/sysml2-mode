;;; test-cli-refactor.el --- Tests for CLI-backed refactor commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for `sysml2-cli-rename', `sysml2-cli-add', `sysml2-cli-remove'.
;; These wrap the corresponding CLI subcommands and consume their
;; `-f json' envelopes.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'test-helper)
(require 'sysml2-cli-commands)

(defvar sysml2-test--cli-captured-args nil)

(defmacro sysml2-test--with-captured-args (&rest body)
  "Stub sysml2-cli--run to capture ARGS and return canned output."
  (declare (indent 0) (debug t))
  `(cl-letf* ((sysml2-test--cli-captured-args nil)
              ((symbol-function 'sysml2-cli--check-executable)
               (lambda () nil))
              ((symbol-function 'sysml2-cli--run)
               (lambda (args &optional _title)
                 (setq sysml2-test--cli-captured-args args)
                 (sysml2-test--stub-json-output args))))
     ,@body
     sysml2-test--cli-captured-args))

(defun sysml2-test--stub-json-output (args)
  "Return canned JSON matching what the real sysml CLI would emit for ARGS."
  (cond
   ((member "rename" args)
    "{\"command\":\"rename\",\"from\":\"Engine\",\"to\":\"Motor\",\"dry_run\":true,\"project_wide\":false,\"files\":[{\"file\":\"/tmp/m.sysml\",\"edits\":2,\"diff\":\"--- a\\n+++ b\\n\"}],\"edits\":2}")
   ((member "remove" args)
    "{\"command\":\"remove\",\"file\":\"/tmp/m.sysml\",\"removed\":\"Engine\",\"dry_run\":true,\"bytes_removed\":20,\"diff\":\"--- a\\n+++ b\\n\"}")
   ((member "add" args)
    "{\"command\":\"add\",\"action\":\"dry-run\",\"file\":\"/tmp/m.sysml\",\"element\":{\"name\":\"Engine\",\"kind\":\"part-def\"},\"diff\":\"--- a\\n+++ b\\n\",\"inserted_text\":\"part def Engine;\"}")
   (t "")))

;; ── rename ────────────────────────────────────────────────────────

(ert-deftest sysml2-cli-rename-defined ()
  "`sysml2-cli-rename' must be an interactive command."
  (should (commandp 'sysml2-cli-rename)))

(ert-deftest sysml2-cli-rename-dry-run-args ()
  "Initial preview must include --dry-run."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
                   ((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli-rename--confirm) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args
             (sysml2-cli-rename "Engine" "Motor" nil)))))
    (should (member "rename" args))
    (should (member "Engine" args))
    (should (member "Motor" args))
    (should (member "--dry-run" args))
    (should (member "-f" args))
    (should (member "json" args))))

(ert-deftest sysml2-cli-rename-project-wide-flag ()
  "When PROJECT-WIDE is non-nil, --project must be in the args."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
                   ((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli-rename--confirm) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args
             (sysml2-cli-rename "Engine" "Motor" t)))))
    (should (member "--project" args))))

;; ── add ───────────────────────────────────────────────────────────

(ert-deftest sysml2-cli-add-defined ()
  "`sysml2-cli-add' must be an interactive command."
  (should (commandp 'sysml2-cli-add)))

(ert-deftest sysml2-cli-add-dry-run-args ()
  "`sysml2-cli-add' should build `add file kind name --dry-run -f json'."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
                   ((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli-add--confirm) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args
             (sysml2-cli-add "part-def" "Engine")))))
    (should (member "add" args))
    (should (member "part-def" args))
    (should (member "Engine" args))
    (should (member "/tmp/m.sysml" args))
    (should (member "--dry-run" args))
    (should (member "-f" args))
    (should (member "json" args))))

;; ── remove ────────────────────────────────────────────────────────

(ert-deftest sysml2-cli-remove-defined ()
  "`sysml2-cli-remove' must be an interactive command."
  (should (commandp 'sysml2-cli-remove)))

(ert-deftest sysml2-cli-remove-dry-run-args ()
  "`sysml2-cli-remove' should build `remove file name --dry-run -f json'."
  (let ((args
         (cl-letf (((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
                   ((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil))
                   ((symbol-function 'sysml2-cli-remove--confirm) (lambda (&rest _) nil)))
           (sysml2-test--with-captured-args
             (sysml2-cli-remove "Engine")))))
    (should (member "remove" args))
    (should (member "Engine" args))
    (should (member "/tmp/m.sysml" args))
    (should (member "--dry-run" args))))

;; ── JSON envelope parsing ─────────────────────────────────────────

(ert-deftest sysml2-cli-parse-rename-envelope-edits-count ()
  "Parser returns the edits count from a rename envelope."
  (let* ((json (sysml2-test--stub-json-output '("rename")))
         (parsed (sysml2-cli--parse-json json)))
    (should (equal (alist-get 'edits parsed) 2))
    (should (equal (alist-get 'command parsed) "rename"))))

(ert-deftest sysml2-cli-parse-remove-envelope-bytes-removed ()
  "Parser returns the bytes_removed field from a remove envelope."
  (let* ((json (sysml2-test--stub-json-output '("remove")))
         (parsed (sysml2-cli--parse-json json)))
    (should (equal (alist-get 'bytes_removed parsed) 20))))

(provide 'test-cli-refactor)
;;; test-cli-refactor.el ends here
