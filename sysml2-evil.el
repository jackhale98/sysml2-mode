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
(declare-function sysml2-diagram-type "sysml2-diagram")
(declare-function sysml2-diagram-open-plantuml "sysml2-diagram")
(declare-function sysml2-diagram-render-examples "sysml2-diagram")
(declare-function sysml2-diagram-generate-examples "sysml2-diagram")
(declare-function sysml2-fmi-inspect-fmu "sysml2-fmi")
(declare-function sysml2-fmi-extract-interfaces "sysml2-fmi")
(declare-function sysml2-fmi-generate-modelica "sysml2-fmi")
(declare-function sysml2-fmi-validate-interfaces "sysml2-fmi")
(declare-function sysml2-cosim-generate-ssp "sysml2-cosim")
(declare-function sysml2-cosim-run "sysml2-cosim")
(declare-function sysml2-cosim-results "sysml2-cosim")
(declare-function sysml2-cosim-verify-requirements "sysml2-cosim")
(declare-function sysml2-outline-toggle "sysml2-outline")
(declare-function sysml2-api-list-projects "sysml2-api")
(declare-function sysml2-api-query "sysml2-api")
(declare-function sysml2-lsp-ensure "sysml2-lsp")
(declare-function sysml2-lsp-restart "sysml2-lsp")

(defvar sysml2-mode-map)

(with-eval-after-load 'evil

  ;; Normal-state bindings on localleader (,) as universal fallback
  (evil-define-key* 'normal sysml2-mode-map
    ;; Navigation
    (kbd ", n o") #'imenu
    (kbd ", n t") #'sysml2-outline-toggle
    ;; Diagram
    (kbd ", d p") #'sysml2-diagram-preview
    (kbd ", d b") #'sysml2-diagram-preview-buffer
    (kbd ", d e") #'sysml2-diagram-export
    (kbd ", d t") #'sysml2-diagram-type
    (kbd ", d o") #'sysml2-diagram-open-plantuml
    (kbd ", d r") #'sysml2-diagram-render-examples
    (kbd ", d g") #'sysml2-diagram-generate-examples
    ;; API
    (kbd ", a l") #'sysml2-api-list-projects
    (kbd ", a q") #'sysml2-api-query
    ;; LSP
    (kbd ", l s") #'sysml2-lsp-ensure
    (kbd ", l r") #'sysml2-lsp-restart
    ;; Simulation / FMI
    (kbd ", s i") #'sysml2-fmi-inspect-fmu
    (kbd ", s e") #'sysml2-fmi-extract-interfaces
    (kbd ", s m") #'sysml2-fmi-generate-modelica
    (kbd ", s v") #'sysml2-fmi-validate-interfaces
    (kbd ", s g") #'sysml2-cosim-generate-ssp
    (kbd ", s r") #'sysml2-cosim-run
    (kbd ", s p") #'sysml2-cosim-results
    (kbd ", s c") #'sysml2-cosim-verify-requirements)

  ;; general.el SPC m bindings (Doom/Spacemacs style)
  (with-eval-after-load 'general
    (general-define-key
     :states 'normal
     :keymaps 'sysml2-mode-map
     :prefix "SPC m"
     ;; Navigation
     "n"   '(:ignore t :which-key "navigate")
     "n o" '(imenu :which-key "outline (imenu)")
     "n t" '(sysml2-outline-toggle :which-key "toggle outline panel")
     ;; Diagram
     "d"   '(:ignore t :which-key "diagram")
     "d p" '(sysml2-diagram-preview :which-key "preview at point")
     "d b" '(sysml2-diagram-preview-buffer :which-key "preview buffer")
     "d e" '(sysml2-diagram-export :which-key "export")
     "d t" '(sysml2-diagram-type :which-key "select type")
     "d o" '(sysml2-diagram-open-plantuml :which-key "open PlantUML")
     "d r" '(sysml2-diagram-render-examples :which-key "render examples")
     "d g" '(sysml2-diagram-generate-examples :which-key "generate examples")
     ;; API
     "a"   '(:ignore t :which-key "api")
     "a l" '(sysml2-api-list-projects :which-key "list projects")
     "a q" '(sysml2-api-query :which-key "query")
     ;; LSP
     "l"   '(:ignore t :which-key "lsp")
     "l s" '(sysml2-lsp-ensure :which-key "start")
     "l r" '(sysml2-lsp-restart :which-key "restart")
     ;; Simulation / FMI
     "s"   '(:ignore t :which-key "simulation")
     "s i" '(sysml2-fmi-inspect-fmu :which-key "inspect FMU")
     "s e" '(sysml2-fmi-extract-interfaces :which-key "extract interfaces")
     "s m" '(sysml2-fmi-generate-modelica :which-key "generate Modelica")
     "s v" '(sysml2-fmi-validate-interfaces :which-key "validate interfaces")
     "s g" '(sysml2-cosim-generate-ssp :which-key "generate SSP")
     "s r" '(sysml2-cosim-run :which-key "run simulation")
     "s p" '(sysml2-cosim-results :which-key "plot results")
     "s c" '(sysml2-cosim-verify-requirements :which-key "verify requirements"))))

(provide 'sysml2-evil)
;;; sysml2-evil.el ends here
