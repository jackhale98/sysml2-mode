# Changelog

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
- Test infrastructure: 202 ERT tests
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
