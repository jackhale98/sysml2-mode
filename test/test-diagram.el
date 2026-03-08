;;; test-diagram.el --- Diagram command tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-diagram.el.  Tests both native (SVG/D2) and
;; PlantUML backends.  PlantUML invocation is mocked via cl-letf
;; to verify command behavior without PlantUML installed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'sysml2-mode)
(require 'sysml2-diagram)
(require 'sysml2-svg)
(require 'sysml2-d2)

;; --- Resolution Tests ---

(ert-deftest sysml2-test-diagram-resolve-executable ()
  "Test correct plist returned for executable exec-mode."
  (let ((sysml2-plantuml-exec-mode 'executable)
        (sysml2-plantuml-executable-path "/usr/bin/plantuml"))
    (let ((resolved (sysml2--diagram-resolve-plantuml)))
      (should resolved)
      (should (eq (plist-get resolved :mode) 'executable))
      (should (equal (plist-get resolved :command) '("/usr/bin/plantuml"))))))

(ert-deftest sysml2-test-diagram-resolve-jar ()
  "Test correct plist returned for jar exec-mode."
  (let ((sysml2-plantuml-exec-mode 'jar)
        (sysml2-plantuml-jar-path nil))
    ;; With no jar path and no plantuml-jar-path, should return nil
    (should (null (sysml2--diagram-resolve-plantuml))))
  ;; With a valid-looking jar path (mock file-exists-p)
  (let ((sysml2-plantuml-exec-mode 'jar)
        (sysml2-plantuml-jar-path "/tmp/plantuml.jar"))
    (cl-letf (((symbol-function 'file-exists-p) (lambda (_f) t)))
      (let ((resolved (sysml2--diagram-resolve-plantuml)))
        (should resolved)
        (should (eq (plist-get resolved :mode) 'jar))
        (should (equal (plist-get resolved :command)
                       '("java" "-jar" "/tmp/plantuml.jar")))))))

(ert-deftest sysml2-test-diagram-resolve-nil ()
  "Test nil returned when no PlantUML is available."
  (let ((sysml2-plantuml-exec-mode 'executable)
        (sysml2-plantuml-executable-path nil))
    (cl-letf (((symbol-function 'executable-find) (lambda (_n) nil)))
      (should (null (sysml2--diagram-resolve-plantuml))))))

(ert-deftest sysml2-test-diagram-resolve-server ()
  "Test correct plist returned for server exec-mode."
  (let ((sysml2-plantuml-exec-mode 'server)
        (sysml2-plantuml-server-url "http://localhost:8080"))
    (let ((resolved (sysml2--diagram-resolve-plantuml)))
      (should resolved)
      (should (eq (plist-get resolved :mode) 'server))
      (should (equal (plist-get resolved :command) '("http://localhost:8080"))))))

;; --- Preview Tests (mocked invocation) ---

(ert-deftest sysml2-test-diagram-preview-generates-plantuml ()
  "Test that preview generates PlantUML when backend is plantuml."
  (let ((captured-puml nil)
        (sysml2-diagram-backend 'plantuml))
    (cl-letf (((symbol-function 'sysml2--diagram-invoke-plantuml)
               (lambda (puml _fmt _cb)
                 (setq captured-puml puml))))
      (with-temp-buffer
        (insert "part def Foo {}\npart def Bar :> Foo {}")
        (sysml2-mode)
        (sysml2-diagram-preview-buffer)))
    (should captured-puml)
    (should (string-match-p "@startuml" captured-puml))
    (should (string-match-p "class Foo <<block>>" captured-puml))))

(ert-deftest sysml2-test-diagram-preview-generates-svg ()
  "Test that native backend generates SVG for tree diagrams."
  (with-temp-buffer
    (insert "part def Foo {}\npart def Bar :> Foo {}")
    (sysml2-mode)
    (let* ((sysml2-diagram-backend 'native)
           (svg (sysml2-svg-generate 'tree nil)))
      (should svg)
      (should (string-match-p "<svg" svg))
      (should (string-match-p "Foo" svg))
      (should (string-match-p "Bar" svg)))))

(ert-deftest sysml2-test-diagram-preview-buffer-tree ()
  "Test that preview-buffer generates tree diagram with expected classes."
  (let ((captured-puml nil)
        (sysml2-diagram-backend 'plantuml))
    (cl-letf (((symbol-function 'sysml2--diagram-invoke-plantuml)
               (lambda (puml _fmt _cb)
                 (setq captured-puml puml))))
      (with-temp-buffer
        (insert "part def Engine :> PowerSource {}\npart def PowerSource {}")
        (sysml2-mode)
        (sysml2-diagram-preview-buffer)))
    (should (string-match-p "class Engine <<block>>" captured-puml))
    (should (string-match-p "PowerSource <|-- Engine" captured-puml))))

;; --- Export Tests ---

(ert-deftest sysml2-test-diagram-export-format-from-extension ()
  "Test that export derives format from file extension."
  (let ((captured-format nil)
        (sysml2-diagram-backend 'plantuml))
    (cl-letf (((symbol-function 'sysml2--diagram-invoke-plantuml)
               (lambda (_puml fmt _cb)
                 (setq captured-format fmt))))
      (with-temp-buffer
        (insert "part def X {}")
        (sysml2-mode)
        (sysml2-diagram-export "/tmp/test-output.svg")))
    (should (equal captured-format "svg"))))

;; --- Type Selection Test ---

(ert-deftest sysml2-test-diagram-type-selection ()
  "Test that explicit type argument routes to correct backend."
  ;; Test PlantUML backend
  (let ((captured-puml nil)
        (sysml2-diagram-backend 'plantuml))
    (cl-letf (((symbol-function 'sysml2--diagram-invoke-plantuml)
               (lambda (puml _fmt _cb)
                 (setq captured-puml puml))))
      (with-temp-buffer
        (insert "requirement def Req1 {\n    doc /* test */\n}\n")
        (sysml2-mode)
        (let ((sysml2-diagram-output-format "svg"))
          (sysml2-diagram-type 'requirement-tree))))
    (should (string-match-p "<<requirement>>" captured-puml)))
  ;; Test native backend (SVG for requirement-tree)
  (with-temp-buffer
    (insert "requirement def Req1 {\n    doc /* test */\n}\n")
    (sysml2-mode)
    (let* ((sysml2-diagram-backend 'native)
           (svg (sysml2-svg-generate 'requirement-tree nil)))
      (should (string-match-p "Req1" svg)))))

;; --- Open PlantUML Test ---

(ert-deftest sysml2-test-diagram-open-plantuml-buffer ()
  "Test that open-plantuml creates a buffer with @startuml content."
  (let ((sysml2-diagram-backend 'plantuml))
    (with-temp-buffer
      (insert "part def Foo {}\npart def Bar :> Foo {}")
      (sysml2-mode)
      (cl-letf (((symbol-function 'pop-to-buffer) #'ignore))
        (sysml2-diagram-open-plantuml)))
    (let ((puml-buf (get-buffer "*SysML2 PlantUML*")))
      (should puml-buf)
      (should (string-match-p "@startuml"
                              (with-current-buffer puml-buf
                                (buffer-string))))
      (kill-buffer puml-buf))))

(ert-deftest sysml2-test-diagram-d2-state-machine ()
  "Test that D2 state machine generation produces valid D2 source."
  (with-temp-buffer
    (insert "state def EngineStates {\n"
            "    state off;\n"
            "    state on;\n"
            "    transition initial then off;\n"
            "    transition start_up\n"
            "        first off\n"
            "        accept StartSignal\n"
            "        then on;\n"
            "}\n")
    (sysml2-mode)
    (let ((d2 (sysml2-d2-generate 'state-machine "EngineStates")))
      (should d2)
      (should (string-match-p "off" d2))
      (should (string-match-p "on" d2))
      (should (string-match-p "__start__" d2)))))

;; --- Initial State Extraction Tests ---

(ert-deftest sysml2-test-initial-state-entry-then ()
  "Test extraction of initial state from `entry; then STATE;' pattern."
  (with-temp-buffer
    (insert "state def EngineStates {\n"
            "    entry; then off;\n"
            "    state off;\n"
            "    state starting;\n"
            "    state running;\n"
            "}\n")
    (sysml2-mode)
    (let ((bounds (sysml2--model-find-def-bounds "state def" "EngineStates")))
      (should bounds)
      (should (equal (sysml2--model-extract-initial-state
                      (car bounds) (cdr bounds))
                     "off")))))

(ert-deftest sysml2-test-initial-state-entry-action ()
  "Test extraction of initial state from `entry action NAME; transition NAME then STATE;' pattern."
  (with-temp-buffer
    (insert "state def Controller {\n"
            "    entry action initial;\n"
            "    state off;\n"
            "    state on;\n"
            "    transition initial then off;\n"
            "}\n")
    (sysml2-mode)
    (let ((bounds (sysml2--model-find-def-bounds "state def" "Controller")))
      (should bounds)
      (should (equal (sysml2--model-extract-initial-state
                      (car bounds) (cdr bounds))
                     "off")))))

(ert-deftest sysml2-test-d2-state-machine-initial-state ()
  "Test that D2 state machine uses parsed initial state."
  (with-temp-buffer
    (insert "state def SM {\n"
            "    entry; then idle;\n"
            "    state idle;\n"
            "    state running;\n"
            "    transition start\n"
            "        first idle\n"
            "        then running;\n"
            "}\n")
    (sysml2-mode)
    (let ((d2 (sysml2-d2-generate 'state-machine "SM")))
      (should (string-match-p "__start__ -> idle" d2)))))

;; --- Calc Extraction Tests ---

(ert-deftest sysml2-test-calc-extraction-basic ()
  "Test extraction of calc defs with params and return."
  (with-temp-buffer
    (insert "calc def FuelConsumption {\n"
            "    in bestFuel : Real;\n"
            "    in idlingFuel : Real;\n"
            "    return dpv : Real;\n"
            "}\n")
    (sysml2-mode)
    (let ((calcs (sysml2--model-extract-calcs)))
      (should (= (length calcs) 1))
      (let ((c (car calcs)))
        (should (equal (plist-get c :name) "FuelConsumption"))
        (should (= (length (plist-get c :params)) 2))
        (should (equal (plist-get c :return-name) "dpv"))
        (should (equal (plist-get c :return-type) "Real"))))))

(ert-deftest sysml2-test-calc-extraction-annex-a ()
  "Test calc extraction against annex-a fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "test/fixtures/annex-a-simple-vehicle-model.sysml"
                       (or (locate-dominating-file default-directory "test")
                           default-directory)))
    (sysml2-mode)
    (let ((calcs (sysml2--model-extract-calcs)))
      ;; annex-a has 9 calc defs
      (should (>= (length calcs) 7))
      ;; Check first calc
      (let ((fc (seq-find (lambda (c) (equal (plist-get c :name) "FuelConsumption"))
                          calcs)))
        (should fc)
        (should (= (length (plist-get fc :params)) 3))))))

;; --- Scan Defs with Body Filter ---

(ert-deftest sysml2-test-scan-defs-require-body ()
  "Test that require-body filters out forward declarations."
  (with-temp-buffer
    (insert "state def VehicleStates;\n"
            "state def EngineStates {\n"
            "    state off;\n"
            "}\n")
    (sysml2-mode)
    (let ((all (sysml2--diagram-scan-defs "state def"))
          (with-body (sysml2--diagram-scan-defs "state def" t)))
      (should (= (length all) 2))
      (should (= (length with-body) 1))
      (should (equal (car with-body) "EngineStates")))))

(provide 'test-diagram)
;;; test-diagram.el ends here
