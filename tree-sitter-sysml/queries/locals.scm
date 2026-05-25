;; SysML v2 / KerML local scope queries for tree-sitter.
;;
;; @local.scope     introduces a new lexical scope
;; @local.definition.X  binds an identifier in the enclosing scope
;; @local.reference     references an identifier resolved by scope rules

;; ── Scopes ─────────────────────────────────────────────────────────
(package_declaration)         @local.scope
(package_body)                @local.scope
(definition_body)             @local.scope
(state_body)                  @local.scope
(requirement_body)            @local.scope
(constraint_body)             @local.scope
(enumeration_body)            @local.scope

;; ── Definitions bind a type-level symbol ───────────────────────────
(part_definition       name: (identifier) @local.definition.type)
(action_definition     name: (identifier) @local.definition.type)
(state_definition      name: (identifier) @local.definition.type)
(port_definition       name: (identifier) @local.definition.type)
(connection_definition name: (identifier) @local.definition.type)
(item_definition       name: (identifier) @local.definition.type)
(requirement_definition name: (identifier) @local.definition.type)
(constraint_definition name: (identifier) @local.definition.type)
(use_case_definition   name: (identifier) @local.definition.type)
(verification_case_definition name: (identifier) @local.definition.type)
(analysis_case_definition name: (identifier) @local.definition.type)
(interface_definition  name: (identifier) @local.definition.type)
(enumeration_definition name: (identifier) @local.definition.type)
(calc_definition       name: (identifier) @local.definition.type)
(view_definition       name: (identifier) @local.definition.type)
(viewpoint_definition  name: (identifier) @local.definition.type)
(allocation_definition name: (identifier) @local.definition.type)

;; ── Usages bind a value-level symbol ──────────────────────────────
(part_usage          name: (identifier) @local.definition.var)
(attribute_usage     name: (identifier) @local.definition.var)
(port_usage          name: (identifier) @local.definition.var)
(action_usage        name: (identifier) @local.definition.var)
(state_usage         name: (identifier) @local.definition.var)
(item_usage          name: (identifier) @local.definition.var)
(connection_usage    name: (identifier) @local.definition.var)
(requirement_usage   name: (identifier) @local.definition.var)
(constraint_usage    name: (identifier) @local.definition.var)
(calc_usage          name: (identifier) @local.definition.var)

;; ── References ────────────────────────────────────────────────────
(qualified_name) @local.reference
