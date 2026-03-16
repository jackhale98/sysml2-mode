# Changelog

## 0.3.0 — 2026-03-15

### Added
- **sysml CLI integration**: Unified `sysml2-cli-executable` defcustom
  (default `"sysml"`) replaces the old `sysml2-simulate-executable`
  (`"sysml2-cli"`). All CLI-dependent features now use this single setting.
- **CLI analysis commands** (`sysml2-cli-commands.el`): 8 new interactive
  commands for cross-file analysis — lint, check, list (with kind filter),
  show, trace, stats, deps, coverage (`C-c C-t` prefix)
- **In-process formatting** (`sysml2-format.el`): `sysml2-format-buffer`
  (`C-c C-= =`) and `sysml2-format-region` (`C-c C-= r`) re-indent using
  tree-sitter rules — no external tools needed. `sysml2-format-on-save-mode`
  for auto-format on save.
- **Async Flymake CLI backend**: When the sysml CLI is installed, runs
  `sysml lint -f json` asynchronously and reports cross-file diagnostics
  (W004-W008: unresolved refs, port types, empty constraints, missing
  returns) alongside in-process checks
- **65+ tree-sitter indent rules**: Expanded from 15 to cover all body
  types, control flow (if/while/for/loop), fork/join/merge/decide,
  entry/do/exit actions, perform/exhibit/include, metadata annotations,
  parenthesized expressions, all usage types, and multi-line definitions
- **Diagram compartments**: BDD/tree blocks show 3 compartments (ports,
  attributes, parts) separated by dividers. IBD parts show attributes from
  type definitions. Matches UML class diagram style.
- **State machine entry/do/exit**: State nodes display action compartments
  (e.g. `entry / performSelfTest`, `do / providePower`)
- **Transition labels**: Full SysML format `trigger [guard] / effect`
- **Action flow control nodes**: Fork/join rendered as bars, decide/merge as
  diamonds. Handles `start`/`done` pseudo-nodes.
- **View expose clauses**: `sysml2-diagram-view` parses `expose` clauses to
  auto-resolve diagram scope
- **Model extractors**: States return `:entry/:do/:exit` actions. Transitions
  capture `:guard` and `:effect`. New `sysml2--model-extract-control-nodes`
  for fork/join/merge/decide.
- 6 new indentation tests (state body, enum, use case, verification,
  connection ends, idempotent nested re-indent)
- Evil/general.el keybindings for format (`SPC m =`) and CLI analysis
  (`SPC m t`) commands

### Changed
- CLI executable default changed from `"sysml2-cli"` to `"sysml"` (the
  sysml-lint project was restructured into a 12-crate sysml-cli workspace)
- `sysml2-simulate-executable` is now optional; defaults to
  `sysml2-cli-executable` when nil
- Tree-sitter indent catch-all changed from `parent-bol + offset` to
  `parent-bol + 0` to avoid spurious indentation

## 0.2.1 — 2026-03-08

### Added
- Diagram export now prompts for diagram type, scope, and output file
  (`C-c C-d e`) instead of relying on auto-detection at point
- Diagram preview scales to fit the preview window using `:max-width`
  and `:max-height` image properties
- Simulation commands now offer completion candidates extracted from
  the model: trigger signals for state machines, parameter names for
  constraints and calculations, construct names for all types
- Multi-select event picker for state machine simulation with trigger
  signal completion
- Per-parameter prompting for constraint/calculation evaluation
- sysml2-cli executable resolution: checks `~/.cargo/bin/` and
  `~/.local/bin/` as fallback paths for simulation and FMI commands
- FMI commands (`extract-interfaces`, `generate-modelica`,
  `validate-interfaces`) now offer part def completion from exportable
  parts instead of bare text input
- `sysml2-fmi-batch-generate-modelica` (`C-c C-s F` / `SPC m s F`):
  generate Modelica stubs for all exportable parts across multiple
  SysML files in a directory

### Fixed
- Cross-platform compatibility: all external tool resolution now uses
  `sysml2--find-executable` with platform-aware fallback paths for
  Windows (`%LOCALAPPDATA%`), macOS (`/opt/homebrew/bin`), and Linux
  (`~/.local/bin`, `~/.cargo/bin`)
- Windows support: FMU extraction (`unzip`) and SSP packaging (`zip`)
  now use PowerShell `Expand-Archive`/`Compress-Archive` on Windows
- Windows support: OpenModelica resolution checks for `.exe` extension
  and Windows-specific install paths
- Windows support: HTML report `file://` URLs use three-slash format
  (`file:///C:/...`) required by Windows browsers
- D2 fallback messaging: displays a user-visible message when falling
  back to SVG rendering because D2 was not found

## 0.2.0 — 2026-03-07

### Added
- Hierarchical tree diagrams: depth-based layout with L-shaped connectors
  replacing flat column alignment; children indented right of parents
- Requirements diagrams: verify/satisfy annotations, requirement ID display
  (`<'ID'>` syntax), color-coded status fills (green=full, yellow=partial,
  red=gap, blue=no-satisfy), and a legend
- Model extraction: verify relationships (`sysml2--model-extract-verifications`),
  allocate relationships (`sysml2--model-extract-allocations`), requirement
  short-name IDs (`:id` field), composition extraction from `part def` bodies
- ISO 13485 traceability: requirement ID column in traceability matrix (both
  interactive and Markdown export), new Allocation Matrix report section
- View filter improvements: `render` clause parsing (e.g. `render asTreeDiagram`),
  view inheritance via `:>` specialization, view usage parsing (not just defs),
  extended metatype mappings (15 metatypes + 8 render methods)
- Deterministic report output: all report tables sorted alphabetically for
  stable git diffs
- `sysml2-diagram-view` command (`C-c C-d v`): generate diagrams from `view def`
  filter and render clauses
- Model extraction: analysis cases (`sysml2--model-extract-analyses`) with
  subject, objective, and parameter extraction; constraint definitions
  (`sysml2--model-extract-constraints`) with parameters and constraint
  expression; refinement dependencies (`sysml2--model-extract-refinements`)
  for `#refinement dependency NAME to TARGET;` patterns
- Report sections: Analysis Cases table (name, type, subject, objective),
  Constraint Definitions table (name, parameters, expression)
- Traceability: "Refined To" column in both interactive and Markdown export
  showing `#refinement dependency` relationships; requirement decomposition
  hierarchy with parent-child indentation; derivation chain tracking
- `sysml2-impact-analysis` command (`C-c C-i a` / `SPC m i a`): interactive
  impact analysis at point showing upstream dependencies and downstream
  dependents across compositions, specializations, connections, flows,
  satisfy/verify, allocations, derivations, refinements, and requirements
- 32 new tests: verification/allocation extraction, requirement IDs,
  hierarchical tree layout, view filter parsing, report enhancements,
  analysis/constraint/refinement extraction, impact analysis

### Fixed
- Byte-compilation: added missing `(require 'cl-lib)` in 5 modules
  (sysml2-outline, sysml2-diagram, sysml2-model, sysml2-cosim, sysml2-plantuml)
- Verification extraction regex: correctly matches outer `verification` block
  brace instead of inner `verify` statement brace
- Composition extraction: Pass 2 scans `part def` bodies for child parts
  (previously only extracted from part usage bodies)
- SVG byte-compilation: renamed `left-margin` to avoid shadowing Emacs dynamic
  variable
- Scope selection: `completing-read` always shows all candidates with at-point
  default, instead of auto-selecting

## 0.1.0 — 2026-03-07

### Added
- Tree-sitter support via separate grammar repo
  ([tree-sitter-sysml](https://github.com/jackhale98/tree-sitter-sysml))
  - 195 corpus tests, ~95% SysML v2 specification coverage
  - `sysml2-ts-mode` auto-activates when grammar is installed
  - Install: `M-x treesit-install-language-grammar RET sysml`
- Full KerML support: class, struct, assoc, behavior, datatype, feature,
  function, interaction, connector, predicate, namespace, type, classifier,
  metaclass, expr, step — definitions and usages
- Relationship keywords: conjugates, references, chains, inverse of, subsets,
  redefines
- Loop action (`loop ... until`)
- Conditional expressions (`if expr ? expr else expr`)
- Library/standard library package declarations
- Smart connection editing (`C-c C-c` prefix):
  - `sysml2-connect` — connection with annotated source/target completion
  - `sysml2-insert-flow` — flow connection with item type
  - `sysml2-insert-binding` — binding connector
  - `sysml2-insert-interface` — interface usage
  - `sysml2-insert-allocation` — allocation
  - `sysml2-insert-satisfy` — satisfy requirement (filters to req/constraint)
  - All source/target prompts require selection from existing buffer elements
    with type annotations (e.g. `<port : FuelPort>`, `<path>`)
  - New entity names use free text input
- Context-aware completion after `connect`, `to`, and `by` keywords
- Smart dot-path completion (`partName.portName`) for connection targets
- Outline side panel (`C-c C-n t` / `SPC m o`): hierarchical view of
  definitions with jump-to-source
- PlantUML diagram generation: 7 diagram types
  - Tree (BDD), Interconnection (IBD), State Machine, Action Flow,
    Requirement Tree, Use Case, Package
- Org-Babel integration for SysML v2 code blocks
- FMI 3.0 / co-simulation integration
- 4 new snippets: `fl` (flow), `ifc` (interface), `alloc` (allocation),
  `bind` (binding)
- Evil mode / Doom Emacs support (`SPC m` prefix via general.el)
- Test infrastructure: 210 ERT tests
- CI with GitHub Actions (Emacs 29.4 + 30.1)
- Eclipse SysON and Pilot LSP server support
- Makefile with test, compile, clean, lint targets

### Changed
- Tree-sitter grammar split to standalone repo:
  [jackhale98/tree-sitter-sysml](https://github.com/jackhale98/tree-sitter-sysml)
- Corrected BNF keyword forms: `enum def` (was `enumeration def`), `flow def`
  (was `flow connection def`), `analysis def` (was `analysis case def`),
  `verification def` (was `verification case def`)
- Default LSP server changed from syside to pilot (syside archived Oct 2025)
- Diagram type menu now includes all 7 diagram types (was missing use-case
  and package)

### Fixed
- Byte-compiled doc string loading on Emacs 29.4
  (`byte-compile-dynamic-docstrings` disabled in sysml2-vars.el)
- Import statement parsing in tree-sitter grammar (wildcard suffix conflict)
- Multi-word keyword font-lock priority
- Byte-compilation warnings across all modules
