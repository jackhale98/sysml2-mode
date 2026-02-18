;;; sysml2-plantuml.el --- PlantUML transforms for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Pure transformation engine: parse SysML v2 buffer text and return
;; PlantUML strings.  No process invocation — that belongs in
;; `sysml2-diagram.el'.
;;
;; Five diagram generators:
;;   - tree (BDD-like class diagram)
;;   - interconnection (IBD component diagram)
;;   - state-machine
;;   - action-flow (activity diagram)
;;   - requirement-tree

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-plantuml-tree' -- BDD-like class diagram
;;   `sysml2-plantuml-interconnection' -- IBD component diagram
;;   `sysml2-plantuml-state-machine' -- State diagram
;;   `sysml2-plantuml-action-flow' -- Activity diagram
;;   `sysml2-plantuml-requirement-tree' -- Requirement diagram
;;   `sysml2-plantuml-generate' -- Dispatcher by diagram type
;;   `sysml2-plantuml-detect-type-at-point' -- Auto-detect diagram type

(require 'sysml2-lang)
(require 'sysml2-navigation)

;; --- Preamble Helper ---

(defun sysml2--puml-preamble ()
  "Return a list of PlantUML preamble lines for page sizing and layout.
Reads `sysml2-diagram-page-size' and `sysml2-diagram-direction'."
  (let ((lines nil))
    (when (eq sysml2-diagram-direction 'left-to-right)
      (push "left to right direction" lines))
    (when sysml2-diagram-page-size
      (let ((w (car sysml2-diagram-page-size))
            (h (cdr sysml2-diagram-page-size)))
        (push (format "scale max %d*%d" w h) lines)))
    (nreverse lines)))

;; --- Scoping Helper ---

(defun sysml2--puml-find-def-bounds (def-keyword name)
  "Find (BEG . END) of the body of DEF-KEYWORD NAME definition.
DEF-KEYWORD is e.g. \"part def\", NAME is the definition name.
Returns nil if not found."
  (save-excursion
    (goto-char (point-min))
    (let ((re (concat "\\b" (regexp-quote def-keyword)
                      "[ \t]+" (regexp-quote name) "\\b")))
      (when (re-search-forward re nil t)
        (let ((def-start (match-beginning 0)))
          (when (re-search-forward "{" nil t)
            (let ((brace-start (1- (point))))
              (goto-char brace-start)
              (condition-case nil
                  (progn
                    (forward-sexp 1)
                    (cons def-start (point)))
                (scan-error nil)))))))))

;; --- Extraction Functions ---

(defun sysml2--puml-extract-typed-defs (def-keyword stereotype &optional buffer)
  "Extract definitions matching DEF-KEYWORD from BUFFER.
DEF-KEYWORD is e.g. \"port def\", \"interface def\".
STEREOTYPE is the PlantUML stereotype string.
Returns list of plists (:name :super :stereotype :attributes)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\b" (regexp-quote def-keyword) "[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (super (match-string-no-properties 2))
                (match-end (match-end 0))
                (attrs nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq body-end (point)))
                    (scan-error (setq body-end (point-max))))
                  (goto-char (1+ brace-start))
                  (while (re-search-forward
                          (concat "\\battribute[ \t]+"
                                  "\\(" sysml2--identifier-regexp "\\)")
                          (1- body-end) t)
                    (push (match-string-no-properties 1) attrs)))))
            (push (list :name name :super super
                        :stereotype stereotype
                        :attributes (nreverse attrs))
                  defs)))
        (nreverse defs)))))

(defun sysml2--puml-extract-enum-defs (&optional buffer)
  "Extract enum/enumeration definitions from BUFFER.
Returns list of plists (:name :super :stereotype :attributes).
Handles both `enum def` and `enumeration def` keywords, and both
`enum name;` literals and `{name;name;}` inline forms."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\b\\(?:enum\\|enumeration\\)[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (super (match-string-no-properties 2))
                (match-end (match-end 0))
                (literals nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq body-end (point)))
                    (scan-error (setq body-end (point-max))))
                  (let ((body (buffer-substring-no-properties
                               (1+ brace-start) (1- body-end))))
                    ;; Try "enum name;" form first
                    (goto-char (1+ brace-start))
                    (while (re-search-forward
                            (concat "\\benum[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)")
                            (1- body-end) t)
                      (push (match-string-no-properties 1) literals))
                    ;; If no "enum X" found, try bare "name;" form
                    ;; (e.g., {black;grey;red;} or {on;off;})
                    (unless literals
                      (let ((trimmed (string-trim body)))
                        (when (string-match-p "^[A-Za-z_]" trimmed)
                          (dolist (part (split-string trimmed "[;\n]+" t))
                            (let ((lit (string-trim part)))
                              (when (string-match
                                     (concat "^\\(" sysml2--identifier-regexp "\\)$")
                                     lit)
                                (push (match-string 1 lit) literals)))))))))))
            (push (list :name name :super super
                        :stereotype "enumeration"
                        :attributes (nreverse literals))
                  defs)))
        (nreverse defs)))))

(defun sysml2--puml-extract-part-defs (&optional buffer)
  "Extract part definitions from BUFFER (defaults to current).
Returns list of plists (:name :super :abstract :attributes :parts)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\(?:\\(abstract\\|variation\\)[ \t]+\\)?"
                        "part[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let* ((modifier (match-string-no-properties 1))
                 (name (match-string-no-properties 2))
                 (super (match-string-no-properties 3))
                 (match-end (match-end 0))
                 (attrs nil)
                 (parts nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn
                        (forward-sexp 1)
                        (setq body-end (point)))
                    (scan-error
                     (setq body-end (point-max))))
                  (let ((beg (1+ brace-start))
                        (end (1- body-end)))
                    (goto-char beg)
                    (while (re-search-forward
                            (concat "\\battribute[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)")
                            end t)
                      (push (match-string-no-properties 1) attrs))
                    (goto-char beg)
                    ;; Match both "part x : Type" and "variant part x : Type"
                    (while (re-search-forward
                            (concat "\\(?:\\bvariant[ \t]+\\)?\\bpart[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)"
                                    "[ \t]*:[ \t]*"
                                    "\\(" sysml2--qualified-name-regexp "\\)"
                                    "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?")
                            end t)
                      (save-excursion
                        (goto-char (match-beginning 0))
                        (unless (looking-at "\\(?:\\bvariant[ \t]+\\)?\\bpart[ \t]+def\\b")
                          (push (list :name (match-string-no-properties 1)
                                      :type (match-string-no-properties 2)
                                      :multiplicity (match-string-no-properties 3))
                                parts))))))))
            (push (list :name name
                        :super super
                        :abstract (when (equal modifier "abstract") t)
                        :attributes (nreverse attrs)
                        :parts (nreverse parts))
                  defs)))
        (nreverse defs)))))

(defun sysml2--puml-extract-part-usages (&optional beg end)
  "Extract part usages within region BEG..END.
Returns list of (:name :type :multiplicity)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bpart[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(" sysml2--qualified-name-regexp "\\)"
                      "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?")
              end t)
        ;; Skip "part def" matches
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bpart[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :type (match-string-no-properties 2)
                        :multiplicity (match-string-no-properties 3))
                  results)))))
    (nreverse results)))

(defun sysml2--puml-extract-port-usages (&optional beg end)
  "Extract port usages within region BEG..END.
Returns list of (:name :type :conjugated :direction)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bport[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(~?\\)"
                      "\\(" sysml2--qualified-name-regexp "\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bport[ \t]+def\\b")
            (let ((name (match-string-no-properties 1))
                  (conj (match-string-no-properties 2))
                  (type (match-string-no-properties 3)))
              (push (list :name name
                          :type type
                          :conjugated (string= conj "~")
                          :direction nil)
                    results))))))
    (nreverse results)))

(defun sysml2--puml-extract-connections (&optional beg end)
  "Extract connection usages within region BEG..END.
Returns list of (:name :source :target)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bconnection[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "\\(?:[ \t]*:[ \t]*" sysml2--qualified-name-regexp "\\)?"
                      "[ \t\n]*connect[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)"
                      "[ \t]+to[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bconnection[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :source (match-string-no-properties 2)
                        :target (match-string-no-properties 3))
                  results)))))
    (nreverse results)))

(defun sysml2--puml-extract-states (&optional beg end)
  "Extract state declarations within region BEG..END.
Returns list of (:name)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bstate[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bstate[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1))
                  results)))))
    (nreverse results)))

(defun sysml2--puml-extract-transitions (&optional beg end)
  "Extract transitions within region BEG..END.
Returns list of (:name :from :trigger :to)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\btransition[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)")
              end t)
        (let ((name (match-string-no-properties 1))
              (trans-start (match-end 0))
              (from nil) (trigger nil) (to nil))
          ;; Look ahead for first/accept/then within a reasonable range
          (save-excursion
            (goto-char trans-start)
            (let ((search-end (min end (+ trans-start 300))))
              (when (re-search-forward
                     (concat "\\bfirst[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)")
                     search-end t)
                (setq from (match-string-no-properties 1)))
              (goto-char trans-start)
              (when (re-search-forward
                     (concat "\\baccept[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)")
                     search-end t)
                (setq trigger (match-string-no-properties 1)))
              (goto-char trans-start)
              (when (re-search-forward
                     (concat "\\bthen[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
                     search-end t)
                (setq to (match-string-no-properties 1)))))
          (when (and from to)
            (push (list :name name :from from :trigger trigger :to to)
                  results)))))
    (nreverse results)))

(defun sysml2--puml-extract-actions (&optional beg end)
  "Extract action usages within region BEG..END.
Returns list of (:name :type)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\baction[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(" sysml2--qualified-name-regexp "\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\baction[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :type (match-string-no-properties 2))
                  results)))))
    (nreverse results)))

(defun sysml2--puml-extract-successions (&optional beg end)
  "Extract succession relationships (first X then Y) within BEG..END.
Returns list of (:from :to)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bfirst[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]+then[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
              end t)
        ;; Skip successions that are part of transitions
        (save-excursion
          (goto-char (match-beginning 0))
          (let ((line-start (line-beginning-position)))
            (goto-char line-start)
            (unless (looking-at ".*\\btransition\\b")
              ;; Also check if this first/then is inside a transition block
              ;; by looking at previous non-blank line
              (let ((in-transition nil))
                (save-excursion
                  (forward-line -1)
                  (while (and (not (bobp))
                              (looking-at "^[ \t]*$"))
                    (forward-line -1))
                  (when (looking-at ".*\\b\\(transition\\|accept\\)\\b")
                    (setq in-transition t)))
                (unless in-transition
                  (push (list :from (match-string-no-properties 1)
                              :to (match-string-no-properties 2))
                        results))))))))
    (nreverse results)))

(defun sysml2--puml-extract-requirements (&optional buffer)
  "Extract requirement definitions from BUFFER.
Returns list of (:name :doc :subject)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward
                (concat "\\brequirement[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")
                nil t)
          (let ((name (match-string-no-properties 1))
                (match-end (match-end 0))
                (doc nil) (subject nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn
                        (forward-sexp 1)
                        (setq body-end (point)))
                    (scan-error
                     (setq body-end (point-max))))
                  (goto-char (1+ brace-start))
                  (when (re-search-forward
                         "\\bdoc[ \t]+/\\*[ \t]*\\([^*]*\\)\\*/"
                         body-end t)
                    (setq doc (string-trim (match-string-no-properties 1))))
                  (goto-char (1+ brace-start))
                  (when (re-search-forward
                         (concat "\\bsubject[ \t]+"
                                 sysml2--identifier-regexp
                                 "[ \t]*:[ \t]*"
                                 "\\(" sysml2--qualified-name-regexp "\\)")
                         body-end t)
                    (setq subject (match-string-no-properties 1))))))
            (push (list :name name :doc doc :subject subject)
                  results)))
        (nreverse results)))))

(defun sysml2--puml-extract-satisfactions (&optional buffer)
  "Extract satisfy relationships from BUFFER.
Returns list of (:requirement :by)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward
                (concat "\\bsatisfy[ \t]+requirement[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)"
                        "[ \t]+by[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)")
                nil t)
          (push (list :requirement (match-string-no-properties 1)
                      :by (match-string-no-properties 2))
                results))
        (nreverse results)))))

;; --- PlantUML Generators ---

(defun sysml2-plantuml-tree (&optional buffer)
  "Generate a BDD-like class diagram from BUFFER.
Returns a PlantUML string with @startuml...@enduml.
Extracts part defs, port defs, interface defs, item defs,
action defs, constraint defs, and enum defs, each rendered
with its SysML v2 stereotype."
  (with-current-buffer (or buffer (current-buffer))
    (let ((part-defs (sysml2--puml-extract-part-defs))
          (port-defs (sysml2--puml-extract-typed-defs "port def" "port"))
          (iface-defs (sysml2--puml-extract-typed-defs "interface def" "interface"))
          (item-defs (sysml2--puml-extract-typed-defs "item def" "item"))
          (action-defs (sysml2--puml-extract-typed-defs "action def" "action"))
          (constraint-defs (sysml2--puml-extract-typed-defs "constraint def" "constraint"))
          (enum-defs (sysml2--puml-extract-enum-defs))
          (lines nil))
      (push "@startuml" lines)
      (dolist (l (sysml2--puml-preamble)) (push l lines))
      (push "" lines)
      ;; Skinparam for visual differentiation
      (push "skinparam class {" lines)
      (push "  BackgroundColor<<block>> LightBlue" lines)
      (push "  BackgroundColor<<port>> LightGreen" lines)
      (push "  BackgroundColor<<interface>> LightYellow" lines)
      (push "  BackgroundColor<<item>> WhiteSmoke" lines)
      (push "  BackgroundColor<<action>> LightCoral" lines)
      (push "  BackgroundColor<<constraint>> Wheat" lines)
      (push "  BackgroundColor<<enumeration>> Plum" lines)
      (push "}" lines)
      (push "" lines)
      ;; Part def declarations
      (dolist (def part-defs)
        (let ((name (plist-get def :name))
              (abstract (plist-get def :abstract))
              (attrs (plist-get def :attributes)))
          (if abstract
              (push (format "abstract class %s <<block>>" name) lines)
            (push (format "class %s <<block>>" name) lines))
          (when attrs
            (push (format "class %s {" name) lines)
            (dolist (attr attrs)
              (push (format "  %s" attr) lines))
            (push "}" lines))))
      (push "" lines)
      ;; Other typed definitions
      (dolist (typed-defs (list port-defs iface-defs item-defs
                                action-defs constraint-defs))
        (dolist (def typed-defs)
          (let ((name (plist-get def :name))
                (stereo (plist-get def :stereotype))
                (attrs (plist-get def :attributes)))
            (push (format "class %s <<%s>>" name stereo) lines)
            (when attrs
              (push (format "class %s {" name) lines)
              (dolist (attr attrs)
                (push (format "  %s" attr) lines))
              (push "}" lines)))))
      (push "" lines)
      ;; Enum definitions
      (dolist (def enum-defs)
        (let ((name (plist-get def :name))
              (literals (plist-get def :attributes)))
          (push (format "enum %s <<enumeration>>" name) lines)
          (when literals
            (push (format "enum %s {" name) lines)
            (dolist (lit literals)
              (push (format "  %s" lit) lines))
            (push "}" lines))))
      (push "" lines)
      ;; Inheritance arrows — part defs
      (dolist (def part-defs)
        (let ((name (plist-get def :name))
              (super (plist-get def :super)))
          (when super
            (push (format "%s <|-- %s" super name) lines))))
      ;; Inheritance arrows — other typed defs
      (dolist (typed-defs (list port-defs iface-defs item-defs
                                action-defs constraint-defs enum-defs))
        (dolist (def typed-defs)
          (let ((name (plist-get def :name))
                (super (plist-get def :super)))
            (when super
              (push (format "%s <|-- %s" super name) lines)))))
      (push "" lines)
      ;; Composition arrows for parts
      (dolist (def part-defs)
        (let ((name (plist-get def :name))
              (parts (plist-get def :parts)))
          (dolist (part parts)
            (let ((ptype (plist-get part :type))
                  (mult (plist-get part :multiplicity)))
              (if mult
                  (push (format "%s *-- \"%s\" %s" name mult ptype) lines)
                (push (format "%s *-- %s" name ptype) lines))))))
      (push "" lines)
      (push "@enduml" lines)
      (mapconcat #'identity (nreverse lines) "\n"))))

(defun sysml2-plantuml-interconnection (part-def-name &optional buffer)
  "Generate an IBD component diagram for PART-DEF-NAME from BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((bounds (sysml2--puml-find-def-bounds "part def" part-def-name))
          (lines nil))
      (push "@startuml" lines)
      (dolist (l (sysml2--puml-preamble)) (push l lines))
      (push "" lines)
      (if (not bounds)
          (push (format "note \"part def %s not found\" as N1" part-def-name) lines)
        (let* ((beg (car bounds))
               (end (cdr bounds))
               (parts (sysml2--puml-extract-part-usages beg end))
               (ports (sysml2--puml-extract-port-usages beg end))
               (conns (sysml2--puml-extract-connections beg end)))
          (push (format "component \"%s\" as %s {" part-def-name part-def-name) lines)
          (dolist (part parts)
            (let ((pname (plist-get part :name))
                  (ptype (plist-get part :type)))
              (push (format "  component \"%s : %s\" as %s" pname ptype pname) lines)))
          (dolist (port ports)
            (let ((pname (plist-get port :name))
                  (ptype (plist-get port :type)))
              (push (format "  portin \"%s : %s\" as %s" pname ptype pname) lines)))
          (push "}" lines)
          (push "" lines)
          (dolist (conn conns)
            (let ((cname (plist-get conn :name))
                  (src (plist-get conn :source))
                  (tgt (plist-get conn :target)))
              ;; Use base component names (before dots)
              (let ((src-base (car (split-string src "\\.")))
                    (tgt-base (car (split-string tgt "\\."))))
                (push (format "%s -- %s : %s" src-base tgt-base cname) lines))))))
      (push "" lines)
      (push "@enduml" lines)
      (mapconcat #'identity (nreverse lines) "\n"))))

(defun sysml2-plantuml-state-machine (state-def-name &optional buffer)
  "Generate a state diagram for STATE-DEF-NAME from BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((bounds (sysml2--puml-find-def-bounds "state def" state-def-name))
          (lines nil))
      (push "@startuml" lines)
      (dolist (l (sysml2--puml-preamble)) (push l lines))
      (push "" lines)
      (if (not bounds)
          (push (format "note \"state def %s not found\" as N1" state-def-name) lines)
        (let* ((beg (car bounds))
               (end (cdr bounds))
               (states (sysml2--puml-extract-states beg end))
               (transitions (sysml2--puml-extract-transitions beg end))
               (first-state (when states
                              (plist-get (car states) :name))))
          ;; Entry transition
          (when first-state
            (push (format "[*] --> %s" first-state) lines))
          (push "" lines)
          ;; State declarations
          (dolist (st states)
            (push (format "state %s" (plist-get st :name)) lines))
          (push "" lines)
          ;; Transitions
          (dolist (tr transitions)
            (let ((from (plist-get tr :from))
                  (to (plist-get tr :to))
                  (trigger (plist-get tr :trigger)))
              (if trigger
                  (push (format "%s --> %s : %s" from to trigger) lines)
                (push (format "%s --> %s" from to) lines))))))
      (push "" lines)
      (push "@enduml" lines)
      (mapconcat #'identity (nreverse lines) "\n"))))

(defun sysml2-plantuml-action-flow (action-def-name &optional buffer)
  "Generate an activity diagram for ACTION-DEF-NAME from BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((bounds (sysml2--puml-find-def-bounds "action def" action-def-name))
          (lines nil))
      (push "@startuml" lines)
      (dolist (l (sysml2--puml-preamble)) (push l lines))
      (push "" lines)
      (if (not bounds)
          (push (format "note \"action def %s not found\" as N1" action-def-name) lines)
        (let* ((beg (car bounds))
               (end (cdr bounds))
               (actions (sysml2--puml-extract-actions beg end))
               (succs (sysml2--puml-extract-successions beg end)))
          (push "start" lines)
          (push "" lines)
          ;; Action nodes
          (dolist (act actions)
            (push (format ":%s;" (plist-get act :name)) lines))
          (push "" lines)
          ;; Flow arrows from successions
          (dolist (succ succs)
            (let ((from (plist-get succ :from))
                  (to (plist-get succ :to)))
              (push (format ":%s;" from) lines)
              (push "-->" lines)
              (push (format ":%s;" to) lines)))
          (push "" lines)
          (push "stop" lines)))
      (push "" lines)
      (push "@enduml" lines)
      (mapconcat #'identity (nreverse lines) "\n"))))

(defun sysml2-plantuml-requirement-tree (&optional buffer)
  "Generate a requirement class diagram from BUFFER."
  (with-current-buffer (or buffer (current-buffer))
    (let ((reqs (sysml2--puml-extract-requirements))
          (sats (sysml2--puml-extract-satisfactions))
          (lines nil))
      (push "@startuml" lines)
      (dolist (l (sysml2--puml-preamble)) (push l lines))
      (push "" lines)
      ;; Requirement classes
      (dolist (req reqs)
        (let ((name (plist-get req :name))
              (doc (plist-get req :doc)))
          (push (format "class %s <<requirement>> {" name) lines)
          (when doc
            (push (format "  text = \"%s\"" doc) lines))
          (push "}" lines)))
      (push "" lines)
      ;; Satisfy dependencies
      (dolist (sat sats)
        (let ((req-name (plist-get sat :requirement))
              (by-name (plist-get sat :by)))
          (push (format "%s ..> %s : <<satisfy>>" by-name req-name) lines)))
      (push "" lines)
      (push "@enduml" lines)
      (mapconcat #'identity (nreverse lines) "\n"))))

;; --- Dispatcher ---

(defun sysml2-plantuml-generate (diagram-type &optional scope-name buffer)
  "Generate PlantUML for DIAGRAM-TYPE, optionally scoped to SCOPE-NAME.
DIAGRAM-TYPE is one of: `tree', `interconnection', `state-machine',
`action-flow', `requirement-tree'.
BUFFER defaults to current buffer."
  (let ((buf (or buffer (current-buffer))))
    (pcase diagram-type
      ('tree (sysml2-plantuml-tree buf))
      ('interconnection
       (unless scope-name
         (user-error "Interconnection diagram requires a part def name"))
       (sysml2-plantuml-interconnection scope-name buf))
      ('state-machine
       (unless scope-name
         (user-error "State machine diagram requires a state def name"))
       (sysml2-plantuml-state-machine scope-name buf))
      ('action-flow
       (unless scope-name
         (user-error "Action flow diagram requires an action def name"))
       (sysml2-plantuml-action-flow scope-name buf))
      ('requirement-tree (sysml2-plantuml-requirement-tree buf))
      (_ (user-error "Unknown diagram type: %s" diagram-type)))))

(defun sysml2-plantuml-detect-type-at-point ()
  "Detect the appropriate diagram type at point.
Returns (TYPE . SCOPE-NAME) where TYPE is a symbol and SCOPE-NAME
may be nil."
  (save-excursion
    (let ((func-name (sysml2-which-function)))
      (cond
       ;; Check enclosing definition keyword
       ((and func-name
             (save-excursion
               (when (re-search-backward
                      (concat "\\bstate[ \t]+def[ \t]+"
                              (regexp-quote func-name) "\\b")
                      nil t)
                 t)))
        (cons 'state-machine func-name))
       ((and func-name
             (save-excursion
               (when (re-search-backward
                      (concat "\\baction[ \t]+def[ \t]+"
                              (regexp-quote func-name) "\\b")
                      nil t)
                 t)))
        (cons 'action-flow func-name))
       ((and func-name
             (save-excursion
               (when (re-search-backward
                      (concat "\\brequirement[ \t]+def[ \t]+"
                              (regexp-quote func-name) "\\b")
                      nil t)
                 t)))
        (cons 'requirement-tree nil))
       ((and func-name
             (save-excursion
               (when (re-search-backward
                      (concat "\\bpart[ \t]+def[ \t]+"
                              (regexp-quote func-name) "\\b")
                      nil t)
                 t)))
        (cons 'interconnection func-name))
       (t
        (cons 'tree nil))))))

(provide 'sysml2-plantuml)
;;; sysml2-plantuml.el ends here
