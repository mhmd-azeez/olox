package olox

import "core:fmt"
import "core:strings"


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

vm_init :: proc() -> VM {
	return VM{chunk = nil, ip = 0, stack_top = 0}
}

vm_free :: proc(vm: ^VM) {
	// Nothing to do yet

	if vm.chunk != nil {
		chunk_free(vm.chunk)
	}
}

vm_interpret :: proc(vm: ^VM, source: string) -> InterpretResult {
	chunk := compile(source, context.allocator)
	if chunk == nil {
		return InterpretResult.CompileError
	}
	defer chunk_free(chunk)

	vm.chunk = chunk
	vm.ip = 0

	return vm_run(vm)
}

vm_run :: proc(vm: ^VM) -> InterpretResult {

	when DEBUG_TRACE_EXECUTION {
		fmt.println("== running ==")
	}

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
		case OpCode.Constant:
			{
				constant := vm_read_constant(vm)
				vm_push(vm, constant)
			}
		case OpCode.Add:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a + b)
			}
		case OpCode.Subtract:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a - b)
			}
		case OpCode.Multiply:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a * b)
			}
		case OpCode.Divide:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a / b)
			}
		case OpCode.Negate:
			{
				a, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, -a)
			}
		case OpCode.Not:
			{
				value := vm_pop(vm)
				vm_push(vm, is_falsy(value))
			}
		case OpCode.True:
			{
				vm_push(vm, true)
			}
		case OpCode.False:
			{
				vm_push(vm, false)
			}
		case OpCode.Nil:
			{
				vm_push(vm, Nil{})
			}
		case OpCode.Equal:
			{
				b := vm_pop(vm)
				a := vm_pop(vm)
				vm_push(vm, a == b)
			}
		case OpCode.Greater:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a > b)
			}
		case OpCode.Less:
			{
				b, ok := vm_pop(vm).(f64)
				if !ok {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				a, okk := vm_pop(vm).(f64)
				if !okk {
					return vm_runtime_error(vm, RuntimeError.OperandMustBeANumber)
				}

				vm_push(vm, a < b)
			}
		case OpCode.Return:
			{
				v := vm_pop(vm)
				print_value(v)
				fmt.println()
				return InterpretResult.Ok
			}
		}
	}
}

vm_runtime_error :: proc(vm: ^VM, err: RuntimeError) -> InterpretResult {
	instruction := vm.ip - 1
	line := vm.chunk.lines[instruction]

	builder := strings.builder_make()

	msg, _ := fmt.enum_value_to_string(err)

	fmt.sbprintfln(&builder, "Runtime error: %s. [line %d in script]", msg, line)

	return InterpretResult.RuntimeError
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

is_falsy :: proc(value: Value) -> bool {
	switch value {
	case Nil{}:
		return true
	case false:
		return true
	case:
		return false
	}
}