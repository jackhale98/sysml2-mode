;;; sysml2-svg.el --- Direct SVG diagram generation for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Zero-dependency SVG diagram generation for SysML v2.
;; Generates SVG XML directly from model data extracted by
;; `sysml2-model.el'.  No external tools required.
;;
;; Supports deterministic layouts where auto-layout is unnecessary:
;;   - tree (BDD / parts decomposition)
;;   - requirement-tree (requirement hierarchy)

;;; Code:

(require 'cl-lib)
(require 'sysml2-model)
(require 'sysml2-vars)

;; ---------------------------------------------------------------------------
;; SVG drawing primitives
;; ---------------------------------------------------------------------------

(defconst sysml2--svg-colors
  '((part-fill     . "#E8F4FD")
    (part-stroke   . "#2196F3")
    (enum-fill     . "#FFF8E1")
    (enum-stroke   . "#FFC107")
    (port-fill     . "#FFF3E0")
    (port-stroke   . "#FF9800")
    (req-fill      . "#FFFDE7")
    (req-stroke    . "#FFC107")
    (sat-fill      . "#E8F5E9")
    (sat-stroke    . "#4CAF50")
    (gap-fill      . "#FFEBEE")
    (gap-stroke    . "#F44336")
    (line          . "#607D8B")
    (text          . "#212121")
    (text-light    . "#757575")
    (bg            . "#FFFFFF"))
  "Color palette for SVG diagrams.")

(defsubst sysml2--svg-color (key)
  "Get color for KEY from the palette."
  (cdr (assq key sysml2--svg-colors)))

(defun sysml2--svg-escape (text)
  "Escape TEXT for use in SVG XML attributes."
  (let ((s (or text "")))
    (setq s (replace-regexp-in-string "&" "&amp;" s))
    (setq s (replace-regexp-in-string "<" "&lt;" s))
    (setq s (replace-regexp-in-string ">" "&gt;" s))
    (setq s (replace-regexp-in-string "\"" "&quot;" s))
    s))

(defun sysml2--svg-header (width height)
  "Return SVG header for canvas of WIDTH x HEIGHT."
  (format (concat "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
                  "<svg xmlns=\"http://www.w3.org/2000/svg\" "
                  "width=\"%d\" height=\"%d\" "
                  "viewBox=\"0 0 %d %d\" "
                  "style=\"background: %s;\">\n"
                  "<defs>\n"
                  "  <style>\n"
                  "    text { font-family: 'Segoe UI', Roboto, sans-serif; }\n"
                  "    .title { font-size: 16px; font-weight: bold; fill: %s; }\n"
                  "    .label { font-size: 12px; fill: %s; }\n"
                  "    .sublabel { font-size: 11px; fill: %s; }\n"
                  "    .stereo { font-size: 10px; fill: %s; font-style: italic; }\n"
                  "  </style>\n"
                  "</defs>\n")
          width height width height
          (sysml2--svg-color 'bg)
          (sysml2--svg-color 'text)
          (sysml2--svg-color 'text)
          (sysml2--svg-color 'text-light)
          (sysml2--svg-color 'text-light)))

(defun sysml2--svg-footer ()
  "Return SVG footer."
  "</svg>\n")

(defun sysml2--svg-rect (x y w h fill stroke &optional rx)
  "Return SVG rect at X,Y with size W,H, colors FILL/STROKE, corner RX."
  (format "<rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" rx=\"%d\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>\n"
          x y w h (or rx 4) fill stroke))

(defun sysml2--svg-text (x y text &optional class)
  "Return SVG text at X,Y with TEXT content and optional CLASS."
  (format "<text x=\"%d\" y=\"%d\" class=\"%s\">%s</text>\n"
          x y (or class "label") (sysml2--svg-escape text)))

(defun sysml2--svg-line (x1 y1 x2 y2 &optional stroke dash)
  "Return SVG line from X1,Y1 to X2,Y2 with optional STROKE and DASH."
  (format "<line x1=\"%d\" y1=\"%d\" x2=\"%d\" y2=\"%d\" stroke=\"%s\" stroke-width=\"1.5\"%s/>\n"
          x1 y1 x2 y2 (or stroke (sysml2--svg-color 'line))
          (if dash (format " stroke-dasharray=\"%s\"" dash) "")))

(defun sysml2--svg-triangle (x y size &optional fill)
  "Return SVG triangle (inheritance arrow) at X,Y with SIZE."
  (let ((half (/ size 2)))
    (format "<polygon points=\"%d,%d %d,%d %d,%d\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>\n"
            x (- y half) (- x half) (+ y half) (+ x half) (+ y half)
            (or fill (sysml2--svg-color 'bg)) (sysml2--svg-color 'line))))

;; ---------------------------------------------------------------------------
;; Text measurement approximation
;; ---------------------------------------------------------------------------

(defun sysml2--svg-text-width (text &optional font-size)
  "Approximate pixel width of TEXT at FONT-SIZE (default 12)."
  (let ((fs (or font-size 12)))
    (* (length text) (* fs 0.6))))

;; ---------------------------------------------------------------------------
;; Tree diagram (BDD / parts decomposition)
;; ---------------------------------------------------------------------------

(defun sysml2--svg-build-tree (part-names compositions)
  "Build a tree structure from PART-NAMES and COMPOSITIONS.
Returns (ROOTS . CHILDREN-MAP) where ROOTS is a list of root names
and CHILDREN-MAP is a hash-table mapping parent-name to list of
child-names."
  (let ((children-map (make-hash-table :test 'equal))
        (child-set (make-hash-table :test 'equal)))
    (dolist (comp compositions)
      (let ((parent (plist-get comp :parent-type))
            (child (plist-get comp :child-type)))
        (when (and (member parent part-names)
                   (member child part-names))
          (puthash parent (cons child (gethash parent children-map))
                   children-map)
          (puthash child t child-set))))
    ;; Reverse child lists to maintain source order
    (maphash (lambda (k v) (puthash k (nreverse v) children-map))
             children-map)
    ;; Roots = parts not appearing as children
    (let ((roots (cl-remove-if (lambda (n) (gethash n child-set))
                               part-names)))
      (cons roots children-map))))

(defun sysml2--svg-assign-depths (roots children-map)
  "Assign depth to each node starting from ROOTS using CHILDREN-MAP.
Returns a hash-table mapping name to depth."
  (let ((depth-map (make-hash-table :test 'equal))
        (queue nil))
    (dolist (r roots)
      (puthash r 0 depth-map)
      (push r queue))
    (while queue
      (let* ((node (pop queue))
             (d (gethash node depth-map))
             (kids (gethash node children-map)))
        (dolist (kid kids)
          (unless (gethash kid depth-map)
            (puthash kid (1+ d) depth-map)
            (push kid queue)))))
    depth-map))

(defun sysml2--svg-layout-tree (ordered-names depth-map box-w box-h-fn
                                              svg-left-margin depth-gap row-gap title-y)
  "Layout nodes in a hierarchical tree and return positioned node list.
ORDERED-NAMES is the list of part names in tree traversal order.
DEPTH-MAP maps name to depth.  BOX-H-FN is a function of name returning
box height.  Returns list of (:name :x :y :w :h :depth)."
  (let ((y-by-depth (make-hash-table))
        (nodes nil))
    ;; Initialize all depths to start below the title
    (maphash (lambda (_k v)
               (unless (gethash v y-by-depth)
                 (puthash v title-y y-by-depth)))
             depth-map)
    (dolist (name ordered-names)
      (let* ((depth (or (gethash name depth-map) 0))
             (x (+ svg-left-margin (* depth (+ box-w depth-gap))))
             (h (funcall box-h-fn name))
             (y (gethash depth y-by-depth title-y)))
        (push (list :name name :x x :y y :w box-w :h h :depth depth)
              nodes)
        (puthash depth (+ y h row-gap) y-by-depth)))
    (nreverse nodes)))

(defun sysml2--svg-tree-order (roots children-map all-names)
  "Return ALL-NAMES ordered by depth-first tree traversal from ROOTS.
Nodes not reachable from ROOTS are appended at the end."
  (let ((result nil)
        (visited (make-hash-table :test 'equal)))
    (cl-labels ((dfs (node)
                  (unless (gethash node visited)
                    (puthash node t visited)
                    (push node result)
                    (dolist (kid (gethash node children-map))
                      (dfs kid)))))
      (dolist (r roots) (dfs r)))
    ;; Append orphans not reached by DFS
    (dolist (n all-names)
      (unless (gethash n visited)
        (push n result)))
    (nreverse result)))

(defun sysml2-svg-tree ()
  "Generate SVG for a tree/BDD diagram from the current buffer.
Returns an SVG string."
  (let* ((part-defs (sysml2--model-extract-part-defs))
         (port-defs (sysml2--model-extract-typed-defs "port def" "port"))
         (enum-defs (sysml2--model-extract-enum-defs))
         (compositions (sysml2--model-extract-usage-compositions))
         ;; Layout constants
         (box-w 200)
         (box-h-base 40)
         (attr-h 16)
         (depth-gap 40)
         (row-gap 20)
         (svg-left-margin 40)
         (title-y 60)
         ;; Build tree structure
         (part-names (mapcar (lambda (d) (plist-get d :name)) part-defs))
         (tree (sysml2--svg-build-tree part-names compositions))
         (roots (car tree))
         (children-map (cdr tree))
         (depth-map (sysml2--svg-assign-depths roots children-map))
         ;; Def lookup
         (def-map (make-hash-table :test 'equal))
         ;; Node storage
         (node-map (make-hash-table :test 'equal))
         (all-nodes nil)
         (max-x 0)
         (max-y 0))
    ;; Build def lookup
    (dolist (d part-defs)
      (puthash (plist-get d :name) d def-map))
    ;; Order parts by DFS tree traversal
    (let* ((ordered (sysml2--svg-tree-order roots children-map part-names))
           (part-nodes
            (sysml2--svg-layout-tree
             ordered depth-map box-w
             (lambda (name)
               (let* ((def (gethash name def-map))
                      (attrs (plist-get def :attributes))
                      (parts (plist-get def :parts)))
                 (+ box-h-base (* (+ (length attrs) (length parts)) attr-h))))
             svg-left-margin depth-gap row-gap title-y)))
      ;; Register part nodes
      (dolist (pn part-nodes)
        (let ((name (plist-get pn :name))
              (def (gethash (plist-get pn :name) def-map)))
          (puthash name
                   (append pn (list :super (plist-get def :super)
                                    :abstract (plist-get def :abstract)
                                    :attrs (plist-get def :attributes)
                                    :parts (plist-get def :parts)
                                    :kind "part"))
                   node-map)
          (push (gethash name node-map) all-nodes)
          (setq max-x (max max-x (+ (plist-get pn :x) box-w)))
          (setq max-y (max max-y (+ (plist-get pn :y) (plist-get pn :h)))))))
    ;; Port defs in a column after the deepest tree level
    (let ((port-x (+ max-x depth-gap 40))
          (port-y title-y))
      (dolist (def port-defs)
        (let* ((name (plist-get def :name))
               (attrs (plist-get def :attributes))
               (h (+ box-h-base (* (length attrs) attr-h)))
               (node (list :name name :super (plist-get def :super)
                           :attrs attrs :parts nil
                           :x port-x :y port-y :w box-w :h h
                           :kind "port")))
          (puthash name node node-map)
          (push node all-nodes)
          (setq port-y (+ port-y h row-gap))
          (setq max-x (max max-x (+ port-x box-w)))
          (setq max-y (max max-y (+ port-y h))))))
    ;; Enum defs in next column
    (when enum-defs
      (let ((enum-x (+ max-x depth-gap 40))
            (enum-y title-y))
        (dolist (def enum-defs)
          (let* ((name (plist-get def :name))
                 (literals (plist-get def :literals))
                 (h (+ box-h-base (* (length literals) attr-h)))
                 (node (list :name name :super (plist-get def :super)
                             :attrs nil :parts nil :literals literals
                             :x enum-x :y enum-y :w box-w :h h
                             :kind "enum")))
            (puthash name node node-map)
            (push node all-nodes)
            (setq enum-y (+ enum-y h row-gap))
            (setq max-x (max max-x (+ enum-x box-w)))
            (setq max-y (max max-y (+ enum-y h)))))))
    (setq max-x (+ max-x 40))
    (setq max-y (max (+ max-y 40) 200))
    ;; Generate SVG
    (let ((svg-lines nil))
      (push (sysml2--svg-header max-x max-y) svg-lines)
      (push (sysml2--svg-text 40 30 "Parts Tree (BDD)" "title") svg-lines)
      ;; Composition connector lines (L-shaped with diamond)
      (dolist (comp compositions)
        (let* ((parent-type (plist-get comp :parent-type))
               (child-type (plist-get comp :child-type))
               (parent-node (gethash parent-type node-map))
               (child-node (gethash child-type node-map)))
          (when (and parent-node child-node)
            (let* ((px (+ (plist-get parent-node :x)
                          (plist-get parent-node :w)))
                   (py (+ (plist-get parent-node :y)
                          (/ (plist-get parent-node :h) 2)))
                   (cx (plist-get child-node :x))
                   (cy (+ (plist-get child-node :y)
                          (/ (plist-get child-node :h) 2)))
                   (mid-x (+ px (/ (- cx px) 2))))
              ;; L-shaped connector: parent → mid → child
              (push (sysml2--svg-line px py mid-x py) svg-lines)
              (push (sysml2--svg-line mid-x py mid-x cy) svg-lines)
              (push (sysml2--svg-line mid-x cy cx cy) svg-lines)
              ;; Diamond at parent end
              (let ((d 6))
                (push (format "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>\n"
                              px py (+ px d) (- py d) (+ px (* 2 d)) py (+ px d) (+ py d)
                              (sysml2--svg-color 'line)
                              (sysml2--svg-color 'line))
                      svg-lines))
              ;; Multiplicity label
              (let ((mult (plist-get comp :multiplicity)))
                (when mult
                  (push (sysml2--svg-text (- cx 30) (- cy 6)
                                          (format "[%s]" mult) "stereo")
                        svg-lines)))))))
      ;; Inheritance lines (vertical with triangle)
      (dolist (node all-nodes)
        (let ((super (plist-get node :super)))
          (when super
            (let ((parent-node (gethash super node-map)))
              (when parent-node
                (let ((px (+ (plist-get parent-node :x)
                             (/ (plist-get parent-node :w) 2)))
                      (py (+ (plist-get parent-node :y)
                             (plist-get parent-node :h)))
                      (cx (+ (plist-get node :x)
                             (/ (plist-get node :w) 2)))
                      (cy (plist-get node :y)))
                  (push (sysml2--svg-line px py cx cy) svg-lines)
                  (push (sysml2--svg-triangle cx cy 8) svg-lines)))))))
      ;; Draw boxes
      (dolist (node (nreverse all-nodes))
        (let* ((x (plist-get node :x))
               (y (plist-get node :y))
               (w (plist-get node :w))
               (h (plist-get node :h))
               (name (plist-get node :name))
               (kind (plist-get node :kind))
               (abstract (plist-get node :abstract))
               (attrs (plist-get node :attrs))
               (parts (plist-get node :parts))
               (literals (plist-get node :literals))
               (fill (cond ((string= kind "port") (sysml2--svg-color 'port-fill))
                           ((string= kind "enum") (sysml2--svg-color 'enum-fill))
                           (t (sysml2--svg-color 'part-fill))))
               (stroke (cond ((string= kind "port") (sysml2--svg-color 'port-stroke))
                             ((string= kind "enum") (sysml2--svg-color 'enum-stroke))
                             (t (sysml2--svg-color 'part-stroke)))))
          (push (sysml2--svg-rect x y w h fill stroke) svg-lines)
          (push (sysml2--svg-text (+ x 8) (+ y 15)
                                  (format "<<%s def>>" kind) "stereo")
                svg-lines)
          (push (sysml2--svg-text (+ x 8) (+ y 30)
                                  (if abstract (format "/%s/" name) name)
                                  "label")
                svg-lines)
          (when (or attrs parts literals)
            (push (sysml2--svg-line x (+ y 36) (+ x w) (+ y 36) stroke)
                  svg-lines))
          (let ((item-y (+ y 50)))
            (dolist (attr attrs)
              (push (sysml2--svg-text (+ x 10) item-y attr "sublabel")
                    svg-lines)
              (setq item-y (+ item-y attr-h)))
            (dolist (p parts)
              (push (sysml2--svg-text (+ x 10) item-y
                                      (format "%s : %s%s"
                                              (plist-get p :name)
                                              (plist-get p :type)
                                              (let ((m (plist-get p :multiplicity)))
                                                (if m (format " [%s]" m) "")))
                                      "sublabel")
                    svg-lines)
              (setq item-y (+ item-y attr-h)))
            (dolist (lit literals)
              (push (sysml2--svg-text (+ x 10) item-y lit "sublabel")
                    svg-lines)
              (setq item-y (+ item-y attr-h))))))
      (push (sysml2--svg-footer) svg-lines)
      (apply #'concat (nreverse svg-lines)))))

;; ---------------------------------------------------------------------------
;; Requirement tree diagram
;; ---------------------------------------------------------------------------

(defun sysml2--svg-req-status (name sat-map ver-map)
  "Compute requirement status for NAME using SAT-MAP and VER-MAP.
Returns a symbol: full, no-test, no-satisfy, or gap."
  (let ((satisfied (gethash name sat-map))
        (verified (gethash name ver-map)))
    (cond
     ((and satisfied verified) 'full)
     (satisfied               'no-test)
     (verified                'no-satisfy)
     (t                       'gap))))

(defun sysml2--svg-req-colors (status)
  "Return (FILL . STROKE) for requirement STATUS symbol."
  (pcase status
    ('full       (cons (sysml2--svg-color 'sat-fill)
                       (sysml2--svg-color 'sat-stroke)))
    ('no-test    (cons "#FFF8E1" "#FFC107"))
    ('no-satisfy (cons "#E3F2FD" "#2196F3"))
    ('gap        (cons (sysml2--svg-color 'gap-fill)
                       (sysml2--svg-color 'gap-stroke)))))

(defun sysml2-svg-requirement-tree ()
  "Generate SVG for a requirement tree diagram from the current buffer.
Returns an SVG string."
  (let* ((req-defs (sysml2--model-extract-requirements))
         (req-usages (sysml2--model-extract-requirement-usages))
         (satisfactions (sysml2--model-extract-satisfactions))
         (verifications (sysml2--model-extract-verifications))
         (allocations (sysml2--model-extract-allocations))
         ;; Layout
         (box-w 240)
         (box-h 60)
         (child-box-h 50)
         (col-gap 60)
         (row-gap 20)
         (child-indent 30)
         (x-def 40)
         (y-pos 60)
         (max-x 0) (max-y 0)
         ;; Lookup tables
         (sat-map (make-hash-table :test 'equal))
         (ver-map (make-hash-table :test 'equal))
         (alloc-map (make-hash-table :test 'equal))
         (node-map (make-hash-table :test 'equal))
         (svg-lines nil))
    ;; Build lookups
    (dolist (s satisfactions)
      (let ((req (plist-get s :requirement)))
        (puthash req (cons (plist-get s :by) (gethash req sat-map)) sat-map)))
    (dolist (v verifications)
      (let ((req (plist-get v :requirement)))
        (puthash req (cons (plist-get v :by) (gethash req ver-map)) ver-map)))
    (dolist (a allocations)
      (let ((src (plist-get a :source)))
        (puthash src (plist-get a :target) alloc-map)))
    ;; Also normalize qualified names for lookup
    (dolist (s satisfactions)
      (let* ((req-full (plist-get s :requirement))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-full)))
        (unless (gethash req-short sat-map)
          (puthash req-short (gethash req-full sat-map) sat-map))))
    (dolist (v verifications)
      (let* ((req-full (plist-get v :requirement))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-full)))
        (unless (gethash req-short ver-map)
          (puthash req-short (gethash req-full ver-map) ver-map))))
    ;; SVG header (placeholder dimensions, fixed at end)
    (push (sysml2--svg-header 800 600) svg-lines)
    ;; Arrow marker defs
    (push (concat
           "<defs>\n"
           "  <marker id=\"arrow-sat\" viewBox=\"0 0 10 10\" refX=\"10\" refY=\"5\""
           " markerWidth=\"8\" markerHeight=\"8\" orient=\"auto\">\n"
           "    <path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"" (sysml2--svg-color 'sat-stroke) "\"/>\n"
           "  </marker>\n"
           "  <marker id=\"arrow-ver\" viewBox=\"0 0 10 10\" refX=\"10\" refY=\"5\""
           " markerWidth=\"8\" markerHeight=\"8\" orient=\"auto\">\n"
           "    <path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#2196F3\"/>\n"
           "  </marker>\n"
           "</defs>\n")
          svg-lines)
    (push (sysml2--svg-text 40 30 "Requirements Diagram" "title") svg-lines)
    ;; Column 1: Requirement definitions
    (dolist (req req-defs)
      (let* ((name (plist-get req :name))
             (doc (plist-get req :doc))
             (status (sysml2--svg-req-status name sat-map ver-map))
             (colors (sysml2--svg-req-colors status)))
        (puthash name (list :x x-def :y y-pos :w box-w :h box-h) node-map)
        (push (sysml2--svg-rect x-def y-pos box-w box-h (car colors) (cdr colors))
              svg-lines)
        (push (sysml2--svg-text (+ x-def 8) (+ y-pos 15)
                                "<<requirement def>>" "stereo")
              svg-lines)
        (push (sysml2--svg-text (+ x-def 8) (+ y-pos 32) name "label")
              svg-lines)
        (when doc
          (push (sysml2--svg-text (+ x-def 8) (+ y-pos 48)
                                  (if (> (length doc) 35)
                                      (concat (substring doc 0 32) "...")
                                    doc)
                                  "sublabel")
                svg-lines))
        (setq y-pos (+ y-pos box-h row-gap))
        (setq max-y (max max-y y-pos))))
    ;; Column 2: Requirement usages (with children as separate boxes)
    (let ((x-usage (+ x-def box-w col-gap))
          (usage-y 60))
      (dolist (req req-usages)
        (let* ((name (plist-get req :name))
               (rtype (plist-get req :type))
               (req-id (plist-get req :id))
               (children (plist-get req :children))
               (status (sysml2--svg-req-status name sat-map ver-map))
               (colors (sysml2--svg-req-colors status)))
          ;; Parent requirement box
          (puthash name (list :x x-usage :y usage-y :w box-w :h box-h) node-map)
          (push (sysml2--svg-rect x-usage usage-y box-w box-h
                                  (car colors) (cdr colors))
                svg-lines)
          (push (sysml2--svg-text (+ x-usage 8) (+ usage-y 15)
                                  (if rtype (format "<<requirement : %s>>" rtype)
                                    "<<requirement>>")
                                  "stereo")
                svg-lines)
          (let ((label (if req-id (format "%s [%s]" name req-id) name)))
            (push (sysml2--svg-text (+ x-usage 8) (+ usage-y 32) label "label")
                  svg-lines))
          (setq usage-y (+ usage-y box-h row-gap))
          ;; Children as indented boxes with containment lines
          (dolist (child children)
            (let* ((cname (plist-get child :name))
                   (ctype (plist-get child :type))
                   (cid (plist-get child :id))
                   (cstatus (sysml2--svg-req-status cname sat-map ver-map))
                   (ccolors (sysml2--svg-req-colors cstatus))
                   (cx (+ x-usage child-indent))
                   (cw (- box-w child-indent)))
              (puthash cname (list :x cx :y usage-y :w cw :h child-box-h) node-map)
              (push (sysml2--svg-rect cx usage-y cw child-box-h
                                      (car ccolors) (cdr ccolors))
                    svg-lines)
              (push (sysml2--svg-text (+ cx 8) (+ usage-y 15)
                                      (if ctype (format ": %s" ctype) "<<requirement>>")
                                      "stereo")
                    svg-lines)
              (let ((clabel (if cid (format "%s [%s]" cname cid) cname)))
                (push (sysml2--svg-text (+ cx 8) (+ usage-y 32) clabel "label")
                      svg-lines))
              ;; Containment line from parent
              (push (sysml2--svg-line x-usage (- usage-y (/ row-gap 2))
                                      cx (+ usage-y (/ child-box-h 2))
                                      (sysml2--svg-color 'req-stroke))
                    svg-lines)
              (setq usage-y (+ usage-y child-box-h row-gap))))
          (setq usage-y (+ usage-y 10))
          (setq max-y (max max-y usage-y))))
      (setq max-x (+ x-usage box-w)))
    ;; Relationship arrows: satisfy (green dashed)
    (dolist (s satisfactions)
      (let* ((req-name (plist-get s :requirement))
             (by-name (plist-get s :by))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-name))
             (req-node (or (gethash req-name node-map)
                           (gethash req-short node-map))))
        (when req-node
          (let* ((rx (plist-get req-node :x))
                 (ry (+ (plist-get req-node :y) (plist-get req-node :h)))
                 (label-x rx)
                 (label-y (+ ry 14)))
            (push (sysml2--svg-text label-x label-y
                                    (format "<<satisfy>> %s" by-name)
                                    "stereo")
                  svg-lines)
            (setq max-y (max max-y (+ label-y 10)))))))
    ;; Relationship annotations: verify (blue)
    (dolist (v verifications)
      (let* ((req-name (plist-get v :requirement))
             (by-name (plist-get v :by))
             (req-short (replace-regexp-in-string "\\`.*[:.]" "" req-name))
             (req-node (or (gethash req-name node-map)
                           (gethash req-short node-map))))
        (when req-node
          (let* ((rx (+ (plist-get req-node :x) (plist-get req-node :w)))
                 (ry (+ (plist-get req-node :y) (/ (plist-get req-node :h) 2))))
            (push (sysml2--svg-text (+ rx 8) (+ ry 4)
                                    (format "<<verify>> %s" by-name)
                                    "stereo")
                  svg-lines)
            (setq max-x (max max-x (+ rx 200)))))))
    ;; Legend
    (let ((lx 40) (ly (+ max-y 20)))
      (push (sysml2--svg-rect lx ly 14 14
                              (sysml2--svg-color 'sat-fill)
                              (sysml2--svg-color 'sat-stroke))
            svg-lines)
      (push (sysml2--svg-text (+ lx 20) (+ ly 12) "Full coverage" "sublabel")
            svg-lines)
      (push (sysml2--svg-rect (+ lx 120) ly 14 14 "#FFF8E1" "#FFC107") svg-lines)
      (push (sysml2--svg-text (+ lx 140) (+ ly 12) "Partial" "sublabel") svg-lines)
      (push (sysml2--svg-rect (+ lx 210) ly 14 14
                              (sysml2--svg-color 'gap-fill)
                              (sysml2--svg-color 'gap-stroke))
            svg-lines)
      (push (sysml2--svg-text (+ lx 230) (+ ly 12) "Gap" "sublabel") svg-lines)
      (setq max-y (+ ly 30)))
    (setq max-x (+ max-x 40))
    (setq max-y (max max-y 200))
    (push (sysml2--svg-footer) svg-lines)
    ;; Fix the header with correct dimensions
    (let ((result (apply #'concat (nreverse svg-lines))))
      (replace-regexp-in-string
       "width=\"800\" height=\"600\" viewBox=\"0 0 800 600\""
       (format "width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\""
               max-x max-y max-x max-y)
       result))))

;; ---------------------------------------------------------------------------
;; Dispatcher
;; ---------------------------------------------------------------------------

(defun sysml2-svg-generate (type &optional _scope)
  "Generate SVG source for diagram TYPE.
TYPE is a symbol: tree or requirement-tree.  _SCOPE is unused."
  (pcase type
    ('tree (sysml2-svg-tree))
    ('requirement-tree (sysml2-svg-requirement-tree))
    (_ (error "SVG backend does not support diagram type: %s" type))))

(provide 'sysml2-svg)
;;; sysml2-svg.el ends here
