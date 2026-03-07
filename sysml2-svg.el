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

(defun sysml2-svg-tree ()
  "Generate SVG for a tree/BDD diagram from the current buffer.
Returns an SVG string."
  (let* ((part-defs (sysml2--model-extract-part-defs))
         (port-defs (sysml2--model-extract-typed-defs "port def" "port"))
         (enum-defs (sysml2--model-extract-enum-defs))
         (compositions (sysml2--model-extract-usage-compositions))
         ;; Layout constants
         (box-w 180)
         (box-h-base 40)
         (attr-h 16)
         (col-gap 40)
         (row-gap 30)
         ;; Build node list with computed heights
         (nodes nil)
         (node-map (make-hash-table :test 'equal))
         (x-pos 40)
         (y-pos 60)
         (max-x 0)
         (max-y 0))
    ;; Create nodes for part defs
    (dolist (def part-defs)
      (let* ((name (plist-get def :name))
             (super (plist-get def :super))
             (abstract (plist-get def :abstract))
             (attrs (plist-get def :attributes))
             (parts (plist-get def :parts))
             (num-items (+ (length attrs) (length parts)))
             (h (+ box-h-base (* num-items attr-h)))
             (node (list :name name :super super :abstract abstract
                         :attrs attrs :parts parts
                         :x x-pos :y y-pos :w box-w :h h
                         :kind "part")))
        (puthash name node node-map)
        (push node nodes)
        (setq y-pos (+ y-pos h row-gap))
        (setq max-y (max max-y (+ y-pos h)))))
    (setq x-pos (+ x-pos box-w col-gap))
    (setq y-pos 60)
    ;; Port defs in second column
    (dolist (def port-defs)
      (let* ((name (plist-get def :name))
             (attrs (plist-get def :attributes))
             (h (+ box-h-base (* (length attrs) attr-h)))
             (node (list :name name :super (plist-get def :super)
                         :attrs attrs :parts nil
                         :x x-pos :y y-pos :w box-w :h h
                         :kind "port")))
        (puthash name node node-map)
        (push node nodes)
        (setq y-pos (+ y-pos h row-gap))
        (setq max-y (max max-y (+ y-pos h)))))
    ;; Enum defs in next column
    (when enum-defs
      (setq x-pos (+ x-pos box-w col-gap))
      (setq y-pos 60)
      (dolist (def enum-defs)
        (let* ((name (plist-get def :name))
               (literals (plist-get def :literals))
               (h (+ box-h-base (* (length literals) attr-h)))
               (node (list :name name :super (plist-get def :super)
                           :attrs nil :parts nil :literals literals
                           :x x-pos :y y-pos :w box-w :h h
                           :kind "enum")))
          (puthash name node node-map)
          (push node nodes)
          (setq y-pos (+ y-pos h row-gap))
          (setq max-y (max max-y (+ y-pos h))))))
    (setq max-x (+ x-pos box-w 40))
    (setq max-y (max max-y 200))
    ;; Generate SVG
    (let ((svg-lines nil))
      (push (sysml2--svg-header max-x max-y) svg-lines)
      ;; Title
      (push (sysml2--svg-text 40 30 "Parts Tree (BDD)" "title") svg-lines)
      ;; Composition lines (behind boxes)
      (dolist (comp compositions)
        (let* ((parent-type (plist-get comp :parent-type))
               (child-type (plist-get comp :child-type))
               (parent-node (gethash parent-type node-map))
               (child-node (gethash child-type node-map)))
          (when (and parent-node child-node)
            (let ((px (+ (plist-get parent-node :x)
                         (plist-get parent-node :w)))
                  (py (+ (plist-get parent-node :y)
                         (/ (plist-get parent-node :h) 2)))
                  (cx (plist-get child-node :x))
                  (cy (+ (plist-get child-node :y)
                         (/ (plist-get child-node :h) 2))))
              (push (sysml2--svg-line px py cx cy) svg-lines)
              ;; Diamond for composition
              (let ((d 6))
                (push (format "<polygon points=\"%d,%d %d,%d %d,%d %d,%d\" fill=\"%s\" stroke=\"%s\" stroke-width=\"1.5\"/>\n"
                              px py (+ px d) (- py d) (+ px (* 2 d)) py (+ px d) (+ py d)
                              (sysml2--svg-color 'line)
                              (sysml2--svg-color 'line))
                      svg-lines))))))
      ;; Inheritance lines
      (dolist (node nodes)
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
      (dolist (node (nreverse nodes))
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
          ;; Box
          (push (sysml2--svg-rect x y w h fill stroke) svg-lines)
          ;; Stereotype
          (push (sysml2--svg-text (+ x 8) (+ y 15)
                                  (format "<<%s def>>" kind) "stereo")
                svg-lines)
          ;; Name
          (push (sysml2--svg-text (+ x 8) (+ y 30)
                                  (if abstract (format "/%s/" name) name)
                                  "label")
                svg-lines)
          ;; Separator line
          (when (or attrs parts literals)
            (push (sysml2--svg-line x (+ y 36) (+ x w) (+ y 36) stroke) svg-lines))
          ;; Attributes
          (let ((item-y (+ y 50)))
            (dolist (attr attrs)
              (push (sysml2--svg-text (+ x 10) item-y attr "sublabel") svg-lines)
              (setq item-y (+ item-y attr-h)))
            ;; Sub-parts
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
            ;; Enum literals
            (dolist (lit literals)
              (push (sysml2--svg-text (+ x 10) item-y lit "sublabel") svg-lines)
              (setq item-y (+ item-y attr-h))))))
      (push (sysml2--svg-footer) svg-lines)
      (apply #'concat (nreverse svg-lines)))))

;; ---------------------------------------------------------------------------
;; Requirement tree diagram
;; ---------------------------------------------------------------------------

(defun sysml2-svg-requirement-tree ()
  "Generate SVG for a requirement tree diagram from the current buffer.
Returns an SVG string."
  (let* ((req-defs (sysml2--model-extract-requirements))
         (req-usages (sysml2--model-extract-requirement-usages))
         (satisfactions (sysml2--model-extract-satisfactions))
         ;; Layout
         (box-w 220)
         (box-h 60)
         (child-h 28)
         (col-gap 40)
         (row-gap 20)
         (x-pos 40)
         (y-pos 60)
         (max-x 0)
         (max-y 0)
         (sat-map (make-hash-table :test 'equal))
         (svg-lines nil))
    ;; Build satisfaction lookup
    (dolist (s satisfactions)
      (puthash (plist-get s :requirement) (plist-get s :by) sat-map))
    ;; Layout requirement defs
    (push (sysml2--svg-header 800 600) svg-lines) ; placeholder, will fix
    (push (sysml2--svg-text 40 30 "Requirements" "title") svg-lines)
    ;; Requirement definitions
    (dolist (req req-defs)
      (let* ((name (plist-get req :name))
             (doc (plist-get req :doc))
             (satisfied-by (gethash name sat-map))
             (fill (if satisfied-by
                       (sysml2--svg-color 'sat-fill)
                     (sysml2--svg-color 'gap-fill)))
             (stroke (if satisfied-by
                         (sysml2--svg-color 'sat-stroke)
                       (sysml2--svg-color 'gap-stroke))))
        (push (sysml2--svg-rect x-pos y-pos box-w box-h fill stroke) svg-lines)
        (push (sysml2--svg-text (+ x-pos 8) (+ y-pos 15)
                                "<<requirement def>>" "stereo")
              svg-lines)
        (push (sysml2--svg-text (+ x-pos 8) (+ y-pos 32) name "label") svg-lines)
        (when doc
          (push (sysml2--svg-text (+ x-pos 8) (+ y-pos 48)
                                  (if (> (length doc) 30)
                                      (concat (substring doc 0 27) "...")
                                    doc)
                                  "sublabel")
                svg-lines))
        (when satisfied-by
          (push (sysml2--svg-text (+ x-pos 8) (+ y-pos box-h -4)
                                  (format "satisfied by %s" satisfied-by)
                                  "stereo")
                svg-lines))
        (setq y-pos (+ y-pos box-h row-gap))
        (setq max-y (max max-y y-pos))))
    ;; Requirement usages in second column
    (setq x-pos (+ x-pos box-w col-gap))
    (setq y-pos 60)
    (dolist (req req-usages)
      (let* ((name (plist-get req :name))
             (rtype (plist-get req :type))
             (children (plist-get req :children))
             (h (+ box-h (* (length children) child-h))))
        (push (sysml2--svg-rect x-pos y-pos box-w h
                                (sysml2--svg-color 'req-fill)
                                (sysml2--svg-color 'req-stroke))
              svg-lines)
        (push (sysml2--svg-text (+ x-pos 8) (+ y-pos 15)
                                (if rtype (format "<<requirement : %s>>" rtype)
                                  "<<requirement>>")
                                "stereo")
              svg-lines)
        (push (sysml2--svg-text (+ x-pos 8) (+ y-pos 32) name "label") svg-lines)
        ;; Children
        (let ((cy (+ y-pos 50)))
          (dolist (child children)
            (let ((cname (plist-get child :name)))
              (push (sysml2--svg-line (+ x-pos 10) cy (+ x-pos box-w -10) cy
                                      (sysml2--svg-color 'req-stroke) "3")
                    svg-lines)
              (push (sysml2--svg-text (+ x-pos 14) (+ cy 16) cname "sublabel")
                    svg-lines)
              (setq cy (+ cy child-h)))))
        (setq y-pos (+ y-pos h row-gap))
        (setq max-y (max max-y y-pos))))
    (setq max-x (+ x-pos box-w 40))
    (setq max-y (max max-y 200))
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
