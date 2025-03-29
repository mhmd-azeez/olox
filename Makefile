# Make 'run' the default (first) command
.DEFAULT_GOAL := run

# Common flags for all commands
COMMON_FLAGS := -debug -vet -strict-style -out:bin/olox.exe
DEBUG_FLAGS := -define:DEBUG_TRACE_EXECUTION=true -define:DEBUG_PRINT_CODE=true -define:DEBUG_VERBOSE=true

# Ensure bin directory exists
.PHONY: bin
bin:
	mkdir -p bin

# Run with normal debug output
.PHONY: run
run: bin
	odin run . $(COMMON_FLAGS) $(DEBUG_FLAGS) -- $(ARGS)

# Build only
.PHONY: build
build: bin
	odin build . $(COMMON_FLAGS) $(DEBUG_FLAGS)

.PHONY: test
test: build
	@echo "Running tests..."
	@bin/olox.exe tests/string.lox
	@echo "All tests completed."