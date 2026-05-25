;;; test-menu.el --- Tests for menu bar and which-key integration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Tests for `sysml2-mode-menu' and `sysml2-which-key-setup'.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'sysml2-mode)

(ert-deftest sysml2-menu-defined-on-keymap ()
  "`sysml2-mode-map' must carry a menu binding under [menu-bar sysml2]."
  (should (keymapp (lookup-key sysml2-mode-map [menu-bar sysml2]))))

(defun sysml2-test--menu-has-label-p (menu label)
  "Return non-nil if MENU contains an entry whose menu-item label is LABEL."
  (let ((found nil))
    (map-keymap
     (lambda (_key binding)
       (when (and (listp binding)
                  (eq (car binding) 'menu-item)
                  (stringp (cadr binding))
                  (string= (cadr binding) label))
         (setq found binding)))
     menu)
    found))

(ert-deftest sysml2-menu-has-diagram-submenu ()
  "Menu must expose a Diagrams submenu."
  (let ((menu (lookup-key sysml2-mode-map [menu-bar sysml2])))
    (should (keymapp menu))
    (should (sysml2-test--menu-has-label-p menu "Diagrams"))))

(ert-deftest sysml2-menu-has-analysis-submenu ()
  "Menu must expose an Analysis (CLI commands) submenu."
  (let ((menu (lookup-key sysml2-mode-map [menu-bar sysml2])))
    (should (keymapp menu))
    (should (sysml2-test--menu-has-label-p menu "Analysis"))))

(ert-deftest sysml2-menu-has-scaffold-submenu ()
  "Menu must expose a Scaffold submenu."
  (let ((menu (lookup-key sysml2-mode-map [menu-bar sysml2])))
    (should (sysml2-test--menu-has-label-p menu "Scaffold"))))

(ert-deftest sysml2-menu-has-format-entry ()
  "Menu must expose a top-level Format Buffer entry."
  (let ((menu (lookup-key sysml2-mode-map [menu-bar sysml2])))
    (should (sysml2-test--menu-has-label-p menu "Format Buffer"))))

(ert-deftest sysml2-menu-has-doctor-entry ()
  "Menu must expose a Doctor entry for health-checks."
  (let ((menu (lookup-key sysml2-mode-map [menu-bar sysml2])))
    (should (sysml2-test--menu-has-label-p menu "Doctor (Health Check)"))))

(ert-deftest sysml2-which-key-setup-defined ()
  "`sysml2-which-key-setup' must be defined (callable)."
  (should (fboundp 'sysml2-which-key-setup)))

(ert-deftest sysml2-which-key-setup-noop-without-which-key ()
  "Calling setup with which-key absent must not raise."
  (cl-letf (((symbol-function 'featurep)
             (lambda (feat &optional _sub)
               (not (eq feat 'which-key)))))
    (should-not (sysml2-which-key-setup))))

(provide 'test-menu)
;;; test-menu.el ends here
