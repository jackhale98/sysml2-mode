#include "tree_sitter/parser.h"

// Token types — must match externals array order in grammar.js
enum TokenType {
  COLON,             // :
  COLON_GT,          // :>
  COLON_GT_GT,       // :>>
};

void *tree_sitter_sysml_external_scanner_create() { return NULL; }
void tree_sitter_sysml_external_scanner_destroy(void *payload) {}
unsigned tree_sitter_sysml_external_scanner_serialize(void *payload, char *buffer) { return 0; }
void tree_sitter_sysml_external_scanner_deserialize(void *payload, const char *buffer, unsigned length) {}

bool tree_sitter_sysml_external_scanner_scan(
  void *payload,
  TSLexer *lexer,
  const bool *valid_symbols
) {
  // Skip whitespace
  while (lexer->lookahead == ' ' || lexer->lookahead == '\t' ||
         lexer->lookahead == '\n' || lexer->lookahead == '\r') {
    lexer->advance(lexer, true);
  }

  if (lexer->lookahead == ':') {
    lexer->advance(lexer, false);

    if (lexer->lookahead == '>') {
      lexer->advance(lexer, false);

      if (lexer->lookahead == '>' && valid_symbols[COLON_GT_GT]) {
        lexer->advance(lexer, false);
        lexer->result_symbol = COLON_GT_GT;
        return true;
      }

      if (valid_symbols[COLON_GT]) {
        lexer->result_symbol = COLON_GT;
        return true;
      }

      return false;
    }

    // ':' followed by ':' is '::' — don't match as COLON
    if (lexer->lookahead == ':') {
      return false;
    }

    // ':' followed by '=' is ':=' — don't match as COLON
    if (lexer->lookahead == '=') {
      return false;
    }

    if (valid_symbols[COLON]) {
      lexer->result_symbol = COLON;
      return true;
    }
  }

  return false;
}
