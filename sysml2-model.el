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

(require 'cl-lib)
(require 'sysml2-lang)
(require 'sysml2-vars)

;; ---------------------------------------------------------------------------
;; Scoping helper
;; ---------------------------------------------------------------------------

(defun sysml2--model-find-def-bounds (def-keyword name)
  "Find (BEG . END) of the body of DEF-KEYWORD NAME definition.
DEF-KEYWORD is e.g. \"part def\", NAME is the definition name.
Returns nil if not found.  Returns nil for forward declarations
\(semicolon-terminated defs without a body)."
  (save-excursion
    (goto-char (point-min))
    (let ((re (concat "\\b" (regexp-quote def-keyword)
                      "[ \t]+" (regexp-quote name) "\\b")))
      (when (re-search-forward re nil t)
        (let ((def-start (match-beginning 0)))
          ;; Look for `{' on this line or next, but stop at `;'
          (when (re-search-forward "[{;]" (line-end-position 3) t)
            (when (eq (char-before) ?\{)
              (let ((brace-start (1- (point))))
                (goto-char brace-start)
                (condition-case nil
                    (progn
                      (forward-sexp 1)
                      (cons def-start (point)))
                  (scan-error nil))))))))))

(defun sysml2--model-find-exhibit-state-bounds (name)
  "Find (BEG . END) of `exhibit state NAME { ... }' block.
Falls back to `state NAME { ... }' inside a part def body.
Returns nil if not found."
  (save-excursion
    (goto-char (point-min))
    (let ((re (concat "\\bexhibit[ \t]+state[ \t]+"
                      (regexp-quote name)
                      "\\b")))
      (when (re-search-forward re nil t)
        (let ((match-end (match-end 0)))
          ;; Skip optional modifiers like "parallel", "redefines ..."
          (goto-char match-end)
          (skip-chars-forward " \t")
          (while (looking-at "[a-zA-Z]")
            (forward-word 1)
            (skip-chars-forward " \t"))
          (when (looking-at "{")
            (let ((brace-start (point)))
              (condition-case nil
                  (progn
                    (forward-sexp 1)
                    (cons brace-start (point)))
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
                                    "[ \t]*:[ \t>]*"
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
                      "[ \t]*:[ \t>]*"
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
                      "[ \t]*:[ \t>]*"
                      "\\(~?\\)[ \t]*"
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
Matches both named connections (`connection NAME connect SOURCE to TARGET')
and standalone connect statements (`connect SOURCE to TARGET').
Returns list of (:name :source :target)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      ;; Named: connection NAME [: Type] connect SOURCE to TARGET
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
                  results))))
      ;; Standalone: connect [MULT] SOURCE to [MULT] TARGET
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bconnect[ \t]+"
                      "\\(?:\\[[^]]*\\][ \t]*\\)?"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)"
                      "\\(?:[ \t]*::>[^\n]*?\\)?"
                      "[ \t]+to[ \t]+"
                      "\\(?:\\[[^]]*\\][ \t]*\\)?"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          ;; Skip if preceded by "connection" (already captured above)
          (unless (save-excursion
                    (beginning-of-line)
                    (looking-at (concat ".*\\bconnection[ \t]+"
                                        sysml2--identifier-regexp)))
            (unless (let ((ppss (syntax-ppss)))
                      (or (nth 3 ppss) (nth 4 ppss)))
              (push (list :name ""
                          :source (match-string-no-properties 1)
                          :target (match-string-no-properties 2))
                    results))))))
    (nreverse results)))

(defun sysml2--model-extract-flows (&optional beg end)
  "Extract flow usages within region BEG..END.
Returns list of (:name :type :source :target)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bflow[ \t]+"
                      "\\(?:\\(" sysml2--identifier-regexp "\\)[ \t]+\\)?"
                      "\\(?:of[ \t]+\\(" sysml2--qualified-name-regexp "\\)[ \t]+\\)?"
                      "from[ \t]+\\([A-Za-z_][A-Za-z0-9_.]*\\)"
                      "[ \t]+to[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)")
              end t)
        (unless (let ((ppss (syntax-ppss)))
                  (or (nth 3 ppss) (nth 4 ppss)))
          (push (list :name (or (match-string-no-properties 1) "")
                      :type (match-string-no-properties 2)
                      :source (match-string-no-properties 3)
                      :target (match-string-no-properties 4))
                results))))
    (nreverse results)))

(defun sysml2--model-extract-bindings (&optional beg end)
  "Extract bind connectors within region BEG..END.
Returns list of (:source :target)."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bbind[ \t]+"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)"
                      "[ \t]*=[ \t]*"
                      "\\([A-Za-z_][A-Za-z0-9_.]*\\)")
              end t)
        (unless (let ((ppss (syntax-ppss)))
                  (or (nth 3 ppss) (nth 4 ppss)))
          (push (list :source (match-string-no-properties 1)
                      :target (match-string-no-properties 2))
                results))))
    (nreverse results)))

;; ---------------------------------------------------------------------------
;; Behavioral extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-states (&optional beg end)
  "Extract state declarations within region BEG..END.
Matches both `state NAME;' and `state NAME { ... }'.
Returns list of (:name :entry :do :exit) where the action fields
are the action name strings or nil."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward
              (concat "\\bstate[ \t]+"
                      "\\(" sysml2--identifier-regexp "\\)"
                      "[ \t]*\\([;{]\\)")
              end t)
        (save-excursion
          (goto-char (match-beginning 0))
          (unless (or (looking-at "\\bstate[ \t]+def\\b")
                      (save-excursion
                        (beginning-of-line)
                        (looking-at ".*\\bexhibit[ \t]+state\\b")))
            (let ((name (match-string-no-properties 1))
                  (delim (match-string-no-properties 2))
                  (entry-act nil) (do-act nil) (exit-act nil))
              ;; If state has a body, extract entry/do/exit actions
              (when (string= delim "{")
                (let ((body-start (match-end 0))
                      (body-end (save-excursion
                                  (goto-char (1- (match-end 0)))
                                  (condition-case nil
                                      (progn (forward-sexp 1) (point))
                                    (scan-error end)))))
                  (save-excursion
                    (goto-char body-start)
                    (when (re-search-forward
                           (concat "\\bentry[ \t]+\\(?:action[ \t]+\\)?"
                                   "\\(" sysml2--identifier-regexp "\\)")
                           body-end t)
                      (setq entry-act (match-string-no-properties 1))))
                  (save-excursion
                    (goto-char body-start)
                    (when (re-search-forward
                           (concat "\\bdo[ \t]+\\(?:action[ \t]+\\)?"
                                   "\\(" sysml2--identifier-regexp "\\)")
                           body-end t)
                      (setq do-act (match-string-no-properties 1))))
                  (save-excursion
                    (goto-char body-start)
                    (when (re-search-forward
                           (concat "\\bexit[ \t]+\\(?:action[ \t]+\\)?"
                                   "\\(" sysml2--identifier-regexp "\\)")
                           body-end t)
                      (setq exit-act (match-string-no-properties 1))))))
              (push (list :name name :entry entry-act
                          :do do-act :exit exit-act)
                    results))))))
    (nreverse results)))

(defun sysml2--model-extract-initial-state (&optional beg end)
  "Extract the initial state name from an `entry; then STATE;' pattern.
Searches within region BEG..END.  Also handles `entry action NAME;'
followed by `transition NAME then STATE;' (pseudo-initial state).
Returns the initial state name string, or nil."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max))))
    (save-excursion
      (goto-char beg)
      ;; First: try "entry; then STATE;"
      (if (re-search-forward
           (concat "\\bentry;[ \t]*then[ \t]+"
                   "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
           end t)
          (match-string-no-properties 1)
        ;; Second: try "entry action NAME;" + "transition NAME then STATE;"
        (goto-char beg)
        (when (re-search-forward
               (concat "\\bentry[ \t]+action[ \t]+"
                       "\\(" sysml2--identifier-regexp "\\)[ \t]*;")
               end t)
          (let ((pseudo-name (match-string-no-properties 1)))
            (goto-char beg)
            (when (re-search-forward
                   (concat "\\btransition[ \t]+"
                           (regexp-quote pseudo-name)
                           "[ \t]+then[ \t]+"
                           "\\(" sysml2--identifier-regexp "\\)")
                   end t)
              (match-string-no-properties 1))))))))

(defun sysml2--model-extract-transitions (&optional beg end)
  "Extract transitions within region BEG..END.
Handles both shorthand (`transition FROM then TO;') and full form
\(`transition NAME first FROM [accept TRIGGER] [if GUARD] [do EFFECT] then TO;').
Returns list of (:name :from :trigger :guard :effect :to)."
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
              (from nil) (trigger nil) (guard nil) (effect nil) (to nil))
          (save-excursion
            (goto-char trans-start)
            (let ((search-end (min end (+ trans-start 500))))
              ;; Check for shorthand: transition FROM then TO;
              (if (looking-at (concat "[ \t]+then[ \t]+"
                                      "\\(" sysml2--identifier-regexp "\\)"))
                  (progn
                    (setq from name)
                    (setq to (match-string-no-properties 1))
                    (setq name (concat from "_to_" to)))
                ;; Full form: transition NAME first FROM [accept TRIGGER]
                ;;   [if GUARD] [do EFFECT] then TO;
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
                       "\\bif[ \t]+\\(.+?\\)[ \t]*\\(?:\\bthen\\b\\|\\bdo\\b\\|;\\)"
                       search-end t)
                  (setq guard (string-trim (match-string-no-properties 1))))
                (goto-char trans-start)
                (when (re-search-forward
                       (concat "\\bdo[ \t]+\\(?:send[ \t]+\\)?"
                               "\\(.+?\\)[ \t]*\\(?:\\bthen\\b\\|;\\)")
                       search-end t)
                  (setq effect (string-trim (match-string-no-properties 1))))
                (goto-char trans-start)
                (when (re-search-forward
                       (concat "\\bthen[ \t]+"
                               "\\(" sysml2--identifier-regexp "\\)")
                       search-end t)
                  (setq to (match-string-no-properties 1))))))
          (when (and from to)
            (push (list :name name :from from :trigger trigger
                        :guard guard :effect effect :to to)
                  results)))))
    (nreverse results)))

(defun sysml2--model-extract-actions (&optional beg end)
  "Extract action usages within region BEG..END.
Returns list of (:name :type).  Matches:
  action NAME : TYPE ...
  action NAME ;
  action NAME { ... }
  perform action NAME ;
Actions without an explicit type get :type nil."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (re (concat "\\(?:\\bperform[ \t]+\\)?\\baction[ \t]+"
                     "\\(" sysml2--identifier-regexp "\\)"))
        (results nil))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward re end t)
        (let ((name (match-string-no-properties 1))
              (after (match-end 0)))
          (save-excursion
            (goto-char (match-beginning 0))
            ;; Skip `action def` declarations
            (unless (looking-at ".*\\baction[ \t]+def\\b")
              ;; Try to find a type annotation after the name
              (goto-char after)
              (let ((typ nil))
                (when (looking-at (concat "[ \t]*:[ \t>]*"
                                          "\\(" sysml2--qualified-name-regexp "\\)"))
                  (setq typ (match-string-no-properties 1)))
                (push (list :name name :type typ) results)))))))
    (nreverse results)))

(defun sysml2--model-extract-successions (&optional beg end)
  "Extract succession relationships (first X then Y) within BEG..END.
Returns list of (:from :to).
Skips `first ... then' that appear inside a transition statement.
A transition statement runs from the `transition' keyword to the
next semicolon, so we detect this by scanning backward from the
match for a `transition' keyword without crossing a `;', `{', or
`}' boundary."
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
        (let ((from (match-string-no-properties 1))
              (to (match-string-no-properties 2))
              (match-start (match-beginning 0))
              (in-transition nil))
          (save-excursion
            (goto-char match-start)
            ;; Scan backward for `transition' keyword; stop at statement
            ;; boundaries (`;', `{', `}') or buffer beginning.
            (let ((done nil))
              (while (not done)
                (if (re-search-backward "[;{}]\\|\\btransition\\b" beg t)
                    (cond
                     ;; Hit a statement boundary — not inside a transition
                     ((memq (char-after) '(?\; ?{ ?}))
                      (setq done t))
                     ;; Found `transition' keyword before any boundary
                     ((looking-at "\\btransition\\b")
                      (setq in-transition t
                            done t))
                     (t (setq done t)))
                  ;; Reached beg without finding anything
                  (setq done t)))))
          (unless in-transition
            (push (list :from from :to to) results)))))
    (nreverse results)))

(defun sysml2--model-extract-control-nodes (&optional beg end)
  "Extract fork, join, merge, and decide nodes within BEG..END.
Returns list of (:name :kind) where :kind is fork, join, merge, or decide."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max)))
        (results nil)
        (re (concat "\\b\\(fork\\|join\\|merge\\|decide\\)[ \t]+"
                    "\\(" sysml2--identifier-regexp "\\)[ \t]*;")))
    (save-excursion
      (goto-char beg)
      (while (re-search-forward re end t)
        (let ((kind (intern (match-string-no-properties 1)))
              (name (match-string-no-properties 2)))
          (push (list :name name :kind kind) results))))
    (nreverse results)))

(defun sysml2--model-extract-port-usages-for-def (def-name)
  "Extract port usages from the definition named DEF-NAME.
Searches for `part def DEF-NAME', `port def DEF-NAME', etc.
Returns list of (:name :type :direction :conjugated)."
  (let ((bounds (or (sysml2--model-find-def-bounds "part def" def-name)
                    (sysml2--model-find-def-bounds "port def" def-name))))
    (when bounds
      (sysml2--model-extract-port-usages (car bounds) (cdr bounds)))))

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
                        "\\(?:<'\\([^']+\\)'>[ \t]+\\)?"
                        "\\(" sysml2--identifier-regexp "\\)")))
        (while (re-search-forward re nil t)
          (let ((match-start (match-beginning 0))
                (req-id (match-string-no-properties 1))
                (name (match-string-no-properties 2))
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
                                         "\\(?:<'\\([^']+\\)'>[ \t]+\\)?"
                                         "\\(" sysml2--identifier-regexp "\\)")))
                            (while (re-search-forward child-re body-end t)
                              (let ((cid (match-string-no-properties 1))
                                    (cname (match-string-no-properties 2))
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
                                              :doc cdoc :id cid)
                                        children))))))))
                    (push (list :name name :type type :doc doc
                                :id req-id
                                :children (nreverse children))
                          results)))))))
        (nreverse results)))))

;; ---------------------------------------------------------------------------
;; Composition extractors
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-usage-compositions (&optional buffer)
  "Extract composition relationships from typed part usages in BUFFER.
Also extracts compositions from part def bodies (part NAME : TYPE
inside a part def block).
Returns list of (:parent-type :child-type :multiplicity)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (seen (make-hash-table :test 'equal))
            (child-re (concat "\\bpart[ \t]+"
                              "\\(" sysml2--identifier-regexp "\\)"
                              "[ \t]*:[ \t>]*"
                              "\\(" sysml2--qualified-name-regexp "\\)"
                              "\\(?:[ \t]*\\[\\([^]]+\\)\\]\\)?"))
            (re (concat "\\bpart[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "[ \t]*:[ \t>]*"
                        "\\(" sysml2--qualified-name-regexp "\\)")))
        ;; Pass 1: compositions inside part usages (e.g. part v : Vehicle { part e : Engine; })
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
                      (while (re-search-forward child-re body-end t)
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
        ;; Pass 2: compositions inside part def bodies
        (goto-char (point-min))
        (let ((def-re (concat "\\bpart[ \t]+def[ \t]+"
                              "\\(" sysml2--identifier-regexp "\\)")))
          (while (re-search-forward def-re nil t)
            (let ((def-name (match-string-no-properties 1))
                  (def-end (match-end 0)))
              (save-excursion
                (goto-char def-end)
                (when (re-search-forward "{" (line-end-position 3) t)
                  (let ((brace-start (1- (point)))
                        (body-end nil))
                    (goto-char brace-start)
                    (condition-case nil
                        (progn (forward-sexp 1) (setq body-end (point)))
                      (scan-error (setq body-end (point-max))))
                    (goto-char (1+ brace-start))
                    (while (re-search-forward child-re body-end t)
                      (save-excursion
                        (goto-char (match-beginning 0))
                        (unless (looking-at "\\bpart[ \t]+def\\b")
                          (let* ((child-type (match-string-no-properties 2))
                                 (mult (match-string-no-properties 3))
                                 (key (concat def-name "|" child-type)))
                            (unless (gethash key seen)
                              (puthash key t seen)
                              (push (list :parent-type def-name
                                          :child-type child-type
                                          :multiplicity mult)
                                    results))))))))))))
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

(defun sysml2--model-extract-verifications (&optional buffer)
  "Extract verify relationships from BUFFER.
Returns list of (:requirement :by).  Searches inside `verification'
blocks for `verify [requirement] NAME' statements."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (verif-re (concat "\\bverification[ \t]+"
                              "\\(" sysml2--identifier-regexp "\\)"))
            (verify-re (concat "\\bverify[ \t]+\\(?:requirement[ \t]+\\)?"
                               "\\(" sysml2--qualified-name-regexp "\\)")))
        ;; Find verification usages with bodies
        (while (re-search-forward verif-re nil t)
          (unless (let ((ppss (syntax-ppss)))
                    (or (nth 3 ppss) (nth 4 ppss)))
            (let ((verif-name (match-string-no-properties 1))
                  (block-end nil)
                  (search-start (match-end 0)))
              ;; Find the opening brace for this verification block
              (when (re-search-forward "{" (line-end-position 3) t)
                (goto-char (1- (point)))
                (condition-case nil
                    (progn (forward-sexp 1) (setq block-end (point)))
                  (scan-error (setq block-end (point-max))))
                (save-excursion
                  (goto-char search-start)
                  (while (re-search-forward verify-re block-end t)
                    (push (list :requirement (match-string-no-properties 1)
                                :by verif-name)
                          results)))))))
        (nreverse results)))))

(defun sysml2--model-extract-allocations (&optional buffer)
  "Extract allocate relationships from BUFFER.
Returns list of (:source :target)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (re (concat "\\ballocate[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)"
                        "[ \t]+to[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)")))
        (while (re-search-forward re nil t)
          (unless (let ((ppss (syntax-ppss)))
                    (or (nth 3 ppss) (nth 4 ppss)))
            (push (list :source (match-string-no-properties 1)
                        :target (match-string-no-properties 2))
                  results)))
        (nreverse results)))))

(defun sysml2--model-extract-derivations (&optional buffer)
  "Extract derive relationships from BUFFER.
Returns list of (:original :derived) plists.
Matches `#derivation connection { end #original ::> A; end #derive ::> B; }'."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (re "#derivation[ \t]+connection[ \t]*{"))
        (while (re-search-forward re nil t)
          (unless (let ((ppss (syntax-ppss)))
                    (or (nth 3 ppss) (nth 4 ppss)))
            (let ((block-start (match-end 0))
                  (block-end nil)
                  (original nil) (derived nil))
              (goto-char (1- (match-end 0)))
              (condition-case nil
                  (progn (forward-sexp 1) (setq block-end (point)))
                (scan-error (setq block-end (point-max))))
              (save-excursion
                (goto-char block-start)
                (when (re-search-forward
                       (concat "#original[ \t]+::>[ \t]+"
                               "\\(" sysml2--qualified-name-regexp "\\)")
                       block-end t)
                  (setq original (match-string-no-properties 1))))
              (save-excursion
                (goto-char block-start)
                (when (re-search-forward
                       (concat "#derive[ \t]+::>[ \t]+"
                               "\\(" sysml2--qualified-name-regexp "\\)")
                       block-end t)
                  (setq derived (match-string-no-properties 1))))
              (when (and original derived)
                (push (list :original original :derived derived) results)))))
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
;; Calc extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-calcs (&optional buffer)
  "Extract calc def declarations from BUFFER.
Returns list of plists (:name :params :return-name :return-type)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward
                (concat "\\bcalc[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")
                nil t)
          (let ((name (match-string-no-properties 1))
                (pos (match-beginning 0))
                (params nil)
                (ret-name nil)
                (ret-type nil))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                ;; Find the body
                (when (re-search-forward "{" (line-end-position 3) t)
                  (let ((body-start (point))
                        (body-end nil))
                    (goto-char (1- (point)))
                    (condition-case nil
                        (progn (forward-sexp 1)
                               (setq body-end (point)))
                      (scan-error nil))
                    (when body-end
                      ;; Extract in parameters
                      (goto-char body-start)
                      (while (re-search-forward
                              (concat "\\bin[ \t]+"
                                      "\\(" sysml2--identifier-regexp "\\)"
                                      "\\(?:[ \t]*:>?[ \t]*"
                                      "\\(" sysml2--qualified-name-regexp "\\)\\)?")
                              body-end t)
                        (push (list :name (match-string-no-properties 1)
                                    :type (match-string-no-properties 2))
                              params))
                      ;; Extract return
                      (goto-char body-start)
                      (when (re-search-forward
                             (concat "\\breturn[ \t]+"
                                     "\\(?:attribute[ \t]+\\)?"
                                     "\\(" sysml2--identifier-regexp "\\)"
                                     "\\(?:[ \t]*:>?[ \t]*"
                                     "\\(" sysml2--qualified-name-regexp "\\)\\)?")
                             body-end t)
                        (setq ret-name (match-string-no-properties 1))
                        (setq ret-type (match-string-no-properties 2))))))
                (push (list :name name
                            :params (nreverse params)
                            :return-name ret-name
                            :return-type ret-type)
                      results)))))
        (nreverse results)))))

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
;; Analysis extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-analyses (&optional buffer)
  "Extract analysis usages and defs from BUFFER.
Returns list of plists (:name :type :subject :objective :params)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (re (concat "\\banalysis[ \t]+"
                        "\\(?:def[ \t]+\\)?"
                        "\\(" sysml2--identifier-regexp "\\)"
                        "\\(?:[ \t]*:>?[ \t]*"
                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (type (match-string-no-properties 2))
                (pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (let ((subject nil) (objective nil) (params nil))
                  (when (re-search-forward "{" (line-end-position 3) t)
                    (let ((body-start (point))
                          (body-end nil))
                      (goto-char (1- (point)))
                      (condition-case nil
                          (progn (forward-sexp 1) (setq body-end (point)))
                        (scan-error (setq body-end (point-max))))
                      (when body-end
                        ;; Extract subject
                        (goto-char body-start)
                        (when (re-search-forward
                               (concat "\\bsubject\\b[= \t]+"
                                       "\\(" sysml2--qualified-name-regexp "\\)")
                               body-end t)
                          (setq subject (match-string-no-properties 1)))
                        ;; Extract objective
                        (goto-char body-start)
                        (when (re-search-forward
                               (concat "\\bobjective[ \t]+"
                                       "\\(" sysml2--identifier-regexp "\\)")
                               body-end t)
                          (setq objective (match-string-no-properties 1)))
                        ;; Extract in parameters
                        (goto-char body-start)
                        (while (re-search-forward
                                (concat "\\bin[ \t]+"
                                        "\\(?:attribute[ \t]+\\)?"
                                        "\\(" sysml2--identifier-regexp "\\)"
                                        "\\(?:[ \t]*:>?[ \t]*"
                                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")
                                body-end t)
                          (push (list :name (match-string-no-properties 1)
                                      :type (match-string-no-properties 2))
                                params)))))
                  (push (list :name name :type type
                              :subject subject :objective objective
                              :params (nreverse params))
                        results))))))
        (nreverse results)))))

;; ---------------------------------------------------------------------------
;; Constraint extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-constraints (&optional buffer)
  "Extract constraint definitions from BUFFER.
Returns list of plists (:name :params :expression)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (re (concat "\\bconstraint[ \t]+def[ \t]+"
                        "\\(" sysml2--identifier-regexp "\\)")))
        (while (re-search-forward re nil t)
          (let ((name (match-string-no-properties 1))
                (pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (let ((params nil) (expr nil))
                  (when (re-search-forward "{" (line-end-position 3) t)
                    (let ((body-start (point))
                          (body-end nil))
                      (goto-char (1- (point)))
                      (condition-case nil
                          (progn (forward-sexp 1) (setq body-end (point)))
                        (scan-error (setq body-end (point-max))))
                      (when body-end
                        ;; Extract in parameters
                        (goto-char body-start)
                        (while (re-search-forward
                                (concat "\\bin[ \t]+"
                                        "\\(" sysml2--identifier-regexp "\\)"
                                        "\\(?:[ \t]*:>?[ \t]*"
                                        "\\(" sysml2--qualified-name-regexp "\\)\\)?")
                                body-end t)
                          (push (list :name (match-string-no-properties 1)
                                      :type (match-string-no-properties 2))
                                params))
                        ;; Extract constraint expression (last non-param line)
                        (goto-char body-start)
                        (let ((last-expr nil))
                          (while (re-search-forward
                                  "^[ \t]*\\([a-zA-Z_][^ \t\n]*.*[<>=!]+.*\\);[ \t]*$"
                                  body-end t)
                            (setq last-expr
                                  (string-trim (match-string-no-properties 1))))
                          (setq expr last-expr)))))
                  (push (list :name name
                              :params (nreverse params)
                              :expression expr)
                        results))))))
        (nreverse results)))))

;; ---------------------------------------------------------------------------
;; Refinement extractor
;; ---------------------------------------------------------------------------

(defun sysml2--model-extract-refinements (&optional buffer)
  "Extract refinement dependency statements from BUFFER.
Matches `#refinement dependency NAME to TARGET;'.
Returns list of plists (:name :target)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil)
            (re (concat "#refinement[ \t]+dependency[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)"
                        "[ \t]+to[ \t]+"
                        "\\(" sysml2--qualified-name-regexp "\\)[ \t]*;")))
        (while (re-search-forward re nil t)
          (unless (let ((ppss (syntax-ppss)))
                    (or (nth 3 ppss) (nth 4 ppss)))
            (push (list :name (match-string-no-properties 1)
                        :target (match-string-no-properties 2))
                  results)))
        (nreverse results)))))

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
