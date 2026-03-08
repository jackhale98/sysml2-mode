# sysml2-mode

An Emacs major mode for editing [SysML v2](https://www.omgsysml.org/SysML-2.htm) and [KerML](https://www.omg.org/spec/KerML/) textual notation files.

Provides syntax highlighting, indentation, completion, navigation, diagram generation, FMI/FMU integration, co-simulation orchestration, and LSP support.

**Requires:** Emacs 29.1+

**[Tutorial](TUTORIAL.md)** — Step-by-step guide to building a complete SysML v2 model with sysml2-mode (drone system example covering all 20 SysML v2 concepts).

## Table of Contents

- [Installation](#installation)
- [Features](#features)
- [Diagram Generation](#diagram-generation)
- [Model Scaffolding](#model-scaffolding)
- [FMI/FMU Integration](#fmifmu-integration)
- [Co-Simulation](#co-simulation)
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
  :config
  (require 'sysml2-evil)  ;; SPC m keybindings
  (require 'sysml2-ts))   ;; tree-sitter support
```

Then run `doom sync`.

## Features

### Syntax Highlighting

Three font-lock levels with 120+ keywords across 10 categories:

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
| Line start | Definition and usage keywords |
| After `import` | Standard library packages (35), `*` |
| After `:` (type position) | Buffer definitions, standard library |
| After `:>` (specialization) | Buffer definitions, standard library |
| After `:>>` (redefinition) | Buffer definitions |
| After `in`/`out`/`inout` | Usage keywords |
| After `#` | Metadata keywords |

### Navigation

- **Imenu** (`C-c C-n o`): Hierarchical index organized by definition category (22 categories)
- **which-function-mode**: Shows enclosing definition/package in mode line
- **beginning/end-of-defun**: `C-M-a` / `C-M-e` navigate between definitions
- **Outline side panel** (`C-c C-n t`): Tree view in a left side window

### Snippets

32 yasnippet templates for common patterns (requires [yasnippet](https://github.com/joaotavora/yasnippet)):

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

Seven in-buffer checks with no external tools required:

**Syntax checks:**

1. **Unmatched delimiters** -- detects mismatched `{}`, `[]`, `()`
2. **Unknown definition keywords** -- catches typos like `prat def`
3. **Missing semicolons** -- warns on single-line usages without trailing `;`

**Semantic checks** (note-level hints):

4. **Unsatisfied requirements** -- requirement defs with no `satisfy` statement
5. **Unverified requirements** -- requirement defs with no `verify` statement
6. **Unused definitions** -- definitions never referenced elsewhere in the buffer
7. **Invalid library references** -- validates ISQ, SI, and ScalarValues qualified names

### Project Detection

Automatic project root detection (ascending search):

1. `.sysml-project` file (highest priority)
2. `sysml.library/` directory
3. `.git` directory

Standard library path is auto-resolved from project root or a custom path.

### Tree-Sitter Support

When the [`sysml` tree-sitter grammar](https://github.com/jackhale98/tree-sitter-sysml) is installed, `sysml2-mode` automatically remaps to `sysml2-ts-mode` for:

- **Font-lock** — node-type-aware highlighting (7 feature groups)
- **Indentation** — parent-type-based indent rules
- **Imenu** — 28 definition categories from parse tree
- **Which-function** — accurate enclosing definition via `treesit-parent-until`
- **Completion** — context-aware CAPF using parse tree queries
- **Flymake** — tree-sitter ERROR node reporting
- **Goto-definition / Rename** — parse-tree-based search

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
| `C-c C-d v` | `sysml2-diagram-view` | Generate from view def filter |
| `C-c C-d e` | `sysml2-diagram-export` | Export to file |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` | View diagram source |
| `C-c C-d w` | `sysml2-diagram-open-in-playground` | Open in D2 web playground |

Scoped diagrams (IBD, state machine, action flow) auto-detect the
enclosing definition or prompt for a scope name.

View-filtered diagrams (`C-c C-d v`) parse `view def` declarations with
`render` clauses, `filter @SysML::...` metatype filters, and `:>`
inheritance to determine the diagram type automatically.

### Native Backend (default)

The native backend (`sysml2-diagram-backend` = `native`) uses two rendering engines:

- **Direct SVG** (zero dependencies) for deterministic layouts: tree/BDD diagrams (hierarchical depth-based layout with L-shaped connectors) and requirement trees (with verify/satisfy annotations, requirement IDs, and color-coded coverage status)
- **[D2](https://d2lang.com)** for graph layouts: IBD, state machine, action flow, use case, and package diagrams

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
#+BEGIN_SRC sysml :diagram-type tree :file vehicle.svg
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
| `C-c m p` | `sysml2-scaffold-package` | Package with optional imports |
| `C-c m d` | `sysml2-scaffold-part-def` | Part def with attributes, ports, specialization |
| `C-c m o` | `sysml2-scaffold-port-def` | Port def with directional items |
| `C-c m r` | `sysml2-scaffold-requirement-def` | Requirement def with doc, subject, constraint |
| `C-c m s` | `sysml2-scaffold-state-def` | State def with states and auto-generated transitions |
| `C-c m a` | `sysml2-scaffold-action-def` | Action def with sub-actions and successions |
| `C-c m e` | `sysml2-scaffold-enum-def` | Enum def with literals |
| `C-c m u` | `sysml2-scaffold-use-case-def` | Use case def with subject, actors, includes |
| `C-c m c` | `sysml2-scaffold-calc-def` | Calc def with in params and return value |

## FMI/FMU Integration

FMI 3.0 support for model exchange and co-simulation workflows.

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

## Co-Simulation

Orchestrate co-simulation runs with FMPy or OMSimulator.

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

Integrates with both [eglot](https://github.com/joaotavora/eglot) (built into Emacs 29+) and [lsp-mode](https://github.com/emacs-lsp/lsp-mode). Provides cross-file go-to-definition, find-references, completion, and diagnostics from the language server.

Two servers are supported:

### SysIDE (Sensmetry)

[SysIDE](https://github.com/sensmetry/sysml-2ls) is an open-source LSP server for SysML v2. Note: this project was archived in Oct 2025 but remains functional.

```elisp
(setq sysml2-lsp-server 'syside)
(setq sysml2-lsp-server-path "/path/to/syside-lsp")
```

### Eclipse SysON

[SysON](https://github.com/eclipse-syson/syson) is Eclipse's actively maintained SysML v2 tooling with LSP support.

```elisp
(setq sysml2-lsp-server 'syson)
```

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
| `SPC m i` | Inspect / Report |
| `SPC m f` | Code folding |

Plus `gd` for goto-definition in normal state. Neither evil nor general.el is a hard dependency.

## Keybinding Reference

| Binding | Command |
|---------|---------|
| **Navigation** | |
| `M-.` | `sysml2-goto-definition` |
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
| `C-c C-s v` | `sysml2-fmi-validate-interfaces` |
| `C-c C-s g` | `sysml2-cosim-generate-ssp` |
| `C-c C-s r` | `sysml2-cosim-run` |
| `C-c C-s p` | `sysml2-cosim-results` |
| `C-c C-s c` | `sysml2-cosim-verify-requirements` |
| **Inspect / Report** | |
| `C-c C-i s` | `sysml2-report-summary` |
| `C-c C-i t` | `sysml2-report-traceability` |
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
| `sysml2-lsp-server` | `'pilot` | LSP server (`pilot`, `syside`, `syson`, `none`) |
| `sysml2-plantuml-exec-mode` | `'executable` | PlantUML invocation mode |
| `sysml2-diagram-output-format` | `"svg"` | Diagram output format |
| `sysml2-cosim-tool` | `'fmpy` | Co-simulation tool (`fmpy`, `omsimulator`) |
| `sysml2-cosim-stop-time` | `10.0` | Default simulation stop time |
| `sysml2-fmi-type-mapping-alist` | `nil` | User SysML-to-FMI type overrides |

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
sysml2-diagram.el       Diagram dispatch, preview, export, org-babel
sysml2-report.el        Model summary, traceability (IDs, derivations, refinements), analyses, constraints, allocations, Markdown/Pandoc export
sysml2-api.el           Systems Modeling API REST client
sysml2-fmi.el           FMU inspector, interface extraction, Modelica gen
sysml2-cosim.el         SSP generation, simulation, results, verification
sysml2-outline.el       Outline side panel
sysml2-eldoc.el         Definition/documentation at point (ElDoc)
sysml2-evil.el          Optional evil-mode keybindings
sysml2-ts.el            Tree-sitter grammar integration
sysml2-mode.el          Entry point, syntax table, keymap, mode definition
```

## Testing

240 ERT tests across 16 test files:

```bash
make test
# or manually:
emacs --batch -L . -L test -l sysml2-mode \
  -l test/test-helper.el -l test/test-lang.el \
  -l test/test-font-lock.el -l test/test-indent.el \
  -l test/test-completion.el -l test/test-navigation.el \
  -l test/test-plantuml.el -l test/test-diagram.el \
  -l test/test-project.el -l test/test-flymake.el \
  -l test/test-outline.el -l test/test-fmi.el \
  -l test/test-cosim.el -l test/test-evil.el \
  -l test/test-api.el -l test/test-ts.el \
  -f ert-run-tests-batch-and-exit
```

## License

GPL-3.0-or-later
