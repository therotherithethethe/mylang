package main

import "base:runtime"
import "core:fmt"

Any_Type :: union {
    Named_Type,
    // Integer_Type,
    // Bool_Type,
    // String_Type,
    Pointer_Type,
    Array_Type,
    // Slice_Type,
    // Dynamic_Array_Type,
    Proc_Type,
}

Named_Type :: struct {
    name: string,
}

Integer_Type :: struct {
    bits: u8,
    is_signed: bool,
}

Bool_Type :: struct {}

String_Type :: struct {}

Pointer_Type :: struct {
    pointee: ^Any_Type,
}

Array_Type :: struct {
    length: int,
    element_type: ^Any_Type,
}

Slice_Type :: struct {
    element_type: ^Any_Type,
}

Dynamic_Array_Type :: struct {
    element_type: ^Any_Type,
}

Proc_Type :: struct {
    parameter_types: []Any_Type,
    return_type: ^Any_Type,
}

token_kind_to_type :: proc(kind: Token_Kind) -> Named_Type {
    #partial switch kind {
    case .Integer:    return {name = "int"}
    case .String_Literal: return {name = "string"}
    case .Char_Literal:   return {name = "char"}
    case: fmt.panicf("No standart type that corrensponds to kind `%v`", kind)
    }
} 

parse_type :: proc(p: ^Parser, allocator: runtime.Allocator) -> Any_Type {
    token := p.current_token
    #partial switch token.kind {
    case .Ident:
        consume_token(p)
        return Named_Type{name = token.text}
    case .Asterisk:
        consume_token(p)
        pointee := new_clone(parse_type(p, allocator), allocator)
        return Pointer_Type{pointee = pointee}
    case .Open_Bracket:
        consume_token(p)
        #partial switch p.current_token.kind {
        // case .Close_Bracket:
        //     consume_token(p)
        //     element_type := new_clone(parse_type(p, allocator), allocator)
        //     return Slice_Type{element_type = element_type}
        // // case .Double_Dot:
        //     consume_token(p)
        //     expect_token(p, .Close_Bracket)
        //     element_type := new_clone(parse_type(p, allocator), allocator)
        //     return Dynamic_Array_Type{element_type = element_type}
        case:
            length_token := expect_token(p, .Integer)
            length := 0
            for c in length_token.text {
                digit := int(c - '0')
                if length > (max(int) - digit) / 10 {
                    fmt.panicf("%s:%d:%d: array length is too large", p.tokenizer.file_name, length_token.line, length_token.col)
                }
                length = length * 10 + digit
            }
            expect_token(p, .Close_Bracket)
            element_type := new_clone(parse_type(p, allocator), allocator)
            return Array_Type{length = length, element_type = element_type}
        }
    case .Open_Paren:
        consume_token(p)
        parameter_types: [dynamic]Any_Type
        if p.current_token.kind != .Close_Paren {
            parameter_types = make([dynamic]Any_Type, allocator)
            for {
                append(&parameter_types, parse_type(p, allocator))
                if p.current_token.kind == .Close_Paren do break
                expect_token(p, .Comma)
            }
        }
        expect_token(p, .Close_Paren)

        return_type: ^Any_Type
        if p.current_token.kind == .Right_Arrow {
            consume_token(p)
            return_type = new_clone(parse_type(p, allocator), allocator)
        }
        return Proc_Type{parameter_types = parameter_types[:], return_type = return_type}
    case:
        fmt.panicf("%s:%d:%d: expected a type, got %v", p.tokenizer.file_name, token.line, token.col, token.kind)
    }
}

