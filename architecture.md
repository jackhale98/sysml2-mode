# SysML v2 Emacs Major Mode — Architecture & Implementation Plan

**Project:** `sysml2-mode` — A full-featured Emacs major mode for the OMG SysML v2.0 / KerML 1.0 textual notation
**Version:** 0.1.0 (Initial Architecture)
**Date:** February 2026
**Target Emacs:** 29.1+ (tree-sitter native), 30.x recommended
**License:** GPL-3.0-or-later (compatible with Emacs ecosystem)

> **For AI Code Generation**: This document provides domain context, research findings, and architectural rationale. The companion document **`sysml2-mode-ai-spec.md`** contains the concrete, file-by-file generation instructions. When generating code, use the AI spec as the primary instruction set and this document as reference. When in conflict, the AI spec governs.

---

## 1. Executive Summary

SysML v2, formally adopted by OMG in July 2025 and published September 2025, represents a generational leap in systems modeling. It introduces a first-class **textual notation** alongside graphical syntax, built atop the Kernel Modeling Language (KerML). This creates a natural opportunity for a text-editor-native development experience.

This document defines the architecture for `sysml2-mode`, an Emacs major mode that brings feature parity with (and in some cases exceeds) the VS Code SysIDE/Syside Editor ecosystem, while leveraging Emacs-native strengths: org-mode integration, extensible Lisp architecture, and the PlantUML ecosystem for diagram generation.

The long-term vision extends to FMI/FMU co-simulation orchestration, Modelica interoperability, and hardware-in-the-loop (HIL) simulation management — enabling full virtual system and requirement validation from within Emacs.

---

## 2. Landscape Analysis

### 2.1 SysML v2 Language Overview

SysML v2.0 is built on a layered architecture:

- **KerML 1.0** (Kernel Modeling Language): Application-independent formal semantics foundation with direct mapping to formal logic. File extension: `.kerml`
- **SysML v2.0**: Systems engineering adaptation built on KerML with domain-specific constructs. File extension: `.sysml`
- **Systems Modeling API & Services 1.0**: Standard REST/OSLC API for tool interoperability (CRUD on model elements, versioning, branching)

The textual notation uses a definition/usage pattern consistently across all constructs:

| Definition Keyword | Usage Keyword | Domain |
|---|---|---|
| `part def` | `part` | Structure |
| `action def` | `action` | Behavior (function-based) |
| `state def` | `state` | Behavior (state-based) |
| `port def` | `port` | Interfaces |
| `connection def` | `connection` | Relationships |
| `attribute def` | `attribute` | Properties |
| `requirement def` | `requirement` | Requirements |
| `constraint def` | `constraint` | Constraints |
| `view def` | `view` | Views & Viewpoints |
| `use case def` | `use case` | Use Cases |
| `item def` | `item` | Items |
| `allocation def` | `allocation` | Allocation |
| `analysis case def` | `analysis case` | Analysis |
| `verification case def` | `verification case` | Verification |
| `concern def` | `concern` | Stakeholder concerns |
| `viewpoint def` | `viewpoint` | Viewpoints |
| `rendering def` | `rendering` | Rendering specifications |
| `enumeration def` | `enumeration` | Enumerations |
| `occurrence def` | `occurrence` | Occurrences |
| `interface def` | `interface` | Interfaces |
| `flow connection def` | `flow connection` | Flows |
| `succession` | `succession` | Temporal ordering |
| `metadata def` | `metadata` | Language extension |
| `calc def` | `calc` | Calculations |

Additional keywords include: `package`, `import`, `alias`, `specialization`, `subset`, `redefines`, `ref`, `in`, `out`, `inout`, `end`, `perform`, `exhibit`, `include`, `first`, `then`, `accept`, `send`, `assign`, `if`, `else`, `while`, `for`, `loop`, `merge`, `decide`, `join`, `fork`, `comment`, `doc`, `about`, `rep`, `language`, `abstract`, `variation`, `variant`, `individual`, `snapshot`, `timeslice`, `dependency`, `expose`, `satisfy`, `assert`, `assume`, `require`, `subject`, `objective`, `stakeholder`, `actor`, `filter`, `bind`, `public`, `private`, `protected`, `readonly`, `derived`, `nonunique`, `ordered`, `return`, `true`, `false`, `null`, `not`, `or`, `and`, `xor`, `implies`, `hastype`, `istype`, `as`, `all`, `from`, `to`, `default`.

### 2.2 Existing VS Code Tooling (Feature Parity Targets)

The primary open-source VS Code extension is **Syside Editor** (by Sensmetry), successor to the now-deprecated SysIDE Editor Legacy. Key features to match or exceed:

1. **Syntax & semantic checking** — Real-time error detection
2. **Semantic highlighting** — Context-aware colorization (definitions vs. usages, types vs. instances)
3. **Autocompletion** — Keyword, type reference, and member completion
4. **Go-to-definition / Find references** — Cross-file navigation
5. **Outline / document symbols** — Hierarchical model structure view
6. **Hover information** — Type and documentation tooltips
7. **Code folding** — Block-level folding
8. **Rename refactoring** — Safe symbol renaming across files
9. **Standard library bundling** — Ships with the SysML v2 standard library
10. **Diagnostics** — Well-formedness constraint checking

Other tools: Astah SysMLv2 Editor (commercial, closed), Ellidiss SysML extension (limited), EDKarlsson Langium-based prototype.

### 2.3 Visualization Ecosystem

The SysML v2 Pilot Implementation uses **PlantUML with SysML v2 extensions** for diagram generation. The extended PlantUML supports:

- **Tree (BDD-like) diagrams** — Part definition hierarchies
- **Interconnection (IBD-like) diagrams** — Port and connection views
- **State machine diagrams** — State transition visualization
- **Action flow diagrams** — Behavioral decomposition

PlantUML is already well-integrated with Emacs via `plantuml-mode` (MELPA), `ob-plantuml` (org-babel), and supports multiple execution modes (jar, executable, server).

GraphViz is a prerequisite for non-trivial PlantUML diagrams.

### 2.4 FMI/FMU/Modelica Landscape

The Functional Mock-up Interface (FMI) is a Modelica Association standard for model exchange and co-simulation. Key facts:

- **FMI 3.0** is the current version; supported by 270+ tools
- An FMU (Functional Mock-up Unit) is a `.fmu` ZIP file containing: XML model description, C binaries/source, and optional data
- **OpenModelica** provides open-source FMU import/export via `buildModelFMU()` and `importFMU()`
- **System Structure and Parameterization (SSP)** is the companion standard for describing co-simulation architectures
- The workflow: SysML v2 model → extract interface contracts → generate Modelica partial models → supplier fills implementation → export FMU → co-simulate

---

## 3. Architecture

### 3.1 Design Principles

1. **Layered & Modular**: Each feature (highlighting, indentation, LSP, diagrams, simulation) is an independent module with clean interfaces. Users can enable/disable features individually.
2. **Grammar-Driven Extensibility**: Language keywords, syntax rules, and semantic categories are defined in data tables (not hardcoded in logic) to absorb SysML v2 specification changes with minimal code edits.
3. **Dual-Engine**: Support both regex-based (`font-lock`) and tree-sitter-based modes. The tree-sitter mode is preferred but the regex mode ensures Emacs 28.x compatibility.
4. **LSP-First for Semantics**: Offload semantic analysis (type checking, cross-file resolution, well-formedness constraints) to language servers. The mode focuses on editing ergonomics.
5. **Emacs-Native Integration**: Leverage existing Emacs infrastructure (eglot/lsp-mode, org-babel, compile, project.el, flymake/flycheck) rather than reinventing.
6. **Progressive Enhancement**: Start with core editing, add LSP integration, then visualization, then simulation orchestration in phases.

### 3.2 Module Map

```
sysml2-mode/
├── sysml2-mode.el              # Entry point, mode definition, autoloads
├── sysml2-vars.el              # ALL customizable variables (defcustom)
├── sysml2-lang.el              # Language data tables (keywords, operators, grammar metadata)
├── sysml2-font-lock.el         # Regex-based font-lock rules
├── sysml2-ts.el                # Tree-sitter font-lock, indentation, navigation
├── sysml2-indent.el            # Indentation engine (shared logic)
├── sysml2-completion.el        # Keyword + context-aware completion (capf)
├── sysml2-navigation.el        # imenu, outline, xref, which-function
├── sysml2-lsp.el               # LSP client configuration (eglot + lsp-mode)
├── sysml2-flymake.el           # Flymake backend for diagnostics
├── sysml2-plantuml.el          # SysML v2 → PlantUML transformation & preview
├── sysml2-diagram.el           # Diagram dispatch (PlantUML, SVG, export)
├── sysml2-api.el               # Systems Modeling API client (REST)
├── sysml2-project.el           # Project management, library path resolution
├── sysml2-snippets.el          # Yasnippet templates for common patterns
├── sysml2-fmi.el               # FMI/FMU integration (future Phase 4)
├── sysml2-cosim.el             # Co-simulation orchestration (future Phase 4)
├── tree-sitter-sysml/          # Tree-sitter grammar (JavaScript/C)
│   ├── grammar.js
│   ├── src/
│   └── queries/
│       ├── highlights.scm      # Syntax highlighting queries
│       ├── indents.scm         # Indentation queries
│       ├── folds.scm           # Code folding queries
│       └── locals.scm          # Scope/reference queries
├── snippets/                   # Yasnippet snippet files
│   └── sysml2-mode/
├── standard-library/           # Bundled SysML v2 standard library (.sysml files)
│   ├── Kernel Library/
│   ├── Systems Library/
│   ├── Domain Libraries/
│   └── Quantities and Units/
├── test/                       # ERT test suite
│   ├── test-font-lock.el
│   ├── test-indent.el
│   ├── test-completion.el
│   ├── test-plantuml.el
│   └── fixtures/               # Sample .sysml / .kerml files
└── doc/
    ├── sysml2-mode.texi        # Texinfo manual
    └── CHANGELOG.md
```

### 3.3 Data-Driven Language Specification (`sysml2-lang.el`)

This is the **key architectural decision for maintainability**. All language knowledge is centralized here and consumed by all other modules:

```elisp
;;; sysml2-lang.el --- SysML v2 / KerML language data tables -*- lexical-binding: t; -*-

;; Specification version this data targets
(defconst sysml2-spec-version "2.0"
  "OMG SysML specification version this language data targets.")

(defconst sysml2-kerml-spec-version "1.0"
  "OMG KerML specification version.")

;; === KEYWORD CATEGORIES ===
;; When the spec changes, update ONLY these tables.

(defconst sysml2-definition-keywords
  '("part def" "action def" "state def" "port def" "connection def"
    "attribute def" "item def" "requirement def" "constraint def"
    "view def" "viewpoint def" "rendering def" "concern def"
    "use case def" "analysis case def" "verification case def"
    "allocation def" "interface def" "flow connection def"
    "enumeration def" "occurrence def" "metadata def" "calc def"
    "succession flow connection def")
  "SysML v2 definition keywords (two-word forms).")

(defconst sysml2-usage-keywords
  '("part" "action" "state" "port" "connection" "attribute"
    "item" "requirement" "constraint" "view" "viewpoint"
    "rendering" "concern" "use case" "analysis case"
    "verification case" "allocation" "interface"
    "flow connection" "enumeration" "occurrence" "metadata"
    "calc" "ref" "succession" "binding" "exhibit" "perform"
    "include" "snapshot" "timeslice" "dependency" "expose")
  "SysML v2 usage keywords.")

(defconst sysml2-structural-keywords
  '("package" "import" "alias" "comment" "doc" "about" "rep"
    "language" "library" "standard library" "filter")
  "Package and organizational keywords.")

(defconst sysml2-behavioral-keywords
  '("entry" "exit" "do" "first" "then" "accept" "send" "assign"
    "if" "else" "while" "for" "loop" "merge" "decide" "join"
    "fork" "transition" "trigger" "guard" "effect")
  "Behavioral / control flow keywords.")

(defconst sysml2-relationship-keywords
  '("specialization" "subset" "redefines" "references" "chains"
    "conjugates" "inverse" "featured" "typing" "satisfy"
    "assert" "assume" "require" "subject" "objective"
    "stakeholder" "actor" "bind" "connect" "to" "from"
    "end" "all" "default")
  "Relationship and constraint keywords.")

(defconst sysml2-visibility-keywords
  '("public" "private" "protected")
  "Visibility modifiers.")

(defconst sysml2-modifier-keywords
  '("abstract" "variation" "variant" "individual" "readonly"
    "derived" "nonunique" "ordered" "in" "out" "inout" "return")
  "Modifier keywords.")

(defconst sysml2-literal-keywords
  '("true" "false" "null")
  "Literal value keywords.")

(defconst sysml2-operator-keywords
  '("not" "or" "and" "xor" "implies" "hastype" "istype" "as"
    "meta" "@")
  "Operator and type-test keywords.")

(defconst sysml2-operators
  '(":>" ":>>" "~" "::" "." ".." "==" "!=" "<" ">" "<=" ">="
    "+" "-" "*" "/" "%" "**" ".." "," ";" "=" ":=" "??"
    "->" "#" "[" "]" "{" "}" "(" ")" "<" ">")
  "SysML v2 operators and punctuation.")

;; === FILE EXTENSIONS ===
(defconst sysml2-file-extensions '("sysml" "kerml")
  "File extensions for SysML v2 and KerML files.")

;; === STANDARD LIBRARY PACKAGES ===
(defconst sysml2-standard-library-packages
  '("Base" "ScalarValues" "Collections" "ControlPerformances"
    "TransitionPerformances" "Occurrences" "Objects" "Items"
    "Parts" "Ports" "Connections" "Interfaces" "Allocations"
    "Actions" "Calculations" "Constraints" "Requirements"
    "Cases" "AnalysisCases" "VerificationCases" "UseCases"
    "Views" "Metadata" "StatePerformances"
    "ISQ" "SI" "USCustomaryUnits"
    "Quantities" "MeasurementReferences" "TriggerActions"
    "SysML")
  "Known standard library package names for completion.")
```

**Rationale**: When OMG publishes SysML v2.1 or errata, a developer only needs to edit `sysml2-lang.el`. All font-lock rules, completion tables, and snippets derive from these constants via computed regexps.

### 3.4 Font-Lock Architecture (Regex Fallback)

`sysml2-font-lock.el` computes font-lock keywords from the data tables:

```elisp
;; Computed at load time from sysml2-lang.el
(defvar sysml2-font-lock-keywords
  (let ((def-kw-re (regexp-opt sysml2-definition-keywords 'words))
        (usage-kw-re (regexp-opt sysml2-usage-keywords 'words))
        (struct-kw-re (regexp-opt sysml2-structural-keywords 'words))
        (behav-kw-re (regexp-opt sysml2-behavioral-keywords 'words))
        (vis-kw-re (regexp-opt sysml2-visibility-keywords 'words))
        (mod-kw-re (regexp-opt sysml2-modifier-keywords 'words))
        (literal-kw-re (regexp-opt sysml2-literal-keywords 'words)))
    `(;; Multi-word definition keywords (must come first)
      (,def-kw-re . font-lock-keyword-face)
      ;; Definition name capture: "part def FooBar"
      (,(concat "\\(?:" def-kw-re "\\)\\s-+\\([A-Za-z_][A-Za-z0-9_]*\\)")
       (1 font-lock-type-face))
      ;; Usage keywords
      (,usage-kw-re . font-lock-keyword-face)
      ;; Usage name capture: "part myPart : PartType"
      (,(concat "\\(?:" usage-kw-re "\\)\\s-+\\([A-Za-z_][A-Za-z0-9_]*\\)")
       (1 font-lock-variable-name-face))
      ;; Type references after ':'
      (":\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)" (1 font-lock-type-face))
      ;; Specialization ':>'
      (":>\\s-*\\([A-Za-z_][A-Za-z0-9_:]*\\)" (1 font-lock-type-face))
      ;; Structural keywords
      (,struct-kw-re . font-lock-builtin-face)
      ;; Behavioral keywords
      (,behav-kw-re . font-lock-keyword-face)
      ;; Visibility
      (,vis-kw-re . font-lock-preprocessor-face)
      ;; Modifiers
      (,mod-kw-re . font-lock-keyword-face)
      ;; Literals
      (,literal-kw-re . font-lock-constant-face)
      ;; Numeric literals
      ("\\b[0-9]+\\.?[0-9]*\\(?:[eE][+-]?[0-9]+\\)?\\b" . font-lock-constant-face)
      ;; String literals
      ("\"[^\"]*\"" . font-lock-string-face)
      ;; Short name identifiers: <R1>, <'name'>
      ("<[^>]+>" . font-lock-reference-face)
      ;; Comments: // line and /* block */
      ("/\\*\\(?:[^*]\\|\\*[^/]\\)*\\*/" . font-lock-comment-face)
      ("//.*$" . font-lock-comment-face)
      ;; doc comments
      ("\\bdoc\\b\\s-+/\\*\\(?:[^*]\\|\\*[^/]\\)*\\*/" . font-lock-doc-face)
      ;; Annotation / metadata: #
      ("#\\([A-Za-z_][A-Za-z0-9_:]*\\)" (1 font-lock-preprocessor-face)))))
```

### 3.5 Tree-Sitter Architecture (Primary Path)

#### 3.5.1 Grammar Development (`tree-sitter-sysml/`)

A custom tree-sitter grammar must be developed since none exists for SysML v2. The grammar will be based on the normative BNF extracted from the SysML v2 specification (the Pilot Implementation includes a BNF Extractor tool in `tool-support/bnf-grammar`).

Key grammar design decisions:

- **Two grammars**: `tree-sitter-sysml` for `.sysml` files and `tree-sitter-kerml` for `.kerml` files, since the textual notations differ (SysML's is fully redefined from KerML's)
- **External scanner** for context-sensitive tokens (e.g., multi-word keywords like `part def`, and the `/*  */` / `//` comment disambiguation)
- **Error recovery**: Aggressive use of tree-sitter's error recovery to maintain a useful parse tree even with syntax errors (critical for editor use)

The highlight queries (`highlights.scm`) map tree-sitter node types to Emacs faces:

```scheme
;; highlights.scm (SysML v2)
;; Definition keywords
["part def" "action def" "state def" "port def"
 "connection def" "attribute def" "requirement def"
 "constraint def" "view def" "use case def"
 "analysis case def" "verification case def"
 "interface def" "allocation def" "enumeration def"
 "calc def" "metadata def"] @keyword

;; Usage keywords
["part" "action" "state" "port" "connection"
 "attribute" "item" "requirement" "constraint"
 "view" "ref"] @keyword

;; Control flow
["if" "else" "while" "for" "loop"
 "first" "then" "accept" "send"
 "fork" "join" "merge" "decide"] @keyword

;; Visibility
["public" "private" "protected"] @keyword.modifier

;; Definition names
(part_definition name: (identifier) @type.definition)
(action_definition name: (identifier) @type.definition)
;; ... etc for all definition types

;; Usage names
(part_usage name: (identifier) @variable)
(action_usage name: (identifier) @variable)

;; Type references
(typed_by type: (qualified_name) @type)
(specialization general: (qualified_name) @type)

;; Literals
(integer_literal) @number
(real_literal) @number
(string_literal) @string
(boolean_literal) @constant.builtin

;; Comments
(line_comment) @comment
(block_comment) @comment
(documentation_comment) @comment.documentation

;; Operators
[":>" ":>>" "~" "::" "==" "!=" "<=" ">="] @operator
```

#### 3.5.2 Emacs Tree-Sitter Integration (`sysml2-ts.el`)

```elisp
(require 'treesit)

(defvar sysml2-ts--font-lock-settings
  (treesit-font-lock-rules
   :language 'sysml
   :feature 'comment
   '((line_comment) @font-lock-comment-face
     (block_comment) @font-lock-comment-face
     (documentation_comment) @font-lock-doc-face)

   :language 'sysml
   :feature 'keyword
   '(["package" "import" "part" "part def" "action" "action def"
      "state" "state def" "port" "port def" "connection"
      "connection def" "attribute" "attribute def" "requirement"
      "requirement def" "constraint" "constraint def"
      ;; ... all keywords
      ] @font-lock-keyword-face)

   :language 'sysml
   :feature 'definition
   '((part_definition name: (identifier) @font-lock-type-face)
     (action_definition name: (identifier) @font-lock-type-face)
     ;; ... all definition types
     )

   :language 'sysml
   :feature 'type
   '((typed_by type: (qualified_name) @font-lock-type-face)
     (specialization_part general: (qualified_name) @font-lock-type-face))

   :language 'sysml
   :feature 'literal
   '((integer_literal) @font-lock-constant-face
     (real_literal) @font-lock-constant-face
     (string_literal) @font-lock-string-face
     (boolean_literal) @font-lock-constant-face)))

(defvar sysml2-ts--indent-rules
  `((sysml
     ;; Top level: no indent
     ((parent-is "source_file") column-0 0)
     ;; Inside braces: indent
     ((node-is "}") parent-bol 0)
     ((parent-is "body") parent-bol ,sysml2-indent-offset)
     ((parent-is "package_body") parent-bol ,sysml2-indent-offset)
     ;; Continuation lines
     ((parent-is "membership") parent-bol ,sysml2-indent-offset)
     ;; Default
     (no-node parent-bol 0))))
```

### 3.6 LSP Integration (`sysml2-lsp.el`)

The mode supports both `eglot` (built-in Emacs 29+) and `lsp-mode` (third-party). The primary language server target is the Syside language server (Sensmetry), with fallback to the SysML v2 Pilot Implementation's Xtext-based server.

```elisp
;;; eglot configuration
(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
               '((sysml2-mode sysml2-ts-mode kerml-mode)
                 . ("syside-lsp" "--stdio")))
  ;; Alternative: Pilot Implementation server
  ;; '((sysml2-mode) . ("java" "-jar" "/path/to/sysml-interactive.jar"
  ;;                     "--lsp" "--stdio"))
  )

;;; lsp-mode configuration
(with-eval-after-load 'lsp-mode
  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection '("syside-lsp" "--stdio"))
    :major-modes '(sysml2-mode sysml2-ts-mode kerml-mode)
    :server-id 'syside
    :priority 1
    :initialization-options
    '(:sysml (:standardLibraryPath nil))))) ;; use bundled
```

### 3.7 PlantUML Diagram Generation (`sysml2-plantuml.el`)

This is the core visualization subsystem. It transforms SysML v2 textual notation into PlantUML syntax for diagram generation.

#### 3.7.1 Transformation Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌────────────────┐
│ .sysml buffer    │───>│ sysml2-plantuml  │───>│ PlantUML       │
│ (source text)    │    │ transformer      │    │ (jar/server)   │
└─────────────────┘    └──────────────────┘    └────────────────┘
                              │                        │
                    ┌─────────┴──────────┐            │
                    │ Diagram Type       │            ▼
                    │ Dispatcher:        │    ┌────────────────┐
                    │ • tree (BDD)       │    │ Output:        │
                    │ • interconnect(IBD)│    │ • PNG/SVG/PDF  │
                    │ • state-machine    │    │ • Inline Emacs │
                    │ • action-flow      │    │ • Org embed    │
                    │ • requirement-tree │    │ • File export  │
                    │ • use-case         │    └────────────────┘
                    └────────────────────┘
```

#### 3.7.2 Supported Diagram Types

1. **Part Definition Tree (BDD-like)**: Extracts `part def` hierarchies and specialization relationships, renders as PlantUML class diagrams with SysML stereotypes
2. **Interconnection (IBD-like)**: Extracts `part` usages, `port` definitions, and `connection` usages within a containing part, renders as PlantUML component diagrams
3. **State Machine**: Extracts `state def` / `state` with transitions, renders as PlantUML state diagrams
4. **Action Flow**: Extracts `action def` / `action` with `first`/`then` succession, renders as PlantUML activity diagrams
5. **Requirement Tree**: Extracts `requirement def` hierarchies and `satisfy` / `verify` relationships
6. **Use Case Diagram**: Extracts `use case def`, `actor`, `subject`, and `include` relationships

#### 3.7.3 Key Commands

| Command | Binding | Description |
|---|---|---|
| `sysml2-diagram-preview` | `C-c C-d p` | Preview diagram for element at point |
| `sysml2-diagram-preview-buffer` | `C-c C-d b` | Preview entire buffer as tree diagram |
| `sysml2-diagram-export` | `C-c C-d e` | Export to file (PNG/SVG/PDF) |
| `sysml2-diagram-type` | `C-c C-d t` | Select diagram type |
| `sysml2-diagram-open-plantuml` | `C-c C-d o` | Open generated PlantUML in buffer |
| `sysml2-diagram-org-embed` | `C-c C-d i` | Insert as org-babel block |

#### 3.7.4 Org-Babel Integration

```org
#+begin_src sysml :file vehicle-bdd.svg :diagram-type tree
package Vehicle {
    part def Vehicle {
        part engine : Engine;
        part transmission : Transmission;
    }
    part def Engine;
    part def Transmission;
}
#+end_src
```

The `ob-sysml` backend:
1. Parses the SysML v2 source
2. Transforms to PlantUML via `sysml2-plantuml.el`
3. Invokes PlantUML to generate the image
4. Returns the file link for org embedding

### 3.8 Systems Modeling API Client (`sysml2-api.el`)

Interface with SysML v2 model repositories via the standard REST API:

```elisp
;; Core API operations
(defun sysml2-api-list-projects ()
  "List projects on the configured repository.")

(defun sysml2-api-get-elements (project-id &optional branch-id)
  "Retrieve model elements from a repository project.")

(defun sysml2-api-push-model (project-id file-or-buffer)
  "Push local model to repository.")

(defun sysml2-api-pull-model (project-id output-dir)
  "Pull model from repository to local files.")

(defun sysml2-api-query (project-id query-string)
  "Execute a query against the repository.")
```

### 3.9 FMI/FMU Integration Architecture (`sysml2-fmi.el` — Phase 4)

This subsystem bridges SysML v2 system models with executable simulation:

```
┌─────────────────┐     ┌───────────────────┐     ┌─────────────────┐
│ SysML v2 Model   │────>│ Interface         │────>│ Modelica Partial│
│ (part defs,      │     │ Contract          │     │ Models          │
│  port defs,      │     │ Extractor         │     │ (.mo files)     │
│  constraints)    │     └───────────────────┘     └─────────────────┘
└─────────────────┘                                       │
        │                                                  ▼
        │              ┌───────────────────┐     ┌─────────────────┐
        │              │ Co-Simulation     │<────│ FMU Export       │
        │              │ Orchestrator      │     │ (OpenModelica)   │
        │              │ (SSP-based)       │     └─────────────────┘
        │              └───────────────────┘
        │                      │
        ▼                      ▼
┌─────────────────┐     ┌───────────────────┐
│ Requirement      │<────│ Simulation        │
│ Verification     │     │ Results           │
│ (satisfy/verify) │     │ (.csv, plots)     │
└─────────────────┘     └───────────────────┘
```

#### 3.9.1 FMU Management Commands

| Command | Description |
|---|---|
| `sysml2-fmi-extract-interfaces` | Extract port definitions as FMI interface contracts |
| `sysml2-fmi-generate-modelica` | Generate Modelica partial model stubs from SysML v2 |
| `sysml2-fmi-import-fmu` | Import an FMU and map to SysML v2 part/port structure |
| `sysml2-fmi-inspect-fmu` | Browse FMU contents (model description, variables) |
| `sysml2-fmi-validate-interfaces` | Validate FMU interfaces against SysML v2 port definitions |

#### 3.9.2 Co-Simulation Orchestration

| Command | Description |
|---|---|
| `sysml2-cosim-configure` | Define co-simulation setup from SysML v2 connections |
| `sysml2-cosim-generate-ssp` | Generate SSP file from connection architecture |
| `sysml2-cosim-run` | Execute co-simulation via OMSimulator or FMPy |
| `sysml2-cosim-results` | View and plot simulation results |
| `sysml2-cosim-verify-requirements` | Check simulation results against SysML v2 requirements |

#### 3.9.3 Hardware-in-the-Loop (HIL) Extension

The HIL subsystem extends co-simulation to include real hardware interfaces:

- **Target platforms**: dSPACE, NI VeriStand, Speedgoat (via FMI)
- **Workflow**: SysML v2 model → identify HIL partition → generate FMU for virtual components → configure HIL platform → run mixed virtual/real simulation → validate requirements
- **Emacs integration**: Compile/deploy commands, serial/TCP monitoring buffers, real-time data plotting via gnuplot

---

## 4. Implementation Plan

### Phase 1: Core Editing (Months 1–3)

**Goal**: A usable `.sysml` and `.kerml` editor with no external dependencies.

| Deliverable | Module | Priority |
|---|---|---|
| Mode definition, file associations, syntax table | `sysml2-mode.el` | P0 |
| Language data tables | `sysml2-lang.el` | P0 |
| Regex font-lock (multi-level) | `sysml2-font-lock.el` | P0 |
| Basic indentation (brace-matching + keyword context) | `sysml2-indent.el` | P0 |
| Comment/uncomment commands | `sysml2-mode.el` | P0 |
| imenu support (definition/usage outline) | `sysml2-navigation.el` | P1 |
| Keyword completion (capf) | `sysml2-completion.el` | P1 |
| Yasnippet templates (20+ common patterns) | `sysml2-snippets.el` | P1 |
| `which-function-mode` support | `sysml2-navigation.el` | P2 |
| Electric pairs for `{}`, `()`, `[]`, `<>` | `sysml2-mode.el` | P2 |
| Standard library bundling (read-only) | `standard-library/` | P1 |
| MELPA packaging | `sysml2-mode.el` | P1 |

### Phase 2: Tree-Sitter + LSP (Months 3–6)

**Goal**: IDE-grade experience with semantic features.

| Deliverable | Module | Priority |
|---|---|---|
| Tree-sitter grammar for SysML v2 | `tree-sitter-sysml/` | P0 |
| Tree-sitter grammar for KerML | `tree-sitter-kerml/` | P0 |
| TS font-lock rules (all levels) | `sysml2-ts.el` | P0 |
| TS indentation rules | `sysml2-ts.el` | P0 |
| TS code folding | `sysml2-ts.el` | P1 |
| TS imenu (structured outline) | `sysml2-ts.el` | P1 |
| TS defun navigation (`C-M-a`, `C-M-e`) | `sysml2-ts.el` | P1 |
| Eglot configuration for Syside | `sysml2-lsp.el` | P0 |
| lsp-mode configuration | `sysml2-lsp.el` | P1 |
| Flymake integration | `sysml2-flymake.el` | P1 |
| Project.el integration (library resolution) | `sysml2-project.el` | P1 |
| Xref backend (go-to-definition) | `sysml2-navigation.el` | P1 |
| Context-aware completion (types, members) | `sysml2-completion.el` | P2 |
| Hover/eldoc integration | `sysml2-lsp.el` | P2 |

### Phase 3: Visualization (Months 6–9)

**Goal**: Generate and preview diagrams from SysML v2 source.

| Deliverable | Module | Priority |
|---|---|---|
| SysML v2 → PlantUML transformer (tree/BDD) | `sysml2-plantuml.el` | P0 |
| SysML v2 → PlantUML (interconnection/IBD) | `sysml2-plantuml.el` | P0 |
| SysML v2 → PlantUML (state machine) | `sysml2-plantuml.el` | P1 |
| SysML v2 → PlantUML (action flow) | `sysml2-plantuml.el` | P1 |
| SysML v2 → PlantUML (requirement tree) | `sysml2-plantuml.el` | P2 |
| Inline preview (image in buffer) | `sysml2-diagram.el` | P0 |
| Export to PNG/SVG/PDF | `sysml2-diagram.el` | P0 |
| Org-babel `ob-sysml` backend | `sysml2-diagram.el` | P1 |
| Side-by-side preview minor mode | `sysml2-diagram.el` | P1 |
| Auto-refresh on save | `sysml2-diagram.el` | P2 |
| Systems Modeling API client | `sysml2-api.el` | P2 |

### Phase 4: Simulation & Verification (Months 9–18)

**Goal**: Bridge SysML v2 models to executable simulation for virtual system validation.

| Deliverable | Module | Priority |
|---|---|---|
| FMU inspector (browse .fmu contents) | `sysml2-fmi.el` | P1 |
| Interface contract extraction | `sysml2-fmi.el` | P1 |
| Modelica stub generation | `sysml2-fmi.el` | P2 |
| FMU ↔ SysML v2 port mapping validation | `sysml2-fmi.el` | P2 |
| SSP file generation from connections | `sysml2-cosim.el` | P2 |
| OMSimulator/FMPy invocation | `sysml2-cosim.el` | P2 |
| Results visualization (gnuplot/org-plot) | `sysml2-cosim.el` | P3 |
| Requirement verification dashboard | `sysml2-cosim.el` | P3 |
| HIL platform integration (dSPACE/NI) | `sysml2-cosim.el` | P3 |
| OpenModelica Emacs integration | `sysml2-fmi.el` | P3 |

---

## 5. Key Design Details

### 5.1 Mode Entry Point

```elisp
;;;###autoload
(define-derived-mode sysml2-mode prog-mode "SysML2"
  "Major mode for editing SysML v2 textual notation files."
  :syntax-table sysml2-mode-syntax-table
  :group 'sysml2

  ;; Syntax table
  (modify-syntax-entry ?/ ". 124" sysml2-mode-syntax-table)
  (modify-syntax-entry ?* ". 23b" sysml2-mode-syntax-table)
  (modify-syntax-entry ?\n ">" sysml2-mode-syntax-table)
  (modify-syntax-entry ?\" "\"" sysml2-mode-syntax-table)
  (modify-syntax-entry ?\' "\"" sysml2-mode-syntax-table)

  ;; Comments
  (setq-local comment-start "// ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "\\(?://+\\|/\\*+\\)\\s-*")

  ;; Font lock
  (setq-local font-lock-defaults
              '(sysml2-font-lock-keywords nil nil nil nil))

  ;; Indentation
  (setq-local indent-line-function #'sysml2-indent-line)
  (setq-local indent-tabs-mode nil)

  ;; Electric
  (setq-local electric-indent-chars
              (append '(?{ ?} ?\; ?\n) electric-indent-chars))

  ;; Navigation
  (setq-local imenu-create-index-function #'sysml2-imenu-create-index)

  ;; Completion
  (add-hook 'completion-at-point-functions
            #'sysml2-completion-at-point nil t)

  ;; Paragraph
  (setq-local paragraph-start (concat "$\\|" page-delimiter))
  (setq-local paragraph-separate paragraph-start)

  ;; Outline (for outline-minor-mode)
  (setq-local outline-regexp
              "\\s-*\\(?:package\\|part def\\|action def\\|state def\\|requirement def\\)")
  (setq-local outline-level #'sysml2-outline-level))

;;;###autoload
(define-derived-mode sysml2-ts-mode prog-mode "SysML2"
  "Major mode for SysML v2 files, powered by tree-sitter."
  :group 'sysml2
  (when (treesit-ready-p 'sysml)
    (treesit-parser-create 'sysml)
    (setq-local treesit-font-lock-settings sysml2-ts--font-lock-settings)
    (setq-local treesit-font-lock-feature-list
                '((comment)
                  (keyword string)
                  (definition type)
                  (literal operator variable)))
    (setq-local treesit-simple-indent-rules sysml2-ts--indent-rules)
    (setq-local treesit-defun-type-regexp
                "\\(?:part\\|action\\|state\\|requirement\\|use_case\\)_definition")
    (treesit-major-mode-setup)))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.sysml\\'" . sysml2-mode))
;;;###autoload
(add-to-list 'auto-mode-alist '("\\.kerml\\'" . kerml-mode))

;; Auto-upgrade to tree-sitter when available
(when (treesit-available-p)
  (add-to-list 'major-mode-remap-alist '(sysml2-mode . sysml2-ts-mode)))
```

### 5.2 Customization Group

```elisp
(defgroup sysml2 nil
  "SysML v2 / KerML editing support."
  :group 'languages
  :prefix "sysml2-")

(defcustom sysml2-indent-offset 4
  "Number of spaces for each indentation level."
  :type 'integer :group 'sysml2)

(defcustom sysml2-standard-library-path nil
  "Path to SysML v2 standard library. Nil uses bundled library."
  :type '(choice (const nil) directory) :group 'sysml2)

(defcustom sysml2-plantuml-jar-path nil
  "Path to PlantUML jar. Nil uses plantuml-mode's setting."
  :type '(choice (const nil) file) :group 'sysml2)

(defcustom sysml2-diagram-output-format "svg"
  "Default output format for diagram generation."
  :type '(choice (const "png") (const "svg") (const "pdf"))
  :group 'sysml2)

(defcustom sysml2-diagram-auto-preview nil
  "Automatically update diagram preview on save."
  :type 'boolean :group 'sysml2)

(defcustom sysml2-lsp-server 'syside
  "Which LSP server to use."
  :type '(choice (const syside) (const pilot-implementation) (const none))
  :group 'sysml2)

(defcustom sysml2-api-base-url nil
  "Base URL for the Systems Modeling API repository."
  :type '(choice (const nil) string) :group 'sysml2)
```

### 5.3 Snippet Examples

```
# -*- mode: snippet; require-final-newline: nil -*-
# name: part def
# key: pd
# --
part def ${1:Name} {
    $0
}

# name: requirement def
# key: rd
# --
requirement def ${1:Name} {
    subject ${2:system} : ${3:SystemType};
    doc /* ${4:description} */
    require constraint {
        $0
    }
}

# name: action def
# key: ad
# --
action def ${1:Name} {
    in ${2:input} : ${3:InputType};
    out ${4:output} : ${5:OutputType};
    $0
}

# name: state def
# key: sd
# --
state def ${1:Name} {
    entry action ${2:entryAction};
    state ${3:State1};
    state ${4:State2};
    transition ${3:State1}
        if ${5:guard}
        then ${4:State2};
}

# name: package
# key: pkg
# --
package ${1:Name} {
    $0
}
```

### 5.4 Keymap

```elisp
(defvar sysml2-mode-map
  (let ((map (make-sparse-keymap)))
    ;; Diagram
    (define-key map (kbd "C-c C-d p") #'sysml2-diagram-preview)
    (define-key map (kbd "C-c C-d b") #'sysml2-diagram-preview-buffer)
    (define-key map (kbd "C-c C-d e") #'sysml2-diagram-export)
    (define-key map (kbd "C-c C-d t") #'sysml2-diagram-type)
    (define-key map (kbd "C-c C-d o") #'sysml2-diagram-open-plantuml)
    ;; Navigation
    (define-key map (kbd "C-c C-n d") #'sysml2-goto-definition)
    (define-key map (kbd "C-c C-n r") #'sysml2-find-references)
    (define-key map (kbd "C-c C-n o") #'sysml2-show-outline)
    ;; API
    (define-key map (kbd "C-c C-a p") #'sysml2-api-push-model)
    (define-key map (kbd "C-c C-a g") #'sysml2-api-pull-model)
    ;; Simulation (Phase 4)
    (define-key map (kbd "C-c C-s i") #'sysml2-fmi-inspect-fmu)
    (define-key map (kbd "C-c C-s r") #'sysml2-cosim-run)
    (define-key map (kbd "C-c C-s v") #'sysml2-cosim-verify-requirements)
    map)
  "Keymap for `sysml2-mode'.")
```

---

## 6. Testing Strategy

### 6.1 Test Framework

- **ERT** (Emacs Regression Testing) for all Elisp modules
- **Tree-sitter test harness** (built-in `tree-sitter test`) for grammar correctness
- **Fixture-based testing**: Sample `.sysml`/`.kerml` files from the SysML v2 Release repository (LGPL-licensed examples from the Flashlight Example, Vehicle Example, and Simple Tests)

### 6.2 Test Categories

| Category | What it tests | Target coverage |
|---|---|---|
| Font-lock | All keyword categories correctly highlighted | 100% of keyword table |
| Indentation | Nested blocks, continuations, multi-line expressions | 50+ fixture cases |
| Tree-sitter parsing | Grammar accepts all Pilot Implementation examples | 100% of official examples |
| Completion | Keyword and type completion in various contexts | Major completion contexts |
| PlantUML transformation | Each diagram type produces valid PlantUML | All 6 diagram types |
| API client | HTTP request/response handling | Mock server tests |

### 6.3 Continuous Integration

- **GitHub Actions**: Run ERT tests on Emacs 29.x, 30.x (Linux, macOS)
- **Grammar CI**: Tree-sitter grammar tested against the full SysML v2 example corpus
- **Spec regression**: Automated check when new SysML v2 releases are tagged on GitHub

---

## 7. Spec Change Adaptation Procedure

When OMG publishes a SysML v2.x update:

1. **Extract BNF** from the new specification using the Pilot Implementation's BNF Extractor tool
2. **Diff keywords**: Compare new BNF terminal symbols against `sysml2-lang.el` constants
3. **Update `sysml2-lang.el`**: Add/remove/modify keyword entries. Bump `sysml2-spec-version`.
4. **Update tree-sitter grammar**: Modify `grammar.js` rules to match new BNF productions. Update highlight/indent queries.
5. **Update snippets**: Add templates for any new construct types
6. **Update PlantUML transformer**: Add rendering support for new diagram-relevant constructs
7. **Update standard library**: Replace bundled library with new release from GitHub
8. **Run test suite**: Verify all tests pass against new examples
9. **Release**: Bump version, update CHANGELOG, push to MELPA

The data-driven architecture ensures steps 3–5 are localized edits, not scattered changes.

---

## 8. Dependencies & Prerequisites

| Dependency | Required/Optional | Purpose |
|---|---|---|
| Emacs 29.1+ | Required | Base editor, tree-sitter support |
| tree-sitter | Optional (recommended) | Grammar-based parsing |
| PlantUML (jar or executable) | Optional | Diagram generation |
| GraphViz | Optional | Complex PlantUML diagram layouts |
| Java 17+ | Optional | PlantUML jar execution |
| Syside LSP server | Optional (recommended) | Semantic analysis, completion, navigation |
| plantuml-mode (MELPA) | Optional | PlantUML buffer editing |
| yasnippet (MELPA) | Optional | Snippet expansion |
| OpenModelica | Optional (Phase 4) | FMU import/export, Modelica compilation |
| FMPy / OMSimulator | Optional (Phase 4) | Co-simulation execution |

---

## 9. Open Questions & Risks

| # | Question/Risk | Mitigation |
|---|---|---|
| 1 | No existing tree-sitter grammar for SysML v2 — grammar development is the largest effort | Start with a subset grammar covering the 80% case; use regex fallback for full coverage initially |
| 2 | PlantUML SysML v2 extensions are limited and not fully conformant | Layer our own transformation that generates standard PlantUML constructs; don't depend on SysML v2-specific PlantUML features |
| 3 | Syside LSP server may have breaking API changes | Abstract LSP configuration; support multiple server backends |
| 4 | SysML v2 specification may receive errata or minor revisions | Data-driven architecture isolates changes to `sysml2-lang.el` |
| 5 | FMI/FMU integration requires domain expertise | Phase 4 timeline allows for community contribution and expert review |
| 6 | Multi-word keywords (`part def`) are unusual for tree-sitter | Use token-level grammar rules or external scanner to handle two-word tokens |
| 7 | Standard library is large (Quantities/Units) and may impact performance | Lazy-load library parsing; rely on LSP server for library resolution |

---

## 10. References

1. OMG SysML v2.0 Specification (September 2025) — https://www.omg.org/spec/SysML/2.0/
2. OMG KerML 1.0 Specification — https://www.omg.org/spec/KerML/1.0/
3. SysML v2 Pilot Implementation — https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation
4. SysML v2 Release (examples, library) — https://github.com/Systems-Modeling/SysML-v2-Release
5. Syside Editor (VS Code) — https://marketplace.visualstudio.com/items?itemName=sensmetry.syside-editor
6. Sensmetry SysIDE Legacy (open source) — https://github.com/sensmetry/sysml-2ls
7. PlantUML — https://plantuml.com/
8. PlantUML SysML v2 extensions — https://github.com/himi/p2-update-puml-sysmlv2
9. Emacs Tree-sitter Major Mode Guide — https://www.gnu.org/software/emacs/manual/html_node/elisp/Tree_002dsitter-Major-Modes.html
10. Mastering Emacs: Tree-Sitter Major Mode Tutorial — https://www.masteringemacs.org/article/lets-write-a-treesitter-major-mode
11. FMI Standard — https://fmi-standard.org/
12. OpenModelica FMI Documentation — https://openmodelica.org/doc/OpenModelicaUsersGuide/latest/fmitlm.html
13. SSP Standard (System Structure & Parameterization) — https://ssp-standard.org/
14. Samares Engineering: Co-simulation of SysML and Modelica through FMI — https://www.samares-engineering.com/en/2021/01/21/part-9-co-simulation-of-sysml-and-other-models-through-fmi/
15. SysML v2 Textual Notation Cheatsheet — https://sensmetry.com/sysml-cheatsheet/
16. plantuml-mode for Emacs — https://github.com/skuro/plantuml-mode
17. MontiCore SysML v2 Parser — https://github.com/MontiCore/sysmlv2
