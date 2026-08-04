
;; --- Book-review extraction additions (multi-line, messages, metadata,
;; variants, satisfy forms) ---

(ert-deftest sysml2-test-model-multiline-connect ()
  "Connections wrapping across lines must extract (book Ch 29 style)."
  (with-temp-buffer
    (insert "part def S {\n    connect powerSystem\n        to battery;\n}\n")
    (sysml2-mode)
    (let ((conns (sysml2--model-extract-connections)))
      (should (equal (plist-get (car conns) :source) "powerSystem"))
      (should (equal (plist-get (car conns) :target) "battery")))))

(ert-deftest sysml2-test-model-flow-shorthand-and-typed ()
  "`flow a.b to c.d;` shorthand and typed flows must extract."
  (with-temp-buffer
    (insert "part def S {\n    flow heat : HeatFlow from e.out\n        to r.in;\n    flow coolant.out to pump.in;\n}\n")
    (sysml2-mode)
    (let ((flows (sysml2--model-extract-flows)))
      (should (= (length flows) 2))
      (should (equal (plist-get (nth 0 flows) :name) "heat"))
      (should (equal (plist-get (nth 1 flows) :source) "coolant.out")))))

(ert-deftest sysml2-test-model-message-extraction ()
  "Message usages (Ch 29) must extract with item and endpoints."
  (with-temp-buffer
    (insert "part def S {\n    message heatExchange of HeatEnergy from a.p to b.q;\n    message of Light from sun to panel;\n}\n")
    (sysml2-mode)
    (let ((msgs (sysml2--model-extract-messages)))
      (should (= (length msgs) 2))
      (should (equal (plist-get (nth 0 msgs) :item) "HeatEnergy"))
      (should (equal (plist-get (nth 1 msgs) :name) ""))
      (should (equal (plist-get (nth 1 msgs) :item) "Light")))))

(ert-deftest sysml2-test-model-variant-extraction ()
  "Untyped variant parts (Ch 35) must extract with :variant t."
  (with-temp-buffer
    (insert "variation part def BatteryChoice {\n    variant part standardBattery;\n    variant part powerBattery : PowerBattery;\n}\n")
    (sysml2-mode)
    (let* ((parts (sysml2--model-extract-part-usages))
           (variants (seq-filter (lambda (p) (plist-get p :variant)) parts)))
      (should (= (length variants) 2))
      (should (member "standardBattery"
                      (mapcar (lambda (p) (plist-get p :name)) variants))))))

(ert-deftest sysml2-test-model-metadata-extraction ()
  "Metadata annotations (Ch 36) must extract values and targets."
  (with-temp-buffer
    (insert "part def Engine {\n    @Status { status = StatusKind::draft; owner = \"Jo\"; }\n}\n")
    (sysml2-mode)
    (let* ((metas (sysml2--model-extract-metadata))
           (m (car metas)))
      (should (equal (plist-get m :type) "Status"))
      (should (equal (cdr (assoc "status" (plist-get m :values)))
                     "StatusKind::draft"))
      (should (equal (plist-get m :target) "Engine")))))

(ert-deftest sysml2-test-model-satisfy-without-by ()
  "`satisfy X;` without a by-clause (Ch 32) must extract."
  (with-temp-buffer
    (insert "part def Battery {\n    satisfy DSRE::uavFlightTime;\n}\n")
    (sysml2-mode)
    (let ((sats (sysml2--model-extract-satisfactions)))
      (should (equal (plist-get (car sats) :requirement) "DSRE::uavFlightTime"))
      (should (null (plist-get (car sats) :by))))))

(ert-deftest sysml2-test-model-semicolon-def-no-absorption ()
  "`part def X;` must not absorb the following definition's body."
  (with-temp-buffer
    (insert "part def Capsule;\npart def Mission {\n    part lander : Lander;\n}\n")
    (sysml2-mode)
    (let* ((defs (sysml2--model-extract-part-defs))
           (capsule (seq-find (lambda (d) (equal (plist-get d :name) "Capsule")) defs)))
      (should capsule)
      (should (null (plist-get capsule :parts))))))
