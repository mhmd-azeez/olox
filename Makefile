run:
	mkdir -p bin
	odin run . -debug -vet -strict-style -out:bin/olox.exe -define:DEBUG_TRACE_EXECUTION=true -define:DEBUG_PRINT_CODE=true

run-verbose:
	mkdir -p bin
	odin run . -debug -vet -strict-style -out:bin/olox.exe -define:DEBUG_TRACE_EXECUTION=true -define:DEBUG_PRINT_CODE=true -define:DEBUG_VERBOSE=true