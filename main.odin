package olox

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strings"

DEBUG_TRACE_EXECUTION :: #config(DEBUG_TRACE_EXECUTION, false)
DEBUG_PRINT_CODE :: #config(DEBUG_PRINT_CODE, false)
DEBUG_VERBOSE :: #config(DEBUG_VERBOSE, false)

main :: proc() {
	os.exit(run())
}

// hack(mo): we do this to make sure print_memory_issues is called even if we exit abnormally
run :: proc() -> int {
	tracking_allocator, a := wrap_into_tracking_allocator(context.allocator)
	context.allocator = a
	defer print_memory_issues(tracking_allocator)

	if len(os.args) == 1 {
		return repl()
	} else if len(os.args) == 2 {
		return run_file(os.args[1])
	} else {
		fmt.printfln("Usage: olox [path]")
		return 64
	}
}

wrap_into_tracking_allocator :: proc(
	current_allocator: mem.Allocator,
) -> (
	^mem.Tracking_Allocator,
	mem.Allocator,
) {
	tracking_allocator := new(mem.Tracking_Allocator)
	mem.tracking_allocator_init(tracking_allocator, current_allocator)

	return tracking_allocator, mem.tracking_allocator(tracking_allocator)
}

print_memory_issues :: proc(a: ^mem.Tracking_Allocator) {
	for _, value in a.allocation_map {
		fmt.printfln("%v: Leaked %v bytes", value.location, value.size)
	}

	for x in a.bad_free_array {
		fmt.printfln("Bad free at: %v", x.location)
	}
}

run_file :: proc(path: string) -> int {
	source, err := os.read_entire_file_from_filename_or_err(path)
	if err != nil {
		fmt.printfln("Could not read file '%s': %v", path, err)
		return 74
	}

	vm := vm_init()
	defer vm_free(&vm)
	result := vm_interpret(&vm, string(source))

	if result == InterpretResult.CompileError {
		return 65
	}
	if result == InterpretResult.RuntimeError {
		return 70
	}

	return 0
}

repl :: proc() -> int {
	vm := vm_init()
	defer vm_free(&vm)

	buf: [1024]u8

	for {
		fmt.print("lox> ")
		n, err := os.read(os.stdin, buf[:])
		if err != nil {
			fmt.printfln("Could not read line: %v", err)
			os.exit(74)
		}

		line, ok := strings.substring_to(string(buf[:]), n - 1)
		if !ok {
			fmt.printfln("Line too long")
			os.exit(74)
		}

		if line == "exit" {
			break
		}

		result := vm_interpret(&vm, line)
		if result == InterpretResult.CompileError {
			return 65
		}

		if result == InterpretResult.RuntimeError {
			return 70
		}

	}

	return 0
}
