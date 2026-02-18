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

;; --- Dispatcher Test ---

(ert-deftest sysml2-test-plantuml-generate-dispatch ()
  "Test that generate dispatches correctly."
  (let ((puml (sysml2-test--plantuml-with-text
               "part def A {}\npart def B :> A {}"
               (lambda () (sysml2-plantuml-generate 'tree)))))
    (should (string-match-p "class A <<block>>" puml))
    (should (string-match-p "A <|-- B" puml))))

(provide 'test-plantuml)
;;; test-plantuml.el ends here
