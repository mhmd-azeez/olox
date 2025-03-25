#+feature dynamic-literals
package olox

import "core:fmt"
import "core:strconv"

CompileError :: enum {
	None,
}

Compiler :: struct {
	chunk:   ^Chunk,
	scanner: Scanner,
	parser:  Parser,
}

Parser :: struct {
	current:    Token,
	previous:   Token,
	had_error:  bool,

	// If true, we have encountered a parsing error and will not spew any more
	// errors until we have reached a synchronization point. This is to prevent
	// cascading errors. We will probably choose statemnt boundaries
	// as synchronization points.
	panic_mode: bool,
}

Precedence :: enum {
	None,
	Assignment, // =
	Or, // or
	And, // and
	Equality, // == !=
	Comparison, // < > <= >=
	Term, // + -
	Factor, // * /
	Unary, // ! -
	Call, // . ()
	Primary,
}

precendence_plus_one :: proc(p: Precedence) -> Precedence {
	return Precedence(u8(p) + 1)
}

ParseFn :: proc(compiler: ^Compiler)

ParseRule :: struct {
	prefix:     ParseFn,
	infix:      ParseFn,
	precedence: Precedence,
}

parse_rules := map[TokenType]ParseRule {
	TokenType.LEFT_PAREN    = {compiler_grouping, nil, Precedence.None},
	TokenType.RIGHT_PAREN   = {nil, nil, Precedence.None},
	TokenType.LEFT_BRACE    = {nil, nil, Precedence.None},
	TokenType.RIGHT_BRACE   = {nil, nil, Precedence.None},
	TokenType.COMMA         = {nil, nil, Precedence.None},
	TokenType.DOT           = {nil, nil, Precedence.None},
	TokenType.MINUS         = {compiler_unary, compiler_binary, Precedence.Term},
	TokenType.PLUS          = {nil, compiler_binary, Precedence.Term},
	TokenType.SEMICOLON     = {nil, nil, Precedence.None},
	TokenType.SLASH         = {nil, compiler_binary, Precedence.Factor},
	TokenType.STAR          = {nil, compiler_binary, Precedence.Factor},
	TokenType.BANG          = {compiler_unary, nil, Precedence.None},
	TokenType.BANG_EQUAL    = {nil, nil, Precedence.Equality},
	TokenType.EQUAL         = {nil, nil, Precedence.None},
	TokenType.EQUAL_EQUAL   = {nil, nil, Precedence.Equality},
	TokenType.GREATER       = {nil, nil, Precedence.Comparison},
	TokenType.GREATER_EQUAL = {nil, nil, Precedence.Comparison},
	TokenType.LESS          = {nil, nil, Precedence.Comparison},
	TokenType.LESS_EQUAL    = {nil, nil, Precedence.Comparison},
	TokenType.IDENTIFIER    = {nil, nil, Precedence.None},
	TokenType.STRING        = {nil, nil, Precedence.None},
	TokenType.NUMBER        = {compiler_number, nil, Precedence.None},
	TokenType.AND           = {nil, nil, Precedence.None},
	TokenType.CLASS         = {nil, nil, Precedence.None},
	TokenType.ELSE          = {nil, nil, Precedence.None},
	TokenType.FALSE         = {nil, nil, Precedence.None},
	TokenType.FUN           = {nil, nil, Precedence.None},
	TokenType.FOR           = {nil, nil, Precedence.None},
	TokenType.IF            = {nil, nil, Precedence.None},
	TokenType.NIL           = {nil, nil, Precedence.None},
	TokenType.OR            = {nil, nil, Precedence.None},
	TokenType.PRINT         = {nil, nil, Precedence.None},
	TokenType.RETURN        = {nil, nil, Precedence.None},
	TokenType.TRUE          = {nil, nil, Precedence.None},
	TokenType.VAR           = {nil, nil, Precedence.None},
	TokenType.WHILE         = {nil, nil, Precedence.None},
	TokenType.EOF           = {nil, nil, Precedence.None},
}

compile :: proc(source: string) -> ^Chunk {
	when DEBUG_VERBOSE {
		fmt.println("#compile starting to compile stuff")
	}

	c := chunk_init()
	compiler := Compiler {
		scanner = scanner_init(source),
		parser = Parser{had_error = false, panic_mode = false},
		chunk = &c,
	}

	compiler_advance(&compiler)
	compiler_expression(&compiler)
	compiler_consume(&compiler, TokenType.EOF, "Expect end of expression.")
	compiler_end(&compiler)

	if compiler.parser.had_error {
		return nil
	}

	when DEBUG_VERBOSE {
		fmt.println("compiler ended successfuly!")
	}
	
	return compiler.chunk
}

// When we start doing user-defined functions, current chunk will be more complicated
// To cover our asses, we will have a function to get the current chunk
compiler_get_current_chunk :: proc(compiler: ^Compiler) -> ^Chunk {
	return compiler.chunk
}

compiler_end :: proc(compiler: ^Compiler) {
	compiler_emit_return(compiler)
	when DEBUG_PRINT_CODE {
		if !compiler.parser.had_error {
			chunk_disassemble(compiler_get_current_chunk(compiler), "code")
		}
	}
}

compiler_binary :: proc(compiler: ^Compiler) {
	operatorType := compiler.parser.previous.type
	rule := parse_rules[operatorType]
	compiler_parse_precendence(compiler, precendence_plus_one(rule.precedence))

	#partial switch operatorType {
	case TokenType.PLUS:
		compiler_emit_opcode(compiler, OpCode.Add)
	case TokenType.MINUS:
		compiler_emit_opcode(compiler, OpCode.Subtract)
	case TokenType.STAR:
		compiler_emit_opcode(compiler, OpCode.Multiply)
	case TokenType.SLASH:
		compiler_emit_opcode(compiler, OpCode.Divide)
	case:
		return // Unreachable.
	}
}

compiler_expression :: proc(compiler: ^Compiler) {
	when DEBUG_VERBOSE {
		fmt.println("#expression")
	}

	compiler_parse_precendence(compiler, Precedence.Assignment)
}

compiler_grouping :: proc(compiler: ^Compiler) {
	// we assume the initial '(' has been consumed
	compiler_expression(compiler)
	compiler_consume(compiler, TokenType.RIGHT_PAREN, "Expect ')' after expression.")
}

compiler_number :: proc(compiler: ^Compiler) {
	value, ok := strconv.parse_f64(compiler.parser.previous.lexeme)
	if !ok {
		compiler_error_at_current(&compiler.parser, "Invalid number.")
	}

	compiler_emit_constant(compiler, value)
}

compiler_unary :: proc(compiler: ^Compiler) {
	operatorType := compiler.parser.previous.type

	// Compile the operand.
	compiler_parse_precendence(compiler, Precedence.Unary)

	// This is unnecessary right now, but this will make more sense
	// when we use this same function to compile the ! operator
	#partial switch operatorType {
	case TokenType.MINUS:
		compiler_emit_opcode(compiler, OpCode.Negate)
	case:
		return // Unreachable.
	}
}

compiler_parse_precendence :: proc(compiler: ^Compiler, precedence: Precedence) {
	when DEBUG_VERBOSE {
		fmt.printfln("#compiler_parse_precendence parsing precedence %v", precedence)
	}

	compiler_advance(compiler)
	prefixRule := parse_rules[compiler.parser.previous.type].prefix
	if prefixRule == nil {
		compiler_error_at_current(&compiler.parser, "Expect expression.")
		return
	}

	prefixRule(compiler)

	for precedence <= parse_rules[compiler.parser.current.type].precedence {

		when DEBUG_VERBOSE {
			lte := precedence <= parse_rules[compiler.parser.current.type].precedence
			fmt.printfln(
				"#compiler_parse_precendence precedence %v <= %v: %v",
				precedence,
				parse_rules[compiler.parser.current.type].precedence,
				lte,
			)
		}


		compiler_advance(compiler)
		infixRule := parse_rules[compiler.parser.previous.type].infix
		infixRule(compiler)
	}
}

compiler_emit_constant :: proc(compiler: ^Compiler, value: Value) {
	idx := compiler_make_constant(compiler, value)
	compiler_emit_opcode_with_operand(compiler, OpCode.Constant, idx)
}

compiler_make_constant :: proc(compiler: ^Compiler, value: Value) -> byte {
	const, err := chunk_add_constant(compiler_get_current_chunk(compiler), value)
	if err != RuntimeError.None {
		compiler_error_at_current(&compiler.parser, "Too many constants in one chunk.")
		return 0
	}

	return const
}

compiler_advance :: proc(compiler: ^Compiler) {
	when DEBUG_VERBOSE {
		fmt.println("#compiler_advance")
	}

	compiler.parser.previous = compiler.parser.current

	for {
		compiler.parser.current = scanner_scan_token(&compiler.scanner)

		when DEBUG_VERBOSE {
			fmt.printfln("#compiler_advance got token: %v", compiler.parser.current.type)
		}

		if compiler.parser.current.type != TokenType.Error {
			break
		}

		compiler_error_at_current(&compiler.parser, compiler.parser.current.lexeme)
	}
}

compiler_consume :: proc(compiler: ^Compiler, tokenType: TokenType, message: string) {
	if compiler.parser.current.type == tokenType {
		compiler_advance(compiler)
		return
	}

	// methods would be nice here
	compiler_error_at_current(&compiler.parser, message)
}

compiler_emit_opcode_with_operand :: proc(compiler: ^Compiler, opcode: OpCode, operand: byte) {
	compiler_emit_opcode(compiler, opcode)
	compiler_emit_byte(compiler, operand)
}

compiler_emit_opcode :: proc(compiler: ^Compiler, opcode: OpCode) {
	compiler_emit_byte(compiler, u8(opcode))
}

compiler_emit_return :: proc(compiler: ^Compiler) {
	compiler_emit_opcode(compiler, OpCode.Return)
}

compiler_emit_byte :: proc(compiler: ^Compiler, byte: byte) {
	chunk_write(compiler_get_current_chunk(compiler), byte, compiler.parser.previous.line)
}

compiler_error_at_current :: proc(parser: ^Parser, message: string) {
	compiler_error_at(parser, parser.current, message)
}

compiler_error :: proc(parser: ^Parser, message: string) {
	compiler_error_at(parser, parser.previous, message)
}

compiler_error_at :: proc(parser: ^Parser, token: Token, message: string) {
	if parser.panic_mode {
		return
	}

	parser.panic_mode = true

	fmt.printf("[line %d] Error", token.line)

	if token.type == TokenType.EOF {
		fmt.printf(" at end")
	} else if token.type == TokenType.Error {
		// Nothing.
	} else {
		fmt.printf(" at '%s'", token.lexeme)
	}

	fmt.printfln(": %s", message)
	parser.had_error = true
}
