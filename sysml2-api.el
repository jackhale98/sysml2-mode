;;; sysml2-api.el --- REST API client for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; REST client for the Systems Modeling API v1.0.  Provides functions
;; for listing projects, querying elements, pushing/pulling models,
;; and executing queries against a remote repository.

;;; Code:

;;; Public API:
;;
;; Functions:
;;   `sysml2-api-list-projects' -- List projects from API
;;   `sysml2-api-get-elements' -- Get elements for a project
;;   `sysml2-api-push-model' -- Push model to API
;;   `sysml2-api-pull-model' -- Pull model from API
;;   `sysml2-api-query' -- Execute query against API

(require 'sysml2-vars)
(require 'url)
(require 'json)

;; --- Internal Helpers ---

(defun sysml2--api-url (path)
  "Join `sysml2-api-base-url' with PATH."
  (sysml2--api-check-configured)
  (concat (string-trim-right sysml2-api-base-url "/") path))

(defun sysml2--api-headers ()
  "Return HTTP headers alist for API requests."
  (let ((headers '(("Content-Type" . "application/json")
                   ("Accept" . "application/json"))))
    (when sysml2--api-auth-token
      (push (cons "Authorization"
                  (concat "Bearer " sysml2--api-auth-token))
            headers))
    headers))

(defun sysml2--api-check-configured ()
  "Signal `user-error' if `sysml2-api-base-url' is nil."
  (unless sysml2-api-base-url
    (user-error "SysML API not configured: set `sysml2-api-base-url'")))

(defun sysml2--api-parse-response (buffer)
  "Parse HTTP response in BUFFER.
Returns (:status INT :body JSON :error STRING-OR-NIL)."
  (with-current-buffer buffer
    (goto-char (point-min))
    (let ((status nil)
          (body nil)
          (err nil))
      ;; Parse status line
      (when (looking-at "HTTP/[0-9.]+ \\([0-9]+\\)")
        (setq status (string-to-number (match-string 1))))
      ;; Find body after headers
      (when (re-search-forward "\n\n" nil t)
        (condition-case e
            (setq body (json-read))
          (json-readtable-error
           (setq err (format "JSON parse error: %s" (error-message-string e))))))
      (when (and status (>= status 400))
        (setq err (format "HTTP %d" status)))
      (list :status status :body body :error err))))

(defun sysml2--api-request (method path &optional body callback)
  "Send HTTP METHOD request to PATH with optional BODY.
If CALLBACK is non-nil, request is async; CALLBACK receives the
parsed response plist.  If CALLBACK is nil, returns the parsed
response synchronously."
  (sysml2--api-check-configured)
  (let ((url-request-method method)
        (url-request-extra-headers (sysml2--api-headers))
        (url-request-data (when body (encode-coding-string
                                       (json-encode body) 'utf-8)))
        (full-url (sysml2--api-url path)))
    (if callback
        (url-retrieve
         full-url
         (lambda (_status)
           (funcall callback (sysml2--api-parse-response (current-buffer))))
         nil t)
      (let ((resp-buf (url-retrieve-synchronously full-url t)))
        (when resp-buf
          (prog1 (sysml2--api-parse-response resp-buf)
            (kill-buffer resp-buf)))))))

;; --- Public API Functions ---

(defun sysml2-api-list-projects (&optional callback)
  "List projects from the Systems Modeling API.
If CALLBACK is non-nil, request is async."
  (interactive)
  (let ((response (sysml2--api-request "GET" "/projects" nil callback)))
    (when (and (not callback) response)
      (if (plist-get response :error)
          (message "API error: %s" (plist-get response :error))
        (sysml2--api-display-projects (plist-get response :body)))
      response)))

(defun sysml2-api-get-elements (project-id &optional branch-id callback)
  "Get elements for PROJECT-ID, optionally from BRANCH-ID.
If CALLBACK is non-nil, request is async."
  (interactive
   (list (read-string "Project ID: "
                      (or sysml2-api-project-id ""))))
  (let* ((path (if branch-id
                   (format "/projects/%s/commits/%s/elements"
                           project-id branch-id)
                 (format "/projects/%s/elements" project-id)))
         (response (sysml2--api-request "GET" path nil callback)))
    (when (and (not callback) response)
      (if (plist-get response :error)
          (message "API error: %s" (plist-get response :error))
        (sysml2--api-display-elements (plist-get response :body)))
      response)))

(defun sysml2-api-push-model (project-id &optional file-or-buffer callback)
  "Push model to PROJECT-ID from FILE-OR-BUFFER.
If CALLBACK is non-nil, request is async."
  (interactive
   (list (read-string "Project ID: "
                      (or sysml2-api-project-id ""))))
  (let* ((content (if (bufferp file-or-buffer)
                      (with-current-buffer file-or-buffer
                        (buffer-string))
                    (if file-or-buffer
                        (with-temp-buffer
                          (insert-file-contents file-or-buffer)
                          (buffer-string))
                      (buffer-string))))
         (body `((source . ,content)))
         (path (format "/projects/%s/commits" project-id)))
    (sysml2--api-request "POST" path body callback)))

(defun sysml2-api-pull-model (project-id output-dir &optional callback)
  "Pull model from PROJECT-ID and write files to OUTPUT-DIR.
If CALLBACK is non-nil, request is async."
  (interactive
   (list (read-string "Project ID: "
                      (or sysml2-api-project-id ""))
         (read-directory-name "Output directory: ")))
  (let* ((path (format "/projects/%s/elements" project-id))
         (response (sysml2--api-request "GET" path nil callback)))
    (when (and (not callback) response)
      (if (plist-get response :error)
          (message "API error: %s" (plist-get response :error))
        (let ((elements (plist-get response :body)))
          (when (vectorp elements)
            (make-directory output-dir t)
            (dotimes (i (length elements))
              (let* ((elem (aref elements i))
                     (name (or (cdr (assq 'name elem))
                               (format "element-%d" i)))
                     (file (expand-file-name
                            (concat name ".sysml") output-dir)))
                (with-temp-file file
                  (insert (json-encode elem))))))))
      response)))

(defun sysml2-api-query (project-id query-string &optional callback)
  "Execute QUERY-STRING against PROJECT-ID.
If CALLBACK is non-nil, request is async."
  (interactive
   (list (read-string "Project ID: "
                      (or sysml2-api-project-id ""))
         (read-string "Query: ")))
  (let* ((body `((query . ,query-string)))
         (path (format "/projects/%s/queries" project-id)))
    (sysml2--api-request "POST" path body callback)))

;; --- Display Helpers ---

(defun sysml2--api-display-projects (projects)
  "Display PROJECTS in a dedicated buffer."
  (let ((buf (get-buffer-create "*SysML2 API: Projects*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Systems Modeling API — Projects\n")
        (insert (make-string 40 ?=) "\n\n")
        (if (and projects (vectorp projects))
            (dotimes (i (length projects))
              (let* ((proj (aref projects i))
                     (id (cdr (assq 'id proj)))
                     (name (cdr (assq 'name proj))))
                (insert (format "  %s  %s\n" (or id "?") (or name "unnamed")))))
          (insert "  (no projects)\n"))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buf)))

(defun sysml2--api-display-elements (elements)
  "Display ELEMENTS in a dedicated buffer."
  (let ((buf (get-buffer-create "*SysML2 API: Elements*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Systems Modeling API — Elements\n")
        (insert (make-string 40 ?=) "\n\n")
        (if (and elements (vectorp elements))
            (dotimes (i (length elements))
              (let* ((elem (aref elements i))
                     (id (cdr (assq 'id elem)))
                     (name (cdr (assq 'name elem)))
                     (type (cdr (assq 'type elem))))
                (insert (format "  [%s] %s (%s)\n"
                                (or type "?") (or name "unnamed") (or id "?")))))
          (insert "  (no elements)\n"))
        (goto-char (point-min))
        (special-mode)))
    (display-buffer buf)))

(provide 'sysml2-api)
;;; sysml2-api.el ends here
