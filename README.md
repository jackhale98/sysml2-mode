# sysml2-mode

An Emacs major mode for editing [SysML v2](https://www.omgsysml.org/SysML-2.htm) and [KerML](https://www.omg.org/spec/KerML/) textual notation files.

Provides syntax highlighting, indentation, completion, navigation, diagram generation, FMI/FMU integration, co-simulation orchestration, and LSP support.

**Requires:** Emacs 29.1+

## Installation

### From source

```bash
git clone https://github.com/sysml2-mode/sysml2-mode.git
```

Add to your init file:

```elisp
(add-to-list 'load-path "/path/to/sysml2-mode")
(require 'sysml2-mode)
```

### use-package

```elisp
(use-package sysml2-mode
  :load-path "/path/to/sysml2-mode"
  :mode (("\\.sysml\\'" . sysml2-mode)
         ("\\.kerml\\'"  . kerml-mode)))
```

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

25 yasnippet templates for common patterns (requires [yasnippet](https://github.com/joaotavora/yasnippet)):

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

When the `sysml` tree-sitter grammar is installed, `sysml2-mode` automatically remaps to `sysml2-ts-mode` for incremental, context-aware highlighting and indentation.

## Diagram Generation

Generate [PlantUML](https://plantuml.com/) diagrams from SysML v2 models. Seven diagram types:

| Type | Command | Description |
|------|---------|-------------|
| Parts Tree (BDD) | `C-c C-d b` | Class diagram of definitions and compositions |
| Interconnection (IBD) | `C-c C-d p` | Component diagram of a part def's internal structure |
| State Machine | `C-c C-d p` | State diagram (auto-detected inside `state def`) |
| Action Flow | `C-c C-d p` | Activity diagram (auto-detected inside `action def`) |
| Requirement Tree | `C-c C-d p` | Requirement hierarchy with satisfy relationships |
| Use Case | `C-c C-d p` | Actors, use cases, includes |
| Package | `C-c C-d p` | Package hierarchy with import arrows |

`C-c C-d p` auto-detects the diagram type at point.

### Diagram Commands

| Binding | Command | Description |
|---------|---------|-------------|
| `C-c C-d p` | `sysml2-diagram-preview` | Preview diagram at point |
| `C-c C-d b` | `sysml2-diagram-preview-buffer` | Preview full buffer tree |
| `C-c C-d e` | `sysml2-diagram-export` | Export to file |
| `C-c C-d t` | `sysml2-diagram-type` | Select diagram type |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` | View generated PlantUML source |

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

### SysIDE (Sensmetry) -- Recommended

[SysIDE](https://github.com/sensmetry/sysml-2ls) is an open-source LSP server with the most complete SysML v2 language support.

**Install:**

```bash
git clone https://github.com/sensmetry/sysml-2ls.git
cd sysml-2ls
npm install
npm run build
```

The language server binary is at `packages/syside-languageserver/bin/syside-lsp`. Add it to your `PATH` or configure:

```elisp
(setq sysml2-lsp-server 'syside)  ;; default
(setq sysml2-lsp-server-path "/path/to/syside-lsp")
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

Optional keybindings for [evil-mode](https://github.com/emacs-evil/evil) users. Provides two binding layers:

1. **Localleader** (`,` prefix) -- works for all evil users
2. **general.el** (`SPC m` prefix) -- Doom/Spacemacs style

| Prefix | Category |
|--------|----------|
| `, n` / `SPC m n` | Navigation |
| `, d` / `SPC m d` | Diagram |
| `, a` / `SPC m a` | API |
| `, l` / `SPC m l` | LSP |
| `, s` / `SPC m s` | Simulation / FMI |

Neither evil nor general.el is a hard dependency.

## Keybinding Reference

| Binding | Command |
|---------|---------|
| **Navigation** | |
| `C-c C-n o` | `imenu` |
| `C-c C-n t` | `sysml2-outline-toggle` |
| **LSP** | |
| `C-c C-l s` | `sysml2-lsp-ensure` |
| `C-c C-l r` | `sysml2-lsp-restart` |
| **Diagram** | |
| `C-c C-d p` | `sysml2-diagram-preview` |
| `C-c C-d b` | `sysml2-diagram-preview-buffer` |
| `C-c C-d e` | `sysml2-diagram-export` |
| `C-c C-d t` | `sysml2-diagram-type` |
| `C-c C-d o` | `sysml2-diagram-open-plantuml` |
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
| `sysml2-lsp-server` | `'syside` | LSP server (`syside`, `pilot`, `none`) |
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

154 ERT tests across 12 test files:

```bash
emacs --batch -L . -L test \
  -l sysml2-mode \
  -l test/test-font-lock.el \
  -l test/test-indent.el \
  -l test/test-completion.el \
  -l test/test-plantuml.el \
  -l test/test-diagram.el \
  -l test/test-project.el \
  -l test/test-flymake.el \
  -l test/test-api.el \
  -l test/test-evil.el \
  -l test/test-outline.el \
  -l test/test-fmi.el \
  -l test/test-cosim.el \
  -f ert-run-tests-batch-and-exit
```

## License

GPL-3.0-or-later
