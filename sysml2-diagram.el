;;; sysml2-diagram.el --- Diagram commands for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; User-facing diagram commands and preview management.  Handles
;; PlantUML invocation (executable, jar, or server), image display,
;; export, and auto-refresh preview mode.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-diagram-preview' -- Preview diagram at point
;;   `sysml2-diagram-preview-buffer' -- Preview tree diagram for buffer
;;   `sysml2-diagram-export' -- Export diagram to file
;;   `sysml2-diagram-type' -- Select diagram type via completing-read
;;   `sysml2-diagram-open-plantuml' -- Open PlantUML source buffer
;;   `sysml2-diagram-preview-mode' -- Minor mode for auto-refresh
;;   `sysml2-diagram-render-puml-file' -- Render a .puml file to image
;;   `sysml2-diagram-render-examples' -- Batch render all example .puml files
;;   `sysml2-diagram-generate-examples' -- Generate .puml from .sysml fixtures

(require 'sysml2-vars)
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
  (let* ((detected (sysml2-plantuml-detect-type-at-point))
         (dtype (car detected))
         (scope (cdr detected))
         (puml (sysml2-plantuml-generate dtype scope)))
    (setq sysml2--diagram-source-buffer (current-buffer))
    (sysml2--diagram-invoke-plantuml
     puml sysml2-diagram-output-format
     (lambda (success data)
       (if success
           (sysml2--diagram-display-image data sysml2-diagram-output-format)
         (message "PlantUML error: %s" data))))))

(defun sysml2-diagram-preview-buffer ()
  "Preview a tree diagram for the entire buffer.
Bound to `C-c C-d b'."
  (interactive)
  (let ((puml (sysml2-plantuml-generate 'tree nil)))
    (setq sysml2--diagram-source-buffer (current-buffer))
    (sysml2--diagram-invoke-plantuml
     puml sysml2-diagram-output-format
     (lambda (success data)
       (if success
           (sysml2--diagram-display-image data sysml2-diagram-output-format)
         (message "PlantUML error: %s" data))))))

(defun sysml2-diagram-export (filename)
  "Export diagram to FILENAME; format derived from extension.
Bound to `C-c C-d e'."
  (interactive "FExport diagram to file: ")
  (let* ((ext (file-name-extension filename))
         (format (or ext sysml2-diagram-output-format))
         (detected (sysml2-plantuml-detect-type-at-point))
         (dtype (car detected))
         (scope (cdr detected))
         (puml (sysml2-plantuml-generate dtype scope)))
    (sysml2--diagram-invoke-plantuml
     puml format
     (lambda (success data)
       (if success
           (progn
             (with-temp-file filename
               (set-buffer-multibyte nil)
               (insert data))
             (message "Exported to %s" filename))
         (message "PlantUML error: %s" data))))))

(defun sysml2-diagram-type (type)
  "Generate a diagram of TYPE via completing-read.
Bound to `C-c C-d t'."
  (interactive
   (list (intern (completing-read "Diagram type: "
                                  '("tree" "interconnection" "state-machine"
                                    "action-flow" "requirement-tree"
                                    "use-case" "package")
                                  nil t))))
  (let* ((scope (when (memq type '(interconnection state-machine action-flow))
                  (read-string "Scope (definition name): ")))
         (puml (sysml2-plantuml-generate type (if (string-empty-p scope) nil scope))))
    (setq sysml2--diagram-source-buffer (current-buffer))
    (sysml2--diagram-invoke-plantuml
     puml sysml2-diagram-output-format
     (lambda (success data)
       (if success
           (sysml2--diagram-display-image data sysml2-diagram-output-format)
         (message "PlantUML error: %s" data))))))

(defun sysml2-diagram-open-plantuml ()
  "Open the PlantUML source for the current diagram in a buffer.
Uses `plantuml-mode' if available.  Bound to `C-c C-d o'."
  (interactive)
  (let* ((detected (sysml2-plantuml-detect-type-at-point))
         (dtype (car detected))
         (scope (cdr detected))
         (puml (sysml2-plantuml-generate dtype scope))
         (buf (get-buffer-create "*SysML2 PlantUML*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert puml)
      (goto-char (point-min))
      (when (fboundp 'plantuml-mode)
        (plantuml-mode)))
    (pop-to-buffer buf)))

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
    "Execute a SysML v2 code block via PlantUML transformation.
Supported PARAMS:
  :diagram-type — one of tree, interconnection, state-machine,
                  action-flow, requirement-tree (default: tree)
  :scope — definition name for scoped diagrams
  :file — output file path"
    (let* ((diagram-type (intern (or (cdr (assq :diagram-type params)) "tree")))
           (scope (cdr (assq :scope params)))
           (out-file (cdr (assq :file params)))
           (puml (with-temp-buffer
                   (insert body)
                   (sysml2-mode)
                   (sysml2-plantuml-generate diagram-type scope))))
      (if out-file
          (let ((format (or (file-name-extension out-file)
                            sysml2-diagram-output-format))
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
            result)
        puml))))

(provide 'sysml2-diagram)
;;; sysml2-diagram.el ends here
