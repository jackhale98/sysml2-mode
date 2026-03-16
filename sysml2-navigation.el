;;; sysml2-navigation.el --- Navigation support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Navigation support for SysML v2 files: imenu (hierarchical),
;; outline-level, which-function-mode, beginning/end-of-defun.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-imenu-create-index' -- Build hierarchical imenu index
;;   `sysml2-outline-level' -- Compute outline level from indentation
;;   `sysml2-which-function' -- Return name of enclosing definition
;;   `sysml2-beginning-of-defun' -- Move to beginning of current definition
;;   `sysml2-end-of-defun' -- Move to end of current definition
;;   `sysml2-goto-definition' -- Jump to definition (current buffer + project)
;;   `sysml2-rename-symbol' -- Rename symbol in current buffer

(require 'sysml2-lang)

(declare-function sysml2-project-root "sysml2-project")
(declare-function sysml2-project-find-sysml-files "sysml2-project")
(declare-function sysml2-ts--search-definition-in-buffer "sysml2-ts")
(declare-function sysml2-ts--rename-symbol "sysml2-ts")

;; --- Imenu ---

(defconst sysml2--imenu-definition-re
  (concat "^\\s-*\\(?:"
          (regexp-opt sysml2-visibility-keywords t)
          "\\s-+\\)?"
          "\\(?:" (regexp-opt sysml2-definition-keywords t) "\\)"
          "\\s-+\\(" sysml2--identifier-regexp "\\)")
  "Regexp for matching definition declarations for imenu.
Captures the definition name in the last group.")

(defconst sysml2--imenu-package-re
  (concat "^\\s-*\\bpackage\\s-+\\(" sysml2--identifier-regexp "\\)")
  "Regexp for matching package declarations for imenu.")

(defconst sysml2--imenu-category-alist
  '(;; SysML v2
    ("part def" . "Parts")
    ("action def" . "Actions")
    ("state def" . "States")
    ("port def" . "Ports")
    ("connection def" . "Connections")
    ("attribute def" . "Attributes")
    ("item def" . "Items")
    ("requirement def" . "Requirements")
    ("constraint def" . "Constraints")
    ("view def" . "Views")
    ("viewpoint def" . "Viewpoints")
    ("rendering def" . "Renderings")
    ("concern def" . "Concerns")
    ("use case def" . "Use Cases")
    ("analysis def" . "Analyses")
    ("verification def" . "Verifications")
    ("allocation def" . "Allocations")
    ("interface def" . "Interfaces")
    ("flow def" . "Flows")
    ("enum def" . "Enumerations")
    ("occurrence def" . "Occurrences")
    ("metadata def" . "Metadata")
    ("calc def" . "Calculations")
    ("case def" . "Cases")
    ;; KerML
    ("assoc def" . "Associations")
    ("assoc struct def" . "Associations")
    ("behavior def" . "Behaviors")
    ("class def" . "Classes")
    ("classifier def" . "Classifiers")
    ("connector def" . "Connectors")
    ("datatype def" . "Datatypes")
    ("expr def" . "Expressions")
    ("feature def" . "Features")
    ("function def" . "Functions")
    ("interaction def" . "Interactions")
    ("metaclass def" . "Metaclasses")
    ("namespace def" . "Namespaces")
    ("predicate def" . "Predicates")
    ("step def" . "Steps")
    ("struct def" . "Structs")
    ("type def" . "Types"))
  "Mapping from definition keywords to imenu category names.")

(defun sysml2-imenu-create-index ()
  "Create a hierarchical imenu index for the current SysML v2 buffer.
Returns an alist suitable for `imenu-create-index-function'."
  (let ((packages nil)
        (categories (make-hash-table :test 'equal))
        (index nil))
    (save-excursion
      (goto-char (point-min))
      ;; Collect packages
      (while (re-search-forward sysml2--imenu-package-re nil t)
        (unless (sysml2--nav-in-comment-or-string-p)
          (push (cons (match-string-no-properties 1)
                      (match-beginning 0))
                packages)))
      ;; Collect definitions
      (goto-char (point-min))
      (while (re-search-forward sysml2--imenu-definition-re nil t)
        (unless (sysml2--nav-in-comment-or-string-p)
          (let* ((full-match (match-string-no-properties 0))
                 (name (sysml2--extract-def-name full-match))
                 (category (sysml2--extract-def-category full-match))
                 (pos (match-beginning 0)))
            (when (and name category)
              (let ((existing (gethash category categories)))
                (puthash category
                         (cons (cons name pos) existing)
                         categories)))))))
    ;; Build the index
    (when packages
      (push (cons "Packages" (nreverse packages)) index))
    (let ((defs nil))
      (maphash (lambda (cat entries)
                 (push (cons cat (nreverse entries)) defs))
               categories)
      (when defs
        (push (cons "Definitions"
                    (sort defs (lambda (a b) (string< (car a) (car b)))))
              index)))
    (nreverse index)))

(defun sysml2--extract-def-name (match-string)
  "Extract the definition name from MATCH-STRING.
MATCH-STRING is the full match of a definition line."
  (when (string-match (concat "\\(" sysml2--identifier-regexp "\\)\\s-*$")
                      (string-trim-right match-string))
    (match-string 1 (string-trim-right match-string))))

(defun sysml2--extract-def-category (match-string)
  "Extract the category name from MATCH-STRING.
Returns the imenu category name or nil."
  (let ((trimmed (string-trim match-string))
        (result nil))
    (dolist (pair sysml2--imenu-category-alist)
      (when (and (not result)
                 (string-match-p (regexp-quote (car pair)) trimmed))
        (setq result (cdr pair))))
    result))

(defun sysml2--nav-in-comment-or-string-p ()
  "Return non-nil if point is inside a comment or string."
  (let ((state (syntax-ppss)))
    (or (nth 3 state) (nth 4 state))))

;; --- Outline ---

(defun sysml2-outline-level ()
  "Compute the outline level of the current line.
Based on indentation: level = indentation / `sysml2-indent-offset' + 1."
  (1+ (/ (current-indentation) sysml2-indent-offset)))

;; --- Which Function ---

(defconst sysml2--defun-re
  (concat "^\\s-*\\(?:"
          (regexp-opt sysml2-visibility-keywords t)
          "\\s-+\\)?"
          "\\(?:package\\|"
          (regexp-opt sysml2-definition-keywords t)
          "\\)"
          "\\s-+\\(" sysml2--identifier-regexp "\\)")
  "Regexp matching definition or package declarations for navigation.")

(defun sysml2-which-function ()
  "Return the name of the innermost enclosing definition or package at point."
  (save-excursion
    (end-of-line)
    (let ((found nil)
          (target-indent (current-indentation))
          (pos (point)))
      ;; Search backward for a definition that encloses this point
      (while (and (not found) (not (bobp)))
        (when (re-search-backward sysml2--defun-re nil t)
          (let ((def-indent (current-indentation))
                (def-name (sysml2--extract-def-name
                           (match-string-no-properties 0))))
            (if (< def-indent target-indent)
                (setq found def-name)
              ;; Same or higher indent — check if this block contains point
              (save-excursion
                (goto-char (match-beginning 0))
                (when (and (re-search-forward "{" nil t)
                           (< (point) pos))
                  (let ((block-start (point)))
                    (goto-char (1- block-start))
                    (condition-case nil
                        (progn
                          (forward-sexp 1)
                          (when (> (point) pos)
                            (setq found def-name)))
                      (scan-error nil)))))))))
      found)))

;; --- Beginning/End of Defun ---

(defun sysml2-beginning-of-defun (&optional arg)
  "Move to the beginning of the current or previous definition.
With ARG, move to the ARGth previous definition."
  (interactive "^p")
  (setq arg (or arg 1))
  (if (> arg 0)
      (dotimes (_ arg)
        (when (re-search-backward sysml2--defun-re nil t)
          (beginning-of-line)))
    (dotimes (_ (- arg))
      (end-of-line)
      (when (re-search-forward sysml2--defun-re nil t)
        (beginning-of-line)))))

(defun sysml2-end-of-defun (&optional arg)
  "Move to the end of the current definition.
With ARG, move forward ARG definitions."
  (interactive "^p")
  (setq arg (or arg 1))
  (dotimes (_ arg)
    ;; First make sure we're at the beginning of a defun
    (unless (looking-at-p sysml2--defun-re)
      (sysml2-beginning-of-defun 1))
    ;; Find the opening brace and skip to matching close
    (when (re-search-forward "{" nil t)
      (backward-char 1)
      (condition-case nil
          (progn
            (forward-sexp 1)
            (forward-line 1))
        (scan-error
         (goto-char (point-max)))))))

;; --- Go to Definition ---

(defun sysml2--search-definition-in-buffer (sym)
  "Search for a definition of SYM in the current buffer.
Returns the position of the match, or nil if not found."
  (let ((def-re (concat "\\b\\(?:"
                        (regexp-opt sysml2-definition-keywords)
                        "\\)\\s-+"
                        (regexp-quote sym)
                        "\\_>"))
        (pkg-re (concat "\\bpackage\\s-+" (regexp-quote sym) "\\_>"))
        (found nil))
    (save-excursion
      (goto-char (point-min))
      (while (and (not found)
                  (re-search-forward def-re nil t))
        (unless (sysml2--nav-in-comment-or-string-p)
          (setq found (match-beginning 0))))
      (unless found
        (goto-char (point-min))
        (while (and (not found)
                    (re-search-forward pkg-re nil t))
          (unless (sysml2--nav-in-comment-or-string-p)
            (setq found (match-beginning 0))))))
    found))

(defun sysml2--search-definition-in-file (file def-re pkg-re)
  "Search FILE for definitions matching DEF-RE and PKG-RE.
Returns a list of (FILE . LINE-NUMBER) for each match found, or nil."
  (let ((hits nil))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (re-search-forward def-re nil t)
        (push (cons file (line-number-at-pos (match-beginning 0))) hits))
      (goto-char (point-min))
      (while (re-search-forward pkg-re nil t)
        (push (cons file (line-number-at-pos (match-beginning 0))) hits)))
    (nreverse hits)))

(defun sysml2--search-definition-in-project (sym)
  "Search all project SysML/KerML files for a definition of SYM.
Returns a list of (FILE . LINE-NUMBER) entries."
  (require 'sysml2-project)
  (let* ((root (sysml2-project-root))
         (files (when root (sysml2-project-find-sysml-files root)))
         (current (buffer-file-name))
         (def-re (concat "\\b\\(?:"
                         (regexp-opt sysml2-definition-keywords)
                         "\\)\\s-+"
                         (regexp-quote sym)
                         "\\_>"))
         (pkg-re (concat "\\bpackage\\s-+" (regexp-quote sym) "\\_>"))
         (results nil))
    (dolist (file files)
      ;; Skip the current buffer's file (already searched)
      (unless (and current (string= (expand-file-name file)
                                    (expand-file-name current)))
        (let ((hits (sysml2--search-definition-in-file
                     file def-re pkg-re)))
          (setq results (nconc results hits)))))
    results))

(defun sysml2--goto-file-line (file line)
  "Open FILE and go to LINE."
  (find-file file)
  (goto-char (point-min))
  (forward-line (1- line))
  (recenter))

(defun sysml2-goto-definition ()
  "Jump to the definition of the identifier at point.
First searches the current buffer for a definition matching the symbol
under the cursor (e.g. `part def NAME', `port def NAME', etc.).
If not found locally, searches all `.sysml' and `.kerml' files in the
project root.  If multiple definitions are found across files, prompts
with `completing-read' to select one.
Pushes the current position onto the mark ring for easy return
with \\[pop-global-mark]."
  (interactive)
  (let ((sym (thing-at-point 'symbol t)))
    (unless sym
      (user-error "No identifier at point"))
    ;; 1. Search the current buffer first (tree-sitter when available)
    (let ((local-pos (if (derived-mode-p 'sysml2-ts-mode)
                         (sysml2-ts--search-definition-in-buffer sym)
                       (sysml2--search-definition-in-buffer sym))))
      (if local-pos
          (progn
            (push-mark nil t)
            (goto-char local-pos)
            (recenter))
        ;; 2. Search project files
        (let ((hits (sysml2--search-definition-in-project sym)))
          (cond
           ((null hits)
            (message "No definition found for `%s'" sym))
           ((= (length hits) 1)
            (push-mark nil t)
            (sysml2--goto-file-line (car (car hits)) (cdr (car hits))))
           (t
            ;; Multiple matches -- let user pick
            (let* ((candidates
                    (mapcar (lambda (hit)
                              (cons (format "%s:%d"
                                           (file-relative-name (car hit))
                                           (cdr hit))
                                    hit))
                            hits))
                   (choice (completing-read
                            (format "Definition of `%s': " sym)
                            (mapcar #'car candidates)
                            nil t))
                   (selected (cdr (assoc choice candidates))))
              (when selected
                (push-mark nil t)
                (sysml2--goto-file-line
                 (car selected) (cdr selected)))))))))))

;; --- Rename Symbol ---

(defun sysml2-rename-symbol ()
  "Rename the symbol at point throughout the current buffer.
Prompts for a new name and replaces all occurrences, skipping
those inside comments and strings.  Only modifies the current
buffer for safety.
When `sysml2-ts-mode' is active, uses tree-sitter for precise
identifier matching instead of regex."
  (interactive)
  (if (derived-mode-p 'sysml2-ts-mode)
      (sysml2-ts--rename-symbol)
    (let ((old-name (thing-at-point 'symbol t)))
      (unless old-name
        (user-error "No symbol at point"))
      (let ((new-name (read-string
                       (format "Rename `%s' to: " old-name)
                       old-name)))
        (when (string-empty-p new-name)
          (user-error "New name must not be empty"))
        (when (string= old-name new-name)
          (user-error "New name is the same as the old name"))
        (let ((count 0)
              (re (concat "\\_<" (regexp-quote old-name) "\\_>")))
          (save-excursion
            (goto-char (point-min))
            (while (re-search-forward re nil t)
              (unless (sysml2--nav-in-comment-or-string-p)
                (replace-match new-name t t)
                (setq count (1+ count)))))
          (message "Renamed `%s' -> `%s' (%d occurrence%s)"
                   old-name new-name count
                   (if (= count 1) "" "s")))))))

;; --- Find References ---

(defvar sysml2-references-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'sysml2--references-goto)
    (define-key map (kbd "o") #'sysml2--references-goto-other)
    (define-key map (kbd "q") #'quit-window)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    map)
  "Keymap for `sysml2-references-mode'.")

(define-derived-mode sysml2-references-mode special-mode "SysML2-Refs"
  "Major mode for displaying SysML v2 reference results."
  :group 'sysml2
  (setq truncate-lines t))

(defun sysml2--references-goto ()
  "Jump to the reference at point."
  (interactive)
  (let ((marker (get-text-property (point) 'sysml2-ref-marker)))
    (when marker
      (let ((buf (marker-buffer marker)))
        (when (buffer-live-p buf)
          (pop-to-buffer buf)
          (goto-char marker)
          (recenter))))))

(defun sysml2--references-goto-other ()
  "Jump to the reference at point in another window."
  (interactive)
  (let ((marker (get-text-property (point) 'sysml2-ref-marker)))
    (when marker
      (let ((buf (marker-buffer marker)))
        (when (buffer-live-p buf)
          (display-buffer buf '((display-buffer-reuse-window
                                 display-buffer-use-some-window)))
          (with-selected-window (get-buffer-window buf)
            (goto-char marker)
            (recenter)))))))

;;;###autoload
(defun sysml2-find-references ()
  "Find all references to the symbol at point in the current buffer.
Displays results in a dedicated buffer with navigation.
Each result shows the line number, context, and the role of the
reference (definition, type reference, usage, etc.)."
  (interactive)
  (let ((sym (thing-at-point 'symbol t)))
    (unless sym
      (user-error "No identifier at point"))
    (let ((re (concat "\\_<" (regexp-quote sym) "\\_>"))
          (results nil)
          (source-buf (current-buffer)))
      ;; Collect all occurrences
      (save-excursion
        (goto-char (point-min))
        (while (re-search-forward re nil t)
          (let ((pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (let* ((line-num (line-number-at-pos pos))
                       (line-text (string-trim
                                   (buffer-substring-no-properties
                                    (line-beginning-position)
                                    (line-end-position))))
                       (role (sysml2--reference-role pos sym))
                       (marker (copy-marker pos)))
                  (push (list :line line-num :text line-text
                              :role role :marker marker)
                        results)))))))
      (setq results (nreverse results))
      (if (null results)
          (message "No references found for `%s'" sym)
        ;; Display results
        (let ((buf (get-buffer-create (format "*SysML Refs: %s*" sym))))
          (with-current-buffer buf
            (let ((inhibit-read-only t))
              (erase-buffer)
              (sysml2-references-mode)
              (insert (propertize (format "References to `%s'" sym)
                                  'face 'bold))
              (insert (format " — %d found in %s\n\n"
                              (length results)
                              (buffer-name source-buf)))
              (dolist (r results)
                (let ((start (point))
                      (line (plist-get r :line))
                      (text (plist-get r :text))
                      (role (plist-get r :role))
                      (marker (plist-get r :marker)))
                  (insert (propertize (format "%4d" line)
                                      'face 'line-number))
                  (insert "  ")
                  (insert (propertize (format "%-12s" role)
                                      'face (pcase role
                                              ("definition" 'sysml2-definition-name-face)
                                              ("type-ref" 'font-lock-type-face)
                                              ("satisfy" 'success)
                                              ("verify" 'success)
                                              (_ 'default))))
                  (insert "  ")
                  ;; Highlight the symbol in the line text
                  (let ((highlighted text)
                        (case-fold-search nil))
                    (when (string-match (regexp-quote sym) highlighted)
                      (setq highlighted
                            (concat (substring highlighted 0 (match-beginning 0))
                                    (propertize (match-string 0 highlighted)
                                                'face 'match)
                                    (substring highlighted (match-end 0)))))
                    (insert highlighted))
                  (insert "\n")
                  (put-text-property start (point) 'sysml2-ref-marker marker)))
              (goto-char (point-min))))
          (display-buffer buf '((display-buffer-reuse-window
                                 display-buffer-below-selected)
                                (window-height . 0.35))))))))

(defun sysml2--reference-role (pos sym)
  "Determine the role of symbol SYM at buffer position POS.
Returns a string like \"definition\", \"type-ref\", \"usage\",
\"satisfy\", \"verify\", \"import\", or \"reference\"."
  (save-excursion
    (goto-char pos)
    (let ((line (buffer-substring-no-properties
                 (line-beginning-position) (line-end-position))))
      (cond
       ;; Definition: "KEYWORD def SYM"
       ((string-match (concat "\\bdef\\s-+" (regexp-quote sym) "\\_>") line)
        "definition")
       ;; Package: "package SYM"
       ((string-match (concat "\\bpackage\\s-+" (regexp-quote sym) "\\_>") line)
        "definition")
       ;; Type reference: ": SYM" or ":> SYM"
       ((string-match (concat ":>?\\s-*" (regexp-quote sym) "\\_>") line)
        "type-ref")
       ;; Satisfy
       ((string-match "\\bsatisfy\\b" line)
        "satisfy")
       ;; Verify
       ((string-match "\\bverify\\b" line)
        "verify")
       ;; Import
       ((string-match "\\bimport\\b" line)
        "import")
       ;; Allocate
       ((string-match "\\ballocat" line)
        "allocate")
       ;; Usage: "KEYWORD SYM" (part, port, attribute, action, state, etc.)
       ((string-match (concat "\\b\\(?:part\\|port\\|attribute\\|action\\|state"
                              "\\|item\\|connection\\|flow\\|constraint"
                              "\\|requirement\\|calc\\|ref\\|enum\\)\\s-+"
                              (regexp-quote sym) "\\_>")
                      line)
        "usage")
       (t "reference")))))

(provide 'sysml2-navigation)
;;; sysml2-navigation.el ends here
