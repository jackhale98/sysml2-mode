;;; sysml2-diagram.el --- Diagram commands for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; User-facing diagram commands and preview management.
;;
;; Dual-backend architecture:
;;   - `native' backend (default): Direct SVG for deterministic layouts
;;     (tree/BDD, requirements) + D2 for graph layouts (IBD, state
;;     machine, action flow, use case, package)
;;   - `plantuml' backend (legacy): PlantUML for all diagram types
;;
;; Backend selection is controlled by `sysml2-diagram-backend'.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-diagram-preview' -- Preview diagram at point (auto-detect type)
;;   `sysml2-diagram-preview-buffer' -- Preview tree diagram for buffer
;;   `sysml2-diagram-tree' -- Preview parts tree diagram
;;   `sysml2-diagram-ibd' -- Preview internal block diagram
;;   `sysml2-diagram-state-machine' -- Preview state machine diagram
;;   `sysml2-diagram-action-flow' -- Preview action flow diagram
;;   `sysml2-diagram-requirement' -- Preview requirement tree diagram
;;   `sysml2-diagram-use-case' -- Preview use case diagram
;;   `sysml2-diagram-package' -- Preview package diagram
;;   `sysml2-diagram-export' -- Export diagram to file
;;   `sysml2-diagram-type' -- Select diagram type via completing-read
;;   `sysml2-diagram-open-source' -- Open diagram source buffer
;;   `sysml2-diagram-preview-mode' -- Minor mode for auto-refresh
;;   `sysml2-diagram-view' -- Generate diagram from a view def's filter

(require 'cl-lib)
(require 'sysml2-vars)
(require 'sysml2-lang)
(require 'sysml2-model)
(require 'sysml2-svg)
(require 'sysml2-d2)
(require 'sysml2-plantuml)

(defvar url-http-end-of-headers)
(defvar url-request-method)
(defvar url-request-data)
(defvar url-request-extra-headers)
(declare-function sysml2-mode "sysml2-mode")

;; --- PlantUML Resolution ---

(defun sysml2--diagram-resolve-plantuml ()
  "Return (:mode SYMBOL :command LIST) for invoking PlantUML, or nil.
Checks `sysml2-plantuml-exec-mode' and the corresponding path variables."
  (pcase sysml2-plantuml-exec-mode
    ('executable
     (let ((cmd (or sysml2-plantuml-executable-path
                    (executable-find "plantuml"))))
       (when cmd
         (list :mode 'executable :command (list cmd)))))
    ('jar
     (let ((jar (or sysml2-plantuml-jar-path
                    (and (boundp 'plantuml-jar-path)
                         (symbol-value 'plantuml-jar-path)))))
       (when (and jar (file-exists-p jar))
         (list :mode 'jar :command (list "java" "-jar" jar)))))
    ('server
     (when sysml2-plantuml-server-url
       (list :mode 'server :command (list sysml2-plantuml-server-url))))))

;; --- PlantUML Invocation ---

(defun sysml2--diagram-invoke-plantuml (puml-string format callback)
  "Invoke PlantUML on PUML-STRING for FORMAT, call CALLBACK with result.
CALLBACK receives (SUCCESS DATA-OR-ERROR) where SUCCESS is non-nil
on success and DATA-OR-ERROR is image data or an error string."
  (let ((resolved (sysml2--diagram-resolve-plantuml)))
    (unless resolved
      (funcall callback nil "PlantUML not found. Configure sysml2-plantuml-exec-mode.")
      (cl-return-from sysml2--diagram-invoke-plantuml nil))
    (pcase (plist-get resolved :mode)
      ('executable
       (sysml2--diagram-invoke-executable
        puml-string format callback (plist-get resolved :command)))
      ('jar
       (sysml2--diagram-invoke-jar
        puml-string format callback (plist-get resolved :command)))
      ('server
       (sysml2--diagram-invoke-server
        puml-string format callback (car (plist-get resolved :command)))))))

(defun sysml2--diagram-invoke-executable (puml-string format callback command)
  "Invoke PlantUML executable COMMAND on PUML-STRING for FORMAT.
CALLBACK receives (SUCCESS DATA-OR-ERROR)."
  (let ((temp-file (make-temp-file "sysml2-puml-" nil ".puml")))
    (with-temp-file temp-file
      (insert puml-string))
    (let* ((fmt-arg (concat "-t" format))
           (args (append command (list fmt-arg "-pipe")))
           (proc-buf (generate-new-buffer " *sysml2-plantuml*")))
      (set-process-sentinel
       (apply #'start-process "sysml2-plantuml" proc-buf
              (car args) (cdr args))
       (lambda (proc _event)
         (when (memq (process-status proc) '(exit signal))
           (let ((output (with-current-buffer (process-buffer proc)
                           (buffer-string))))
             (if (= (process-exit-status proc) 0)
                 (funcall callback t output)
               (funcall callback nil output)))
           (kill-buffer (process-buffer proc))
           (delete-file temp-file))))
      (process-send-string (get-buffer-process proc-buf) puml-string)
      (process-send-eof (get-buffer-process proc-buf)))))

(defun sysml2--diagram-invoke-jar (puml-string format callback command)
  "Invoke PlantUML jar COMMAND on PUML-STRING for FORMAT.
CALLBACK receives (SUCCESS DATA-OR-ERROR)."
  (let* ((proc-buf (generate-new-buffer " *sysml2-plantuml*"))
         (fmt-arg (concat "-t" format))
         (args (append command (list fmt-arg "-pipe"))))
    (set-process-sentinel
     (apply #'start-process "sysml2-plantuml" proc-buf
            (car args) (cdr args))
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (let ((output (with-current-buffer (process-buffer proc)
                         (buffer-string))))
           (if (= (process-exit-status proc) 0)
               (funcall callback t output)
             (funcall callback nil output)))
         (kill-buffer (process-buffer proc)))))
    (process-send-string (get-buffer-process proc-buf) puml-string)
    (process-send-eof (get-buffer-process proc-buf))))

(defun sysml2--diagram-invoke-server (puml-string format callback server-url)
  "POST PUML-STRING to SERVER-URL for FORMAT.
CALLBACK receives (SUCCESS DATA-OR-ERROR)."
  (require 'url)
  (let ((url-request-method "POST")
        (url-request-data puml-string)
        (url-request-extra-headers '(("Content-Type" . "text/plain")))
        (endpoint (concat (string-trim-right server-url "/")
                          "/" format "/")))
    (url-retrieve
     endpoint
     (lambda (status)
       (if (plist-get status :error)
           (funcall callback nil
                    (format "Server error: %s" (plist-get status :error)))
         (goto-char url-http-end-of-headers)
         (funcall callback t (buffer-substring (point) (point-max)))))
     nil t)))

;; --- D2 Invocation ---

(defun sysml2--diagram-resolve-d2 ()
  "Return the D2 executable path, or nil if not found."
  (or sysml2-d2-executable-path
      (executable-find "d2")))

(defun sysml2--diagram-invoke-d2 (d2-string format callback)
  "Invoke D2 on D2-STRING for FORMAT, call CALLBACK with result.
CALLBACK receives (SUCCESS DATA-OR-ERROR)."
  (let ((d2-cmd (sysml2--diagram-resolve-d2)))
    (unless d2-cmd
      (funcall callback nil "D2 not found. Install from https://d2lang.com or set `sysml2-d2-executable-path'.")
      (cl-return-from sysml2--diagram-invoke-d2 nil))
    (let* ((temp-in (make-temp-file "sysml2-d2-" nil ".d2"))
           (temp-out (make-temp-file "sysml2-d2-out-" nil (concat "." format)))
           (args (list d2-cmd))
           (proc-buf (generate-new-buffer " *sysml2-d2*")))
      (with-temp-file temp-in
        (insert d2-string))
      ;; Build args
      (when sysml2-d2-theme
        (setq args (append args (list "--theme" (number-to-string sysml2-d2-theme)))))
      (when sysml2-d2-layout-engine
        (setq args (append args (list "--layout" (symbol-name sysml2-d2-layout-engine)))))
      (setq args (append args (list temp-in temp-out)))
      (set-process-sentinel
       (apply #'start-process "sysml2-d2" proc-buf (car args) (cdr args))
       (lambda (proc _event)
         (when (memq (process-status proc) '(exit signal))
           (if (= (process-exit-status proc) 0)
               (let ((output (with-temp-buffer
                               (set-buffer-multibyte nil)
                               (insert-file-contents-literally temp-out)
                               (buffer-string))))
                 (funcall callback t output))
             (let ((err (with-current-buffer (process-buffer proc)
                          (buffer-string))))
               (funcall callback nil err)))
           (kill-buffer (process-buffer proc))
           (ignore-errors (delete-file temp-in))
           (ignore-errors (delete-file temp-out))))))))

(defun sysml2--diagram-invoke-d2-sync (d2-string format)
  "Synchronously invoke D2 on D2-STRING for FORMAT.
Returns image data as a string."
  (let ((d2-cmd (sysml2--diagram-resolve-d2)))
    (unless d2-cmd
      (user-error "D2 not found; install from https://d2lang.com or set `sysml2-d2-executable-path'"))
    (let* ((temp-in (make-temp-file "sysml2-d2-" nil ".d2"))
           (temp-out (make-temp-file "sysml2-d2-out-" nil (concat "." format)))
           (args (list)))
      (with-temp-file temp-in
        (insert d2-string))
      (when sysml2-d2-theme
        (setq args (append args (list "--theme" (number-to-string sysml2-d2-theme)))))
      (when sysml2-d2-layout-engine
        (setq args (append args (list "--layout" (symbol-name sysml2-d2-layout-engine)))))
      (setq args (append args (list temp-in temp-out)))
      (let ((exit-code (apply #'call-process d2-cmd nil nil nil args)))
        (unless (= exit-code 0)
          (user-error "D2 failed with exit code %d" exit-code))
        (prog1
            (with-temp-buffer
              (set-buffer-multibyte nil)
              (insert-file-contents-literally temp-out)
              (buffer-string))
          (ignore-errors (delete-file temp-in))
          (ignore-errors (delete-file temp-out)))))))

;; --- Unified Generation and Display ---

(defconst sysml2--diagram-svg-types '(tree requirement-tree)
  "Diagram types that have a direct SVG fallback backend.")

(defconst sysml2--diagram-d2-types
  '(tree requirement-tree interconnection state-machine action-flow use-case package)
  "Diagram types rendered by the D2 backend.")

(defun sysml2--diagram-generate-and-display (type scope)
  "Generate a diagram of TYPE with SCOPE and display it.
Uses the backend selected by `sysml2-diagram-backend'."
  (setq sysml2--diagram-source-buffer (current-buffer))
  (pcase sysml2-diagram-backend
    ('native
     (cond
      ((memq type sysml2--diagram-d2-types)
       ;; D2 — try local binary first, fall back to SVG or web playground
       (if (sysml2--diagram-resolve-d2)
           (let ((d2-src (sysml2-d2-generate type scope)))
             (sysml2--diagram-invoke-d2
              d2-src "svg"
              (lambda (success data)
                (if success
                    (sysml2--diagram-display-image data "svg")
                  (message "D2 error: %s" data)))))
         ;; No local D2 — fall back to SVG for types that support it
         (if (memq type sysml2--diagram-svg-types)
             (let ((svg-data (sysml2-svg-generate type scope)))
               (sysml2--diagram-display-image svg-data "svg"))
           ;; No SVG fallback — open in web playground
           (let* ((d2-src (sysml2-d2-generate type scope))
                  (encoded (sysml2--d2-playground-encode d2-src))
                  (url (concat "https://play.d2lang.com/?script=" encoded)))
             (browse-url url)
             (message "D2 not installed locally — opened in web playground")))))

      (t (error "Unknown diagram type: %s" type))))
    ('plantuml
     (let ((puml (sysml2-plantuml-generate type scope)))
       (sysml2--diagram-invoke-plantuml
        puml sysml2-diagram-output-format
        (lambda (success data)
          (if success
              (sysml2--diagram-display-image data sysml2-diagram-output-format)
            (message "PlantUML error: %s" data))))))
    (_ (error "Unknown diagram backend: %s" sysml2-diagram-backend))))

;; --- Preview Management ---

(defun sysml2--diagram-get-preview-buffer ()
  "Get or create the diagram preview buffer."
  (let ((buf (get-buffer-create "*SysML2 Diagram*")))
    (setq sysml2--diagram-preview-buffer buf)
    buf))

(defun sysml2--diagram-display-image (image-data format)
  "Display IMAGE-DATA as FORMAT in the preview buffer."
  (let ((buf (sysml2--diagram-get-preview-buffer))
        (img-type (pcase format
                    ("svg" 'svg)
                    ("png" 'png)
                    (_ 'png))))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (if (display-graphic-p)
            (insert-image (create-image image-data img-type t))
          (insert image-data))
        (goto-char (point-min))))
    (sysml2--diagram-show-preview-window)))

(defun sysml2--diagram-show-preview-window ()
  "Display the preview buffer according to `sysml2-diagram-preview-window'."
  (let ((buf (sysml2--diagram-get-preview-buffer)))
    (pcase sysml2-diagram-preview-window
      ('split-right
       (display-buffer buf '(display-buffer-in-side-window
                             (side . right)
                             (window-width . 0.4))))
      ('split-below
       (display-buffer buf '(display-buffer-in-side-window
                             (side . bottom)
                             (window-height . 0.4))))
      ('other-frame
       (display-buffer buf '(display-buffer-pop-up-frame)))
      (_
       (display-buffer buf)))))

;; --- Interactive Commands ---

(defun sysml2-diagram-preview ()
  "Preview diagram for the definition at point.
Auto-detects the diagram type.  Bound to `C-c C-d p'."
  (interactive)
  (let* ((detected (sysml2--model-detect-diagram-type-at-point))
         (dtype (car detected))
         (scope (cdr detected)))
    (sysml2--diagram-generate-and-display dtype scope)))

(defun sysml2-diagram-preview-buffer ()
  "Preview a tree diagram for the entire buffer.
Bound to `C-c C-d b'."
  (interactive)
  (sysml2--diagram-generate-and-display 'tree nil))

;; --- Direct Diagram Commands ---

(declare-function sysml2-which-function "sysml2-navigation")

(defun sysml2--diagram-scan-defs (def-keyword &optional require-body)
  "Return a list of definition names matching DEF-KEYWORD in the buffer.
DEF-KEYWORD is e.g. \"part def\", \"state def\".
When REQUIRE-BODY is non-nil, skip forward declarations (semicolons
without a `{' body)."
  (let ((names nil)
        (re (concat "\\b" (regexp-quote def-keyword)
                    "[ \t]+\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward re nil t)
        (unless (let ((ppss (syntax-ppss)))
                  (or (nth 3 ppss) (nth 4 ppss)))
          (let ((name (match-string-no-properties 1)))
            (if require-body
                ;; Check that this def has a body (not just semicolon)
                (save-excursion
                  (when (re-search-forward "[{;]" (line-end-position 3) t)
                    (when (eq (char-before) ?\{)
                      (push name names))))
              (push name names))))))
    (nreverse names)))

(defun sysml2--diagram-scan-exhibit-states ()
  "Return a list of exhibit state names in the buffer."
  (let ((names nil)
        (re (concat "\\bexhibit[ \t]+state[ \t]+"
                    "\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward re nil t)
        (unless (let ((ppss (syntax-ppss)))
                  (or (nth 3 ppss) (nth 4 ppss)))
          (push (match-string-no-properties 1) names))))
    (nreverse names)))

(defun sysml2--diagram-read-scope (diagram-type)
  "Return a scope name for DIAGRAM-TYPE.
Always shows all matching candidates via `completing-read', with
the enclosing definition at point as the default selection."
  (let* ((def-kw (pcase diagram-type
                   ("IBD" "part def")
                   ("State machine" "state def")
                   ("Action flow" "action def")
                   (_ nil)))
         ;; For state machines, require body (skip forward declarations)
         (require-body (string= diagram-type "State machine"))
         (candidates (when def-kw
                       (sysml2--diagram-scan-defs def-kw require-body)))
         ;; For state machines, also include exhibit state names
         (candidates (if (string= diagram-type "State machine")
                         (delete-dups (append candidates
                                             (sysml2--diagram-scan-exhibit-states)))
                       candidates))
         ;; Use at-point definition as default, not auto-select
         (default (sysml2-which-function))
         (name (if candidates
                   (completing-read
                    (format "%s — select %s: " diagram-type
                            (or def-kw "definition"))
                    candidates nil t nil nil default)
                 (read-string
                  (format "%s — scope (definition name): " diagram-type)
                  nil nil default))))
    (if (string-empty-p name) nil name)))

(defun sysml2--diagram-generate-and-show (type scope)
  "Generate a diagram of TYPE with SCOPE and display it."
  (sysml2--diagram-generate-and-display type scope))

(defun sysml2-diagram-tree ()
  "Preview a parts tree diagram for the current buffer."
  (interactive)
  (sysml2--diagram-generate-and-show 'tree nil))

(defun sysml2-diagram-ibd ()
  "Preview an internal block diagram (interconnection).
Auto-detects scope from enclosing definition, or prompts."
  (interactive)
  (sysml2--diagram-generate-and-show
   'interconnection (sysml2--diagram-read-scope "IBD")))

(defun sysml2-diagram-state-machine ()
  "Preview a state machine diagram.
Auto-detects scope from enclosing definition, or prompts."
  (interactive)
  (sysml2--diagram-generate-and-show
   'state-machine (sysml2--diagram-read-scope "State machine")))

(defun sysml2-diagram-action-flow ()
  "Preview an action flow diagram.
Auto-detects scope from enclosing definition, or prompts."
  (interactive)
  (sysml2--diagram-generate-and-show
   'action-flow (sysml2--diagram-read-scope "Action flow")))

(defun sysml2-diagram-requirement ()
  "Preview a requirement tree diagram for the current buffer."
  (interactive)
  (sysml2--diagram-generate-and-show 'requirement-tree nil))

(defun sysml2-diagram-use-case ()
  "Preview a use case diagram for the current buffer."
  (interactive)
  (sysml2--diagram-generate-and-show 'use-case nil))

(defun sysml2-diagram-package ()
  "Preview a package diagram for the current buffer."
  (interactive)
  (sysml2--diagram-generate-and-show 'package nil))

(defun sysml2-diagram-export (filename)
  "Export diagram to FILENAME; format derived from extension.
Bound to `C-c C-d e'."
  (interactive "FExport diagram to file: ")
  (let* ((ext (or (file-name-extension filename) "svg"))
         (format ext)
         (detected (sysml2--model-detect-diagram-type-at-point))
         (dtype (car detected))
         (scope (cdr detected)))
    (pcase sysml2-diagram-backend
      ('native
       (cond
        ((memq dtype sysml2--diagram-d2-types)
         (if (sysml2--diagram-resolve-d2)
             (let ((d2-src (sysml2-d2-generate dtype scope)))
               (sysml2--diagram-invoke-d2
                d2-src format
                (lambda (success data)
                  (if success
                      (progn
                        (with-temp-file filename
                          (set-buffer-multibyte nil)
                          (insert data))
                        (message "Exported to %s" filename))
                    (message "D2 error: %s" data)))))
           ;; Fall back to SVG for types that support it
           (if (memq dtype sysml2--diagram-svg-types)
               (let ((svg-data (sysml2-svg-generate dtype scope)))
                 (with-temp-file filename
                   (set-buffer-multibyte nil)
                   (insert svg-data))
                 (message "Exported to %s (SVG fallback)" filename))
             (user-error "D2 not installed; cannot export %s diagram" dtype))))))
      ('plantuml
       (let ((puml (sysml2-plantuml-generate dtype scope)))
         (sysml2--diagram-invoke-plantuml
          puml format
          (lambda (success data)
            (if success
                (progn
                  (with-temp-file filename
                    (set-buffer-multibyte nil)
                    (insert data))
                  (message "Exported to %s" filename))
              (message "PlantUML error: %s" data)))))))))

(defun sysml2-diagram-type (type)
  "Generate a diagram of TYPE via completing-read."
  (interactive
   (list (intern (completing-read "Diagram type: "
                                  '("tree" "interconnection" "state-machine"
                                    "action-flow" "requirement-tree"
                                    "use-case" "package")
                                  nil t))))
  (let ((scope (when (memq type '(interconnection state-machine action-flow))
                 (sysml2--diagram-read-scope
                  (pcase type
                    ('interconnection "IBD")
                    ('state-machine "State machine")
                    ('action-flow "Action flow"))))))
    (sysml2--diagram-generate-and-display type scope)))

(defun sysml2-diagram-open-plantuml ()
  "Open the diagram source for the current diagram in a buffer.
Bound to `C-c C-d o'."
  (interactive)
  (let* ((detected (sysml2--model-detect-diagram-type-at-point))
         (dtype (car detected))
         (scope (cdr detected)))
    (pcase sysml2-diagram-backend
      ('native
       (cond
        ((memq dtype sysml2--diagram-d2-types)
         (let ((d2-src (sysml2-d2-generate dtype scope))
               (buf (get-buffer-create "*SysML2 D2 Source*")))
           (with-current-buffer buf
             (erase-buffer)
             (insert d2-src)
             (goto-char (point-min)))
           (pop-to-buffer buf)))))
      ('plantuml
       (let ((puml (sysml2-plantuml-generate dtype scope))
             (buf (get-buffer-create "*SysML2 PlantUML*")))
         (with-current-buffer buf
           (erase-buffer)
           (insert puml)
           (goto-char (point-min))
           (when (fboundp 'plantuml-mode)
             (plantuml-mode)))
         (pop-to-buffer buf))))))

;; --- D2 Playground (Web Interface) ---

(defun sysml2--d2-playground-encode (d2-source)
  "Encode D2-SOURCE for use in a D2 playground URL.
Uses base64url encoding."
  (let ((b64 (base64-encode-string (encode-coding-string d2-source 'utf-8) t)))
    ;; Convert to base64url: + -> -, / -> _, remove padding =
    (setq b64 (replace-regexp-in-string "\\+" "-" b64))
    (setq b64 (replace-regexp-in-string "/" "_" b64))
    (setq b64 (replace-regexp-in-string "=+$" "" b64))
    b64))

(defun sysml2-diagram-open-in-playground ()
  "Open the current diagram in the D2 web playground.
Generates D2 source for the diagram at point and opens it in
the browser at play.d2lang.com for interactive viewing.
Changes to the D2 source in the playground do NOT update the
SysML model — this is a one-way visualization.
No local D2 installation required."
  (interactive)
  (let* ((detected (sysml2--model-detect-diagram-type-at-point))
         (dtype (car detected))
         (scope (cdr detected)))
    (if (memq dtype sysml2--diagram-d2-types)
        (let* ((d2-src (sysml2-d2-generate dtype scope))
               (encoded (sysml2--d2-playground-encode d2-src))
               (url (concat "https://play.d2lang.com/?script=" encoded)))
          (browse-url url)
          (message "Opened diagram in D2 playground (read-only visualization)"))
      (message "Unknown diagram type: %s" dtype))))

;; --- Synchronous Invocation ---

(defun sysml2--diagram-invoke-plantuml-sync (puml-string format)
  "Synchronously invoke PlantUML on PUML-STRING for FORMAT.
Returns image data as a string.  Signals `user-error' if PlantUML
is not available or the process fails.  Suitable for batch use."
  (let ((resolved (sysml2--diagram-resolve-plantuml)))
    (unless resolved
      (user-error "PlantUML not found; configure `sysml2-plantuml-exec-mode'"))
    (when (eq (plist-get resolved :mode) 'server)
      (user-error "Synchronous rendering does not support server mode"))
    (let* ((command (plist-get resolved :command))
           (args (append command (list (concat "-t" format) "-pipe")))
           (exit-code nil)
           (output
            (with-temp-buffer
              (set-buffer-multibyte nil)
              (setq exit-code
                    (apply #'call-process-region
                           puml-string nil (car args) nil t nil (cdr args)))
              (buffer-string))))
      (unless (= exit-code 0)
        (user-error "PlantUML failed (exit %d): %s" exit-code output))
      output)))

;; --- File Rendering ---

(defun sysml2-diagram-render-puml-file (puml-file &optional output-file format)
  "Render PUML-FILE to OUTPUT-FILE using PlantUML.
FORMAT defaults to `sysml2-diagram-output-format'.
OUTPUT-FILE defaults to PUML-FILE with the format as extension.
Returns the output file path."
  (interactive "fPlantUML file: ")
  (let* ((fmt (or format sysml2-diagram-output-format))
         (outfile (or output-file
                      (concat (file-name-sans-extension puml-file) "." fmt)))
         (puml (with-temp-buffer
                 (insert-file-contents puml-file)
                 (buffer-string)))
         (data (sysml2--diagram-invoke-plantuml-sync puml fmt)))
    (with-temp-file outfile
      (set-buffer-multibyte nil)
      (insert data))
    (message "Rendered %s -> %s" (file-name-nondirectory puml-file)
             (file-name-nondirectory outfile))
    outfile))

(defun sysml2-diagram-render-examples (&optional format)
  "Render all .puml files in the examples/plantuml/ directory.
FORMAT defaults to `sysml2-diagram-output-format'.
Works both interactively and in batch mode:
  emacs --batch -L . -l sysml2-mode -f sysml2-diagram-render-examples"
  (interactive)
  (let* ((fmt (or format sysml2-diagram-output-format))
         (root (or (locate-dominating-file
                    (or load-file-name buffer-file-name default-directory)
                    "examples")
                   default-directory))
         (dir (expand-file-name "examples/plantuml/" root))
         (files (and (file-directory-p dir)
                     (directory-files dir t "\\.puml\\'")))
         (count 0))
    (unless files
      (user-error "No .puml files found in %s" dir))
    (dolist (f files)
      (condition-case err
          (progn
            (sysml2-diagram-render-puml-file f nil fmt)
            (cl-incf count))
        (user-error
         (message "Skipped %s: %s" (file-name-nondirectory f) (cadr err)))))
    (message "Rendered %d/%d example diagrams to %s" count (length files) fmt)
    count))

;; --- Example Generation ---

(defconst sysml2--diagram-example-specs
  '(;; simple-vehicle.sysml
    (:fixture "simple-vehicle.sysml" :type tree :scope nil
     :output "vehicle-parts-tree.puml")
    (:fixture "simple-vehicle.sysml" :type interconnection :scope "Vehicle"
     :output "vehicle-ibd.puml")
    (:fixture "simple-vehicle.sysml" :type state-machine :scope "EngineStates"
     :output "engine-states.puml")
    (:fixture "simple-vehicle.sysml" :type action-flow :scope "Drive"
     :output "drive-action-flow.puml")
    (:fixture "simple-vehicle.sysml" :type requirement-tree :scope nil
     :output "vehicle-requirements.puml")
    (:fixture "simple-vehicle.sysml" :type use-case :scope nil
     :output "vehicle-use-case.puml")
    ;; flashlight.sysml
    (:fixture "flashlight.sysml" :type tree :scope nil
     :output "flashlight-parts-tree.puml")
    (:fixture "flashlight.sysml" :type interconnection :scope "Flashlight"
     :output "flashlight-ibd.puml")
    (:fixture "flashlight.sysml" :type state-machine :scope "FlashlightStates"
     :output "flashlight-states.puml")
    (:fixture "flashlight.sysml" :type action-flow :scope "UseFlashlight"
     :output "flashlight-action-flow.puml")
    (:fixture "flashlight.sysml" :type requirement-tree :scope nil
     :output "flashlight-requirements.puml")
    ;; annex-a-simple-vehicle-model.sysml
    (:fixture "annex-a-simple-vehicle-model.sysml" :type tree :scope nil
     :output "annex-a-parts-tree.puml")
    (:fixture "annex-a-simple-vehicle-model.sysml" :type requirement-tree :scope nil
     :output "annex-a-requirements.puml")
    (:fixture "annex-a-simple-vehicle-model.sysml" :type use-case :scope nil
     :output "annex-a-use-case.puml")
    (:fixture "annex-a-simple-vehicle-model.sysml" :type package :scope nil
     :output "annex-a-packages.puml"))
  "Specifications for example PlantUML generation.
Each entry maps a fixture file and diagram type to an output file.")

(defun sysml2-diagram-generate-examples ()
  "Generate example .puml files from .sysml fixtures using our generators.
Reads each fixture, runs the appropriate PlantUML generator, and writes
the result to examples/plantuml/.  Works interactively and in batch:
  emacs --batch -L . -l sysml2-mode -f sysml2-diagram-generate-examples"
  (interactive)
  (let* ((root (or (locate-dominating-file
                    (or load-file-name buffer-file-name default-directory)
                    "test")
                   default-directory))
         (fixture-dir (expand-file-name "test/fixtures/" root))
         (output-dir (expand-file-name "examples/plantuml/" root))
         (count 0))
    (unless (file-directory-p fixture-dir)
      (user-error "Fixture directory not found: %s" fixture-dir))
    (make-directory output-dir t)
    (dolist (spec sysml2--diagram-example-specs)
      (let* ((fixture (plist-get spec :fixture))
             (dtype (plist-get spec :type))
             (scope (plist-get spec :scope))
             (output (plist-get spec :output))
             (fixture-path (expand-file-name fixture fixture-dir))
             (output-path (expand-file-name output output-dir)))
        (condition-case err
            (let ((puml (with-temp-buffer
                          (insert-file-contents fixture-path)
                          (sysml2-mode)
                          (sysml2-plantuml-generate dtype scope))))
              (with-temp-file output-path
                (insert puml)
                (insert "\n"))
              (message "Generated %s" output)
              (cl-incf count))
          (error
           (message "Failed %s: %s" output (error-message-string err))))))
    (message "Generated %d/%d example PlantUML files"
             count (length sysml2--diagram-example-specs))
    count))

;; --- View-Filtered Diagrams ---

(defconst sysml2--diagram-view-filter-type-alist
  '(("PartUsage" . tree)
    ("PartDefinition" . tree)
    ("RequirementUsage" . requirement-tree)
    ("RequirementDefinition" . requirement-tree)
    ("ConnectionUsage" . interconnection)
    ("InterfaceUsage" . interconnection)
    ("StateUsage" . state-machine)
    ("StateDefinition" . state-machine)
    ("ActionUsage" . action-flow)
    ("ActionDefinition" . action-flow)
    ("UseCaseUsage" . use-case)
    ("UseCaseDefinition" . use-case)
    ("Package" . package)
    ("AllocationUsage" . tree)
    ("FlowConnectionUsage" . interconnection))
  "Map SysML v2 view filter metatype names to diagram type symbols.")

(defconst sysml2--diagram-render-method-alist
  '(("asTreeDiagram" . tree)
    ("asInterconnectionDiagram" . interconnection)
    ("asStateMachineDiagram" . state-machine)
    ("asActionFlowDiagram" . action-flow)
    ("asRequirementDiagram" . requirement-tree)
    ("asUseCaseDiagram" . use-case)
    ("asPackageDiagram" . package)
    ("asTableDiagram" . tree))
  "Map SysML v2 render method names to diagram type symbols.")

(defun sysml2--diagram-parse-views ()
  "Parse the current buffer for view definitions and usages.
Return a list of (NAME . DIAGRAM-TYPE) where DIAGRAM-TYPE is resolved
from `render' clauses, `filter @SysML::XXX' clauses, and view
inheritance via `:>' or `:' specialization."
  (save-excursion
    (goto-char (point-min))
    (let ((view-defs (make-hash-table :test 'equal))
          (results nil)
          ;; Match view def with optional inheritance
          (def-re (concat "\\bview[ \t]+def[ \t]+"
                          "\\([A-Za-z_][A-Za-z0-9_]*\\)"
                          "\\(?:[ \t]*:>?[ \t]*\\([A-Za-z_][A-Za-z0-9_]*\\)\\)?"))
          ;; Match view usage with optional type
          (usage-re (concat "\\bview[ \t]+"
                            "\\([A-Za-z_][A-Za-z0-9_]*\\)"
                            "\\(?:[ \t]*:>?[ \t]*\\([A-Za-z_][A-Za-z0-9_]*\\)\\)?")))
      ;; Pass 1: collect all view defs
      (while (re-search-forward def-re nil t)
        (unless (let ((ppss (syntax-ppss))) (or (nth 3 ppss) (nth 4 ppss)))
          (let ((name (match-string-no-properties 1))
                (parent (match-string-no-properties 2))
                (view-start (match-end 0))
                (render-dtype nil)
                (filter-dtype nil))
            ;; Parse body for render and filter clauses
            (save-excursion
              (goto-char view-start)
              (when (re-search-forward "{" (line-end-position 3) t)
                (let ((brace-start (1- (point))) brace-end)
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq brace-end (point)))
                    (scan-error nil))
                  (when brace-end
                    (let ((body (buffer-substring-no-properties
                                 brace-start brace-end)))
                      ;; Check for render clause
                      (when (string-match
                             "\\brender[ \t]+\\([A-Za-z_][A-Za-z0-9_]*\\)"
                             body)
                        (setq render-dtype
                              (cdr (assoc (match-string 1 body)
                                          sysml2--diagram-render-method-alist))))
                      ;; Check for filter clause
                      (when (string-match
                             "filter[ \t]+@SysML::\\([A-Za-z_][A-Za-z0-9_]*\\)"
                             body)
                        (setq filter-dtype
                              (cdr (assoc (match-string 1 body)
                                          sysml2--diagram-view-filter-type-alist)))))))))
            (puthash name (list :parent parent
                                :dtype (or render-dtype filter-dtype))
                     view-defs))))
      ;; Pass 2: resolve inheritance for view defs (max 10 iterations)
      (let ((changed t) (guard 0))
        (while (and changed (< guard 10))
          (setq changed nil guard (1+ guard))
          (maphash
           (lambda (_name props)
             (when (and (not (plist-get props :dtype))
                        (plist-get props :parent))
               (let* ((parent-name (plist-get props :parent))
                      (parent-props (gethash parent-name view-defs)))
                 (when (and parent-props (plist-get parent-props :dtype))
                   (plist-put props :dtype (plist-get parent-props :dtype))
                   (setq changed t)))))
           view-defs)))
      ;; Collect resolved view defs
      (maphash (lambda (name props)
                 (when (plist-get props :dtype)
                   (push (cons name (plist-get props :dtype)) results)))
               view-defs)
      ;; Pass 3: collect view usages (not defs)
      (goto-char (point-min))
      (while (re-search-forward usage-re nil t)
        (unless (let ((ppss (syntax-ppss))) (or (nth 3 ppss) (nth 4 ppss)))
          (let ((name (match-string-no-properties 1))
                (type-name (match-string-no-properties 2)))
            ;; Skip if this is actually a `view def'
            (unless (string= name "def")
              ;; Check body for filter clause
              (let ((usage-dtype nil)
                    (usage-start (match-end 0)))
                (save-excursion
                  (goto-char usage-start)
                  (when (re-search-forward "{" (line-end-position 3) t)
                    (let ((brace-start (1- (point))) brace-end)
                      (goto-char brace-start)
                      (condition-case nil
                          (progn (forward-sexp 1) (setq brace-end (point)))
                        (scan-error nil))
                      (when brace-end
                        (let ((body (buffer-substring-no-properties
                                     brace-start brace-end)))
                          (when (string-match
                                 "filter[ \t]+@SysML::\\([A-Za-z_][A-Za-z0-9_]*\\)"
                                 body)
                            (setq usage-dtype
                                  (cdr (assoc (match-string 1 body)
                                              sysml2--diagram-view-filter-type-alist)))))))))
                ;; Resolve from type or parent view def
                (unless usage-dtype
                  (when type-name
                    (let ((parent-props (gethash type-name view-defs)))
                      (when parent-props
                        (setq usage-dtype (plist-get parent-props :dtype))))))
                (when usage-dtype
                  (push (cons name usage-dtype) results)))))))
      (nreverse results))))

(defun sysml2-diagram-view ()
  "Generate a diagram based on a `view def' in the current buffer.
Parses all view definitions with `filter @SysML::...' clauses,
prompts the user to select one, then generates and displays the
corresponding diagram type."
  (interactive)
  (let ((views (sysml2--diagram-parse-views)))
    (unless views
      (user-error "No view definitions with filter clauses found in buffer"))
    (let* ((candidates (mapcar (lambda (v)
                                 (format "%s (%s)" (car v) (cdr v)))
                               views))
           (choice (completing-read "View: " candidates nil t))
           (idx (cl-position choice candidates :test #'string=))
           (view (nth idx views))
           (dtype (cdr view))
           (scope (when (memq dtype '(interconnection state-machine action-flow))
                    (sysml2--diagram-read-scope (symbol-name dtype)))))
      (sysml2--diagram-generate-and-show dtype scope))))

;; --- Preview Minor Mode ---

(defvar sysml2-diagram-preview-mode)

(defun sysml2--diagram-preview-on-save ()
  "Hook to regenerate diagram preview after save."
  (when (and sysml2-diagram-preview-mode
             (buffer-live-p sysml2--diagram-preview-buffer)
             (get-buffer-window sysml2--diagram-preview-buffer))
    (sysml2-diagram-preview-buffer)))

(define-minor-mode sysml2-diagram-preview-mode
  "Minor mode for auto-refreshing diagram preview on save."
  :lighter " SysML2-Preview"
  (if sysml2-diagram-preview-mode
      (add-hook 'after-save-hook #'sysml2--diagram-preview-on-save nil t)
    (remove-hook 'after-save-hook #'sysml2--diagram-preview-on-save t)))

;; --- Org-Babel Integration ---

(with-eval-after-load 'org
  (defun org-babel-execute:sysml (body params)
    "Execute a SysML v2 code block via diagram generation.
Supported PARAMS:
  :diagram-type — one of tree, interconnection, state-machine,
                  action-flow, requirement-tree (default: tree)
  :scope — definition name for scoped diagrams
  :file — output file path"
    (let* ((diagram-type (intern (or (cdr (assq :diagram-type params)) "tree")))
           (scope (cdr (assq :scope params)))
           (out-file (cdr (assq :file params))))
      (with-temp-buffer
        (insert body)
        (sysml2-mode)
        (if out-file
            (let ((format (or (file-name-extension out-file) "svg")))
              (pcase sysml2-diagram-backend
                ('native
                 (if (and (sysml2--diagram-resolve-d2)
                          (memq diagram-type sysml2--diagram-d2-types))
                     (let* ((d2-src (sysml2-d2-generate diagram-type scope))
                            (data (sysml2--diagram-invoke-d2-sync d2-src format)))
                       (with-temp-file out-file
                         (set-buffer-multibyte nil)
                         (insert data))
                       out-file)
                   ;; Fall back to SVG
                   (when (memq diagram-type sysml2--diagram-svg-types)
                     (let ((svg (sysml2-svg-generate diagram-type scope)))
                       (with-temp-file out-file
                         (set-buffer-multibyte nil)
                         (insert svg))
                       out-file))))
                ('plantuml
                 (let ((puml (sysml2-plantuml-generate diagram-type scope))
                       (result nil))
                   (sysml2--diagram-invoke-plantuml
                    puml format
                    (lambda (success data)
                      (if success
                          (progn
                            (with-temp-file out-file
                              (set-buffer-multibyte nil)
                              (insert data))
                            (setq result out-file))
                        (setq result (format "Error: %s" data)))))
                   result))))
          ;; No output file — return source
          (pcase sysml2-diagram-backend
            ('native
             (if (memq diagram-type sysml2--diagram-d2-types)
                 (sysml2-d2-generate diagram-type scope)
               (when (memq diagram-type sysml2--diagram-svg-types)
                 (sysml2-svg-generate diagram-type scope))))
            ('plantuml
             (sysml2-plantuml-generate diagram-type scope))))))))

(provide 'sysml2-diagram)
;;; sysml2-diagram.el ends here
