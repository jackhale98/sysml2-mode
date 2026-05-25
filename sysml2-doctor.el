;;; sysml2-doctor.el --- Health-check command for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; `M-x sysml2-doctor' probes the user's environment for every external
;; dependency the mode can leverage and reports findings in a buffer.
;; Run it after first install — or any time something stops working — to
;; quickly distinguish "the mode is broken" from "I haven't installed
;; the tool yet."
;;
;; Each check is a `sysml2-doctor-check' struct with:
;;   :label     human-readable name
;;   :probe     thunk; returns truthy detail (path/string) on success
;;   :severity  'error (required) or 'warn (optional)
;;   :hint      suggestion text when missing (optional)

;;; Code:

(require 'cl-lib)
(require 'sysml2-vars)

(cl-defstruct sysml2-doctor-check
  label probe severity hint)

;; --- Individual probes ---------------------------------------------

(defun sysml2-doctor--probe-cli ()
  "Locate sysml CLI."
  (sysml2--find-executable (or sysml2-cli-executable "sysml")))

(defun sysml2-doctor--probe-d2 ()
  "Locate D2 binary."
  (or sysml2-d2-executable-path
      (sysml2--find-executable "d2")))

(defun sysml2-doctor--probe-grammar ()
  "Verify that the SysML tree-sitter grammar is installed and ready."
  (and (fboundp 'treesit-available-p)
       (treesit-available-p)
       (fboundp 'treesit-ready-p)
       (treesit-ready-p 'sysml t)
       "installed"))

(defun sysml2-doctor--probe-lsp ()
  "Locate the active LSP server binary."
  (let ((server (pcase sysml2-lsp-server
                  ('sysml-lsp "sysml-lsp")
                  ('pilot "pilot")
                  ('syside "syside")
                  ('syson "syson")
                  (_ nil))))
    (when server
      (or sysml2-lsp-server-path
          (sysml2--find-executable server)))))

(defun sysml2-doctor--probe-plantuml ()
  "Locate PlantUML."
  (or sysml2-plantuml-executable-path
      sysml2-plantuml-jar-path
      (sysml2--find-executable "plantuml")))

(defun sysml2-doctor--probe-pandoc ()
  "Locate Pandoc."
  (or sysml2-report-pandoc-executable
      (sysml2--find-executable "pandoc")))

(defun sysml2-doctor--probe-stdlib ()
  "Resolve the SysML standard library path."
  (when (fboundp 'sysml2-project-library-path)
    (sysml2-project-library-path)))

(defun sysml2-doctor--probe-graphviz ()
  "Locate GraphViz dot."
  (or sysml2-graphviz-dot-path
      (sysml2--find-executable "dot")))

;; --- Check registry -------------------------------------------------

(defun sysml2-doctor--all-checks ()
  "Return the canonical list of `sysml2-doctor-check' structs."
  (list
   (make-sysml2-doctor-check
    :label "sysml CLI"
    :probe #'sysml2-doctor--probe-cli
    :severity 'error
    :hint "Install from https://github.com/jackhale98/sysml-cli (cargo install --path crates/sysml-cli)")
   (make-sysml2-doctor-check
    :label "Tree-sitter grammar"
    :probe #'sysml2-doctor--probe-grammar
    :severity 'warn
    :hint "Run: (sysml2-install-tree-sitter-grammar) — falls back to regex if absent.")
   (make-sysml2-doctor-check
    :label "LSP server"
    :probe #'sysml2-doctor--probe-lsp
    :severity 'warn
    :hint "Install sysml-lsp (recommended) or set `sysml2-lsp-server'.")
   (make-sysml2-doctor-check
    :label "D2 binary"
    :probe #'sysml2-doctor--probe-d2
    :severity 'warn
    :hint "Install from https://d2lang.com — falls back to play.d2lang.com in browser.")
   (make-sysml2-doctor-check
    :label "PlantUML"
    :probe #'sysml2-doctor--probe-plantuml
    :severity 'warn
    :hint "Optional legacy backend; install only if you set `sysml2-diagram-backend' to 'plantuml.")
   (make-sysml2-doctor-check
    :label "GraphViz dot"
    :probe #'sysml2-doctor--probe-graphviz
    :severity 'warn
    :hint "Optional; used by some D2 layouts and PlantUML.")
   (make-sysml2-doctor-check
    :label "Pandoc"
    :probe #'sysml2-doctor--probe-pandoc
    :severity 'warn
    :hint "Optional; required only for `sysml2-report-export' to non-Markdown formats.")
   (make-sysml2-doctor-check
    :label "Standard library"
    :probe #'sysml2-doctor--probe-stdlib
    :severity 'warn
    :hint "Set `sysml2-standard-library-path' or run from inside a sysml.library/ project.")))

;; --- Execution & rendering ------------------------------------------

(defun sysml2-doctor--run-one (check)
  "Run a single CHECK and return a result plist."
  (let* ((label (sysml2-doctor-check-label check))
         (severity (sysml2-doctor-check-severity check))
         (hint (sysml2-doctor-check-hint check))
         (detail (condition-case err
                     (funcall (sysml2-doctor-check-probe check))
                   (error (format "probe error: %S" err)))))
    (list :label label
          :status (if detail 'ok 'missing)
          :detail (cond ((stringp detail) detail)
                        (detail (format "%S" detail))
                        (t nil))
          :severity severity
          :hint hint)))

(defun sysml2-doctor-run ()
  "Run all doctor checks and return the list of result plists."
  (mapcar #'sysml2-doctor--run-one (sysml2-doctor--all-checks)))

(defconst sysml2-doctor-buffer-name "*SysML2 Doctor*")

(defun sysml2-doctor--status-icon (status severity)
  "Return a short marker for STATUS / SEVERITY."
  (cond
   ((eq status 'ok) "[ok]   ")
   ((eq status 'missing)
    (if (eq severity 'error) "[FAIL] " "[warn] "))
   (t "[skip] ")))

(defun sysml2-doctor--render (results)
  "Render RESULTS into a buffer and return it."
  (let ((buf (get-buffer-create sysml2-doctor-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "SysML2 Doctor\n")
        (insert "=============\n\n")
        (insert
         (format "sysml2-mode %s — checked %s\n\n"
                 (if (boundp 'sysml2-mode-version) sysml2-mode-version "?")
                 (format-time-string "%Y-%m-%d %H:%M")))
        (dolist (r results)
          (insert (sysml2-doctor--status-icon
                   (plist-get r :status)
                   (plist-get r :severity)))
          (insert (format "%-22s" (plist-get r :label)))
          (cond
           ((eq (plist-get r :status) 'ok)
            (insert (or (plist-get r :detail) "found")))
           (t
            (insert "MISSING")
            (when (plist-get r :hint)
              (insert (format "\n%24s%s" "" (plist-get r :hint))))))
          (insert "\n"))
        (insert "\n")
        (insert "Legend: [ok] working   [warn] optional, not installed   [FAIL] required, not installed\n")
        (goto-char (point-min)))
      (special-mode))
    buf))

;;;###autoload
(defun sysml2-doctor ()
  "Probe external dependencies and display a health-check report.

Each row shows the status of an external tool sysml2-mode can leverage.
[FAIL] entries indicate required tools that are missing.  [warn]
entries are optional features."
  (interactive)
  (let* ((results (sysml2-doctor-run))
         (buf (sysml2-doctor--render results)))
    (when (called-interactively-p 'any)
      (display-buffer buf))
    buf))

;;;###autoload
(defun sysml2-doctor-check (label)
  "Run a single doctor check by LABEL and message the result."
  (interactive
   (list (completing-read
          "Check: "
          (mapcar #'sysml2-doctor-check-label (sysml2-doctor--all-checks))
          nil t)))
  (let* ((check (cl-find label (sysml2-doctor--all-checks)
                         :key #'sysml2-doctor-check-label
                         :test #'string=))
         (result (and check (sysml2-doctor--run-one check))))
    (when result
      (message "%s%s: %s"
               (sysml2-doctor--status-icon
                (plist-get result :status)
                (plist-get result :severity))
               (plist-get result :label)
               (or (plist-get result :detail) "missing")))
    result))

(provide 'sysml2-doctor)
;;; sysml2-doctor.el ends here
