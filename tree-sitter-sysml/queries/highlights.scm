;; SysML v2 / KerML highlights for tree-sitter
;;
;; Canonical query file shared by Helix, Neovim, Zed, and as a reference
;; for sysml2-mode (Emacs). When updating, keep in sync with the
;; treesit-font-lock-rules in sysml2-ts.el.
;;
;; Capture names follow tree-sitter-standard conventions:
;; @comment, @string, @keyword, @type, @function, @variable, @number,
;; @constant, @operator, @punctuation, @attribute.

;; ── Comments ───────────────────────────────────────────────────────
(line_comment)  @comment.line
(block_comment) @comment.block
(doc_comment)   @comment.documentation

;; ── Strings & literals ─────────────────────────────────────────────
(string_literal)  @string
(number_literal)  @number
(boolean_literal) @constant.builtin.boolean
(null_literal)    @constant.builtin

;; ── Keywords ───────────────────────────────────────────────────────
[
  "package" "import" "alias" "comment" "doc" "about" "filter"
  "def"
  "part" "action" "state" "port" "connection" "attribute"
  "item" "requirement" "constraint" "view" "viewpoint"
  "rendering" "concern" "allocation" "interface"
  "occurrence" "metadata" "calc"
  "ref" "exhibit" "perform" "include"
  "enum" "enumeration" "flow"
  ;; KerML
  "assoc" "behavior" "class" "connector"
  "datatype" "feature" "function" "interaction"
  "namespace" "predicate" "struct" "type"
  "classifier" "metaclass" "expr" "step"
] @keyword

;; ── Behavioral keywords ────────────────────────────────────────────
[
  "entry" "first" "then" "accept"
  "for" "transition" "loop" "until"
  "if" "else" "while" "do" "assign" "send"
  "merge" "decide" "fork" "join"
] @keyword.control

;; ── Relationship / specialization keywords ─────────────────────────
[
  "satisfy" "require" "subject" "objective"
  "actor" "connect" "to"
  "end" "all" "default" "by"
  "use" "case" "analysis" "verification"
  "snapshot" "timeslice"
  "render" "expose" "stakeholder" "frame"
  "event" "return" "redefines" "subsets" "via"
  "conjugates" "references" "chains" "inverse"
  "library" "standard"
] @keyword.relationship

;; ── Visibility & modifiers ─────────────────────────────────────────
["public" "private" "protected"] @keyword.modifier.visibility
[
  "abstract" "variation" "variant" "individual" "readonly"
  "derived" "nonunique" "ordered" "in" "out" "inout"
  "composite" "conjugate" "const" "disjoint" "portion" "var"
] @keyword.modifier

;; ── Operators ──────────────────────────────────────────────────────
[
  "~" "::" "==" "!=" "<=" ">="
  "+" "-" "*" "/" "%" "**" "=" ":="
  "not" "or" "and" "xor" "implies"
  "hastype" "istype" "as" "@"
] @operator

;; ── Punctuation ────────────────────────────────────────────────────
[ "{" "}" ] @punctuation.bracket
[ "(" ")" ] @punctuation.bracket
[ "[" "]" ] @punctuation.bracket
[ ";" "," ":" ] @punctuation.delimiter

;; ── Definition names (the part of `part def NAME`) ─────────────────
(part_definition          name: (identifier) @type.definition)
(action_definition        name: (identifier) @type.definition)
(state_definition         name: (identifier) @type.definition)
(port_definition          name: (identifier) @type.definition)
(connection_definition    name: (identifier) @type.definition)
(flow_definition          name: (identifier) @type.definition)
(attribute_definition     name: (identifier) @type.definition)
(item_definition          name: (identifier) @type.definition)
(requirement_definition   name: (identifier) @type.definition)
(constraint_definition    name: (identifier) @type.definition)
(view_definition          name: (identifier) @type.definition)
(viewpoint_definition     name: (identifier) @type.definition)
(rendering_definition     name: (identifier) @type.definition)
(concern_definition       name: (identifier) @type.definition)
(use_case_definition      name: (identifier) @type.definition)
(analysis_case_definition name: (identifier) @type.definition)
(verification_case_definition name: (identifier) @type.definition)
(allocation_definition    name: (identifier) @type.definition)
(interface_definition     name: (identifier) @type.definition)
(enumeration_definition   name: (identifier) @type.definition)
(individual_definition    name: (identifier) @type.definition)
(occurrence_definition    name: (identifier) @type.definition)
(metadata_definition      name: (identifier) @type.definition)
(calc_definition          name: (identifier) @type.definition)
(case_definition          name: (identifier) @type.definition)
(class_definition         name: (identifier) @type.definition)
(struct_definition        name: (identifier) @type.definition)
(assoc_definition         name: (identifier) @type.definition)
(behavior_definition      name: (identifier) @type.definition)
(datatype_definition      name: (identifier) @type.definition)
(feature_definition       name: (identifier) @type.definition)
(function_definition      name: (identifier) @type.definition)
(predicate_definition     name: (identifier) @type.definition)
(connector_definition     name: (identifier) @type.definition)
(interaction_definition   name: (identifier) @type.definition)
(type_definition          name: (identifier) @type.definition)
(namespace_definition     name: (identifier) @type.definition)
(classifier_definition    name: (identifier) @type.definition)
(metaclass_definition     name: (identifier) @type.definition)
(expr_definition          name: (identifier) @type.definition)
(step_definition          name: (identifier) @type.definition)
(package_declaration      name: (identifier) @namespace)

;; ── Usage names (the part of `part NAME : Type`) ───────────────────
(part_usage          name: (identifier) @variable.member)
(attribute_usage     name: (identifier) @variable.member)
(port_usage          name: (identifier) @variable.member)
(action_usage        name: (identifier) @variable.member)
(state_usage         name: (identifier) @variable.member)
(item_usage          name: (identifier) @variable.member)
(connection_usage    name: (identifier) @variable.member)
(constraint_usage    name: (identifier) @variable.member)
(requirement_usage   name: (identifier) @variable.member)
(snapshot_usage      name: (identifier) @variable.member)
(timeslice_usage     name: (identifier) @variable.member)
(calc_usage          name: (identifier) @variable.member)
(view_usage          name: (identifier) @variable.member)
(viewpoint_usage     name: (identifier) @variable.member)
(rendering_usage     name: (identifier) @variable.member)
(concern_usage       name: (identifier) @variable.member)
(use_case_usage      name: (identifier) @variable.member)
(analysis_usage      name: (identifier) @variable.member)
(verification_usage  name: (identifier) @variable.member)
(metadata_usage      name: (identifier) @variable.member)
(classifier_usage    name: (identifier) @variable.member)
(metaclass_usage     name: (identifier) @variable.member)
(expr_usage          name: (identifier) @variable.member)
(step_usage          name: (identifier) @variable.member)

;; ── Type references (after `:`, `:>`, `defined by`) ────────────────
(typed_by         type:   (qualified_name) @type)
(specialization   target: (qualified_name) @type.parameter)

;; ── Metadata annotations (#Name) ───────────────────────────────────
(metadata_annotation_list) @attribute
