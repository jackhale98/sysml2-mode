;;; sysml2-eldoc.el --- ElDoc support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Provides definition and documentation information at point via ElDoc.
;; Shows the definition signature and any `doc' comment for the symbol
;; under the cursor in the echo area.

;;; Code:

(require 'sysml2-lang)
(require 'sysml2-vars)

(declare-function eldoc-message "eldoc")

(defun sysml2--eldoc-find-definition (name)
  "Find the definition line for NAME in the current buffer.
Returns a plist (:keyword :name :specializes :doc :line) or nil."
  (save-excursion
    (goto-char (point-min))
    (let ((re (concat "\\b\\(\\(?:"
                      (regexp-opt (append sysml2-definition-keywords '("package")))
                      "\\)\\)"
                      "\\s-+" (regexp-quote name) "\\b")))
      (when (re-search-forward re nil t)
        (let* ((kw (match-string-no-properties 1))
               (line (line-number-at-pos (match-beginning 0)))
               (specializes nil)
               (doc nil))
          ;; Check for specialization `:>' after name
          (save-excursion
            (when (looking-at "\\s-*:>\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)")
              (setq specializes (match-string-no-properties 1))))
          ;; Check for typing `:' after name
          (save-excursion
            (when (and (not specializes)
                       (looking-at "\\s-*:\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)"))
              (setq specializes (concat ": " (match-string-no-properties 1)))))
          ;; Look for doc comment inside the body
          (save-excursion
            (when (re-search-forward "{" (line-end-position 3) t)
              (let ((body-start (point)))
                (when (re-search-forward
                       "doc\\s-+/\\*\\s-*\\(\\(?:.\\|\n\\)*?\\)\\s-*\\*/"
                       (+ body-start 500) t)
                  (setq doc (string-trim (match-string-no-properties 1)))))))
          (list :keyword kw :name name :specializes specializes
                :doc doc :line line))))))

(defun sysml2--eldoc-symbol-at-point ()
  "Return the SysML identifier at point, or nil."
  (let ((ppss (syntax-ppss)))
    (unless (or (nth 3 ppss) (nth 4 ppss))
      (save-excursion
        (let ((end (progn (skip-chars-forward "A-Za-z0-9_") (point)))
              (beg (progn (skip-chars-backward "A-Za-z0-9_") (point))))
          (when (> end beg)
            (buffer-substring-no-properties beg end)))))))

(defun sysml2--eldoc-keyword-doc (keyword)
  "Return a short documentation string for SysML KEYWORD."
  (cond
   ((string= keyword "part def") "Defines a structural part (block)")
   ((string= keyword "part") "Declares a part usage (instance)")
   ((string= keyword "port def") "Defines a port interface boundary")
   ((string= keyword "port") "Declares a port on a part")
   ((string= keyword "action def") "Defines a behavioral action")
   ((string= keyword "action") "Declares an action usage")
   ((string= keyword "state def") "Defines a state machine")
   ((string= keyword "state") "Declares a state in a state machine")
   ((string= keyword "connection def") "Defines a connection type")
   ((string= keyword "connect") "Creates a connection between parts/ports")
   ((string= keyword "attribute def") "Defines an attribute type")
   ((string= keyword "attribute") "Declares an attribute (property)")
   ((string= keyword "item def") "Defines an item type (flows through ports)")
   ((string= keyword "item") "Declares an item usage")
   ((string= keyword "requirement def") "Defines a system requirement")
   ((string= keyword "constraint def") "Defines a constraint expression")
   ((string= keyword "enum def") "Defines an enumeration")
   ((string= keyword "interface def") "Defines a binary interface type")
   ((string= keyword "flow def") "Defines a flow connection type")
   ((string= keyword "allocation def") "Defines an allocation relationship")
   ((string= keyword "use case def") "Defines a use case scenario")
   ((string= keyword "verification def") "Defines a verification case")
   ((string= keyword "analysis def") "Defines an analysis case")
   ((string= keyword "view def") "Defines a model view/filter")
   ((string= keyword "viewpoint def") "Defines stakeholder viewpoint concerns")
   ((string= keyword "calc def") "Defines a calculation (function)")
   ((string= keyword "package") "Defines a namespace/package")
   ((string= keyword "import") "Imports elements from another package")
   ((string= keyword "satisfy") "Satisfies a requirement by an element")
   ((string= keyword "verify") "Verifies a requirement via test case")
   ((string= keyword "transition") "Defines a state transition")
   ((string= keyword "exhibit") "Exhibits a state machine behavior")
   ((string= keyword "bind") "Creates a binding connector (equality)")
   ((string= keyword "first") "Defines succession: first A then B")
   ((string= keyword "assign") "Assigns a value to a feature")
   ((string= keyword "assert") "Asserts a constraint must hold")
   ((string= keyword "assume") "Assumes a constraint is true (precondition)")
   ((string= keyword "require") "Adds a constraint requirement")
   ((string= keyword "subject") "Declares the subject of a requirement/use case")
   ((string= keyword "actor") "Declares an actor in a use case")
   ((string= keyword "objective") "Declares the verification objective")
   ((string= keyword "doc") "Inline documentation comment")
   (t nil)))

(defun sysml2--eldoc-function (callback &rest _)
  "ElDoc documentation function for SysML v2.
Calls CALLBACK with documentation for the symbol at point."
  (let* ((sym (sysml2--eldoc-symbol-at-point))
         (result nil))
    (when sym
      ;; First: check if it's a keyword on the current line
      (save-excursion
        (beginning-of-line)
        (let ((line (buffer-substring-no-properties
                     (point) (line-end-position))))
          ;; Check multi-word keywords first
          (dolist (kw sysml2-definition-keywords)
            (when (and (not result)
                       (string-match-p (concat "\\b" (regexp-quote kw) "\\b") line)
                       (let ((parts (split-string kw " ")))
                         (member sym parts)))
              (let ((doc (sysml2--eldoc-keyword-doc kw)))
                (when doc
                  (setq result (format "%s — %s" kw doc))))))))
      ;; Check single-word keywords
      (unless result
        (let ((doc (sysml2--eldoc-keyword-doc sym)))
          (when doc
            (setq result (format "%s — %s" sym doc)))))
      ;; Then: look for a definition of this name
      (unless result
        (let ((def-info (sysml2--eldoc-find-definition sym)))
          (when def-info
            (let ((kw (plist-get def-info :keyword))
                  (name (plist-get def-info :name))
                  (spec (plist-get def-info :specializes))
                  (doc (plist-get def-info :doc))
                  (line (plist-get def-info :line)))
              (setq result
                    (concat
                     (propertize kw 'face 'font-lock-keyword-face)
                     " "
                     (propertize name 'face 'font-lock-function-name-face)
                     (when spec (format " :> %s" spec))
                     (format " [line %d]" line)
                     (when doc (format " — %s" doc)))))))))
    (when result
      (funcall callback result)))
  t)

(defun sysml2-eldoc-setup ()
  "Set up ElDoc support for the current SysML v2 buffer."
  (add-hook 'eldoc-documentation-functions #'sysml2--eldoc-function nil t))

(provide 'sysml2-eldoc)
;;; sysml2-eldoc.el ends here
