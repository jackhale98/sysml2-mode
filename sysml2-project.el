;;; sysml2-project.el --- Project management for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Project root detection, library path resolution, and multi-file support
;; for SysML v2 projects.
;;
;; Project root is detected by searching upward for marker files/directories
;; in priority order: `.sysml-project' file, `sysml.library/' directory,
;; `.git' directory.

;;; Code:

(require 'sysml2-vars)

;; --- Buffer-local cache ---

(defvar-local sysml2--project-root-cache nil
  "Cached project root directory for the current buffer.")

;; --- Project root detection ---

(defun sysml2-project-root (&optional dir)
  "Find the SysML v2 project root starting from DIR.
Search upward for project markers in priority order:
  1. `.sysml-project' file
  2. `sysml.library/' directory
  3. `.git' directory
Returns the directory containing the marker, or nil if none found.
Result is cached in the buffer-local `sysml2--project-root-cache'."
  (or sysml2--project-root-cache
      (let* ((start (or dir default-directory))
             (root (or (locate-dominating-file start ".sysml-project")
                       (locate-dominating-file start "sysml.library")
                       (locate-dominating-file start ".git"))))
        (setq sysml2--project-root-cache
              (when root (expand-file-name root))))))

(defun sysml2-project-library-path (&optional dir)
  "Resolve the SysML v2 standard library path.
Resolution order:
  1. `sysml2-standard-library-path' defcustom (if set)
  2. `sysml.library/' in project root (if it exists)
  3. `standard-library/' relative to this package
Returns the path or nil.  Sets `sysml2--current-library-path'."
  (setq sysml2--current-library-path
        (cond
         ;; 1. Explicit custom path
         (sysml2-standard-library-path
          (expand-file-name sysml2-standard-library-path))
         ;; 2. sysml.library/ in project root
         ((let* ((root (sysml2-project-root dir))
                 (lib (when root
                        (expand-file-name "sysml.library" root))))
            (when (and lib (file-directory-p lib))
              lib)))
         ;; 3. Bundled SysML v2 standard library (git submodule)
         ((let* ((pkg-dir (file-name-directory
                           (or load-file-name buffer-file-name
                               default-directory)))
                 (bundled (expand-file-name
                           "sysml-v2-stdlib/sysml.library" pkg-dir)))
            (when (file-directory-p bundled)
              bundled)))
         ;; 4. Legacy fallback: standard-library/ relative to package
         ((let ((bundled (expand-file-name
                          "standard-library"
                          (file-name-directory
                           (or load-file-name buffer-file-name
                               default-directory)))))
            (when (file-directory-p bundled)
              bundled))))))

(defun sysml2-project-find-sysml-files (&optional dir)
  "Find all SysML v2 and KerML files under DIR recursively.
DIR defaults to the project root.  Returns a list of absolute file paths
matching `.sysml' or `.kerml' extensions."
  (let ((root (or dir (sysml2-project-root) default-directory)))
    (when (file-directory-p root)
      (directory-files-recursively root "\\.\\(sysml\\|kerml\\)\\'"))))

(provide 'sysml2-project)
;;; sysml2-project.el ends here
