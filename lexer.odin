#+feature using-stmt
package main

import "core:unicode"
import "core:fmt"
import "core:strings"

Token_Kind :: enum {
    // Utility.
    NONE, ERROR, EOF,
    // Keywords.
    IF, NIL, ELSE, FOR, STRUCT, ENUM, UNION, IDENT, RETURN,
    // Operators.
    LPAREN, RPAREN,
    ASSIGNMENT, PLUS, MINUS, MULTIPLY, DIVIDE, MODULO, PLUS_EQUAL, MINUS_EQUAL, MULTIPLY_EQUAL, DIVIDE_EQUAL,
    LOGICAL_NEGATION, LOGICAL_EQUAL, LOGICAL_NOT_EQUAL, LOGICAL_AND, LOGICAL_OR, LESS, LESS_EQUAL, GREATER, GREATER_EQUAL,
    AMPERSAND, BIT_OR, BIT_XOR, BIT_NOT, LEFT_SHIFT, RIGHT_SHIFT, BIT_AND_EQUAL, BIT_OR_EQUAL, BIT_XOR_EQUAL, LEFT_SHIFT_EQUAL, RIGHT_SHIFT_EQUAL,

    LBRACE, RBRACE,
    LBRACKET, RBRACKET,
    DOT,
    RANGE,
    COLON,
    COMMA,
    SEMICOLON,

    NUMERIC,
    STRING_LIT,
    CHAR_LIT,
    COMPILER_DIRECTIVE
}

op_to_str :: #force_inline proc(kind: Token_Kind) -> string {
    switch kind {
    case .ASSIGNMENT:        return "="
    case .PLUS:              return "+"
    case .MINUS:             return "-"
    case .MULTIPLY:          return "*"
    case .DIVIDE:            return "/"
    case .MODULO:            return "%"
    case .PLUS_EQUAL:        return "+="
    case .MINUS_EQUAL:       return "-="
    case .MULTIPLY_EQUAL:    return "*="
    case .DIVIDE_EQUAL:      return "/="
    case .LOGICAL_NEGATION:  return "!"
    case .LOGICAL_EQUAL:     return "=="
    case .LOGICAL_NOT_EQUAL: return "!="
    case .LOGICAL_AND:       return "&&"
    case .LOGICAL_OR:        return "||"
    case .LESS:              return "<"
    case .LESS_EQUAL:        return "<="
    case .GREATER:           return ">"
    case .GREATER_EQUAL:     return ">="
    case .AMPERSAND:         return "&"
    case .BIT_OR:            return "|"
    case .BIT_XOR:           return "^"
    case .BIT_NOT:           return "~"
    case .LEFT_SHIFT:        return "<<"
    case .RIGHT_SHIFT:       return ">>"
    case .BIT_AND_EQUAL:     return "&="
    case .BIT_OR_EQUAL:      return "|="
    case .BIT_XOR_EQUAL:     return "^="
    case .LEFT_SHIFT_EQUAL:  return "<<="
    case .RIGHT_SHIFT_EQUAL: return ">>="
    case .LPAREN:   return "("
    case .RPAREN:   return ")"
    case .LBRACE:   return "{"
    case .RBRACE:   return "}"
    case .LBRACKET: return "["
    case .RBRACKET: return "]"
    case .DOT:      return "."
    case .RANGE:    return ".."
    case .COLON:    return ":"
    case .COMMA:    return ","
    case .SEMICOLON: return ";"
    case .IF:       return "if"
    case .NIL:      return "nil"
    case .ELSE:     return "else"
    case .FOR:      return "for"
    case .STRUCT:   return "struct"
    case .ENUM:     return "enum"
    case .UNION:    return "union"
    case .RETURN:   return "return"
    case .EOF:      return "EOF"
    case .NONE, .ERROR, .IDENT, .NUMERIC, .STRING_LIT, .CHAR_LIT, .COMPILER_DIRECTIVE:
        fmt.panicf("op_to_str: no string spelling for %v", kind)
    }
    unreachable()
}

Token :: struct {
    kind: Token_Kind,
    text: string,
    line, col: int
}

keyword_to_lexem :: #force_inline proc(s: string) -> Token_Kind {
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

op_to_lexem :: #force_inline proc(s: string) -> Token_Kind {
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

// file:line:col: error|warning: msg

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

is_digit :: proc(c: u8) -> bool {
    return c >= '0' && c <= '9'
}

Tokenizer :: struct {
    file_name: string,
    line: int,
    col: int,
    input: string,
    offset: int,
}

advance :: proc(using tokenizer: ^Tokenizer, amount := 1) {
    for _ in 0..<amount {
        if input[offset] == '\n' {
            col = 1
            line += 1
        }
        else {
            col += 1
        }
        offset += 1
    }
}

current_char :: proc(using tokenizer: ^Tokenizer) -> u8 {
    return input[offset]
}

next_token :: proc(using tokenizer: ^Tokenizer) -> Token {
    input_len := len(input)

    // Skippable stream
    for {
        line, col := line, col
        for offset < input_len && is_whitespace(current_char(tokenizer)) {
            advance(tokenizer)
        }
        if offset >= input_len do return Token {kind = .EOF, line = line, col = col}

        if strings.has_prefix(input[offset:], "//") {
            idx := strings.index_any(input[offset:], "\n\r")
            if idx < 0 do return Token {kind = .EOF}
            advance(tokenizer, idx)
            continue
        }

        if strings.has_prefix(input[offset:], "/*") {
            advance(tokenizer, 2)
            idx := strings.index(input[offset:], "*/")
            if idx < 0 do panic("Unterminated block comment.")
            advance(tokenizer, idx + 2)
            continue
        }
        break
    }

    if is_ident_start(current_char(tokenizer)) {
        start := offset
        line, col := line, col
        for offset < input_len && is_ident_char(current_char(tokenizer)) {
            advance(tokenizer)
        }
        value := input[start:offset]

        if lexem := keyword_to_lexem(value); lexem == .IDENT {
            return Token {kind = .IDENT, text = value, line = line, col = col}
        } else {
            return Token {kind = lexem, line = line, col = col}
        }
    }

    if is_digit(current_char(tokenizer)) {
        start := offset
        line, col := line, col
        for offset < input_len && is_digit(current_char(tokenizer)) {
            advance(tokenizer)
        }
        return Token {kind = .NUMERIC, text = input[start:offset], line = line, col = col}
    }

    if input[offset] == '"' {
        advance(tokenizer)
        start := offset
        line, col := line, col
        for offset < input_len && input[offset] != '"' {
            advance(tokenizer)
        }

        if offset >= input_len do panic("Unterminated string literal.")
        advance(tokenizer)
        return Token {kind = .STRING_LIT, text = input[start:offset - 1], line = line, col = col}
    }

    if input[offset] == '\'' {
        advance(tokenizer, 2)
        line, col := line, col
        if offset >= input_len || input[offset] != '\'' do fmt.panicf("Char character must end with \'\n", input[offset])
        value := input[offset-1:offset]
        advance(tokenizer)
        return Token {kind = .CHAR_LIT, text = input[offset-2:offset-1], line = line, col = col}
    }

    if input[offset] == '#' {
        advance(tokenizer)
        start := offset
        line, col := line, col
        for offset < input_len && is_ident_char(current_char(tokenizer)) {
            advance(tokenizer)
        }
        return Token {kind = .COMPILER_DIRECTIVE, text = input[start:offset], line = line, col = col}
    }
    
    for op_size in 0..<3 {
        size := 3 - op_size
        line, col := line, col
        if offset + size <= input_len {
            value := input[offset:offset+size]
            if kind := op_to_lexem(value); kind != .ERROR {
                advance(tokenizer, size)
                return Token {kind = kind, line = line, col = col}
            }
        }
    }

    start := offset
    err_line, err_col := line, col
    offset += 1
    for offset < input_len {
        c := current_char(tokenizer)
        if is_whitespace(c) || is_ident_start(c) || is_digit(c) || c == '"' || c == '\'' {
            break
        }
        if op_to_lexem(input[offset:offset+1]) != .ERROR {
            break
        }
        advance(tokenizer)
    }
    return Token { kind = .ERROR, text = input[start:offset], line = err_line, col = err_col}
}
