#+feature using-stmt
package main

import "core:unicode"
import "core:fmt"
import "core:strings"

Token_Kind :: enum {
    None, Error, EOF,
    If, Nil, Else, For, Struct, Enum, Union, Ident, Return,
    Open_Paren, Close_Paren,
    Assign, Plus, Minus, Asterisk, Divide, Modulo,
    Plus_Assign, Minus_Assign, Multiply_Assign, Divide_Assign,
    Logical_Not, Equal, Not_Equal, Logical_And, Logical_Or,
    Less, Less_Equal, Greater, Greater_Equal,
    Ampersand, Bit_Or, Bit_Xor, Bit_Not, Left_Shift, Right_Shift,
    Bit_And_Assign, Bit_Or_Assign, Bit_Xor_Assign, Left_Shift_Assign, Right_Shift_Assign,

    Open_Brace, Close_Brace,
    Open_Bracket, Close_Bracket,
    Period, Double_Dot, Colon, Comma, Semicolon, Right_Arrow,

    Integer, String_Literal, Char_Literal, Compiler_Directive,

    Multiply = Asterisk,
    Bit_And = Ampersand,
}

token_kind_to_string :: #force_inline proc(kind: Token_Kind) -> string {
    switch kind {
    case .Right_Arrow:          return "->"
    case .Assign:               return "="
    case .Plus:                 return "+"
    case .Minus:                return "-"
    case .Asterisk:             return "*"
    case .Divide:               return "/"
    case .Modulo:               return "%"
    case .Plus_Assign:          return "+="
    case .Minus_Assign:         return "-="
    case .Multiply_Assign:      return "*="
    case .Divide_Assign:        return "/="
    case .Logical_Not:          return "!"
    case .Equal:                return "=="
    case .Not_Equal:            return "!="
    case .Logical_And:          return "&&"
    case .Logical_Or:           return "||"
    case .Less:                 return "<"
    case .Less_Equal:           return "<="
    case .Greater:              return ">"
    case .Greater_Equal:        return ">="
    case .Ampersand:            return "&"
    case .Bit_Or:               return "|"
    case .Bit_Xor:              return "^"
    case .Bit_Not:              return "~"
    case .Left_Shift:           return "<<"
    case .Right_Shift:          return ">>"
    case .Bit_And_Assign:       return "&="
    case .Bit_Or_Assign:        return "|="
    case .Bit_Xor_Assign:       return "^="
    case .Left_Shift_Assign:    return "<<="
    case .Right_Shift_Assign:   return ">>="
    case .Open_Paren:           return "("
    case .Close_Paren:          return ")"
    case .Open_Brace:           return "{"
    case .Close_Brace:          return "}"
    case .Open_Bracket:         return "["
    case .Close_Bracket:        return "]"
    case .Period:               return "."
    case .Double_Dot:           return ".."
    case .Colon:                return ":"
    case .Comma:                return ","
    case .Semicolon:            return ";"
    case .If:                   return "if"
    case .Nil:                  return "nil"
    case .Else:                 return "else"
    case .For:                  return "for"
    case .Struct:               return "struct"
    case .Enum:                 return "enum"
    case .Union:                return "union"
    case .Return:               return "return"
    case .EOF:                  return "EOF"
    case .None, .Error, .Ident, .Integer, .String_Literal, .Char_Literal, .Compiler_Directive:
        fmt.panicf("token_kind_to_string: no string spelling for %v", kind)
    }
    unreachable()
}

Token :: struct {
    kind: Token_Kind,
    text: string,
    line, col: int
}

lookup_keyword :: #force_inline proc(s: string) -> Token_Kind {
    switch s {
    case "if":     return .If
    case "nil":    return .Nil
    case "else":   return .Else
    case "for":    return .For
    case "enum":   return .Enum
    case "union":  return .Union
    case "struct": return .Struct
    case "return": return .Return
    case: return .Ident
    }
}

lookup_symbol :: #force_inline proc(s: string) -> Token_Kind {
    switch s {
    case "=": return .Assign
    case "+": return .Plus
    case "-": return .Minus
    case "*": return .Asterisk
    case "/": return .Divide
    case "%": return .Modulo
    case "+=": return .Plus_Assign
    case "-=": return .Minus_Assign
    case "*=": return .Multiply_Assign
    case "/=": return .Divide_Assign

    case "!": return .Logical_Not
    case "==": return .Equal
    case "!=": return .Not_Equal
    case "&&": return .Logical_And
    case "||": return .Logical_Or
    case "<": return .Less
    case "<=": return .Less_Equal
    case ">": return .Greater
    case ">=": return .Greater_Equal

    case "&": return .Ampersand
    case "|": return .Bit_Or
    case "^": return .Bit_Xor
    case "~": return .Bit_Not
    case "<<": return .Left_Shift
    case ">>": return .Right_Shift
    case "|=": return .Bit_Or_Assign
    case "&=": return .Bit_And_Assign
    case "^=": return .Bit_Xor_Assign
    case "<<=": return .Left_Shift_Assign
    case ">>=": return .Right_Shift_Assign

    case ".": return .Period
    case "..": return .Double_Dot
    case ":": return .Colon
    case "(": return .Open_Paren
    case ")": return .Close_Paren
    case "[": return .Open_Bracket
    case "]": return .Close_Bracket
    case "{": return .Open_Brace
    case "}": return .Close_Brace
    case ",": return .Comma
    case ";": return .Semicolon
    case "->": return .Right_Arrow
    case: return .Error
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

// tokenizer for get_next_token procedure.
Tokenizer :: struct {
    file_name: string,
    line: int,
    col: int,
    input: string,
    offset: int,
}

advance :: proc(using tokenizer: ^Tokenizer, amount := 1, loc := #caller_location) {
    assert(amount >= 0)
    assert(amount + offset <= len(input))
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

        if kind := lookup_keyword(value); kind == .Ident {
            return Token {kind = .Ident, text = value, line = line, col = col}
        } else {
            return Token {kind = kind, line = line, col = col, text = value}
        }
    }

    if is_digit(current_char(tokenizer)) {
        start := offset
        line, col := line, col
        for offset < input_len && is_digit(current_char(tokenizer)) {
            advance(tokenizer)
        }
        return Token {kind = .Integer, text = input[start:offset], line = line, col = col}
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
        return Token {kind = .String_Literal, text = input[start:offset - 1], line = line, col = col}
    }

    if input[offset] == '\'' {
        advance(tokenizer, 2)
        line, col := line, col
        if offset >= input_len || input[offset] != '\'' do fmt.panicf("Char character must end with \'\n")
        value := input[offset-1:offset]
        advance(tokenizer)
        return Token {kind = .Char_Literal, text = input[offset-2:offset-1], line = line, col = col}
    }

    if input[offset] == '#' {
        advance(tokenizer)
        start := offset
        line, col := line, col
        for offset < input_len && is_ident_char(current_char(tokenizer)) {
            advance(tokenizer)
        }
        return Token {kind = .Compiler_Directive, text = input[start:offset], line = line, col = col}
    }
    
    for op_size in 0..<3 {
        size := 3 - op_size
        line, col := line, col
        if offset + size <= input_len {
            value := input[offset:offset+size]
            if kind := lookup_symbol(value); kind != .Error {
                advance(tokenizer, size)
                return Token {kind = kind, line = line, col = col, text = value}
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
        if lookup_symbol(input[offset:offset+1]) != .Error {
            break
        }
        advance(tokenizer)
    }
    return Token { kind = .Error, text = input[start:offset], line = err_line, col = err_col}
}
