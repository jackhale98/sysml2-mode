;;; sysml2-completion.el --- Completion support for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Completion-at-point-functions (CAPF) backend for SysML v2.
;; Provides context-aware completion based on cursor position.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-completion-at-point' -- CAPF backend for SysML v2

(require 'sysml2-lang)

(defun sysml2--completion-context ()
  "Determine the completion context at point.
Returns one of: `line-start', `after-colon', `after-specialization',
`after-redefinition', `after-import', `after-modifier', `after-hash',
`after-connect', `after-to', `after-satisfy-by', `in-block', `general'."
  (save-excursion
    (let ((case-fold-search nil)
          (line-start (line-beginning-position)))
      (cond
       ;; Inside a comment or string
       ((nth 4 (syntax-ppss)) nil)
       ((nth 3 (syntax-ppss)) nil)

       ;; After # (metadata)
       ((looking-back "#\\([A-Za-z_]*\\)" line-start)
        'after-hash)

       ;; After "connect" keyword — suggest connectable elements
       ((looking-back "\\bconnect\\s-+\\([A-Za-z0-9_.]*\\)" line-start)
        'after-connect)

       ;; After "to" in connection context — suggest target elements
       ((looking-back "\\bto\\s-+\\([A-Za-z0-9_.]*\\)" line-start)
        'after-to)

       ;; After "satisfy ... by" — suggest parts that can satisfy
       ((looking-back "\\bby\\s-+\\([A-Za-z0-9_.]*\\)" line-start)
        'after-satisfy-by)

       ;; After import keyword
       ((looking-back "\\bimport\\s-+\\([A-Za-z_:.*]*\\)" line-start)
        'after-import)

       ;; After :>> (redefinition)
       ((looking-back ":>>\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-redefinition)

       ;; After :> (specialization)
       ((looking-back ":>\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-specialization)

       ;; After : (type position) — not :: or :> or :>>
       ((looking-back ":\\(?:[^:>]\\|^\\)\\s-*\\([A-Za-z_:]*\\)" line-start)
        'after-colon)

       ;; After in/out/inout modifier
       ((looking-back "\\b\\(?:in\\|out\\|inout\\)\\s-+\\([A-Za-z_]*\\)" line-start)
        'after-modifier)

       ;; Beginning of line (possibly after whitespace or visibility)
       ((looking-back "^\\s-*\\(?:public\\s-+\\|private\\s-+\\|protected\\s-+\\)?\\([A-Za-z_]*\\)" line-start)
        'line-start)

       ;; Default
       (t 'general)))))

(defun sysml2--buffer-definition-names ()
  "Extract all definition names from the current buffer.
Scans for patterns like `KEYWORD def NAME' and returns a list of NAME strings."
  (let ((names nil)
        (def-re (concat "\\b\\(?:part\\|action\\|state\\|port\\|connection"
                        "\\|attribute\\|item\\|requirement\\|constraint"
                        "\\|view\\|viewpoint\\|rendering\\|concern"
                        "\\|allocation\\|interface\\|enum\\|enumeration"
                        "\\|occurrence\\|metadata\\|calc\\|flow"
                        "\\|analysis\\|verification"
                        "\\|use case\\|case"
                        "\\|assoc\\|assoc struct\\|behavior\\|class"
                        "\\|classifier\\|connector\\|datatype\\|expr"
                        "\\|feature\\|function\\|interaction\\|metaclass"
                        "\\|namespace\\|predicate\\|step\\|struct\\|type"
                        "\\)\\s-+def\\s-+"
                        "\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward def-re nil t)
        (unless (sysml2--in-comment-or-string-p)
          (push (match-string-no-properties 1) names))))
    (delete-dups (nreverse names))))

(defun sysml2--in-comment-or-string-p ()
  "Return non-nil if point is inside a comment or string."
  (let ((state (syntax-ppss)))
    (or (nth 3 state) (nth 4 state))))

(defun sysml2--buffer-usage-names ()
  "Extract named part, port, and interface usages from the current buffer.
Returns list of plists (:name :type :kind) for connectable elements."
  (let ((results nil)
        (re (concat "\\b\\(part\\|port\\|interface\\|item\\|ref\\|connection\\)"
                    "\\s-+\\(" sysml2--identifier-regexp "\\)"
                    "\\(?:\\s-*:\\s-*\\(" sysml2--qualified-name-regexp "\\)\\)?")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward re nil t)
        (unless (or (sysml2--in-comment-or-string-p)
                    ;; Skip definitions (keyword followed by "def")
                    (save-excursion
                      (goto-char (match-end 1))
                      (looking-at "\\s-+def\\b")))
          (push (list :name (match-string-no-properties 2)
                      :type (match-string-no-properties 3)
                      :kind (match-string-no-properties 1))
                results))))
    (delete-dups (nreverse results))))

(defun sysml2--connectable-names ()
  "Return a list of connectable element names with dot-path variants.
Builds names like `partName.portName' for port usages inside part defs."
  (let ((usages (sysml2--buffer-usage-names))
        (names nil))
    (dolist (u usages)
      (push (plist-get u :name) names))
    ;; Also build dot-paths: part.port patterns from the buffer
    (save-excursion
      (goto-char (point-min))
      (let ((part-re (concat "\\bpart\\s-+\\(" sysml2--identifier-regexp "\\)"
                             "\\s-*:\\s-*\\(" sysml2--qualified-name-regexp "\\)")))
        (while (re-search-forward part-re nil t)
          (unless (or (sysml2--in-comment-or-string-p)
                      (save-excursion
                        (goto-char (match-beginning 0))
                        (looking-at ".*\\bpart\\s-+def\\b")))
            (let ((part-name (match-string-no-properties 1))
                  (part-type (match-string-no-properties 2)))
              ;; Find port usages inside the definition of part-type
              (save-excursion
                (goto-char (point-min))
                (let ((def-re (concat "\\b\\(?:part\\|port\\)\\s-+def\\s-+"
                                      (regexp-quote part-type) "\\b")))
                  (when (re-search-forward def-re nil t)
                    (when (re-search-forward "{" (line-end-position 2) t)
                      (let ((brace-start (1- (point)))
                            (body-end nil))
                        (goto-char brace-start)
                        (condition-case nil
                            (progn (forward-sexp 1)
                                   (setq body-end (point)))
                          (scan-error nil))
                        (when body-end
                          (goto-char (1+ brace-start))
                          (let ((port-re (concat "\\bport\\s-+"
                                                 "\\(" sysml2--identifier-regexp "\\)")))
                            (while (re-search-forward port-re body-end t)
                              (unless (looking-at "\\s-+def\\b")
                                (push (concat part-name "."
                                              (match-string-no-properties 1))
                                      names)))))))))))))))
    (delete-dups (nreverse names))))

(defun sysml2--completion-candidates (context)
  "Return completion candidates for CONTEXT."
  (pcase context
    ('line-start
     (append sysml2-definition-keywords
             sysml2-usage-keywords
             sysml2-structural-keywords
             sysml2-behavioral-keywords))

    ('after-import
     (append sysml2-standard-library-packages '("*")))

    ('after-colon
     (append (sysml2--buffer-definition-names)
             sysml2-standard-library-packages))

    ('after-specialization
     (append (sysml2--buffer-definition-names)
             sysml2-standard-library-packages))

    ('after-redefinition
     (sysml2--buffer-definition-names))

    ('after-connect
     (sysml2--connectable-names))

    ('after-to
     (sysml2--connectable-names))

    ('after-satisfy-by
     (mapcar (lambda (u) (plist-get u :name))
             (sysml2--buffer-usage-names)))

    ('after-modifier
     sysml2-usage-keywords)

    ('after-hash
     '("Metadata"))

    ('in-block
     (append sysml2-usage-keywords
             sysml2-behavioral-keywords
             sysml2-modifier-keywords))

    ('general
     sysml2-all-keywords)

    (_ nil)))

(defun sysml2-completion-at-point ()
  "Completion-at-point function for SysML v2 buffers.
Returns a completion table based on the context at point."
  (let ((context (sysml2--completion-context)))
    (when context
      (let* ((end (point))
             (start (save-excursion
                      (skip-chars-backward "A-Za-z0-9_:.*")
                      (point)))
             (candidates (sysml2--completion-candidates context)))
        (when candidates
          (list start end candidates
                :exclusive 'no
                :annotation-function
                (lambda (cand)
                  (cond
                   ((member cand sysml2-definition-keywords) " <def>")
                   ((member cand sysml2-usage-keywords) " <usage>")
                   ((member cand sysml2-structural-keywords) " <struct>")
                   ((member cand sysml2-behavioral-keywords) " <behav>")
                   ((member cand sysml2-standard-library-packages) " <lib>")
                   ((string-match-p "\\." cand) " <path>")
                   (t nil)))))))))

;; --- Smart Connection Commands ---

(defun sysml2--annotate-usage (name usages)
  "Return an annotation string for NAME based on USAGES plist data."
  (let ((match (seq-find (lambda (u) (string= (plist-get u :name) name)) usages)))
    (if match
        (let ((kind (plist-get match :kind))
              (type (plist-get match :type)))
          (concat " " (propertize
                       (if type (format "<%s : %s>" kind type) (format "<%s>" kind))
                       'face 'completions-annotations)))
      (when (string-match-p "\\." name)
        (concat " " (propertize "<path>" 'face 'completions-annotations))))))

(defun sysml2--read-connectable (prompt)
  "Read a connectable element name with PROMPT, showing annotated candidates."
  (let* ((names (sysml2--connectable-names))
         (usages (sysml2--buffer-usage-names))
         (all (delete-dups (append names (mapcar (lambda (u) (plist-get u :name)) usages)))))
    (completing-read prompt
                     (lambda (str pred action)
                       (if (eq action 'metadata)
                           `(metadata
                             (annotation-function
                              . ,(lambda (cand) (sysml2--annotate-usage cand usages))))
                         (complete-with-action action all str pred)))
                     nil t)))

(defun sysml2--read-definition-type (prompt)
  "Read a definition type with PROMPT, allowing empty for none."
  (let ((defs (sysml2--buffer-definition-names)))
    (completing-read prompt defs nil nil)))

(defun sysml2-connect ()
  "Insert a connection usage by selecting source and target interactively.
Scans the buffer for connectable elements (parts, ports) and offers
them for completion.  Generates valid SysML v2 connection syntax."
  (interactive)
  (let* ((conn-name (read-string "Connection name: "))
         (conn-type (sysml2--read-definition-type "Connection type (RET for none): "))
         (source (sysml2--read-connectable "Connect (source): "))
         (target (sysml2--read-connectable "To (target): "))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "connection " conn-name)
    (unless (string-empty-p conn-type)
      (insert " : " conn-type))
    (insert "\n" indent "  connect " source " to " target ";")))

(defun sysml2-insert-binding ()
  "Insert a binding connector by selecting source and target interactively."
  (interactive)
  (let* ((source (sysml2--read-connectable "Bind (source): "))
         (target (sysml2--read-connectable "To (target): "))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "bind " source " = " target ";")))

(defun sysml2-insert-flow ()
  "Insert a flow connection by selecting source and target interactively."
  (interactive)
  (let* ((flow-name (read-string "Flow name: "))
         (item-type (sysml2--read-definition-type "Item type flowing (RET for none): "))
         (source (sysml2--read-connectable "From (source): "))
         (target (sysml2--read-connectable "To (target): "))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "flow " flow-name)
    (unless (string-empty-p item-type)
      (insert " of " item-type))
    (insert " from " source " to " target ";")))

(defun sysml2-insert-interface ()
  "Insert an interface usage by selecting endpoints interactively."
  (interactive)
  (let* ((iface-name (read-string "Interface name: "))
         (iface-type (sysml2--read-definition-type "Interface type (RET for none): "))
         (source (sysml2--read-connectable "Connect (source): "))
         (target (sysml2--read-connectable "To (target): "))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "interface " iface-name)
    (unless (string-empty-p iface-type)
      (insert " : " iface-type))
    (insert "\n" indent "  connect " source " to " target ";")))

(defun sysml2-insert-allocation ()
  "Insert an allocation usage by selecting source and target interactively."
  (interactive)
  (let* ((usages (sysml2--buffer-usage-names))
         (defs (sysml2--buffer-definition-names))
         (all (delete-dups (append (mapcar (lambda (u) (plist-get u :name)) usages) defs)))
         (alloc-name (read-string "Allocation name: "))
         (source (completing-read "Allocate (source): " all nil t))
         (target (completing-read "To (target): " all nil t))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "allocation " alloc-name
            "\n" indent "  allocate " source " to " target ";")))

(defun sysml2-insert-satisfy ()
  "Insert a satisfy requirement statement interactively."
  (interactive)
  (let* ((usages (sysml2--buffer-usage-names))
         (defs (sysml2--buffer-definition-names))
         (all (delete-dups (append (mapcar (lambda (u) (plist-get u :name)) usages) defs)))
         ;; Filter to requirement-like names for the requirement prompt
         (req-usages (seq-filter (lambda (u)
                                   (member (plist-get u :kind)
                                           '("requirement" "constraint")))
                                 usages))
         (req-names (if req-usages
                        (mapcar (lambda (u) (plist-get u :name)) req-usages)
                      all))
         (req (completing-read "Satisfy requirement: " req-names nil t))
         (by (completing-read "By (satisfying element): " all nil t))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "satisfy " req " by " by ";")))

(defun sysml2--buffer-requirement-names ()
  "Extract all requirement definition names from the current buffer.
Scans for `requirement def NAME' patterns and returns a list of NAME strings."
  (let ((names nil)
        (req-re (concat "\\brequirement\\s-+def\\s-+"
                         "\\(" sysml2--identifier-regexp "\\)")))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward req-re nil t)
        (unless (sysml2--in-comment-or-string-p)
          (push (match-string-no-properties 1) names))))
    (delete-dups (nreverse names))))

(defun sysml2-insert-verify ()
  "Insert a verification definition interactively.
Prompts for the requirement to verify, verification name, subject name,
and subject type, then generates a verification def block."
  (interactive)
  (let* ((req-names (sysml2--buffer-requirement-names))
         (req (completing-read "Verify requirement: " req-names nil t))
         (verif-name (read-string
                      (format "Verification name (default %sVerification): " req)
                      nil nil (concat req "Verification")))
         (subj-name (read-string "Subject name (default testSubject): "
                                 nil nil "testSubject"))
         (subj-type (sysml2--read-definition-type "Subject type: "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "verification def " verif-name " {")
    (insert "\n" inner "subject " subj-name)
    (unless (string-empty-p subj-type)
      (insert " : " subj-type))
    (insert ";")
    (insert "\n" inner "objective {")
    (insert "\n" inner "    verify requirement " req ";")
    (insert "\n" inner "}")
    (insert "\n" indent "}")))

(defun sysml2-insert-subject ()
  "Insert a subject declaration interactively.
Prompts for subject name and type, then inserts at current indentation."
  (interactive)
  (let* ((subj-name (read-string "Subject name (default s): " nil nil "s"))
         (subj-type (sysml2--read-definition-type "Subject type: "))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "subject " subj-name)
    (unless (string-empty-p subj-type)
      (insert " : " subj-type))
    (insert ";")))

;; --- Model Scaffolding Commands ---

(defun sysml2-scaffold-package ()
  "Scaffold a new SysML v2 package with optional imports."
  (interactive)
  (let* ((name (read-string "Package name: "))
         (imports (read-string "Imports (comma-separated, RET for none): "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "package " name " {")
    (unless (string-empty-p imports)
      (dolist (imp (split-string imports "," t " "))
        (insert "\n" inner "import " imp ";")))
    (insert "\n" inner)
    (let ((pos (point)))
      (insert "\n" indent "}")
      (goto-char pos))))

(defun sysml2-scaffold-part-def ()
  "Scaffold a new part definition with optional attributes and ports."
  (interactive)
  (let* ((name (read-string "Part def name: "))
         (super (sysml2--read-definition-type "Specializes (RET for none): "))
         (abstract (y-or-n-p "Abstract? "))
         (attrs (read-string "Attributes (comma-separated, RET for none): "))
         (ports (read-string "Ports (comma-separated, RET for none): "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent)
    (when abstract (insert "abstract "))
    (insert "part def " name)
    (unless (string-empty-p super)
      (insert " :> " super))
    (insert " {")
    (unless (string-empty-p attrs)
      (dolist (attr (split-string attrs "," t " "))
        (insert "\n" inner "attribute " attr ";")))
    (unless (string-empty-p ports)
      (dolist (port (split-string ports "," t " "))
        (insert "\n" inner "port " port ";")))
    (insert "\n" inner)
    (let ((pos (point)))
      (insert "\n" indent "}")
      (goto-char pos))))

(defun sysml2-scaffold-port-def ()
  "Scaffold a new port definition with items."
  (interactive)
  (let* ((name (read-string "Port def name: "))
         (items (read-string "Items (format: in/out/inout name : Type, ...): "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "port def " name " {")
    (unless (string-empty-p items)
      (dolist (item (split-string items "," t " "))
        (insert "\n" inner item ";")))
    (insert "\n" inner)
    (let ((pos (point)))
      (insert "\n" indent "}")
      (goto-char pos))))

(defun sysml2-scaffold-requirement-def ()
  "Scaffold a new requirement definition with doc, subject, and constraint."
  (interactive)
  (let* ((name (read-string "Requirement def name: "))
         (doc (read-string "Description (RET for none): "))
         (subj-name (read-string "Subject name (RET for none): "))
         (subj-type (unless (string-empty-p subj-name)
                      (sysml2--read-definition-type "Subject type: ")))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "requirement def " name " {")
    (unless (string-empty-p doc)
      (insert "\n" inner "doc /* " doc " */"))
    (unless (string-empty-p subj-name)
      (insert "\n" inner "subject " subj-name)
      (when (and subj-type (not (string-empty-p subj-type)))
        (insert " : " subj-type))
      (insert ";"))
    (insert "\n" inner "require constraint {")
    (insert "\n" inner "    ")
    (let ((pos (point)))
      (insert "\n" inner "}")
      (insert "\n" indent "}")
      (goto-char pos))))

(defun sysml2-scaffold-state-def ()
  "Scaffold a new state machine definition with states and transitions."
  (interactive)
  (let* ((name (read-string "State def name: "))
         (states-str (read-string "States (comma-separated): "))
         (states (split-string states-str "," t " "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "state def " name " {")
    (insert "\n" inner "entry; then " (car states) ";")
    (insert "\n")
    ;; State declarations
    (dolist (s states)
      (insert "\n" inner "state " s ";"))
    (insert "\n")
    ;; Auto-generate sequential transitions
    (let ((prev nil))
      (dolist (s states)
        (when prev
          (insert "\n" inner "transition " prev "_to_" s)
          (insert "\n" inner "    first " prev)
          (insert "\n" inner "    then " s ";"))
        (setq prev s)))
    (insert "\n" indent "}")))

(defun sysml2-scaffold-action-def ()
  "Scaffold a new action definition with sub-actions and succession."
  (interactive)
  (let* ((name (read-string "Action def name: "))
         (actions-str (read-string "Sub-actions (name:Type, ...): "))
         (action-specs (split-string actions-str "," t " "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    "))
         (action-names nil))
    (end-of-line)
    (insert "\n" indent "action def " name " {")
    ;; Sub-action usages
    (dolist (spec action-specs)
      (let* ((parts (split-string spec ":" t " "))
             (aname (car parts))
             (atype (cadr parts)))
        (when aname
          (push aname action-names)
          (insert "\n" inner "action " aname)
          (when atype
            (insert " : " atype))
          (insert ";"))))
    ;; Successions
    (setq action-names (nreverse action-names))
    (when (> (length action-names) 1)
      (insert "\n")
      (let ((prev (car action-names)))
        (dolist (a (cdr action-names))
          (insert "\n" inner "first " prev " then " a ";")
          (setq prev a))))
    (insert "\n" indent "}")))

(defun sysml2-scaffold-enum-def ()
  "Scaffold a new enumeration definition with literals."
  (interactive)
  (let* ((name (read-string "Enum def name: "))
         (literals-str (read-string "Literals (comma-separated): "))
         (literals (split-string literals-str "," t " "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "enum def " name " {")
    (dolist (lit literals)
      (insert "\n" inner "enum " lit ";"))
    (insert "\n" indent "}")))

(defun sysml2-scaffold-use-case-def ()
  "Scaffold a new use case definition with subject and actors."
  (interactive)
  (let* ((name (read-string "Use case def name: "))
         (subj-name (read-string "Subject name (RET for none): "))
         (subj-type (unless (string-empty-p subj-name)
                      (sysml2--read-definition-type "Subject type: ")))
         (actors-str (read-string "Actors (comma-separated, RET for none): "))
         (indent (make-string (current-indentation) ?\s))
         (inner (concat indent "    ")))
    (end-of-line)
    (insert "\n" indent "use case def " name " {")
    (unless (string-empty-p subj-name)
      (insert "\n" inner "subject " subj-name)
      (when (and subj-type (not (string-empty-p subj-type)))
        (insert " : " subj-type))
      (insert ";"))
    (unless (string-empty-p actors-str)
      (dolist (actor (split-string actors-str "," t " "))
        (insert "\n" inner "actor " actor ";")))
    (insert "\n" inner)
    (let ((pos (point)))
      (insert "\n" indent "}")
      (goto-char pos))))

(defun sysml2-scaffold ()
  "Scaffold a new SysML v2 model element.
Presents a menu of available scaffolding commands."
  (interactive)
  (let ((type (completing-read "Scaffold: "
                               '("package" "part def" "port def"
                                 "requirement def" "state def"
                                 "action def" "enum def" "use case def")
                               nil t)))
    (pcase type
      ("package"         (sysml2-scaffold-package))
      ("part def"        (sysml2-scaffold-part-def))
      ("port def"        (sysml2-scaffold-port-def))
      ("requirement def" (sysml2-scaffold-requirement-def))
      ("state def"       (sysml2-scaffold-state-def))
      ("action def"      (sysml2-scaffold-action-def))
      ("enum def"        (sysml2-scaffold-enum-def))
      ("use case def"    (sysml2-scaffold-use-case-def)))))

(provide 'sysml2-completion)
;;; sysml2-completion.el ends here
