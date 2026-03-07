# sysml2-mode

An Emacs major mode for editing [SysML v2](https://www.omgsysml.org/SysML-2.htm) and [KerML](https://www.omg.org/spec/KerML/) textual notation files.

Provides syntax highlighting, indentation, completion, navigation, diagram generation, FMI/FMU integration, co-simulation orchestration, and LSP support.

**Requires:** Emacs 29.1+

**[Tutorial](TUTORIAL.md)** — Step-by-step guide to building a complete SysML v2 model with sysml2-mode (drone system example covering all 20 SysML v2 concepts).

## Table of Contents

- [Installation](#installation)
- [Features](#features)
- [Diagram Generation](#diagram-generation)
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

Three in-buffer checks with no external tools required:

1. **Unmatched delimiters** -- detects mismatched `{}`, `[]`, `()`
2. **Unknown definition keywords** -- catches typos like `prat def`
3. **Missing semicolons** -- warns on single-line usages without trailing `;`

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

Generate [PlantUML](https://plantuml.com/) diagrams from SysML v2 models. Seven diagram types:

Each diagram type has its own command:

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
| `C-c C-d e` | `sysml2-diagram-export` | Export to file |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` | View PlantUML source |

Scoped diagrams (IBD, state machine, action flow) auto-detect the
enclosing definition or prompt for a scope name.

### PlantUML Execution Modes

```elisp
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
| `SPC m c` | Connections (connect, flow, bind, etc.) |
| `SPC m d` | Diagram (tree, IBD, state, etc.) |
| `SPC m a` | API |
| `SPC m l` | LSP |
| `SPC m s` | Simulation / FMI |

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
| **Diagram** | |
| `C-c C-d t` | `sysml2-diagram-tree` |
| `C-c C-d i` | `sysml2-diagram-ibd` |
| `C-c C-d s` | `sysml2-diagram-state-machine` |
| `C-c C-d a` | `sysml2-diagram-action-flow` |
| `C-c C-d r` | `sysml2-diagram-requirement` |
| `C-c C-d u` | `sysml2-diagram-use-case` |
| `C-c C-d k` | `sysml2-diagram-package` |
| `C-c C-d p` | `sysml2-diagram-preview` |
| `C-c C-d e` | `sysml2-diagram-export` |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` |
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

## Customization

All customization variables are in the `sysml2` group. `M-x customize-group RET sysml2 RET` to browse.

Key variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `sysml2-indent-offset` | `4` | Spaces per indentation level |
| `sysml2-lsp-server` | `'syside` | LSP server (`syside`, `syson`, `pilot`, `none`) |
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
sysml2-completion.el    Context-aware completion
sysml2-navigation.el    Imenu, which-function, defun movement
sysml2-snippets.el      Yasnippet template registration
sysml2-project.el       Project root detection, library resolution
sysml2-lsp.el           LSP client config (eglot + lsp-mode)
sysml2-flymake.el       In-buffer diagnostics
sysml2-plantuml.el      SysML-to-PlantUML transformation engine
sysml2-diagram.el       PlantUML invocation, preview, export, org-babel
sysml2-api.el           Systems Modeling API REST client
sysml2-fmi.el           FMU inspector, interface extraction, Modelica gen
sysml2-cosim.el         SSP generation, simulation, results, verification
sysml2-outline.el       Outline side panel
sysml2-evil.el          Optional evil-mode keybindings
sysml2-ts.el            Tree-sitter grammar integration
sysml2-mode.el          Entry point, syntax table, keymap, mode definition
```

## Testing

202 ERT tests across 16 test files:

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
