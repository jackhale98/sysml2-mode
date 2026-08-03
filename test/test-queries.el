;;; test-queries.el --- Tests for tree-sitter .scm query files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; Verifies that canonical tree-sitter query files exist in
;; tree-sitter-sysml/queries/ for downstream editor consumption
;; (Helix, Neovim, Zed) and that they cover expected node types.

;;; Code:

(require 'ert)
(require 'test-helper)

(defvar sysml2-test--queries-dir
  (expand-file-name "tree-sitter-sysml/queries/" sysml2-test--repo-root)
  "Path to the canonical tree-sitter query files.")

(ert-deftest sysml2-queries-highlights-exists ()
  "highlights.scm must exist in the queries directory."
  (should (file-exists-p
           (expand-file-name "highlights.scm" sysml2-test--queries-dir))))

(ert-deftest sysml2-queries-indents-exists ()
  "indents.scm must exist in the queries directory."
  (should (file-exists-p
           (expand-file-name "indents.scm" sysml2-test--queries-dir))))

(ert-deftest sysml2-queries-folds-exists ()
  "folds.scm must exist in the queries directory."
  (should (file-exists-p
           (expand-file-name "folds.scm" sysml2-test--queries-dir))))

(ert-deftest sysml2-queries-locals-exists ()
  "locals.scm must exist in the queries directory."
  (should (file-exists-p
           (expand-file-name "locals.scm" sysml2-test--queries-dir))))

(ert-deftest sysml2-queries-tags-exists ()
  "tags.scm must exist for ctags-style symbol indexing."
  (should (file-exists-p
           (expand-file-name "tags.scm" sysml2-test--queries-dir))))

(defun sysml2-test--query-contains (name pattern)
  "Return non-nil if NAME query file contains PATTERN."
  (let ((path (expand-file-name name sysml2-test--queries-dir)))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (re-search-forward pattern nil t))))

(ert-deftest sysml2-queries-highlights-cover-definitions ()
  "highlights.scm must mark definition nodes.
The grammar uses a unified `definition' node for all `<kw> def'
forms; state and enum definitions have their own node types."
  (should (sysml2-test--query-contains
           "highlights.scm" "(definition"))
  (should (sysml2-test--query-contains
           "highlights.scm" "state_definition"))
  (should (sysml2-test--query-contains
           "highlights.scm" "enumeration_definition")))

(ert-deftest sysml2-queries-highlights-cover-keywords ()
  "highlights.scm must include keyword captures."
  (should (sysml2-test--query-contains
           "highlights.scm" "@keyword"))
  (should (sysml2-test--query-contains
           "highlights.scm" "\"part\""))
  (should (sysml2-test--query-contains
           "highlights.scm" "\"def\"")))

(ert-deftest sysml2-queries-highlights-cover-comments ()
  "highlights.scm must include comment captures."
  (should (sysml2-test--query-contains
           "highlights.scm" "@comment"))
  (should (sysml2-test--query-contains
           "highlights.scm" "line_comment")))

(ert-deftest sysml2-queries-indents-cover-bodies ()
  "indents.scm must cover at least the canonical body nodes."
  (should (sysml2-test--query-contains "indents.scm" "definition_body"))
  (should (sysml2-test--query-contains "indents.scm" "package_body"))
  (should (sysml2-test--query-contains "indents.scm" "state_body")))

(ert-deftest sysml2-queries-folds-cover-bodies ()
  "folds.scm should mark body nodes as foldable."
  (should (sysml2-test--query-contains "folds.scm" "@fold"))
  (should (sysml2-test--query-contains "folds.scm" "definition_body")))

(ert-deftest sysml2-queries-tags-cover-definitions ()
  "tags.scm should mark definitions for ctags-style indexing."
  (should (sysml2-test--query-contains "tags.scm" "@definition"))
  (should (sysml2-test--query-contains "tags.scm" "(definition"))
  (should (sysml2-test--query-contains "tags.scm" "package_declaration")))

(ert-deftest sysml2-queries-readme-exists ()
  "A README in queries/ should document the format and version."
  (should (file-exists-p
           (expand-file-name "README.md" sysml2-test--queries-dir))))

(provide 'test-queries)
;;; test-queries.el ends here
