;;; test-api.el --- API client tests for sysml2-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; ERT tests for sysml2-api.el.  Tests verify request construction
;; and JSON parsing without making real HTTP requests.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'sysml2-mode)
(require 'sysml2-api)

;; --- URL Construction ---

(ert-deftest sysml2-test-api-url-construction ()
  "Test that base URL and path are correctly joined."
  (let ((sysml2-api-base-url "http://localhost:9000"))
    (should (equal (sysml2--api-url "/projects")
                   "http://localhost:9000/projects")))
  ;; Trailing slash on base URL is stripped
  (let ((sysml2-api-base-url "http://localhost:9000/"))
    (should (equal (sysml2--api-url "/projects")
                   "http://localhost:9000/projects"))))

(ert-deftest sysml2-test-api-url-no-base ()
  "Test that user-error is signaled when base URL is nil."
  (let ((sysml2-api-base-url nil))
    (should-error (sysml2--api-url "/projects") :type 'user-error)))

;; --- Headers ---

(ert-deftest sysml2-test-api-headers-basic ()
  "Test that Content-Type header is present."
  (let ((sysml2--api-auth-token nil))
    (let ((headers (sysml2--api-headers)))
      (should (assoc "Content-Type" headers))
      (should (equal (cdr (assoc "Content-Type" headers))
                     "application/json")))))

(ert-deftest sysml2-test-api-headers-with-auth ()
  "Test that Authorization header is present when token is set."
  (let ((sysml2--api-auth-token "test-token-123"))
    (let ((headers (sysml2--api-headers)))
      (should (assoc "Authorization" headers))
      (should (equal (cdr (assoc "Authorization" headers))
                     "Bearer test-token-123")))))

;; --- Response Parsing ---

(ert-deftest sysml2-test-api-parse-response-success ()
  "Test parsing a mock 200 response with JSON body."
  (with-temp-buffer
    (insert "HTTP/1.1 200 OK\nContent-Type: application/json\n\n")
    (insert "[{\"id\":\"p1\",\"name\":\"Project 1\"}]")
    (let ((result (sysml2--api-parse-response (current-buffer))))
      (should (= (plist-get result :status) 200))
      (should (null (plist-get result :error)))
      (should (vectorp (plist-get result :body)))
      (should (equal (cdr (assq 'id (aref (plist-get result :body) 0)))
                     "p1")))))

(ert-deftest sysml2-test-api-parse-response-error ()
  "Test parsing a mock 404 response."
  (with-temp-buffer
    (insert "HTTP/1.1 404 Not Found\nContent-Type: application/json\n\n")
    (insert "{\"error\":\"not found\"}")
    (let ((result (sysml2--api-parse-response (current-buffer))))
      (should (= (plist-get result :status) 404))
      (should (string-match-p "HTTP 404" (plist-get result :error))))))

;; --- Request Construction (mocked HTTP) ---

(ert-deftest sysml2-test-api-list-projects-request ()
  "Test that list-projects sends GET /projects."
  (let ((captured-method nil)
        (captured-url nil)
        (sysml2-api-base-url "http://test:9000"))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (url &rest _args)
                 (setq captured-url url)
                 (let ((buf (generate-new-buffer " *mock-response*")))
                   (with-current-buffer buf
                     (insert "HTTP/1.1 200 OK\n\n[]"))
                   buf))))
      (sysml2-api-list-projects))
    (should (string-match-p "/projects$" captured-url))))

(ert-deftest sysml2-test-api-query-request-body ()
  "Test that query sends POST with query body."
  (let ((captured-data nil)
        (sysml2-api-base-url "http://test:9000"))
    (cl-letf (((symbol-function 'url-retrieve-synchronously)
               (lambda (_url &rest _args)
                 (setq captured-data url-request-data)
                 (let ((buf (generate-new-buffer " *mock-response*")))
                   (with-current-buffer buf
                     (insert "HTTP/1.1 200 OK\n\n{}"))
                   buf))))
      (sysml2-api-query "proj1" "select * from elements"))
    (should captured-data)
    (let ((parsed (json-read-from-string captured-data)))
      (should (equal (cdr (assq 'query parsed))
                     "select * from elements")))))

(provide 'test-api)
;;; test-api.el ends here
