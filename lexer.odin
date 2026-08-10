#+feature using-stmt
package main

import "core:unicode"
import "core:fmt"
import "core:strings"

Lexem_Kind :: enum {
    NONE, ERROR, EOF,
    IF, NIL, ELSE, FOR, STRUCT, ENUM, UNION, IDENT, RETURN,
    NUMERIC,
    LPAREN, RPAREN,
    LBRACE, RBRACE,
    LBRACKET, RBRACKET,
    ASSIGNMENT, PLUS, MINUS, MULTIPLY, DIVIDE, MODULO, PLUS_EQUAL, MINUS_EQUAL, MULTIPLY_EQUAL, DIVIDE_EQUAL,
    LOGICAL_NEGATION, LOGICAL_EQUAL, LOGICAL_NOT_EQUAL, LOGICAL_AND, LOGICAL_OR, LESS, LESS_EQUAL, GREATER, GREATER_EQUAL,
    AMPERSAND, BIT_OR, BIT_XOR, BIT_NOT, LEFT_SHIFT, RIGHT_SHIFT, BIT_AND_EQUAL, BIT_OR_EQUAL, BIT_XOR_EQUAL, LEFT_SHIFT_EQUAL, RIGHT_SHIFT_EQUAL,
    DOT,
    RANGE,
    COLON,
    COMMA,
    STRING_LIT,
    CHAR_LIT,
    SEMICOLON,
}

keyword_lexem :: #force_inline proc(s: string) -> Lexem_Kind {
    switch s {
    case "if":     return .IF
    case "nil":    return .NIL
    case "else":   return .ELSE
    case "for":    return .FOR
    case "enum":   return .ENUM
    case "union":  return .UNION
    case "struct": return .STRUCT
    case "return": return .RETURN
    case: return .IDENT
    }
}

op_lexem :: #force_inline proc(s: string) -> Lexem_Kind {
    switch s {
    case "=": return .ASSIGNMENT
    case "+": return .PLUS
    case "-": return .MINUS
    case "*": return .MULTIPLY
    case "/": return .DIVIDE
    case "%": return .MODULO
    case "+=": return .PLUS_EQUAL
    case "-=": return .MINUS_EQUAL
    case "*=": return .MULTIPLY_EQUAL
    case "/=": return .DIVIDE_EQUAL

    case "!": return .LOGICAL_NEGATION
    case "==": return .LOGICAL_EQUAL
    case "!=": return .LOGICAL_NOT_EQUAL
    case "&&": return .LOGICAL_AND
    case "||": return .LOGICAL_OR
    case "<": return .LESS
    case "<=": return .LESS_EQUAL
    case ">": return .GREATER
    case ">=": return .GREATER_EQUAL

    case "&": return .AMPERSAND
    case "|": return .BIT_OR
    case "^": return .BIT_XOR
    case "~": return .BIT_NOT
    case "<<": return .LEFT_SHIFT
    case ">>": return .RIGHT_SHIFT
    case "|=": return .BIT_OR_EQUAL
    case "&=": return .BIT_AND_EQUAL
    case "^=": return .BIT_XOR_EQUAL
    case "<<=": return .LEFT_SHIFT_EQUAL
    case ">>=": return .RIGHT_SHIFT_EQUAL

    case ".": return .DOT
    case "..": return .RANGE
    case ":": return .COLON
    case "(": return .LPAREN
    case ")": return .RPAREN
    case "[": return .LBRACKET
    case "]": return .RBRACKET
    case "{": return .LBRACE
    case "}": return .RBRACE
    case ",": return .COMMA
    case ";": return .SEMICOLON
    case: return .ERROR
    }
}
Token :: struct {
    kind: Lexem_Kind,
    value: string,
}

Scanner :: struct {
    input: string,
    pos: int,
}

is_whitespace :: proc(c: u8) -> bool {
    switch c {
    case '\t', '\n', '\v', '\f', '\r', ' ':
        return true
    }
    return false
}

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

is_number :: proc(c: u8) -> bool {
    return c >= '0' && c <= '9'
}

// Could be refactored. For now it's ok.
get_next_token :: proc(using scanner: ^Scanner) -> Token {
    len := len(input)

    for {
        // res := strings.index_any(input[pos:], "\t\n\v\f\r")
        for pos < len && is_whitespace(input[pos]) {
            pos += 1
        }
        if pos >= len do return Token {kind = .EOF}

        if strings.has_prefix(input[pos:], "//") {
            idx := strings.index_any(input[pos:], "\n\r")
            if idx < 0 do return Token {kind = .EOF}
            pos += idx
            continue
        }

        if strings.has_prefix(input[pos:], "/*") {
            pos += 2
            idx := strings.index(input[pos:], "*/")
            if idx < 0 do panic("Unterminated block comment.")
            pos += idx + 2
            continue
        }
        break
    }

    if is_ident_start(input[pos]) {
        start := pos
        for pos < len && is_ident_char(input[pos]) {
            pos += 1
        }
        value := input[start:pos]

        if lexem := keyword_lexem(value); lexem == .IDENT {
            return Token {kind = .IDENT, value = value}
        } else {
            return Token {kind = lexem}
        }
    }

    if is_number(input[pos]) {
        start := pos
        for pos < len && is_number(input[pos]) do pos += 1
        return Token {kind = .NUMERIC, value = input[start:pos]}
    }

    if input[pos] == '"' {
        pos += 1
        start := pos
        for pos < len && input[pos] != '"' {
            pos += 1
        }
        if pos >= len do panic("Unterminated string literal.")
        pos += 1
        return Token {kind = .STRING_LIT, value = input[start:pos - 1]}
    }
    
    #unroll for offset in 0..<3 {
        size := 3 - offset
        if pos + size <= len {
            value := input[pos:pos+size]
            if kind := op_lexem(value); kind != .ERROR {
                pos += size
                return Token {kind = kind}
            }
        }
    }

    start := pos
    pos += 1
    for pos < len {
        c := input[pos]
        if is_whitespace(c) || is_ident_start(c) || is_number(c) || c == '"' {
            break
        }
        if op_lexem(input[pos:pos+1]) != .ERROR {
            break
        }
        pos += 1
    }
    return Token { kind = .ERROR, value = input[start:pos] }
}
