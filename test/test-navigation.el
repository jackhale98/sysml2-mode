;;; test-navigation.el --- Navigation tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-navigation.el: imenu, which-function,
;; beginning/end-of-defun.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'sysml2-navigation)

;; --- Imenu ---

(ert-deftest sysml2-test-nav-imenu-basic ()
  "Test that imenu creates index for a simple buffer."
  (sysml2-test--with-sysml-buffer
      (concat "package Foo {\n"
              "    part def Bar {}\n"
              "    action def Baz {}\n"
              "}")
    (let ((index (sysml2-imenu-create-index)))
      (should index)
      ;; Should have Packages category
      (let ((pkgs (assoc "Packages" index)))
        (should pkgs)
        (should (assoc "Foo" (cdr pkgs))))
      ;; Should have Definitions category
      (let ((defs (assoc "Definitions" index)))
        (should defs)))))

(ert-deftest sysml2-test-nav-imenu-finds-part-defs ()
  "Test that imenu finds part def entries."
  (sysml2-test--with-sysml-buffer
      "part def Vehicle {}\npart def Engine {}"
    (let ((index (sysml2-imenu-create-index)))
      (let ((defs (assoc "Definitions" index)))
        (should defs)
        (let ((parts (assoc "Parts" (cdr defs))))
          (should parts)
          (should (assoc "Vehicle" (cdr parts)))
          (should (assoc "Engine" (cdr parts))))))))

(ert-deftest sysml2-test-nav-imenu-finds-action-defs ()
  "Test that imenu finds action def entries."
  (sysml2-test--with-sysml-buffer
      "action def Drive {}\naction def Park {}"
    (let ((index (sysml2-imenu-create-index)))
      (let ((defs (assoc "Definitions" index)))
        (should defs)
        (let ((actions (assoc "Actions" (cdr defs))))
          (should actions)
          (should (assoc "Drive" (cdr actions))))))))

(ert-deftest sysml2-test-nav-imenu-finds-state-defs ()
  "Test that imenu finds state def entries."
  (sysml2-test--with-sysml-buffer
      "state def VehicleStates {}"
    (let ((index (sysml2-imenu-create-index)))
      (let ((defs (assoc "Definitions" index)))
        (should defs)
        (let ((states (assoc "States" (cdr defs))))
          (should states)
          (should (assoc "VehicleStates" (cdr states))))))))

(ert-deftest sysml2-test-nav-imenu-finds-requirement-defs ()
  "Test that imenu finds requirement def entries."
  (sysml2-test--with-sysml-buffer
      "requirement def MassReq {}"
    (let ((index (sysml2-imenu-create-index)))
      (let ((defs (assoc "Definitions" index)))
        (should defs)
        (let ((reqs (assoc "Requirements" (cdr defs))))
          (should reqs)
          (should (assoc "MassReq" (cdr reqs))))))))

(ert-deftest sysml2-test-nav-imenu-fixture ()
  "Test that imenu returns categories for vehicle fixture."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "simple-vehicle.sysml"
                                            sysml2-test-fixtures-dir))
    (sysml2-mode)
    (font-lock-ensure)
    (let ((index (sysml2-imenu-create-index)))
      (should index)
      ;; Should have Packages
      (should (assoc "Packages" index))
      ;; Should have Definitions
      (should (assoc "Definitions" index)))))

;; --- Which Function ---

(ert-deftest sysml2-test-nav-which-function ()
  "Test that which-function returns the enclosing definition name."
  (sysml2-test--with-sysml-buffer
      (concat "part def Vehicle {\n"
              "    attribute mass;\n"
              "}")
    (goto-char (point-min))
    (search-forward "mass")
    (should (equal (sysml2-which-function) "Vehicle"))))

(ert-deftest sysml2-test-nav-which-function-package ()
  "Test that which-function finds enclosing package."
  (sysml2-test--with-sysml-buffer
      (concat "package Foo {\n"
              "    import ISQ::*;\n"
              "    part def Bar {}\n"
              "}")
    (goto-char (point-min))
    (search-forward "import")
    (should (equal (sysml2-which-function) "Foo"))))

;; --- Beginning of Defun ---

(ert-deftest sysml2-test-nav-beginning-of-defun ()
  "Test that beginning-of-defun moves to the start of the current definition."
  (sysml2-test--with-sysml-buffer
      (concat "part def Vehicle {\n"
              "    attribute mass;\n"
              "}\n"
              "part def Engine {\n"
              "    attribute power;\n"
              "}")
    (goto-char (point-max))
    (sysml2-beginning-of-defun)
    (should (looking-at-p "part def Engine"))))

(ert-deftest sysml2-test-nav-beginning-of-defun-arg ()
  "Test that beginning-of-defun with ARG=2 goes back 2 definitions."
  (sysml2-test--with-sysml-buffer
      (concat "part def A {}\n"
              "part def B {}\n"
              "part def C {}\n")
    (goto-char (point-max))
    (sysml2-beginning-of-defun 2)
    (should (looking-at-p "part def B"))))

;; --- End of Defun ---

(ert-deftest sysml2-test-nav-end-of-defun ()
  "Test that end-of-defun moves past the closing brace."
  (sysml2-test--with-sysml-buffer
      (concat "part def Vehicle {\n"
              "    attribute mass;\n"
              "}\n"
              "part def Engine {}\n")
    (goto-char (point-min))
    (sysml2-end-of-defun)
    ;; Should be after the closing brace of Vehicle
    (should (looking-at-p "part def Engine"))))

(provide 'test-navigation)
;;; test-navigation.el ends here
