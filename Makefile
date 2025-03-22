run:
	mkdir -p bin
	odin run . -debug -vet -strict-style -define:DEBUG_TRACE_EXECUTION=true -out:bin/olox.exe