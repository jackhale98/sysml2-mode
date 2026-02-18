;;; test-project.el --- Project management tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-project.el: project root detection, library path
;; resolution, and SysML file discovery.

;;; Code:

(require 'ert)
(require 'sysml2-mode)

;; --- Helpers ---

(defmacro sysml2-test--with-temp-project (bindings &rest body)
  "Create a temp directory, bind vars per BINDINGS, execute BODY, clean up.
BINDINGS is a list of (VAR SUBPATH [type]) forms where type is
`file' (default) or `dir'.  The temp root is bound to `project-root'."
  (declare (indent 1))
  `(let ((project-root (make-temp-file "sysml2-test-" t)))
     (unwind-protect
         (let ,(mapcar
                (lambda (binding)
                  (let ((var (nth 0 binding))
                        (subpath (nth 1 binding))
                        (type (or (nth 2 binding) 'file)))
                    `(,var
                      (let ((full-path (expand-file-name ,subpath project-root)))
                        ,(if (eq type 'dir)
                             `(progn (make-directory full-path t) full-path)
                           `(progn
                              (make-directory (file-name-directory full-path) t)
                              (write-region "" nil full-path)
                              full-path))))))
                bindings)
           ,@body)
       (delete-directory project-root t))))

;; --- Project root detection ---

(ert-deftest sysml2-test-project-root-sysml-project-file ()
  "Test project root detection via `.sysml-project' file."
  (sysml2-test--with-temp-project
      ((marker ".sysml-project")
       (subdir "src/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          sysml2--project-root-cache)
      (should (equal (sysml2-project-root)
                     (file-name-as-directory project-root))))))

(ert-deftest sysml2-test-project-root-sysml-library-dir ()
  "Test project root detection via `sysml.library/' directory."
  (sysml2-test--with-temp-project
      ((lib "sysml.library/" dir)
       (subdir "src/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          sysml2--project-root-cache)
      (should (equal (sysml2-project-root)
                     (file-name-as-directory project-root))))))

(ert-deftest sysml2-test-project-root-git-dir ()
  "Test project root detection via `.git' directory."
  (sysml2-test--with-temp-project
      ((git ".git/" dir)
       (subdir "src/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          sysml2--project-root-cache)
      (should (equal (sysml2-project-root)
                     (file-name-as-directory project-root))))))

(ert-deftest sysml2-test-project-root-priority ()
  "Test that `.sysml-project' takes priority over `.git'."
  (sysml2-test--with-temp-project
      ((marker ".sysml-project")
       (git ".git/" dir)
       (subdir "deep/nested/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          sysml2--project-root-cache)
      ;; Should find .sysml-project root, not .git
      (should (equal (sysml2-project-root)
                     (file-name-as-directory project-root))))))

(ert-deftest sysml2-test-project-root-nil-when-no-markers ()
  "Test that nil is returned when no project markers are found."
  (let ((tmpdir (make-temp-file "sysml2-test-empty-" t)))
    (unwind-protect
        (let ((default-directory (file-name-as-directory tmpdir))
              sysml2--project-root-cache)
          (should (null (sysml2-project-root))))
      (delete-directory tmpdir t))))

(ert-deftest sysml2-test-project-root-caching ()
  "Test that project root is cached in buffer-local variable."
  (sysml2-test--with-temp-project
      ((marker ".sysml-project")
       (subdir "src/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          sysml2--project-root-cache)
      (sysml2-project-root)
      (should (equal sysml2--project-root-cache
                     (file-name-as-directory project-root))))))

;; --- Library path resolution ---

(ert-deftest sysml2-test-library-path-custom ()
  "Test that custom library path is used when set."
  (sysml2-test--with-temp-project
      ((lib "my-lib/" dir))
    (let ((sysml2-standard-library-path (expand-file-name "my-lib" project-root))
          sysml2--current-library-path
          sysml2--project-root-cache)
      (should (equal (sysml2-project-library-path)
                     (expand-file-name "my-lib" project-root))))))

(ert-deftest sysml2-test-library-path-auto-detect ()
  "Test auto-detection of sysml.library/ in project root."
  (sysml2-test--with-temp-project
      ((marker ".sysml-project")
       (lib "sysml.library/" dir)
       (subdir "src/" dir))
    (let ((default-directory (file-name-as-directory subdir))
          (sysml2-standard-library-path nil)
          sysml2--current-library-path
          sysml2--project-root-cache)
      (should (equal (sysml2-project-library-path)
                     (expand-file-name "sysml.library" project-root))))))

(ert-deftest sysml2-test-library-path-nil-when-missing ()
  "Test that nil is returned when no library can be found."
  (let ((tmpdir (make-temp-file "sysml2-test-nolib-" t)))
    (unwind-protect
        (let ((default-directory (file-name-as-directory tmpdir))
              (sysml2-standard-library-path nil)
              sysml2--current-library-path
              sysml2--project-root-cache)
          (should (null (sysml2-project-library-path))))
      (delete-directory tmpdir t))))

;; --- File discovery ---

(ert-deftest sysml2-test-find-sysml-files ()
  "Test recursive discovery of .sysml and .kerml files."
  (sysml2-test--with-temp-project
      ((marker ".sysml-project")
       (f1 "models/vehicle.sysml")
       (f2 "models/engine.sysml")
       (f3 "kernel/base.kerml")
       (f4 "readme.txt"))
    (let ((default-directory (file-name-as-directory project-root))
          sysml2--project-root-cache)
      (let ((files (sysml2-project-find-sysml-files project-root)))
        (should (= 3 (length files)))
        (should (cl-every (lambda (f)
                            (string-match-p "\\.\\(sysml\\|kerml\\)\\'" f))
                          files))))))

(provide 'test-project)
;;; test-project.el ends here
