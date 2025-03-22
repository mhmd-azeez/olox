package olox

Scanner :: struct {
	source:  string,
	start:   int,
	current: int,
	line:    int,
}

scanner_init :: proc(source: string) -> Scanner {
	return Scanner{source = source, start = 0, current = 0, line = 1}
}

scanner_scan_token :: proc(scanner: ^Scanner) -> Token {
	scanner_skip_whitespace(scanner)
	scanner.start = scanner.current

	if scanner_is_at_end(scanner) {
		return scanner_make_token(scanner, TokenType.EOF)
	}

	c := scanner_advance(scanner)

	if is_digit(c) {
		return scanner_number(scanner)
	} else if is_alpha(c) {
		return scanner_identifier(scanner)
	}

	switch c {
	// Single character tokens
	case '(':
		return scanner_make_token(scanner, TokenType.LEFT_PAREN)
	case ')':
		return scanner_make_token(scanner, TokenType.RIGHT_PAREN)
	case '{':
		return scanner_make_token(scanner, TokenType.LEFT_BRACE)
	case '}':
		return scanner_make_token(scanner, TokenType.RIGHT_BRACE)
	case ';':
		return scanner_make_token(scanner, TokenType.SEMICOLON)
	case ',':
		return scanner_make_token(scanner, TokenType.COMMA)
	case '.':
		return scanner_make_token(scanner, TokenType.DOT)
	case '-':
		return scanner_make_token(scanner, TokenType.MINUS)
	case '+':
		return scanner_make_token(scanner, TokenType.PLUS)
	case '/':
		return scanner_make_token(scanner, TokenType.SLASH)
	case '*':
		return scanner_make_token(scanner, TokenType.STAR)

	// Two character tokens

	case '!':
		{
			if scanner_match(scanner, '=') {
				return scanner_make_token(scanner, TokenType.BANG_EQUAL)
			} else {
				return scanner_make_token(scanner, TokenType.BANG)
			}
		}

	case '=':
		{
			if scanner_match(scanner, '=') {
				return scanner_make_token(scanner, TokenType.EQUAL_EQUAL)
			} else {
				return scanner_make_token(scanner, TokenType.EQUAL)
			}
		}

	case '<':
		{
			if scanner_match(scanner, '=') {
				return scanner_make_token(scanner, TokenType.LESS_EQUAL)
			} else {
				return scanner_make_token(scanner, TokenType.LESS)
			}
		}

	case '>':
		{
			if scanner_match(scanner, '=') {
				return scanner_make_token(scanner, TokenType.GREATER_EQUAL)
			} else {
				return scanner_make_token(scanner, TokenType.GREATER)
			}
		}

	// Literals
	case '"':
		return scanner_string(scanner)

	case '\n':
		{
			scanner.line += 1
			scanner_advance(scanner)
		}
	}

	return scanner_error_token(scanner, "Unexpected character")
}

scanner_string :: proc(scanner: ^Scanner) -> Token {
	for scanner_peek(scanner) != '"' && !scanner_is_at_end(scanner) {
		if scanner_peek(scanner) == '\n' {
			scanner.line += 1
		}
		scanner_advance(scanner)
	}

	if scanner_is_at_end(scanner) {
		return scanner_error_token(scanner, "Unterminated string.")
	}

	// The closing ".
	scanner_advance(scanner)
	return scanner_make_token(scanner, TokenType.STRING)
}

scanner_skip_whitespace :: proc(scanner: ^Scanner) {
	for {
		c := scanner_peek(scanner)
		switch c {
		case ' ', '\r', '\t':
			scanner_advance(scanner)
		case '\n':
			scanner.line += 1
			scanner_advance(scanner)
		case '/':
			if scanner_peek_next(scanner) == '/' {
				// A comment goes until the end of the line.
				for scanner_peek(scanner) != '\n' && !scanner_is_at_end(scanner) {
					scanner_advance(scanner)
				}
			} else {
				return
			}
		case:
			return
		}
	}
}

scanner_peek_next :: proc(scanner: ^Scanner) -> byte {
	if scanner.current + 1 >= len(scanner.source) {
		return 0
	}
	return scanner.source[scanner.current + 1]
}

scanner_peek :: proc(scanner: ^Scanner) -> byte {
	if scanner_is_at_end(scanner) {
		return 0 // Null byte
	}
	return scanner.source[scanner.current]
}

scanner_match :: proc(scanner: ^Scanner, expected: byte) -> bool {
	if scanner_is_at_end(scanner) {
		return false
	}
	if scanner.source[scanner.current] != expected {
		return false
	}

	scanner.current += 1
	return true
}

scanner_advance :: proc(scanner: ^Scanner) -> byte {
	scanner.current += 1
	return scanner.source[scanner.current - 1]
}

scanner_is_at_end :: proc(scanner: ^Scanner) -> bool {
	return scanner.current >= len(scanner.source)
}

scanner_make_token :: proc(scanner: ^Scanner, token_type: TokenType) -> Token {
	return Token {
		type = token_type,
		lexeme = scanner.source[scanner.start:scanner.current],
		literal = "",
		line = scanner.line,
	}
}

scanner_error_token :: proc(scanner: ^Scanner, message: string) -> Token {
	return Token{type = TokenType.Error, lexeme = message, literal = "", line = scanner.line}
}

is_digit :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

is_alpha :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

scanner_number :: proc(scanner: ^Scanner) -> Token {
	for is_digit(scanner_peek(scanner)) {
		scanner_advance(scanner)
	}

	// Look for a fractional part.
	if scanner_peek(scanner) == '.' && is_digit(scanner_peek_next(scanner)) {
		// Consume the "."
		scanner_advance(scanner)

		for is_digit(scanner_peek(scanner)) {
			scanner_advance(scanner)
		}
	}

	return scanner_make_token(scanner, TokenType.NUMBER)
}

scanner_identifier :: proc(scanner: ^Scanner) -> Token {
	for is_alpha(scanner_peek(scanner)) || is_digit(scanner_peek(scanner)) {
		scanner_advance(scanner)
	}

	return scanner_make_token(scanner, scanner_identifier_type(scanner))
}

scanner_identifier_type :: proc(scanner: ^Scanner) -> TokenType {
	switch scanner.source[scanner.start:scanner.current] {
	case "and":
		return TokenType.AND
	case "class":
		return TokenType.CLASS
	case "else":
		return TokenType.ELSE
	case "false":
		return TokenType.FALSE
	case "for":
		return TokenType.FOR
	case "fun":
		return TokenType.FUN
	case "if":
		return TokenType.IF
	case "nil":
		return TokenType.NIL
	case "or":
		return TokenType.OR
	case "print":
		return TokenType.PRINT
	case "return":
		return TokenType.RETURN
	case "super":
		return TokenType.SUPER
	case "this":
		return TokenType.THIS
	case "true":
		return TokenType.TRUE
	case "var":
		return TokenType.VAR
	case "while":
		return TokenType.WHILE
	}

	return TokenType.IDENTIFIER
}

Token :: struct {
	type:    TokenType,
	lexeme:  string,
	literal: string,
	line:    int,
}

TokenType :: enum {
	// Single-character tokens
	LEFT_PAREN,
	RIGHT_PAREN,
	LEFT_BRACE,
	RIGHT_BRACE,
	COMMA,
	DOT,
	MINUS,
	PLUS,
	SEMICOLON,
	SLASH,
	STAR,

	// One or two character tokens
	BANG,
	BANG_EQUAL,
	EQUAL,
	EQUAL_EQUAL,
	GREATER,
	GREATER_EQUAL,
	LESS,
	LESS_EQUAL,

	// Literals
	IDENTIFIER,
	STRING,
	NUMBER,

	// Keywords
	AND,
	CLASS,
	ELSE,
	FALSE,
	FUN,
	FOR,
	IF,
	NIL,
	OR,
	PRINT,
	RETURN,
	SUPER,
	THIS,
	TRUE,
	VAR,
	WHILE,

	// Special
	Error,
	EOF,
}
