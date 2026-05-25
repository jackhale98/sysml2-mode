# Tree-sitter SysML v2 Queries

Canonical tree-sitter query files for the SysML v2 / KerML grammar.

These files are designed to be consumed by any editor with tree-sitter
support — Helix, Neovim (`nvim-treesitter`), Zed, and as a reference
mirror for sysml2-mode (Emacs).

The grammar itself lives in a separate repository:
<https://github.com/jackhale98/tree-sitter-sysml>

| File             | Purpose                                              |
| ---------------- | ---------------------------------------------------- |
| `highlights.scm` | Syntax highlighting captures                         |
| `indents.scm`    | Indentation hints (which nodes open/close contexts)  |
| `folds.scm`      | Foldable region markers                              |
| `locals.scm`     | Lexical scope and definition/reference resolution    |
| `tags.scm`       | ctags-style symbol declarations for outline indexes  |

## Capture conventions

Captures follow the de-facto tree-sitter conventions documented at
<https://tree-sitter.github.io/tree-sitter/syntax-highlighting>.
Editors map captures to highlight groups (`@comment.line` →
`comment.line`, etc.).

## Versioning

These queries target grammar revision **0.5.x** (matches the parser
embedded in [`sysml-cli`](https://github.com/jackhale98/sysml-cli) and
the grammar source in the linked grammar repo).

When the grammar adds or renames a node, update the relevant `.scm`
file here AND the corresponding inline rule in
`../../sysml2-ts.el` (Emacs).

## Editor installation

### Helix

Drop these files into `~/.config/helix/runtime/queries/sysml/`.

### Neovim (`nvim-treesitter`)

Drop into `~/.config/nvim/queries/sysml/`. Override the bundled
defaults by setting `vim.g.skip_ts_default_groups` if needed.

### Zed

Include `queries/` in your extension manifest.

### Emacs (sysml2-mode)

The Emacs major mode embeds equivalent rules inline via
`treesit-font-lock-rules`. These `.scm` files serve as the canonical
reference and the source of truth when porting to other editors.
