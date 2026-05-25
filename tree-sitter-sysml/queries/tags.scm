;; SysML v2 / KerML ctags-style tag queries for tree-sitter.
;;
;; Used by Neovim, Emacs (via treesit-tags), and other editors to
;; populate go-to-definition indexes and outline views.
;;
;; Capture conventions:
;;   @definition.X   declares a tag with kind X
;;   @reference.X    references a previously declared tag

(part_definition          name: (identifier) @name) @definition.class
(action_definition        name: (identifier) @name) @definition.method
(state_definition         name: (identifier) @name) @definition.class
(port_definition          name: (identifier) @name) @definition.interface
(connection_definition    name: (identifier) @name) @definition.interface
(flow_definition          name: (identifier) @name) @definition.interface
(item_definition          name: (identifier) @name) @definition.class
(requirement_definition   name: (identifier) @name) @definition.constant
(constraint_definition    name: (identifier) @name) @definition.constant
(use_case_definition      name: (identifier) @name) @definition.class
(verification_case_definition name: (identifier) @name) @definition.class
(analysis_case_definition name: (identifier) @name) @definition.class
(interface_definition     name: (identifier) @name) @definition.interface
(enumeration_definition   name: (identifier) @name) @definition.enum
(calc_definition          name: (identifier) @name) @definition.function
(view_definition          name: (identifier) @name) @definition.class
(viewpoint_definition     name: (identifier) @name) @definition.class
(allocation_definition    name: (identifier) @name) @definition.class
(metadata_definition      name: (identifier) @name) @definition.macro
(package_declaration      name: (identifier) @name) @definition.module

;; ── References ────────────────────────────────────────────────────
(typed_by       type:   (qualified_name) @name) @reference.type
(specialization target: (qualified_name) @name) @reference.type
