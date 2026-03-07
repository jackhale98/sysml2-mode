# Changelog

## 0.1.0 — 2026-03-07

### Added
- Tree-sitter grammar for SysML v2 / KerML (`tree-sitter-sysml/`)
  - 195 corpus tests, 7 fixture files parse cleanly (including official Annex A)
  - ~95% SysML v2 specification coverage
- Full KerML support: class, struct, assoc, behavior, datatype, feature,
  function, interaction, connector, predicate, namespace, type, classifier,
  metaclass, expr, step — definitions and usages
- Relationship keywords: conjugates, references, chains, inverse of, subsets,
  redefines
- Loop action (`loop ... until`)
- Conditional expressions (`if expr ? expr else expr`)
- Library/standard library package declarations
- Smart connection editing (`C-c C-c` prefix):
  - `sysml2-connect` — interactive connection insertion with buffer-aware completion
  - `sysml2-insert-flow` — flow connection with item type
  - `sysml2-insert-binding` — binding connector
  - `sysml2-insert-interface` — interface usage
  - `sysml2-insert-allocation` — allocation
  - `sysml2-insert-satisfy` — satisfy requirement
- Context-aware completion after `connect`, `to`, and `by` keywords
- Smart dot-path completion (`partName.portName`) for connection targets
- PlantUML diagram generation: 7 diagram types
  - Tree (BDD), Interconnection (IBD), State Machine, Action Flow,
    Requirement Tree, Use Case, Package
- Org-Babel integration for SysML v2 code blocks
- FMI 3.0 / co-simulation integration
- 4 new snippets: `fl` (flow), `ifc` (interface), `alloc` (allocation),
  `bind` (binding)
- Test infrastructure: 79 ERT tests, 195 tree-sitter corpus tests
- CI with GitHub Actions (Emacs 29.4 + 30.1)
- Eclipse SysON and Pilot LSP server support
- Makefile with test, compile, clean, lint targets

### Changed
- Corrected BNF keyword forms: `enum def` (was `enumeration def`), `flow def`
  (was `flow connection def`), `analysis def` (was `analysis case def`),
  `verification def` (was `verification case def`)
- Default LSP server changed from syside to pilot (syside archived Oct 2025)
- Diagram type menu now includes all 7 diagram types (was missing use-case
  and package)

### Fixed
- Import statement parsing in tree-sitter grammar (wildcard suffix conflict)
- Multi-word keyword font-lock priority
- Byte-compilation warnings across all modules
