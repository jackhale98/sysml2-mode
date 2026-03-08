;;; sysml2-fmi.el --- FMI/FMU integration for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; FMI 3.0 integration for sysml2-mode.  Provides:
;;   - FMU inspector (parse modelDescription.xml from .fmu ZIP)
;;   - Interface contract extraction (SysML ports → FMI variables)
;;   - Modelica stub generation (partial model from SysML part def)
;;   - Interface validation (compare FMU against SysML port defs)
;;
;; When `sysml2-cli' is available on exec-path, interface extraction,
;; Modelica generation, and SSP export use the tree-sitter AST via
;; sysml2-cli instead of regex-based extraction.  FMU inspection and
;; display remain in Emacs (they are UI-only operations).

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-fmi-inspect-fmu' -- Open FMU inspector buffer
;;   `sysml2-fmi-extract-interfaces' -- Extract FMI interface contracts
;;   `sysml2-fmi-generate-modelica' -- Generate Modelica stub
;;   `sysml2-fmi-generate-all-modelica' -- Generate stubs for all parts
;;   `sysml2-fmi-compile-fmu' -- Compile .mo to .fmu via OpenModelica
;;   `sysml2-fmi-compile-all-fmus' -- Batch compile all .mo files
;;   `sysml2-fmi-validate-interfaces' -- Validate FMU against SysML
;;   `sysml2-fmi-validate-all' -- Validate all FMUs against SysML
;;   `sysml2-fmi-dashboard' -- Status overview of FMI export pipeline

(require 'cl-lib)
(require 'sysml2-vars)
(require 'sysml2-lang)
(require 'dom)

(require 'sysml2-model)

;; --- sysml2-cli backend ---

(defun sysml2--cli-available-p ()
  "Return non-nil if sysml2-cli is available on exec-path."
  (executable-find (or (bound-and-true-p sysml2-simulate-executable)
                       "sysml2-cli")))

(defun sysml2--cli-executable ()
  "Return the sysml2-cli executable path."
  (or (bound-and-true-p sysml2-simulate-executable) "sysml2-cli"))

(defun sysml2--cli-call-json (&rest args)
  "Call sysml2-cli with ARGS and parse JSON output.
Prepends `-f json' to ARGS.  Returns parsed JSON as plists/lists."
  (let* ((exe (sysml2--cli-executable))
         (all-args (append (list "-f" "json") args))
         (output (with-temp-buffer
                   (apply #'call-process exe nil t nil all-args)
                   (buffer-string))))
    (when (and output (not (string-empty-p (string-trim output))))
      (json-parse-string output :object-type 'plist :array-type 'list))))

(defun sysml2--cli-call-text (&rest args)
  "Call sysml2-cli with ARGS and return text output."
  (let ((exe (sysml2--cli-executable)))
    (with-temp-buffer
      (apply #'call-process exe nil t nil args)
      (buffer-string))))

;; --- Guard ---

(defun sysml2--fmi-check-libxml ()
  "Signal an error if Emacs was not built with libxml2 support."
  (unless (fboundp 'libxml-parse-xml-region)
    (user-error "sysml2-fmi requires Emacs built with libxml2 support")))

;; --- Default Type Mapping ---

(defconst sysml2--fmi-default-type-mapping
  '(("Real" . "Float64")
    ("Integer" . "Int32")
    ("Boolean" . "Boolean")
    ("String" . "String")
    ("ScalarValues::Real" . "Float64")
    ("ScalarValues::Integer" . "Int32")
    ("ScalarValues::Boolean" . "Boolean")
    ("ScalarValues::String" . "String"))
  "Default mapping from SysML types to FMI 3.0 variable types.")

;; --- XML Parsing (FMU Inspector) ---

(defun sysml2--fmi-unzip-fmu (fmu-path)
  "Unzip FMU-PATH to a temporary directory.
Returns alist with keys `dir', `model-description'."
  (let ((tmp-dir (make-temp-file "sysml2-fmu-" t)))
    (unless (= 0 (call-process "unzip" nil nil nil "-o" "-q"
                                (expand-file-name fmu-path) "-d" tmp-dir))
      (user-error "Failed to unzip FMU: %s" fmu-path))
    (let ((xml-path (expand-file-name "modelDescription.xml" tmp-dir)))
      (unless (file-exists-p xml-path)
        (user-error "FMU does not contain modelDescription.xml"))
      (list (cons 'dir tmp-dir)
            (cons 'model-description xml-path)))))

(defun sysml2--fmi-parse-model-description (xml-path)
  "Parse FMI modelDescription.xml at XML-PATH.
Returns plist with `:fmi-version', `:model-name', `:guid',
`:variables', `:model-structure'."
  (sysml2--fmi-check-libxml)
  (let* ((dom (with-temp-buffer
                (insert-file-contents xml-path)
                (libxml-parse-xml-region (point-min) (point-max))))
         (root dom)
         (fmi-version (dom-attr root 'fmiVersion))
         (model-name (dom-attr root 'modelName))
         (guid (or (dom-attr root 'instantiationToken)
                   (dom-attr root 'guid)))
         (variables (sysml2--fmi-extract-variables root))
         (structure (sysml2--fmi-extract-model-structure root)))
    (list :fmi-version fmi-version
          :model-name model-name
          :guid guid
          :variables variables
          :model-structure structure)))

(defun sysml2--fmi-extract-variables (dom)
  "Extract model variables from DOM.
Returns list of plists with `:name', `:type', `:causality',
`:variability', `:start'."
  (let ((results nil)
        (mv-node (car (dom-by-tag dom 'ModelVariables))))
    (when mv-node
      (dolist (child (dom-children mv-node))
        (when (and (listp child) (symbolp (car child)))
          (let ((tag-name (symbol-name (car child)))
                (name (dom-attr child 'name))
                (causality (dom-attr child 'causality))
                (variability (dom-attr child 'variability))
                (start (dom-attr child 'start)))
            (when name
              (push (list :name name
                          :type tag-name
                          :causality (or causality "local")
                          :variability (or variability "continuous")
                          :start start)
                    results))))))
    (nreverse results)))

(defun sysml2--fmi-extract-model-structure (dom)
  "Extract model structure (outputs, derivatives, unknowns) from DOM.
Returns plist with `:outputs', `:derivatives', `:initial-unknowns'."
  (let ((ms-node (car (dom-by-tag dom 'ModelStructure)))
        (outputs nil)
        (derivatives nil)
        (unknowns nil))
    (when ms-node
      (dolist (child (dom-children ms-node))
        (when (and (listp child) (symbolp (car child)))
          (let ((tag (car child))
                (vr (dom-attr child 'valueReference)))
            (pcase tag
              ('Output (push vr outputs))
              ('ContinuousStateDerivative (push vr derivatives))
              ('InitialUnknown (push vr unknowns)))))))
    (list :outputs (nreverse outputs)
          :derivatives (nreverse derivatives)
          :initial-unknowns (nreverse unknowns))))

(defun sysml2--fmi-display-inspector (fmu-data fmu-path)
  "Display FMU inspector buffer with FMU-DATA from FMU-PATH."
  (let ((buf (get-buffer-create "*SysML2 FMU Inspector*")))
    (setq sysml2--fmi-inspector-buffer buf)
    (setq sysml2--fmi-current-fmu-path fmu-path)
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "FMU Inspector\n" 'face 'bold))
        (insert (make-string 40 ?-) "\n\n")
        (insert (format "File:        %s\n" fmu-path))
        (insert (format "FMI Version: %s\n" (plist-get fmu-data :fmi-version)))
        (insert (format "Model Name:  %s\n" (plist-get fmu-data :model-name)))
        (insert (format "GUID:        %s\n" (plist-get fmu-data :guid)))
        (insert "\n")
        ;; Variables section
        (insert (propertize "Model Variables\n" 'face 'bold))
        (insert (make-string 40 ?-) "\n")
        (let ((vars (plist-get fmu-data :variables)))
          (insert (format "%-20s %-10s %-12s %-12s %s\n"
                          "Name" "Type" "Causality" "Variability" "Start"))
          (insert (make-string 70 ?-) "\n")
          (dolist (var vars)
            (insert (format "%-20s %-10s %-12s %-12s %s\n"
                            (plist-get var :name)
                            (plist-get var :type)
                            (plist-get var :causality)
                            (plist-get var :variability)
                            (or (plist-get var :start) "")))))
        (insert "\n")
        ;; Model structure
        (insert (propertize "Model Structure\n" 'face 'bold))
        (insert (make-string 40 ?-) "\n")
        (let ((structure (plist-get fmu-data :model-structure)))
          (insert (format "Outputs:     %s\n"
                          (mapconcat #'identity
                                     (plist-get structure :outputs) ", ")))
          (insert (format "Derivatives: %s\n"
                          (mapconcat #'identity
                                     (plist-get structure :derivatives) ", ")))
          (insert (format "Unknowns:    %s\n"
                          (mapconcat #'identity
                                     (plist-get structure :initial-unknowns)
                                     ", ")))))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)))

;;;###autoload
(defun sysml2-fmi-inspect-fmu (fmu-path)
  "Inspect an FMU file at FMU-PATH.
Parses the modelDescription.xml and displays an inspector buffer."
  (interactive "fFMU file: ")
  (let* ((extracted (sysml2--fmi-unzip-fmu fmu-path))
         (xml-path (cdr (assq 'model-description extracted)))
         (fmu-data (sysml2--fmi-parse-model-description xml-path)))
    (sysml2--fmi-display-inspector fmu-data fmu-path)))

;;;###autoload
(defun sysml2-fmi-inspect-model-description (xml-path)
  "Inspect an FMI modelDescription.xml file directly.
XML-PATH is the path to a modelDescription.xml file."
  (interactive "fmodelDescription.xml file: ")
  (let ((fmu-data (sysml2--fmi-parse-model-description xml-path)))
    (sysml2--fmi-display-inspector fmu-data xml-path)))

;; --- Interface Contract Extraction ---

(defun sysml2--fmi-map-type (sysml-type)
  "Map SYSML-TYPE to an FMI 3.0 type string.
Checks user `sysml2-fmi-type-mapping-alist' first, then built-in defaults.
Unknown types default to Float64."
  (or (cdr (assoc sysml-type sysml2-fmi-type-mapping-alist))
      (cdr (assoc sysml-type sysml2--fmi-default-type-mapping))
      "Float64"))

(defun sysml2--fmi-apply-conjugation (direction conjugated)
  "Apply conjugation to DIRECTION.
When CONJUGATED is non-nil, flip \"input\" to \"output\" and vice versa."
  (if conjugated
      (pcase direction
        ("input" "output")
        ("output" "input")
        ("in" "out")
        ("out" "in")
        (_ direction))
    direction))

(defun sysml2--fmi-direction-to-causality (direction)
  "Convert SysML DIRECTION keyword to FMI causality."
  (pcase direction
    ("in" "input")
    ("out" "output")
    ("inout" "input")
    ("input" "input")
    ("output" "output")
    (_ "local")))

(defun sysml2--fmi-extract-port-def-items (port-def-name &optional buffer)
  "Extract flow items from PORT-DEF-NAME definition in BUFFER.
Returns list of plists with `:name', `:direction', `:type'."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (let ((bounds (sysml2--model-find-def-bounds "port def" port-def-name)))
        (when bounds
          (let ((beg (car bounds))
                (end (cdr bounds))
                (results nil))
            (goto-char beg)
            (while (re-search-forward
                    (concat "\\b\\(in\\|out\\|inout\\)[ \t]+item[ \t]+"
                            "\\(" sysml2--identifier-regexp "\\)"
                            "[ \t]*:[ \t]*"
                            "\\(" sysml2--qualified-name-regexp "\\)")
                    end t)
              (push (list :name (match-string-no-properties 2)
                          :direction (match-string-no-properties 1)
                          :type (match-string-no-properties 3))
                    results))
            (nreverse results)))))))

(defun sysml2--fmi-extract-part-interface (part-def-name &optional buffer)
  "Extract FMI interface contract for PART-DEF-NAME from BUFFER.
When sysml2-cli is available, uses tree-sitter AST extraction.
Otherwise falls back to regex-based extraction.
Returns list of plists with `:name', `:direction', `:sysml-type',
`:fmi-type', `:causality', `:variability', `:source-port'."
  (let ((file (buffer-file-name (or buffer (current-buffer)))))
    (if (and file (sysml2--cli-available-p))
        ;; Tree-sitter backend via sysml2-cli
        (let* ((result (sysml2--cli-call-json
                        "export" "interfaces" file
                        "--part" part-def-name))
               (items (plist-get result :items)))
          (mapcar (lambda (item)
                    (list :name (plist-get item :name)
                          :direction (plist-get item :direction)
                          :sysml-type (plist-get item :sysml_type)
                          :fmi-type (plist-get item :fmi_type)
                          :causality (plist-get item :causality)
                          :variability (plist-get item :variability)
                          :source-port (plist-get item :source_port)))
                  items))
      ;; Regex fallback
      (sysml2--fmi-extract-part-interface--regex part-def-name buffer))))

(defun sysml2--fmi-extract-part-interface--regex (part-def-name &optional buffer)
  "Regex-based FMI interface extraction (fallback when sysml2-cli unavailable)."
  (with-current-buffer (or buffer (current-buffer))
    (let ((bounds (sysml2--model-find-def-bounds "part def" part-def-name)))
      (unless bounds
        (user-error "Part def '%s' not found" part-def-name))
      (let ((beg (car bounds))
            (end (cdr bounds))
            (results nil))
        ;; Get port usages on this part def
        (let ((port-usages (sysml2--model-extract-port-usages beg end)))
          (dolist (port port-usages)
            (let* ((port-name (plist-get port :name))
                   (port-type (plist-get port :type))
                   (conjugated (plist-get port :conjugated))
                   (items (sysml2--fmi-extract-port-def-items port-type)))
              (dolist (item items)
                (let* ((raw-dir (plist-get item :direction))
                       (dir (sysml2--fmi-apply-conjugation raw-dir conjugated))
                       (sysml-type (plist-get item :type))
                       (fmi-type (sysml2--fmi-map-type sysml-type)))
                  (push (list :name (plist-get item :name)
                              :direction dir
                              :sysml-type sysml-type
                              :fmi-type fmi-type
                              :causality (sysml2--fmi-direction-to-causality dir)
                              :variability "continuous"
                              :source-port port-name)
                        results))))))
        (nreverse results)))))

;;;###autoload
(defun sysml2-fmi-extract-interfaces (&optional part-def-name buffer)
  "Extract FMI interface contracts for PART-DEF-NAME from BUFFER.
Interactive: prompts for part def name.  Displays results in a buffer."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (name (or part-def-name
                   (read-string "Part def name: ")))
         (contract (sysml2--fmi-extract-part-interface name buf))
         (out-buf (get-buffer-create "*SysML2 FMI Interfaces*")))
    (with-current-buffer out-buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (format "FMI Interface Contract: %s\n" name)
                            'face 'bold))
        (insert (make-string 60 ?-) "\n\n")
        (if (null contract)
            (insert "No interface items extracted.\n")
          (insert (format "%-15s %-10s %-12s %-10s %-12s %s\n"
                          "Name" "Direction" "SysML Type" "FMI Type"
                          "Causality" "Source Port"))
          (insert (make-string 75 ?-) "\n")
          (dolist (item contract)
            (insert (format "%-15s %-10s %-12s %-10s %-12s %s\n"
                            (plist-get item :name)
                            (plist-get item :direction)
                            (plist-get item :sysml-type)
                            (plist-get item :fmi-type)
                            (plist-get item :causality)
                            (plist-get item :source-port))))))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer out-buf)
    contract))

;; --- Modelica Stub Generation ---

(defun sysml2--fmi-extract-typed-attributes (beg end &optional buffer)
  "Extract attributes with types from region BEG..END in BUFFER.
Returns list of plists with `:name' and `:type'."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char beg)
      (let ((results nil))
        (while (re-search-forward
                (concat "\\battribute[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "[ \t]*:[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)")
                end t)
          (push (list :name (match-string-no-properties 1)
                      :type (match-string-no-properties 2))
                results))
        (nreverse results)))))

(defun sysml2--fmi-modelica-type (fmi-type)
  "Convert FMI-TYPE to Modelica connector type."
  (pcase fmi-type
    ("Float64" "Modelica.Blocks.Interfaces.RealInput")
    ("Int32" "Modelica.Blocks.Interfaces.IntegerInput")
    ("Boolean" "Modelica.Blocks.Interfaces.BooleanInput")
    (_ "Modelica.Blocks.Interfaces.RealInput")))

(defun sysml2--fmi-modelica-output-type (fmi-type)
  "Convert FMI-TYPE to Modelica output connector type."
  (pcase fmi-type
    ("Float64" "Modelica.Blocks.Interfaces.RealOutput")
    ("Int32" "Modelica.Blocks.Interfaces.IntegerOutput")
    ("Boolean" "Modelica.Blocks.Interfaces.BooleanOutput")
    (_ "Modelica.Blocks.Interfaces.RealOutput")))

(defun sysml2--fmi-modelica-param-type (sysml-type)
  "Convert SYSML-TYPE to Modelica parameter type."
  (pcase sysml-type
    ((or "Real" "ScalarValues::Real") "Real")
    ((or "Integer" "ScalarValues::Integer") "Integer")
    ((or "Boolean" "ScalarValues::Boolean") "Boolean")
    ((or "String" "ScalarValues::String") "String")
    (_ "Real")))

(defun sysml2--fmi-generate-mo-string (part-def-name interface-contract attributes)
  "Generate Modelica source for PART-DEF-NAME.
INTERFACE-CONTRACT is the FMI interface list.
ATTRIBUTES is a list of typed attribute plists."
  (let ((lines nil))
    (push (format "partial model %s" part-def-name) lines)
    (push (format "  \"Generated from SysML v2 part def %s\"" part-def-name) lines)
    ;; Interface connectors
    (dolist (item interface-contract)
      (let* ((name (plist-get item :name))
             (direction (plist-get item :direction))
             (fmi-type (plist-get item :fmi-type))
             (source-port (plist-get item :source-port))
             (mo-type (if (member direction '("out" "output"))
                          (sysml2--fmi-modelica-output-type fmi-type)
                        (sysml2--fmi-modelica-type fmi-type))))
        (push (format "  %s %s \"From port %s\";" mo-type name source-port)
              lines)))
    ;; Attributes as parameters
    (dolist (attr attributes)
      (let ((name (plist-get attr :name))
            (type (plist-get attr :type)))
        (push (format "  parameter %s %s \"From SysML attribute\";"
                      (sysml2--fmi-modelica-param-type type) name)
              lines)))
    (push "equation" lines)
    (push "  // Equations to be filled by model developer" lines)
    (push (format "end %s;" part-def-name) lines)
    (mapconcat #'identity (nreverse lines) "\n")))

;;;###autoload
(defun sysml2-fmi-generate-modelica (&optional part-def-name buffer)
  "Generate a Modelica stub for PART-DEF-NAME from BUFFER.
When sysml2-cli is available, uses tree-sitter AST extraction.
Interactive: prompts for part def name and output path."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (name (or part-def-name
                   (read-string "Part def name: ")))
         (file (buffer-file-name buf))
         (mo-string
          (if (and file (sysml2--cli-available-p))
              ;; Tree-sitter backend
              (sysml2--cli-call-text "export" "modelica" file "--part" name)
            ;; Regex fallback
            (let* ((contract (sysml2--fmi-extract-part-interface name buf))
                   (bounds (with-current-buffer buf
                             (sysml2--model-find-def-bounds "part def" name)))
                   (attributes (when bounds
                                 (with-current-buffer buf
                                   (sysml2--fmi-extract-typed-attributes
                                    (car bounds) (cdr bounds))))))
              (sysml2--fmi-generate-mo-string name contract attributes)))))
    (if (called-interactively-p 'any)
        (let ((output-path
               (read-file-name "Save Modelica file: "
                               sysml2-fmi-modelica-output-dir
                               nil nil
                               (concat name ".mo"))))
          (with-temp-file output-path
            (insert mo-string))
          (message "Modelica stub written to %s" output-path)
          (find-file-other-window output-path))
      mo-string)))

;; --- Batch Modelica Generation ---

(defun sysml2--fmi-list-exportable-parts (&optional buffer)
  "List exportable part defs in BUFFER.
When sysml2-cli is available, uses tree-sitter AST.
Otherwise extracts part defs via regex.
Returns list of plists with `:name', `:ports', `:attributes', `:connections'."
  (let ((file (buffer-file-name (or buffer (current-buffer)))))
    (if (and file (sysml2--cli-available-p))
        ;; Tree-sitter backend returns JSON list
        (let ((result (sysml2--cli-call-json "export" "list" file)))
          (if (and result (listp result))
              (mapcar (lambda (item)
                        (list :name (plist-get item :name)
                              :ports (or (plist-get item :ports) 0)
                              :attributes (or (plist-get item :attributes) 0)
                              :connections (or (plist-get item :connections) 0)))
                      result)
            nil))
      ;; Regex fallback — extract part defs that have ports
      (with-current-buffer (or buffer (current-buffer))
        (let ((part-defs (sysml2--model-extract-part-defs)))
          (mapcar (lambda (pd)
                    (list :name (plist-get pd :name)
                          :ports 0 :attributes 0 :connections 0))
                  part-defs))))))

;;;###autoload
(defun sysml2-fmi-generate-all-modelica (&optional buffer)
  "Generate Modelica stubs for all exportable parts in BUFFER.
Prompts for output directory, then generates a .mo file for each
part definition that has ports or attributes."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (parts (sysml2--fmi-list-exportable-parts buf)))
    (unless parts
      (user-error "No exportable part definitions found"))
    (let* ((output-dir (read-directory-name
                        "Output directory for .mo files: "
                        sysml2-fmi-modelica-output-dir))
           (file (buffer-file-name buf))
           (generated nil))
      (make-directory output-dir t)
      (dolist (part parts)
        (let* ((name (plist-get part :name))
               (output-path (expand-file-name (concat name ".mo") output-dir))
               (mo-string
                (if (and file (sysml2--cli-available-p))
                    (sysml2--cli-call-text "export" "modelica" file
                                           "--part" name)
                  (let* ((contract (sysml2--fmi-extract-part-interface name buf))
                         (bounds (with-current-buffer buf
                                   (sysml2--model-find-def-bounds "part def" name)))
                         (attributes (when bounds
                                       (with-current-buffer buf
                                         (sysml2--fmi-extract-typed-attributes
                                          (car bounds) (cdr bounds))))))
                    (sysml2--fmi-generate-mo-string name contract attributes)))))
          (with-temp-file output-path
            (insert mo-string))
          (push (list :name name :path output-path) generated)))
      ;; Display summary
      (let ((out-buf (get-buffer-create "*SysML2 Modelica Generation*")))
        (with-current-buffer out-buf
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert (propertize "Modelica Stub Generation\n" 'face 'bold))
            (insert (make-string 50 ?-) "\n\n")
            (insert (format "Generated %d Modelica stubs in %s\n\n"
                            (length generated) output-dir))
            (dolist (g (nreverse generated))
              (insert (format "  %s  ->  %s\n"
                              (plist-get g :name)
                              (file-name-nondirectory (plist-get g :path))))))
          (special-mode)
          (goto-char (point-min)))
        (pop-to-buffer out-buf))
      (message "Generated %d Modelica stubs" (length generated)))))

;; --- FMU Compilation via OpenModelica ---

(defun sysml2--fmi-resolve-omc ()
  "Resolve the OpenModelica compiler (omc) executable path.
Checks `sysml2-fmi-openmodelica-path'/bin/omc, then exec-path."
  (or (when sysml2-fmi-openmodelica-path
        (let ((omc (expand-file-name "bin/omc" sysml2-fmi-openmodelica-path)))
          (when (file-executable-p omc) omc)))
      (executable-find "omc")
      (user-error "OpenModelica (omc) not found.  Set `sysml2-fmi-openmodelica-path' or add omc to PATH")))

(defun sysml2--fmi-generate-mos-script (mo-path &optional fmu-version fmu-type)
  "Generate a .mos script to compile MO-PATH to an FMU.
FMU-VERSION defaults to \"2.0\".  FMU-TYPE defaults to \"me_cs\"."
  (let ((model-name (file-name-sans-extension (file-name-nondirectory mo-path)))
        (version (or fmu-version "2.0"))
        (ftype (or fmu-type "me_cs")))
    (format "loadFile(\"%s\");\nbuildModelFMU(%s, version=\"%s\", fmuType=\"%s\");\n"
            (expand-file-name mo-path) model-name version ftype)))

;;;###autoload
(defun sysml2-fmi-compile-fmu (mo-file)
  "Compile Modelica file MO-FILE to an FMU using OpenModelica.
Runs omc asynchronously.  The FMU is produced in the same directory."
  (interactive "fModelica file (.mo): ")
  (let* ((omc (sysml2--fmi-resolve-omc))
         (mo-path (expand-file-name mo-file))
         (mos-script (sysml2--fmi-generate-mos-script mo-path))
         (mos-file (make-temp-file "sysml2-fmu-" nil ".mos"))
         (default-directory (file-name-directory mo-path))
         (proc-buf (generate-new-buffer " *sysml2-omc*")))
    (with-temp-file mos-file
      (insert mos-script))
    (message "Compiling %s to FMU..." (file-name-nondirectory mo-path))
    (let ((proc (start-process "sysml2-omc" proc-buf omc mos-file)))
      (set-process-sentinel
       proc
       (let ((mo-name (file-name-sans-extension
                       (file-name-nondirectory mo-path)))
             (dir default-directory))
         (lambda (p _event)
           (when (memq (process-status p) '(exit signal))
             (let ((fmu-path (expand-file-name (concat mo-name ".fmu") dir)))
               (if (and (= (process-exit-status p) 0)
                        (file-exists-p fmu-path))
                   (message "FMU compiled: %s" fmu-path)
                 (message "FMU compilation failed for %s (exit %d)"
                          mo-name (process-exit-status p))))
             (delete-file mos-file)
             (kill-buffer (process-buffer p)))))))))

;;;###autoload
(defun sysml2-fmi-compile-all-fmus (directory)
  "Compile all .mo files in DIRECTORY to FMUs using OpenModelica.
Runs omc with a single .mos script that loads and builds all models."
  (interactive "DDirectory with .mo files: ")
  (let* ((omc (sysml2--fmi-resolve-omc))
         (dir (expand-file-name directory))
         (mo-files (directory-files dir t "\\.mo\\'" t)))
    (unless mo-files
      (user-error "No .mo files found in %s" dir))
    ;; Generate combined .mos script
    (let ((mos-file (make-temp-file "sysml2-fmu-all-" nil ".mos"))
          (mos-lines nil)
          (model-names nil))
      (dolist (mo mo-files)
        (let ((name (file-name-sans-extension (file-name-nondirectory mo))))
          (push name model-names)
          (push (format "loadFile(\"%s\");" (expand-file-name mo)) mos-lines)
          (push (format "buildModelFMU(%s, version=\"2.0\", fmuType=\"me_cs\");"
                        name)
                mos-lines)))
      (with-temp-file mos-file
        (insert (mapconcat #'identity (nreverse mos-lines) "\n") "\n"))
      (let ((default-directory dir)
            (proc-buf (generate-new-buffer " *sysml2-omc*"))
            (count (length mo-files)))
        (message "Compiling %d Modelica models to FMUs..." count)
        (let ((proc (start-process "sysml2-omc" proc-buf omc mos-file)))
          (set-process-sentinel
           proc
           (let ((names (nreverse model-names))
                 (output-dir dir))
             (lambda (p _event)
               (when (memq (process-status p) '(exit signal))
                 (let ((compiled
                        (cl-count-if
                         (lambda (n)
                           (file-exists-p
                            (expand-file-name (concat n ".fmu") output-dir)))
                         names)))
                   (message "FMU compilation complete: %d/%d succeeded"
                            compiled (length names)))
                 (delete-file mos-file)
                 (kill-buffer (process-buffer p)))))))))))

;; --- Batch Validation ---

;;;###autoload
(defun sysml2-fmi-validate-all (fmu-directory &optional buffer)
  "Validate all FMUs in FMU-DIRECTORY against part defs in BUFFER.
Matches FMU filenames (case-insensitive) to part def names."
  (interactive "DFMU directory: ")
  (let* ((buf (or buffer (current-buffer)))
         (dir (expand-file-name fmu-directory))
         (fmu-files (directory-files dir t "\\.fmu\\'" t))
         (parts (sysml2--fmi-list-exportable-parts buf))
         (part-names (mapcar (lambda (p) (plist-get p :name)) parts))
         (results nil))
    (unless fmu-files
      (user-error "No .fmu files found in %s" dir))
    (dolist (fmu fmu-files)
      (let* ((fmu-name (file-name-sans-extension (file-name-nondirectory fmu)))
             (part-name (cl-find fmu-name part-names
                                 :test #'string-equal-ignore-case)))
        (if part-name
            (let* ((extracted (sysml2--fmi-unzip-fmu fmu))
                   (xml-path (cdr (assq 'model-description extracted)))
                   (fmu-data (sysml2--fmi-parse-model-description xml-path))
                   (fmu-vars (plist-get fmu-data :variables))
                   (sysml-contract (sysml2--fmi-extract-part-interface
                                    part-name buf))
                   (comparison (sysml2--fmi-compare-interfaces
                                fmu-vars sysml-contract)))
              (push (list :fmu fmu-name
                          :part part-name
                          :matches (length (plist-get comparison :matches))
                          :mismatches (length (plist-get comparison :type-mismatches))
                          :sysml-only (length (plist-get comparison :sysml-only))
                          :fmu-only (length (plist-get comparison :fmu-only))
                          :status (if (and (= 0 (length (plist-get comparison :type-mismatches)))
                                          (= 0 (length (plist-get comparison :sysml-only))))
                                      'pass 'fail))
                    results))
          (push (list :fmu fmu-name :part nil :status 'unmatched) results))))
    ;; Display
    (let ((out-buf (get-buffer-create "*SysML2 FMI Validation*")))
      (with-current-buffer out-buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (propertize "FMI Batch Validation\n" 'face 'bold))
          (insert (make-string 60 ?-) "\n\n")
          (insert (format "%-20s %-20s %-8s %-8s %-10s %s\n"
                          "FMU" "Part Def" "Match" "Mismatch" "Missing" "Status"))
          (insert (make-string 75 ?-) "\n")
          (dolist (r (nreverse results))
            (let* ((status (plist-get r :status))
                   (face (pcase status
                           ('pass '(:foreground "green"))
                           ('fail '(:foreground "red"))
                           ('unmatched '(:foreground "yellow")))))
              (if (eq status 'unmatched)
                  (insert (format "%-20s %-20s %-8s %-8s %-10s "
                                  (plist-get r :fmu) "—" "—" "—" "—"))
                (insert (format "%-20s %-20s %-8d %-8d %-10d "
                                (plist-get r :fmu)
                                (plist-get r :part)
                                (plist-get r :matches)
                                (plist-get r :mismatches)
                                (plist-get r :sysml-only))))
              (insert (propertize (upcase (symbol-name status)) 'face face))
              (insert "\n"))))
        (special-mode)
        (goto-char (point-min)))
      (pop-to-buffer out-buf))))

;; --- FMI Dashboard ---

;;;###autoload
(defun sysml2-fmi-dashboard (&optional buffer)
  "Show FMI export pipeline status for the current SysML file.
Displays which parts have Modelica stubs, compiled FMUs, and
validation results."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (file (buffer-file-name buf))
         (file-dir (when file (file-name-directory file)))
         (mo-dir (or sysml2-fmi-modelica-output-dir file-dir))
         (parts (sysml2--fmi-list-exportable-parts buf))
         (rows nil))
    (unless parts
      (user-error "No exportable part definitions found"))
    (dolist (part parts)
      (let* ((name (plist-get part :name))
             (mo-exists (and mo-dir
                             (file-exists-p
                              (expand-file-name (concat name ".mo") mo-dir))))
             (fmu-exists (and mo-dir
                              (file-exists-p
                               (expand-file-name (concat name ".fmu") mo-dir)))))
        (push (list :name name
                    :ports (plist-get part :ports)
                    :attributes (plist-get part :attributes)
                    :mo mo-exists
                    :fmu fmu-exists)
              rows)))
    ;; Display
    (let ((out-buf (get-buffer-create "*SysML2 FMI Dashboard*")))
      (with-current-buffer out-buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (propertize "FMI Export Dashboard\n" 'face 'bold))
          (insert (make-string 60 ?-) "\n\n")
          (when file
            (insert (format "Source: %s\n" (file-name-nondirectory file))))
          (insert (format "Output: %s\n\n" (or mo-dir "not configured")))
          (insert (format "%-25s %-6s %-6s %-12s %-12s\n"
                          "Part Definition" "Ports" "Attrs" "Modelica" "FMU"))
          (insert (make-string 65 ?-) "\n")
          (dolist (r (nreverse rows))
            (insert (format "%-25s %-6d %-6d "
                            (plist-get r :name)
                            (plist-get r :ports)
                            (plist-get r :attributes)))
            (insert (propertize
                     (format "%-12s"
                             (if (plist-get r :mo) "generated" "missing"))
                     'face (if (plist-get r :mo)
                               '(:foreground "green")
                             '(:foreground "yellow"))))
            (insert (propertize
                     (format "%-12s"
                             (if (plist-get r :fmu) "compiled" "missing"))
                     'face (if (plist-get r :fmu)
                               '(:foreground "green")
                             '(:foreground "yellow"))))
            (insert "\n"))
          (insert "\n")
          ;; Summary counts
          (let* ((all-rows rows)
                 (total (length all-rows))
                 (mo-count (cl-count-if (lambda (r) (plist-get r :mo)) all-rows))
                 (fmu-count (cl-count-if (lambda (r) (plist-get r :fmu)) all-rows)))
            (insert (format "Total: %d parts | %d Modelica stubs | %d FMUs\n"
                            total mo-count fmu-count))
            (insert "\n")
            (insert "Commands:\n")
            (insert "  C-c C-s M   Generate all Modelica stubs\n")
            (insert "  C-c C-s B   Compile all FMUs (OpenModelica)\n")
            (insert "  C-c C-s V   Validate all FMUs\n")
            (insert "  C-c C-s P   Run full pipeline\n")))
        (special-mode)
        (goto-char (point-min)))
      (pop-to-buffer out-buf))))

;; --- Interface Validation ---

(defun sysml2--fmi-compare-interfaces (fmu-vars sysml-contract)
  "Compare FMU-VARS against SYSML-CONTRACT.
Returns plist with `:matches', `:fmu-only', `:sysml-only',
`:type-mismatches'."
  (let ((matches nil)
        (fmu-only nil)
        (sysml-only nil)
        (type-mismatches nil)
        (fmu-by-name (make-hash-table :test 'equal))
        (sysml-by-name (make-hash-table :test 'equal)))
    ;; Index FMU variables (only inputs/outputs/parameters)
    (dolist (var fmu-vars)
      (let ((causality (plist-get var :causality)))
        (when (member causality '("input" "output" "parameter"))
          (puthash (plist-get var :name) var fmu-by-name))))
    ;; Index SysML contract
    (dolist (item sysml-contract)
      (puthash (plist-get item :name) item sysml-by-name))
    ;; Check each SysML item against FMU
    (maphash
     (lambda (name item)
       (let ((fmu-var (gethash name fmu-by-name)))
         (if fmu-var
             (let ((fmu-type (plist-get fmu-var :type))
                   (sysml-fmi-type (plist-get item :fmi-type)))
               (if (equal fmu-type sysml-fmi-type)
                   (push name matches)
                 (push (list :name name
                             :fmu-type fmu-type
                             :sysml-type sysml-fmi-type)
                       type-mismatches)))
           (push name sysml-only))))
     sysml-by-name)
    ;; Find FMU-only variables
    (maphash
     (lambda (name _var)
       (unless (gethash name sysml-by-name)
         (push name fmu-only)))
     fmu-by-name)
    (list :matches (nreverse matches)
          :fmu-only (nreverse fmu-only)
          :sysml-only (nreverse sysml-only)
          :type-mismatches (nreverse type-mismatches))))

(defun sysml2--fmi-display-validation (comparison fmu-path part-def-name)
  "Display validation results from COMPARISON.
FMU-PATH and PART-DEF-NAME are displayed in the header."
  (let ((buf (get-buffer-create "*SysML2 FMI Validation*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "FMI Interface Validation\n" 'face 'bold))
        (insert (make-string 50 ?-) "\n\n")
        (insert (format "FMU:      %s\n" fmu-path))
        (insert (format "Part Def: %s\n\n" part-def-name))
        ;; Matches
        (let ((matches (plist-get comparison :matches)))
          (insert (propertize
                   (format "MATCHES (%d)\n" (length matches))
                   'face '(:foreground "green")))
          (dolist (name matches)
            (insert (format "  %s\n" name))))
        (insert "\n")
        ;; Type mismatches
        (let ((mismatches (plist-get comparison :type-mismatches)))
          (insert (propertize
                   (format "TYPE MISMATCHES (%d)\n" (length mismatches))
                   'face '(:foreground "red")))
          (dolist (mm mismatches)
            (insert (format "  %s: FMU=%s, SysML=%s\n"
                            (plist-get mm :name)
                            (plist-get mm :fmu-type)
                            (plist-get mm :sysml-type)))))
        (insert "\n")
        ;; FMU only
        (let ((fmu-only (plist-get comparison :fmu-only)))
          (insert (propertize
                   (format "FMU ONLY (%d)\n" (length fmu-only))
                   'face '(:foreground "yellow")))
          (dolist (name fmu-only)
            (insert (format "  %s\n" name))))
        (insert "\n")
        ;; SysML only
        (let ((sysml-only (plist-get comparison :sysml-only)))
          (insert (propertize
                   (format "SYSML ONLY (%d)\n" (length sysml-only))
                   'face '(:foreground "yellow")))
          (dolist (name sysml-only)
            (insert (format "  %s\n" name)))))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)
    buf))

;;;###autoload
(defun sysml2-fmi-validate-interfaces (fmu-path &optional part-def-name buffer)
  "Validate FMU at FMU-PATH against SysML PART-DEF-NAME in BUFFER.
Interactive: prompts for FMU path and part def name."
  (interactive "fFMU or modelDescription.xml: ")
  (let* ((buf (or buffer (current-buffer)))
         (name (or part-def-name
                   (read-string "Part def name: ")))
         (xml-path (if (string-suffix-p ".xml" fmu-path)
                       fmu-path
                     (let ((extracted (sysml2--fmi-unzip-fmu fmu-path)))
                       (cdr (assq 'model-description extracted)))))
         (fmu-data (sysml2--fmi-parse-model-description xml-path))
         (fmu-vars (plist-get fmu-data :variables))
         (sysml-contract (sysml2--fmi-extract-part-interface name buf))
         (comparison (sysml2--fmi-compare-interfaces fmu-vars sysml-contract)))
    (sysml2--fmi-display-validation comparison fmu-path name)
    comparison))

(provide 'sysml2-fmi)
;;; sysml2-fmi.el ends here
