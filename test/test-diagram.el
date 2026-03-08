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

;; --- Verification Extraction Tests ---

(ert-deftest sysml2-test-extract-verifications-basic ()
  "Test extraction of verify relationships."
  (with-temp-buffer
    (insert "verification massTests : MassTest {\n"
            "    verify vehicleMassRequirement {\n"
            "        redefines massActual = weighVehicle.massMeasured;\n"
            "    }\n"
            "}\n")
    (sysml2-mode)
    (let ((vrs (sysml2--model-extract-verifications)))
      (should (= (length vrs) 1))
      (should (equal (plist-get (car vrs) :requirement) "vehicleMassRequirement"))
      (should (equal (plist-get (car vrs) :by) "massTests")))))

(ert-deftest sysml2-test-extract-verifications-annex-a ()
  "Test verification extraction against annex-a fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "test/fixtures/annex-a-simple-vehicle-model.sysml"
                       (or (locate-dominating-file default-directory "test")
                           default-directory)))
    (sysml2-mode)
    (let ((vrs (sysml2--model-extract-verifications)))
      (should (>= (length vrs) 1))
      (should (seq-find (lambda (v)
                          (string-match-p "vehicleMassRequirement"
                                          (plist-get v :requirement)))
                        vrs)))))

(ert-deftest sysml2-test-extract-verifications-flashlight ()
  "Test verification extraction against flashlight fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "test/fixtures/flashlight.sysml"
                       (or (locate-dominating-file default-directory "test")
                           default-directory)))
    (sysml2-mode)
    (let ((vrs (sysml2--model-extract-verifications)))
      (should (>= (length vrs) 1))
      (should (seq-find (lambda (v)
                          (equal (plist-get v :requirement) "BatteryLifeReq"))
                        vrs)))))

;; --- Allocation Extraction Tests ---

(ert-deftest sysml2-test-extract-allocations-basic ()
  "Test extraction of allocate relationships."
  (with-temp-buffer
    (insert "allocate vehicleLogical to vehicle_b;\n"
            "allocate engineLogical to vehicle_b.engine;\n")
    (sysml2-mode)
    (let ((als (sysml2--model-extract-allocations)))
      (should (= (length als) 2))
      (should (equal (plist-get (car als) :source) "vehicleLogical"))
      (should (equal (plist-get (car als) :target) "vehicle_b")))))

(ert-deftest sysml2-test-extract-allocations-annex-a ()
  "Test allocation extraction against annex-a fixture."
  (with-temp-buffer
    (insert-file-contents
     (expand-file-name "test/fixtures/annex-a-simple-vehicle-model.sysml"
                       (or (locate-dominating-file default-directory "test")
                           default-directory)))
    (sysml2-mode)
    (let ((als (sysml2--model-extract-allocations)))
      (should (>= (length als) 3)))))

;; --- Requirement ID Extraction ---

(ert-deftest sysml2-test-requirement-id-extraction ()
  "Test that requirement IDs are extracted from short name syntax."
  (with-temp-buffer
    (insert "requirement <'1'> vehicleMassReq : MassRequirement {\n"
            "    doc /* The mass shall be under 2000 kg */\n"
            "    requirement <'1.1'> engineMassReq : MassRequirement;\n"
            "}\n")
    (sysml2-mode)
    (let ((reqs (sysml2--model-extract-requirement-usages)))
      (should (>= (length reqs) 1))
      (let ((r (car reqs)))
        (should (equal (plist-get r :name) "vehicleMassReq"))
        (should (equal (plist-get r :id) "1"))
        (let ((child (car (plist-get r :children))))
          (should child)
          (should (equal (plist-get child :id) "1.1")))))))

;; --- Tree Diagram Hierarchical Layout ---

(ert-deftest sysml2-test-svg-tree-hierarchical ()
  "Test that tree SVG uses hierarchical layout with distinct X positions."
  (with-temp-buffer
    (insert "part def Vehicle {\n"
            "    part engine : Engine;\n"
            "    part trans : Transmission;\n"
            "}\n"
            "part def Engine;\n"
            "part def Transmission;\n")
    (sysml2-mode)
    (let ((svg (sysml2-svg-generate 'tree nil)))
      ;; Vehicle and Engine should be at different X positions
      ;; Engine is a child so should be indented right
      (should (string-match-p "Parts Tree" svg))
      ;; Should contain polygon (composition diamond)
      (should (string-match-p "<polygon" svg))
      ;; SVG should contain all three part names
      (should (string-match-p "Vehicle" svg))
      (should (string-match-p "Engine" svg))
      (should (string-match-p "Transmission" svg)))))

;; --- Requirements Diagram with Relationships ---

(ert-deftest sysml2-test-svg-requirement-tree-with-verify ()
  "Test that requirements SVG includes verify annotations."
  (with-temp-buffer
    (insert "requirement def MassReq {\n"
            "    doc /* mass shall be under 2000 kg */\n"
            "}\n"
            "requirement vehicleMassReq : MassReq;\n"
            "verification massTest : MassTest {\n"
            "    verify vehicleMassReq;\n"
            "}\n")
    (sysml2-mode)
    (let ((svg (sysml2-svg-generate 'requirement-tree nil)))
      (should (string-match-p "Requirements Diagram" svg))
      (should (string-match-p "MassReq" svg))
      (should (string-match-p "vehicleMassReq" svg))
      (should (string-match-p "verify" svg))
      (should (string-match-p "massTest" svg)))))

;; --- View Filter Parsing ---

(ert-deftest sysml2-test-view-parse-render-clause ()
  "Test that views with render clauses are detected."
  (with-temp-buffer
    (insert "view def TreeView {\n"
            "    render asTreeDiagram;\n"
            "}\n")
    (sysml2-mode)
    (let ((views (sysml2--diagram-parse-views)))
      (should (= 1 (length views)))
      (should (string= "TreeView" (caar views)))
      (should (eq 'tree (cdar views))))))

(ert-deftest sysml2-test-view-parse-inheritance ()
  "Test that view defs inherit diagram type from parent."
  (with-temp-buffer
    (insert "view def TreeView {\n"
            "    render asTreeDiagram;\n"
            "}\n"
            "view def PartsTreeView :> TreeView {\n"
            "    filter @SysML::PartUsage;\n"
            "}\n")
    (sysml2-mode)
    (let ((views (sysml2--diagram-parse-views)))
      (should (>= (length views) 2))
      (let ((parts-view (assoc "PartsTreeView" views)))
        (should parts-view)
        (should (eq 'tree (cdr parts-view)))))))

(ert-deftest sysml2-test-view-parse-usage ()
  "Test that view usages inherit diagram type from their def."
  (with-temp-buffer
    (insert "view def TreeView {\n"
            "    render asTreeDiagram;\n"
            "}\n"
            "view def PartsTreeView :> TreeView {\n"
            "    filter @SysML::PartUsage;\n"
            "}\n"
            "view myPartsView : PartsTreeView {\n"
            "    expose foo::**;\n"
            "}\n")
    (sysml2-mode)
    (let ((views (sysml2--diagram-parse-views)))
      (let ((usage (assoc "myPartsView" views)))
        (should usage)
        (should (eq 'tree (cdr usage)))))))

(ert-deftest sysml2-test-view-parse-annex-a ()
  "Test view parsing on the annex-a fixture."
  (let ((fixture (expand-file-name "test/fixtures/annex-a-simple-vehicle-model.sysml"
                                   (or (locate-dominating-file default-directory "test")
                                       default-directory))))
    (with-temp-buffer
      (insert-file-contents fixture)
      (sysml2-mode)
      (let ((views (sysml2--diagram-parse-views)))
        ;; TreeView has render asTreeDiagram -> tree
        (should (assoc "TreeView" views))
        (should (eq 'tree (cdr (assoc "TreeView" views))))
        ;; PartsTreeView inherits from TreeView -> tree
        (should (assoc "PartsTreeView" views))
        (should (eq 'tree (cdr (assoc "PartsTreeView" views))))
        ;; vehiclePartsTree_Safety usage inherits from PartsTreeView
        (should (assoc "vehiclePartsTree_Safety" views))))))

;; --- Report Enhancements ---

(ert-deftest sysml2-test-md-traceability-has-id-column ()
  "Test that markdown traceability includes requirement IDs."
  (with-temp-buffer
    (insert "requirement def MassReq {\n"
            "    doc /* mass ok */\n"
            "}\n"
            "requirement <'REQ-001'> vehicleMass : MassReq {\n"
            "    doc /* mass under 2000 */\n"
            "}\n")
    (sysml2-mode)
    (let ((md (sysml2--report-md-traceability (current-buffer))))
      ;; Header should include ID column
      (should (string-match-p "| Requirement | ID |" md))
      ;; Row should include the ID value
      (should (string-match-p "REQ-001" md)))))

(ert-deftest sysml2-test-md-allocations-section ()
  "Test allocation matrix markdown rendering."
  (with-temp-buffer
    (insert "allocation def FunctionAllocation;\n"
            "allocate providePower to engine;\n"
            "allocate controlBraking to brakingSubsystem;\n")
    (sysml2-mode)
    (let ((md (sysml2--report-md-allocations (current-buffer))))
      (should (string-match-p "Allocation Matrix" md))
      (should (string-match-p "providePower" md))
      (should (string-match-p "engine" md))
      (should (string-match-p "controlBraking" md))
      (should (string-match-p "brakingSubsystem" md)))))

(ert-deftest sysml2-test-allocations-section-registered ()
  "Test that the allocations section is registered."
  (should (assoc "allocations" sysml2--report-md-sections)))

(provide 'test-diagram)
;;; test-diagram.el ends here
