package olox

import "core:fmt"

DEBUG_TRACE_EXECUTION :: #config(DEBUG_TRACE_EXECUTION, false)

main :: proc() {
    chunk := chunk_init()
    defer chunk_free(&chunk)

    constant, _ := chunk_add_constant(&chunk, 1.2)
    chunk_write_opcode(&chunk, OpCode.Constant, 123)
    chunk_write(&chunk, constant, 123)

    constant2, _ := chunk_add_constant(&chunk, 3.4)
    chunk_write_opcode(&chunk, OpCode.Constant, 123)
    chunk_write(&chunk, constant2, 123)

    chunk_write_opcode(&chunk, OpCode.Add, 123)

    constant3, _ := chunk_add_constant(&chunk, 5.6)
    chunk_write_opcode(&chunk, OpCode.Constant, 123)
    chunk_write(&chunk, constant3, 123)

    chunk_write_opcode(&chunk, OpCode.Divide, 123)

    chunk_write_opcode(&chunk, OpCode.Negate, 123)

    chunk_write_opcode(&chunk, OpCode.Return, 123)

    chunk_disassemble(&chunk, "test")

    fmt.println("=== Run ===")

    vm := vm_init(&chunk)
    defer vm_free(&vm)

    result := vm_interpret(&vm, &chunk)

    fmt.println("=== Result ===")
    fmt.println(result)
}