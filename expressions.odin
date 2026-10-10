#+feature using-stmt
package main

import "base:runtime"
import "core:strings"
import "core:fmt"

Parser :: struct {
    tokenizer: ^Tokenizer,
    current_token: Token,
}

Any_Expr :: union {
    Identifier_Expr,
    Literal_Expr,
    Unary_Expr,
    Binary_Expr,
    Call_Expr,
    Index_Expr,
}

Identifier_Expr :: struct {
    name: string,
}

Literal_Expr :: struct {
    kind: Token_Kind,
    text: string,
}

Unary_Expr :: struct {
    op: Token_Kind,
    expr: ^Any_Expr,
}

Binary_Expr :: struct {
    left: ^Any_Expr,
    op: Token_Kind,
    right: ^Any_Expr,
}

Index_Expr :: struct {
    expr: ^Any_Expr,
    index: ^Any_Expr,
}

Call_Expr :: struct {
    callee: ^Any_Expr,
    args: [dynamic]Any_Expr,
}

make_parser :: proc(tokenizer: ^Tokenizer) -> Parser {
    parser := Parser {tokenizer = tokenizer}
    token := next_token(parser.tokenizer)
    parser.current_token = token
    return parser
}

consume_token :: proc(using parser: ^Parser) -> Token {
    token_to_return := current_token
    current_token = next_token(tokenizer)
    return token_to_return
}

// Pratt parsing. https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
parse_expression :: proc(using parser: ^Parser, allocator: runtime.Allocator, min_bp : i8 = 0) -> Any_Expr {
    token := consume_token(parser)

    lhs : Any_Expr = ---
    switch token.kind {
    case .IDENT:
        lhs = Identifier_Expr{name = token.text}
    case .NUMERIC:
        lhs = Literal_Expr{kind = token.kind, text = token.text}
    case .LPAREN:
        new_lhs := parse_expression(parser, allocator)
        assert(consume_token(parser).kind == .RPAREN)
        lhs = new_lhs
    case .PLUS, .MINUS:
        r_bp := prefix_binding_power(token.kind)
        rhs := new_clone(parse_expression(parser, allocator, r_bp))
        lhs = Unary_Expr {expr = rhs, op = token.kind}
    case .NONE, .ERROR, .EOF, .IF, .NIL, .ELSE, .FOR, .STRUCT, .ENUM, .UNION, .RETURN, .RPAREN,
         .ASSIGNMENT, .MULTIPLY, .DIVIDE, .MODULO, .PLUS_EQUAL, .MINUS_EQUAL, .MULTIPLY_EQUAL, .DIVIDE_EQUAL,
         .LOGICAL_NEGATION, .LOGICAL_EQUAL, .LOGICAL_NOT_EQUAL, .LOGICAL_AND, .LOGICAL_OR, .LESS, .LESS_EQUAL,
         .GREATER, .GREATER_EQUAL, .AMPERSAND, .BIT_OR, .BIT_XOR, .BIT_NOT, .LEFT_SHIFT, .RIGHT_SHIFT, .BIT_AND_EQUAL,
         .BIT_OR_EQUAL, .BIT_XOR_EQUAL, .LEFT_SHIFT_EQUAL, .RIGHT_SHIFT_EQUAL, .LBRACE, .RBRACE, .LBRACKET, .RBRACKET,
         .DOT, .RANGE, .COLON, .COMMA, .SEMICOLON, .STRING_LIT, .CHAR_LIT,
         .COMPILER_DIRECTIVE: fmt.panicf("Expected expression, got %v", token.text)
    }

    for {
        op := parser.current_token
        if op.kind == .EOF {
            break
        }
        
        // foo[1+2]
        if op.kind == .LBRACKET {
            consume_token(parser)
            index_expression := parse_expression(parser, allocator, 0)
            assert(consume_token(parser).kind == .RBRACKET)
            lhs = Index_Expr {expr = new_clone(lhs, allocator), index = new_clone(index_expression)}
            continue
        }
        // foo(1 + 2)
        if op.kind == .LPAREN {
            consume_token(parser)
            args := make([dynamic]Any_Expr, allocator)

            for {
                if parser.current_token.kind != .RPAREN do append(&args, parse_expression(parser, allocator, 0))
                if parser.current_token.kind == .COMMA  do consume_token(parser)
                if parser.current_token.kind == .RPAREN do break
            }
            assert(consume_token(parser).kind == .RPAREN)
            lhs = Call_Expr {callee = new_clone(lhs), args = args}
            continue
        }

        l_bp, r_bp := infix_binding_power(op.kind)
        if l_bp != -1 {
            if l_bp < min_bp do break

            consume_token(parser)

            rhs := new_clone(parse_expression(parser, allocator, r_bp), allocator)
            lhs = Binary_Expr {
                left = new_clone(lhs, allocator),
                op = op.kind,
                right = rhs,
            }
            continue
        }
        break
    }
    return lhs
}

infix_binding_power :: proc(op: Token_Kind) -> (l_bp: i8, r_bp: i8) {
    #partial switch op {
    case .LOGICAL_OR: return 1, 2
    case .BIT_XOR: return 3, 4
    case .AMPERSAND: return 5, 6
    case .RIGHT_SHIFT, .LEFT_SHIFT: return 7, 8
    case .PLUS, .MINUS: return 9, 10
    case .MULTIPLY, .DIVIDE, .MODULO: return 11, 12
    case: return -1, -1
    }
}

prefix_binding_power :: proc(op: Token_Kind) -> i8 {
    #partial switch op {
    case .PLUS, .MINUS: return 13
    case: unreachable()
    }
}
