;;; sysml2-repl.el --- Inferior `sysml repl' for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Run the `sysml repl' subcommand inside an Emacs comint buffer.
;;
;; M-x `sysml2-repl' starts a fresh REPL session.  When invoked from
;; a buffer that visits a `.sysml' or `.kerml' file, that file is
;; preloaded (and any project root / library path is forwarded as
;; `-I' / `--stdlib-path').
;;
;; The REPL prompt is `sysml> ' at top level, `sysml:NAME> ' when
;; focused on a definition via the `cd' command.

;;; Code:

(require 'comint)
(require 'sysml2-vars)
(require 'sysml2-project)

(defvar sysml2-repl-prompt-regexp
  "^sysml\\(?::[^ \n>]+\\)?> "
  "Regexp matching the `sysml repl' prompt.
Top-level prompt is `sysml> '; when focused via `cd' it becomes
`sysml:NAME> ' where NAME may contain `::' for qualified paths.")

(defun sysml2-repl-buffer-name (&optional tag)
  "Return the comint buffer name for the REPL.
With optional TAG, append `<TAG>' to disambiguate multiple sessions."
  (if tag
      (format "*sysml repl<%s>*" tag)
    "*sysml repl*"))

(defun sysml2-repl--executable ()
  "Resolve the sysml CLI executable, or signal a user error."
  (let* ((name (or sysml2-cli-executable "sysml"))
         (path (sysml2--find-executable name)))
    (unless path
      (user-error "Cannot find `%s' on exec-path — install sysml-cli first"
                  name))
    path))

(defun sysml2-repl--build-args (files)
  "Build the argument list for `sysml repl', given a list of FILES.
Includes project flags (-I, --stdlib-path) when detectable."
  (let ((args (list "repl")))
    (let ((root (sysml2-project-root)))
      (when root
        (setq args (append args (list "-I" root)))))
    (let ((lib (sysml2-project-library-path)))
      (when lib
        (setq args (append args (list "--stdlib-path" lib)))))
    (when files
      (setq args (append args files)))
    args))

;;;###autoload
(define-derived-mode sysml2-repl-mode comint-mode "SysML-REPL"
  "Major mode for the inferior `sysml repl' process."
  (setq-local comint-prompt-regexp sysml2-repl-prompt-regexp)
  (setq-local comint-prompt-read-only nil)
  (setq-local comint-input-ignoredups t)
  (setq-local comint-process-echoes t))

;;;###autoload
(defun sysml2-repl (&optional file)
  "Start (or switch to) an interactive `sysml repl' session.
With a prefix argument, prompt for a SysML FILE to preload;
otherwise, when called from a `.sysml'/`.kerml' buffer, preload
that file."
  (interactive
   (list (cond
          (current-prefix-arg
           (read-file-name "Preload SysML file: " nil nil t))
          ((and buffer-file-name
                (string-match-p "\\.\\(sysml\\|kerml\\)\\'" buffer-file-name))
           buffer-file-name))))
  (let* ((exe (sysml2-repl--executable))
         (args (sysml2-repl--build-args (when file (list file))))
         (bufname (sysml2-repl-buffer-name))
         (buf (apply #'make-comint-in-buffer
                     "sysml-repl"
                     bufname
                     exe nil
                     args)))
    (with-current-buffer buf
      (sysml2-repl-mode))
    (pop-to-buffer buf)
    buf))

(provide 'sysml2-repl)
;;; sysml2-repl.el ends here
