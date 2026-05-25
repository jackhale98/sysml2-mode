;;; sysml2-transient.el --- transient.el menus for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Provides transient.el menus for the most-used command families,
;; supplementing the `easy-menu' menu-bar entries and giving keyboard
;; users a discoverable popup.
;;
;;   C-c C-d RET   →  diagram picker
;;   C-c m   RET   →  scaffold picker
;;   C-c C-t RET   →  CLI analyze picker

;;; Code:

(require 'transient)

(defvar sysml2-mode-map)

;; --- Diagram transient ---------------------------------------------

(transient-define-prefix sysml2-transient-diagram ()
  "Generate or preview a SysML diagram."
  ["Type"
   ("t" "Tree (BDD)"          sysml2-diagram-tree)
   ("i" "IBD (interconnect)"  sysml2-diagram-ibd)
   ("s" "State machine"       sysml2-diagram-state-machine)
   ("a" "Action flow"         sysml2-diagram-action-flow)
   ("r" "Requirement"         sysml2-diagram-requirement)
   ("u" "Use case"            sysml2-diagram-use-case)
   ("k" "Package"             sysml2-diagram-package)
   ("v" "View (filtered)"     sysml2-diagram-view)]
  ["Action"
   ("p" "Preview at point"    sysml2-diagram-preview)
   ("b" "Preview buffer"      sysml2-diagram-preview-buffer)
   ("e" "Export to file…"     sysml2-diagram-export)
   ("o" "Open in PlantUML"    sysml2-diagram-open-plantuml)
   ("w" "Open in D2 web"      sysml2-diagram-open-in-playground)])

;; --- Scaffold transient --------------------------------------------

(transient-define-prefix sysml2-transient-scaffold ()
  "Insert a SysML v2 skeleton at point."
  ["Containers"
   ("M" "Model skeleton"     sysml2-scaffold-model)
   ("p" "Package"            sysml2-scaffold-package)]
  ["Definitions"
   ("d" "Part def"           sysml2-scaffold-part-def)
   ("o" "Port def"           sysml2-scaffold-port-def)
   ("r" "Requirement def"    sysml2-scaffold-requirement-def)
   ("s" "State def"          sysml2-scaffold-state-def)
   ("a" "Action def"         sysml2-scaffold-action-def)
   ("c" "Calc def"           sysml2-scaffold-calc-def)
   ("e" "Enum def"           sysml2-scaffold-enum-def)
   ("u" "Use case def"       sysml2-scaffold-use-case-def)]
  ["Menu"
   ("m" "Show full menu"     sysml2-scaffold)])

;; --- CLI analyze transient -----------------------------------------

(transient-define-prefix sysml2-transient-analyze ()
  "Run sysml CLI analysis on the current file or project."
  ["Validation"
   ("l" "Lint / check"       sysml2-cli-check)
   ("v" "Coverage"           sysml2-cli-coverage)
   ("n" "Analyze cases"      sysml2-cli-analyze)]
  ["Query"
   ("s" "List elements"      sysml2-cli-list)
   ("w" "Show element"       sysml2-cli-show)
   ("f" "Find by pattern"    sysml2-cli-find)
   ("t" "Traceability"       sysml2-cli-trace)
   ("d" "Dependencies"       sysml2-cli-deps)]
  ["Project"
   ("a" "Stats"              sysml2-cli-stats)
   ("r" "Rollup"             sysml2-cli-rollup)
   ("i" "Interfaces"         sysml2-cli-interfaces)
   ("o" "Allocations"        sysml2-cli-allocation)
   ("D" "Diff two files"     sysml2-cli-diff)
   ("X" "Build / show index" sysml2-cli-index)]
  ["Refactor"
   ("R" "Rename (project)"   sysml2-cli-rename)
   ("A" "Add element"        sysml2-cli-add)
   ("K" "Remove element"     sysml2-cli-remove)]
  ["Docs"
   ("g" "Generate Markdown"  sysml2-cli-doc)])

;; --- Keymap installation -------------------------------------------

(defun sysml2-transient-install (&optional keymap)
  "Bind RET-suffixed entry points on KEYMAP (default `sysml2-mode-map').
- C-c C-d RET → diagram transient
- C-c m   RET → scaffold transient
- C-c C-t RET → CLI analyze transient"
  (let ((map (or keymap (and (boundp 'sysml2-mode-map) sysml2-mode-map))))
    (when map
      (define-key map (kbd "C-c C-d RET") #'sysml2-transient-diagram)
      (define-key map (kbd "C-c m   RET") #'sysml2-transient-scaffold)
      (define-key map (kbd "C-c C-t RET") #'sysml2-transient-analyze))))

(when (boundp 'sysml2-mode-map)
  (sysml2-transient-install))

(provide 'sysml2-transient)
;;; sysml2-transient.el ends here
