# sysml2-mode

An Emacs major mode for editing [SysML v2](https://www.omgsysml.org/SysML-2.htm) and [KerML](https://www.omg.org/spec/KerML/) textual notation files.

Provides syntax highlighting, indentation, completion, navigation, diagram generation, native simulation, FMI/FMU integration, co-simulation orchestration, and LSP support.

Follows the book's house style: quoted unrestricted names (`package <DSPA> 'Drone System Product Architecture'`) and `<ID>` requirement short names (`requirement <REQ23> observeArea`) are first-class in highlighting, navigation, imenu, and model extraction.

**Requires:** Emacs 29.1+ | **Platforms:** Linux, macOS, Windows

## Documentation

| Document | Description |
|----------|-------------|
| **[Tutorial](TUTORIAL.md)** | Step-by-step guide to building a complete SysML v2 model (drone system example covering all 20 SysML v2 concepts) |
| **[SysML v2 Syntax Reference](SYNTAX-REFERENCE.md)** | Language syntax reference and best practices for SysML v2 textual notation |
| **[FMI Integration Guide](examples/fmi-integration.md)** | Complete workflow for SysML v2 + Modelica/FMI co-simulation (8-step process from model to results) |
| **[Literate SysML Guide](examples/literate-sysml.md)** | Org-babel literate programming: tangle, noweb, inline validation, simulation, and diagrams |
| **[Changelog](CHANGELOG.md)** | Release history and version notes |
| **[Book Review Findings](REVIEW-2026-07.md)** | Systematic review of the toolchain against the *SysML v2 Book* (Weilkiens 2026-05) — the working backlog |

## Table of Contents

- [Installation](#installation)
- [First-Run Health Check](#first-run-health-check)
- [Menu Bar and Transient Pickers](#menu-bar-and-transient-pickers)
- [Features](#features)
- [Diagram Generation](#diagram-generation)
- [Model Scaffolding](#model-scaffolding)
- [Model Inspection](#model-inspection)
- [FMI/FMU Integration](#fmifmu-integration)
- [Co-Simulation](#co-simulation)
- [Native Simulation](#native-simulation)
- [CLI Analysis](#cli-analysis)
- [Formatting](#formatting)
- [Systems Modeling API](#systems-modeling-api)
- [LSP Support](#lsp-support)
- [Evil-Mode Integration](#evil-mode-integration)
- [Keybinding Reference](#keybinding-reference)
- [Customization](#customization)
- [Module Architecture](#module-architecture)
- [Testing](#testing)
- [License](#license)

## Installation

### From source

```bash
git clone https://github.com/jackhale98/sysml2-mode.git
```

Add to your init file:

```elisp
(add-to-list 'load-path "/path/to/sysml2-mode")
(require 'sysml2-mode)
;; .sysml and .kerml files auto-activate — no auto-mode-alist needed
```

### use-package

```elisp
(use-package sysml2-mode
  :load-path "/path/to/sysml2-mode")
```

### straight.el / elpaca

```elisp
(use-package sysml2-mode
  :straight (:host github :repo "jackhale98/sysml2-mode"
             :files ("*.el" "snippets")))
```

### Doom Emacs

Add to `~/.config/doom/packages.el`:

```elisp
(package! sysml2-mode
  :recipe (:host github :repo "jackhale98/sysml2-mode"
           :files ("*.el" "snippets")))
```

Add to `~/.config/doom/config.el`:

```elisp
(use-package! sysml2-mode
  :mode "\\.sysml\\'")
```

`sysml2-mode.el` already requires `sysml2-evil` (`SPC m` keybindings)
and `sysml2-ts` (tree-sitter) internally — no `:config` block needed.

Then run `doom sync`.

### First-Run Health Check

After installing, run `M-x sysml2-doctor` to probe every external tool the
mode can leverage — `sysml` CLI, tree-sitter grammar, LSP server, D2,
PlantUML, GraphViz, Pandoc, and the resolved SysML stdlib path. The
doctor buffer shows one line per check with `[ok]`, `[warn]` (optional,
not installed), or `[FAIL]` (required, missing) plus an install hint.
Re-run it any time something stops working to quickly separate
"the mode is broken" from "I haven't installed that tool yet."

### Menu Bar and Transient Pickers

Every major feature is exposed on a `SysML2` menu-bar item (no
external dependencies) for mouse-driven discovery, and three
keyboard-driven transient pickers replace minibuffer-prompt sub-menus:

| Picker | Binding | Covers |
|--------|---------|--------|
| Diagrams      | `C-c C-d RET` | tree, IBD, state, action, requirement, use case, package, view, preview, export, open in playground |
| Scaffold      | `C-c m RET`   | model skeleton, package, part def, port def, requirement, state, action, calc, enum, use case |
| CLI / Refactor| `C-c C-t RET` | check, list, show, trace, deps, coverage, doc, analyze (incl. uncertainty cases), rollup, view (model-defined reports), allocation, diff, rename, add, remove |

Vanilla-Emacs users with `which-key` installed also see prefix labels
("diagram", "scaffold", "cli-analyze", …) when they hold a `C-c` prefix.

## Features

### Syntax Highlighting

Three font-lock levels with 216 keywords across 9 categories:

- **Level 1:** Keywords only (multi-word matched before single-word)
- **Level 2:** + definition names, usage names, type references
- **Level 3 (default):** + visibility, modifiers, literals, operators, short names (`<R1>`), metadata (`#Annotation`), numeric literals, qualified name prefixes (`Package::`)

```sysml
package Vehicle {
    part def Engine :> PowerSource {
        attribute displacement : Real;
        port fuelIn : FuelPort;
    }
}
```

### Indentation

Automatic indentation with `sysml2-indent-offset` (default 4):

- Brace/bracket/paren alignment
- Continuation line handling inside blocks
- Comment and string awareness
- Electric indent on `{`, `}`, `;`, newline

### Completion

Context-aware `completion-at-point` with annotation hints:

| Context | Candidates |
|---------|-----------|
| Line start | Definition, usage, structural, and behavioral keywords |
| After `import` | Standard library packages (58), `*` |
| After `:` (type position) | Buffer definitions, standard library |
| After `:>` (specialization) | Buffer definitions, standard library |
| After `:>>` (redefinition) | Buffer definitions |
| After `connect` / `to` | Part and port names |
| After `satisfy`/`verify` ... `by` | Buffer definitions and usages |
| After `in`/`out`/`inout` | Usage keywords |
| After `#` | `Metadata` |
| Inside a definition body | Usage keywords and members |

### Navigation

- **Imenu** (`C-c C-n o`): Hierarchical index organized by definition category (40 categories, SysML v2 + KerML)
- **which-function-mode**: Shows enclosing definition/package in mode line
- **beginning/end-of-defun**: `C-M-a` / `C-M-e` navigate between definitions
- **Find references** (`M-?`): All references to the symbol at point
- **Outline side panel** (`C-c C-n t`): Tree view in a left side window

### Snippets

49 yasnippet templates for common patterns (requires [yasnippet](https://github.com/joaotavora/yasnippet)):

| Key | Expansion |
|-----|-----------|
| `pkg` | `package Name { ... }` |
| `pd` | `part def Name { ... }` |
| `p` | `part name : Type;` |
| `ad` | `action def Name { ... }` |
| `sd` | `state def Name { ... }` |
| `ptd` | `port def Name { ... }` |
| `rd` | `requirement def Name { ... }` |
| `cd` | `connection def Name { ... }` |
| `imp` | `import Package::*;` |
| `doc` | `doc /* ... */` |
| `sat` | `satisfy requirement ... by ...;` |

...and more (`at`, `atd`, `s`, `a`, `pt`, `cn`, `cnd`, `ucd`, `vd`, `vpd`, `c`, `pdb`, `imps`).

### Flymake Diagnostics

Three layers of diagnostics, from zero-dependency to deep cross-file analysis:

**In-process checks** (no external tools):

1. **Unmatched delimiters** — detects mismatched `{}`, `[]`, `()`
2. **Unknown definition keywords** — catches typos like `prat def`
3. **Missing semicolons** — warns on single-line usages without trailing `;`
4. **Unsatisfied requirements** — requirement defs with no `satisfy` statement
5. **Unverified requirements** — requirement defs with no `verify` statement
6. **Unused definitions** — definitions never referenced elsewhere in the buffer
7. **Invalid library references** — validates ISQ, SI, and ScalarValues qualified names

**Tree-sitter checks** (when grammar installed):

8. **Syntax errors** — ERROR nodes from the incremental parser
9. **Missing nodes** — expected tokens the parser couldn't find

**CLI checks** (when `sysml` CLI installed, async):

10. **Unresolved types** (W004) — type references that don't resolve across files
11. **Unresolved targets** (W005) — reference targets that don't resolve
12. **Port type mismatches** (W006) — connected ports with incompatible types
13. **Empty constraints** (W007) — constraint defs with body but no expression
14. **Missing returns** (W008) — calc defs with body but no return
15. **Port direction mismatches** (W009) — `in`/`out` incompatibility
16. **Import cycles** (W010) — recursive import chains
17. **Multiplicity violations** (W011) — bounds violations
18. **Missing documentation** (W012) — public top-level defs without `doc /* ... */`
19. **Naming conventions** (W013) — definitions not in PascalCase, usages not in camelCase
20. **Orphaned requirements** (W014) — requirement defs that are never satisfied, verified, or specialized
21. **Self-specialization** (W015) — `part def X :> X` infinite-recursion typos
22. **Unbound ports** (W016) — port usages declared inside a part but never connected
23. **Value-constraint violations** (W017) — model-declared `assert constraint`s evaluated against concrete values (e.g. an `@Fmea` severity of 12 fails FmeaRating's 1–10 range)

### Project Detection

Automatic project root detection (ascending search):

1. `.sysml-project` file (highest priority)
2. `sysml.library/` directory
3. `.git` directory

Standard library path is auto-resolved from project root or a custom path.

### Tree-Sitter Support

When the [`sysml` tree-sitter grammar](https://github.com/jackhale98/tree-sitter-sysml) is installed, `sysml2-mode` automatically remaps to `sysml2-ts-mode` for:

- **Font-lock** — node-type-aware highlighting (8 features across 3 levels)
- **Indentation** — 50 parent-type-based indent rules covering all body types, control flow, fork/join/merge/decide, metadata, and multi-line expressions
- **Formatting** — `C-c C-= =` re-indents the buffer using tree-sitter rules (no external tool needed)
- **Imenu** — 28 definition categories from parse tree
- **Which-function** — accurate enclosing definition via `treesit-parent-until`
- **Completion** — context-aware CAPF using parse tree queries
- **Flymake** — tree-sitter ERROR node reporting
- **Goto-definition / Rename** — parse-tree-based search
- **Structural movement** (Emacs 30+) — `treesit-thing-settings` for `forward-sexp`, `forward-sentence`, `forward-list` driven by AST node types
- **Outline** (Emacs 30+) — `treesit-outline-predicate` recognises every definition node as an outline heading

Canonical tree-sitter query files for downstream editors (Helix,
Neovim, Zed) live in [`tree-sitter-sysml/queries/`](tree-sitter-sysml/queries/):
`highlights.scm`, `indents.scm`, `folds.scm`, `locals.scm`, `tags.scm`.

Install the grammar:

```elisp
(add-to-list 'treesit-language-source-alist
             '(sysml "https://github.com/jackhale98/tree-sitter-sysml"
                     nil "src"))
M-x treesit-install-language-grammar RET sysml
```

## Diagram Generation

Generate diagrams from SysML v2 models with a dual-backend architecture. Seven diagram types:

| Binding | Command | Diagram |
|---------|---------|---------|
| `C-c C-d t` | `sysml2-diagram-tree` | Parts Tree (BDD) |
| `C-c C-d i` | `sysml2-diagram-ibd` | Interconnection (IBD) |
| `C-c C-d s` | `sysml2-diagram-state-machine` | State Machine |
| `C-c C-d a` | `sysml2-diagram-action-flow` | Action Flow |
| `C-c C-d r` | `sysml2-diagram-requirement` | Requirement Tree |
| `C-c C-d u` | `sysml2-diagram-use-case` | Use Case |
| `C-c C-d k` | `sysml2-diagram-package` | Package |
| `C-c C-d p` | `sysml2-diagram-preview` | Auto-detect at point |
| `C-c C-d b` | `sysml2-diagram-preview-buffer` | Whole-buffer diagram |
| `C-c C-d v` | `sysml2-diagram-view` | Generate from view def filter |
| `C-c C-d e` | `sysml2-diagram-export` | Export to file |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` | View diagram source |
| `C-c C-d w` | `sysml2-diagram-open-in-playground` | Open in D2 web playground |

Scoped diagrams (IBD, state machine, action flow) auto-detect the
enclosing definition or prompt for a scope name. Diagram export
(`C-c C-d e`) prompts for diagram type, scope, and output file.

Diagrams are automatically scaled to fit the preview window.

**UML-style compartments:** Block diagrams (BDD/tree) show ports, attributes, and parts in separate compartments. State machine nodes show entry/do/exit actions. IBD parts show attributes from their type definitions.

**Transition labels:** State machine transitions display the full `trigger [guard] / effect` label.

**Control flow nodes:** Action flow diagrams render fork/join as bars and decide/merge as diamonds.

**View-filtered diagrams** (`C-c C-d v`) parse `view def` declarations with
`render` clauses, `filter @SysML::...` metatype filters, `expose` clauses (for automatic scope resolution), and `:>` inheritance to determine the diagram type automatically.

### Native Backend (default)

The native backend (`sysml2-diagram-backend` = `native`) uses two rendering engines:

- **[D2](https://d2lang.com)** for all seven diagram types: tree/BDD, requirements, IBD, state machine, action flow, use case, and package
- **Direct SVG** (zero-dependency fallback) for tree and requirement diagrams when D2 is not installed

When D2 is not installed locally, graph diagrams automatically fall back to opening in the [D2 Playground](https://play.d2lang.com) in your browser — no local installation required. Changes in the playground do NOT update the SysML model; this is a one-way, read-only visualization.

You can also open any D2-backed diagram in the playground explicitly with `C-c C-d w` / `SPC m d w`.

```elisp
;; Install D2 for local rendering (optional):
;; https://d2lang.com/tour/install

;; Customize D2 settings:
(setq sysml2-d2-executable-path "/path/to/d2")  ; nil = search exec-path
(setq sysml2-d2-theme 0)                         ; theme number
(setq sysml2-d2-layout-engine 'elk)              ; nil (dagre), elk, or tala
```

### PlantUML Backend (legacy)

Set `sysml2-diagram-backend` to `plantuml` to use [PlantUML](https://plantuml.com/) for all diagram types:

```elisp
(setq sysml2-diagram-backend 'plantuml)

;; Direct executable (default)
(setq sysml2-plantuml-exec-mode 'executable)

;; Java JAR
(setq sysml2-plantuml-exec-mode 'jar)
(setq sysml2-plantuml-jar-path "/path/to/plantuml.jar")

;; Remote server
(setq sysml2-plantuml-exec-mode 'server)
(setq sysml2-plantuml-server-url "https://www.plantuml.com/plantuml")
```

### Org-Babel Integration

Execute SysML blocks in org-mode:

```org
#+BEGIN_SRC sysml :cmd diagram :diagram-type tree :file vehicle.svg
package Vehicle {
    part def Engine { }
    part def Body { }
}
#+END_SRC
```

## Model Scaffolding

Interactive commands to bootstrap common SysML v2 model structures. Each command prompts for names, types, and optional elements, then inserts well-formed SysML v2 code at point.

| Binding | Command | Scaffolds |
|---------|---------|-----------|
| `C-c m m` | `sysml2-scaffold` | Menu of all scaffolding commands |
| `C-c m M` | `sysml2-scaffold-model` | Whole-model skeleton (package + parts + requirements) |
| `C-c m p` | `sysml2-scaffold-package` | Package with optional imports |
| `C-c m d` | `sysml2-scaffold-part-def` | Part def with attributes, ports, specialization |
| `C-c m o` | `sysml2-scaffold-port-def` | Port def with directional items |
| `C-c m r` | `sysml2-scaffold-requirement-def` | Requirement def with doc, subject, constraint |
| `C-c m s` | `sysml2-scaffold-state-def` | State def with states and auto-generated transitions |
| `C-c m a` | `sysml2-scaffold-action-def` | Action def with sub-actions and successions |
| `C-c m e` | `sysml2-scaffold-enum-def` | Enum def with literals |
| `C-c m u` | `sysml2-scaffold-use-case-def` | Use case def with subject, actors, includes |
| `C-c m c` | `sysml2-scaffold-calc-def` | Calc def with in params and return value |

## Model Inspection

Interactive reporting and analysis commands for model understanding and ISO 13485 traceability.

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-i s` | `sysml2-report-summary` | Model statistics (definitions, usages, relationships, coverage) |
| `C-c C-i t` | `sysml2-report-traceability` | Sortable traceability matrix (IDs, satisfy, verify, derive, refine) |
| `C-c C-i a` | `sysml2-impact-analysis` | Upstream/downstream dependency analysis at point |
| `C-c C-i m` | `sysml2-report-export-markdown` | Export model report as Markdown (13 sections) |
| `C-c C-i e` | `sysml2-report-export` | Export via Pandoc (PDF/HTML/DOCX) |

**Impact analysis** (`C-c C-i a`) shows all relationships for the definition at point:
- **Upstream**: supertypes, parent compositions, connections from, flows from, satisfies, verifies, derived from, refines
- **Downstream**: subtypes, child compositions, connections to, flows to, satisfied by, verified by, derived to, refined by, sub-requirements, port type usages

**Markdown report sections**: Model Summary, Part Decomposition (BOM), Interface Table, Connection Matrix, Requirements Specification, Traceability Matrix, Allocation Matrix, State Machines, Action Flows, Calculations, Analysis Cases, Constraint Definitions, Enumerations.

## FMI/FMU Integration

FMI 3.0 support for model exchange and co-simulation workflows. See the **[FMI Integration Guide](examples/fmi-integration.md)** for a complete walkthrough from SysML model to co-simulation.

### FMU Inspector

Inspect `.fmu` files by parsing `modelDescription.xml`:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s i` | `sysml2-fmi-inspect-fmu` | Open FMU inspector (variables, structure, metadata) |

### Interface Extraction

Extract FMI-compatible interface contracts from SysML port definitions:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s e` | `sysml2-fmi-extract-interfaces` | Extract ports as FMI variables |

Handles:
- Port conjugation (`~`) with automatic direction flipping
- SysML-to-FMI type mapping (`Real` -> `Float64`, `Integer` -> `Int32`, `Boolean` -> `Boolean`)
- User-extensible type mapping via `sysml2-fmi-type-mapping-alist`

### Modelica Stub Generation

Generate partial Modelica models from SysML part definitions:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s m` | `sysml2-fmi-generate-modelica` | Generate `.mo` file from part def |
| `C-c C-s M` | `sysml2-fmi-generate-all-modelica` | Generate `.mo` files for all parts in current file |
| `C-c C-s F` | `sysml2-fmi-batch-generate-modelica` | Generate `.mo` files for all parts across multiple SysML files |

```modelica
partial model Engine
  "Generated from SysML v2 part def Engine"
  Modelica.Blocks.Interfaces.RealInput fuelFlow "From port fuelIn";
  Modelica.Blocks.Interfaces.RealOutput torque "From port driveOut";
  parameter Real displacement "From SysML attribute";
equation
  // Equations to be filled by model developer
end Engine;
```

### Interface Validation

Compare FMU `modelDescription.xml` against SysML port definitions:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s v` | `sysml2-fmi-validate-interfaces` | Show match/mismatch/missing report |
| `C-c C-s V` | `sysml2-fmi-validate-all` | Validate all FMUs against SysML |

### FMU Compilation

Compile Modelica models to FMUs via OpenModelica:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s b` | `sysml2-fmi-compile-fmu` | Compile single `.mo` to FMU |
| `C-c C-s B` | `sysml2-fmi-compile-all-fmus` | Compile all `.mo` files to FMUs |

### FMI Dashboard

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s d` | `sysml2-fmi-dashboard` | Status overview (stubs, FMUs, validation) |

## Co-Simulation

Orchestrate co-simulation runs with FMPy or OMSimulator. See the **[FMI Integration Guide](examples/fmi-integration.md)** for a complete end-to-end walkthrough.

### SSP Generation

Generate [SSP](https://ssp-standard.org/) (System Structure and Parameterization) packages from SysML connections:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s g` | `sysml2-cosim-generate-ssp` | Generate SSP from connections |

### Simulation Execution

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s r` | `sysml2-cosim-run` | Run simulation (async) |

Supports FMPy and OMSimulator via `sysml2-cosim-tool`.

### Results Visualization

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s p` | `sysml2-cosim-results` | Display CSV results in tabulated buffer |

Optional gnuplot integration for time-series plots.

### Requirement Verification

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s c` | `sysml2-cosim-verify-requirements` | Check simulation results against requirements |

Parses simple constraints from requirement `doc` comments (`signal <= bound`) and checks simulation data. Complex constraints are flagged as `MANUAL`.

### End-to-End Pipeline

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-s P` | `sysml2-cosim-pipeline` | Full pipeline: generate all stubs, compile FMUs, package SSP, run simulation |

## Native Simulation

Built-in SysML v2 behavioral simulation powered by the [sysml CLI](https://github.com/jackhale98/sysml-cli). Evaluate constraints, run calculations, simulate state machines, and execute action flows directly from Emacs.

**Requires:** `sysml` on `exec-path` (install from [sysml-cli releases](https://github.com/jackhale98/sysml-cli/releases))

### Simulation Commands

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-x s` | `sysml2-simulate` | Open simulation dispatch menu |
| `C-c C-x l` | `sysml2-simulate-list` | List all simulatable constructs in the current file |
| `C-c C-x e` | `sysml2-simulate-eval` | Evaluate a constraint or calculation (with parameter completion) |
| `C-c C-x m` | `sysml2-simulate-state-machine` | Simulate a state machine (with trigger signal completion) |
| `C-c C-x a` | `sysml2-simulate-action-flow` | Execute an action flow |

All simulation commands offer model-aware completion: construct names, trigger signals for state machines, and parameter names for constraints and calculations are extracted from the model and presented as candidates.

### Listing Constructs

`C-c C-x l` scans the current file and lists all simulatable constructs with their parameters:

```
=== Simulatable Constructs: model.sysml ===

Constraints:
  SpeedLimit (speed: Real)

Calculations:
  KineticEnergy (mass: Real, velocity: Real) -> Real

State Machines:
  TrafficLight [entry: red, states: red, yellow, green, transitions: 3]

Actions:
  ProcessOrder (7 steps)
```

### Evaluating Constraints and Calculations

`C-c C-x e` prompts for a constraint/calculation name (with completion) and variable bindings, then displays the result:

```
=== Eval: SpeedLimit ===

constraint SpeedLimit: satisfied
```

Variable bindings use `name=value` format, comma-separated (e.g., `speed=100,mass=1500`).

### State Machine Simulation

`C-c C-x m` prompts for the state machine name, events to inject, variable bindings for guards, and maximum steps. The simulation trace shows each state transition:

```
=== State Machine: TrafficLight ===

State Machine: TrafficLight
Initial state: red

  Step 0: red -- [next]--> green
  Step 1: green -- [next]--> yellow
  Step 2: yellow -- [next]--> red

Status: deadlocked (3 steps, current: red)
```

### Action Flow Execution

`C-c C-x a` executes an action flow and traces each step, including fork/join parallelism, conditionals, assignments, and loops:

```
=== Action Flow: ProcessOrder ===

Action: ProcessOrder

  Step 0: [perform] perform validate
  Step 1: [perform] perform checkInventory
  Step 2: [perform] perform ship
  Step 3: [perform] perform notifyCustomer

Status: completed (4 steps)
```

### Simulation Capabilities

The simulation engine supports:

- **Constraints**: Boolean expression evaluation with comparison, logical, and arithmetic operators
- **Calculations**: Expression evaluation with parameterized inputs and built-in functions (`abs`, `sqrt`, `min`, `max`, etc.)
- **State machines**: Entry state, signal triggers, guard conditions, entry/exit actions, effects, deadlock detection. Supports `state def`, `exhibit state`, and nested state regions (e.g. parallel orthogonal states)
- **Action flows**: Sequential execution, fork/join, if/else, while loops, assign, send actions

### Customization

| Variable | Default | Description |
|----------|---------|-------------|
| `sysml2-cli-executable` | `"sysml"` | Path to the sysml CLI binary |
| `sysml2-simulate-max-steps` | `100` | Default maximum simulation steps |

### Multi-File Import Resolution

When models span multiple files with `import` statements, use `-I` to include additional files for resolution:

```sh
sysml simulate list model.sysml -I lib/
sysml check model.sysml -I shared-library/
```

## CLI Analysis

When the `sysml` CLI is installed, additional analysis and refactoring commands are available for cross-file validation, project-level queries, and code transformation. Refactoring commands always show a JSON-driven preview and prompt for confirmation before touching disk.

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-t l` | `sysml2-cli-lint` | Alias for `sysml2-cli-check` (the CLI's `lint` command was removed) |
| `C-c C-t c` | `sysml2-cli-check` | Comprehensive checks + project integrity |
| `C-c C-t s` | `sysml2-cli-list` | List model elements (with kind filter) |
| `C-c C-t w` | `sysml2-cli-show` | Show element details |
| `C-c C-t t` | `sysml2-cli-trace` | Requirements traceability matrix |
| `C-c C-t a` | `sysml2-cli-stats` | Model statistics (renders the ModelStats view) |
| `C-c C-t d` | `sysml2-cli-deps` | Forward/reverse dependency analysis |
| `C-c C-t v` | `sysml2-cli-coverage` | Model completeness and quality score |
| `C-c C-t f` | `sysml2-cli-find` | Search names via `sysml list -n` (prefix arg: `--doc` text search) |
| `C-c C-t g` | `sysml2-cli-doc` | Generate Markdown documentation |
| `C-c C-t n` | `sysml2-cli-analyze` | List analysis cases (`sysml list -k analyses`) |
| `C-c C-t r` | `sysml2-cli-rollup` | Attribute rollup (mass/cost/power/…) |
| `C-c C-t i` | `sysml2-cli-interfaces` | Render the PortTable view (`C-u`: unconnected ports via `check`/W016) |
| `C-c C-t o` | `sysml2-cli-allocation` | Logical-to-physical allocation matrix |
| `C-c C-t D` | `sysml2-cli-diff` | Semantic diff between two SysML files |
| `C-c C-t R` | `sysml2-cli-rename` | Refactor: rename element (`C-u` for project-wide) |
| `C-c C-t A` | `sysml2-cli-add` | Refactor: add an element from a template |
| `C-c C-t K` | `sysml2-cli-remove` | Refactor: remove an element |
| `C-c C-t V` | `sysml2-cli-view` | Render a model-defined view (empty name lists views) |
| `C-c C-t u` | `sysml2-cli-analyze-run` | Run an analysis case (prefix arg: choose uncertainty method) |

All commands automatically forward `-I PROJECT-ROOT` and `--stdlib-path` to the CLI when a project root is detected, so cross-file resolution Just Works without per-buffer configuration.

A transient picker is available at `C-c C-t RET` for keyboard browsing.

## Formatting

Re-indent the buffer or region using the tree-sitter indentation engine (no external tools needed):

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-= =` | `sysml2-format-buffer` | Re-indent entire buffer |
| `C-c C-= r` | `sysml2-format-region` | Re-indent selected region |

Enable `sysml2-format-on-save-mode` to auto-format before every save.

For a CI-style "would the canonical formatter change anything?" gate that
does NOT modify the buffer, run `M-x sysml2-format-check-via-cli` (uses
`sysml fmt --check -f json`), or set the defcustom
`sysml2-format-check-on-save` to `t` to warn automatically on every save.

## Systems Modeling API

REST client for the [Systems Modeling API](https://www.omg.org/spec/SystemsModelingAPI/) v1.0:

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-a l` | `sysml2-api-list-projects` | List remote projects |
| `C-c C-a q` | `sysml2-api-query` | Execute query against project |

```elisp
(setq sysml2-api-base-url "http://localhost:9000")
(setq sysml2-api-project-id "my-project-id")
```

## LSP Support

Integrates with both [eglot](https://github.com/joaotavora/eglot) (built into Emacs 29+) and [lsp-mode](https://github.com/emacs-lsp/lsp-mode). Provides cross-file go-to-definition, find-references, completion, hover, inlay hints, semantic tokens, code actions, type hierarchy, code lenses, document links, and diagnostics from the language server.

The default server is **`sysml-lsp`** (Rust, from the same workspace as
the CLI) which advertises 17 capabilities including codeLens
(satisfy/verify/usage counts above each definition) and documentLink
(clickable imports and super-types). Three additional servers are
recognised:

### sysml-lsp (default, recommended)

```elisp
(setq sysml2-lsp-server 'sysml-lsp)   ;; default
```

Built from <https://github.com/jackhale98/sysml-cli> (same workspace as
the `sysml` CLI). Install with
`cargo install --path crates/sysml-lsp`. Advertises 17 capabilities
including codeLens (satisfy/verify/usage counts above each definition)
and documentLink (clickable imports and super-types).

### SysIDE (Sensmetry)

[SysIDE](https://github.com/sensmetry/sysml-2ls) is an open-source LSP server for SysML v2. Note: this project was archived in Oct 2025 but remains functional.

```elisp
(setq sysml2-lsp-server 'syside)
(setq sysml2-lsp-server-path "/path/to/syside-lsp")
```

### Eclipse SysON

[SysON](https://github.com/eclipse-syson/syson) is Eclipse's actively maintained SysML v2 tooling with LSP support.

```elisp
(setq sysml2-lsp-server 'syson
      sysml2-lsp-server-path "/path/to/syson-language-server.jar")
```

(The `syson` backend runs the jar with `java -jar`, so both variables
are required.)

With eglot (recommended, built into Emacs 29+):

```elisp
(use-package sysml2-mode
  :hook (sysml2-mode . eglot-ensure))
```

### SysML v2 Pilot Implementation

The [official OMG pilot](https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation) is an Eclipse/Xtext-based implementation that can run as a Java LSP server.

```elisp
(setq sysml2-lsp-server 'pilot)
(setq sysml2-lsp-server-path "/path/to/sysml2-pilot.jar")
```

### Disabling LSP

```elisp
(setq sysml2-lsp-server 'none)
```

## Evil-Mode Integration

Optional keybindings for [evil-mode](https://github.com/emacs-evil/evil) users via [general.el](https://github.com/noctuid/general.el) (`SPC m` prefix, Doom/Spacemacs style):

| Prefix | Category |
|--------|----------|
| `SPC m n` | Navigation (outline, goto-definition) |
| `SPC m r` | Rename symbol |
| `SPC m o` | Outline panel |
| `SPC m c` | Connections (connect, flow, bind, verify, subject, etc.) |
| `SPC m d` | Diagram (tree, IBD, state, playground, etc.) |
| `SPC m m` | Model scaffolding |
| `SPC m a` | API |
| `SPC m l` | LSP |
| `SPC m s` | Simulation / FMI |
| `SPC m x` | Native simulation |
| `SPC m =` | Format (buffer, region) |
| `SPC m t` | CLI analysis (lint, trace, deps, coverage) |
| `SPC m i` | Inspect / Report |
| `SPC m f` | Code folding |

Plus `gd` for goto-definition in normal state. Neither evil nor general.el is a hard dependency.

## Keybinding Reference

| Binding | Command |
|---------|---------|
| **Navigation** | |
| `M-.` | `sysml2-goto-definition` |
| `M-?` | `sysml2-find-references` |
| `C-c C-r` | `sysml2-rename-symbol` |
| `C-c C-n o` | `imenu` |
| `C-c C-n t` | `sysml2-outline-toggle` |
| **Connections** | |
| `C-c C-c c` | `sysml2-connect` |
| `C-c C-c f` | `sysml2-insert-flow` |
| `C-c C-c b` | `sysml2-insert-binding` |
| `C-c C-c i` | `sysml2-insert-interface` |
| `C-c C-c a` | `sysml2-insert-allocation` |
| `C-c C-c s` | `sysml2-insert-satisfy` |
| `C-c C-c v` | `sysml2-insert-verify` |
| `C-c C-c u` | `sysml2-insert-subject` |
| **Diagram** | |
| `C-c C-d t` | `sysml2-diagram-tree` |
| `C-c C-d i` | `sysml2-diagram-ibd` |
| `C-c C-d s` | `sysml2-diagram-state-machine` |
| `C-c C-d a` | `sysml2-diagram-action-flow` |
| `C-c C-d r` | `sysml2-diagram-requirement` |
| `C-c C-d u` | `sysml2-diagram-use-case` |
| `C-c C-d k` | `sysml2-diagram-package` |
| `C-c C-d p` | `sysml2-diagram-preview` |
| `C-c C-d v` | `sysml2-diagram-view` |
| `C-c C-d e` | `sysml2-diagram-export` |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` |
| `C-c C-d w` | `sysml2-diagram-open-in-playground` |
| **Scaffolding** | |
| `C-c m m` | `sysml2-scaffold` |
| `C-c m p` | `sysml2-scaffold-package` |
| `C-c m d` | `sysml2-scaffold-part-def` |
| `C-c m o` | `sysml2-scaffold-port-def` |
| `C-c m r` | `sysml2-scaffold-requirement-def` |
| `C-c m s` | `sysml2-scaffold-state-def` |
| `C-c m a` | `sysml2-scaffold-action-def` |
| `C-c m e` | `sysml2-scaffold-enum-def` |
| `C-c m u` | `sysml2-scaffold-use-case-def` |
| `C-c m c` | `sysml2-scaffold-calc-def` |
| **LSP** | |
| `C-c C-l s` | `sysml2-lsp-ensure` |
| `C-c C-l r` | `sysml2-lsp-restart` |
| **API** | |
| `C-c C-a l` | `sysml2-api-list-projects` |
| `C-c C-a q` | `sysml2-api-query` |
| **Simulation / FMI** | |
| `C-c C-s i` | `sysml2-fmi-inspect-fmu` |
| `C-c C-s e` | `sysml2-fmi-extract-interfaces` |
| `C-c C-s m` | `sysml2-fmi-generate-modelica` |
| `C-c C-s M` | `sysml2-fmi-generate-all-modelica` |
| `C-c C-s F` | `sysml2-fmi-batch-generate-modelica` |
| `C-c C-s b` | `sysml2-fmi-compile-fmu` |
| `C-c C-s B` | `sysml2-fmi-compile-all-fmus` |
| `C-c C-s v` | `sysml2-fmi-validate-interfaces` |
| `C-c C-s V` | `sysml2-fmi-validate-all` |
| `C-c C-s d` | `sysml2-fmi-dashboard` |
| `C-c C-s g` | `sysml2-cosim-generate-ssp` |
| `C-c C-s r` | `sysml2-cosim-run` |
| `C-c C-s p` | `sysml2-cosim-results` |
| `C-c C-s c` | `sysml2-cosim-verify-requirements` |
| `C-c C-s P` | `sysml2-cosim-pipeline` |
| **Native Simulation** | |
| `C-c C-x s` | `sysml2-simulate` |
| `C-c C-x l` | `sysml2-simulate-list` |
| `C-c C-x e` | `sysml2-simulate-eval` |
| `C-c C-x m` | `sysml2-simulate-state-machine` |
| `C-c C-x a` | `sysml2-simulate-action-flow` |
| **Format** | |
| `C-c C-= =` | `sysml2-format-buffer` |
| `C-c C-= r` | `sysml2-format-region` |
| **CLI Analysis** | |
| `C-c C-t l` | `sysml2-cli-lint` |
| `C-c C-t c` | `sysml2-cli-check` |
| `C-c C-t s` | `sysml2-cli-list` |
| `C-c C-t w` | `sysml2-cli-show` |
| `C-c C-t t` | `sysml2-cli-trace` |
| `C-c C-t a` | `sysml2-cli-stats` |
| `C-c C-t d` | `sysml2-cli-deps` |
| `C-c C-t v` | `sysml2-cli-coverage` |
| `C-c C-t f` | `sysml2-cli-find` |
| `C-c C-t g` | `sysml2-cli-doc` |
| `C-c C-t n` | `sysml2-cli-analyze` |
| `C-c C-t r` | `sysml2-cli-rollup` |
| `C-c C-t i` | `sysml2-cli-interfaces` |
| `C-c C-t o` | `sysml2-cli-allocation` |
| `C-c C-t D` | `sysml2-cli-diff` |
| `C-c C-t R` | `sysml2-cli-rename` |
| `C-c C-t A` | `sysml2-cli-add` |
| `C-c C-t K` | `sysml2-cli-remove` |
| `C-c C-t V` | `sysml2-cli-view` |
| `C-c C-t u` | `sysml2-cli-analyze-run` |
| `C-c C-t RET` | `sysml2-transient-analyze` (picker) |
| **REPL** | |
| `C-c C-x r` | `sysml2-repl` (comint inferior `sysml repl`) |
| **Health Check** | |
| `M-x sysml2-doctor` | Probe sysml CLI, grammar, LSP, D2, PlantUML, Pandoc |
| **Inspect / Report** | |
| `C-c C-i s` | `sysml2-report-summary` |
| `C-c C-i t` | `sysml2-report-traceability` |
| `C-c C-i a` | `sysml2-impact-analysis` |
| `C-c C-i m` | `sysml2-report-export-markdown` |
| `C-c C-i e` | `sysml2-report-export` |
| **Code Folding** | |
| `C-c C-f t` | `hs-toggle-hiding` |
| `C-c C-f h` | `hs-hide-block` |
| `C-c C-f s` | `hs-show-block` |
| `C-c C-f H` | `hs-hide-all` |
| `C-c C-f S` | `hs-show-all` |
| `C-c C-f l` | `hs-hide-level` |

## Customization

All customization variables are in the `sysml2` group. `M-x customize-group RET sysml2 RET` to browse.

Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `sysml2-indent-offset` | `4` | Spaces per indentation level |
| `sysml2-diagram-backend` | `'native` | Backend: `native` (SVG + D2) or `plantuml` |
| `sysml2-d2-executable-path` | `nil` | Path to D2 binary (nil = search exec-path) |
| `sysml2-d2-theme` | `nil` | D2 theme number (nil = default) |
| `sysml2-d2-layout-engine` | `nil` | D2 layout: nil (dagre), `elk`, or `tala` |
| `sysml2-lsp-server` | `'sysml-lsp` | LSP server (`sysml-lsp`, `pilot`, `syside`, `syson`, `none`) |
| `sysml2-format-check-on-save` | `nil` | When non-nil, run `sysml fmt --check -f json` on save and report drift |
| `sysml2-plantuml-exec-mode` | `'executable` | PlantUML invocation mode |
| `sysml2-diagram-output-format` | `"svg"` | Diagram output format |
| `sysml2-cli-executable` | `"sysml"` | Path to sysml CLI binary |
| `sysml2-cosim-tool` | `'fmpy` | Co-simulation tool (`fmpy`, `omsimulator`) |
| `sysml2-cosim-stop-time` | `10.0` | Default simulation stop time |
| `sysml2-fmi-type-mapping-alist` | `nil` | User SysML-to-FMI type overrides |

Additional customization (see `M-x customize-group RET sysml2 RET` for
the full set of 39 options): indentation (`sysml2-indent-tabs-mode`),
library discovery (`sysml2-standard-library-path`,
`sysml2-auto-detect-library`), diagram presentation
(`sysml2-diagram-auto-preview`, `sysml2-diagram-page-size`,
`sysml2-diagram-direction`, `sysml2-diagram-preview-window`,
`sysml2-graphviz-dot-path`, `sysml2-plantuml-executable-path`), FMI
(`sysml2-fmi-openmodelica-path`, `sysml2-fmi-fmpy-executable`,
`sysml2-fmi-default-fmi-version`, `sysml2-fmi-modelica-output-dir`),
co-simulation (`sysml2-cosim-omsimulator-path`,
`sysml2-cosim-gnuplot-path`, `sysml2-cosim-step-size`,
`sysml2-cosim-output-dir`, `sysml2-cosim-results-format`), native
simulation (`sysml2-simulate-executable`), and report export
(`sysml2-report-pandoc-executable`).

## Module Architecture

```
sysml2-vars.el          Customization variables, faces, shared state
sysml2-lang.el          Keyword lists, regexp constants (pure data)
sysml2-font-lock.el     Syntax highlighting rules
sysml2-indent.el        Indentation engine
sysml2-completion.el    Context-aware completion, scaffolding commands
sysml2-navigation.el    Imenu, which-function, defun movement
sysml2-snippets.el      Yasnippet template registration
sysml2-project.el       Project root detection, library resolution
sysml2-lsp.el           LSP client config (eglot + lsp-mode)
sysml2-flymake.el       In-buffer diagnostics (syntax + semantic)
sysml2-model.el         Shared model extraction (parts, ports, reqs, analyses, constraints, refinements)
sysml2-svg.el           Direct SVG generation (tree, requirement diagrams)
sysml2-d2.el            D2 language generation (IBD, state, action, etc.)
sysml2-plantuml.el      SysML-to-PlantUML transformation (legacy backend)
sysml2-diagram.el       Diagram dispatch, preview, export
ob-sysml.el             Org-babel: execute SysML blocks (diagrams + CLI commands)
sysml2-report.el        Model summary, traceability (IDs, derivations, refinements), analyses, constraints, allocations, Markdown/Pandoc export
sysml2-api.el           Systems Modeling API REST client
sysml2-fmi.el           FMU inspector, interface extraction, Modelica gen
sysml2-cosim.el         SSP generation, simulation, results, verification
sysml2-simulate.el      Native simulation via sysml CLI (constraints, state machines, actions)
sysml2-format.el        In-process formatting (tree-sitter indent-region)
sysml2-cli-commands.el  CLI analysis + refactor wrappers (check, list, show, trace, stats, deps, coverage, find, doc, analyze, rollup, interfaces, allocation, diff, rename, add, remove)
sysml2-doctor.el        Health check probe for CLI, grammar, LSP, D2, PlantUML, Pandoc, stdlib
sysml2-menu.el          Easy-menu bar + which-key prefix labels
sysml2-repl.el          comint-mode inferior `sysml repl' session
sysml2-transient.el     transient.el pickers for diagrams, scaffold, analyze
sysml2-outline.el       Outline side panel
sysml2-eldoc.el         Definition/documentation at point (ElDoc)
sysml2-evil.el          Optional evil-mode keybindings
sysml2-ts.el            Tree-sitter grammar integration (font-lock, indent, imenu, thing-settings, outline)
sysml2-mode.el          Entry point, syntax table, keymap, mode definition
```

Canonical tree-sitter query files (consumed by other editors) live in
`tree-sitter-sysml/queries/`: `highlights.scm`, `indents.scm`,
`folds.scm`, `locals.scm`, `tags.scm`.

## Testing

365 ERT tests across 28 test files (`make test`).

```bash
make test
```

Test files cover the language layer, font-lock, indentation,
completion, navigation, project detection, flymake (in-process and CLI
codes), tree-sitter parsing/imenu/structural movement, outline, FMI,
co-simulation, evil-mode wiring, REST API, org-babel, the menu bar +
which-key registration, `sysml2-doctor`, autoload coverage, the
canonical `.scm` query files, REPL prompt-regex detection, transient
pickers, all CLI command wrappers (including rename / add / remove
preview-then-apply flows), and `sysml2-format-check-via-cli`.

## License

GPL-3.0-or-later
