package olox

import "core:fmt"
import "core:os"
import "core:strings"

DEBUG_TRACE_EXECUTION :: #config(DEBUG_TRACE_EXECUTION, false)
DEBUG_PRINT_CODE :: #config(DEBUG_PRINT_CODE, false)
DEBUG_VERBOSE :: #config(DEBUG_VERBOSE, false)

main :: proc() {
    if len(os.args) == 1 {
        repl()
    } else if len(os.args) == 2 {
        run_file(os.args[1])
    } else {
        fmt.printfln("Usage: olox [path]")
        os.exit(64)
    }
}

run_file :: proc(path: string) {
    source, err := os.read_entire_file_from_filename_or_err(path)
    if err != nil {
        fmt.printfln("Could not read file '%s': %v", path, err)
        os.exit(74)
    }

    vm := vm_init()
    defer vm_free(&vm)
    result := vm_interpret(&vm, string(source))

    if result == InterpretResult.CompileError {
        os.exit(65)
    }
    if result == InterpretResult.RuntimeError {
        os.exit(70)
    }
}

repl :: proc() {
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

        line, ok := strings.substring_to(string(buf[:]), n-1)
        if !ok {
            fmt.printfln("Line too long")
            os.exit(74)
        }

        result := vm_interpret(&vm, line)
        if result == InterpretResult.CompileError {
            os.exit(65)
        }
        if result == InterpretResult.RuntimeError {
            os.exit(70)
        }
    }
}