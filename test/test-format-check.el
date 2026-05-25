;;; test-format-check.el --- Tests for CLI-backed fmt-check -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for `sysml2-format-check-via-cli' and the
;; `sysml2-format-check-on-save' defcustom + save-hook integration.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'test-helper)
(require 'sysml2-format)

(defvar sysml2-test--format-captured-args nil)

(ert-deftest sysml2-format-check-on-save-defcustom-defined ()
  "`sysml2-format-check-on-save' must be a `defcustom'."
  (should (boundp 'sysml2-format-check-on-save))
  (should (get 'sysml2-format-check-on-save 'standard-value)))

(ert-deftest sysml2-format-check-via-cli-defined ()
  "`sysml2-format-check-via-cli' must be an interactive command."
  (should (commandp 'sysml2-format-check-via-cli)))

(ert-deftest sysml2-format-check-builds-args ()
  "Arguments must be `fmt -f json --check FILE'."
  (let ((args
         (cl-letf* ((sysml2-test--format-captured-args nil)
                    ((symbol-function 'sysml2-cli--check-executable)
                     (lambda () nil))
                    ((symbol-function 'sysml2-cli--run)
                     (lambda (a &optional _) (setq sysml2-test--format-captured-args a) ""))
                    ((symbol-function 'sysml2-cli--ensure-file)
                     (lambda () "/tmp/m.sysml")))
           (sysml2-format-check-via-cli)
           sysml2-test--format-captured-args)))
    (should (member "fmt" args))
    (should (member "--check" args))
    (should (member "-f" args))
    (should (member "json" args))
    (should (member "/tmp/m.sysml" args))))

(ert-deftest sysml2-format-check-clean-reports-ok ()
  "When the CLI returns `unchanged' for the file, message is ok."
  (cl-letf (((symbol-function 'sysml2-cli--check-executable) (lambda () nil))
            ((symbol-function 'sysml2-cli--run)
             (lambda (_a &optional _)
               "{\"command\":\"fmt\",\"files\":[{\"file\":\"/tmp/m.sysml\",\"action\":\"unchanged\",\"would_change\":false}]}"))
            ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
            ((symbol-function 'message) (lambda (fmt &rest args)
                                          (apply #'format fmt args))))
    (let ((result (sysml2-format-check-via-cli)))
      (should (string-match-p "formatted" result)))))

(ert-deftest sysml2-format-check-dirty-reports-would-format ()
  "When the CLI reports `would-format', the message must say so."
  (cl-letf (((symbol-function 'sysml2-cli--check-executable) (lambda () nil))
            ((symbol-function 'sysml2-cli--run)
             (lambda (_a &optional _)
               "{\"command\":\"fmt\",\"files\":[{\"file\":\"/tmp/m.sysml\",\"action\":\"would-format\",\"would_change\":true}]}"))
            ((symbol-function 'sysml2-cli--ensure-file) (lambda () "/tmp/m.sysml"))
            ((symbol-function 'message) (lambda (fmt &rest args)
                                          (apply #'format fmt args))))
    (let ((result (sysml2-format-check-via-cli)))
      (should (string-match-p "would change" result)))))

(provide 'test-format-check)
;;; test-format-check.el ends here
