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
;; All commands work on the current buffer's file and display results
;; in a dedicated *SysML Simulation* buffer.
;;
;; Requires `sysml2-cli' (v0.2.0+) on exec-path.

;;; Code:

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
  (unless (executable-find sysml2-simulate-executable)
    (user-error "Cannot find `%s' on exec-path.  Install sysml2-cli from https://github.com/jackhale98/sysml-lint"
                sysml2-simulate-executable)))

(defun sysml2-simulate--ensure-file ()
  "Return the current buffer's file name.  Signal error if unsaved."
  (or buffer-file-name
      (user-error "Buffer is not visiting a file.  Save first")))

(defun sysml2-simulate--run (args &optional json-p)
  "Run sysml2-cli simulate with ARGS and display results.
When JSON-P is non-nil, pass -f json and parse the output."
  (sysml2-simulate--check-executable)
  (let* ((full-args (append (when json-p '("-f" "json"))
                            '("simulate") args))
         (output (with-output-to-string
                   (with-current-buffer standard-output
                     (apply #'call-process
                            sysml2-simulate-executable nil t nil
                            full-args)))))
    output))

(defun sysml2-simulate--display (title output)
  "Display simulation OUTPUT in the results buffer with TITLE."
  (let ((buf (get-buffer-create sysml2-simulate-output-buffer)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize (concat "=== " title " ===\n\n")
                            'face 'bold))
        (insert output)
        (goto-char (point-min)))
      (special-mode))
    (display-buffer buf '((display-buffer-reuse-window
                           display-buffer-below-selected)
                          (window-height . 0.4)))))

(defun sysml2-simulate--get-constructs (file)
  "Get simulatable constructs from FILE as parsed JSON."
  (let* ((output (sysml2-simulate--run
                  (list "list" file)))
         (lines (split-string output "\n" t)))
    ;; Parse the text output into sections
    (let ((constraints nil)
          (calcs nil)
          (machines nil)
          (actions nil)
          (section nil))
      (dolist (line lines)
        (cond
         ((string-match "^Constraints:" line) (setq section 'constraints))
         ((string-match "^Calculations:" line) (setq section 'calcs))
         ((string-match "^State Machines:" line) (setq section 'machines))
         ((string-match "^Actions:" line) (setq section 'actions))
         ((string-match "^$" line) nil)
         ((string-match "^  \\([A-Za-z_][A-Za-z0-9_]*\\)" line)
          (let ((name (match-string 1 line)))
            (pcase section
              ('constraints (push name constraints))
              ('calcs (push name calcs))
              ('machines (push name machines))
              ('actions (push name actions)))))))
      (list :constraints (nreverse constraints)
            :calcs (nreverse calcs)
            :machines (nreverse machines)
            :actions (nreverse actions)))))

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
Prompts for the construct name and variable bindings."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (constructs (sysml2-simulate--get-constructs file))
         (all-names (append (plist-get constructs :constraints)
                            (plist-get constructs :calcs)))
         (name (if all-names
                   (completing-read "Constraint/Calc: " all-names nil t)
                 (read-string "Constraint/Calc name: ")))
         (bindings (read-string "Variable bindings (name=val,...): "
                                nil 'sysml2-simulate-history))
         (args (list "eval" file "-n" name)))
    (when (and bindings (not (string-empty-p bindings)))
      (setq args (append args (list "-b" bindings))))
    (let ((output (sysml2-simulate--run args)))
      (sysml2-simulate--display
       (format "Eval: %s" name) output))))

;;;###autoload
(defun sysml2-simulate-state-machine ()
  "Simulate a state machine from the current file.
Prompts for the machine name, events, and variable bindings."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (constructs (sysml2-simulate--get-constructs file))
         (machines (plist-get constructs :machines))
         (name (if machines
                   (completing-read "State machine: " machines nil t)
                 (read-string "State machine name: ")))
         (events (read-string "Events (comma-separated, empty for none): "
                              nil 'sysml2-simulate-event-history))
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
Prompts for the action name and variable bindings."
  (interactive)
  (let* ((file (sysml2-simulate--ensure-file))
         (constructs (sysml2-simulate--get-constructs file))
         (actions (plist-get constructs :actions))
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
