;;; test-repl.el --- Tests for sysml2 comint REPL -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for `sysml2-repl' inferior process integration.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'test-helper)
(require 'sysml2-repl)

(ert-deftest sysml2-repl-mode-defined ()
  "`sysml2-repl-mode' must be a defined major mode derived from comint."
  (should (fboundp 'sysml2-repl-mode))
  (should (provided-mode-derived-p 'sysml2-repl-mode 'comint-mode)))

(ert-deftest sysml2-repl-command-defined ()
  "`sysml2-repl' must be an interactive command."
  (should (commandp 'sysml2-repl)))

(ert-deftest sysml2-repl-prompt-regex-matches ()
  "Prompt regex must match `sysml> ' and `sysml:Vehicle> '."
  (should (string-match-p sysml2-repl-prompt-regexp "sysml> "))
  (should (string-match-p sysml2-repl-prompt-regexp "sysml:Vehicle> "))
  (should (string-match-p sysml2-repl-prompt-regexp "sysml:Some::Long::Name> ")))

(ert-deftest sysml2-repl-prompt-regex-does-not-match-text ()
  "Prompt regex must not match ordinary content lines."
  (should-not (string-match-p sysml2-repl-prompt-regexp "info: scanning current directory"))
  (should-not (string-match-p sysml2-repl-prompt-regexp "Type 'help' for commands")))

(ert-deftest sysml2-repl-buffer-name-format ()
  "`sysml2-repl-buffer-name' returns a stable comint buffer name."
  (should (equal (sysml2-repl-buffer-name) "*sysml repl*"))
  (should (equal (sysml2-repl-buffer-name "my") "*sysml repl<my>*")))

(ert-deftest sysml2-repl-build-args-no-files ()
  "Building args with no files produces just project flags (or nothing)."
  (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
            ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil)))
    (let ((args (sysml2-repl--build-args nil)))
      (should-not (member "" args))
      (should-not (cl-find-if (lambda (s) (string-suffix-p ".sysml" s)) args)))))

(ert-deftest sysml2-repl-build-args-with-file ()
  "Building args with a file appends the file path."
  (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) nil))
            ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) nil)))
    (let ((args (sysml2-repl--build-args (list "/tmp/m.sysml"))))
      (should (member "/tmp/m.sysml" args)))))

(ert-deftest sysml2-repl-build-args-includes-project-flags ()
  "Builds include and stdlib path flags when available."
  (cl-letf (((symbol-function 'sysml2-project-root) (lambda (&rest _) "/tmp/p/"))
            ((symbol-function 'sysml2-project-library-path) (lambda (&rest _) "/tmp/lib/")))
    (let ((args (sysml2-repl--build-args (list "/tmp/m.sysml"))))
      (should (member "-I" args))
      (should (member "/tmp/p/" args))
      (should (member "--stdlib-path" args))
      (should (member "/tmp/lib/" args)))))

(provide 'test-repl)
;;; test-repl.el ends here
