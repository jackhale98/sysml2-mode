;;; sysml2-d2.el --- D2 diagram generation for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; D2 diagram generation for SysML v2 graph layouts.
;; Generates D2 diagram language source from model data extracted
;; by `sysml2-model.el'.
;;
;; D2 (https://d2lang.com) is a modern diagram scripting language
;; with automatic graph layout, clean syntax, and SVG output.
;;
;; Supported diagram types:
;;   - interconnection (IBD / internal block diagram)
;;   - state-machine
;;   - action-flow (activity diagram)
;;   - use-case
;;   - package

;;; Code:

(require 'sysml2-model)
(require 'sysml2-vars)

;; ---------------------------------------------------------------------------
;; D2 style constants
;; ---------------------------------------------------------------------------

(defconst sysml2--d2-sysml-style
  "classes: {
  part: {
    style.border-radius: 4
    style.fill: \"#E8F4FD\"
    style.stroke: \"#2196F3\"
  }
  port: {
    style.border-radius: 0
    style.fill: \"#FFF3E0\"
    style.stroke: \"#FF9800\"
    width: 20
    height: 20
  }
  state: {
    style.border-radius: 12
    style.fill: \"#E8F5E9\"
    style.stroke: \"#4CAF50\"
  }
  action: {
    style.border-radius: 20
    style.fill: \"#F3E5F5\"
    style.stroke: \"#9C27B0\"
  }
  requirement: {
    style.border-radius: 0
    style.fill: \"#FFFDE7\"
    style.stroke: \"#FFC107\"
  }
  actor: {
    shape: person
    style.fill: \"#EFEBE9\"
    style.stroke: \"#795548\"
  }
  usecase: {
    shape: oval
    style.fill: \"#E0F7FA\"
    style.stroke: \"#00BCD4\"
  }
  package: {
    shape: package
    style.fill: \"#F5F5F5\"
    style.stroke: \"#607D8B\"
  }
  start: {
    shape: circle
    style.fill: \"#000000\"
    width: 16
    height: 16
  }
  end: {
    shape: circle
    style.fill: \"#000000\"
    style.stroke: \"#000000\"
    style.stroke-width: 3
    width: 16
    height: 16
    style.double-border: true
  }
}"
  "D2 style classes for SysML v2 diagram elements.")

;; ---------------------------------------------------------------------------
;; Interconnection diagram (IBD)
;; ---------------------------------------------------------------------------

(defun sysml2-d2-interconnection (scope-name)
  "Generate D2 source for an IBD of part def SCOPE-NAME."
  (let ((bounds (sysml2--model-find-def-bounds "part def" scope-name))
        (lines nil))
    (push (format "title: \"%s — Internal Block Diagram\" {" scope-name) lines)
    (push "  near: top-center" lines)
    (push "  style.font-size: 18" lines)
    (push "  style.bold: true" lines)
    (push "}" lines)
    (push "" lines)
    (push "direction: right" lines)
    (push "" lines)
    (when bounds
      (let ((parts (sysml2--model-extract-part-usages (car bounds) (cdr bounds)))
            (ports (sysml2--model-extract-port-usages (car bounds) (cdr bounds)))
            (conns (sysml2--model-extract-connections (car bounds) (cdr bounds))))
        ;; Parts as containers
        (dolist (p parts)
          (let ((pname (plist-get p :name))
                (ptype (plist-get p :type))
                (mult (plist-get p :multiplicity)))
            (push (format "%s: \"%s : %s%s\" {" pname pname ptype
                          (if mult (format " [%s]" mult) ""))
                  lines)
            (push "  style.border-radius: 4" lines)
            (push "  style.fill: \"#E8F4FD\"" lines)
            (push "  style.stroke: \"#2196F3\"" lines)
            ;; Find ports belonging to this part's type
            (let ((type-bounds (sysml2--model-find-def-bounds "part def" ptype)))
              (when type-bounds
                (let ((inner-ports (sysml2--model-extract-port-usages
                                    (car type-bounds) (cdr type-bounds))))
                  (dolist (ip inner-ports)
                    (let ((ipname (plist-get ip :name))
                          (iptype (plist-get ip :type)))
                      (push (format "  %s: \"%s : %s\" {" ipname ipname iptype) lines)
                      (push "    style.fill: \"#FFF3E0\"" lines)
                      (push "    style.stroke: \"#FF9800\"" lines)
                      (push "    width: 24" lines)
                      (push "    height: 24" lines)
                      (push "  }" lines))))))
            (push "}" lines)
            (push "" lines)))
        ;; Boundary ports
        (dolist (p ports)
          (let ((pname (plist-get p :name))
                (ptype (plist-get p :type))
                (conj (plist-get p :conjugated)))
            (push (format "%s: \"%s%s : %s\" {"
                          pname (if conj "~" "") pname ptype) lines)
            (push "  style.fill: \"#FFF3E0\"" lines)
            (push "  style.stroke: \"#FF9800\"" lines)
            (push "}" lines)
            (push "" lines)))
        ;; Connections
        (dolist (c conns)
          (let ((src (plist-get c :source))
                (tgt (plist-get c :target))
                (cname (plist-get c :name)))
            ;; Convert dot-path to D2 nesting
            (let ((d2-src (replace-regexp-in-string "\\." "." src))
                  (d2-tgt (replace-regexp-in-string "\\." "." tgt)))
              (push (format "%s -> %s: %s" d2-src d2-tgt cname) lines))))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; State machine diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-state-machine (scope-name)
  "Generate D2 source for a state machine diagram of SCOPE-NAME."
  (let ((bounds (sysml2--model-find-def-bounds "state def" scope-name))
        (lines nil))
    (push (format "title: \"%s — State Machine\" {" scope-name) lines)
    (push "  near: top-center" lines)
    (push "  style.font-size: 18" lines)
    (push "  style.bold: true" lines)
    (push "}" lines)
    (push "" lines)
    (push "direction: right" lines)
    (push "" lines)
    (when bounds
      (let ((states (sysml2--model-extract-states (car bounds) (cdr bounds)))
            (transitions (sysml2--model-extract-transitions
                          (car bounds) (cdr bounds)))
            (state-names nil))
        ;; Collect state names
        (dolist (s states)
          (push (plist-get s :name) state-names))
        ;; Start node
        (push "__start__: \"\" {" lines)
        (push "  shape: circle" lines)
        (push "  style.fill: \"#000000\"" lines)
        (push "  width: 16" lines)
        (push "  height: 16" lines)
        (push "}" lines)
        (push "" lines)
        ;; State nodes
        (dolist (s states)
          (let ((sname (plist-get s :name)))
            (push (format "%s: \"%s\" {" sname sname) lines)
            (push "  style.border-radius: 12" lines)
            (push "  style.fill: \"#E8F5E9\"" lines)
            (push "  style.stroke: \"#4CAF50\"" lines)
            (push "}" lines)
            (push "" lines)))
        ;; Initial transition to first state
        (when state-names
          (push (format "__start__ -> %s" (car (last state-names))) lines)
          (push "" lines))
        ;; Transitions
        (dolist (tr transitions)
          (let ((from (plist-get tr :from))
                (to (plist-get tr :to))
                (trigger (plist-get tr :trigger))
                (tname (plist-get tr :name)))
            (push (format "%s -> %s: \"%s\"" from to
                          (if trigger
                              (format "%s [%s]" tname trigger)
                            tname))
                  lines)))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Action flow diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-action-flow (scope-name)
  "Generate D2 source for an action flow diagram of SCOPE-NAME."
  (let ((bounds (sysml2--model-find-def-bounds "action def" scope-name))
        (lines nil))
    (push (format "title: \"%s — Action Flow\" {" scope-name) lines)
    (push "  near: top-center" lines)
    (push "  style.font-size: 18" lines)
    (push "  style.bold: true" lines)
    (push "}" lines)
    (push "" lines)
    (push "direction: right" lines)
    (push "" lines)
    (when bounds
      (let ((actions (sysml2--model-extract-actions (car bounds) (cdr bounds)))
            (successions (sysml2--model-extract-successions
                          (car bounds) (cdr bounds)))
            (action-names nil)
            (first-actions nil)
            (last-actions nil))
        ;; Collect action names
        (dolist (a actions)
          (push (plist-get a :name) action-names))
        ;; Start/end nodes
        (push "__start__: \"\" {" lines)
        (push "  shape: circle" lines)
        (push "  style.fill: \"#000000\"" lines)
        (push "  width: 16" lines)
        (push "  height: 16" lines)
        (push "}" lines)
        (push "" lines)
        ;; Action nodes
        (dolist (a actions)
          (let ((aname (plist-get a :name))
                (atype (plist-get a :type)))
            (push (format "%s: \"%s : %s\" {" aname aname atype) lines)
            (push "  style.border-radius: 20" lines)
            (push "  style.fill: \"#F3E5F5\"" lines)
            (push "  style.stroke: \"#9C27B0\"" lines)
            (push "}" lines)
            (push "" lines)))
        ;; End node
        (push "__end__: \"\" {" lines)
        (push "  shape: circle" lines)
        (push "  style.fill: \"#000000\"" lines)
        (push "  style.stroke: \"#000000\"" lines)
        (push "  style.stroke-width: 3" lines)
        (push "  width: 16" lines)
        (push "  height: 16" lines)
        (push "}" lines)
        (push "" lines)
        ;; Track which actions have incoming/outgoing edges
        (dolist (s successions)
          (push (plist-get s :to) first-actions)
          (push (plist-get s :from) last-actions))
        ;; Connect start to first action (one without incoming)
        (dolist (a action-names)
          (unless (member a first-actions)
            (push (format "__start__ -> %s" a) lines)))
        ;; Succession edges
        (dolist (s successions)
          (push (format "%s -> %s" (plist-get s :from) (plist-get s :to)) lines))
        ;; Connect last action to end (one without outgoing)
        (dolist (a action-names)
          (unless (member a last-actions)
            (push (format "%s -> __end__" a) lines)))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Use case diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-use-case ()
  "Generate D2 source for a use case diagram from the current buffer."
  (let ((data (sysml2--model-extract-use-cases))
        (lines nil))
    (push "title: \"Use Case Diagram\" {" lines)
    (push "  near: top-center" lines)
    (push "  style.font-size: 18" lines)
    (push "  style.bold: true" lines)
    (push "}" lines)
    (push "" lines)
    (let ((use-cases (plist-get data :use-cases))
          (actors (plist-get data :actors))
          (includes (plist-get data :includes)))
      ;; Actor nodes
      (dolist (a actors)
        (let ((aname (plist-get a :name)))
          (push (format "%s: \"%s\" {" aname aname) lines)
          (push "  shape: person" lines)
          (push "  style.fill: \"#EFEBE9\"" lines)
          (push "  style.stroke: \"#795548\"" lines)
          (push "}" lines)
          (push "" lines)))
      ;; Use case nodes
      (dolist (uc use-cases)
        (let ((ucname (plist-get uc :name))
              (doc (plist-get uc :doc)))
          (push (format "%s: \"%s\" {" ucname ucname) lines)
          (push "  shape: oval" lines)
          (push "  style.fill: \"#E0F7FA\"" lines)
          (push "  style.stroke: \"#00BCD4\"" lines)
          (when doc
            (push (format "  tooltip: \"%s\""
                          (replace-regexp-in-string "\"" "\\\\\"" doc))
                  lines))
          (push "}" lines)
          (push "" lines)))
      ;; Relationships
      (dolist (inc includes)
        (let ((uc (plist-get inc :use-case))
              (actor (plist-get inc :actor))
              (from (plist-get inc :from))
              (to (plist-get inc :to))
              (rel (plist-get inc :rel)))
          (cond
           (actor
            (push (format "%s -> %s" actor uc) lines))
           ((and from to (equal rel "include"))
            (push (format "%s -> %s: \"<<include>>\" {" from to) lines)
            (push "  style.stroke-dash: 5" lines)
            (push "}" lines))))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Package diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-package ()
  "Generate D2 source for a package diagram from the current buffer."
  (let ((data (sysml2--model-extract-packages))
        (lines nil))
    (push "title: \"Package Diagram\" {" lines)
    (push "  near: top-center" lines)
    (push "  style.font-size: 18" lines)
    (push "  style.bold: true" lines)
    (push "}" lines)
    (push "" lines)
    (let ((packages (plist-get data :packages))
          (imports (plist-get data :imports)))
      ;; Package nodes
      (dolist (pkg packages)
        (let ((pname (plist-get pkg :name)))
          (push (format "%s: \"%s\" {" pname pname) lines)
          (push "  shape: package" lines)
          (push "  style.fill: \"#F5F5F5\"" lines)
          (push "  style.stroke: \"#607D8B\"" lines)
          (push "}" lines)
          (push "" lines)))
      ;; Import edges
      (dolist (imp imports)
        (let* ((target (plist-get imp :target))
               (pos (plist-get imp :pos))
               (source-pkg (sysml2--model-package-at-pos
                            pos (plist-get data :packages)))
               ;; Extract first segment of import target as package name
               (target-pkg (car (split-string target "::" t))))
          (when (and source-pkg target-pkg
                     (not (string= source-pkg target-pkg)))
            (push (format "%s -> %s: \"<<import>>\" {" source-pkg target-pkg) lines)
            (push "  style.stroke-dash: 5" lines)
            (push "}" lines)))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Dispatcher
;; ---------------------------------------------------------------------------

(defun sysml2-d2-generate (type &optional scope)
  "Generate D2 source for diagram TYPE with optional SCOPE.
TYPE is a symbol: interconnection, state-machine, action-flow,
use-case, or package."
  (pcase type
    ('interconnection (sysml2-d2-interconnection scope))
    ('state-machine (sysml2-d2-state-machine scope))
    ('action-flow (sysml2-d2-action-flow scope))
    ('use-case (sysml2-d2-use-case))
    ('package (sysml2-d2-package))
    (_ (error "D2 backend does not support diagram type: %s" type))))

(provide 'sysml2-d2)
;;; sysml2-d2.el ends here
