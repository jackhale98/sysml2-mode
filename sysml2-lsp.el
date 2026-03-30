;;; sysml2-lsp.el --- LSP integration for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; LSP client configuration for SysML v2 language servers.
;; Supports both eglot (built-in since Emacs 29) and lsp-mode.
;;
;; Supported servers:
;;   - sysml-lsp (sysml-cli project) — Rust-based, recommended
;;   - SySide LSP (Sensmetry) — ARCHIVED since Oct 2025
;;   - SysML v2 Pilot Implementation — Java jar
;;   - Eclipse SysON LSP — VS Code-oriented, experimental
;;
;; Server auto-detection tries custom path, then $PATH, then known jars.
;; Integration uses `with-eval-after-load' to avoid hard dependencies.
;;
;; The sysml-lsp server (from the sysml-cli project) provides 17 LSP
;; capabilities including inlay hints, type hierarchy, add-import code
;; actions, and semantic tokens.  Install with:
;;   cargo install --path crates/sysml-lsp

;;; Code:

(require 'sysml2-vars)
(require 'sysml2-project)

;; Forward declarations for optional dependencies
(declare-function eglot-ensure "eglot")
(declare-function eglot-reconnect "eglot")
(declare-function eglot--managed-mode "eglot")
(declare-function lsp-deferred "lsp-mode")
(declare-function lsp-restart-workspace "lsp-mode")
(declare-function lsp-register-client "lsp-mode")
(declare-function make-lsp-client "lsp-mode")
(declare-function lsp-stdio-connection "lsp-mode")
(declare-function lsp-activate-on "lsp-mode")
(declare-function eglot-current-server "eglot")

(defvar eglot-server-programs)
(defvar lsp-language-id-configuration)

;; --- Server resolution ---

(defun sysml2--resolve-lsp-server ()
  "Resolve the LSP server command for SysML v2.
Returns a list of strings (command + args) or nil if not found.
Checks in order:
  1. `sysml2-lsp-server-path' (custom path)
  2. `sysml-lsp' on PATH (Rust-based, from sysml-cli project)
  3. `syside-lsp' on PATH (for Syside, archived)
  4. Java + known jar paths (for Pilot Implementation / SysON)"
  (cond
   ;; Explicit custom path
   ((and sysml2-lsp-server-path
         (file-executable-p sysml2-lsp-server-path))
    (list sysml2-lsp-server-path))
   ;; sysml-lsp (Rust-based, recommended)
   ((and (memq sysml2-lsp-server '(sysml-lsp nil))
         (sysml2--find-executable "sysml-lsp"))
    (list (sysml2--find-executable "sysml-lsp") "--stdio"))
   ;; Pilot Implementation (Java jar)
   ((and (memq sysml2-lsp-server '(pilot nil))
         (executable-find "java")
         sysml2-lsp-server-path
         (file-exists-p sysml2-lsp-server-path))
    (list (executable-find "java") "-jar" sysml2-lsp-server-path))
   ;; Syside LSP (archived)
   ((and (eq sysml2-lsp-server 'syside)
         (sysml2--find-executable "syside-lsp"))
    (list (sysml2--find-executable "syside-lsp") "--stdio"))
   ;; Eclipse SysON (Java jar)
   ((and (eq sysml2-lsp-server 'syson)
         (executable-find "java")
         sysml2-lsp-server-path
         (file-exists-p sysml2-lsp-server-path))
    (list (executable-find "java") "-jar" sysml2-lsp-server-path))
   ;; Nothing found
   (t nil)))

;; --- Interactive commands ---

(defun sysml2-lsp-ensure ()
  "Start or connect to the SysML v2 LSP server.
Uses eglot if available, then lsp-mode.  Shows a message if no
server can be found."
  (interactive)
  (let ((server (sysml2--resolve-lsp-server)))
    (cond
     ((null server)
      (message "sysml2-mode: No LSP server found. Set `sysml2-lsp-server-path' or install syside-lsp."))
     ((featurep 'eglot)
      (eglot-ensure))
     ((featurep 'lsp-mode)
      (lsp-deferred))
     (t
      (message "sysml2-mode: Install eglot or lsp-mode for LSP support.")))))

(defun sysml2-lsp-restart ()
  "Restart the current SysML v2 LSP session."
  (interactive)
  (cond
   ((and (featurep 'eglot)
         (bound-and-true-p eglot--managed-mode))
    (eglot-reconnect (eglot-current-server)))
   ((featurep 'lsp-mode)
    (lsp-restart-workspace))
   (t
    (message "sysml2-mode: No active LSP session to restart."))))

;; --- Silent setup (called from mode body) ---

(defun sysml2-lsp-setup ()
  "Set up LSP for the current SysML v2 buffer if a server is available.
Called from the mode body.  Silently skips if no server found or
`sysml2-lsp-server' is \\='none."
  (unless (eq sysml2-lsp-server 'none)
    (when (sysml2--resolve-lsp-server)
      (cond
       ((featurep 'eglot)
        (eglot-ensure))
       ((featurep 'lsp-mode)
        (lsp-deferred))))))

;; --- Eglot integration ---

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               `((sysml2-mode kerml-mode) . ,#'sysml2--resolve-lsp-server)))

;; --- lsp-mode integration ---

(with-eval-after-load 'lsp-mode
  (add-to-list 'lsp-language-id-configuration '(sysml2-mode . "sysml"))
  (add-to-list 'lsp-language-id-configuration '(kerml-mode . "kerml"))
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection #'sysml2--resolve-lsp-server)
    :activation-fn (lsp-activate-on "sysml" "kerml")
    :server-id 'sysml2-lsp
    :priority -1)))

(provide 'sysml2-lsp)
;;; sysml2-lsp.el ends here
