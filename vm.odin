package olox

import "core:fmt"

InterpretResult :: enum {
    Ok,
    CompileError,
    RuntimeError,
}

STACK_MAX :: 256

VM :: struct {
    chunk:     ^Chunk,
    ip:        int,
    stack:     [STACK_MAX]Value,
    stack_top: int,
}

vm_init :: proc(chunk: ^Chunk) -> VM {
    return VM{chunk = chunk, ip = 0, stack_top = 0}
}

vm_free :: proc(vm: ^VM) {
    // Nothing to do yet
}

vm_interpret :: proc(vm: ^VM, chunk: ^Chunk) -> InterpretResult {
    vm.chunk = chunk
    vm.ip = 0
    return vm_run(vm)
}

vm_run :: proc(vm: ^VM) -> InterpretResult {
    for {
        instruction := OpCode(vm_read_byte(vm))

        when DEBUG_TRACE_EXECUTION {
            fmt.printf("          ")
            for i := 0; i < vm.stack_top; i += 1 {
                fmt.printf("[ ")
                print_value(vm.stack[i])
                fmt.printf(" ]")
            }
            fmt.printf("\n")
            disassemble_instruction(vm.chunk, vm.ip - 1) // -1 because we've already advanced the IP
        }
        
        switch instruction {
        case OpCode.Constant: {
            constant := vm_read_constant(vm)
            vm_push(vm, constant)
        }
        case OpCode.Add: {
            b := vm_pop(vm)
            a := vm_pop(vm)
            vm_push(vm, a + b)
        }
        case OpCode.Subtract: {
            b := vm_pop(vm)
            a := vm_pop(vm)
            vm_push(vm, a - b)
        }
        case OpCode.Multiply: {
            b := vm_pop(vm)
            a := vm_pop(vm)
            vm_push(vm, a * b)
        }
        case OpCode.Divide: {
            b := vm_pop(vm)
            a := vm_pop(vm)
            vm_push(vm, a / b)
        }
        case OpCode.Negate: {
            vm_push(vm, -vm_pop(vm))
        }
        case OpCode.Return: {
            vm_pop(vm)
            return InterpretResult.Ok
        }
        }
    }
}

vm_read_constant :: proc(vm: ^VM) -> Value {
    return vm.chunk.constants[vm_read_byte(vm)]
}

vm_read_byte :: proc(vm: ^VM) -> u8 {
    byte := vm.chunk.code[vm.ip]
    vm.ip += 1
    return byte
}

vm_push :: proc(vm: ^VM, value: Value) {
    vm.stack[vm.stack_top] = value
    vm.stack_top += 1
}

vm_pop :: proc(vm: ^VM) -> Value {
    vm.stack_top -= 1
    return vm.stack[vm.stack_top]
}