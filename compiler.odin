package olox

import "core:fmt"

compile :: proc(source: string) {
    // Create a scanner
    scanner := scanner_init(source)
    
    line := -1

    for {
        token := scanner_scan_token(&scanner)
        if line != token.line {
            fmt.printf("%.4d ", token.line)
            line = token.line
        } else {
            fmt.print("   | ")
        }

        fmt.printf("%.2d '%s'\n", token.type, token.lexeme)        

        if token.type == TokenType.EOF {
            break
        }
    }
}