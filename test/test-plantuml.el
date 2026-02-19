;;; test-plantuml.el --- PlantUML transformation tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-plantuml.el: extraction functions and all five
;; diagram generators, including tests against OMG validation fixtures.

;;; Code:

(require 'ert)
(require 'sysml2-mode)
(require 'sysml2-plantuml)

;; --- Helpers ---

(defvar sysml2-test--puml-fixtures-dir
  (expand-file-name "fixtures"
                    (file-name-directory
                     (or load-file-name buffer-file-name)))
  "Directory containing test fixtures.")

(defun sysml2-test--plantuml-with-text (text fn)
  "Insert TEXT into a temp buffer in sysml2-mode, call FN, return result."
  (with-temp-buffer
    (insert text)
    (sysml2-mode)
    (funcall fn)))

(defun sysml2-test--with-fixture (name fn)
  "Load fixture NAME into a temp buffer in sysml2-mode and call FN."
  (with-temp-buffer
    (insert-file-contents (expand-file-name name sysml2-test--puml-fixtures-dir))
    (sysml2-mode)
    (funcall fn)))

;; --- Tree Diagram Tests ---

(ert-deftest sysml2-test-plantuml-tree-basic ()
  "Test tree diagram with simple part defs and specialization."
  (let ((puml (sysml2-test--plantuml-with-text
               "part def A {}\npart def B :> A {}"
               #'sysml2-plantuml-tree)))
    (should (string-match-p "@startuml" puml))
    (should (string-match-p "@enduml" puml))
    (should (string-match-p "class A <<block>>" puml))
    (should (string-match-p "class B <<block>>" puml))
    (should (string-match-p "A <|-- B" puml))))

(ert-deftest sysml2-test-plantuml-tree-vehicle-fixture ()
  "Test tree diagram against simple-vehicle.sysml fixture."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               #'sysml2-plantuml-tree)))
    (should (string-match-p "class Vehicle <<block>>" puml))
    (should (string-match-p "class Engine <<block>>" puml))
    (should (string-match-p "PowerSource <|-- Engine" puml))
    (should (string-match-p "PowerSource <|-- ElectricMotor" puml))
    (should (string-match-p "Vehicle \\*-- Engine" puml))))

(ert-deftest sysml2-test-plantuml-tree-abstract ()
  "Test that abstract part defs get the abstract modifier."
  (let ((puml (sysml2-test--plantuml-with-text
               "abstract part def Base {\n    attribute x;\n}"
               #'sysml2-plantuml-tree)))
    (should (string-match-p "abstract class Base <<block>>" puml))))

(ert-deftest sysml2-test-plantuml-tree-validation-fixture ()
  "Test tree diagram against OMG validation Parts Tree fixture."
  (let ((puml (sysml2-test--with-fixture
               "validation-parts-tree.sysml"
               #'sysml2-plantuml-tree)))
    (should (string-match-p "class Vehicle <<block>>" puml))
    (should (string-match-p "class Axle <<block>>" puml))
    (should (string-match-p "class FrontAxle <<block>>" puml))
    (should (string-match-p "Axle <|-- FrontAxle" puml))))

;; --- Interconnection (IBD) Diagram Tests ---

(ert-deftest sysml2-test-plantuml-ibd-basic ()
  "Test IBD with parts and a connection."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "part def System {\n"
                       "    part a : CompA;\n"
                       "    part b : CompB;\n"
                       "    connection link1\n"
                       "        connect a to b;\n"
                       "}")
               (lambda () (sysml2-plantuml-interconnection "System")))))
    (should (string-match-p "component.*System" puml))
    (should (string-match-p "component.*a : CompA" puml))
    (should (string-match-p "component.*b : CompB" puml))
    (should (string-match-p "a -- b : link1" puml))))

(ert-deftest sysml2-test-plantuml-ibd-flashlight ()
  "Test IBD against flashlight.sysml fixture."
  (let ((puml (sysml2-test--with-fixture
               "flashlight.sysml"
               (lambda () (sysml2-plantuml-interconnection "Flashlight")))))
    (should (string-match-p "component.*battery : Battery" puml))
    (should (string-match-p "component.*bulb : Bulb" puml))
    (should (string-match-p "battery -- bulb : batteryToBulb" puml))))

(ert-deftest sysml2-test-plantuml-ibd-validation-fixture ()
  "Test IBD against OMG validation Parts Interconnection fixture."
  (let ((puml (sysml2-test--with-fixture
               "validation-parts-interconnection.sysml"
               (lambda () (sysml2-plantuml-interconnection "VehicleA")))))
    ;; VehicleA has ports but no nested parts/connections at def level
    (should (string-match-p "component.*VehicleA" puml))
    (should (string-match-p "@startuml" puml))))

;; --- State Machine Tests ---

(ert-deftest sysml2-test-plantuml-state-machine-basic ()
  "Test state diagram with 2 states and 1 transition."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "state def TestStates {\n"
                       "    entry; then idle;\n"
                       "    state idle;\n"
                       "    state active;\n"
                       "    transition idle_to_active\n"
                       "        first idle\n"
                       "        accept go\n"
                       "        then active;\n"
                       "}")
               (lambda () (sysml2-plantuml-state-machine "TestStates")))))
    (should (string-match-p "\\[\\*\\] --> idle" puml))
    (should (string-match-p "state idle" puml))
    (should (string-match-p "state active" puml))
    (should (string-match-p "idle --> active : go" puml))))

(ert-deftest sysml2-test-plantuml-state-machine-vehicle ()
  "Test state diagram for EngineStates in simple-vehicle.sysml."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               (lambda () (sysml2-plantuml-state-machine "EngineStates")))))
    (should (string-match-p "state off" puml))
    (should (string-match-p "state starting" puml))
    (should (string-match-p "state running" puml))
    (should (string-match-p "state stopping" puml))
    (should (string-match-p "off --> starting : startCmd" puml))
    (should (string-match-p "starting --> running" puml))
    (should (string-match-p "running --> stopping : stopCmd" puml))
    (should (string-match-p "stopping --> off" puml))))

;; --- Action Flow Tests ---

(ert-deftest sysml2-test-plantuml-action-flow-basic ()
  "Test activity diagram with actions and succession."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "action def TestFlow {\n"
                       "    action step1 : DoA;\n"
                       "    action step2 : DoB;\n"
                       "    first step1 then step2;\n"
                       "}")
               (lambda () (sysml2-plantuml-action-flow "TestFlow")))))
    (should (string-match-p ":step1;" puml))
    (should (string-match-p ":step2;" puml))
    (should (string-match-p "start" puml))
    (should (string-match-p "stop" puml))
    (should (string-match-p "-->" puml))))

(ert-deftest sysml2-test-plantuml-action-flow-vehicle ()
  "Test activity diagram for Drive in simple-vehicle.sysml."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               (lambda () (sysml2-plantuml-action-flow "Drive")))))
    (should (string-match-p ":start;" puml))
    (should (string-match-p ":accelerate;" puml))
    (should (string-match-p "start" puml))
    (should (string-match-p "stop" puml))))

;; --- Requirement Tree Tests ---

(ert-deftest sysml2-test-plantuml-requirement-tree-basic ()
  "Test requirement diagram with reqs and satisfaction."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "requirement def ReqA {\n"
                       "    doc /* Must do A */\n"
                       "    subject x : Foo;\n"
                       "}\n"
                       "requirement def ReqB {\n"
                       "    doc /* Must do B */\n"
                       "}\n"
                       "satisfy requirement ReqA by Foo;\n")
               #'sysml2-plantuml-requirement-tree)))
    (should (string-match-p "class ReqA <<requirement>>" puml))
    (should (string-match-p "class ReqB <<requirement>>" puml))
    (should (string-match-p "<<satisfy>>" puml))
    (should (string-match-p "Foo \\.\\.> ReqA" puml))))

(ert-deftest sysml2-test-plantuml-requirement-vehicle ()
  "Test requirement diagram against simple-vehicle.sysml."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               #'sysml2-plantuml-requirement-tree)))
    (should (string-match-p "class VehicleMassReq <<requirement>>" puml))
    (should (string-match-p "class TopSpeedReq <<requirement>>" puml))
    (should (string-match-p "Vehicle \\.\\.> VehicleMassReq : <<satisfy>>" puml))
    (should (string-match-p "Vehicle \\.\\.> TopSpeedReq : <<satisfy>>" puml))))

;; --- Annex A Requirement Tests ---

(ert-deftest sysml2-test-plantuml-requirement-annex-a ()
  "Test requirement diagram against Annex A fixture.
Verifies that satisfy without `requirement' keyword is extracted."
  (let ((puml (sysml2-test--with-fixture
               "annex-a-simple-vehicle-model.sysml"
               #'sysml2-plantuml-requirement-tree)))
    ;; All 5 requirement defs should be present
    (should (string-match-p "class MassRequirement <<requirement>>" puml))
    (should (string-match-p "class ReliabilityRequirement <<requirement>>" puml))
    (should (string-match-p "class TorqueGenerationRequirement <<requirement>>" puml))
    (should (string-match-p "class DrivePowerOutputRequirement <<requirement>>" puml))
    (should (string-match-p "class FuelEconomyRequirement <<requirement>>" puml))
    ;; Both satisfy relationships (short names after last ::)
    (should (string-match-p "vehicle_b\\.engine \\.\\.> engineSpecification : <<satisfy>>" puml))
    (should (string-match-p "vehicle_b \\.\\.> vehicleSpecification : <<satisfy>>" puml))))

(ert-deftest sysml2-test-plantuml-satisfy-without-requirement-keyword ()
  "Test satisfy extraction when `requirement' keyword is omitted."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "requirement def ReqA {\n"
                       "    doc /* Must do A */\n"
                       "}\n"
                       "satisfy ReqA by Foo;\n")
               #'sysml2-plantuml-requirement-tree)))
    (should (string-match-p "class ReqA <<requirement>>" puml))
    (should (string-match-p "Foo \\.\\.> ReqA : <<satisfy>>" puml))))

(ert-deftest sysml2-test-plantuml-tree-annex-a ()
  "Test tree diagram against Annex A fixture.
Verifies typed definitions, stereotypes, and inheritance."
  (let ((puml (sysml2-test--with-fixture
               "annex-a-simple-vehicle-model.sysml"
               #'sysml2-plantuml-tree)))
    ;; Part defs with stereotypes
    (should (string-match-p "class Vehicle <<block>>" puml))
    (should (string-match-p "class Engine <<block>>" puml))
    (should (string-match-p "abstract class Software <<block>>" puml))
    ;; Inheritance
    (should (string-match-p "Axle <|-- FrontAxle" puml))
    (should (string-match-p "Software <|-- VehicleSoftware" puml))
    (should (string-match-p "Software <|-- VehicleController" puml))
    ;; Port defs with stereotypes
    (should (string-match-p "class IgnitionCmdPort <<port>>" puml))
    (should (string-match-p "class FuelPort <<port>>" puml))
    (should (string-match-p "PwrCmdPort <|-- FuelCmdPort" puml))
    ;; Interface defs
    (should (string-match-p "class EngineToTransmissionInterface <<interface>>" puml))
    ;; Item defs
    (should (string-match-p "class PwrCmd <<item>>" puml))
    (should (string-match-p "PwrCmd <|-- FuelCmd" puml))
    ;; Action defs
    (should (string-match-p "class ProvidePower <<action>>" puml))
    ;; Enum defs
    (should (string-match-p "enum Colors <<enumeration>>" puml))
    (should (string-match-p "enum IgnitionOnOff <<enumeration>>" puml))))

;; --- Detect Type Tests ---

(ert-deftest sysml2-test-plantuml-detect-type ()
  "Test auto-detection of diagram type at point."
  ;; Default is tree
  (let ((result (sysml2-test--plantuml-with-text
                 "part def Foo {}"
                 (lambda ()
                   (goto-char (point-min))
                   (sysml2-plantuml-detect-type-at-point)))))
    (should (eq (car result) 'tree)))
  ;; Inside a state def
  (let ((result (sysml2-test--plantuml-with-text
                 "state def MyStates {\n    state idle;\n}"
                 (lambda ()
                   (goto-char (point-min))
                   (search-forward "idle")
                   (sysml2-plantuml-detect-type-at-point)))))
    (should (eq (car result) 'state-machine))
    (should (equal (cdr result) "MyStates"))))

;; --- Use Case Diagram Tests ---

(ert-deftest sysml2-test-plantuml-use-case-basic ()
  "Test use case diagram with actors and includes."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "use case def DriveVehicle {\n"
                       "    subject vehicle : Vehicle;\n"
                       "    actor driver : Driver;\n"
                       "    include use case startEngine : StartEngine;\n"
                       "}\n"
                       "use case def StartEngine {\n"
                       "    subject vehicle : Vehicle;\n"
                       "}\n")
               #'sysml2-plantuml-use-case)))
    (should (string-match-p "@startuml" puml))
    (should (string-match-p "@enduml" puml))
    (should (string-match-p "actor.*driver" puml))
    (should (string-match-p "usecase.*DriveVehicle" puml))
    (should (string-match-p "usecase.*StartEngine" puml))
    (should (string-match-p "rectangle.*Vehicle" puml))
    (should (string-match-p "driver --> DriveVehicle" puml))
    (should (string-match-p "DriveVehicle \\.\\.> startEngine : <<include>>" puml))))

(ert-deftest sysml2-test-plantuml-use-case-vehicle ()
  "Test use case diagram against simple-vehicle.sysml fixture.
Actor shows as `driver' (name), not `ScalarValues::String' (type)."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               #'sysml2-plantuml-use-case)))
    (should (string-match-p "usecase.*DriveVehicle" puml))
    (should (string-match-p "rectangle.*Vehicle" puml))
    (should (string-match-p "actor.*driver" puml))
    (should-not (string-match-p "ScalarValues" puml))))

(ert-deftest sysml2-test-plantuml-use-case-annex-a ()
  "Test use case diagram against Annex A fixture.
Verifies 4 actors (untyped) and include targets resolve via :>."
  (let ((puml (sysml2-test--with-fixture
               "annex-a-simple-vehicle-model.sysml"
               #'sysml2-plantuml-use-case)))
    (should (string-match-p "usecase.*TransportPassenger" puml))
    (should (string-match-p "usecase.*GetInVehicle" puml))
    (should (string-match-p "usecase.*GetOutOfVehicle" puml))
    ;; 4 actors by name (untyped)
    (should (string-match-p "actor.*environment" puml))
    (should (string-match-p "actor.*road" puml))
    (should (string-match-p "actor.*driver" puml))
    (should (string-match-p "actor.*passenger" puml))
    ;; Includes resolve to def names via :>
    (should (string-match-p "TransportPassenger \\.\\.> getInVehicle : <<include>>" puml))
    (should (string-match-p "TransportPassenger \\.\\.> getOutOfVehicle : <<include>>" puml))))

(ert-deftest sysml2-test-plantuml-use-case-extract ()
  "Test use case extractor returns correct structure."
  (let ((data (sysml2-test--plantuml-with-text
               (concat "use case def FlyPlane {\n"
                       "    subject plane : Airplane;\n"
                       "    actor pilot : Pilot;\n"
                       "    actor copilot : CoPilot;\n"
                       "}\n")
               #'sysml2--puml-extract-use-cases)))
    (should (= (length (plist-get data :use-cases)) 1))
    (should (equal (plist-get (car (plist-get data :use-cases)) :name)
                   "FlyPlane"))
    (should (= (length (plist-get data :actors)) 2))
    (let ((actor-names (mapcar (lambda (a) (plist-get a :name))
                               (plist-get data :actors))))
      (should (member "pilot" actor-names))
      (should (member "copilot" actor-names)))))

(ert-deftest sysml2-test-plantuml-use-case-untyped-actors ()
  "Test use case extraction with untyped actors (Annex A style)."
  (let ((data (sysml2-test--plantuml-with-text
               (concat "use case def TransportPassenger {\n"
                       "    subject vehicle : Vehicle;\n"
                       "    actor environment;\n"
                       "    actor road;\n"
                       "    actor driver;\n"
                       "    actor passenger [0..4];\n"
                       "}\n")
               #'sysml2--puml-extract-use-cases)))
    (let ((actor-names (mapcar (lambda (a) (plist-get a :name))
                               (plist-get data :actors))))
      (should (= (length actor-names) 4))
      (should (member "environment" actor-names))
      (should (member "road" actor-names))
      (should (member "driver" actor-names))
      (should (member "passenger" actor-names)))
    ;; All actors should have nil type (untyped)
    (dolist (actor (plist-get data :actors))
      (should (null (plist-get actor :type))))))

(ert-deftest sysml2-test-plantuml-use-case-include-def-name ()
  "Test include use case resolves :> def name as target."
  (let ((data (sysml2-test--plantuml-with-text
               (concat "use case def TransportPassenger {\n"
                       "    include use case getIn_a:>getInVehicle [1..5];\n"
                       "    include use case getOut_a:>getOutOfVehicle [1..5];\n"
                       "}\n")
               #'sysml2--puml-extract-use-cases)))
    (let ((include-rels (cl-remove-if-not
                         (lambda (r) (plist-get r :rel))
                         (plist-get data :includes))))
      (should (= (length include-rels) 2))
      ;; Should resolve to def names, not usage names
      (should (equal (plist-get (nth 0 include-rels) :to) "getInVehicle"))
      (should (equal (plist-get (nth 1 include-rels) :to) "getOutOfVehicle")))))

;; --- Package Diagram Tests ---

(ert-deftest sysml2-test-plantuml-package-basic ()
  "Test package diagram with nested packages."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "package Outer {\n"
                       "    package Inner {\n"
                       "        part def Foo {}\n"
                       "    }\n"
                       "}\n")
               #'sysml2-plantuml-package)))
    (should (string-match-p "@startuml" puml))
    (should (string-match-p "@enduml" puml))
    (should (string-match-p "package.*Outer" puml))
    (should (string-match-p "package.*Inner" puml))))

(ert-deftest sysml2-test-plantuml-package-vehicle ()
  "Test package diagram against simple-vehicle.sysml fixture."
  (let ((puml (sysml2-test--with-fixture
               "simple-vehicle.sysml"
               #'sysml2-plantuml-package)))
    (should (string-match-p "package.*VehicleModel" puml))))

(ert-deftest sysml2-test-plantuml-package-annex-a ()
  "Test package diagram against Annex A fixture.
Verifies deeply nested package structure."
  (let ((puml (sysml2-test--with-fixture
               "annex-a-simple-vehicle-model.sysml"
               #'sysml2-plantuml-package)))
    (should (string-match-p "package.*SimpleVehicleModel" puml))
    (should (string-match-p "package.*Definitions" puml))
    (should (string-match-p "package.*PartDefinitions" puml))
    (should (string-match-p "package.*VehicleConfigurations" puml))
    (should (string-match-p "package.*VehicleAnalysis" puml))))

(ert-deftest sysml2-test-plantuml-package-extract ()
  "Test package extractor returns correct hierarchy."
  (let ((data (sysml2-test--plantuml-with-text
               (concat "package A {\n"
                       "    package B {\n"
                       "        package C {}\n"
                       "    }\n"
                       "}\n")
               #'sysml2--puml-extract-packages)))
    (let ((pkgs (plist-get data :packages)))
      (should (= (length pkgs) 3))
      (should (equal (plist-get (nth 0 pkgs) :name) "A"))
      (should (= (plist-get (nth 0 pkgs) :level) 0))
      (should (equal (plist-get (nth 1 pkgs) :name) "B"))
      (should (= (plist-get (nth 1 pkgs) :level) 1))
      (should (equal (plist-get (nth 2 pkgs) :name) "C"))
      (should (= (plist-get (nth 2 pkgs) :level) 2)))))

(ert-deftest sysml2-test-plantuml-package-no-external-imports ()
  "Test that package diagram does not emit arrows to external packages."
  (let ((puml (sysml2-test--plantuml-with-text
               (concat "package Outer {\n"
                       "    import ISQ::*;\n"
                       "    import ScalarValues::*;\n"
                       "    import ShapeItems::Box;\n"
                       "    package Inner {\n"
                       "        import Outer::*;\n"
                       "    }\n"
                       "}\n")
               #'sysml2-plantuml-package)))
    ;; Should NOT have arrows to ISQ, ScalarValues, ShapeItems
    (should-not (string-match-p "ISQ" puml))
    (should-not (string-match-p "ScalarValues" puml))
    (should-not (string-match-p "ShapeItems" puml))
    ;; Should have arrow from Inner to Outer (both defined in file)
    (should (string-match-p "\"Inner\" \\.\\.> \"Outer\" : <<import>>" puml))))

(ert-deftest sysml2-test-plantuml-package-annex-a-no-external ()
  "Test Annex A package diagram has no arrows to standard library packages."
  (let ((puml (sysml2-test--with-fixture
               "annex-a-simple-vehicle-model.sysml"
               #'sysml2-plantuml-package)))
    (should-not (string-match-p "\"ISQ\"" puml))
    (should-not (string-match-p "\"ScalarValues\"" puml))
    (should-not (string-match-p "\"ShapeItems\"" puml))))

;; --- Detect Type Tests (additional) ---

(ert-deftest sysml2-test-plantuml-detect-use-case-type ()
  "Test auto-detection of use case diagram type."
  (let ((result (sysml2-test--plantuml-with-text
                 "use case def DriveVehicle {\n    subject v : Vehicle;\n}"
                 (lambda ()
                   (goto-char (point-min))
                   (search-forward "subject")
                   (sysml2-plantuml-detect-type-at-point)))))
    (should (eq (car result) 'use-case))))

;; --- Dispatcher Test ---

(ert-deftest sysml2-test-plantuml-generate-dispatch ()
  "Test that generate dispatches correctly."
  (let ((puml (sysml2-test--plantuml-with-text
               "part def A {}\npart def B :> A {}"
               (lambda () (sysml2-plantuml-generate 'tree)))))
    (should (string-match-p "class A <<block>>" puml))
    (should (string-match-p "A <|-- B" puml))))

(ert-deftest sysml2-test-plantuml-generate-dispatch-use-case ()
  "Test that generate dispatches use-case type correctly."
  (let ((puml (sysml2-test--plantuml-with-text
               "use case def Test {\n    subject t : Thing;\n}\n"
               (lambda () (sysml2-plantuml-generate 'use-case)))))
    (should (string-match-p "usecase.*Test" puml))))

(ert-deftest sysml2-test-plantuml-generate-dispatch-package ()
  "Test that generate dispatches package type correctly."
  (let ((puml (sysml2-test--plantuml-with-text
               "package Foo {\n    package Bar {}\n}\n"
               (lambda () (sysml2-plantuml-generate 'package)))))
    (should (string-match-p "package.*Foo" puml))
    (should (string-match-p "package.*Bar" puml))))

(provide 'test-plantuml)
;;; test-plantuml.el ends here
