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
;;   - tree (BDD / parts decomposition)
;;   - requirement-tree (requirement hierarchy)
;;   - interconnection (IBD / internal block diagram)
;;   - state-machine
;;   - action-flow (activity diagram)
;;   - use-case
;;   - package

;;; Code:

(require 'cl-lib)
(require 'subr-x)
(require 'sysml2-model)
(require 'sysml2-vars)

;; ---------------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------------

(defun sysml2--d2-sanitize-id (name)
  "Sanitize NAME for use as a D2 node identifier.
Replaces characters that are invalid in D2 identifiers."
  (replace-regexp-in-string "[^A-Za-z0-9_]" "_" (or name "")))

;; ---------------------------------------------------------------------------
;; Tree diagram (BDD / parts decomposition)
;; ---------------------------------------------------------------------------

(defun sysml2-d2-tree ()
  "Generate D2 source for a tree/BDD diagram from the current buffer."
  (let* ((part-defs (sysml2--model-extract-part-defs))
         (port-defs (sysml2--model-extract-typed-defs "port def" "port"))
         (enum-defs (sysml2--model-extract-enum-defs))
         (compositions (sysml2--model-extract-usage-compositions))
         (lines nil))
    (push "direction: down" lines)
    (push "" lines)
    ;; Part def nodes with attributes, ports, and parts compartments
    (dolist (d part-defs)
      (let* ((name (plist-get d :name))
             (id (sysml2--d2-sanitize-id name))
             (super (plist-get d :super))
             (abstract (plist-get d :abstract))
             (attrs (plist-get d :attributes))
             (parts (plist-get d :parts))
             ;; Look up port usages from this definition
             (def-ports (sysml2--model-extract-port-usages-for-def name))
             (display-name (if abstract (format "/%s/" name) name))
             (content-lines (list (format "<<part def>>\\n**%s**" display-name))))
        ;; Add port compartment
        (when def-ports
          (push "\\n---" content-lines)
          (dolist (port def-ports)
            (let ((pname (plist-get port :name))
                  (ptype (plist-get port :type))
                  (conj (plist-get port :conjugated)))
              (push (format "\\n%sport %s : %s"
                            (if conj "~" "") pname (or ptype ""))
                    content-lines))))
        ;; Add attribute compartment
        (when attrs
          (push "\\n---" content-lines)
          (dolist (attr attrs)
            (push (format "\\n%s" attr) content-lines)))
        ;; Add parts compartment
        (when parts
          (push "\\n---" content-lines)
          (dolist (p parts)
            (let ((pname (plist-get p :name))
                  (ptype (plist-get p :type))
                  (mult (plist-get p :multiplicity)))
              (push (format "\\npart %s : %s%s" pname ptype
                            (if mult (format " [%s]" mult) ""))
                    content-lines))))
        (push (format "%s: \"%s\" {" id
                      (apply #'concat (nreverse content-lines)))
              lines)
        (push "  style.border-radius: 4" lines)
        (push "  style.fill: \"#E8F4FD\"" lines)
        (push "  style.stroke: \"#2196F3\"" lines)
        (push "}" lines)
        (push "" lines)
        ;; Inheritance edge
        (when super
          (let ((super-id (sysml2--d2-sanitize-id super)))
            (push (format "%s -> %s: \"\" {" id super-id) lines)
            (push "  target-arrowhead: {" lines)
            (push "    shape: triangle" lines)
            (push "    style.filled: false" lines)
            (push "  }" lines)
            (push "  style.stroke: \"#607D8B\"" lines)
            (push "}" lines)
            (push "" lines)))))
    ;; Port def nodes
    (dolist (d port-defs)
      (let* ((name (plist-get d :name))
             (id (sysml2--d2-sanitize-id name))
             (attrs (plist-get d :attributes))
             (content (format "<<port def>>\\n**%s**" name)))
        (dolist (attr attrs)
          (setq content (concat content (format "\\n%s" attr))))
        (push (format "%s: \"%s\" {" id content) lines)
        (push "  style.border-radius: 0" lines)
        (push "  style.fill: \"#FFF3E0\"" lines)
        (push "  style.stroke: \"#FF9800\"" lines)
        (push "}" lines)
        (push "" lines)))
    ;; Enum def nodes
    (dolist (d enum-defs)
      (let* ((name (plist-get d :name))
             (id (sysml2--d2-sanitize-id name))
             (literals (plist-get d :literals))
             (content (format "<<enum def>>\\n**%s**" name)))
        (dolist (lit literals)
          (setq content (concat content (format "\\n%s" lit))))
        (push (format "%s: \"%s\" {" id content) lines)
        (push "  style.border-radius: 0" lines)
        (push "  style.fill: \"#FFF8E1\"" lines)
        (push "  style.stroke: \"#FFC107\"" lines)
        (push "}" lines)
        (push "" lines)))
    ;; Composition edges (filled diamond at parent)
    (dolist (comp compositions)
      (let ((parent (sysml2--d2-sanitize-id (plist-get comp :parent-type)))
            (child (sysml2--d2-sanitize-id (plist-get comp :child-type)))
            (mult (plist-get comp :multiplicity)))
        (push (format "%s -> %s: \"%s\" {" parent child
                      (if mult (format "[%s]" mult) ""))
              lines)
        (push "  source-arrowhead: {" lines)
        (push "    shape: diamond" lines)
        (push "    style.filled: true" lines)
        (push "  }" lines)
        (push "  target-arrowhead: \"\"" lines)
        (push "  style.stroke: \"#2196F3\"" lines)
        (push "}" lines)
        (push "" lines)))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Requirement tree diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-requirement-tree ()
  "Generate D2 source for a requirement tree diagram from the current buffer."
  (let* ((req-defs (sysml2--model-extract-requirements))
         (req-usages (sysml2--model-extract-requirement-usages))
         (satisfactions (sysml2--model-extract-satisfactions))
         (verifications (sysml2--model-extract-verifications))
         ;; Build lookup tables for status
         (sat-map (make-hash-table :test 'equal))
         (ver-map (make-hash-table :test 'equal))
         (lines nil))
    ;; Build satisfy/verify maps
    (dolist (s satisfactions)
      (let ((req (plist-get s :requirement)))
        (puthash req (cons (plist-get s :by) (gethash req sat-map)) sat-map)
        ;; Also normalize short name
        (let ((short (replace-regexp-in-string "\\`.*[:.]" "" req)))
          (unless (gethash short sat-map)
            (puthash short (gethash req sat-map) sat-map)))))
    (dolist (v verifications)
      (let ((req (plist-get v :requirement)))
        (puthash req (cons (plist-get v :by) (gethash req ver-map)) ver-map)
        (let ((short (replace-regexp-in-string "\\`.*[:.]" "" req)))
          (unless (gethash short ver-map)
            (puthash short (gethash req ver-map) ver-map)))))

    (push "direction: down" lines)
    (push "" lines)

    ;; Requirement def nodes
    (dolist (req req-defs)
      (let* ((name (plist-get req :name))
             (id (sysml2--d2-sanitize-id name))
             (doc (plist-get req :doc))
             (satisfied (gethash name sat-map))
             (verified (gethash name ver-map))
             (fill (cond ((and satisfied verified) "#E8F5E9")
                         (satisfied "#FFF8E1")
                         (verified "#E3F2FD")
                         (t "#FFEBEE")))
             (stroke (cond ((and satisfied verified) "#4CAF50")
                           (satisfied "#FFC107")
                           (verified "#2196F3")
                           (t "#F44336")))
             (content (format "<<requirement def>>\\n**%s**" name)))
        (when doc
          (let ((truncated (if (> (length doc) 40)
                               (concat (substring doc 0 37) "...")
                             doc)))
            (setq content (concat content (format "\\n%s" truncated)))))
        (push (format "%s: \"%s\" {" id content) lines)
        (push "  style.border-radius: 0" lines)
        (push (format "  style.fill: \"%s\"" fill) lines)
        (push (format "  style.stroke: \"%s\"" stroke) lines)
        (push "}" lines)
        (push "" lines)))

    ;; Requirement usage nodes (with children as nested)
    (dolist (req req-usages)
      (let* ((name (plist-get req :name))
             (id (sysml2--d2-sanitize-id name))
             (rtype (plist-get req :type))
             (req-id (plist-get req :id))
             (children (plist-get req :children))
             (label (if req-id (format "%s [%s]" name req-id) name))
             (stereo (if rtype (format "<<req : %s>>" rtype) "<<requirement>>"))
             (content (format "%s\\n**%s**" stereo label)))
        (push (format "%s: \"%s\" {" id content) lines)
        (push "  style.border-radius: 0" lines)
        (push "  style.fill: \"#FFFDE7\"" lines)
        (push "  style.stroke: \"#FFC107\"" lines)
        ;; Children as nested nodes inside the parent
        (dolist (child children)
          (let* ((cname (plist-get child :name))
                 (cid (sysml2--d2-sanitize-id cname))
                 (ctype (plist-get child :type))
                 (cid-val (plist-get child :id))
                 (clabel (if cid-val (format "%s [%s]" cname cid-val) cname))
                 (cstereo (if ctype (format ": %s" ctype) "<<req>>")))
            (push (format "  %s: \"%s\\n**%s**\" {" cid cstereo clabel) lines)
            (push "    style.fill: \"#FFFDE7\"" lines)
            (push "    style.stroke: \"#FFC107\"" lines)
            (push "  }" lines)))
        (push "}" lines)
        (push "" lines)))

    ;; Satisfy relationships (green dashed arrows)
    (dolist (s satisfactions)
      (let* ((req-name (plist-get s :requirement))
             (by-name (plist-get s :by))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-name))
             (req-id (sysml2--d2-sanitize-id req-short))
             (by-id (sysml2--d2-sanitize-id by-name)))
        ;; Create the "by" node if it doesn't exist yet
        (push (format "%s: \"%s\" {" by-id by-name) lines)
        (push "  style.fill: \"#E8F4FD\"" lines)
        (push "  style.stroke: \"#2196F3\"" lines)
        (push "  style.border-radius: 4" lines)
        (push "}" lines)
        (push (format "%s -> %s: \"<<satisfy>>\" {" by-id req-id) lines)
        (push "  style.stroke: \"#4CAF50\"" lines)
        (push "  style.stroke-dash: 5" lines)
        (push "}" lines)
        (push "" lines)))

    ;; Verify relationships (blue dashed arrows)
    (dolist (v verifications)
      (let* ((req-name (plist-get v :requirement))
             (by-name (plist-get v :by))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-name))
             (req-id (sysml2--d2-sanitize-id req-short))
             (by-id (sysml2--d2-sanitize-id by-name)))
        (push (format "%s: \"%s\" {" by-id by-name) lines)
        (push "  style.fill: \"#E8F4FD\"" lines)
        (push "  style.stroke: \"#2196F3\"" lines)
        (push "  style.border-radius: 4" lines)
        (push "}" lines)
        (push (format "%s -> %s: \"<<verify>>\" {" by-id req-id) lines)
        (push "  style.stroke: \"#2196F3\"" lines)
        (push "  style.stroke-dash: 5" lines)
        (push "}" lines)
        (push "" lines)))

    ;; Legend
    (push "legend: \"\" {" lines)
    (push "  near: bottom-right" lines)
    (push "  full: \"Full coverage\" { style.fill: \"#E8F5E9\"; style.stroke: \"#4CAF50\" }" lines)
    (push "  partial: \"Partial\" { style.fill: \"#FFF8E1\"; style.stroke: \"#FFC107\" }" lines)
    (push "  gap: \"Gap\" { style.fill: \"#FFEBEE\"; style.stroke: \"#F44336\" }" lines)
    (push "}" lines)

    (string-join (nreverse lines) "\n")))

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
      (let* ((parts (sysml2--model-extract-part-usages (car bounds) (cdr bounds)))
             (ports (sysml2--model-extract-port-usages (car bounds) (cdr bounds)))
             (conns (sysml2--model-extract-connections (car bounds) (cdr bounds)))
             (flows (sysml2--model-extract-flows (car bounds) (cdr bounds)))
             (binds (sysml2--model-extract-bindings (car bounds) (cdr bounds)))
             ;; Collect all port refs from connections/flows/binds to ensure
             ;; they exist as explicit nodes inside their part containers
             (port-refs (make-hash-table :test 'equal))
             (part-name-set (make-hash-table :test 'equal)))
        ;; Index part names
        (dolist (p parts)
          (puthash (plist-get p :name) t part-name-set))
        ;; Collect port references from edges (dotted names like heater.heatOut)
        (dolist (c conns)
          (dolist (ref (list (plist-get c :source) (plist-get c :target)))
            (when (string-match "\\`\\([^.]+\\)\\.\\(.+\\)" ref)
              (let ((part (match-string 1 ref))
                    (port (match-string 2 ref)))
                (when (gethash part part-name-set)
                  (puthash (cons part port) t port-refs))))))
        (dolist (f flows)
          (dolist (ref (list (plist-get f :source) (plist-get f :target)))
            (when (string-match "\\`\\([^.]+\\)\\.\\(.+\\)" ref)
              (let ((part (match-string 1 ref))
                    (port (match-string 2 ref)))
                (when (gethash part part-name-set)
                  (puthash (cons part port) t port-refs))))))
        (dolist (b binds)
          (dolist (ref (list (plist-get b :source) (plist-get b :target)))
            (when (string-match "\\`\\([^.]+\\)\\.\\(.+\\)" ref)
              (let ((part (match-string 1 ref))
                    (port (match-string 2 ref)))
                (when (gethash part part-name-set)
                  (puthash (cons part port) t port-refs))))))

        ;; Parts as containers with ports and attributes
        (dolist (p parts)
          (let* ((pname (plist-get p :name))
                 (ptype (plist-get p :type))
                 (mult (plist-get p :multiplicity))
                 ;; Try to look up ports and attributes from the type definition
                 (type-bounds (sysml2--model-find-def-bounds "part def" ptype))
                 (inner-ports (when type-bounds
                                (sysml2--model-extract-port-usages
                                 (car type-bounds) (cdr type-bounds))))
                 (inner-attrs (when type-bounds
                                (let ((type-part-defs
                                       (sysml2--model-extract-part-defs)))
                                  (plist-get
                                   (car (cl-remove-if-not
                                         (lambda (d)
                                           (equal (plist-get d :name) ptype))
                                         type-part-defs))
                                   :attributes))))
                 (declared-port-names (make-hash-table :test 'equal))
                 ;; Build label with attributes if available
                 (label (format "%s : %s%s" pname ptype
                                (if mult (format " [%s]" mult) "")))
                 (content (if inner-attrs
                              (concat label
                                      (mapconcat (lambda (a) (format "\\n%s" a))
                                                 inner-attrs ""))
                            label)))
            (push (format "%s: \"%s\" {" pname content) lines)
            (push "  style.border-radius: 4" lines)
            (push "  style.fill: \"#E8F4FD\"" lines)
            (push "  style.stroke: \"#2196F3\"" lines)
            ;; Render ports found from type definition
            (dolist (ip inner-ports)
              (let ((ipname (plist-get ip :name))
                    (iptype (plist-get ip :type))
                    (conj (plist-get ip :conjugated)))
                (puthash ipname t declared-port-names)
                (push (format "  %s: \"%s%s : %s\" {" ipname
                              (if conj "~" "") ipname (or iptype ""))
                      lines)
                (push "    style.fill: \"#FFF3E0\"" lines)
                (push "    style.stroke: \"#FF9800\"" lines)
                (push "    style.border-radius: 0" lines)
                (push "    width: 60" lines)
                (push "    height: 36" lines)
                (push "  }" lines)))
            ;; Ensure ports referenced by connections exist even if type
            ;; def wasn't found (prevents D2 creating implicit nodes outside)
            (maphash
             (lambda (key _val)
               (when (equal (car key) pname)
                 (let ((port-name (cdr key)))
                   (unless (gethash port-name declared-port-names)
                     (push (format "  %s: \"%s\" {" port-name port-name) lines)
                     (push "    style.fill: \"#FFF3E0\"" lines)
                     (push "    style.stroke: \"#FF9800\"" lines)
                     (push "    style.border-radius: 0" lines)
                     (push "    width: 60" lines)
                     (push "    height: 36" lines)
                     (push "  }" lines)))))
             port-refs)
            ;; Minimum size for empty containers
            (unless (or inner-ports
                        (cl-some (lambda (key)
                                   (equal (car key) pname))
                                 (hash-table-keys port-refs)))
              (push "  width: 160" lines)
              (push "  height: 80" lines))
            (push "}" lines)
            (push "" lines)))
        ;; Boundary ports (on the scope boundary, not inside parts)
        (dolist (p ports)
          (let* ((pname (plist-get p :name))
                 ;; Skip ports that are inside a nested part
                 (is-boundary t))
            ;; A port at the scope level should NOT have a matching part
            (dolist (part-p parts)
              (when (equal pname (plist-get part-p :name))
                (setq is-boundary nil)))
            (when is-boundary
              (let ((ptype (plist-get p :type))
                    (conj (plist-get p :conjugated)))
                (push (format "%s: \"%s%s : %s\" {"
                              pname (if conj "~" "") pname (or ptype ""))
                      lines)
                (push "  style.fill: \"#FFF3E0\"" lines)
                (push "  style.stroke: \"#FF9800\"" lines)
                (push "  style.border-radius: 0" lines)
                (push "  width: 60" lines)
                (push "  height: 36" lines)
                (push "}" lines)
                (push "" lines)))))
        ;; Connection edges
        (dolist (c conns)
          (let ((src (plist-get c :source))
                (tgt (plist-get c :target))
                (cname (plist-get c :name)))
            (push (format "%s -> %s: \"%s\" {" src tgt
                          (if (string-empty-p cname) "" cname))
                  lines)
            (push "  style.stroke: \"#2196F3\"" lines)
            (push "}" lines)))
        (when conns (push "" lines))
        ;; Flow edges
        (dolist (f flows)
          (let ((src (plist-get f :source))
                (tgt (plist-get f :target))
                (fname (plist-get f :name))
                (ftype (plist-get f :type)))
            (push (format "%s -> %s: \"%s\" {" src tgt
                          (if ftype
                              (format "%s [%s]"
                                      (if (string-empty-p fname) "flow" fname)
                                      ftype)
                            (if (string-empty-p fname) "flow" fname)))
                  lines)
            (push "  style.stroke: \"#9C27B0\"" lines)
            (push "  style.stroke-dash: 5" lines)
            (push "}" lines)))
        (when flows (push "" lines))
        ;; Bind edges
        (dolist (b binds)
          (let ((src (plist-get b :source))
                (tgt (plist-get b :target)))
            (push (format "%s -> %s: \"=\" {" src tgt) lines)
            (push "  style.stroke: \"#FF9800\"" lines)
            (push "  style.stroke-dash: 3" lines)
            (push "}" lines)))
        (when binds (push "" lines))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; State machine diagram
;; ---------------------------------------------------------------------------

(defun sysml2--d2-transition-label (tr)
  "Build a SysML-style transition label from transition plist TR.
Format: trigger [guard] / effect"
  (let ((trigger (plist-get tr :trigger))
        (guard (plist-get tr :guard))
        (effect (plist-get tr :effect))
        (parts nil))
    (when trigger (push trigger parts))
    (when guard (push (format " [%s]" guard) parts))
    (when effect (push (format " / %s" effect) parts))
    (if parts (apply #'concat (nreverse parts)) "")))

(defun sysml2-d2-state-machine (scope-name)
  "Generate D2 source for a state machine diagram of SCOPE-NAME.
Looks for `state def SCOPE-NAME { ... }' first, then falls back to
`exhibit state SCOPE-NAME { ... }' inside part definitions.
States show entry/do/exit action compartments."
  (let ((bounds (or (sysml2--model-find-def-bounds "state def" scope-name)
                    (sysml2--model-find-exhibit-state-bounds scope-name)))
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
      (let* ((states (sysml2--model-extract-states (car bounds) (cdr bounds)))
             (transitions (sysml2--model-extract-transitions
                           (car bounds) (cdr bounds)))
             (initial-state (sysml2--model-extract-initial-state
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
        ;; State nodes with entry/do/exit compartments
        (dolist (s states)
          (let* ((sname (plist-get s :name))
                 (entry-act (plist-get s :entry))
                 (do-act (plist-get s :do))
                 (exit-act (plist-get s :exit))
                 (has-actions (or entry-act do-act exit-act))
                 (content (format "**%s**" sname)))
            (when has-actions
              (when entry-act
                (setq content (concat content (format "\\nentry / %s" entry-act))))
              (when do-act
                (setq content (concat content (format "\\ndo / %s" do-act))))
              (when exit-act
                (setq content (concat content (format "\\nexit / %s" exit-act)))))
            (push (format "%s: \"%s\" {" sname content) lines)
            (push "  style.border-radius: 12" lines)
            (push "  style.fill: \"#E8F5E9\"" lines)
            (push "  style.stroke: \"#4CAF50\"" lines)
            (push "}" lines)
            (push "" lines)))
        ;; Initial transition
        (let ((init-target (or initial-state
                               (car (last state-names)))))
          (when init-target
            (push (format "__start__ -> %s" init-target) lines)
            (push "" lines)))
        ;; Transitions with full labels: trigger [guard] / effect
        (dolist (tr transitions)
          (let ((from (plist-get tr :from))
                (to (plist-get tr :to))
                (label (sysml2--d2-transition-label tr)))
            (push (format "%s -> %s: \"%s\"" from to label) lines)))))
    (string-join (nreverse lines) "\n")))

;; ---------------------------------------------------------------------------
;; Action flow diagram
;; ---------------------------------------------------------------------------

(defun sysml2-d2-action-flow (scope-name)
  "Generate D2 source for an action flow diagram of SCOPE-NAME.
Renders actions as rounded rectangles, fork/join as bars, and
decide/merge as diamonds.  Connects via succession edges."
  (let ((bounds (or (sysml2--model-find-def-bounds "action def" scope-name)
                    ;; Also search use case usages for action-like bodies
                    (sysml2--model-find-def-bounds "use case def" scope-name)))
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
            (control-nodes (sysml2--model-extract-control-nodes
                            (car bounds) (cdr bounds)))
            (all-node-names nil)
            (has-incoming (make-hash-table :test 'equal))
            (has-outgoing (make-hash-table :test 'equal)))
        ;; Collect all node names
        (dolist (a actions)
          (push (plist-get a :name) all-node-names))
        (dolist (cn control-nodes)
          (push (plist-get cn :name) all-node-names))
        ;; Start node
        (push "__start__: \"\" {" lines)
        (push "  shape: circle" lines)
        (push "  style.fill: \"#000000\"" lines)
        (push "  width: 16" lines)
        (push "  height: 16" lines)
        (push "}" lines)
        (push "" lines)
        ;; Action nodes (rounded rectangles)
        (dolist (a actions)
          (let ((aname (plist-get a :name))
                (atype (plist-get a :type)))
            (push (format "%s: \"%s\" {" aname
                          (if atype (format "%s : %s" aname atype) aname))
                  lines)
            (push "  style.border-radius: 20" lines)
            (push "  style.fill: \"#F3E5F5\"" lines)
            (push "  style.stroke: \"#9C27B0\"" lines)
            (push "}" lines)
            (push "" lines)))
        ;; Control nodes (fork/join = bars, decide/merge = diamonds)
        (dolist (cn control-nodes)
          (let ((cname (plist-get cn :name))
                (ckind (plist-get cn :kind)))
            (pcase ckind
              ((or 'fork 'join)
               (push (format "%s: \"%s\" {" cname
                             (format "<<%s>>" (symbol-name ckind)))
                     lines)
               (push "  shape: rectangle" lines)
               (push "  width: 8" lines)
               (push "  height: 60" lines)
               (push "  style.fill: \"#263238\"" lines)
               (push "  style.stroke: \"#263238\"" lines)
               (push "}" lines))
              ((or 'decide 'merge)
               (push (format "%s: \"%s\" {" cname cname) lines)
               (push "  shape: diamond" lines)
               (push "  style.fill: \"#FFF8E1\"" lines)
               (push "  style.stroke: \"#FFC107\"" lines)
               (push "}" lines)))
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
        ;; Track incoming/outgoing edges
        (dolist (s successions)
          (puthash (plist-get s :to) t has-incoming)
          (puthash (plist-get s :from) t has-outgoing))
        ;; Connect start to nodes with no incoming edge
        ;; (skip "start" and "done" pseudo-nodes)
        (dolist (a all-node-names)
          (unless (or (gethash a has-incoming)
                      (member a '("start" "done")))
            (push (format "__start__ -> %s" a) lines)))
        ;; Handle "first start then X" pattern
        (dolist (s successions)
          (when (equal (plist-get s :from) "start")
            (push (format "__start__ -> %s" (plist-get s :to)) lines)
            (puthash "start" t has-outgoing)))
        ;; Succession edges (skip start/done pseudo-nodes)
        (dolist (s successions)
          (let ((from (plist-get s :from))
                (to (plist-get s :to)))
            (cond
             ((equal from "start") nil)  ; already handled
             ((equal to "done")
              (push (format "%s -> __end__" from) lines))
             (t
              (push (format "%s -> %s" from to) lines)))))
        ;; Connect nodes with no outgoing edge to end
        (dolist (a all-node-names)
          (unless (or (gethash a has-outgoing)
                      (member a '("start" "done")))
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
TYPE is a symbol: tree, requirement-tree, interconnection,
state-machine, action-flow, use-case, or package."
  (pcase type
    ('tree (sysml2-d2-tree))
    ('requirement-tree (sysml2-d2-requirement-tree))
    ('interconnection (sysml2-d2-interconnection scope))
    ('state-machine (sysml2-d2-state-machine scope))
    ('action-flow (sysml2-d2-action-flow scope))
    ('use-case (sysml2-d2-use-case))
    ('package (sysml2-d2-package))
    (_ (error "D2 backend does not support diagram type: %s" type))))

(provide 'sysml2-d2)
;;; sysml2-d2.el ends here
