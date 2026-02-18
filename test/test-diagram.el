;;; test-diagram.el --- Diagram command tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-diagram.el.  Tests mock PlantUML invocation
;; via cl-letf to verify command behavior without PlantUML installed.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'sysml2-mode)
(require 'sysml2-diagram)

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
  "Test that preview generates PlantUML string and passes it to invoker."
  (let ((captured-puml nil))
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

(ert-deftest sysml2-test-diagram-preview-buffer-tree ()
  "Test that preview-buffer generates tree diagram with expected classes."
  (let ((captured-puml nil))
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
  (let ((captured-format nil))
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
  "Test that explicit type argument routes correctly."
  (let ((captured-puml nil))
    (cl-letf (((symbol-function 'sysml2--diagram-invoke-plantuml)
               (lambda (puml _fmt _cb)
                 (setq captured-puml puml))))
      (with-temp-buffer
        (insert "requirement def Req1 {\n    doc /* test */\n}\n")
        (sysml2-mode)
        (let ((sysml2-diagram-output-format "svg"))
          (sysml2-diagram-type 'requirement-tree))))
    (should (string-match-p "<<requirement>>" captured-puml))))

;; --- Open PlantUML Test ---

(ert-deftest sysml2-test-diagram-open-plantuml-buffer ()
  "Test that open-plantuml creates a buffer with @startuml content."
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
    (kill-buffer puml-buf)))

(provide 'test-diagram)
;;; test-diagram.el ends here
