; highlights.scm — Tree-sitter highlight queries for SysML v2

; Comments
(line_comment) @comment
(block_comment) @comment
(doc_comment) @comment.documentation

; Strings
(string_literal) @string

; Numbers
(number_literal) @number

; Boolean and null literals
(boolean_literal) @constant.builtin
(null_literal) @constant.builtin

; Definition names
(part_definition name: (identifier) @type.definition)
(action_definition name: (identifier) @type.definition)
(state_definition name: (identifier) @type.definition)
(port_definition name: (identifier) @type.definition)
(connection_definition name: (identifier) @type.definition)
(attribute_definition name: (identifier) @type.definition)
(item_definition name: (identifier) @type.definition)
(requirement_definition name: (identifier) @type.definition)
(constraint_definition name: (identifier) @type.definition)
(view_definition name: (identifier) @type.definition)
(viewpoint_definition name: (identifier) @type.definition)
(rendering_definition name: (identifier) @type.definition)
(concern_definition name: (identifier) @type.definition)
(use_case_definition name: (identifier) @type.definition)
(analysis_case_definition name: (identifier) @type.definition)
(verification_case_definition name: (identifier) @type.definition)
(allocation_definition name: (identifier) @type.definition)
(interface_definition name: (identifier) @type.definition)
(enumeration_definition name: (identifier) @type.definition)
(occurrence_definition name: (identifier) @type.definition)
(metadata_definition name: (identifier) @type.definition)
(calc_definition name: (identifier) @type.definition)

; Package names
(package_declaration name: (identifier) @module)

; Usage names
(part_usage name: (identifier) @variable)
(attribute_usage name: (identifier) @variable)
(port_usage name: (identifier) @variable)
(action_usage name: (identifier) @variable)
(state_usage name: (identifier) @variable)
(item_usage name: (identifier) @variable)
(connection_usage name: (identifier) @variable)
(constraint_usage name: (identifier) @variable)
(requirement_usage name: (identifier) @variable)

; Type references
(typed_by type: (qualified_name) @type)
(specialization target: (qualified_name) @type)

; Operators
[":>" ":>>" "~" "::" "==" "!=" "<=" ">=" "+" "-" "*" "/" "%" "**" "=" ":="] @operator
["not" "or" "and" "xor" "implies" "hastype" "istype" "as"] @keyword.operator

; Metadata
"@" @attribute
"meta" @attribute

; Visibility
["public" "private" "protected"] @keyword.modifier

; Modifiers
["abstract" "variation" "variant" "individual" "readonly"
 "derived" "nonunique" "ordered" "in" "out" "inout" "return"] @keyword.modifier

; Structural keywords
["package" "import" "alias" "comment" "doc" "about" "rep"
 "language" "library" "filter" "standard"] @keyword

; Definition keyword
"def" @keyword

; Usage keywords
["part" "action" "state" "port" "connection" "attribute" "item"
 "requirement" "constraint" "view" "viewpoint" "rendering" "concern"
 "allocation" "interface" "enumeration" "occurrence" "metadata" "calc"
 "ref" "succession" "binding" "exhibit" "perform" "include"
 "snapshot" "timeslice" "dependency" "expose"] @keyword

; Behavioral keywords
["entry" "exit" "do" "first" "then" "accept" "send" "assign"
 "if" "else" "while" "for" "loop" "merge" "decide" "join" "fork"
 "transition" "trigger" "guard" "effect"] @keyword

; Relationship keywords
["specialization" "subset" "redefines" "references" "chains"
 "conjugates" "inverse" "featured" "typing" "satisfy"
 "assert" "assume" "require" "subject" "objective"
 "stakeholder" "actor" "bind" "connect" "to" "from"
 "end" "all" "default"
 "use" "case" "analysis" "verification" "flow"] @keyword

; Punctuation
["{" "}"] @punctuation.bracket
["(" ")"] @punctuation.bracket
["[" "]"] @punctuation.bracket
[";" "," "."] @punctuation.delimiter
