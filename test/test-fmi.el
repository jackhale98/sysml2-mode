;;; test-fmi.el --- FMI integration tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-fmi.el: XML parsing, interface extraction,
;; Modelica generation, and interface validation.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
(require 'sysml2-fmi)

;; --- Helpers ---

(defvar sysml2-test--fmi-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Directory containing test fixtures.")

(defun sysml2-test--fmi-fixture-path (name)
  "Return absolute path to fixture NAME."
  (expand-file-name name sysml2-test--fmi-fixtures-dir))

(defun sysml2-test--fmi-with-fixture (name fn)
  "Load fixture NAME into a temp buffer in sysml2-mode and call FN."
  (with-temp-buffer
    (insert-file-contents (sysml2-test--fmi-fixture-path name))
    (sysml2-mode)
    (funcall fn)))

(defun sysml2-test--fmi-with-text (text fn)
  "Insert TEXT into a temp buffer in sysml2-mode, call FN."
  (with-temp-buffer
    (insert text)
    (sysml2-mode)
    (funcall fn)))

;; ===================================================================
;; XML Parsing Tests
;; ===================================================================

(ert-deftest sysml2-test-fmi-parse-model-description ()
  "Parse modelDescription.xml fixture, verify model name and version."
  (let ((data (sysml2--fmi-parse-model-description
               (sysml2-test--fmi-fixture-path "modelDescription.xml"))))
    (should (equal (plist-get data :fmi-version) "3.0"))
    (should (equal (plist-get data :model-name) "TestEngine"))
    (should (stringp (plist-get data :guid)))))

(ert-deftest sysml2-test-fmi-extract-variables ()
  "Verify 5 variables extracted with correct types and causality."
  (let* ((data (sysml2--fmi-parse-model-description
                (sysml2-test--fmi-fixture-path "modelDescription.xml")))
         (vars (plist-get data :variables)))
    (should (= (length vars) 5))
    ;; First variable: fuelIn
    (let ((v (car vars)))
      (should (equal (plist-get v :name) "fuelIn"))
      (should (equal (plist-get v :causality) "input")))))

(ert-deftest sysml2-test-fmi-extract-variables-types ()
  "Verify all FMI types handled (Float64, Int32, Boolean)."
  (let* ((data (sysml2--fmi-parse-model-description
                (sysml2-test--fmi-fixture-path "modelDescription.xml")))
         (vars (plist-get data :variables))
         (types (mapcar (lambda (v) (plist-get v :type)) vars)))
    (should (member "Float64" types))
    (should (member "Int32" types))
    (should (member "Boolean" types))))

(ert-deftest sysml2-test-fmi-extract-model-structure ()
  "Verify 2 outputs extracted from model structure."
  (let* ((data (sysml2--fmi-parse-model-description
                (sysml2-test--fmi-fixture-path "modelDescription.xml")))
         (structure (plist-get data :model-structure))
         (outputs (plist-get structure :outputs)))
    (should (= (length outputs) 2))))

(ert-deftest sysml2-test-fmi-inspector-buffer ()
  "Verify inspector buffer is created and populated."
  (let* ((data (sysml2--fmi-parse-model-description
                (sysml2-test--fmi-fixture-path "modelDescription.xml"))))
    (sysml2--fmi-display-inspector data "test.fmu")
    (should sysml2--fmi-inspector-buffer)
    (should (buffer-live-p sysml2--fmi-inspector-buffer))
    (with-current-buffer sysml2--fmi-inspector-buffer
      (should (string-match-p "FMU Inspector" (buffer-string)))
      (should (string-match-p "TestEngine" (buffer-string)))
      (should (string-match-p "3\\.0" (buffer-string)))
      (should (string-match-p "fuelIn" (buffer-string))))
    (kill-buffer sysml2--fmi-inspector-buffer)))

;; ===================================================================
;; Interface Extraction Tests
;; ===================================================================

(ert-deftest sysml2-test-fmi-extract-port-def-items ()
  "Extract items from FuelPort def (1 in item)."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((items (sysml2--fmi-extract-port-def-items "FuelPort")))
       (should (= (length items) 1))
       (let ((item (car items)))
         (should (equal (plist-get item :name) "fuelFlow"))
         (should (equal (plist-get item :direction) "in"))
         (should (equal (plist-get item :type) "Real")))))))

(ert-deftest sysml2-test-fmi-extract-part-interface ()
  "Extract full Engine interface (3 ports, expected flow items)."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((contract (sysml2--fmi-extract-part-interface "Engine")))
       ;; FuelPort: 1 item (fuelFlow)
       ;; DrivePort (conjugated): 2 items (torque, speed) with flipped dirs
       ;; IgnitionPort: 1 item (ignitionOn)
       (should (= (length contract) 4))
       ;; Check that all items have required keys
       (dolist (item contract)
         (should (plist-get item :name))
         (should (plist-get item :fmi-type))
         (should (plist-get item :causality)))))))

(ert-deftest sysml2-test-fmi-conjugation-handling ()
  "DrivePort on Engine is conjugated (~), directions should flip."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((contract (sysml2--fmi-extract-part-interface "Engine"))
            ;; DrivePort items come from the conjugated driveOut port
            (drive-items (seq-filter
                          (lambda (item)
                            (equal (plist-get item :source-port) "driveOut"))
                          contract)))
       ;; DrivePort has `out item torque` and `out item speed`
       ;; but Engine has `port driveOut : ~DrivePort` so they should be input
       (should (= (length drive-items) 2))
       (dolist (item drive-items)
         (should (equal (plist-get item :direction) "in"))
         (should (equal (plist-get item :causality) "input")))))))

(ert-deftest sysml2-test-fmi-type-mapping ()
  "Verify SysML Real maps to Float64, Integer to Int32."
  (should (equal (sysml2--fmi-map-type "Real") "Float64"))
  (should (equal (sysml2--fmi-map-type "Integer") "Int32"))
  (should (equal (sysml2--fmi-map-type "Boolean") "Boolean"))
  (should (equal (sysml2--fmi-map-type "String") "String"))
  ;; User override
  (let ((sysml2-fmi-type-mapping-alist '(("MassValue" . "Float64"))))
    (should (equal (sysml2--fmi-map-type "MassValue") "Float64")))
  ;; Unknown defaults to Float64
  (should (equal (sysml2--fmi-map-type "UnknownType") "Float64")))

(ert-deftest sysml2-test-fmi-extract-vehicle-fixture ()
  "Extract interface from Transmission in fmi-vehicle.sysml."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((contract (sysml2--fmi-extract-part-interface "Transmission")))
       ;; DrivePort: 2 items (torque, speed) as input
       (should (= (length contract) 2))
       (dolist (item contract)
         (should (equal (plist-get item :causality) "output")))))))

;; ===================================================================
;; Modelica Generation Tests
;; ===================================================================

(ert-deftest sysml2-test-fmi-generate-modelica-basic ()
  "Generate .mo from Engine, verify basic structure."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((mo (sysml2-fmi-generate-modelica "Engine")))
       (should (string-match-p "partial model Engine" mo))
       (should (string-match-p "end Engine;" mo))
       (should (string-match-p "equation" mo))))))

(ert-deftest sysml2-test-fmi-generate-modelica-connectors ()
  "Verify connector declarations in generated Modelica."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((mo (sysml2-fmi-generate-modelica "Engine")))
       ;; Should have input connectors for FuelPort items and conjugated DrivePort
       (should (string-match-p "Modelica\\.Blocks\\.Interfaces\\.Real" mo))
       (should (string-match-p "fuelFlow" mo))))))

(ert-deftest sysml2-test-fmi-generate-modelica-parameters ()
  "Verify parameters from SysML attributes."
  (sysml2-test--fmi-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((mo (sysml2-fmi-generate-modelica "Engine")))
       (should (string-match-p "parameter Real displacement" mo))
       (should (string-match-p "parameter Integer cylinders" mo))))))

(ert-deftest sysml2-test-fmi-generate-modelica-string ()
  "Verify full Modelica output string structure."
  (sysml2-test--fmi-with-text
   "port def TestPort {\n    in item val : Real;\n}\npart def TestPart {\n    port p : TestPort;\n    attribute x : Real;\n}"
   (lambda ()
     (let ((mo (sysml2-fmi-generate-modelica "TestPart")))
       (should (string-match-p "^partial model TestPart" mo))
       (should (string-match-p "RealInput val" mo))
       (should (string-match-p "parameter Real x" mo))
       (should (string-match-p "end TestPart;$" mo))))))

;; ===================================================================
;; Validation Tests
;; ===================================================================

(ert-deftest sysml2-test-fmi-validate-matching ()
  "Perfect match returns no mismatches."
  (sysml2-test--fmi-with-text
   "port def P1 {\n    in item fuelIn : Real;\n}\npart def E1 {\n    port p : P1;\n}"
   (lambda ()
     (let* ((fmu-vars (list (list :name "fuelIn" :type "Float64"
                                  :causality "input" :variability "continuous"
                                  :start "0.0")))
            (contract (sysml2--fmi-extract-part-interface "E1"))
            (comparison (sysml2--fmi-compare-interfaces fmu-vars contract)))
       (should (= (length (plist-get comparison :matches)) 1))
       (should (= (length (plist-get comparison :type-mismatches)) 0))
       (should (= (length (plist-get comparison :fmu-only)) 0))
       (should (= (length (plist-get comparison :sysml-only)) 0))))))

(ert-deftest sysml2-test-fmi-validate-missing-input ()
  "FMU has extra input not in SysML."
  (sysml2-test--fmi-with-text
   "port def P1 {\n    in item fuelIn : Real;\n}\npart def E1 {\n    port p : P1;\n}"
   (lambda ()
     (let* ((fmu-vars (list (list :name "fuelIn" :type "Float64"
                                  :causality "input" :variability "continuous"
                                  :start "0.0")
                            (list :name "extraInput" :type "Float64"
                                  :causality "input" :variability "continuous"
                                  :start "0.0")))
            (contract (sysml2--fmi-extract-part-interface "E1"))
            (comparison (sysml2--fmi-compare-interfaces fmu-vars contract)))
       (should (= (length (plist-get comparison :fmu-only)) 1))
       (should (equal (car (plist-get comparison :fmu-only)) "extraInput"))))))

(ert-deftest sysml2-test-fmi-validate-type-mismatch ()
  "Type disagreement is detected."
  (sysml2-test--fmi-with-text
   "port def P1 {\n    in item fuelIn : Integer;\n}\npart def E1 {\n    port p : P1;\n}"
   (lambda ()
     (let* ((fmu-vars (list (list :name "fuelIn" :type "Float64"
                                  :causality "input" :variability "continuous"
                                  :start "0.0")))
            (contract (sysml2--fmi-extract-part-interface "E1"))
            (comparison (sysml2--fmi-compare-interfaces fmu-vars contract)))
       (should (= (length (plist-get comparison :type-mismatches)) 1))
       (let ((mm (car (plist-get comparison :type-mismatches))))
         (should (equal (plist-get mm :fmu-type) "Float64"))
         (should (equal (plist-get mm :sysml-type) "Int32")))))))

(ert-deftest sysml2-test-fmi-validate-extra-port ()
  "SysML port not found in FMU."
  (sysml2-test--fmi-with-text
   "port def P1 {\n    in item fuelIn : Real;\n    out item extra : Real;\n}\npart def E1 {\n    port p : P1;\n}"
   (lambda ()
     (let* ((fmu-vars (list (list :name "fuelIn" :type "Float64"
                                  :causality "input" :variability "continuous"
                                  :start "0.0")))
            (contract (sysml2--fmi-extract-part-interface "E1"))
            (comparison (sysml2--fmi-compare-interfaces fmu-vars contract)))
       (should (= (length (plist-get comparison :sysml-only)) 1))
       (should (equal (car (plist-get comparison :sysml-only)) "extra"))))))

(provide 'test-fmi)
;;; test-fmi.el ends here
