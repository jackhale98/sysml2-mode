;;; sysml2-cli-commands.el --- SysML CLI analysis commands -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.5.0
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
(require 'sysml2-project)

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

(defun sysml2-cli--project-flags ()
  "Return a list of project-aware flags to forward to the sysml CLI.
Currently emits `-I PROJECT-ROOT' and `--stdlib-path LIBRARY-PATH'
when those are detected.  Empty list when both are unavailable."
  (let ((flags nil)
        (root (sysml2-project-root))
        (lib (sysml2-project-library-path)))
    (when root
      (setq flags (append flags (list "-I" root))))
    (when lib
      (setq flags (append flags (list "--stdlib-path" lib))))
    flags))

(defun sysml2-cli--with-project-flags (head &rest tail)
  "Compose CLI args: HEAD list followed by project flags, then TAIL list.
TAIL entries may themselves be lists; they are flattened."
  (append head
          (sysml2-cli--project-flags)
          (apply #'append (mapcar (lambda (x) (if (listp x) x (list x))) tail))))

(defun sysml2-cli--parse-json (output)
  "Parse the JSON envelope OUTPUT into an alist, or nil on failure.
The CLI may print a summary line on stderr after the JSON body —
trailing non-JSON content is tolerated; leading non-JSON is not."
  (when (and (stringp output) (not (string-empty-p output)))
    (condition-case _
        (with-temp-buffer
          (insert output)
          (goto-char (point-min))
          (json-parse-buffer :object-type 'alist :array-type 'list))
      (error nil))))

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
The CLI's `lint' command was removed in 0.7.0; this is `check'."
  (interactive)
  (sysml2-cli-check))

;;;###autoload
(defun sysml2-cli-check ()
  "Run `sysml check' on the current file.
Comprehensive checks including lint and project integrity."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "check" file))
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
         (extra (when kind (list "--kind" kind)))
         (args (sysml2-cli--with-project-flags (list "list" file) extra)))
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
     (sysml2-cli--with-project-flags (list "show" file element))
     (format "Show: %s" element))))

;;;###autoload
(defun sysml2-cli-trace ()
  "Run `sysml trace' on the current file.
Shows requirements traceability matrix."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "trace" file))
     (format "Trace: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-stats ()
  "Render the `ModelStats' view for the current file.
The CLI's `stats' command became a model-defined view (0.7.0); the
StandardViews library must be on the include path (projects created
with `sysml init' and a libraries/ directory have it automatically)."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "view" "ModelStats" file))
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
     (sysml2-cli--with-project-flags (list "deps" file target))
     (format "Dependencies: %s" target))))

;;;###autoload
(defun sysml2-cli-coverage ()
  "Run `sysml coverage' on the current file.
Shows model completeness and quality score."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "coverage" file))
     (format "Coverage: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-find (pattern)
  "Search elements whose name contains PATTERN via `sysml list -n'.
The CLI's `find' command folded into `list' (0.7.0); use
\[universal-argument] to search documentation text instead (--doc)."
  (interactive "sSearch pattern: ")
  (let ((file (sysml2-cli--ensure-file))
        (flag (if current-prefix-arg "--doc" "-n")))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "list" file)
                                     (list flag pattern))
     (format "Find: %s" pattern))))

;;;###autoload
(defun sysml2-cli-doc ()
  "Run `sysml doc' on the current file.
Generates Markdown documentation from the model."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "doc" file))
     (format "Doc: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-analyze ()
  "Run `sysml analyze list' on the current file.
Lists analysis cases defined in the model."
  (interactive)
  (let ((file (sysml2-cli--ensure-file)))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "analyze" "list" file))
     (format "Analyze: %s" (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-view (&optional view-name)
  "Render the model-defined view VIEW-NAME via `sysml view'.
Views are `view def's carrying a @TableRendering annotation (see the
Reporting domain library) — FmeaWorksheet, RiskMatrix, StackupSummary,
PortTable, and any view your project defines.  Called with no name
\(or interactively with empty input), lists the available views."
  (interactive
   (list (read-string "View name (empty to list): ")))
  (let* ((file (sysml2-cli--ensure-file))
         (args (if (and view-name (not (string-empty-p view-name)))
                   (list "view" view-name file)
                 (list "view" file))))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags args)
     (if (and view-name (not (string-empty-p view-name)))
         (format "View: %s" view-name)
       "Views"))))

;;;###autoload
(defun sysml2-cli-analyze-run (case-name &optional method)
  "Run analysis CASE-NAME via `sysml analyze run -n CASE-NAME'.
Uncertainty analysis cases (types specializing
Uncertainty::UncertaintyAnalysis, e.g. tolerance stackups) run
worst-case, RSS, and Monte Carlo propagation.  With a prefix arg,
prompt for METHOD (worst-case, rss, monte-carlo, or all)."
  (interactive
   (list (read-string "Analysis case name: "
                      (thing-at-point 'symbol t))
         (when current-prefix-arg
           (completing-read "Method: "
                            '("all" "worst-case" "rss" "monte-carlo")
                            nil t "all"))))
  (let* ((file (sysml2-cli--ensure-file))
         (extra (append (list "-n" case-name)
                        (when (and method (not (equal method "all")))
                          (list "--method" method)))))
    (sysml2-cli--run
     (sysml2-cli--with-project-flags (list "analyze" "run" file) extra)
     (format "Analyze: %s" case-name))))

;; --- Newly wired commands ------------------------------------------

(defconst sysml2-cli--rollup-subcommands
  '("compute" "budget" "sensitivity" "sweep" "what-if")
  "Known `sysml rollup' subcommands.
\(`query' was removed in CLI 0.7.0 — use `sysml list -k attributes'.)")

;;;###autoload
(defun sysml2-cli-rollup (subcommand root attr)
  "Run `sysml rollup SUBCOMMAND' on the current file.

SUBCOMMAND defaults to \"compute\" — also: budget, sensitivity,
sweep, what-if, query.  ROOT names the root part definition.
ATTR is the attribute to roll up (mass, cost, power, …).

Interactively prompts for each argument."
  (interactive
   (let ((sub (completing-read
               "Rollup subcommand: "
               sysml2-cli--rollup-subcommands nil t
               "compute")))
     (list sub
           (read-string "Root part def: " (thing-at-point 'symbol t))
           (read-string "Attribute (e.g. mass, cost): " "mass"))))
  (let* ((file (sysml2-cli--ensure-file))
         (args (sysml2-cli--with-project-flags
                (list "rollup" subcommand file)
                (list "--root" root "--attr" attr))))
    (sysml2-cli--run
     args
     (format "Rollup %s: %s.%s" subcommand root attr))))

;;;###autoload
(defun sysml2-cli-interfaces (&optional unconnected-only)
  "Render the `PortTable' view for the current file.
The CLI's `interfaces' command became a model-defined view (0.7.0).
Unconnected ports are reported by `sysml check' as W016, so
UNCONNECTED-ONLY (prefix arg) runs check instead."
  (interactive "P")
  (let* ((file (sysml2-cli--ensure-file))
         (extra nil)
         (args (sysml2-cli--with-project-flags
                (if unconnected-only
                    (list "check" file)
                  (list "view" "PortTable" file)) extra)))
    (sysml2-cli--run
     args
     (format "Interfaces%s: %s"
             (if unconnected-only " (unconnected)" "")
             (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-allocation (&optional unallocated-only)
  "Run `sysml allocation' on the current file.
With prefix arg or UNALLOCATED-ONLY non-nil, pass `--unallocated'."
  (interactive "P")
  (let* ((file (sysml2-cli--ensure-file))
         (extra (when unallocated-only (list "--unallocated")))
         (args (sysml2-cli--with-project-flags
                (list "allocation" file) extra)))
    (sysml2-cli--run
     args
     (format "Allocation%s: %s"
             (if unallocated-only " (unallocated)" "")
             (file-name-nondirectory file)))))

;;;###autoload
(defun sysml2-cli-diff (file-a file-b)
  "Run `sysml diff FILE-A FILE-B' for a semantic comparison.
Interactively prompts for both files (default for FILE-A is the
current buffer)."
  (interactive
   (let* ((default-a (or buffer-file-name default-directory))
          (a (read-file-name "Old file: " nil default-a t))
          (b (read-file-name "New file: " nil nil t)))
     (list a b)))
  (let ((args (sysml2-cli--with-project-flags (list "diff" file-a file-b))))
    (sysml2-cli--run
     args
     (format "Diff: %s vs %s"
             (file-name-nondirectory file-a)
             (file-name-nondirectory file-b)))))

;; --- CLI-backed refactoring (preview → confirm → apply) -----------

(defun sysml2-cli--refactor-buffer (title)
  "Return a fresh refactor preview buffer with TITLE."
  (let ((buf (get-buffer-create "*SysML Refactor Preview*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (concat "=== " title " ===\n\n") 'face 'bold)))
      (diff-mode))
    buf))

(defun sysml2-cli--show-refactor-preview (title parsed)
  "Display the `diff' field of PARSED (an envelope alist) under TITLE.
For project-wide envelopes (with a `files' array), concatenate each
file's diff section.  Returns the buffer."
  (let* ((buf (sysml2-cli--refactor-buffer title))
         (files (alist-get 'files parsed))
         (top-diff (alist-get 'diff parsed)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (cond
         (top-diff (insert top-diff))
         (files
          (dolist (entry files)
            (insert (format "## %s (%d edit%s)\n"
                            (alist-get 'file entry)
                            (alist-get 'edits entry 0)
                            (if (= 1 (alist-get 'edits entry 0)) "" "s")))
            (when-let ((d (alist-get 'diff entry)))
              (insert d))
            (insert "\n")))
         (t (insert "(no diff returned)\n"))))
      (goto-char (point-min)))
    (display-buffer buf '((display-buffer-reuse-window
                           display-buffer-below-selected)
                          (window-height . 0.4)))
    buf))

(defun sysml2-cli--reload-changed-buffer (file)
  "Reload FILE in any buffer visiting it (after on-disk modification)."
  (when (and file (file-exists-p file))
    (when-let ((buf (find-buffer-visiting file)))
      (with-current-buffer buf
        (revert-buffer t t t)))))

(defun sysml2-cli-rename--confirm (parsed)
  "Ask the user to confirm the rename described by PARSED.  Return t/nil."
  (yes-or-no-p
   (format "Apply rename `%s' -> `%s' (%d edit%s)? "
           (alist-get 'from parsed)
           (alist-get 'to parsed)
           (alist-get 'edits parsed 0)
           (if (= 1 (alist-get 'edits parsed 0)) "" "s"))))

;;;###autoload
(defun sysml2-cli-rename (old-name new-name &optional project-wide)
  "Rename OLD-NAME to NEW-NAME via `sysml rename'.
With prefix arg or PROJECT-WIDE non-nil, rename across the entire
project (passes `--project').  Always performs a dry-run preview
first, then prompts for confirmation before applying."
  (interactive
   (list (read-string "Rename: " (thing-at-point 'symbol t))
         (read-string "To: ")
         current-prefix-arg))
  (let* ((file (sysml2-cli--ensure-file))
         (extra (append (list "--dry-run" "-f" "json")
                        (when project-wide (list "--project"))))
         (preview-args (sysml2-cli--with-project-flags
                        (list "rename" file old-name new-name)
                        extra))
         (preview-output (sysml2-cli--run preview-args nil))
         (parsed (sysml2-cli--parse-json preview-output)))
    (cond
     ((null parsed)
      (message "sysml rename: no JSON output — check `*SysML CLI*' buffer for errors")
      (sysml2-cli--display
       (format "Rename %s -> %s (preview failed)" old-name new-name)
       preview-output))
     ((sysml2-cli-rename--confirm parsed)
      (let* ((apply-args (sysml2-cli--with-project-flags
                          (list "rename" file old-name new-name)
                          (append (list "-f" "json")
                                  (when project-wide (list "--project")))))
             (apply-output (sysml2-cli--run apply-args nil))
             (apply-parsed (sysml2-cli--parse-json apply-output)))
        ;; Reload any open buffers visiting changed files.
        (if-let ((files (alist-get 'files apply-parsed)))
            (dolist (f files)
              (sysml2-cli--reload-changed-buffer (alist-get 'file f)))
          (sysml2-cli--reload-changed-buffer file))
        (message "Renamed `%s' → `%s' (%d edit%s)"
                 old-name new-name
                 (alist-get 'edits (or apply-parsed parsed) 0)
                 (if (= 1 (alist-get 'edits (or apply-parsed parsed) 0)) "" "s"))))
     (t
      (sysml2-cli--show-refactor-preview
       (format "Rename %s -> %s (cancelled)" old-name new-name)
       parsed)
      (message "Rename cancelled")))))

(defun sysml2-cli-add--confirm (parsed)
  "Ask the user to confirm the add described by PARSED.  Return t/nil."
  (let* ((element (alist-get 'element parsed))
         (name (and element (alist-get 'name element)))
         (kind (and element (alist-get 'kind element))))
    (yes-or-no-p
     (format "Insert `%s %s' into %s? "
             (or kind "?") (or name "?")
             (alist-get 'file parsed)))))

;;;###autoload
(defun sysml2-cli-add (kind name)
  "Insert a new SysML element of KIND named NAME via `sysml add'.
KIND is a CLI-recognised template name such as `part-def', `port-def',
`requirement-def', `state-def', etc.  Performs a dry-run preview first,
then prompts for confirmation."
  (interactive
   (let* ((kind-choice (completing-read
                        "Element kind: "
                        '("part-def" "port-def" "action-def" "state-def"
                          "requirement-def" "constraint-def" "calc-def"
                          "enum-def" "item-def" "use-case-def"
                          "interface-def" "verification-case-def"
                          "analysis-case-def" "allocation-def"
                          "package" "import")
                        nil nil))
          (name (read-string (format "Name for %s: " kind-choice))))
     (list kind-choice name)))
  (let* ((file (sysml2-cli--ensure-file))
         (preview-args (sysml2-cli--with-project-flags
                        (list "add" file kind name)
                        (list "--dry-run" "-f" "json")))
         (preview-output (sysml2-cli--run preview-args nil))
         (parsed (sysml2-cli--parse-json preview-output)))
    (cond
     ((null parsed)
      (sysml2-cli--display
       (format "Add %s %s (preview failed)" kind name)
       preview-output))
     ((sysml2-cli-add--confirm parsed)
      (let ((apply-args (sysml2-cli--with-project-flags
                         (list "add" file kind name)
                         (list "-f" "json"))))
        (sysml2-cli--run apply-args nil)
        (sysml2-cli--reload-changed-buffer file)
        (message "Added `%s %s' to %s" kind name
                 (file-name-nondirectory file))))
     (t
      (sysml2-cli--show-refactor-preview
       (format "Add %s %s (cancelled)" kind name)
       parsed)
      (message "Add cancelled")))))

(defun sysml2-cli-remove--confirm (parsed)
  "Ask the user to confirm the removal described by PARSED.  Return t/nil."
  (yes-or-no-p
   (format "Remove `%s' from %s (%d byte%s deleted)? "
           (alist-get 'removed parsed)
           (alist-get 'file parsed)
           (alist-get 'bytes_removed parsed 0)
           (if (= 1 (alist-get 'bytes_removed parsed 0)) "" "s"))))

;;;###autoload
(defun sysml2-cli-remove (name)
  "Remove the SysML element NAME via `sysml remove'.
Performs a dry-run preview first, then prompts for confirmation."
  (interactive
   (list (read-string "Remove element: " (thing-at-point 'symbol t))))
  (let* ((file (sysml2-cli--ensure-file))
         (preview-args (sysml2-cli--with-project-flags
                        (list "remove" file name)
                        (list "--dry-run" "-f" "json")))
         (preview-output (sysml2-cli--run preview-args nil))
         (parsed (sysml2-cli--parse-json preview-output)))
    (cond
     ((null parsed)
      (sysml2-cli--display
       (format "Remove %s (preview failed)" name)
       preview-output))
     ((sysml2-cli-remove--confirm parsed)
      (let ((apply-args (sysml2-cli--with-project-flags
                         (list "remove" file name)
                         (list "-f" "json"))))
        (sysml2-cli--run apply-args nil)
        (sysml2-cli--reload-changed-buffer file)
        (message "Removed `%s' from %s" name
                 (file-name-nondirectory file))))
     (t
      (sysml2-cli--show-refactor-preview
       (format "Remove %s (cancelled)" name)
       parsed)
      (message "Remove cancelled")))))


(provide 'sysml2-cli-commands)
;;; sysml2-cli-commands.el ends here
