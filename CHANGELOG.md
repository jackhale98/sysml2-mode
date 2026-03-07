# Changelog

## Unreleased

### Added
- Tree-sitter grammar for SysML v2 / KerML (`tree-sitter-sysml/`)
- KerML keyword support: class, struct, assoc, behavior, datatype, feature, function, interaction, connector, predicate, namespace, type definitions and usages
- New behavioral keywords: after, event, message, parallel, terminate, until, when
- New modifier keywords: composite, conjugate, const, disjoint, portion, var
- New relationship keywords: by, conjugation, crosses, differences, disjoining, featuring, intersects, inverting, member, multiplicity, of, redefinition, specializes, subclassifier, subsets, subtype, typed, unions
- Test infrastructure: test-helper.el, test-lang.el, test-navigation.el
- CI with GitHub Actions (Emacs 29.4 + 30.1)
- Eclipse SysON LSP server support
- Makefile with test, compile, clean, lint targets

### Changed
- Corrected BNF keyword forms: `enum def` (was `enumeration def`), `flow def` (was `flow connection def`), `analysis def` (was `analysis case def`), `verification def` (was `verification case def`)
- Default LSP server changed from syside to pilot (syside archived Oct 2025)
- Strengthened font-lock and indentation tests

### Fixed
- Import statement parsing in tree-sitter grammar (wildcard suffix conflict)
- Multi-word keyword font-lock priority
- Byte-compilation warnings in sysml2-diagram.el and sysml2-evil.el
