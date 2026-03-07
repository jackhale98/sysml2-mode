;;; sysml2-lang.el --- SysML v2 / KerML language data tables -*- lexical-binding: t; -*-

;; Copyright (C) 2026 sysml2-mode contributors
;; Author: sysml2-mode contributors
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))
;; Keywords: languages, systems-engineering, sysml
;; URL: https://github.com/jackhale98/sysml2-mode

;; This file is part of sysml2-mode.
;; SPDX-License-Identifier: GPL-3.0-or-later

;;; Commentary:

;; All SysML v2 / KerML language knowledge as pure data.  This is the
;; ONLY file that changes when the SysML specification changes.  All other
;; modules derive their language knowledge from these constants.

;;; Code:

;;; Public API:
;;
;; Variables:
;;   `sysml2-spec-version' -- Target SysML specification version
;;   `sysml2-kerml-spec-version' -- Target KerML specification version
;;   `sysml2-definition-keywords' -- Definition keywords (two-word forms)
;;   `sysml2-usage-keywords' -- Usage keywords
;;   `sysml2-structural-keywords' -- Package/organizational keywords
;;   `sysml2-behavioral-keywords' -- Behavioral/control flow keywords
;;   `sysml2-relationship-keywords' -- Relationship/constraint keywords
;;   `sysml2-visibility-keywords' -- Visibility modifiers
;;   `sysml2-modifier-keywords' -- Modifier keywords
;;   `sysml2-literal-keywords' -- Literal value keywords
;;   `sysml2-operator-keywords' -- Operator keywords
;;   `sysml2-all-keywords' -- All keywords combined
;;   `sysml2-multi-word-keywords' -- Keywords containing spaces
;;   `sysml2-block-opening-keywords' -- Keywords that precede `{'
;;   `sysml2-standard-library-packages' -- Known library package names
;;   `sysml2-file-extensions' -- File extensions for SysML/KerML

(require 'sysml2-vars)

;; === Specification Version ===

(defconst sysml2-spec-version "2.0"
  "OMG SysML specification version this language data targets.")

(defconst sysml2-kerml-spec-version "1.0"
  "OMG KerML specification version.")

;; === Keyword Categories ===

(defconst sysml2-definition-keywords
  '(;; SysML v2
    "part def" "action def" "state def" "port def" "connection def"
    "attribute def" "item def" "requirement def" "constraint def"
    "view def" "viewpoint def" "rendering def" "concern def"
    "use case def" "analysis def" "verification def"
    "allocation def" "interface def" "flow def"
    "enum def" "occurrence def" "metadata def" "calc def"
    "case def"
    ;; KerML
    "assoc def" "assoc struct def" "behavior def" "class def"
    "classifier def" "connector def" "datatype def" "expr def"
    "feature def" "function def" "interaction def" "metaclass def"
    "namespace def" "predicate def" "step def" "struct def"
    "type def")
  "SysML v2 / KerML definition keywords (multi-word forms ending in `def').")

(defconst sysml2-usage-keywords
  '(;; SysML v2
    "part" "action" "state" "port" "connection" "attribute"
    "item" "requirement" "constraint" "view" "viewpoint"
    "rendering" "concern" "use case" "analysis"
    "verification" "allocation" "interface"
    "flow" "enum" "occurrence" "metadata"
    "calc" "ref" "succession" "binding" "exhibit" "perform"
    "include" "snapshot" "timeslice" "dependency" "expose"
    "case"
    ;; KerML
    "assoc" "behavior" "class" "classifier" "connector"
    "datatype" "expr" "feature" "function" "interaction"
    "metaclass" "namespace" "predicate" "step" "struct" "type")
  "SysML v2 / KerML usage keywords.")

(defconst sysml2-structural-keywords
  '("package" "import" "alias" "comment" "doc" "about" "rep"
    "language" "library" "standard library" "filter"
    "defined" "verify" "via" "allocate")
  "Package and organizational keywords.")

(defconst sysml2-behavioral-keywords
  '("entry" "exit" "do" "first" "then" "accept" "send" "assign"
    "if" "else" "while" "for" "loop" "merge" "decide" "join"
    "fork" "transition" "trigger" "guard" "effect"
    "after" "event" "message" "parallel" "terminate" "until" "when")
  "Behavioral and control flow keywords.")

(defconst sysml2-relationship-keywords
  '("specialization" "subset" "redefines" "references" "chains"
    "conjugates" "inverse" "featured" "typing" "satisfy"
    "assert" "assume" "require" "subject" "objective"
    "stakeholder" "actor" "bind" "connect" "to" "from"
    "end" "all" "default"
    "by" "conjugation" "crosses" "differences" "disjoining"
    "featuring" "intersects" "inverting" "member" "multiplicity"
    "of" "redefinition" "specializes" "subclassifier" "subsets"
    "subtype" "typed" "unions"
    "standard")
  "Relationship and constraint keywords.")

(defconst sysml2-visibility-keywords
  '("public" "private" "protected")
  "Visibility modifiers.")

(defconst sysml2-modifier-keywords
  '("abstract" "variation" "variant" "individual" "readonly"
    "derived" "nonunique" "ordered" "in" "out" "inout" "return"
    "composite" "conjugate" "const" "disjoint" "portion" "var")
  "Modifier keywords.")

(defconst sysml2-literal-keywords
  '("true" "false" "null")
  "Literal value keywords.")

(defconst sysml2-operator-keywords
  '("not" "or" "and" "xor" "implies" "hastype" "istype" "as"
    "meta" "@" "new")
  "Operator and type-test keywords.")

;; === Computed Regexps ===

(defconst sysml2-definition-keywords-regexp
  (regexp-opt sysml2-definition-keywords t)
  "Regexp matching SysML v2 definition keywords.
The regexp uses a capture group for the matched keyword.")

(defconst sysml2-usage-keywords-regexp
  (regexp-opt sysml2-usage-keywords t)
  "Regexp matching SysML v2 usage keywords.")

(defconst sysml2-structural-keywords-regexp
  (regexp-opt sysml2-structural-keywords t)
  "Regexp matching structural/organizational keywords.")

(defconst sysml2-behavioral-keywords-regexp
  (regexp-opt sysml2-behavioral-keywords t)
  "Regexp matching behavioral/control flow keywords.")

(defconst sysml2-relationship-keywords-regexp
  (regexp-opt sysml2-relationship-keywords t)
  "Regexp matching relationship/constraint keywords.")

(defconst sysml2-visibility-keywords-regexp
  (regexp-opt sysml2-visibility-keywords 'words)
  "Regexp matching visibility modifiers.")

(defconst sysml2-modifier-keywords-regexp
  (regexp-opt sysml2-modifier-keywords 'words)
  "Regexp matching modifier keywords.")

(defconst sysml2-literal-keywords-regexp
  (regexp-opt sysml2-literal-keywords 'words)
  "Regexp matching literal value keywords.")

(defconst sysml2-operator-keywords-regexp
  (regexp-opt sysml2-operator-keywords 'words)
  "Regexp matching operator keywords.")

;; === Combined Keywords ===

(defconst sysml2-all-keywords
  (append sysml2-definition-keywords
          sysml2-usage-keywords
          sysml2-structural-keywords
          sysml2-behavioral-keywords
          sysml2-relationship-keywords
          sysml2-visibility-keywords
          sysml2-modifier-keywords
          sysml2-literal-keywords
          sysml2-operator-keywords)
  "All SysML v2 keywords combined.")

(defconst sysml2-all-keywords-regexp
  (regexp-opt sysml2-all-keywords 'words)
  "Regexp matching any SysML v2 keyword.")

;; === Multi-Word Keyword Handling ===

(defconst sysml2-multi-word-keywords
  '(;; SysML v2 definition keywords
    "part def" "action def" "state def" "port def"
    "connection def" "attribute def" "item def"
    "requirement def" "constraint def" "view def"
    "viewpoint def" "rendering def" "concern def"
    "use case def" "analysis def" "verification def"
    "allocation def" "interface def" "flow def"
    "enum def" "occurrence def" "metadata def"
    "calc def" "case def"
    ;; KerML definition keywords
    "assoc def" "assoc struct def" "behavior def" "class def"
    "classifier def" "connector def" "datatype def" "expr def"
    "feature def" "function def" "interaction def" "metaclass def"
    "namespace def" "predicate def" "step def" "struct def"
    "type def"
    ;; Multi-word usage keywords
    "use case"
    ;; Other multi-word
    "standard library")
  "Keywords that contain spaces.
Must be matched before single-word keywords in font-lock rules.")

(defconst sysml2-multi-word-keywords-regexp
  (regexp-opt sysml2-multi-word-keywords t)
  "Regexp for multi-word keywords.
Match BEFORE single-word keywords to prevent partial matches.")

;; === Block-Opening Keywords ===

(defconst sysml2-block-opening-keywords
  '("package" "part def" "action def" "state def" "port def"
    "connection def" "attribute def" "item def"
    "requirement def" "constraint def" "view def"
    "viewpoint def" "rendering def" "concern def"
    "use case def" "analysis def" "verification def"
    "allocation def" "interface def" "enum def"
    "occurrence def" "metadata def" "calc def" "flow def"
    "case def"
    ;; KerML definition keywords
    "assoc def" "assoc struct def" "behavior def" "class def"
    "classifier def" "connector def" "datatype def" "expr def"
    "feature def" "function def" "interaction def" "metaclass def"
    "namespace def" "predicate def" "step def" "struct def"
    "type def"
    ;; Usage keywords
    "part" "action" "state" "port" "connection"
    "attribute" "item" "requirement" "constraint"
    "view" "viewpoint" "rendering" "concern"
    "use case" "analysis" "verification"
    "allocation" "interface" "enum" "occurrence"
    "metadata" "calc" "ref" "flow"
    ;; KerML usage keywords
    "assoc" "behavior" "class" "classifier" "connector"
    "datatype" "feature" "function" "interaction"
    "metaclass" "namespace" "predicate" "step" "struct" "type")
  "Keywords that can precede a `{' to open a body block.")

(defconst sysml2-block-opening-keywords-regexp
  (regexp-opt sysml2-block-opening-keywords t)
  "Regexp matching keywords that can open blocks.")

;; === Operators and Punctuation ===

(defconst sysml2-operators
  '(":>" ":>>" "~" "::" "." ".." "==" "!=" "<" ">" "<=" ">="
    "+" "-" "*" "/" "%" "**" "," ";" "=" ":=" "??"
    "->" "#" "[" "]" "{" "}" "(" ")"
    "@@" "::>" "=>" "===" "!==" ".?" "^" "|" "&" "$")
  "SysML v2 operators and punctuation characters.")

;; === File Extensions ===

(defconst sysml2-file-extensions '("sysml" "kerml")
  "File extensions for SysML v2 and KerML files.")

;; === Standard Library Packages ===

(defconst sysml2-standard-library-packages
  '("Base" "ScalarValues" "Collections" "ControlPerformances"
    "TransitionPerformances" "Occurrences" "Objects" "Items"
    "Parts" "Ports" "Connections" "Interfaces" "Allocations"
    "Actions" "Calculations" "Constraints" "Requirements"
    "Cases" "AnalysisCases" "VerificationCases" "UseCases"
    "Views" "Metadata" "StatePerformances"
    "ISQ" "SI" "USCustomaryUnits"
    "Quantities" "MeasurementReferences" "TriggerActions"
    "SysML"
    ;; KerML packages
    "Performances" "Features" "Classifiers" "KerML" "Enumerations"
    "Events" "Messages" "Geometries" "SpatialFrames" "Transfers"
    ;; Function library packages
    "BaseFunctions" "BooleanFunctions" "IntegerFunctions"
    "NaturalFunctions" "NumericalFunctions" "RationalFunctions"
    "RealFunctions" "ComplexFunctions" "StringFunctions"
    "CollectionFunctions" "ControlFunctions" "TrigFunctions"
    "SequenceFunctions" "DataFunctions"
    ;; Other
    "Links" "Clocks" "Observation")
  "Known standard library package names for completion.")

;; === Definition Name Pattern ===

(defconst sysml2--identifier-regexp
  "[A-Za-z_][A-Za-z0-9_]*"
  "Regexp matching a SysML v2 identifier.")

(defconst sysml2--qualified-name-regexp
  "[A-Za-z_][A-Za-z0-9_:.*]*"
  "Regexp matching a SysML v2 qualified name (with :: separators).")

(provide 'sysml2-lang)
;;; sysml2-lang.el ends here
