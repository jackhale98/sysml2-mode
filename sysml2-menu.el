;;; sysml2-menu.el --- Menu bar and which-key for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Defines an `easy-menu' for `sysml2-mode-map' exposing all major
;; feature groups (Navigation, Diagrams, Analysis, Scaffold, Connect,
;; Simulate, Inspect, LSP, Format, Fold, Help).
;;
;; Also provides `sysml2-which-key-setup' which, when `which-key' is
;; available, registers human-readable labels for every prefix in
;; `sysml2-mode-map'.

;;; Code:

(require 'easymenu)

(defvar sysml2-mode-map)

(declare-function which-key-add-major-mode-key-based-replacements
                  "which-key" (mode key-sequence replacement &rest more))

(defvar sysml2-mode-menu-spec
  '("SysML2"
    ["Format Buffer"          sysml2-format-buffer t]
    ["Format Region"          sysml2-format-region mark-active]
    "--"
    ("Navigation"
     ["Outline Toggle"        sysml2-outline-toggle t]
     ["Imenu"                 imenu t]
     ["Go to Definition"      sysml2-goto-definition t]
     ["Find References"       sysml2-find-references t]
     ["Rename Symbol"         sysml2-rename-symbol t]
     ["Impact Analysis"       sysml2-impact-analysis t])
    ("Diagrams"
     ["Tree"                  sysml2-diagram-tree t]
     ["IBD"                   sysml2-diagram-ibd t]
     ["State Machine"         sysml2-diagram-state-machine t]
     ["Action Flow"           sysml2-diagram-action-flow t]
     ["Requirement"           sysml2-diagram-requirement t]
     ["Use Case"              sysml2-diagram-use-case t]
     ["Package"               sysml2-diagram-package t]
     ["View Filter"           sysml2-diagram-view t]
     "--"
     ["Preview"               sysml2-diagram-preview t]
     ["Preview Buffer"        sysml2-diagram-preview-buffer t]
     ["Export Image"          sysml2-diagram-export t]
     ["Open in PlantUML"      sysml2-diagram-open-plantuml t]
     ["Open in D2 Playground" sysml2-diagram-open-in-playground t])
    ("Analysis"
     ["Lint / Check"          sysml2-cli-check t]
     ["List Elements"         sysml2-cli-list t]
     ["Show Element"          sysml2-cli-show t]
     ["Traceability"          sysml2-cli-trace t]
     ["Statistics"            sysml2-cli-stats t]
     ["Dependencies"          sysml2-cli-deps t]
     ["Coverage"              sysml2-cli-coverage t]
     ["Find"                  sysml2-cli-find t]
     ["Generate Doc"          sysml2-cli-doc t]
     ["Analyze (list cases)"  sysml2-cli-analyze t]
     ["Analyze: Run Case"     sysml2-cli-analyze-run t]
     ["Render View"           sysml2-cli-view t]
     "--"
     ["Rollup"                sysml2-cli-rollup t]
     ["Interfaces"            sysml2-cli-interfaces t]
     ["Allocations"           sysml2-cli-allocation t]
     ["Project Diff"          sysml2-cli-diff t]
     "--"
     ["Refactor: Rename"      sysml2-cli-rename t]
     ["Refactor: Add Element" sysml2-cli-add t]
     ["Refactor: Remove"      sysml2-cli-remove t])
    ("API Server"
     ["List Projects"         sysml2-api-list-projects t]
     ["Query Elements"        sysml2-api-query t])
    ("Scaffold"
     ["Menu"                  sysml2-scaffold t]
     ["Model Skeleton"        sysml2-scaffold-model t]
     ["Package"               sysml2-scaffold-package t]
     ["Part Def"              sysml2-scaffold-part-def t]
     ["Port Def"              sysml2-scaffold-port-def t]
     ["Requirement Def"       sysml2-scaffold-requirement-def t]
     ["State Def"             sysml2-scaffold-state-def t]
     ["Action Def"            sysml2-scaffold-action-def t]
     ["Enum Def"              sysml2-scaffold-enum-def t]
     ["Use Case Def"          sysml2-scaffold-use-case-def t]
     ["Calc Def"              sysml2-scaffold-calc-def t])
    ("Connect"
     ["Connection"            sysml2-connect t]
     ["Flow"                  sysml2-insert-flow t]
     ["Binding"               sysml2-insert-binding t]
     ["Interface"             sysml2-insert-interface t]
     ["Allocation"            sysml2-insert-allocation t]
     ["Satisfy"               sysml2-insert-satisfy t]
     ["Verify"                sysml2-insert-verify t]
     ["Subject"               sysml2-insert-subject t])
    ("Simulate"
     ["Simulate"              sysml2-simulate t]
     ["List Simulatables"     sysml2-simulate-list t]
     ["Evaluate Calc"         sysml2-simulate-eval t]
     ["State Machine"         sysml2-simulate-state-machine t]
     ["Action Flow"           sysml2-simulate-action-flow t]
     ["REPL"                  sysml2-repl t])
    ("FMI / Co-Sim"
     ["Inspect FMU"           sysml2-fmi-inspect-fmu t]
     ["Extract Interfaces"    sysml2-fmi-extract-interfaces t]
     ["Generate Modelica"     sysml2-fmi-generate-modelica t]
     ["Compile FMU"           sysml2-fmi-compile-fmu t]
     ["Generate SSP"          sysml2-cosim-generate-ssp t]
     ["Run Co-Sim"            sysml2-cosim-run t]
     ["Results"               sysml2-cosim-results t]
     ["Verify Requirements"   sysml2-cosim-verify-requirements t]
     ["Full Pipeline"         sysml2-cosim-pipeline t])
    ("Inspect / Report"
     ["Summary"               sysml2-report-summary t]
     ["Traceability"          sysml2-report-traceability t]
     ["Export Markdown"       sysml2-report-export-markdown t]
     ["Export …"              sysml2-report-export t])
    ("Folding"
     ["Toggle"                hs-toggle-hiding t]
     ["Hide Block"            hs-hide-block t]
     ["Show Block"            hs-show-block t]
     ["Hide All"              hs-hide-all t]
     ["Show All"              hs-show-all t]
     ["Hide Level"            hs-hide-level t])
    ("LSP"
     ["Ensure / Start"        sysml2-lsp-ensure t]
     ["Restart"               sysml2-lsp-restart t])
    "--"
    ["Doctor (Health Check)"  sysml2-doctor t]
    ["Version"                sysml2-version t])
  "Specification passed to `easy-menu-define' for the SysML2 menu.")

(defvar sysml2-mode-menu nil
  "Menu keymap installed on `sysml2-mode-map'.  Set by `sysml2-menu-install'.")

(defun sysml2-menu-install (&optional keymap)
  "Install the SysML2 menu on KEYMAP (default `sysml2-mode-map').
Returns the installed menu keymap.  Safe to call multiple times."
  (let ((map (or keymap (and (boundp 'sysml2-mode-map) sysml2-mode-map))))
    (when map
      (easy-menu-define sysml2-mode-menu map
        "Menu for `sysml2-mode'."
        sysml2-mode-menu-spec)
      sysml2-mode-menu)))

;; Install the menu on every loaded keymap that supports it.  When the
;; mode hasn't loaded yet, this is a noop; sysml2-mode.el calls it
;; again after binding the keymap.
(when (boundp 'sysml2-mode-map)
  (sysml2-menu-install))

;; --- which-key prefix labels ---------------------------------------

(defconst sysml2--which-key-prefixes
  '(("C-c C-n"  "navigate")
    ("C-c C-d"  "diagram")
    ("C-c C-c"  "connect")
    ("C-c m"    "scaffold")
    ("C-c C-l"  "lsp")
    ("C-c C-a"  "api")
    ("C-c C-s"  "fmi/cosim")
    ("C-c C-x"  "simulate")
    ("C-c C-="  "format")
    ("C-c C-t"  "cli-analyze")
    ("C-c C-i"  "inspect/report")
    ("C-c C-f"  "fold")
    ("C-c C-r"  "rename"))
  "Prefix → label pairs registered with `which-key' for `sysml2-mode'.")

;;;###autoload
(defun sysml2-which-key-setup ()
  "Register `sysml2-mode' prefix descriptions with `which-key', if loaded.
Returns nil if `which-key' is unavailable, t on success."
  (when (and (featurep 'which-key)
             (fboundp 'which-key-add-major-mode-key-based-replacements))
    (dolist (entry sysml2--which-key-prefixes)
      (which-key-add-major-mode-key-based-replacements
       'sysml2-mode (car entry) (cadr entry))
      (which-key-add-major-mode-key-based-replacements
       'kerml-mode (car entry) (cadr entry)))
    t))

;; Run setup when which-key loads later in the session.
;;;###autoload
(with-eval-after-load 'which-key
  (sysml2-which-key-setup))

(provide 'sysml2-menu)
;;; sysml2-menu.el ends here
