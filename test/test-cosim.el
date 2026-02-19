;;; test-cosim.el --- Co-simulation tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-cosim.el: SSP generation, tool resolution,
;; results parsing, and requirement verification.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
(require 'sysml2-cosim)

;; --- Helpers ---

(defvar sysml2-test--cosim-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Directory containing test fixtures.")

(defun sysml2-test--cosim-fixture-path (name)
  "Return absolute path to fixture NAME."
  (expand-file-name name sysml2-test--cosim-fixtures-dir))

(defun sysml2-test--cosim-with-fixture (name fn)
  "Load fixture NAME into a temp buffer in sysml2-mode and call FN."
  (with-temp-buffer
    (insert-file-contents (sysml2-test--cosim-fixture-path name))
    (sysml2-mode)
    (funcall fn)))

(defun sysml2-test--cosim-with-text (text fn)
  "Insert TEXT into a temp buffer in sysml2-mode, call FN."
  (with-temp-buffer
    (insert text)
    (sysml2-mode)
    (funcall fn)))

;; ===================================================================
;; SSP Generation Tests
;; ===================================================================

(ert-deftest sysml2-test-cosim-extract-structure ()
  "Extract components and connections from FMI vehicle fixture."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((structure (sysml2--cosim-extract-ssp-structure))
            (components (plist-get structure :components))
            (connections (plist-get structure :connections)))
       ;; VehicleSystem has 2 parts: engine, transmission
       (should (>= (length components) 2))
       ;; 1 connection: engineToDrive
       (should (>= (length connections) 1))
       (let ((conn (car connections)))
         (should (equal (plist-get conn :name) "engineToDrive")))))))

(ert-deftest sysml2-test-cosim-generate-ssd-basic ()
  "Generate valid SSD XML from fixture."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((structure (sysml2--cosim-extract-ssp-structure))
            (xml (sysml2--cosim-generate-ssd-xml structure)))
       (should (string-match-p "<?xml version" xml))
       (should (string-match-p "SystemStructureDescription" xml))
       (should (string-match-p "ssd:System" xml))))))

(ert-deftest sysml2-test-cosim-ssd-components ()
  "Verify component names and source references in SSD."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((structure (sysml2--cosim-extract-ssp-structure))
            (xml (sysml2--cosim-generate-ssd-xml structure)))
       (should (string-match-p "name=\"engine\"" xml))
       (should (string-match-p "name=\"transmission\"" xml))
       (should (string-match-p "source=\"resources/" xml))))))

(ert-deftest sysml2-test-cosim-ssd-connections ()
  "Verify connection mappings in SSD."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((structure (sysml2--cosim-extract-ssp-structure))
            (xml (sysml2--cosim-generate-ssd-xml structure)))
       (should (string-match-p "startElement=\"engine\"" xml))
       (should (string-match-p "endElement=\"transmission\"" xml))
       (should (string-match-p "ssd:Connection" xml))))))

(ert-deftest sysml2-test-cosim-ssd-xml-wellformed ()
  "Generated SSD XML should parse as valid XML."
  (sysml2-test--cosim-with-text
   "part def Sys {\n    part a : PartA;\n    part b : PartB;\n    connection c connect a.out to b.in;\n}"
   (lambda ()
     (let* ((structure (sysml2--cosim-extract-ssp-structure))
            (xml (sysml2--cosim-generate-ssd-xml structure)))
       ;; Parse the XML — should not error
       (with-temp-buffer
         (insert xml)
         (let ((dom (libxml-parse-xml-region (point-min) (point-max))))
           (should dom)
           ;; libxml strips namespace prefixes, so tag is SystemStructureDescription
           (should (eq (car dom) 'SystemStructureDescription))))))))

;; ===================================================================
;; Tool Resolution Tests
;; ===================================================================

(ert-deftest sysml2-test-cosim-resolve-fmpy ()
  "Mock executable-find for FMPy resolution."
  (let ((sysml2-cosim-tool 'fmpy)
        (sysml2-fmi-fmpy-executable "/usr/bin/fmpy"))
    (let ((result (sysml2--cosim-resolve-tool)))
      (should (eq (car result) 'fmpy))
      (should (equal (cdr result) "/usr/bin/fmpy")))))

(ert-deftest sysml2-test-cosim-resolve-omsimulator ()
  "Mock path for OMSimulator resolution."
  (let ((sysml2-cosim-tool 'omsimulator)
        (sysml2-cosim-omsimulator-path "/usr/bin/OMSimulator"))
    (let ((result (sysml2--cosim-resolve-tool)))
      (should (eq (car result) 'omsimulator))
      (should (equal (cdr result) "/usr/bin/OMSimulator")))))

(ert-deftest sysml2-test-cosim-resolve-custom-path ()
  "Verify defcustom path override takes precedence."
  (let ((sysml2-cosim-tool 'fmpy)
        (sysml2-fmi-fmpy-executable "/custom/path/fmpy"))
    (let ((result (sysml2--cosim-resolve-tool)))
      (should (equal (cdr result) "/custom/path/fmpy")))))

;; ===================================================================
;; Results Parsing Tests
;; ===================================================================

(ert-deftest sysml2-test-cosim-parse-csv-basic ()
  "Parse sample CSV, verify headers and row count."
  (let ((data (sysml2--cosim-parse-csv
               (sysml2-test--cosim-fixture-path "sample-results.csv"))))
    (should (= (length (plist-get data :headers)) 5))
    (should (= (length (plist-get data :rows)) 6))))

(ert-deftest sysml2-test-cosim-parse-csv-headers ()
  "Verify variable names extracted from CSV headers."
  (let* ((data (sysml2--cosim-parse-csv
                (sysml2-test--cosim-fixture-path "sample-results.csv")))
         (headers (plist-get data :headers)))
    (should (member "time" headers))
    (should (member "fuelIn" headers))
    (should (member "torqueOut" headers))
    (should (member "speed" headers))))

(ert-deftest sysml2-test-cosim-parse-csv-numeric ()
  "Verify numeric conversion from CSV data."
  (let* ((data (sysml2--cosim-parse-csv
                (sysml2-test--cosim-fixture-path "sample-results.csv")))
         (rows (plist-get data :rows))
         (first-row (car rows)))
    ;; First row: 0.0,0.0,0.0,0.0,0
    (should (numberp (car first-row)))
    (should (= (car first-row) 0.0))))

(ert-deftest sysml2-test-cosim-results-buffer ()
  "Verify results buffer is created and populated."
  (let* ((data (sysml2--cosim-parse-csv
                (sysml2-test--cosim-fixture-path "sample-results.csv")))
         (buf (sysml2--cosim-display-results data "sample-results.csv")))
    (should (buffer-live-p buf))
    (with-current-buffer buf
      (should (string-match-p "Simulation Results" (buffer-string)))
      (should (string-match-p "torqueOut" (buffer-string)))
      (should (string-match-p "Rows: 6" (buffer-string))))
    (kill-buffer buf)))

;; ===================================================================
;; Verification Tests
;; ===================================================================

(ert-deftest sysml2-test-cosim-extract-constraint ()
  "Extract `speed <= 200' constraint from requirement."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let ((constraint (sysml2--cosim-extract-constraint-expression
                        "MaxSpeedReq")))
       (should constraint)
       (should (equal (plist-get constraint :signal) "speed"))
       (should (equal (plist-get constraint :op) "<="))
       (should (= (plist-get constraint :bound) 200))))))

(ert-deftest sysml2-test-cosim-check-bounds-pass ()
  "Signal within bounds returns PASS."
  (let ((data '(1.0 2.0 3.0 4.0 5.0)))
    (should (eq (sysml2--cosim-check-bounds data "<=" 10.0) 'pass))
    (should (eq (sysml2--cosim-check-bounds data ">=" 1.0) 'pass))
    (should (eq (sysml2--cosim-check-bounds data "<" 6.0) 'pass))))

(ert-deftest sysml2-test-cosim-check-bounds-fail ()
  "Signal exceeding bounds returns FAIL."
  (let ((data '(1.0 2.0 3.0 4.0 15.0)))
    (should (eq (sysml2--cosim-check-bounds data "<=" 10.0) 'fail))
    (should (eq (sysml2--cosim-check-bounds data "<" 10.0) 'fail))))

(ert-deftest sysml2-test-cosim-verify-dashboard ()
  "Full pipeline: reqs + results produces verification dashboard."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((csv-path (sysml2-test--cosim-fixture-path "sample-results.csv"))
            (results (sysml2-cosim-verify-requirements csv-path (current-buffer))))
       (should results)
       ;; MaxSpeedReq: speed <= 200, max speed in data is 25.5 → PASS
       (let ((speed-req (seq-find (lambda (r)
                                    (equal (plist-get r :requirement)
                                           "MaxSpeedReq"))
                                  results)))
         (should speed-req)
         (should (eq (plist-get speed-req :result) 'pass)))
       ;; MaxTorqueReq: torqueOut <= 500, max is 42.0 → PASS
       (let ((torque-req (seq-find (lambda (r)
                                     (equal (plist-get r :requirement)
                                            "MaxTorqueReq"))
                                   results)))
         (should torque-req)
         (should (eq (plist-get torque-req :result) 'pass)))
       ;; Clean up verification buffer
       (when sysml2--cosim-verification-buffer
         (kill-buffer sysml2--cosim-verification-buffer))))))

(ert-deftest sysml2-test-cosim-verify-manual-constraint ()
  "Complex constraint gets MANUAL status."
  (sysml2-test--cosim-with-fixture
   "fmi-vehicle.sysml"
   (lambda ()
     (let* ((csv-path (sysml2-test--cosim-fixture-path "sample-results.csv"))
            (results (sysml2-cosim-verify-requirements csv-path (current-buffer))))
       ;; ComplexReq has multi-term expression → MANUAL
       (let ((complex-req (seq-find (lambda (r)
                                      (equal (plist-get r :requirement)
                                             "ComplexReq"))
                                    results)))
         (should complex-req)
         (should (eq (plist-get complex-req :result) 'manual)))
       ;; Clean up
       (when sysml2--cosim-verification-buffer
         (kill-buffer sysml2--cosim-verification-buffer))))))

(provide 'test-cosim)
;;; test-cosim.el ends here
