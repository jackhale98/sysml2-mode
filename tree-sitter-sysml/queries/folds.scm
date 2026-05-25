;; SysML v2 / KerML code folding for tree-sitter.
;;
;; @fold marks a node as foldable in editors that support tree-sitter
;; folding (Helix, Neovim with nvim-treesitter, Zed).

(package_body)          @fold
(definition_body)       @fold
(enumeration_body)      @fold
(state_body)            @fold
(requirement_body)      @fold
(constraint_body)       @fold

(part_definition)       @fold
(action_definition)     @fold
(state_definition)      @fold
(port_definition)       @fold
(connection_definition) @fold
(flow_definition)       @fold
(requirement_definition) @fold
(constraint_definition) @fold
(use_case_definition)   @fold
(analysis_case_definition) @fold
(verification_case_definition) @fold
(interface_definition)  @fold
(enumeration_definition) @fold
(allocation_definition) @fold
(view_definition)       @fold
(viewpoint_definition)  @fold

(block_comment) @fold
(doc_comment)   @fold
