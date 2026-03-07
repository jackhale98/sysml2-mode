;;; sysml2-navigation.el --- Navigation support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/sysml2-mode/sysml2-mode

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

(require 'sysml2-lang)

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

(provide 'sysml2-navigation)
;;; sysml2-navigation.el ends here
