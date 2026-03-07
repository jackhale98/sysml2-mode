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
(declare-function sysml2-outline-refresh "sysml2-outline")
(declare-function sysml2--outline-goto "sysml2-outline")
(declare-function sysml2--outline-goto-and-close "sysml2-outline")
(declare-function sysml2-goto-definition "sysml2-navigation")
(declare-function sysml2-connect "sysml2-completion")
(declare-function sysml2-insert-flow "sysml2-completion")
(declare-function sysml2-insert-binding "sysml2-completion")
(declare-function sysml2-insert-interface "sysml2-completion")
(declare-function sysml2-insert-allocation "sysml2-completion")
(declare-function sysml2-insert-satisfy "sysml2-completion")
(declare-function sysml2-api-list-projects "sysml2-api")
(declare-function sysml2-api-query "sysml2-api")
(declare-function sysml2-lsp-ensure "sysml2-lsp")
(declare-function sysml2-lsp-restart "sysml2-lsp")

(defvar sysml2-mode-map)
(defvar sysml2-outline-mode-map)

(with-eval-after-load 'evil

  ;; Go to definition with gd (standard evil binding)
  (evil-define-key* 'normal sysml2-mode-map
    (kbd "gd") #'sysml2-goto-definition)

  ;; Outline panel: evil bindings for navigation
  (evil-define-key* 'normal sysml2-outline-mode-map
    (kbd "RET") #'sysml2--outline-goto
    (kbd "o")   #'sysml2--outline-goto-and-close
    (kbd "gr")  #'sysml2-outline-refresh
    (kbd "q")   #'sysml2-outline-toggle)

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
     "o"   '(sysml2-outline-toggle :which-key "outline panel")
     ;; Connections
     "c"   '(:ignore t :which-key "connect")
     "c c" '(sysml2-connect :which-key "connection")
     "c f" '(sysml2-insert-flow :which-key "flow")
     "c b" '(sysml2-insert-binding :which-key "binding")
     "c i" '(sysml2-insert-interface :which-key "interface")
     "c a" '(sysml2-insert-allocation :which-key "allocation")
     "c s" '(sysml2-insert-satisfy :which-key "satisfy")
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
