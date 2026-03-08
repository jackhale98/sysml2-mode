# sysml2-mode TODO

## Completed

- [x] Fix flymake test infinite loop (`syntax-ppss` moves point in Emacs 30)
- [x] Outline panel tree collapsing (TAB toggle, S collapse all, E expand all)
- [x] ElDoc support (`sysml2-eldoc.el` — keyword docs + definition lookup)
- [x] Auto-indentation for all inserted code (`sysml2--indent-inserted-region`)
- [x] Full model scaffold (`sysml2-scaffold-model`)
- [x] ISQ/SI/ScalarValues reference validation in Flymake
- [x] Traceability matrix: show satisfy/verify status with qualified name normalization
- [x] State machine diagram: include `exhibit state` names in scope candidates
- [x] Verify regex: make `requirement` keyword optional for annex-A compatibility
- [x] State machine: parse `entry; then STATE;` for initial state routing
- [x] State machine: skip forward-declared state defs from scope candidates
- [x] State machine: fix `entry/do/exit` exclusion regex (only exclude `exhibit state`)
- [x] Traceability matrix: add "No satisfy" status for verified-only requirements
- [x] Calc def scaffold (`sysml2-scaffold-calc-def`, `C-c m c`)
- [x] Calc model extraction (`sysml2--model-extract-calcs`)
- [x] Calc report section in Markdown export
- [x] SysML v2 syntax quick reference in TUTORIAL.md
- [x] Update README test count (210 tests)
- [x] Update README module list (add sysml2-eldoc.el)
- [x] Update README flymake check count (7 checks)

## Remaining

- [ ] **Requirements diagram interactive display** — SVG generation works in batch
      (confirmed 4083 chars for annex-a) but may have display issues interactively
      in a GUI Emacs session (needs manual testing)
