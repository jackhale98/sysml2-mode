;;; test-ob-sysml.el --- Tests for ob-sysml org-babel integration -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for SysML v2 org-babel support: variable expansion,
;; tangle configuration, execution modes, and diagram generation.

;;; Code:

(require 'ert)
(require 'test-helper)
(require 'ob-sysml)

;; --- Variable expansion ---

(ert-deftest sysml2-test-ob-expand-no-vars ()
  "Test that body without variables is returned unchanged."
  (let ((body "part def Vehicle { attribute mass; }"))
    (should (string= body
                     (org-babel-expand-body:sysml body nil)))))

(ert-deftest sysml2-test-ob-expand-dollar-var ()
  "Test $name variable substitution."
  (let ((body "part def $name { attribute $attr; }")
        (params '((:var . (name . "Engine"))
                  (:var . (attr . "power")))))
    (should (string= "part def Engine { attribute power; }"
                     (org-babel-expand-body:sysml body params)))))

(ert-deftest sysml2-test-ob-expand-braced-var ()
  "Test ${name} variable substitution."
  (let ((body "part def ${defname}Impl {}")
        (params '((:var . (defname . "Motor")))))
    (should (string= "part def MotorImpl {}"
                     (org-babel-expand-body:sysml body params)))))

(ert-deftest sysml2-test-ob-expand-numeric-var ()
  "Test numeric variable substitution."
  (let ((body "attribute maxPower = $power;")
        (params '((:var . (power . 200)))))
    (should (string= "attribute maxPower = 200;"
                     (org-babel-expand-body:sysml body params)))))

;; --- Execution: no-cmd passthrough ---

(ert-deftest sysml2-test-ob-execute-no-cmd ()
  "Test that blocks without :cmd return expanded body (for tangle)."
  (let ((result (org-babel-execute:sysml
                 "part def Foo {}" '((:cmd . nil)))))
    (should (string= "part def Foo {}" result))))

(ert-deftest sysml2-test-ob-execute-none-cmd ()
  "Test that :cmd none returns expanded body."
  (let ((result (org-babel-execute:sysml
                 "part def Foo {}" '((:cmd . "none")))))
    (should (string= "part def Foo {}" result))))

(ert-deftest sysml2-test-ob-execute-unknown-cmd ()
  "Test that unknown :cmd returns error message."
  (let ((result (org-babel-execute:sysml
                 "part def Foo {}" '((:cmd . "bogus")))))
    (should (string-match-p "Unknown" result))))

;; --- Execution: CLI commands (require sysml binary) ---

(ert-deftest sysml2-test-ob-execute-check ()
  "Test :cmd check runs sysml check and returns output."
  (skip-unless (sysml2--find-executable (or sysml2-cli-executable "sysml")))
  (let ((result (org-babel-execute:sysml
                 "part def Vehicle { attribute mass; }"
                 '((:cmd . "check")))))
    (should (stringp result))
    ;; Should contain some diagnostic output (at least a note about unused def)
    (should (> (length result) 0))))

(ert-deftest sysml2-test-ob-execute-list ()
  "Test :cmd list runs sysml list."
  (skip-unless (sysml2--find-executable (or sysml2-cli-executable "sysml")))
  (let ((result (org-babel-execute:sysml
                 "part def Vehicle { part engine : Engine; }"
                 '((:cmd . "list")))))
    (should (stringp result))
    (should (string-match-p "Vehicle" result))))

(ert-deftest sysml2-test-ob-execute-stats ()
  "Test :cmd stats runs sysml stats."
  (skip-unless (sysml2--find-executable (or sysml2-cli-executable "sysml")))
  (let ((result (org-babel-execute:sysml
                 "part def A {} part def B {}"
                 '((:cmd . "stats")))))
    (should (stringp result))
    (should (> (length result) 0))))

;; --- Simulate args building ---

(ert-deftest sysml2-test-ob-simulate-args-list ()
  "Test simulate args for list type."
  (let ((args (ob-sysml--simulate-args "/tmp/f.sysml"
                                        '((:simulate-type . "list")))))
    (should (equal args '("simulate" "list" "/tmp/f.sysml")))))

(ert-deftest sysml2-test-ob-simulate-args-sm ()
  "Test simulate args for state-machine with events."
  (let ((args (ob-sysml--simulate-args "/tmp/f.sysml"
                                        '((:simulate-type . "sm")
                                          (:name . "TrafficLight")
                                          (:events . "next,next")))))
    (should (equal args '("simulate" "state-machine" "/tmp/f.sysml"
                          "-n" "TrafficLight" "-e" "next,next")))))

(ert-deftest sysml2-test-ob-simulate-args-eval ()
  "Test simulate args for eval with bindings."
  (let ((args (ob-sysml--simulate-args "/tmp/f.sysml"
                                        '((:simulate-type . "eval")
                                          (:name . "SpeedLimit")
                                          (:bindings . "speed=100")))))
    (should (equal args '("simulate" "eval" "/tmp/f.sysml"
                          "-n" "SpeedLimit" "-b" "speed=100")))))

;; --- Tangle configuration ---

(ert-deftest sysml2-test-ob-tangle-extension ()
  "Test that sysml tangle extension is registered."
  (should (assoc "sysml" org-babel-tangle-lang-exts)))

;; --- Default header args ---

(ert-deftest sysml2-test-ob-default-noweb ()
  "Test that noweb is enabled by default for SysML blocks."
  (let ((noweb (cdr (assq :noweb org-babel-default-header-args:sysml))))
    (should (string= "yes" noweb))))

;; --- Src-lang mode ---

(ert-deftest sysml2-test-ob-src-lang-mode ()
  "Test that sysml src blocks use sysml2-mode."
  (should (equal 'sysml2 (cdr (assoc "sysml" org-src-lang-modes)))))

(provide 'test-ob-sysml)
;;; test-ob-sysml.el ends here
