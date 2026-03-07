;;; sysml2-model.el --- Model data extraction for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Regex-based model data extraction from SysML v2 buffer text.
;; Returns structured plists suitable for any diagram backend
;; (SVG, D2, PlantUML) or report generation.
;;
;; This module contains NO diagram-specific code — it only parses
;; SysML v2 textual notation and returns structured data.

;;; Code:

(require 'sysml2-lang)
(require 'sysml2-vars)

;; ---------------------------------------------------------------------------
;; Scoping helper
;; ---------------------------------------------------------------------------

(defun sysml2--model-find-def-bounds (def-keyword name)
  "Find (BEG . END) of the body of DEF-KEYWORD NAME definition.
DEF-KEYWORD is e.g. \"part def\", NAME is the definition name.
Returns nil if not found."
  (save-excursion
    (goto-char (point-min))
    (let ((re (concat "\\b" (regexp-quote def-keyword)
                      "[ \t]+" (regexp-quote name) "\\b")))
      (when (re-search-forward re nil t)
        (let ((def-start (match-beginning 0)))
          (when (re-search-forward "{" nil t)
            (let ((brace-start (1- (point))))
              (goto-char brace-start)
              (condition-case nil
                  (progn
                    (forward-sexp 1)
                    (cons def-start (point)))
                (scan-error nil)))))))))

;; ---------------------------------------------------------------------------
;; Definition extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-typed-defs (def-keyword kind &optional buffer)
  "Extract definitions matching DEF-KEYWORD from BUFFER.
DEF-KEYWORD is e.g. \"port def\", \"interface def\".
KIND is a string tag for the element kind (e.g. \"port\").
Returns list of plists (:name :super :kind :attributes)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\b" (regexp-quote def-keyword) "[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (super (match-string-no-properties 2))
                (match-end (match-end 0))
                (attrs nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq body-end (point)))
                    (scan-error (setq body-end (point-max))))
                  (goto-char (1+ brace-start))
                  (while (re-search-forward
                          (concat "\\battribute[ \t]+"
                                  "\\(" sysml2--identifier-regexp "\\)")
                          (1- body-end) t)
                    (push (match-string-no-properties 1) attrs)))))
            (push (list :name name :super super
                        :kind kind
                        :attributes (nreverse attrs))
                  defs)))
        (nreverse defs)))))

(defun sysml2--model-extract-enum-defs (&optional buffer)
  "Extract enum/enumeration definitions from BUFFER.
Returns list of plists (:name :super :kind :literals)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\b\\(?:enum\\|enumeration\\)[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (super (match-string-no-properties 2))
                (match-end (match-end 0))
                (literals nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq body-end (point)))
                    (scan-error (setq body-end (point-max))))
                  (let ((body (buffer-substring-no-properties
                               (1+ brace-start) (1- body-end))))
                    (goto-char (1+ brace-start))
                    (while (re-search-forward
                            (concat "\\benum[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)")
                            (1- body-end) t)
                      (push (match-string-no-properties 1) literals))
                    (unless literals
                      (let ((trimmed (string-trim body)))
                        (when (string-match-p "^[A-Za-z_]" trimmed)
                          (dolist (part (split-string trimmed "[;\n]+" t))
                            (let ((lit (string-trim part)))
                              (when (string-match
                                     (concat "^\\(" sysml2--identifier-regexp "\\)$")
                                     lit)
                                (push (match-string 1 lit) literals)))))))))))
            (push (list :name name :super super
                        :kind "enumeration"
                        :literals (nreverse literals))
                  defs)))
        (nreverse defs)))))

(defun sysml2--model-extract-part-defs (&optional buffer)
  "Extract part definitions from BUFFER.
Returns list of plists (:name :super :abstract :attributes :parts)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((defs nil)
            (re (concat "\\(?:\\(abstract\\|variation\\)[ \t]+\\)?"
                        "part[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let* ((modifier (match-string-no-properties 1))
                 (name (match-string-no-properties 2))
                 (super (match-string-no-properties 3))
                 (match-end (match-end 0))
                 (attrs nil)
                 (parts nil))
            (save-excursion
              (goto-char match-end)
              (when (re-search-forward "{" (line-end-position 2) t)
                (let ((brace-start (1- (point)))
                      (body-end nil))
                  (goto-char brace-start)
                  (condition-case nil
                      (progn (forward-sexp 1) (setq body-end (point)))
                    (scan-error (setq body-end (point-max))))
                  (let ((beg (1+ brace-start))
                        (end (1- body-end)))
                    (goto-char beg)
                    (while (re-search-forward
                            (concat "\\battribute[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)")
                            end t)
                      (push (match-string-no-properties 1) attrs))
                    (goto-char beg)
                    (while (re-search-forward
                            (concat "\\(?:\\bvariant[ \t]+\\)?\\bpart[ \t]+"
                                    "\\(" sysml2--identifier-regexp "\\)"
                                    "[ \t]*:[ \t]*"
                                    "\\(" sysml2--qualified-name-regexp "\\)"
                                    "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?")
                            end t)
                      (save-excursion
                        (goto-char (match-beginning 0))
                        (unless (looking-at "\\(?:\\bvariant[ \t]+\\)?\\bpart[ \t]+def\\b")
                          (push (list :name (match-string-no-properties 1)
                                      :type (match-string-no-properties 2)
                                      :multiplicity (match-string-no-properties 3))
                                parts))))))))
            (push (list :name name
                        :super super
                        :abstract (when (equal modifier "abstract") t)
                        :attributes (nreverse attrs)
                        :parts (nreverse parts))
                  defs)))
        (nreverse defs)))))

;; ---------------------------------------------------------------------------
;; Usage extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-part-usages (&optional beg end)
  "Extract part usages within region BEG..END.
Returns list of (:name :type :multiplicity)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bpart[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(" sysml2--qualified-name-regexp "\\)"
                      "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bpart[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :type (match-string-no-properties 2)
                        :multiplicity (match-string-no-properties 3))
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-port-usages (&optional beg end)
  "Extract port usages within region BEG..END.
Returns list of (:name :type :conjugated :direction)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bport[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(~?\\)"
                      "\\(" sysml2--qualified-name-regexp "\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bport[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :type (match-string-no-properties 3)
                        :conjugated (string= (match-string-no-properties 2) "~")
                        :direction nil)
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-connections (&optional beg end)
  "Extract connection usages within region BEG..END.
Returns list of (:name :source :target)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bconnection[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "\\(?:[ \t]*:[ \t]*" sysml2--qualified-name-regexp "\\)?"
                      "[ \t\n]*connect[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)"
                      "[ \t]+to[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bconnection[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :source (match-string-no-properties 2)
                        :target (match-string-no-properties 3))
                  results)))))
    (nreverse results)))

;; ---------------------------------------------------------------------------
;; Behavioral extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-states (&optional beg end)
  "Extract state declarations within region BEG..END.
Returns list of (:name)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bstate[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\bstate[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1))
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-transitions (&optional beg end)
  "Extract transitions within region BEG..END.
Returns list of (:name :from :trigger :to)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\btransition[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)")
              end t)
        (let ((name (match-string-no-properties 1))
              (trans-start (match-end 0))
              (from nil) (trigger nil) (to nil))
          (save-excursion
            (goto-char trans-start)
            (let ((search-end (min end (+ trans-start 300))))
              (when (re-search-forward
                     (concat "\\bfirst[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)")
                     search-end t)
                (setq from (match-string-no-properties 1)))
              (goto-char trans-start)
              (when (re-search-forward
                     (concat "\\baccept[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)")
                     search-end t)
                (setq trigger (match-string-no-properties 1)))
              (goto-char trans-start)
              (when (re-search-forward
                     (concat "\\bthen[ \t]+"
                             "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
                     search-end t)
                (setq to (match-string-no-properties 1)))))
          (when (and from to)
            (push (list :name name :from from :trigger trigger :to to)
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-actions (&optional beg end)
  "Extract action usages within region BEG..END.
Returns list of (:name :type)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\baction[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*:[ \t]*"
                      "\\(" sysml2--qualified-name-regexp "\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (looking-at "\\baction[ \t]+def\\b")
            (push (list :name (match-string-no-properties 1)
                        :type (match-string-no-properties 2))
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-successions (&optional beg end)
  "Extract succession relationships (first X then Y) within BEG..END.
Returns list of (:from :to)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bfirst[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]+then[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (let ((line-start (line-beginning-position)))
            (goto-char line-start)
            (unless (looking-at ".*\\btransition\\b")
              (let ((in-transition nil))
                (save-excursion
                  (forward-line -1)
                  (while (and (not (bobp))
                              (looking-at "^[ \t]*$"))
                    (forward-line -1))
                  (when (looking-at ".*\\b\\(transition\\|accept\\)\\b")
                    (setq in-transition t)))
                (unless in-transition
                  (push (list :from (match-string-no-properties 1)
                              :to (match-string-no-properties 2))
                        results))))))))
    (nreverse results)))

;; ---------------------------------------------------------------------------
;; Requirement extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-requirements (&optional buffer)
  "Extract requirement definitions from BUFFER.
Returns list of (:name :doc :subject)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward
                (concat "\\brequirement[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")
                nil t)
          (let ((name (match-string-no-properties 1))
                (match-end (match-end 0))
                (doc nil) (subject nil))
            (save-excursion
              (goto-char match-end)
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
                    (setq doc (string-trim (match-string-no-properties 1))))
                  (goto-char (1+ brace-start))
                  (when (re-search-forward
                         (concat "\\bsubject[ \t]+"
                                 sysml2--identifier-regexp
                                 "[ \t]*:[ \t]*"
                                 "\\(" sysml2--qualified-name-regexp "\\)")
                         body-end t)
                    (setq subject (match-string-no-properties 1))))))
            (push (list :name name :doc doc :subject subject)
                  results)))
        (nreverse results)))))

(defun sysml2--model-extract-requirement-usages (&optional buffer)
  "Extract named requirement usages (not defs) from BUFFER.
Returns list of plists (:name :type :doc :children)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (seen (make-hash-table :test 'equal))
            (re (concat "\\brequirement[ \t]+"
                        "\\(?:<[^>]+>[ \t]+\\)?"
                        "\\(" sysml2--identifier-regexp "\\)")))
        (while (re-search-forward re nil t)
          (let ((match-start (match-beginning 0))
                (name (match-string-no-properties 1))
                (match-end (match-end 0)))
            (save-excursion
              (goto-char match-start)
              (let ((skip nil) (type nil))
                (let ((ppss (save-excursion (syntax-ppss match-start))))
                  (when (or (nth 3 ppss) (nth 4 ppss))
                    (setq skip t)))
                (when (looking-at "\\brequirement[ \t]+def\\b")
                  (setq skip t))
                (unless skip
                  (save-excursion
                    (beginning-of-line)
                    (when (looking-at ".*\\bsatisfy[ \t]")
                      (setq skip t))))
                (unless skip
                  (save-excursion
                    (goto-char match-end)
                    (cond
                     ((looking-at "[ \t]*:>>")
                      (setq skip t))
                     ((looking-at (concat "[ \t]*:>?[ \t]*"
                                          "\\(" sysml2--qualified-name-regexp "\\)"))
                      (setq type (match-string-no-properties 1))))))
                (when (gethash name seen)
                  (setq skip t))
                (unless skip
                  (puthash name t seen)
                  (let ((doc nil) (children nil))
                    (save-excursion
                      (goto-char match-end)
                      (when type
                        (re-search-forward (regexp-quote type) (line-end-position) t))
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
                            (setq doc (string-trim
                                       (match-string-no-properties 1))))
                          (goto-char (1+ brace-start))
                          (let ((child-re
                                 (concat "\\brequirement[ \t]+"
                                         "\\(?:<[^>]+>[ \t]+\\)?"
                                         "\\(" sysml2--identifier-regexp "\\)")))
                            (while (re-search-forward child-re body-end t)
                              (let ((cname (match-string-no-properties 1))
                                    (cend (match-end 0))
                                    (ctype nil) (cdoc nil))
                                (unless (or (save-excursion
                                              (goto-char (match-beginning 0))
                                              (looking-at
                                               "\\brequirement[ \t]+def\\b"))
                                            (save-excursion
                                              (goto-char cend)
                                              (looking-at "[ \t]*:>>")))
                                  (save-excursion
                                    (goto-char cend)
                                    (when (looking-at
                                           (concat "[ \t]*:>?[ \t]*"
                                                   "\\("
                                                   sysml2--qualified-name-regexp
                                                   "\\)"))
                                      (setq ctype
                                            (match-string-no-properties 1))))
                                  (save-excursion
                                    (goto-char cend)
                                    (when (re-search-forward
                                           "{" (line-end-position 2) t)
                                      (let ((cb (1- (point))) cb-end)
                                        (goto-char cb)
                                        (condition-case nil
                                            (progn (forward-sexp 1)
                                                   (setq cb-end (point)))
                                          (scan-error
                                           (setq cb-end (point-max))))
                                        (goto-char (1+ cb))
                                        (when (re-search-forward
                                               "\\bdoc[ \t]+/\\*[ \t]*\\([^*]*\\)\\*/"
                                               cb-end t)
                                          (setq cdoc
                                                (string-trim
                                                 (match-string-no-properties
                                                  1)))))))
                                  (puthash cname t seen)
                                  (push (list :name cname :type ctype
                                              :doc cdoc)
                                        children))))))))
                    (push (list :name name :type type :doc doc
                                :children (nreverse children))
                          results)))))))
        (nreverse results)))))

;; ---------------------------------------------------------------------------
;; Composition extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-usage-compositions (&optional buffer)
  "Extract composition relationships from typed part usages in BUFFER.
Returns list of (:parent-type :child-type :multiplicity)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (seen (make-hash-table :test 'equal))
            (re (concat "\\bpart[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "[ \t]*:[ \t>]*"
                        "\\(" sysml2--qualified-name-regexp "\\)")))
        (while (re-search-forward re nil t)
          (let ((parent-type (match-string-no-properties 2))
                (match-end-pos (match-end 0)))
            (save-excursion
              (goto-char (match-beginning 0))
              (unless (looking-at "\\bpart[ \t]+def\\b")
                (save-excursion
                  (goto-char match-end-pos)
                  (when (re-search-forward "{" (line-end-position 2) t)
                    (let ((brace-start (1- (point)))
                          (body-end nil))
                      (goto-char brace-start)
                      (condition-case nil
                          (progn (forward-sexp 1) (setq body-end (point)))
                        (scan-error (setq body-end (point-max))))
                      (goto-char (1+ brace-start))
                      (while (re-search-forward
                              (concat "\\bpart[ \t]+"
                                      "\\(" sysml2--identifier-regexp "\\)"
                                      "[ \t]*:[ \t]*"
                                      "\\(" sysml2--qualified-name-regexp "\\)"
                                      "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?")
                              body-end t)
                        (save-excursion
                          (goto-char (match-beginning 0))
                          (unless (looking-at "\\bpart[ \t]+def\\b")
                            (let ((depth 0)
                                  (check-pos (match-beginning 0))
                                  (scan-pos (1+ brace-start)))
                              (save-excursion
                                (goto-char scan-pos)
                                (while (< (point) check-pos)
                                  (cond
                                   ((eq (char-after) ?\{)
                                    (cl-incf depth)
                                    (forward-char 1))
                                   ((eq (char-after) ?\})
                                    (cl-decf depth)
                                    (forward-char 1))
                                   (t (forward-char 1)))))
                              (when (= depth 0)
                                (let* ((child-type (match-string-no-properties 2))
                                       (mult (match-string-no-properties 3))
                                       (key (concat parent-type "|" child-type)))
                                  (unless (gethash key seen)
                                    (puthash key t seen)
                                    (push (list :parent-type parent-type
                                                :child-type child-type
                                                :multiplicity mult)
                                          results)))))))))))))))
        (nreverse results)))))

(defun sysml2--model-extract-satisfactions (&optional buffer)
  "Extract satisfy relationships from BUFFER.
Returns list of (:requirement :by)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward
                (concat "\\bsatisfy[ \t]+"
                        "\\(?:requirement[ \t]+\\)?"
                        "\\(" sysml2--qualified-name-regexp "\\)"
                        "[ \t]+by[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)")
                nil t)
          (push (list :requirement (match-string-no-properties 1)
                      :by (match-string-no-properties 2))
                results))
        (nreverse results)))))

;; ---------------------------------------------------------------------------
;; Use case extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-use-cases (&optional buffer)
  "Extract use case definitions and actors from BUFFER.
Returns plist (:use-cases :actors :includes :subjects)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((use-cases nil)
            (actors nil)
            (includes nil)
            (subjects nil)
            (seen-uc (make-hash-table :test 'equal))
            (seen-actor (make-hash-table :test 'equal)))
        (while (re-search-forward
                (concat "\\buse[ \t]+case[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")
                nil t)
          (let ((name (match-string-no-properties 1))
                (pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (unless (gethash name seen-uc)
                  (puthash name t seen-uc)
                  (let ((doc nil) (body-end nil))
                    (when (re-search-forward "[{;]" nil t)
                      (when (eq (char-before) ?\{)
                        (goto-char (1- (point)))
                        (condition-case nil
                            (progn (forward-sexp 1)
                                   (setq body-end (point)))
                          (scan-error nil))
                        (goto-char (1+ (match-beginning 0)))
                        (when (re-search-forward
                               "\\bdoc[ \t]+/\\*\\([^*]*(?:\\*[^/][^*]*)*\\)\\*/"
                               body-end t)
                          (setq doc (string-trim
                                     (match-string-no-properties 1))))
                        (goto-char pos)
                        (when (and body-end
                                   (re-search-forward
                                    (concat "\\bsubject[ \t]+"
                                            "\\(" sysml2--identifier-regexp "\\)"
                                            "[ \t]*:[ \t]*"
                                            "\\(" sysml2--qualified-name-regexp "\\)")
                                    body-end t))
                          (push (list :use-case name
                                      :subject-type
                                      (match-string-no-properties 2))
                                subjects))
                        (goto-char pos)
                        (while (and body-end
                                    (re-search-forward
                                     (concat "\\bactor[ \t]+"
                                             "\\(" sysml2--identifier-regexp "\\)"
                                             "\\(?:[ \t]*\\[.*?\\]\\)?"
                                             "\\(?:[ \t]*:[ \t]*"
                                             "\\(" sysml2--qualified-name-regexp "\\)\\)?")
                                     body-end t))
                          (let ((actor-name (match-string-no-properties 1))
                                (actor-type (match-string-no-properties 2)))
                            (unless (gethash actor-name seen-actor)
                              (puthash actor-name t seen-actor)
                              (push (list :name actor-name :type actor-type)
                                    actors))
                            (push (list :use-case name :actor actor-name)
                                  includes)))
                        (goto-char pos)
                        (while (and body-end
                                    (re-search-forward
                                     (concat "\\binclude[ \t]+use[ \t]+case[ \t]+"
                                             "\\(" sysml2--identifier-regexp "\\)"
                                             "\\(?:[ \t]*:>[ \t]*"
                                             "\\(" sysml2--identifier-regexp "\\)\\)?")
                                     body-end t))
                          (let* ((usage-name (match-string-no-properties 1))
                                 (def-name (match-string-no-properties 2))
                                 (target (or def-name usage-name)))
                            (push (list :from name :to target :rel "include")
                                  includes)))))
                    (push (list :name name :doc doc) use-cases)))))))
        (list :use-cases (nreverse use-cases)
              :actors (nreverse actors)
              :includes (nreverse includes)
              :subjects (nreverse subjects))))))

;; ---------------------------------------------------------------------------
;; Package extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-packages (&optional buffer)
  "Extract package hierarchy and imports from BUFFER.
Returns plist (:packages :imports)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((packages nil)
            (imports nil))
        (while (re-search-forward
                (concat "^\\(\\s-*\\)\\bpackage[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")
                nil t)
          (let ((indent (length (match-string-no-properties 1)))
                (name (match-string-no-properties 2))
                (pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (push (list :name name
                            :level (/ indent sysml2-indent-offset)
                            :pos pos)
                      packages)))))
        (goto-char (point-min))
        (while (re-search-forward
                (concat "\\bimport[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)")
                nil t)
          (let ((target (match-string-no-properties 1))
                (pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (push (list :target target :pos pos) imports)))))
        (list :packages (nreverse packages)
              :imports (nreverse imports))))))

(defun sysml2--model-package-at-pos (pos packages)
  "Find the name of the innermost package enclosing POS from PACKAGES."
  (let ((best nil)
        (best-pos 0))
    (dolist (pkg packages)
      (let ((pkg-pos (plist-get pkg :pos))
            (pkg-name (plist-get pkg :name)))
        (when (and (< pkg-pos pos) (> pkg-pos best-pos))
          (setq best pkg-name best-pos pkg-pos))))
    best))

;; ---------------------------------------------------------------------------
;; Diagram type detection
;; ---------------------------------------------------------------------------

(declare-function sysml2-which-function "sysml2-navigation")

(defun sysml2--model-detect-diagram-type-at-point ()
  "Detect the appropriate diagram type at point.
Returns (TYPE . SCOPE-NAME) where TYPE is a symbol and SCOPE-NAME
may be nil."
  (save-excursion
    (let ((func-name (sysml2-which-function)))
      (cond
       ((and func-name
             (save-excursion
               (re-search-backward
                (concat "\\bstate[ \t]+def[ \t]+"
                        (regexp-quote func-name) "\\b")
                nil t)))
        (cons 'state-machine func-name))
       ((and func-name
             (save-excursion
               (re-search-backward
                (concat "\\baction[ \t]+def[ \t]+"
                        (regexp-quote func-name) "\\b")
                nil t)))
        (cons 'action-flow func-name))
       ((and func-name
             (save-excursion
               (re-search-backward
                (concat "\\buse[ \t]+case[ \t]+def[ \t]+"
                        (regexp-quote func-name) "\\b")
                nil t)))
        (cons 'use-case nil))
       ((and func-name
             (save-excursion
               (re-search-backward
                (concat "\\brequirement[ \t]+def[ \t]+"
                        (regexp-quote func-name) "\\b")
                nil t)))
        (cons 'requirement-tree nil))
       ((and func-name
             (save-excursion
               (re-search-backward
                (concat "\\bpart[ \t]+def[ \t]+"
                        (regexp-quote func-name) "\\b")
                nil t)))
        (cons 'interconnection func-name))
       (t
        (cons 'tree nil))))))

(provide 'sysml2-model)
;;; sysml2-model.el ends here
