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

(defun sysml2-connect ()
  "Insert a connection usage by selecting source and target interactively.
Scans the buffer for connectable elements (parts, ports) and offers
them for completion.  Generates valid SysML v2 connection syntax."
  (interactive)
  (let* ((names (sysml2--connectable-names))
         (usages (sysml2--buffer-usage-names))
         (defs (sysml2--buffer-definition-names))
         (all-connectable (delete-dups (append names
                                               (mapcar (lambda (u) (plist-get u :name))
                                                       usages))))
         (conn-name (read-string "Connection name: "))
         (conn-type (completing-read "Connection type (empty for none): "
                                     defs nil nil))
         (source (completing-read "Connect (source): " all-connectable nil nil))
         (target (completing-read "To (target): " all-connectable nil nil))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "connection " conn-name)
    (unless (string-empty-p conn-type)
      (insert " : " conn-type))
    (insert "\n" indent "  connect " source " to " target ";")))

(defun sysml2-insert-binding ()
  "Insert a binding connector by selecting source and target interactively."
  (interactive)
  (let* ((names (sysml2--connectable-names))
         (source (completing-read "Bind (source): " names nil nil))
         (target (completing-read "To (target): " names nil nil))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "bind " source " = " target ";")))

(defun sysml2-insert-flow ()
  "Insert a flow connection by selecting source and target interactively."
  (interactive)
  (let* ((names (sysml2--connectable-names))
         (defs (sysml2--buffer-definition-names))
         (flow-name (read-string "Flow name: "))
         (item-type (completing-read "Item type flowing (empty for none): "
                                     defs nil nil))
         (source (completing-read "From (source): " names nil nil))
         (target (completing-read "To (target): " names nil nil))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "flow " flow-name)
    (unless (string-empty-p item-type)
      (insert " : " item-type))
    (insert " from " source " to " target ";")))

(defun sysml2-insert-interface ()
  "Insert an interface usage by selecting endpoints interactively."
  (interactive)
  (let* ((names (sysml2--connectable-names))
         (defs (sysml2--buffer-definition-names))
         (iface-name (read-string "Interface name: "))
         (iface-type (completing-read "Interface type (empty for none): "
                                      defs nil nil))
         (source (completing-read "Connect (source): " names nil nil))
         (target (completing-read "To (target): " names nil nil))
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
         (all-names (mapcar (lambda (u) (plist-get u :name)) usages))
         (defs (sysml2--buffer-definition-names))
         (alloc-name (read-string "Allocation name: "))
         (source (completing-read "Allocate (source): "
                                  (append all-names defs) nil nil))
         (target (completing-read "To (target): "
                                  (append all-names defs) nil nil))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "allocation " alloc-name
            "\n" indent "  allocate " source " to " target ";")))

(defun sysml2-insert-satisfy ()
  "Insert a satisfy requirement statement interactively."
  (interactive)
  (let* ((usages (sysml2--buffer-usage-names))
         (defs (sysml2--buffer-definition-names))
         (all-names (append (mapcar (lambda (u) (plist-get u :name)) usages) defs))
         (req (completing-read "Satisfy requirement: " all-names nil nil))
         (by (completing-read "By (satisfying element): " all-names nil nil))
         (indent (make-string (current-indentation) ?\s)))
    (end-of-line)
    (insert "\n" indent "satisfy " req " by " by ";")))

(provide 'sysml2-completion)
;;; sysml2-completion.el ends here
