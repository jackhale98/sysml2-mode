;;; sysml2-evil.el --- Evil-mode integration for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Optional evil-mode keybindings for sysml2-mode.
;;
;; Provides two layers of bindings:
;;   1. Localleader (`,') fallback via `evil-define-key*' — works for
;;      all evil users without extra packages.
;;   2. `SPC m' major-mode leader via general.el — Doom/Spacemacs style,
;;      only activated when general.el is loaded.
;;
;; Neither evil nor general is a hard dependency; both are loaded lazily
;; via `with-eval-after-load'.

;;; Code:

(require 'sysml2-vars)

;; Forward declarations for optional dependencies
(declare-function evil-define-key* "evil-core")
(declare-function general-define-key "general")
(declare-function sysml2-diagram-preview "sysml2-diagram")
(declare-function sysml2-diagram-preview-buffer "sysml2-diagram")
(declare-function sysml2-diagram-export "sysml2-diagram")
(declare-function sysml2-diagram-open-plantuml "sysml2-diagram")
(declare-function sysml2-diagram-open-in-playground "sysml2-diagram")
(declare-function sysml2-diagram-tree "sysml2-diagram")
(declare-function sysml2-diagram-ibd "sysml2-diagram")
(declare-function sysml2-diagram-state-machine "sysml2-diagram")
(declare-function sysml2-diagram-action-flow "sysml2-diagram")
(declare-function sysml2-diagram-requirement "sysml2-diagram")
(declare-function sysml2-diagram-use-case "sysml2-diagram")
(declare-function sysml2-diagram-package "sysml2-diagram")
(declare-function sysml2-diagram-view "sysml2-diagram")
(declare-function sysml2-fmi-inspect-fmu "sysml2-fmi")
(declare-function sysml2-fmi-extract-interfaces "sysml2-fmi")
(declare-function sysml2-fmi-generate-modelica "sysml2-fmi")
(declare-function sysml2-fmi-generate-all-modelica "sysml2-fmi")
(declare-function sysml2-fmi-compile-fmu "sysml2-fmi")
(declare-function sysml2-fmi-compile-all-fmus "sysml2-fmi")
(declare-function sysml2-fmi-validate-interfaces "sysml2-fmi")
(declare-function sysml2-fmi-validate-all "sysml2-fmi")
(declare-function sysml2-fmi-dashboard "sysml2-fmi")
(declare-function sysml2-cosim-generate-ssp "sysml2-cosim")
(declare-function sysml2-cosim-run "sysml2-cosim")
(declare-function sysml2-cosim-results "sysml2-cosim")
(declare-function sysml2-cosim-verify-requirements "sysml2-cosim")
(declare-function sysml2-cosim-pipeline "sysml2-cosim")
(declare-function sysml2-outline-toggle "sysml2-outline")
(declare-function sysml2-outline-refresh "sysml2-outline")
(declare-function sysml2--outline-goto "sysml2-outline")
(declare-function sysml2--outline-goto-and-close "sysml2-outline")
(declare-function sysml2-goto-definition "sysml2-navigation")
(declare-function sysml2-rename-symbol "sysml2-navigation")
(declare-function sysml2-connect "sysml2-completion")
(declare-function sysml2-insert-flow "sysml2-completion")
(declare-function sysml2-insert-binding "sysml2-completion")
(declare-function sysml2-insert-interface "sysml2-completion")
(declare-function sysml2-insert-allocation "sysml2-completion")
(declare-function sysml2-insert-satisfy "sysml2-completion")
(declare-function sysml2-insert-verify "sysml2-completion")
(declare-function sysml2-insert-subject "sysml2-completion")
(declare-function sysml2-api-list-projects "sysml2-api")
(declare-function sysml2-api-query "sysml2-api")
(declare-function sysml2-lsp-ensure "sysml2-lsp")
(declare-function sysml2-lsp-restart "sysml2-lsp")
(declare-function sysml2-scaffold "sysml2-completion")
(declare-function sysml2-scaffold-package "sysml2-completion")
(declare-function sysml2-scaffold-part-def "sysml2-completion")
(declare-function sysml2-scaffold-port-def "sysml2-completion")
(declare-function sysml2-scaffold-requirement-def "sysml2-completion")
(declare-function sysml2-scaffold-state-def "sysml2-completion")
(declare-function sysml2-scaffold-action-def "sysml2-completion")
(declare-function sysml2-scaffold-enum-def "sysml2-completion")
(declare-function sysml2-scaffold-use-case-def "sysml2-completion")
(declare-function sysml2-scaffold-calc-def "sysml2-completion")
(declare-function sysml2-report-summary "sysml2-report")
(declare-function sysml2-report-traceability "sysml2-report")
(declare-function sysml2-impact-analysis "sysml2-report")
(declare-function sysml2-report-export-markdown "sysml2-report")
(declare-function sysml2-report-export "sysml2-report")
(declare-function sysml2-simulate "sysml2-simulate")
(declare-function sysml2-simulate-list "sysml2-simulate")
(declare-function sysml2-simulate-eval "sysml2-simulate")
(declare-function sysml2-simulate-state-machine "sysml2-simulate")
(declare-function sysml2-simulate-action-flow "sysml2-simulate")

(defvar sysml2-mode-map)

(with-eval-after-load 'evil

  ;; Go to definition with gd (standard evil binding)
  (evil-define-key* 'normal sysml2-mode-map
    (kbd "gd") #'sysml2-goto-definition)

  ;; Outline panel: evil bindings for navigation
  ;; Deferred until sysml2-outline is loaded, since sysml2-evil may be
  ;; required before sysml2-outline.
  (with-eval-after-load 'sysml2-outline
    (defvar sysml2-outline-mode-map)
    (evil-define-key* 'normal sysml2-outline-mode-map
      (kbd "RET") #'sysml2--outline-goto
      (kbd "o")   #'sysml2--outline-goto-and-close
      (kbd "gr")  #'sysml2-outline-refresh
      (kbd "q")   #'sysml2-outline-toggle))

  ;; general.el SPC m bindings (Doom/Spacemacs style)
  (with-eval-after-load 'general
    (general-define-key
     :states 'normal
     :keymaps 'sysml2-mode-map
     :prefix "SPC m"
     ;; Navigation
     "n"   '(:ignore t :which-key "navigate")
     "n o" '(imenu :which-key "outline (imenu)")
     "n d" '(sysml2-goto-definition :which-key "go to definition")
     "r" '(sysml2-rename-symbol :which-key "rename symbol")
     "o"   '(sysml2-outline-toggle :which-key "outline panel")
     ;; Connections
     "c"   '(:ignore t :which-key "connect")
     "c c" '(sysml2-connect :which-key "connection")
     "c f" '(sysml2-insert-flow :which-key "flow")
     "c b" '(sysml2-insert-binding :which-key "binding")
     "c i" '(sysml2-insert-interface :which-key "interface")
     "c a" '(sysml2-insert-allocation :which-key "allocation")
     "c s" '(sysml2-insert-satisfy :which-key "satisfy")
     "c v" '(sysml2-insert-verify :which-key "verify")
     "c u" '(sysml2-insert-subject :which-key "subject")
     ;; Diagram — direct type commands
     "d"   '(:ignore t :which-key "diagram")
     "d t" '(sysml2-diagram-tree :which-key "tree")
     "d i" '(sysml2-diagram-ibd :which-key "IBD (interconnection)")
     "d s" '(sysml2-diagram-state-machine :which-key "state machine")
     "d a" '(sysml2-diagram-action-flow :which-key "action flow")
     "d r" '(sysml2-diagram-requirement :which-key "requirement tree")
     "d u" '(sysml2-diagram-use-case :which-key "use case")
     "d k" '(sysml2-diagram-package :which-key "package")
     ;; Diagram — view-filtered
     "d v" '(sysml2-diagram-view :which-key "view filter")
     ;; Diagram — general
     "d p" '(sysml2-diagram-preview :which-key "preview at point")
     "d b" '(sysml2-diagram-preview-buffer :which-key "preview buffer")
     "d e" '(sysml2-diagram-export :which-key "export")
     "d o" '(sysml2-diagram-open-plantuml :which-key "open source")
     "d w" '(sysml2-diagram-open-in-playground :which-key "web playground")
     ;; API
     "a"   '(:ignore t :which-key "api")
     "a l" '(sysml2-api-list-projects :which-key "list projects")
     "a q" '(sysml2-api-query :which-key "query")
     ;; LSP
     "l"   '(:ignore t :which-key "lsp")
     "l s" '(sysml2-lsp-ensure :which-key "start")
     "l r" '(sysml2-lsp-restart :which-key "restart")
     ;; FMI / Co-simulation
     "s"   '(:ignore t :which-key "simulation/fmi")
     "s i" '(sysml2-fmi-inspect-fmu :which-key "inspect FMU")
     "s e" '(sysml2-fmi-extract-interfaces :which-key "extract interfaces")
     "s m" '(sysml2-fmi-generate-modelica :which-key "generate Modelica")
     "s M" '(sysml2-fmi-generate-all-modelica :which-key "generate all Modelica")
     "s b" '(sysml2-fmi-compile-fmu :which-key "compile FMU")
     "s B" '(sysml2-fmi-compile-all-fmus :which-key "compile all FMUs")
     "s v" '(sysml2-fmi-validate-interfaces :which-key "validate interfaces")
     "s V" '(sysml2-fmi-validate-all :which-key "validate all FMUs")
     "s d" '(sysml2-fmi-dashboard :which-key "FMI dashboard")
     "s g" '(sysml2-cosim-generate-ssp :which-key "generate SSP")
     "s r" '(sysml2-cosim-run :which-key "run co-simulation")
     "s p" '(sysml2-cosim-results :which-key "plot results")
     "s c" '(sysml2-cosim-verify-requirements :which-key "verify requirements")
     "s P" '(sysml2-cosim-pipeline :which-key "full pipeline")
     ;; SysML Simulation (sysml2-cli simulate)
     "x"   '(:ignore t :which-key "simulate")
     "x s" '(sysml2-simulate :which-key "simulate menu")
     "x l" '(sysml2-simulate-list :which-key "list constructs")
     "x e" '(sysml2-simulate-eval :which-key "eval constraint/calc")
     "x m" '(sysml2-simulate-state-machine :which-key "state machine")
     "x a" '(sysml2-simulate-action-flow :which-key "action flow")
     ;; Inspect / Report
     "i"   '(:ignore t :which-key "inspect")
     "i s" '(sysml2-report-summary :which-key "model summary")
     "i t" '(sysml2-report-traceability :which-key "traceability matrix")
     "i a" '(sysml2-impact-analysis :which-key "impact analysis")
     "i m" '(sysml2-report-export-markdown :which-key "export Markdown")
     "i e" '(sysml2-report-export :which-key "export (Pandoc)")
     ;; Model Scaffolding
     "m"   '(:ignore t :which-key "scaffold")
     "m m" '(sysml2-scaffold :which-key "scaffold menu")
     "m p" '(sysml2-scaffold-package :which-key "package")
     "m d" '(sysml2-scaffold-part-def :which-key "part def")
     "m o" '(sysml2-scaffold-port-def :which-key "port def")
     "m r" '(sysml2-scaffold-requirement-def :which-key "requirement def")
     "m s" '(sysml2-scaffold-state-def :which-key "state def")
     "m a" '(sysml2-scaffold-action-def :which-key "action def")
     "m e" '(sysml2-scaffold-enum-def :which-key "enum def")
     "m u" '(sysml2-scaffold-use-case-def :which-key "use case def")
     "m c" '(sysml2-scaffold-calc-def :which-key "calc def")
     ;; Code folding
     "f"   '(:ignore t :which-key "fold")
     "f t" '(hs-toggle-hiding :which-key "toggle")
     "f h" '(hs-hide-block :which-key "hide block")
     "f s" '(hs-show-block :which-key "show block")
     "f H" '(hs-hide-all :which-key "hide all")
     "f S" '(hs-show-all :which-key "show all")
     "f l" '(hs-hide-level :which-key "hide level"))))

(provide 'sysml2-evil)
;;; sysml2-evil.el ends here
