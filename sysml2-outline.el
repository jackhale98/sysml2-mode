;;; sysml2-outline.el --- Outline side panel for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Persistent outline side panel showing a hierarchical tree view of the
;; SysML file structure, similar to the VS Code Syside editor's outline.
;; Toggle with `sysml2-outline-toggle' (C-c C-n t).

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-outline-toggle' -- Toggle the outline side panel
;;   `sysml2-outline-refresh' -- Refresh the outline tree

(require 'sysml2-vars)
(require 'sysml2-lang)
(require 'sysml2-navigation)

;; --- Constants ---

(defconst sysml2--outline-buffer-name "*SysML2 Outline*"
  "Name of the outline side panel buffer.")

(defconst sysml2--outline-scan-re
  (concat "^\\(\\s-*\\)"
          "\\(?:\\(?:" (regexp-opt sysml2-visibility-keywords) "\\)\\s-+\\)?"
          "\\(?:abstract\\s-+\\)?"
          "\\(package\\|"
          (regexp-opt sysml2-definition-keywords)
          "\\)"
          "\\s-+\\(" sysml2--identifier-regexp "\\)")
  "Regexp for scanning outline entries.
Group 1: leading whitespace (for indent level).
Group 2: keyword (package, part def, etc.).
Group 3: name.")

(defconst sysml2--outline-width 35
  "Width of the outline side panel.")

;; --- Scanning ---

(defun sysml2--outline-scan (&optional buffer)
  "Scan BUFFER for outline entries.
Returns a list of plists (:name :type :level :pos :line)."
  (with-current-buffer (or buffer (current-buffer))
    (save-excursion
      (goto-char (point-min))
      (let ((results nil))
        (while (re-search-forward sysml2--outline-scan-re nil t)
          (let ((pos (match-beginning 0)))
            (save-excursion
              (goto-char pos)
              (unless (let ((ppss (syntax-ppss)))
                        (or (nth 3 ppss) (nth 4 ppss)))
                (let* ((indent (length (match-string-no-properties 1)))
                       (kw (match-string-no-properties 2))
                       (name (match-string-no-properties 3))
                       (level (/ indent sysml2-indent-offset)))
                  (push (list :name name
                              :type kw
                              :level level
                              :pos pos
                              :line (line-number-at-pos pos))
                        results))))))
        (nreverse results)))))

;; --- Rendering ---

(defun sysml2--outline-has-children-p (entry entries)
  "Return non-nil if ENTRY has children in ENTRIES.
A child is the next entry with a higher level."
  (let ((idx (cl-position entry entries :test #'eq))
        (level (plist-get entry :level)))
    (when idx
      (let ((next (nth (1+ idx) entries)))
        (and next (> (plist-get next :level) level))))))

(defun sysml2--outline-render (entries source-buffer)
  "Render ENTRIES into the outline buffer for SOURCE-BUFFER."
  (let ((buf (get-buffer-create sysml2--outline-buffer-name))
        (inhibit-read-only t))
    (with-current-buffer buf
      (erase-buffer)
      (sysml2-outline-mode)
      (setq-local sysml2--outline-source-buffer source-buffer)
      (setq-local sysml2--outline-entries entries)
      (dolist (entry entries)
        (let* ((level (plist-get entry :level))
               (indent-str (make-string (* level 2) ?\s))
               (kw (plist-get entry :type))
               (name (plist-get entry :name))
               (pos (plist-get entry :pos))
               (line (plist-get entry :line))
               (has-children (sysml2--outline-has-children-p entry entries))
               (start (point)))
          ;; Collapse indicator
          (insert indent-str)
          (if has-children
              (insert (propertize "▶ " 'face 'shadow
                                  'sysml2-outline-toggle t))
            (insert "  "))
          (let ((kw-start (point)))
            (insert kw)
            (put-text-property kw-start (point) 'face 'sysml2-keyword-face))
          (insert " ")
          (let ((name-start (point)))
            (insert name)
            (put-text-property name-start (point) 'face 'sysml2-definition-name-face))
          (insert "\n")
          ;; Store properties for navigation and collapsing
          (put-text-property start (point) 'sysml2-outline-marker pos)
          (put-text-property start (point) 'sysml2-outline-line line)
          (put-text-property start (point) 'sysml2-outline-level level)))
      (goto-char (point-min)))
    buf))

;; --- Collapsing ---

(defvar-local sysml2--outline-entries nil
  "The outline entries for the current outline buffer.")

(defvar-local sysml2--outline-collapsed (make-hash-table :test 'equal)
  "Hash of collapsed line numbers in the outline.")

(defun sysml2--outline-toggle-fold ()
  "Toggle folding of the outline entry at point."
  (interactive)
  (let ((level (get-text-property (line-beginning-position) 'sysml2-outline-level))
        (inhibit-read-only t))
    (when level
      (let* ((line-num (line-number-at-pos))
             (collapsed (gethash line-num sysml2--outline-collapsed)))
        (save-excursion
          (forward-line 1)
          (let ((start (point)))
            ;; Find extent of children (all following lines with level > this one)
            (while (and (not (eobp))
                        (let ((child-level (get-text-property
                                            (line-beginning-position)
                                            'sysml2-outline-level)))
                          (and child-level (> child-level level))))
              (forward-line 1))
            (when (> (point) start)
              (if collapsed
                  ;; Expand
                  (progn
                    (remove-text-properties start (point) '(invisible nil))
                    (remhash line-num sysml2--outline-collapsed)
                    ;; Update indicator
                    (save-excursion
                      (goto-char (line-beginning-position (- 1 (- (line-number-at-pos) line-num))))
                      (when (search-forward "▼" (line-end-position) t)
                        (replace-match "▶"))))
                ;; Collapse
                (put-text-property start (point) 'invisible 'sysml2-outline)
                (puthash line-num t sysml2--outline-collapsed)
                ;; Update indicator
                (save-excursion
                  (goto-char (line-beginning-position 0))
                  (goto-char (line-beginning-position))
                  (when (search-forward "▶" (line-end-position) t)
                    (replace-match "▼")))))))))))

(defun sysml2--outline-collapse-all ()
  "Collapse all entries that have children in the outline.
Collapses every level, not just top-level."
  (interactive)
  (let ((inhibit-read-only t))
    ;; Work bottom-up so inner nodes collapse before outer ones
    (save-excursion
      (goto-char (point-max))
      (forward-line -1)
      (while (>= (point) (point-min))
        (let ((level (get-text-property (line-beginning-position)
                                        'sysml2-outline-level)))
          (when (and level
                     (sysml2--outline-line-has-children-p)
                     (not (gethash (line-number-at-pos)
                                   sysml2--outline-collapsed)))
            (sysml2--outline-toggle-fold)))
        (forward-line -1)))))

(defun sysml2--outline-line-has-children-p ()
  "Return non-nil if the current outline line has children."
  (let ((level (get-text-property (line-beginning-position)
                                   'sysml2-outline-level)))
    (when level
      (save-excursion
        (forward-line 1)
        (and (not (eobp))
             (let ((next-level (get-text-property (line-beginning-position)
                                                   'sysml2-outline-level)))
               (and next-level (> next-level level))))))))

(defun sysml2--outline-expand-all ()
  "Expand all collapsed entries in the outline."
  (interactive)
  (let ((inhibit-read-only t))
    (remove-text-properties (point-min) (point-max) '(invisible nil))
    (clrhash sysml2--outline-collapsed)
    (save-excursion
      (goto-char (point-min))
      (while (search-forward "▼" nil t)
        (replace-match "▶")))))

;; --- Navigation ---

(defvar-local sysml2--outline-source-buffer nil
  "The source SysML buffer associated with this outline buffer.")

(defun sysml2--outline-goto ()
  "Jump to the source position of the outline entry at point."
  (interactive)
  (let ((pos (get-text-property (point) 'sysml2-outline-marker))
        (src sysml2--outline-source-buffer))
    (when (and pos src (buffer-live-p src))
      (let ((win (get-buffer-window src)))
        (if win
            (select-window win)
          (pop-to-buffer src)))
      (goto-char pos)
      (recenter))))

(defun sysml2--outline-goto-and-close ()
  "Jump to the source position and close the outline panel."
  (interactive)
  (sysml2--outline-goto)
  (sysml2-outline-toggle))

;; --- Outline Mode ---

(defvar sysml2-outline-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "RET") #'sysml2--outline-goto)
    (define-key map (kbd "o") #'sysml2--outline-goto-and-close)
    (define-key map (kbd "g") #'sysml2-outline-refresh)
    (define-key map (kbd "q") #'sysml2-outline-toggle)
    (define-key map (kbd "n") #'next-line)
    (define-key map (kbd "p") #'previous-line)
    (define-key map (kbd "TAB") #'sysml2--outline-toggle-fold)
    (define-key map (kbd "S") #'sysml2--outline-collapse-all)
    (define-key map (kbd "E") #'sysml2--outline-expand-all)
    (define-key map [mouse-1] #'sysml2--outline-click)
    map)
  "Keymap for `sysml2-outline-mode'.")

(defun sysml2--outline-click (event)
  "Jump to outline entry at mouse click EVENT."
  (interactive "e")
  (mouse-set-point event)
  (sysml2--outline-goto))

(define-derived-mode sysml2-outline-mode special-mode "SysML2-Outline"
  "Major mode for the SysML2 outline side panel.
\\{sysml2-outline-mode-map}"
  :group 'sysml2
  (setq truncate-lines t)
  (setq cursor-type 'bar)
  (setq-local sysml2--outline-collapsed (make-hash-table :test 'equal))
  (add-to-invisibility-spec '(sysml2-outline . t)))

;; --- Auto-refresh ---

(defun sysml2--outline-after-save ()
  "Refresh the outline panel after saving, if it is visible."
  (when (get-buffer-window sysml2--outline-buffer-name)
    (sysml2-outline-refresh)))

;; --- Public Commands ---

(defun sysml2-outline-refresh ()
  "Refresh the outline side panel from the current source buffer."
  (interactive)
  (let ((src (if (eq major-mode 'sysml2-outline-mode)
                 sysml2--outline-source-buffer
               (current-buffer))))
    (when (and src (buffer-live-p src))
      (let ((entries (sysml2--outline-scan src)))
        (sysml2--outline-render entries src)))))

(defun sysml2-outline-toggle ()
  "Toggle the SysML2 outline side panel."
  (interactive)
  (let ((outline-buf (get-buffer sysml2--outline-buffer-name)))
    (if (and outline-buf (get-buffer-window outline-buf))
        ;; Close: delete the outline window and remove hooks
        (progn
          (delete-window (get-buffer-window outline-buf))
          (when (and outline-buf (buffer-live-p outline-buf))
            (let ((src (buffer-local-value 'sysml2--outline-source-buffer
                                           outline-buf)))
              (when (and src (buffer-live-p src))
                (with-current-buffer src
                  (remove-hook 'after-save-hook #'sysml2--outline-after-save t))))))
      ;; Open: scan, render, display in side window
      (let* ((src (if (eq major-mode 'sysml2-outline-mode)
                      sysml2--outline-source-buffer
                    (current-buffer)))
             (entries (sysml2--outline-scan src))
             (buf (sysml2--outline-render entries src)))
        (display-buffer-in-side-window
         buf `((side . left)
               (slot . -1)
               (window-width . ,sysml2--outline-width)
               (preserve-size . (t . nil))))
        ;; Install auto-refresh hook on the source buffer
        (with-current-buffer src
          (add-hook 'after-save-hook #'sysml2--outline-after-save nil t))))))

(provide 'sysml2-outline)
;;; sysml2-outline.el ends here
