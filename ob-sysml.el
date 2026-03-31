;;; ob-sysml.el --- Org-Babel support for SysML v2 -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml, literate-programming
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Org-Babel language support for SysML v2 textual notation.
;; Enables literate systems engineering — combining documentation,
;; requirements narratives, and executable SysML v2 model definitions
;; in a single org-mode document.
;;
;; Features:
;;   - Tangle: extract SysML blocks to .sysml files
;;   - Noweb: compose models from named blocks with <<references>>
;;   - Execute: run CLI commands (check, simulate, diagram, list, etc.)
;;   - Variables: substitute org variables into SysML templates
;;   - Diagrams: generate SVG/PNG diagrams inline
;;
;; Usage:
;;
;;   Tangle a complete model from literate blocks:
;;
;;     #+BEGIN_SRC sysml :tangle vehicle.sysml :noweb yes
;;     package VehicleModel {
;;         <<part-definitions>>
;;         <<requirements>>
;;     }
;;     #+END_SRC
;;
;;     #+NAME: part-definitions
;;     #+BEGIN_SRC sysml
;;     part def Vehicle {
;;         attribute mass :> ISQ::mass;
;;     }
;;     #+END_SRC
;;
;;   Execute a check on a SysML block:
;;
;;     #+BEGIN_SRC sysml :cmd check :results output
;;     part def Foo { attribute x; }
;;     #+END_SRC
;;
;;   Generate a diagram:
;;
;;     #+BEGIN_SRC sysml :cmd diagram :diagram-type tree :file tree.svg
;;     part def Vehicle { part engine : Engine; }
;;     #+END_SRC
;;
;;   Simulate a state machine:
;;
;;     #+BEGIN_SRC sysml :cmd simulate :simulate-type sm :name TrafficLight :events "next,next"
;;     state def TrafficLight { ... }
;;     #+END_SRC
;;
;;   Pass variables into a template:
;;
;;     #+BEGIN_SRC sysml :var name="Engine" power="200"
;;     part def $name {
;;         attribute maxPower = $power;
;;     }
;;     #+END_SRC
;;
;;   Import from other tangled files:
;;
;;     #+BEGIN_SRC sysml :tangle subsystems/propulsion.sysml
;;     package Propulsion { part def Motor { } }
;;     #+END_SRC
;;
;;     #+BEGIN_SRC sysml :cmd check :tangle-before yes :includes "subsystems/"
;;     package Main {
;;         import Propulsion::*;
;;         part myMotor : Motor;
;;     }
;;     #+END_SRC

;;; Code:

(require 'ob)
(require 'sysml2-vars)

;; Forward declarations
(declare-function sysml2-mode "sysml2-mode")
(declare-function sysml2-d2-generate "sysml2-d2")
(declare-function sysml2-svg-generate "sysml2-svg")
(declare-function org-babel-process-file-name "ob-core")

(defvar sysml2-diagram-backend)
(defvar sysml2--diagram-d2-types)
(defvar sysml2--diagram-svg-types)
(declare-function sysml2--diagram-resolve-d2 "sysml2-diagram")
(declare-function sysml2--diagram-invoke-d2-sync "sysml2-diagram")
(declare-function sysml2--diagram-invoke-plantuml "sysml2-diagram")
(declare-function sysml2-plantuml-generate "sysml2-plantuml")

;; ---------------------------------------------------------------------------
;; Language registration
;; ---------------------------------------------------------------------------

(defvar org-babel-default-header-args:sysml
  '((:results . "output")
    (:exports . "both")
    (:noweb   . "yes"))
  "Default header arguments for SysML v2 source blocks.
Noweb is enabled by default to support literate model composition.")

(defvar org-babel-tangle-lang-exts)
(with-eval-after-load 'ob-tangle
  (add-to-list 'org-babel-tangle-lang-exts '("sysml" . "sysml")))

;; ---------------------------------------------------------------------------
;; Variable expansion
;; ---------------------------------------------------------------------------

(defun org-babel-variable-assignments:sysml (params)
  "Return variable assignment preamble for SysML PARAMS.
Variables are not inserted as code — they are used for $-substitution
in `org-babel-expand-body:sysml'."
  ;; SysML doesn't have runtime variable assignment, so we return nil.
  ;; Variable substitution happens in expand-body instead.
  nil)

(defun org-babel-expand-body:sysml (body params)
  "Expand BODY with variable substitutions from PARAMS.
Replaces $name or ${name} with the value of :var name=value.
Also handles noweb expansion (done by org-babel before this)."
  (let ((vars (org-babel--get-vars params))
        (expanded body))
    (dolist (var vars)
      (let ((name (symbol-name (car var)))
            (val (format "%s" (cdr var))))
        (setq expanded
              (replace-regexp-in-string
               (concat "\\$\\(?:{" (regexp-quote name) "}\\|"
                       (regexp-quote name) "\\b\\)")
               val expanded t t))))
    expanded))

;; ---------------------------------------------------------------------------
;; Execution
;; ---------------------------------------------------------------------------

(defun org-babel-execute:sysml (body params)
  "Execute a SysML v2 source block.
BODY is the SysML source code.  PARAMS are the header arguments.

The :cmd parameter determines what to do:
  nil / \"none\"  — return the expanded body (for tangle-only blocks)
  \"check\"       — run `sysml check' and return diagnostics
  \"lint\"        — alias for check
  \"list\"        — run `sysml list' and return element listing
  \"stats\"       — run `sysml stats' and return statistics
  \"simulate\"    — run simulation (see :simulate-type, :name, :events)
  \"diagram\"     — generate a diagram (see :diagram-type, :scope, :file)
  \"doc\"         — generate documentation
  \"show\"        — show element details (see :name)

Additional parameters:
  :file           — output file for diagrams
  :diagram-type   — tree, interconnection, state-machine, etc.
  :scope          — definition name for scoped diagrams
  :simulate-type  — eval, sm/state-machine, af/action-flow, list
  :name           — element name for simulate/show
  :events         — comma-separated events for state machine
  :bindings       — comma-separated name=value for simulation
  :includes       — additional .sysml files or directories for import
                    resolution (passed as -I to the CLI)
  :tangle-before  — when \"yes\", tangle all blocks in the document
                    before execution so imports across tangled files
                    resolve correctly"
  (let* ((cmd (cdr (assq :cmd params)))
         (expanded (org-babel-expand-body:sysml body params)))
    (cond
     ;; No command — just return expanded body (for tangle/export)
     ((or (null cmd) (string= cmd "none"))
      expanded)

     ;; Diagram generation
     ((string= cmd "diagram")
      (ob-sysml--execute-diagram expanded params))

     ;; CLI commands
     ((member cmd '("check" "lint" "list" "stats" "doc"
                     "show" "simulate"))
      (ob-sysml--execute-cli cmd expanded params))

     (t (format "Unknown :cmd \"%s\"" cmd)))))

;; ---------------------------------------------------------------------------
;; CLI execution
;; ---------------------------------------------------------------------------

(defun ob-sysml--execute-cli (cmd body params)
  "Execute CLI command CMD on BODY with PARAMS.
When :tangle-before is \"yes\", tangles all SysML blocks in the
current org document first, then passes the tangle output directory
as an include path so cross-file imports resolve.
The :includes parameter adds additional -I paths."
  ;; Tangle first if requested
  (when (equal (cdr (assq :tangle-before params)) "yes")
    (ob-sysml--tangle-for-includes))
  (let* ((tmp (make-temp-file "ob-sysml-" nil ".sysml"))
         (exe (or (sysml2--find-executable
                   (or sysml2-cli-executable "sysml"))
                  (user-error "sysml CLI not found on exec-path")))
         (args nil)
         (include-args (ob-sysml--build-include-args params)))
    (unwind-protect
        (progn
          (with-temp-file tmp (insert body))
          (setq args
                (pcase cmd
                  ((or "check" "lint")
                   (list "check" tmp))
                  ("list"
                   (list "list" tmp))
                  ("stats"
                   (list "stats" tmp))
                  ("doc"
                   (list "doc" tmp))
                  ("show"
                   (let ((name (cdr (assq :name params))))
                     (if name
                         (list "show" tmp name)
                       (list "show" tmp))))
                  ("simulate"
                   (ob-sysml--simulate-args tmp params))))
          ;; Append include paths
          (setq args (append args include-args))
          (with-temp-buffer
            (apply #'call-process exe nil t nil args)
            (buffer-string)))
      (ignore-errors (delete-file tmp)))))

(defun ob-sysml--build-include-args (params)
  "Build -I flags from :includes in PARAMS and tangle directories.
Returns a list of strings like (\"-I\" \"path1\" \"-I\" \"path2\")."
  (let ((includes (cdr (assq :includes params)))
        (result nil))
    ;; :includes can be a string (single path) or space-separated paths
    (when includes
      (dolist (path (if (stringp includes)
                        (split-string includes)
                      (list includes)))
        (let ((expanded (expand-file-name path)))
          (when (or (file-directory-p expanded)
                    (file-exists-p expanded))
            (push "-I" result)
            (push expanded result)))))
    ;; Also include the directory of the org file (where tangles land)
    (when buffer-file-name
      (let ((org-dir (file-name-directory buffer-file-name)))
        (push "-I" result)
        (push org-dir result)))
    (nreverse result)))

(declare-function org-babel-tangle "ob-tangle")

(defun ob-sysml--tangle-for-includes ()
  "Tangle all SysML blocks in the current org buffer.
This ensures that tangled .sysml files exist on disk so that
cross-file import statements resolve during CLI execution."
  (when (and (derived-mode-p 'org-mode)
             (fboundp 'org-babel-tangle))
    (let ((inhibit-message t))
      (org-babel-tangle nil nil "sysml"))))

(defun ob-sysml--simulate-args (file params)
  "Build simulate command args for FILE from PARAMS."
  (let* ((sim-type (or (cdr (assq :simulate-type params)) "list"))
         (name (cdr (assq :name params)))
         (events (cdr (assq :events params)))
         (bindings (cdr (assq :bindings params)))
         (args (list "simulate")))
    (pcase sim-type
      ("list"
       (append args (list "list" file)))
      ((or "eval" "evaluate")
       (setq args (append args (list "eval" file)))
       (when name (setq args (append args (list "-n" name))))
       (when bindings (setq args (append args (list "-b" bindings))))
       args)
      ((or "sm" "state-machine")
       (setq args (append args (list "state-machine" file)))
       (when name (setq args (append args (list "-n" name))))
       (when events (setq args (append args (list "-e" events))))
       (when bindings (setq args (append args (list "-b" bindings))))
       args)
      ((or "af" "action-flow")
       (setq args (append args (list "action-flow" file)))
       (when name (setq args (append args (list "-n" name))))
       (when bindings (setq args (append args (list "-b" bindings))))
       args)
      (_ (list "simulate" "list" file)))))

;; ---------------------------------------------------------------------------
;; Diagram generation
;; ---------------------------------------------------------------------------

(defun ob-sysml--execute-diagram (body params)
  "Generate a diagram from BODY with PARAMS."
  (let* ((diagram-type (intern (or (cdr (assq :diagram-type params)) "tree")))
         (scope (cdr (assq :scope params)))
         (out-file (cdr (assq :file params))))
    (with-temp-buffer
      (insert body)
      (sysml2-mode)
      (if out-file
          (ob-sysml--diagram-to-file diagram-type scope out-file)
        ;; No output file — return D2/SVG source
        (pcase sysml2-diagram-backend
          ('native
           (if (memq diagram-type sysml2--diagram-d2-types)
               (sysml2-d2-generate diagram-type scope)
             (when (memq diagram-type sysml2--diagram-svg-types)
               (sysml2-svg-generate diagram-type scope))))
          ('plantuml
           (sysml2-plantuml-generate diagram-type scope)))))))

(defun ob-sysml--diagram-to-file (diagram-type scope out-file)
  "Render DIAGRAM-TYPE (with SCOPE) and write to OUT-FILE."
  (let ((format (or (file-name-extension out-file) "svg")))
    (pcase sysml2-diagram-backend
      ('native
       (if (and (sysml2--diagram-resolve-d2)
                (memq diagram-type sysml2--diagram-d2-types))
           (let ((data (sysml2--diagram-invoke-d2-sync
                        (sysml2-d2-generate diagram-type scope) format)))
             (with-temp-file out-file
               (set-buffer-multibyte nil)
               (insert data))
             out-file)
         (when (memq diagram-type sysml2--diagram-svg-types)
           (let ((svg (sysml2-svg-generate diagram-type scope)))
             (with-temp-file out-file
               (set-buffer-multibyte nil)
               (insert svg))
             out-file))))
      ('plantuml
       (let ((puml (sysml2-plantuml-generate diagram-type scope))
             (result nil))
         (sysml2--diagram-invoke-plantuml
          puml format
          (lambda (success data)
            (if success
                (progn
                  (with-temp-file out-file
                    (set-buffer-multibyte nil)
                    (insert data))
                  (setq result out-file))
              (setq result (format "Error: %s" data)))))
         result)))))

;; ---------------------------------------------------------------------------
;; Syntax highlighting in org src blocks
;; ---------------------------------------------------------------------------

;; Tell org-mode to use sysml2-mode for editing SysML blocks
(with-eval-after-load 'org-src
  (defvar org-src-lang-modes)
  (add-to-list 'org-src-lang-modes '("sysml" . sysml2)))

(provide 'ob-sysml)
;;; ob-sysml.el ends here
