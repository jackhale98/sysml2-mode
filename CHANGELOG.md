# Changelog

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
- 28 new tests: verification/allocation extraction, requirement IDs,
  hierarchical tree layout, view filter parsing, report enhancements,
  analysis/constraint/refinement extraction and rendering

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
