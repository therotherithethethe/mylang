#+feature using-stmt
package main

import "core:fmt"
import "core:os"

Lexem_Kind :: enum {
    NONE, // 0
    IDENT,
    COLON,
    LPAREN,
    RPAREN,
    LBRACE,
    RBRACE,
    STRING_LIT,
    SEMICOLON,
    ERROR,
    EOF,
}

Token :: struct {
    kind: Lexem_Kind,
    value: string,
}

Scanner :: struct {
    input: string,
    pos: int,
}

get_next_token :: proc(using scanner: ^Scanner) -> Token {
    len := len(input)

    if pos >= len do return Token {kind = .EOF}
    for pos < len && (input[pos] == ' ' || input[pos] == '\n') {
        pos += 1
    }

    if pos >= len do return Token {kind = .EOF}

    ch := input[pos]

    // Strings:
    if ch == '"' {
        pos += 1
        start := pos
        for pos < len && input[pos] != '"' {
            pos += 1
        }
        if pos >= len do panic("Error in string literal.")
        pos += 1
        return Token {kind = .STRING_LIT, value = input[start:pos - 1]}
    }
    // ------------------------ 

    // One symbol lexems:

    // All .NONE (zero) except those listed.
    single_char_kinds := [256]Lexem_Kind {
        ':' = .COLON,
        '(' = .LPAREN,
        ')' = .RPAREN,
        '{' = .LBRACE,
        '}' = .RBRACE,
        ';' = .SEMICOLON,
    }
    //                                          0
    //                                          v
    if kind := single_char_kinds[ch]; kind != .NONE {
        pos += 1
        return Token {kind = kind}
    }
    // ------------------------ 

    // Identifiers:
    start := pos
    if !is_ident_start(ch) {
        pos += 1
        return Token {kind = .ERROR, value = input[start:pos]}
    }
    for is_ident_char(input[pos]) {
        pos += 1
    }
    return Token {kind = .IDENT, value = input[start:pos]}
    // ------------------------ 

    is_ident_start :: proc(c: u8) -> bool {
        switch c {
        case 'a'..='z', 'A'..='Z', '_':
            return true
        case:
            return false
        }
    }

    is_ident_char :: proc(c: u8) -> bool {
        switch c {
        case 'a'..='z', 'A'..='Z', '0'..='9', '_':
            return true
        case:
            return false
        }
    }
}

main :: proc() {
    src, err := os.read_entire_file_from_path("./tests/main.mylang", context.allocator)
    assert(err == nil)

    src_string := string(src)
    fmt.println(src_string)

    scanner := Scanner {input = src_string}
    for {
        tok := get_next_token(&scanner)
        if tok.kind == .ERROR do fmt.printf("Unknown symbol `%v`\n", tok.value)
        else do fmt.println(tok)

        if tok.kind == .EOF do break
    }
}
