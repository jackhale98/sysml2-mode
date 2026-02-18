/// <reference types="tree-sitter-cli/dsl" />
// grammar.js — Tree-sitter grammar for SysML v2 / KerML textual notation
//
// Reference: OMG SysML v2 specification and
// https://github.com/Systems-Modeling/SysML-v2-Pilot-Implementation/blob/master/org.omg.sysml.xtext/src/org/omg/sysml/xtext/SysML.xtext

module.exports = grammar({
  name: "sysml",

  extras: ($) => [/\s/, $.line_comment, $.block_comment],

  word: ($) => $.identifier,

  conflicts: ($) => [
    [$.qualified_name, $.identifier],
  ],

  rules: {
    source_file: ($) => repeat($._element),

    _element: ($) =>
      choice(
        $.package_declaration,
        $._definition,
        $._usage,
        $.import_statement,
        $.alias_declaration,
        $.comment_element,
        $.doc_comment,
        $.satisfy_statement,
      ),

    // --- Package ---

    package_declaration: ($) =>
      seq(
        optional($.visibility),
        "package",
        field("name", $.identifier),
        $.package_body,
      ),

    package_body: ($) => seq("{", repeat($._element), "}"),

    // --- Import ---

    import_statement: ($) =>
      seq(
        optional($.visibility),
        "import",
        optional("all"),
        $.qualified_name,
        optional(seq("::", "*")),
        ";",
      ),

    // --- Alias ---

    alias_declaration: ($) =>
      seq(
        optional($.visibility),
        "alias",
        field("name", $.identifier),
        "for",
        $.qualified_name,
        ";",
      ),

    // --- Comments ---

    comment_element: ($) =>
      seq(
        "comment",
        optional(field("name", $.identifier)),
        optional(seq("about", $.qualified_name)),
        $.comment_body,
      ),

    doc_comment: ($) =>
      seq("doc", $.comment_body),

    comment_body: ($) =>
      seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/"),

    // --- Satisfy ---

    satisfy_statement: ($) =>
      seq(
        "satisfy",
        optional("requirement"),
        $.qualified_name,
        "by",
        $.qualified_name,
        ";",
      ),

    // --- Definitions ---

    _definition: ($) =>
      choice(
        $.part_definition,
        $.action_definition,
        $.state_definition,
        $.port_definition,
        $.connection_definition,
        $.attribute_definition,
        $.item_definition,
        $.requirement_definition,
        $.constraint_definition,
        $.view_definition,
        $.viewpoint_definition,
        $.rendering_definition,
        $.concern_definition,
        $.use_case_definition,
        $.analysis_case_definition,
        $.verification_case_definition,
        $.allocation_definition,
        $.interface_definition,
        $.enumeration_definition,
        $.occurrence_definition,
        $.metadata_definition,
        $.calc_definition,
      ),

    // Each definition: optional modifiers + keyword(s) + "def" + name + optional specialization + body
    part_definition: ($) =>
      seq(
        repeat($._modifier),
        "part",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    action_definition: ($) =>
      seq(
        repeat($._modifier),
        "action",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    state_definition: ($) =>
      seq(
        repeat($._modifier),
        "state",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    port_definition: ($) =>
      seq(
        repeat($._modifier),
        "port",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    connection_definition: ($) =>
      seq(
        repeat($._modifier),
        optional("flow"),
        "connection",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    attribute_definition: ($) =>
      seq(
        repeat($._modifier),
        "attribute",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        choice($.definition_body, seq(";"))
      ),

    item_definition: ($) =>
      seq(
        repeat($._modifier),
        "item",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        choice($.definition_body, seq(";"))
      ),

    requirement_definition: ($) =>
      seq(
        repeat($._modifier),
        "requirement",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    constraint_definition: ($) =>
      seq(
        repeat($._modifier),
        "constraint",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    view_definition: ($) =>
      seq(
        repeat($._modifier),
        "view",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    viewpoint_definition: ($) =>
      seq(
        repeat($._modifier),
        "viewpoint",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    rendering_definition: ($) =>
      seq(
        repeat($._modifier),
        "rendering",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    concern_definition: ($) =>
      seq(
        repeat($._modifier),
        "concern",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    use_case_definition: ($) =>
      seq(
        repeat($._modifier),
        "use",
        "case",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    analysis_case_definition: ($) =>
      seq(
        repeat($._modifier),
        "analysis",
        "case",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    verification_case_definition: ($) =>
      seq(
        repeat($._modifier),
        "verification",
        "case",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    allocation_definition: ($) =>
      seq(
        repeat($._modifier),
        "allocation",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    interface_definition: ($) =>
      seq(
        repeat($._modifier),
        "interface",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    enumeration_definition: ($) =>
      seq(
        repeat($._modifier),
        "enumeration",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.enumeration_body,
      ),

    occurrence_definition: ($) =>
      seq(
        repeat($._modifier),
        "occurrence",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    metadata_definition: ($) =>
      seq(
        repeat($._modifier),
        "metadata",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    calc_definition: ($) =>
      seq(
        repeat($._modifier),
        "calc",
        "def",
        field("name", $.identifier),
        optional($.specialization),
        $.definition_body,
      ),

    // --- Definition body ---

    definition_body: ($) =>
      seq("{", repeat($._body_element), "}"),

    enumeration_body: ($) =>
      seq("{", repeat(choice($.enum_member, $._body_element)), "}"),

    enum_member: ($) => seq("enum", field("name", $.identifier), ";"),

    // --- Usages ---

    _usage: ($) =>
      choice(
        $.part_usage,
        $.attribute_usage,
        $.port_usage,
        $.action_usage,
        $.state_usage,
        $.item_usage,
        $.connection_usage,
        $.constraint_usage,
        $.requirement_usage,
        $.ref_usage,
        $.succession_statement,
        $.perform_statement,
        $.exhibit_statement,
        $.include_statement,
        $.transition_statement,
        $.end_feature,
      ),

    part_usage: ($) =>
      seq(
        repeat($._modifier),
        "part",
        field("name", $.identifier),
        optional($.typed_by),
        optional($.multiplicity),
        choice($.usage_body, ";"),
      ),

    attribute_usage: ($) =>
      seq(
        repeat($._modifier),
        "attribute",
        field("name", $.identifier),
        optional($.typed_by),
        optional($.value_assignment),
        choice($.usage_body, ";"),
      ),

    port_usage: ($) =>
      seq(
        repeat($._modifier),
        "port",
        field("name", $.identifier),
        optional(seq(":", optional("~"), field("type", $.qualified_name))),
        choice($.usage_body, ";"),
      ),

    action_usage: ($) =>
      seq(
        repeat($._modifier),
        "action",
        field("name", $.identifier),
        optional($.typed_by),
        choice($.action_body, ";"),
      ),

    state_usage: ($) =>
      seq(
        repeat($._modifier),
        "state",
        field("name", $.identifier),
        optional($.typed_by),
        choice($.state_body, ";"),
      ),

    item_usage: ($) =>
      seq(
        repeat($._modifier),
        "item",
        field("name", $.identifier),
        optional($.typed_by),
        choice($.usage_body, ";"),
      ),

    connection_usage: ($) =>
      seq(
        repeat($._modifier),
        optional("flow"),
        "connection",
        field("name", $.identifier),
        optional($.typed_by),
        optional($.connect_clause),
        choice($.usage_body, ";"),
      ),

    constraint_usage: ($) =>
      seq(
        repeat($._modifier),
        optional("require"),
        "constraint",
        optional(field("name", $.identifier)),
        optional($.typed_by),
        choice($.constraint_body, ";"),
      ),

    requirement_usage: ($) =>
      seq(
        repeat($._modifier),
        "requirement",
        optional(field("name", $.identifier)),
        optional($.typed_by),
        choice($.requirement_body, ";"),
      ),

    ref_usage: ($) =>
      seq(
        "ref",
        field("name", $.identifier),
        optional($.typed_by),
        ";",
      ),

    end_feature: ($) =>
      seq(
        "end",
        field("name", $.identifier),
        optional($.typed_by),
        ";",
      ),

    // --- Behavioral ---

    succession_statement: ($) =>
      seq("first", $.qualified_name, "then", $.qualified_name, ";"),

    perform_statement: ($) =>
      seq("perform", $.qualified_name, ";"),

    exhibit_statement: ($) =>
      seq("exhibit", $.qualified_name, ";"),

    include_statement: ($) =>
      seq(
        "include",
        repeat1(choice("use", "case", "action", "state")),
        field("name", $.identifier),
        optional($.typed_by),
        ";",
      ),

    transition_statement: ($) =>
      seq(
        "transition",
        optional(field("name", $.identifier)),
        optional(seq("first", $.qualified_name)),
        optional(seq("accept", $.qualified_name)),
        optional(seq("guard", $._expression)),
        optional(seq("effect", $._expression)),
        seq("then", $.qualified_name),
        ";",
      ),

    // --- Body variants ---

    usage_body: ($) =>
      seq("{", repeat($._body_element), "}"),

    action_body: ($) =>
      seq("{", repeat($._body_element), "}"),

    state_body: ($) =>
      seq(
        "{",
        optional(seq("entry", optional(choice(";", $.action_body)),
                     optional(seq("then", $.qualified_name, ";")))),
        repeat($._body_element),
        "}",
      ),

    requirement_body: ($) =>
      seq("{", repeat($._body_element), "}"),

    constraint_body: ($) =>
      seq("{", repeat(choice($._body_element, $._expression)), "}"),

    block: ($) =>
      seq("{", repeat($._body_element), "}"),

    // --- Body elements ---

    _body_element: ($) =>
      choice(
        $._definition,
        $._usage,
        $.import_statement,
        $.alias_declaration,
        $.comment_element,
        $.doc_comment,
        $.satisfy_statement,
        $.subject_declaration,
        $.actor_declaration,
        $.objective_declaration,
        $.filter_statement,
        $.metadata_annotation,
        $.expression_statement,
      ),

    subject_declaration: ($) =>
      seq("subject", field("name", $.identifier), optional($.typed_by), ";"),

    actor_declaration: ($) =>
      seq("actor", field("name", $.identifier), optional($.typed_by), ";"),

    objective_declaration: ($) =>
      seq("objective", optional(field("name", $.identifier)),
          optional($.typed_by), choice($.usage_body, ";")),

    filter_statement: ($) =>
      seq("filter", $._expression, ";"),

    metadata_annotation: ($) =>
      seq("@", $.qualified_name, optional($.usage_body), ";"),

    expression_statement: ($) =>
      seq($._expression, ";"),

    // --- Type relationships ---

    typed_by: ($) =>
      seq(":", field("type", $.qualified_name)),

    specialization: ($) =>
      seq(":>", field("target", $.qualified_name)),

    multiplicity: ($) =>
      seq("[", $._expression, optional(seq("..", $._expression)), "]"),

    value_assignment: ($) =>
      seq(choice("=", ":=", "default"), $._expression),

    connect_clause: ($) =>
      seq("connect", $.qualified_name, "to", $.qualified_name),

    // --- Visibility ---

    visibility: ($) => choice("public", "private", "protected"),

    // --- Modifiers ---

    _modifier: ($) =>
      choice(
        $.visibility,
        "abstract",
        "variation",
        "variant",
        "individual",
        "readonly",
        "derived",
        "nonunique",
        "ordered",
        "in",
        "out",
        "inout",
        "return",
      ),

    // --- Expressions ---

    _expression: ($) =>
      choice(
        $.identifier,
        $.qualified_name,
        $.number_literal,
        $.string_literal,
        $.boolean_literal,
        $.null_literal,
        $.binary_expression,
        $.unary_expression,
        $.paren_expression,
        $.bracket_expression,
      ),

    binary_expression: ($) =>
      prec.left(
        1,
        seq(
          $._expression,
          choice(
            "==", "!=", "<", ">", "<=", ">=",
            "+", "-", "*", "/", "%", "**",
            "and", "or", "xor", "implies",
            "hastype", "istype", "as",
            ".", "::",
          ),
          $._expression,
        ),
      ),

    unary_expression: ($) =>
      prec(2, seq(choice("not", "-", "~"), $._expression)),

    paren_expression: ($) => seq("(", $._expression, ")"),

    bracket_expression: ($) =>
      seq($._expression, "[", $._expression, "]"),

    // --- Names ---

    qualified_name: ($) =>
      prec.left(
        seq($.identifier, repeat1(seq("::", $.identifier))),
      ),

    identifier: ($) => /[A-Za-z_][A-Za-z0-9_]*/,

    // --- Literals ---

    number_literal: ($) =>
      token(choice(
        /[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?/,
        /0[xX][0-9a-fA-F]+/,
      )),

    string_literal: ($) =>
      token(seq('"', repeat(choice(/[^"\\]/, /\\./)), '"')),

    boolean_literal: ($) => choice("true", "false"),

    null_literal: ($) => "null",

    // --- Comments ---

    line_comment: ($) => token(seq("//", /.*/)),

    block_comment: ($) =>
      token(seq("/*", /[^*]*\*+([^/*][^*]*\*+)*/, "/")),
  },
});
