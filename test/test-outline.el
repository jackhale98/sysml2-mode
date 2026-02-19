;;; test-outline.el --- Tests for sysml2-outline.el -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for the SysML2 outline side panel.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
(require 'sysml2-outline)

;; --- Helpers ---

(defvar sysml2-test--outline-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Directory containing test fixtures.")

(defun sysml2-test--outline-with-text (text fn)
  "Insert TEXT into a temp buffer in sysml2-mode, call FN, return result."
  (with-temp-buffer
    (insert text)
    (sysml2-mode)
    (funcall fn)))

(defun sysml2-test--outline-with-fixture (name fn)
  "Load fixture NAME, activate sysml2-mode, call FN."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name sysml2-test--outline-fixtures-dir))
    (sysml2-mode)
    (funcall fn)))

;; --- Scan Tests ---

(ert-deftest sysml2-test-outline-scan-basic ()
  "Test scanning finds packages and definitions."
  (let ((entries (sysml2-test--outline-with-text
                  (concat "package Foo {\n"
                          "    part def Bar {}\n"
                          "    action def Baz {}\n"
                          "}")
                  #'sysml2--outline-scan)))
    (should (= (length entries) 3))
    (should (equal (plist-get (nth 0 entries) :name) "Foo"))
    (should (equal (plist-get (nth 0 entries) :type) "package"))
    (should (= (plist-get (nth 0 entries) :level) 0))
    (should (equal (plist-get (nth 1 entries) :name) "Bar"))
    (should (equal (plist-get (nth 1 entries) :type) "part def"))
    (should (= (plist-get (nth 1 entries) :level) 1))
    (should (equal (plist-get (nth 2 entries) :name) "Baz"))
    (should (equal (plist-get (nth 2 entries) :type) "action def"))
    (should (= (plist-get (nth 2 entries) :level) 1))))

(ert-deftest sysml2-test-outline-scan-nesting ()
  "Test that indent levels are computed correctly."
  (let ((entries (sysml2-test--outline-with-text
                  (concat "package A {\n"
                          "    package B {\n"
                          "        part def C {}\n"
                          "    }\n"
                          "}")
                  #'sysml2--outline-scan)))
    (should (= (length entries) 3))
    (should (= (plist-get (nth 0 entries) :level) 0))
    (should (= (plist-get (nth 1 entries) :level) 1))
    (should (= (plist-get (nth 2 entries) :level) 2))))

(ert-deftest sysml2-test-outline-scan-vehicle-fixture ()
  "Test scanning against simple-vehicle.sysml fixture."
  (let ((entries (sysml2-test--outline-with-fixture
                  "simple-vehicle.sysml"
                  #'sysml2--outline-scan)))
    ;; Should find multiple entries
    (should (> (length entries) 5))
    ;; First entry should be a top-level package or part def
    (should (= (plist-get (car entries) :level) 0))
    ;; Check that we find expected names
    (let ((names (mapcar (lambda (e) (plist-get e :name)) entries)))
      (should (member "Vehicle" names))
      (should (member "Engine" names)))))

(ert-deftest sysml2-test-outline-scan-annex-a ()
  "Test scanning against Annex A fixture."
  (let ((entries (sysml2-test--outline-with-fixture
                  "annex-a-simple-vehicle-model.sysml"
                  #'sysml2--outline-scan)))
    ;; Annex A has many definitions
    (should (> (length entries) 30))
    (let ((names (mapcar (lambda (e) (plist-get e :name)) entries)))
      ;; Top-level package
      (should (member "SimpleVehicleModel" names))
      ;; Part definitions
      (should (member "Vehicle" names))
      (should (member "Engine" names))
      ;; Port definitions
      (should (member "FuelPort" names))
      ;; Action definitions
      (should (member "ProvidePower" names))
      ;; Requirement definitions
      (should (member "MassRequirement" names)))))

(ert-deftest sysml2-test-outline-scan-skips-comments ()
  "Test that outline scan skips commented-out definitions."
  (let ((entries (sysml2-test--outline-with-text
                  (concat "part def Real {}\n"
                          "// part def Commented {}\n"
                          "/* part def BlockCommented {} */\n")
                  #'sysml2--outline-scan)))
    (should (= (length entries) 1))
    (should (equal (plist-get (car entries) :name) "Real"))))

;; --- Toggle / Render Tests ---

(ert-deftest sysml2-test-outline-toggle-creates-buffer ()
  "Test that toggle creates the outline buffer."
  (sysml2-test--outline-with-text
   "package Foo {\n    part def Bar {}\n}"
   (lambda ()
     ;; Kill any pre-existing outline buffer
     (when (get-buffer sysml2--outline-buffer-name)
       (kill-buffer sysml2--outline-buffer-name))
     ;; The side window requires a frame, but in batch mode we can
     ;; at least verify the render produces a buffer with content
     (let ((entries (sysml2--outline-scan)))
       (let ((buf (sysml2--outline-render entries (current-buffer))))
         (should (bufferp buf))
         (should (string= (buffer-name buf) sysml2--outline-buffer-name))
         (with-current-buffer buf
           (should (> (buffer-size) 0))
           (should (eq major-mode 'sysml2-outline-mode))
           ;; Verify content
           (goto-char (point-min))
           (should (search-forward "package" nil t))
           (should (search-forward "Foo" nil t))
           (should (search-forward "part def" nil t))
           (should (search-forward "Bar" nil t))
           ;; Verify text properties
           (goto-char (point-min))
           (should (get-text-property (point) 'sysml2-outline-marker)))
         (kill-buffer buf))))))

(ert-deftest sysml2-test-outline-navigation-marker ()
  "Test that outline entries have correct source position markers."
  (sysml2-test--outline-with-text
   (concat "package Top {\n"
           "    part def Inner {}\n"
           "}")
   (lambda ()
     (let* ((entries (sysml2--outline-scan))
            (buf (sysml2--outline-render entries (current-buffer))))
       (with-current-buffer buf
         ;; First entry (package Top) should point to position 1
         (goto-char (point-min))
         (let ((marker (get-text-property (point) 'sysml2-outline-marker)))
           (should marker)
           (should (= marker 1)))
         ;; Second entry (part def Inner)
         (forward-line 1)
         (let ((marker (get-text-property (point) 'sysml2-outline-marker)))
           (should marker)
           (should (> marker 1))))
       (kill-buffer buf)))))

(provide 'test-outline)
;;; test-outline.el ends here
