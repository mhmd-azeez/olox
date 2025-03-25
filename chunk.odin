package olox

import "core:fmt"
import "core:mem"

OpCode :: enum {
	Constant,
	True,
	False,
	Nil,
	Add,
	Subtract,
	Multiply,
	Divide,
	Not,
	Negate,
	Greater,
	Less,
	Equal,
	Return,
}

Nil :: struct {}

Value :: union {
	f64,
	bool,
	Nil,
}

RuntimeError :: enum {
	None,
	TooManyConstants,
	OperandMustBeANumber,
}

Chunk :: struct {
	code:      [dynamic]u8,
	constants: [dynamic]Value,
	lines:     [dynamic]int,
}

chunk_init :: proc(chunk: ^Chunk, allocator: mem.Allocator = context.allocator) {
	chunk.code = make([dynamic]u8, 0, 8, allocator)
	chunk.constants = make([dynamic]Value, 0, 8, allocator)
	chunk.lines = make([dynamic]int, 0, 8, allocator)
}

chunk_free :: proc(chunk: ^Chunk) {
	delete(chunk.code)
	delete(chunk.constants)
	delete(chunk.lines)
}

chunk_write_opcode :: proc(chunk: ^Chunk, opcode: OpCode, line: int) {
	append(&chunk.code, u8(opcode))
	append(&chunk.lines, line)
}

chunk_write :: proc(chunk: ^Chunk, byte: u8, line: int) {
	append(&chunk.code, byte)
	append(&chunk.lines, line)
}

chunk_add_constant :: proc(chunk: ^Chunk, value: Value) -> (u8, RuntimeError) {
	append(&chunk.constants, value)

	if len(chunk.constants) > 256 {
		return 0, RuntimeError.TooManyConstants
	}

	return u8(len(chunk.constants) - 1), RuntimeError.None
}

print_value :: proc(value: Value) {
	fmt.printf("%v", value)
}

chunk_disassemble :: proc(chunk: ^Chunk, name: string) {
	fmt.printf("== %s ==\n", name)

	for offset := 0; offset < len(chunk.code); {
		offset = disassemble_instruction(chunk, offset)
	}
}

disassemble_instruction :: proc(chunk: ^Chunk, offset: int) -> int {
	fmt.printf("%4v ", chunk.lines[offset])

	if offset > 0 && chunk.lines[offset] == chunk.lines[offset - 1] {
		fmt.print("   | ")
	} else {
		fmt.printf("%4d ", chunk.lines[offset])
	}

	byte := chunk.code[offset]
	opcode := OpCode(byte)

	switch opcode {
	case OpCode.Constant:
		return disassemble_constant_instruction(chunk, "OP_CONSTANT", offset)
	case OpCode.Add:
		return disassemble_simple_instruction("OP_ADD", offset)
	case OpCode.Subtract:
		return disassemble_simple_instruction("OP_SUBTRACT", offset)
	case OpCode.Multiply:
		return disassemble_simple_instruction("OP_MULTIPLY", offset)
	case OpCode.Divide:
		return disassemble_simple_instruction("OP_DIVIDE", offset)
	case OpCode.Negate:
		return disassemble_simple_instruction("OP_NEGATE", offset)
	case OpCode.Return:
		return disassemble_simple_instruction("OP_RETURN", offset)
	case OpCode.True:
		return disassemble_simple_instruction("OP_TRUE", offset)
	case OpCode.False:
		return disassemble_simple_instruction("OP_FALSE", offset)
	case OpCode.Nil:
		return disassemble_simple_instruction("OP_NIL", offset)
	case OpCode.Not:
		return disassemble_simple_instruction("OP_NOT", offset)
	case OpCode.Greater:
		return disassemble_simple_instruction("OP_GREATER", offset)
	case OpCode.Less:
		return disassemble_simple_instruction("OP_LESS", offset)
	case OpCode.Equal:
		return disassemble_simple_instruction("OP_EQUAL", offset)
	case:
		fmt.printf("Unknown opcode %d\n", opcode)
		return offset + 1
	}
}

disassemble_constant_instruction :: proc(chunk: ^Chunk, name: string, offset: int) -> int {
	idx := chunk.code[offset + 1]
	constant := chunk.constants[idx]
	fmt.printf("%-16s %d '", name, idx)
	print_value(constant)
	fmt.print("'\n")
	return offset + 2
}

disassemble_simple_instruction :: proc(name: string, offset: int) -> int {
	fmt.printf("%s\n", name)
	return offset + 1
}
