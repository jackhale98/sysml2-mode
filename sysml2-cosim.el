;;; sysml2-cosim.el --- Co-simulation orchestration for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Co-simulation orchestration for sysml2-mode.  Provides:
;;   - SSP generation (SysML connections → SystemStructureDescription)
;;   - Tool invocation (FMPy / OMSimulator async execution)
;;   - Results visualization (CSV parsing, tabulated display, gnuplot)
;;   - Requirement verification dashboard (constraint checking)

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-cosim-generate-ssp' -- Generate SSP from SysML connections
;;   `sysml2-cosim-run' -- Run co-simulation
;;   `sysml2-cosim-stop' -- Stop running simulation
;;   `sysml2-cosim-results' -- Display simulation results
;;   `sysml2-cosim-verify-requirements' -- Verify requirements against results

(require 'sysml2-vars)
(require 'sysml2-lang)
(require 'sysml2-fmi)

(require 'sysml2-model)

;; --- SSP Generation ---

(defun sysml2--cosim-extract-ssp-structure (&optional buffer)
  "Extract system components and connections from SysML BUFFER.
Returns plist with `:components' and `:connections'.
Components are plists with `:name' and `:type'.
Connections are plists with `:name', `:source', `:target',
`:start-element', `:start-connector', `:end-element', `:end-connector'."
  (with-current-buffer (or buffer (current-buffer))
    (let ((parts (sysml2--model-extract-part-usages))
          (conns (sysml2--model-extract-connections))
          (components nil)
          (connections nil))
      ;; Convert part usages to components
      (dolist (part parts)
        (push (list :name (plist-get part :name)
                    :type (plist-get part :type))
              components))
      ;; Convert connections with dotted references
      (dolist (conn conns)
        (let* ((source (plist-get conn :source))
               (target (plist-get conn :target))
               (src-parts (split-string source "\\."))
               (tgt-parts (split-string target "\\.")))
          (push (list :name (plist-get conn :name)
                      :source source
                      :target target
                      :start-element (car src-parts)
                      :start-connector (or (cadr src-parts) (car src-parts))
                      :end-element (car tgt-parts)
                      :end-connector (or (cadr tgt-parts) (car tgt-parts)))
                connections)))
      (list :components (nreverse components)
            :connections (nreverse connections)))))

(defun sysml2--cosim-generate-ssd-xml (structure)
  "Generate SSP SystemStructureDescription XML from STRUCTURE."
  (let ((components (plist-get structure :components))
        (connections (plist-get structure :connections))
        (lines nil))
    (push "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" lines)
    (push (concat "<ssd:SystemStructureDescription version=\"1.0\" name=\"system\""
                  "\n    xmlns:ssd=\"http://ssp-standard.org/SSP1/"
                  "SystemStructureDescription\">")
          lines)
    (push "  <ssd:System name=\"root\">" lines)
    ;; Elements
    (push "    <ssd:Elements>" lines)
    (dolist (comp components)
      (let ((name (plist-get comp :name))
            (type (plist-get comp :type)))
        (push (format "      <ssd:Component name=\"%s\" source=\"resources/%s.fmu\">"
                      name (downcase type))
              lines)
        (push "        <ssd:Connectors>" lines)
        ;; Find connectors for this component from connections
        (let ((seen (make-hash-table :test 'equal)))
          (dolist (conn connections)
            (when (equal (plist-get conn :start-element) name)
              (let ((connector (plist-get conn :start-connector)))
                (unless (gethash connector seen)
                  (puthash connector t seen)
                  (push (format "          <ssd:Connector name=\"%s\" kind=\"output\"/>"
                                connector)
                        lines))))
            (when (equal (plist-get conn :end-element) name)
              (let ((connector (plist-get conn :end-connector)))
                (unless (gethash connector seen)
                  (puthash connector t seen)
                  (push (format "          <ssd:Connector name=\"%s\" kind=\"input\"/>"
                                connector)
                        lines))))))
        (push "        </ssd:Connectors>" lines)
        (push "      </ssd:Component>" lines)))
    (push "    </ssd:Elements>" lines)
    ;; Connections
    (push "    <ssd:Connections>" lines)
    (dolist (conn connections)
      (push (format (concat "      <ssd:Connection"
                            " startElement=\"%s\" startConnector=\"%s\""
                            " endElement=\"%s\" endConnector=\"%s\"/>")
                    (plist-get conn :start-element)
                    (plist-get conn :start-connector)
                    (plist-get conn :end-element)
                    (plist-get conn :end-connector))
            lines))
    (push "    </ssd:Connections>" lines)
    (push "  </ssd:System>" lines)
    (push "</ssd:SystemStructureDescription>" lines)
    (mapconcat #'identity (nreverse lines) "\n")))

(defun sysml2--cosim-package-ssp (ssd-xml fmu-paths output-path)
  "Package SSD-XML and FMU-PATHS into an SSP at OUTPUT-PATH."
  (let ((tmp-dir (make-temp-file "sysml2-ssp-" t)))
    ;; Write SSD
    (let ((ssd-path (expand-file-name "SystemStructure.ssd" tmp-dir)))
      (with-temp-file ssd-path
        (insert ssd-xml)))
    ;; Copy FMUs to resources/
    (let ((res-dir (expand-file-name "resources" tmp-dir)))
      (make-directory res-dir t)
      (dolist (fmu fmu-paths)
        (when (file-exists-p fmu)
          (copy-file fmu (expand-file-name
                          (file-name-nondirectory fmu) res-dir)
                     t))))
    ;; Create ZIP
    (let ((default-directory tmp-dir))
      (call-process "zip" nil nil nil "-r"
                    (expand-file-name output-path) "."))))

;;;###autoload
(defun sysml2-cosim-generate-ssp (&optional buffer)
  "Generate SSP from SysML connections in BUFFER.
Interactive: prompts for output path."
  (interactive)
  (let* ((buf (or buffer (current-buffer)))
         (structure (with-current-buffer buf
                      (sysml2--cosim-extract-ssp-structure)))
         (ssd-xml (sysml2--cosim-generate-ssd-xml structure)))
    (if (called-interactively-p 'any)
        (let ((output-path (read-file-name "Save SSP file: "
                                           nil nil nil "system.ssp")))
          (sysml2--cosim-package-ssp ssd-xml nil output-path)
          (message "SSP written to %s" output-path))
      ssd-xml)))

;; --- Tool Invocation ---

(defun sysml2--cosim-resolve-tool ()
  "Resolve the co-simulation tool executable.
Returns (TOOL . PATH) where TOOL is `fmpy' or `omsimulator'."
  (pcase sysml2-cosim-tool
    ('fmpy
     (let ((path (or sysml2-fmi-fmpy-executable
                     (executable-find "fmpy"))))
       (if path
           (cons 'fmpy path)
         (user-error "FMPy not found.  Set `sysml2-fmi-fmpy-executable'"))))
    ('omsimulator
     (let ((path (or sysml2-cosim-omsimulator-path
                     (executable-find "OMSimulator"))))
       (if path
           (cons 'omsimulator path)
         (user-error "OMSimulator not found.  Set `sysml2-cosim-omsimulator-path'"))))))

(defun sysml2--cosim-invoke-fmpy (target stop-time output-file callback)
  "Run FMPy simulation on TARGET with STOP-TIME.
Write results to OUTPUT-FILE.  CALLBACK receives (SUCCESS MESSAGE)."
  (let* ((tool-info (sysml2--cosim-resolve-tool))
         (fmpy-path (cdr tool-info))
         (proc-buf (generate-new-buffer " *sysml2-cosim*"))
         (args (list "simulate" (expand-file-name target)
                     "--stop-time" (number-to-string stop-time)
                     "--output-file" (expand-file-name output-file))))
    (setq sysml2--cosim-process
          (apply #'start-process "sysml2-cosim" proc-buf fmpy-path args))
    (set-process-sentinel
     sysml2--cosim-process
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (let ((output (with-current-buffer (process-buffer proc)
                         (buffer-string))))
           (if (= (process-exit-status proc) 0)
               (funcall callback t output)
             (funcall callback nil output)))
         (kill-buffer (process-buffer proc))
         (setq sysml2--cosim-process nil))))))

(defun sysml2--cosim-invoke-omsimulator (ssp-path output-file callback)
  "Run OMSimulator on SSP-PATH, writing results to OUTPUT-FILE.
CALLBACK receives (SUCCESS MESSAGE)."
  (let* ((tool-info (sysml2--cosim-resolve-tool))
         (oms-path (cdr tool-info))
         (proc-buf (generate-new-buffer " *sysml2-cosim*"))
         (args (list "--stripRoot=true"
                     (format "--resultFile=%s" (expand-file-name output-file))
                     (expand-file-name ssp-path))))
    (setq sysml2--cosim-process
          (apply #'start-process "sysml2-cosim" proc-buf oms-path args))
    (set-process-sentinel
     sysml2--cosim-process
     (lambda (proc _event)
       (when (memq (process-status proc) '(exit signal))
         (let ((output (with-current-buffer (process-buffer proc)
                         (buffer-string))))
           (if (= (process-exit-status proc) 0)
               (funcall callback t output)
             (funcall callback nil output)))
         (kill-buffer (process-buffer proc))
         (setq sysml2--cosim-process nil))))))

;;;###autoload
(defun sysml2-cosim-run (&optional fmu-or-ssp)
  "Run co-simulation on FMU-OR-SSP.
Interactive: prompts for file path.  Runs asynchronously."
  (interactive
   (list (read-file-name "FMU or SSP file: ")))
  (when (and sysml2--cosim-process
             (process-live-p sysml2--cosim-process))
    (user-error "Simulation already running.  Use `sysml2-cosim-stop' first"))
  (let* ((target (or fmu-or-ssp
                     (read-file-name "FMU or SSP file: ")))
         (output-dir (or sysml2-cosim-output-dir
                         (file-name-directory target)))
         (output-file (expand-file-name
                       (concat "results." sysml2-cosim-results-format)
                       output-dir))
         (callback (lambda (success msg)
                     (if success
                         (progn
                           (message "Simulation complete: %s" output-file)
                           (sysml2-cosim-results output-file))
                       (message "Simulation failed: %s" msg)))))
    (message "Starting simulation: %s" target)
    (if (string-suffix-p ".ssp" target)
        (sysml2--cosim-invoke-omsimulator target output-file callback)
      (sysml2--cosim-invoke-fmpy target sysml2-cosim-stop-time
                                  output-file callback))))

;;;###autoload
(defun sysml2-cosim-stop ()
  "Stop the running co-simulation process."
  (interactive)
  (if (and sysml2--cosim-process
           (process-live-p sysml2--cosim-process))
      (progn
        (kill-process sysml2--cosim-process)
        (setq sysml2--cosim-process nil)
        (message "Simulation stopped."))
    (message "No simulation is running.")))

;; --- Results Visualization ---

(defun sysml2--cosim-parse-csv (csv-path)
  "Parse CSV file at CSV-PATH.
Returns plist with `:headers' (list of strings) and
`:rows' (list of lists of numbers/strings)."
  (with-temp-buffer
    (insert-file-contents csv-path)
    (let* ((all-lines (split-string (buffer-string) "\n" t))
           (headers (split-string (car all-lines) "," t))
           (rows nil))
      (dolist (line (cdr all-lines))
        (let ((fields (split-string line "," t))
              (row nil))
          (dolist (field fields)
            (let ((trimmed (string-trim field)))
              (push (if (string-match-p "^-?[0-9]*\\.?[0-9]+$" trimmed)
                        (string-to-number trimmed)
                      trimmed)
                    row)))
          (when row
            (push (nreverse row) rows))))
      (list :headers headers
            :rows (nreverse rows)))))

(defun sysml2--cosim-display-results (data csv-path)
  "Display simulation results DATA in a tabulated buffer.
CSV-PATH is shown in the header."
  (let ((buf (get-buffer-create "*SysML2 Simulation Results*"))
        (headers (plist-get data :headers))
        (rows (plist-get data :rows)))
    (setq sysml2--cosim-results-buffer buf)
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Simulation Results\n" 'face 'bold))
        (insert (make-string 50 ?-) "\n")
        (insert (format "File: %s\n" csv-path))
        (insert (format "Rows: %d, Columns: %d\n\n"
                        (length rows) (length headers)))
        ;; Header row
        (insert (mapconcat (lambda (h) (format "%-15s" h)) headers " ") "\n")
        (insert (make-string (* 16 (length headers)) ?-) "\n")
        ;; Data rows
        (dolist (row rows)
          (insert (mapconcat
                   (lambda (val)
                     (format "%-15s"
                             (if (numberp val)
                                 (format "%.4g" val)
                               val)))
                   row " ")
                  "\n")))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)
    buf))

(defun sysml2--cosim-plot-gnuplot (csv-path signals output-png)
  "Plot SIGNALS from CSV-PATH to OUTPUT-PNG using gnuplot."
  (let ((gnuplot (or sysml2-cosim-gnuplot-path
                     (executable-find "gnuplot"))))
    (unless gnuplot
      (user-error "Gnuplot not found.  Set `sysml2-cosim-gnuplot-path'"))
    (let* ((data (sysml2--cosim-parse-csv csv-path))
           (headers (plist-get data :headers))
           (script-lines nil)
           (col-indices
            (mapcar (lambda (sig)
                      (1+ (seq-position headers sig #'equal)))
                    signals)))
      (push "set terminal png size 800,600" script-lines)
      (push (format "set output '%s'" (expand-file-name output-png)) script-lines)
      (push "set datafile separator ','" script-lines)
      (push "set xlabel 'time'" script-lines)
      (push "set grid" script-lines)
      (push (concat "plot "
                    (mapconcat
                     (lambda (pair)
                       (format "'%s' using 1:%d with lines title '%s'"
                               (expand-file-name csv-path)
                               (car pair) (cdr pair)))
                     (cl-mapcar #'cons col-indices signals)
                     ", "))
            script-lines)
      (let ((script (mapconcat #'identity (nreverse script-lines) "\n"))
            (script-file (make-temp-file "sysml2-gnuplot-" nil ".gp")))
        (with-temp-file script-file
          (insert script))
        (call-process gnuplot nil nil nil script-file)
        (delete-file script-file)
        output-png))))

;;;###autoload
(defun sysml2-cosim-results (&optional results-file)
  "Display simulation results from RESULTS-FILE.
Interactive: prompts for CSV file path."
  (interactive
   (list (read-file-name "Results CSV: ")))
  (let* ((csv-path (or results-file
                       (read-file-name "Results CSV: ")))
         (data (sysml2--cosim-parse-csv csv-path)))
    (sysml2--cosim-display-results data csv-path)))

;; --- Requirement Verification ---

(defun sysml2--cosim-extract-constraint-expression (req-name &optional buffer)
  "Extract constraint from requirement def REQ-NAME in BUFFER.
Parses doc comment for simple `SIGNAL OP VALUE' patterns.
Returns plist (:signal :op :bound) or nil if complex/not found."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((re (concat "\\brequirement[ \t]+def[ \t]+"
                        (regexp-quote req-name) "\\b")))
        (when (re-search-forward re nil t)
          (when (re-search-forward "{" (line-end-position 2) t)
            (let ((brace-start (1- (point)))
                  (body-end nil))
              (goto-char brace-start)
              (condition-case nil
                  (progn (forward-sexp 1) (setq body-end (point)))
                (scan-error (setq body-end (point-max))))
              (goto-char (1+ brace-start))
              (when (re-search-forward
                     "\\bdoc[ \t]+/\\*[ \t]*\\([^*]*\\)\\*/"
                     body-end t)
                (let ((doc (string-trim (match-string-no-properties 1))))
                  ;; Try to parse SIGNAL OP VALUE pattern
                  (when (string-match
                         (concat "^\\([A-Za-z_][A-Za-z0-9_]*\\)"
                                 "[ \t]*\\(<=\\|>=\\|<\\|>\\|==\\)"
                                 "[ \t]*\\([0-9]+\\.?[0-9]*\\)")
                         doc)
                    (list :signal (match-string 1 doc)
                          :op (match-string 2 doc)
                          :bound (string-to-number
                                  (match-string 3 doc)))))))))))))

(defun sysml2--cosim-check-bounds (signal-data op bound)
  "Check SIGNAL-DATA (list of numbers) against OP and BOUND.
Returns `pass' if all values satisfy the constraint, `fail' otherwise."
  (let ((check-fn
         (pcase op
           ("<=" (lambda (v) (<= v bound)))
           (">=" (lambda (v) (>= v bound)))
           ("<"  (lambda (v) (< v bound)))
           (">"  (lambda (v) (> v bound)))
           ("==" (lambda (v) (= v bound)))
           (_    (lambda (_v) nil)))))
    (if (cl-every check-fn signal-data)
        'pass
      'fail)))

(defun sysml2--cosim-display-verification (results)
  "Display verification RESULTS in a dashboard buffer.
RESULTS is a list of plists with `:requirement', `:constraint',
`:signal', `:result', `:value'."
  (let ((buf (get-buffer-create "*SysML2 Verification*")))
    (setq sysml2--cosim-verification-buffer buf)
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Requirement Verification Dashboard\n" 'face 'bold))
        (insert (make-string 60 ?-) "\n\n")
        (insert (format "%-20s %-20s %-10s %-10s %s\n"
                        "Requirement" "Constraint" "Signal" "Result" "Value"))
        (insert (make-string 75 ?-) "\n")
        (dolist (r results)
          (let ((result (plist-get r :result))
                (face (pcase (plist-get r :result)
                        ('pass '(:foreground "green"))
                        ('fail '(:foreground "red"))
                        (_ '(:foreground "yellow")))))
            (insert (format "%-20s %-20s %-10s "
                            (plist-get r :requirement)
                            (or (plist-get r :constraint) "")
                            (or (plist-get r :signal) "")))
            (insert (propertize (format "%-10s" (upcase (symbol-name result)))
                                'face face))
            (insert (format " %s\n" (or (plist-get r :value) ""))))))
      (special-mode)
      (goto-char (point-min)))
    (pop-to-buffer buf)
    buf))

;;;###autoload
(defun sysml2-cosim-verify-requirements (&optional results-file buffer)
  "Verify requirements against simulation RESULTS-FILE.
BUFFER contains SysML requirement definitions.
Interactive: prompts for CSV file and uses current buffer."
  (interactive
   (list (read-file-name "Results CSV: ")))
  (let* ((buf (or buffer (current-buffer)))
         (csv-path (or results-file
                       (read-file-name "Results CSV: ")))
         (data (sysml2--cosim-parse-csv csv-path))
         (headers (plist-get data :headers))
         (rows (plist-get data :rows))
         (reqs (with-current-buffer buf
                 (sysml2--model-extract-requirements)))
         (verification nil))
    (dolist (req reqs)
      (let* ((req-name (plist-get req :name))
             (constraint (with-current-buffer buf
                           (sysml2--cosim-extract-constraint-expression
                            req-name))))
        (if constraint
            (let* ((signal (plist-get constraint :signal))
                   (op (plist-get constraint :op))
                   (bound (plist-get constraint :bound))
                   (col-idx (seq-position headers signal #'equal))
                   (signal-data
                    (when col-idx
                      (mapcar (lambda (row) (nth col-idx row)) rows))))
              (if signal-data
                  (let ((result (sysml2--cosim-check-bounds
                                 signal-data op bound)))
                    (push (list :requirement req-name
                                :constraint (format "%s %s %s" signal op bound)
                                :signal signal
                                :result result
                                :value (format "max=%.4g"
                                               (apply #'max signal-data)))
                          verification))
                (push (list :requirement req-name
                            :constraint (format "%s %s %s" signal op bound)
                            :signal signal
                            :result 'manual
                            :value "Signal not in results")
                      verification)))
          (push (list :requirement req-name
                      :constraint nil
                      :signal nil
                      :result 'manual
                      :value "Complex constraint")
                verification))))
    (let ((ver-results (nreverse verification)))
      (sysml2--cosim-display-verification ver-results)
      ver-results)))

(provide 'sysml2-cosim)
;;; sysml2-cosim.el ends here
