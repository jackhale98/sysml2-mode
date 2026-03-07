;;; sysml2-vars.el --- Customization variables and faces for sysml2-mode -*- lexical-binding: t; byte-compile-dynamic-docstrings: nil; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Single source of truth for all user customization, faces, and shared
;; mutable state for sysml2-mode.  No logic lives here.

;;; Code:

;;; Public API:
;;
;; Variables:
;;   `sysml2-indent-offset' -- Number of spaces per indentation level
;;   `sysml2-indent-tabs-mode' -- Whether to use tabs for indentation
;;   `sysml2-standard-library-path' -- Path to standard library
;;   `sysml2-auto-detect-library' -- Auto-detect library path
;;   `sysml2-plantuml-jar-path' -- Path to PlantUML jar
;;   `sysml2-plantuml-executable-path' -- Path to PlantUML executable
;;   `sysml2-plantuml-exec-mode' -- PlantUML execution mode
;;   `sysml2-plantuml-server-url' -- PlantUML server URL
;;   `sysml2-diagram-output-format' -- Diagram output format
;;   `sysml2-diagram-auto-preview' -- Auto-preview on save
;;   `sysml2-diagram-preview-window' -- Preview window placement
;;   `sysml2-lsp-server' -- LSP server selection
;;   `sysml2-lsp-server-path' -- LSP server executable path
;;   `sysml2-api-base-url' -- Systems Modeling API base URL
;;   `sysml2-api-project-id' -- Default API project ID
;;   `sysml2-graphviz-dot-path' -- Path to GraphViz dot
;;   `sysml2-fmi-openmodelica-path' -- Path to OpenModelica
;;   `sysml2-fmi-fmpy-executable' -- Path to FMPy
;;   `sysml2-fmi-default-fmi-version' -- Default FMI version
;;   `sysml2-fmi-modelica-output-dir' -- Modelica output directory
;;   `sysml2-fmi-type-mapping-alist' -- SysML→FMI type mapping
;;   `sysml2-cosim-tool' -- Co-simulation tool selection
;;   `sysml2-cosim-omsimulator-path' -- OMSimulator executable
;;   `sysml2-cosim-gnuplot-path' -- Gnuplot executable
;;   `sysml2-cosim-step-size' -- Simulation step size
;;   `sysml2-cosim-stop-time' -- Simulation stop time
;;   `sysml2-cosim-output-dir' -- Simulation output directory
;;   `sysml2-cosim-results-format' -- Results format (csv/mat)

;; --- Customization Groups ---

(defgroup sysml2 nil
  "SysML v2 / KerML editing support."
  :group 'languages
  :prefix "sysml2-")

(defgroup sysml2-faces nil
  "Faces for SysML v2 syntax highlighting."
  :group 'sysml2
  :prefix "sysml2-")

(defgroup sysml2-diagram nil
  "Diagram generation and preview settings."
  :group 'sysml2
  :prefix "sysml2-diagram-")

(defgroup sysml2-lsp nil
  "LSP server configuration."
  :group 'sysml2
  :prefix "sysml2-lsp-")

(defgroup sysml2-fmi nil
  "FMI/FMU and co-simulation settings."
  :group 'sysml2
  :prefix "sysml2-fmi-")

;; --- Customization Variables ---

(defcustom sysml2-indent-offset 4
  "Number of spaces for each indentation level in SysML v2 files."
  :type 'integer
  :group 'sysml2)

(defcustom sysml2-indent-tabs-mode nil
  "Whether to use tabs for indentation in SysML v2 files."
  :type 'boolean
  :group 'sysml2)

(defcustom sysml2-standard-library-path nil
  "Path to SysML v2 standard library directory.
When nil, the mode will attempt auto-detection or use a bundled library."
  :type '(choice (const :tag "Auto-detect" nil)
                 (directory :tag "Directory path"))
  :group 'sysml2)

(defcustom sysml2-auto-detect-library t
  "Whether to automatically detect the standard library path.
When non-nil, searches project root for `sysml.library/' directory."
  :type 'boolean
  :group 'sysml2)

(defcustom sysml2-plantuml-jar-path nil
  "Path to PlantUML jar file.
When nil, uses `plantuml-mode' setting if available."
  :type '(choice (const :tag "Use plantuml-mode setting" nil)
                 (file :tag "Jar file path"))
  :group 'sysml2-diagram)

(defcustom sysml2-plantuml-executable-path nil
  "Path to PlantUML executable.
When nil, searches `exec-path' for `plantuml'."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "Executable path"))
  :group 'sysml2-diagram)

(defcustom sysml2-plantuml-exec-mode 'executable
  "How to invoke PlantUML for diagram generation."
  :type '(choice (const :tag "PlantUML executable" executable)
                 (const :tag "Java jar" jar)
                 (const :tag "PlantUML server" server))
  :group 'sysml2-diagram)

(defcustom sysml2-plantuml-server-url "https://www.plantuml.com/plantuml"
  "URL of PlantUML server for server execution mode."
  :type 'string
  :group 'sysml2-diagram)

(defcustom sysml2-diagram-output-format "svg"
  "Default output format for diagram generation."
  :type '(choice (const :tag "SVG" "svg")
                 (const :tag "PNG" "png")
                 (const :tag "PDF" "pdf"))
  :group 'sysml2-diagram)

(defcustom sysml2-diagram-auto-preview nil
  "Whether to automatically regenerate diagram preview on save."
  :type 'boolean
  :group 'sysml2-diagram)

(defcustom sysml2-diagram-page-size nil
  "Page size constraint for generated PlantUML diagrams.
When non-nil, emits a `scale` directive to fit diagrams within the
given dimensions.  Values are pixel dimensions at the target DPI."
  :type '(choice (const :tag "No constraint" nil)
                 (const :tag "Letter portrait (150 DPI)" (1200 . 1500))
                 (const :tag "Letter landscape (150 DPI)" (1500 . 1200))
                 (const :tag "Letter portrait (300 DPI)" (2400 . 3150))
                 (const :tag "Letter landscape (300 DPI)" (3150 . 2400))
                 (const :tag "A4 portrait (150 DPI)" (1170 . 1600))
                 (const :tag "A4 landscape (150 DPI)" (1600 . 1170))
                 (cons :tag "Custom (width . height)"
                       (integer :tag "Max width (px)")
                       (integer :tag "Max height (px)")))
  :group 'sysml2-diagram)

(defcustom sysml2-diagram-direction nil
  "Layout direction for generated PlantUML diagrams.
Left-to-right can be more readable for wide inheritance trees."
  :type '(choice (const :tag "Top to bottom (default)" nil)
                 (const :tag "Left to right" left-to-right))
  :group 'sysml2-diagram)

(defcustom sysml2-diagram-preview-window 'split-right
  "Where to display the diagram preview window."
  :type '(choice (const :tag "Split right" split-right)
                 (const :tag "Split below" split-below)
                 (const :tag "Other frame" other-frame))
  :group 'sysml2-diagram)

(defcustom sysml2-lsp-server 'pilot
  "Which LSP server to use for SysML v2."
  :type '(choice (const :tag "Pilot Implementation (recommended)" pilot)
                 (const :tag "Syside (Sensmetry, archived)" syside)
                 (const :tag "Eclipse SysON" syson)
                 (const :tag "None" none))
  :group 'sysml2-lsp)

(defcustom sysml2-lsp-server-path nil
  "Path to the LSP server executable or jar.
When nil, the server is found via `exec-path'."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "Server path"))
  :group 'sysml2-lsp)

(defcustom sysml2-api-base-url nil
  "Base URL for the Systems Modeling API repository.
Example: \"http://localhost:9000\"."
  :type '(choice (const :tag "Not configured" nil)
                 (string :tag "URL"))
  :group 'sysml2)

(defcustom sysml2-api-project-id nil
  "Default project ID for Systems Modeling API operations."
  :type '(choice (const :tag "Not configured" nil)
                 (string :tag "Project ID"))
  :group 'sysml2)

(defcustom sysml2-graphviz-dot-path nil
  "Path to GraphViz dot executable.
When nil, searches `exec-path'."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "Dot path"))
  :group 'sysml2-diagram)

(defcustom sysml2-fmi-openmodelica-path nil
  "Path to OpenModelica installation directory."
  :type '(choice (const :tag "Not configured" nil)
                 (directory :tag "OpenModelica path"))
  :group 'sysml2-fmi)

(defcustom sysml2-fmi-fmpy-executable nil
  "Path to FMPy executable for co-simulation."
  :type '(choice (const :tag "Not configured" nil)
                 (file :tag "FMPy path"))
  :group 'sysml2-fmi)

(defcustom sysml2-fmi-default-fmi-version "3.0"
  "Default FMI version for generated interfaces."
  :type 'string
  :group 'sysml2-fmi)

(defcustom sysml2-fmi-modelica-output-dir nil
  "Default directory for generated Modelica stub files."
  :type '(choice (const :tag "Prompt each time" nil)
                 (directory :tag "Output directory"))
  :group 'sysml2-fmi)

(defcustom sysml2-fmi-type-mapping-alist nil
  "User-defined SysML type to FMI type mapping.
Each entry maps a SysML type name to an FMI type name.
These override the built-in default mapping."
  :type '(alist :key-type string :value-type string)
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-tool 'fmpy
  "Which co-simulation tool to invoke."
  :type '(choice (const :tag "FMPy" fmpy)
                 (const :tag "OMSimulator" omsimulator))
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-omsimulator-path nil
  "Path to OMSimulator executable."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "OMSimulator path"))
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-gnuplot-path nil
  "Path to gnuplot executable for results plotting."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "Gnuplot path"))
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-step-size 0.001
  "Default simulation step size in seconds."
  :type 'float
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-stop-time 10.0
  "Default simulation stop time in seconds."
  :type 'float
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-output-dir nil
  "Default directory for simulation results."
  :type '(choice (const :tag "Prompt each time" nil)
                 (directory :tag "Output directory"))
  :group 'sysml2-fmi)

(defcustom sysml2-cosim-results-format "csv"
  "Default format for simulation results."
  :type '(choice (const "csv") (const "mat"))
  :group 'sysml2-fmi)

;; --- Report / Export ---

(defcustom sysml2-report-pandoc-executable nil
  "Path to Pandoc executable for report format conversion.
When nil, searches `exec-path' for `pandoc'."
  :type '(choice (const :tag "Search exec-path" nil)
                 (file :tag "Pandoc path"))
  :group 'sysml2)

;; --- Faces ---

(defface sysml2-keyword-face
  '((t :inherit font-lock-keyword-face))
  "Face for SysML v2 keywords."
  :group 'sysml2-faces)

(defface sysml2-definition-name-face
  '((t :inherit font-lock-type-face :weight bold))
  "Face for definition names (e.g., the name in `part def Vehicle')."
  :group 'sysml2-faces)

(defface sysml2-usage-name-face
  '((t :inherit font-lock-variable-name-face))
  "Face for usage names (e.g., the name in `part engine : Engine')."
  :group 'sysml2-faces)

(defface sysml2-type-reference-face
  '((t :inherit font-lock-type-face))
  "Face for type references (e.g., the type in `: Engine')."
  :group 'sysml2-faces)

(defface sysml2-modifier-face
  '((t :inherit font-lock-keyword-face :slant italic))
  "Face for modifier keywords (abstract, variation, in, out, etc.)."
  :group 'sysml2-faces)

(defface sysml2-visibility-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for visibility keywords (public, private, protected)."
  :group 'sysml2-faces)

(defface sysml2-builtin-face
  '((t :inherit font-lock-builtin-face))
  "Face for structural/builtin keywords (package, import, etc.)."
  :group 'sysml2-faces)

(defface sysml2-operator-face
  '((t :inherit font-lock-keyword-face))
  "Face for operator keywords (not, or, and, xor, etc.)."
  :group 'sysml2-faces)

(defface sysml2-literal-face
  '((t :inherit font-lock-constant-face))
  "Face for literal keywords (true, false, null) and numeric literals."
  :group 'sysml2-faces)

(defface sysml2-short-name-face
  '((((class color) (background light)) :foreground "SteelBlue")
    (((class color) (background dark)) :foreground "LightSteelBlue")
    (t :inherit font-lock-constant-face))
  "Face for short name identifiers like <R1>."
  :group 'sysml2-faces)

(defface sysml2-doc-comment-face
  '((t :inherit font-lock-doc-face))
  "Face for documentation comments (doc /* ... */)."
  :group 'sysml2-faces)

(defface sysml2-comment-face
  '((t :inherit font-lock-comment-face))
  "Face for comments."
  :group 'sysml2-faces)

(defface sysml2-string-face
  '((t :inherit font-lock-string-face))
  "Face for string literals."
  :group 'sysml2-faces)

(defface sysml2-metadata-face
  '((t :inherit font-lock-preprocessor-face))
  "Face for metadata annotations (#Name)."
  :group 'sysml2-faces)

(defface sysml2-package-face
  '((t :inherit font-lock-constant-face))
  "Face for package names in qualified references."
  :group 'sysml2-faces)

(defface sysml2-specialization-face
  '((((class color) (background light)) :foreground "DarkGreen")
    (((class color) (background dark)) :foreground "LightGreen")
    (t :inherit font-lock-type-face))
  "Face for specialization targets (after :> operator)."
  :group 'sysml2-faces)

;; --- Shared State (internal) ---

(defvar sysml2--current-library-path nil
  "Resolved standard library path (computed at runtime).")

(defvar sysml2--plantuml-process nil
  "Current PlantUML process, or nil if none is running.")

(defvar sysml2--diagram-preview-buffer nil
  "Buffer used for diagram preview display.")

(defvar sysml2--diagram-source-buffer nil
  "Source SysML buffer for the current diagram preview.")

(defvar sysml2--api-auth-token nil
  "Optional authentication token for the Systems Modeling API.")

(defvar sysml2--fmi-inspector-buffer nil
  "Buffer used for FMU inspector display.")

(defvar sysml2--fmi-current-fmu-path nil
  "Path to the FMU currently being inspected.")

(defvar sysml2--cosim-process nil
  "Current co-simulation process, or nil if none is running.")

(defvar sysml2--cosim-results-buffer nil
  "Buffer used for simulation results display.")

(defvar sysml2--cosim-verification-buffer nil
  "Buffer used for requirement verification dashboard.")

(provide 'sysml2-vars)
;;; sysml2-vars.el ends here
