;;; sysml2-cli-commands.el --- SysML CLI analysis commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Interactive wrappers for sysml CLI analysis commands.
;; These run `sysml check', `sysml list', `sysml show', `sysml trace',
;; `sysml stats', `sysml deps', `sysml coverage', `sysml find',
;; `sysml doc', and `sysml analyze' on the current buffer's file.
;;
;; Requires `sysml' CLI (v0.5.0+) on exec-path.

;;; Code:

(require 'cl-lib)
(require 'sysml2-vars)

;;; Public API:
;;
;; Functions:
;;   `sysml2-cli-lint'     -- Run lint/check on current file
;;   `sysml2-cli-check'    -- Run comprehensive checks (same as lint)
;;   `sysml2-cli-list'     -- List model elements
;;   `sysml2-cli-show'     -- Show element details
;;   `sysml2-cli-trace'    -- Requirements traceability
;;   `sysml2-cli-stats'    -- Aggregate statistics
;;   `sysml2-cli-deps'     -- Dependency analysis
;;   `sysml2-cli-coverage' -- Model coverage analysis
;;   `sysml2-cli-find'     -- Search elements by name pattern
;;   `sysml2-cli-doc'      -- Generate documentation
;;   `sysml2-cli-analyze'  -- Run analysis cases

(defvar sysml2-cli-output-buffer "*SysML CLI*"
  "Name of the CLI output buffer.")

;; --- Internal helpers ---

(defun sysml2-cli--exe-name ()
  "Return the CLI executable name."
  (or sysml2-cli-executable "sysml"))

(defun sysml2-cli--check-executable ()
  "Check that the sysml CLI is available.  Signal an error if not found."
  (unless (sysml2--find-executable (sysml2-cli--exe-name))
    (user-error "Cannot find `%s' on exec-path.  Install from https://github.com/jackhale98/sysml-cli"
                (sysml2-cli--exe-name))))

(defun sysml2-cli--resolve-executable ()
  "Return the full path to the sysml CLI."
  (or (sysml2--find-executable (sysml2-cli--exe-name))
      (sysml2--platform-exe-name (sysml2-cli--exe-name))))

(defun sysml2-cli--ensure-file ()
  "Return the current buffer's file name.  Signal error if unsaved."
  (or buffer-file-name
      (user-error "Buffer is not visiting a file")))

(defun sysml2-cli--run (args &optional title)
  "Run sysml CLI with ARGS and display output.
TITLE is shown as a header in the output buffer.
Returns the output string."
  (sysml2-cli--check-executable)
  (let* ((exe (sysml2-cli--resolve-executable))
         (stderr-file (make-temp-file "sysml2-cli-stderr"))
         (stdout (with-output-to-string
                   (with-current-buffer standard-output
                     (apply #'call-process exe nil
                            (list t stderr-file) nil args))))
         (stderr (with-temp-buffer
                   (insert-file-contents stderr-file)
                   (prog1 (buffer-string)
                     (ignore-errors (delete-file stderr-file)))))
         (output (if (string-empty-p stderr) stdout
                   (concat stdout
                           (unless (string-empty-p stdout) "\n")
                           stderr))))
    (when title
      (sysml2-cli--display title output))
    output))

(defun sysml2-cli--display (title output)
  "Display CLI OUTPUT in the results buffer with TITLE."
  (let ((buf (get-buffer-create sysml2-cli-output-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (concat "=== " title " ===\n\n") 'face 'bold))
        (if (string-empty-p (string-trim output))
            (insert "(no output)\n")
          (insert output))
        (goto-char (point-min)))
      (special-mode))
    (display-buffer buf '((display-buffer-reuse-window
                           display-buffer-below-selected)
                          (window-height . 0.4)))))

;; --- Interactive commands ---

;;;###autoload
(defun sysml2-cli-lint ()
  "Run `sysml check' on the current file.
Displays syntax and structural validation results.
\(In CLI v0.5+, `lint' is an alias for `check'.)"
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "check" file)
     (format "Check: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-check ()
  "Run `sysml check' on the current file.
Comprehensive checks including lint and project integrity."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "check" file)
     (format "Check: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-list (&optional kind)
  "Run `sysml list' on the current file.
Optional KIND filters by element type (e.g. \"part-def\", \"port-def\")."
  (interactive
   (list (let ((choice (completing-read
                        "Filter by kind (empty for all): "
                        '("" "part-def" "port-def" "action-def"
                          "state-def" "constraint-def" "calc-def"
                          "requirement" "enum-def" "item-def"
                          "connection" "flow" "allocation"
                          "use-case-def" "verification-def"
                          "view-def" "viewpoint-def" "package")
                        nil nil)))
           (unless (string-empty-p choice) choice))))
  (let* ((file (sysml2-cli--ensure-file))
         (args (list "list" file)))
    (when kind
      (setq args (append args (list "--kind" kind))))
    (sysml2-cli--run
     args
     (format "List%s: %s"
             (if kind (format " (%s)" kind) "")
             (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-show (element)
  "Run `sysml show' for ELEMENT in the current file.
Shows detailed information about a model element."
  (interactive
   (list (read-string "Element name: "
                      (thing-at-point 'symbol t))))
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "show" file element)
     (format "Show: %s" element))))

;;;###autoload
(defun sysml2-cli-trace ()
  "Run `sysml trace' on the current file.
Shows requirements traceability matrix."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "trace" file)
     (format "Trace: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-stats ()
  "Run `sysml stats' on the current file.
Shows aggregate model statistics."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "stats" file)
     (format "Stats: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-deps (target)
  "Run `sysml deps' for TARGET in the current file.
Shows forward and reverse dependencies."
  (interactive
   (list (read-string "Target element: "
                      (thing-at-point 'symbol t))))
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "deps" file target)
     (format "Dependencies: %s" target))))

;;;###autoload
(defun sysml2-cli-coverage ()
  "Run `sysml coverage' on the current file.
Shows model completeness and quality score."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "coverage" file)
     (format "Coverage: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-find (pattern)
  "Run `sysml find' to search elements matching PATTERN.
Searches across all project files by name or regex."
  (interactive "sSearch pattern: ")
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "find" file "--pattern" pattern)
     (format "Find: %s" pattern))))

;;;###autoload
(defun sysml2-cli-doc ()
  "Run `sysml doc' on the current file.
Generates Markdown documentation from the model."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "doc" file)
     (format "Doc: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-analyze ()
  "Run `sysml analyze list' on the current file.
Lists analysis cases defined in the model."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (list "analyze" "list" file)
     (format "Analyze: %s" (file-name-nondirectory file)))))

(provide 'sysml2-cli-commands)
;;; sysml2-cli-commands.el ends here
