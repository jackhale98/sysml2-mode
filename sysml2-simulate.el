;;; sysml2-simulate.el --- SysML v2 simulation via sysml2-cli -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Interactive simulation support for SysML v2 models using the
;; sysml2-cli simulation engine.  Provides commands for:
;;
;;   - Listing simulatable constructs in the current buffer
;;   - Evaluating constraints and calculations with variable bindings
;;   - Simulating state machines with event injection
;;   - Executing action flows
;;
;; All prompts offer completion candidates extracted from the model:
;; trigger signals for state machines, parameter names for constraints
;; and calculations, etc.
;;
;; All commands work on the current buffer's file and display results
;; in a dedicated *SysML Simulation* buffer.
;;
;; Requires `sysml2-cli' (v0.2.0+) on exec-path.

;;; Code:

(require 'cl-lib)
(require 'sysml2-vars)

;;; Public API:
;;
;; Functions:
;;   `sysml2-simulate-list'   -- List simulatable constructs
;;   `sysml2-simulate-eval'   -- Evaluate constraint/calculation
;;   `sysml2-simulate-state-machine' -- Simulate a state machine
;;   `sysml2-simulate-action-flow'   -- Execute an action flow
;;   `sysml2-simulate'        -- Dispatch to simulation command

(defcustom sysml2-simulate-executable "sysml2-cli"
  "Path to the sysml2-cli executable."
  :type 'string
  :group 'sysml2)

(defcustom sysml2-simulate-max-steps 100
  "Default maximum simulation steps."
  :type 'integer
  :group 'sysml2)

(defvar sysml2-simulate-output-buffer "*SysML Simulation*"
  "Name of the simulation output buffer.")

(defvar sysml2-simulate-history nil
  "History list for simulation variable bindings.")

(defvar sysml2-simulate-event-history nil
  "History list for state machine events.")

;; --- Internal helpers ---

(defun sysml2-simulate--check-executable ()
  "Check that sysml2-cli is available.  Signal an error if not found."
  (unless (or (executable-find sysml2-simulate-executable)
              (cl-find-if #'file-executable-p
                          (list (expand-file-name
                                 (concat "~/.cargo/bin/" sysml2-simulate-executable))
                                (expand-file-name
                                 (concat "~/.local/bin/" sysml2-simulate-executable)))))
    (user-error "Cannot find `%s' on exec-path.  Install from https://github.com/jackhale98/sysml2-cli"
                sysml2-simulate-executable)))

(defun sysml2-simulate--resolve-executable ()
  "Return the full path to sysml2-cli."
  (or (executable-find sysml2-simulate-executable)
      (cl-find-if #'file-executable-p
                  (list (expand-file-name
                         (concat "~/.cargo/bin/" sysml2-simulate-executable))
                        (expand-file-name
                         (concat "~/.local/bin/" sysml2-simulate-executable))))
      sysml2-simulate-executable))

(defun sysml2-simulate--ensure-file ()
  "Return the current buffer's file name.  Signal error if unsaved."
  (or buffer-file-name
      (user-error "Buffer is not visiting a file.  Save first")))

(defun sysml2-simulate--run (args &optional json-p)
  "Run sysml2-cli simulate with ARGS and return combined output.
When JSON-P is non-nil, pass -f json.
Captures both stdout and stderr for complete diagnostics."
  (sysml2-simulate--check-executable)
  (let* ((exe (sysml2-simulate--resolve-executable))
         (full-args (append (when json-p '("-f" "json"))
                            '("simulate") args))
         (stderr-file (make-temp-file "sysml2-sim-stderr"))
         (stdout (with-output-to-string
                   (with-current-buffer standard-output
                     (apply #'call-process exe nil
                            (list t stderr-file) nil
                            full-args))))
         (stderr (with-temp-buffer
                   (insert-file-contents stderr-file)
                   (prog1 (buffer-string)
                     (ignore-errors (delete-file stderr-file))))))
    ;; Combine stdout + stderr for display
    (if (string-empty-p stderr)
        stdout
      (concat stdout
              (unless (string-empty-p stdout) "\n")
              stderr))))

(defun sysml2-simulate--display (title output)
  "Display simulation OUTPUT in the results buffer with TITLE."
  (let ((buf (get-buffer-create sysml2-simulate-output-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (concat "=== " title " ===\n\n")
                            'face 'bold))
        (if (string-empty-p (string-trim output))
            (insert (propertize "No output from sysml2-cli.\n" 'face 'warning)
                    "\nPossible causes:\n"
                    "  - The definition may be a forward declaration (no body)\n"
                    "  - The construct name may not match any definition\n"
                    "  - sysml2-cli may have crashed (check *Messages*)\n")
          (insert output)
          ;; Add diagnostic hints for common issues
          (goto-char (point-min))
          (cond
           ;; State machine: 0 steps with no events
           ((and (string-match-p "0 steps" output)
                 (string-match-p "State Machine" title))
            (goto-char (point-max))
            (insert (propertize "\n\nHint: " 'face 'bold))
            (cond
             ((string-match-p "Initial state: *$" output)
              (insert "No states found — this definition may be a forward "
                      "declaration (semicolon-only, no body with states)."))
             (t
              (insert "0 steps with a valid initial state usually means no "
                      "events were provided or guard conditions blocked all "
                      "transitions."))))
           ;; Action flow: 0 steps
           ((and (string-match-p "0 steps" output)
                 (string-match-p "Action Flow" title))
            (goto-char (point-max))
            (insert (propertize "\n\nHint: " 'face 'bold)
                    "0 steps usually means the action definition has no "
                    "sub-actions or successions (first/then). It may only "
                    "contain port declarations (in/out items) or be a "
                    "forward declaration."))))
        (goto-char (point-min)))
      (special-mode))
    (display-buffer buf '((display-buffer-reuse-window
                           display-buffer-below-selected)
                          (window-height . 0.4)))))

;; --- Structured data extraction ---

(defun sysml2-simulate--get-constructs-json (file)
  "Get simulatable constructs from FILE as parsed JSON.
Returns the parsed JSON alist with full details (triggers, params, etc.)."
  (let ((output (sysml2-simulate--run (list "list" file) t)))
    (condition-case nil
        (json-parse-string output :object-type 'alist :array-type 'list)
      (error nil))))

(defun sysml2-simulate--machine-names (data)
  "Extract state machine names from parsed JSON DATA."
  (mapcar (lambda (m) (alist-get 'name m))
          (alist-get 'state_machines data)))

(defun sysml2-simulate--machine-triggers (data machine-name)
  "Extract trigger signal names for MACHINE-NAME from DATA."
  (let ((machine (cl-find-if (lambda (m) (equal (alist-get 'name m) machine-name))
                             (alist-get 'state_machines data))))
    (when machine
      (alist-get 'triggers machine))))

(defun sysml2-simulate--machine-states (data machine-name)
  "Extract state names for MACHINE-NAME from DATA."
  (let ((machine (cl-find-if (lambda (m) (equal (alist-get 'name m) machine-name))
                             (alist-get 'state_machines data))))
    (when machine
      (alist-get 'states machine))))

(defun sysml2-simulate--constraint-names (data)
  "Extract constraint names from parsed JSON DATA."
  (mapcar (lambda (c) (alist-get 'name c))
          (alist-get 'constraints data)))

(defun sysml2-simulate--calc-names (data)
  "Extract calculation names from parsed JSON DATA."
  (mapcar (lambda (c) (alist-get 'name c))
          (alist-get 'calculations data)))

(defun sysml2-simulate--construct-params (data kind name)
  "Extract parameter names for construct NAME of KIND from DATA.
KIND is `constraints' or `calculations'."
  (let ((construct (cl-find-if (lambda (c) (equal (alist-get 'name c) name))
                               (alist-get kind data))))
    (when construct
      (mapcar (lambda (p) (alist-get 'name p))
              (alist-get 'params construct)))))

(defun sysml2-simulate--action-names (data)
  "Extract action names from parsed JSON DATA."
  (mapcar (lambda (a) (alist-get 'name a))
          (alist-get 'actions data)))

;; --- Completing-read helpers ---

(defun sysml2-simulate--read-events (triggers)
  "Prompt for events with TRIGGERS as completion candidates.
Returns a comma-separated string of selected events."
  (if (null triggers)
      (read-string "Events (comma-separated, empty for none): "
                   nil 'sysml2-simulate-event-history)
    (let ((selected nil)
          (available (copy-sequence triggers))
          (done nil))
      (while (not done)
        (let* ((prompt (if selected
                           (format "Events so far: [%s]. Add event (empty to finish): "
                                   (string-join (reverse selected) ","))
                         "Select event (empty to finish): "))
               (choice (completing-read prompt available nil nil nil
                                        'sysml2-simulate-event-history)))
          (if (string-empty-p choice)
              (setq done t)
            (push choice selected))))
      (string-join (nreverse selected) ","))))

(defun sysml2-simulate--read-bindings (params)
  "Prompt for variable bindings with PARAMS as guidance.
Shows each parameter name and prompts for a value.
Returns a comma-separated string of name=value pairs."
  (if (null params)
      (read-string "Variable bindings (name=val,..., empty for none): "
                   nil 'sysml2-simulate-history)
    (let ((bindings nil))
      (dolist (param params)
        (let ((val (read-string (format "  %s = " param) nil 'sysml2-simulate-history)))
          (unless (string-empty-p val)
            (push (format "%s=%s" param val) bindings))))
      (string-join (nreverse bindings) ","))))

;; --- Interactive commands ---

;;;###autoload
(defun sysml2-simulate-list ()
  "List all simulatable constructs in the current file."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (output (sysml2-simulate--run (list "list" file))))
    (sysml2-simulate--display
     (format "Simulatable Constructs: %s" (file-name-nondirectory file))
     output)))

;;;###autoload
(defun sysml2-simulate-eval ()
  "Evaluate a constraint or calculation from the current file.
Prompts for the construct name (with completion) and variable
bindings (with parameter name suggestions)."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (data (sysml2-simulate--get-constructs-json file))
         (all-names (append (sysml2-simulate--constraint-names data)
                            (sysml2-simulate--calc-names data)))
         (name (if all-names
                   (completing-read "Constraint/Calc: " all-names nil t)
                 (read-string "Constraint/Calc name: ")))
         ;; Look up parameters for this construct
         (params (or (sysml2-simulate--construct-params data 'constraints name)
                     (sysml2-simulate--construct-params data 'calculations name)))
         (_ (when params
              (message "Parameters: %s" (string-join params ", "))))
         (bindings (sysml2-simulate--read-bindings params))
         (args (list "eval" file "-n" name)))
    (when (and bindings (not (string-empty-p bindings)))
      (setq args (append args (list "-b" bindings))))
    (let ((output (sysml2-simulate--run args)))
      (sysml2-simulate--display
       (format "Eval: %s" name) output))))

;;;###autoload
(defun sysml2-simulate-state-machine ()
  "Simulate a state machine from the current file.
Prompts for the machine name (with completion), events (with
trigger signal completion), and variable bindings."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (data (sysml2-simulate--get-constructs-json file))
         (machines (sysml2-simulate--machine-names data))
         (name (if machines
                   (completing-read "State machine: " machines nil t)
                 (read-string "State machine name: ")))
         ;; Show available triggers for this machine
         (triggers (sysml2-simulate--machine-triggers data name))
         (states (sysml2-simulate--machine-states data name))
         (_ (when states
              (message "States: %s | Triggers: %s"
                       (string-join states ", ")
                       (if triggers (string-join triggers ", ") "(none)"))))
         (events (sysml2-simulate--read-events triggers))
         (bindings (read-string "Variable bindings (name=val,..., empty for none): "
                                nil 'sysml2-simulate-history))
         (max-steps (read-number "Max steps: " sysml2-simulate-max-steps))
         (args (list "state-machine" file "-n" name
                     "-m" (number-to-string max-steps))))
    (when (and events (not (string-empty-p events)))
      (setq args (append args (list "-e" events))))
    (when (and bindings (not (string-empty-p bindings)))
      (setq args (append args (list "-b" bindings))))
    (let ((output (sysml2-simulate--run args)))
      (sysml2-simulate--display
       (format "State Machine: %s" name) output))))

;;;###autoload
(defun sysml2-simulate-action-flow ()
  "Execute an action flow from the current file.
Prompts for the action name (with completion) and variable bindings."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (data (sysml2-simulate--get-constructs-json file))
         (actions (sysml2-simulate--action-names data))
         (name (if actions
                   (completing-read "Action: " actions nil t)
                 (read-string "Action name: ")))
         (bindings (read-string "Variable bindings (name=val,..., empty for none): "
                                nil 'sysml2-simulate-history))
         (max-steps (read-number "Max steps: " 1000))
         (args (list "action-flow" file "-n" name
                     "-m" (number-to-string max-steps))))
    (when (and bindings (not (string-empty-p bindings)))
      (setq args (append args (list "-b" bindings))))
    (let ((output (sysml2-simulate--run args)))
      (sysml2-simulate--display
       (format "Action Flow: %s" name) output))))

;;;###autoload
(defun sysml2-simulate ()
  "Run a simulation on the current SysML v2 file.
Presents a menu of simulation types to choose from."
  (interactive)
  (let ((choice (completing-read
                 "Simulate: "
                 '("list"
                   "eval (constraint/calculation)"
                   "state-machine"
                   "action-flow")
                 nil t)))
    (pcase choice
      ("list" (sysml2-simulate-list))
      ("eval (constraint/calculation)" (sysml2-simulate-eval))
      ("state-machine" (sysml2-simulate-state-machine))
      ("action-flow" (sysml2-simulate-action-flow)))))

(provide 'sysml2-simulate)
;;; sysml2-simulate.el ends here
