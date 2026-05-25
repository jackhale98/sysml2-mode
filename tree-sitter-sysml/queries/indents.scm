;; SysML v2 / KerML indentation hints for tree-sitter.
;;
;; Editor convention (Helix, Neovim, Zed):
;;   @indent        node opens a new indent context for its children
;;   @indent.begin  alias for @indent
;;   @indent.end    closing token deindents (e.g. `}`)
;;   @indent.align  child aligns with parent's open delimiter
;;
;; Keep in sync with sysml2-ts--indent-rules in sysml2-ts.el.

;; ── Body blocks (braced containers) ────────────────────────────────
(package_body)      @indent
(definition_body)   @indent
(enumeration_body)  @indent
(state_body)        @indent
(requirement_body)  @indent
(constraint_body)   @indent

;; ── Multi-line statements (children continue on subsequent lines) ──
(transition_statement) @indent
(succession_statement) @indent
(then_succession)      @indent

(connection_usage)   @indent
(flow_usage)         @indent
(allocation_usage)   @indent
(interface_usage)    @indent
(binding_usage)      @indent

(satisfy_statement)  @indent
(verify_statement)   @indent
(bind_statement)     @indent
(assert_statement)   @indent

;; ── Control flow actions ───────────────────────────────────────────
(if_action)     @indent
(while_action)  @indent
(for_action)    @indent
(loop_action)   @indent
(assign_action) @indent

(fork_node)   @indent
(join_node)   @indent
(merge_node)  @indent
(decide_node) @indent

;; ── State actions ──────────────────────────────────────────────────
(entry_action) @indent
(do_action)    @indent
(exit_action)  @indent

;; ── Perform / exhibit / include ────────────────────────────────────
(perform_statement) @indent
(exhibit_statement) @indent
(include_statement) @indent

;; ── Metadata ───────────────────────────────────────────────────────
(metadata_usage)            @indent
(metadata_annotation_list)  @indent

;; ── Parenthesized expressions ──────────────────────────────────────
(paren_expression)      @indent
(invocation_expression) @indent

;; ── Closing tokens deindent ────────────────────────────────────────
"}" @indent.end
"]" @indent.end
")" @indent.end
