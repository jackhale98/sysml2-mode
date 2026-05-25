;;; test-transient.el --- Tests for sysml2 transient menus -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for transient.el menus defined in `sysml2-transient'.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'sysml2-transient)

(ert-deftest sysml2-transient-diagram-defined ()
  "`sysml2-transient-diagram' must be a defined transient prefix."
  (should (commandp 'sysml2-transient-diagram))
  (should (get 'sysml2-transient-diagram 'transient--prefix)))

(ert-deftest sysml2-transient-scaffold-defined ()
  "`sysml2-transient-scaffold' must be a defined transient prefix."
  (should (commandp 'sysml2-transient-scaffold))
  (should (get 'sysml2-transient-scaffold 'transient--prefix)))

(ert-deftest sysml2-transient-analyze-defined ()
  "`sysml2-transient-analyze' must be a defined transient prefix."
  (should (commandp 'sysml2-transient-analyze))
  (should (get 'sysml2-transient-analyze 'transient--prefix)))

(ert-deftest sysml2-transient-keymap-binding ()
  "`sysml2-mode-map' must bind C-c C-d RET to the diagram transient."
  (should (eq (lookup-key sysml2-mode-map (kbd "C-c C-d RET"))
              'sysml2-transient-diagram)))

(ert-deftest sysml2-transient-scaffold-bound ()
  "`sysml2-mode-map' must bind C-c m RET to the scaffold transient."
  (should (eq (lookup-key sysml2-mode-map (kbd "C-c m RET"))
              'sysml2-transient-scaffold)))

(ert-deftest sysml2-transient-analyze-bound ()
  "`sysml2-mode-map' must bind C-c C-t RET to the analyze transient."
  (should (eq (lookup-key sysml2-mode-map (kbd "C-c C-t RET"))
              'sysml2-transient-analyze)))

(provide 'test-transient)
;;; test-transient.el ends here
