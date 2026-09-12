#+feature using-stmt
package main

import "base:runtime"
import "core:strings"
import "core:fmt"

parser_make :: proc(scanner: Scanner) -> Parser {
    parser := Parser {scanner = scanner}
    token := next_token(&parser.scanner)
    parser.last_token = token
    return parser
}

tree_to_string :: proc(node: Node, allocator: runtime.Allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)
    impl :: proc(node: Node, builder: ^strings.Builder) -> string {
        switch v in node {
        case string:
            sbprint(builder, v)
        case Unary:
            sbprintf(builder, "(%s ", op_to_str(v.op))
            impl(v.child^, builder)
            sbprint(builder, ")")
        case Binary:
            sbprintf(builder, "(%s ", op_to_str(v.op))
            impl(v.left_child^, builder)
            sbprintf(builder, " ")
            impl(v.right_child^, builder)
            sbprint(builder, ")")
        case Index:
            sbprint(builder, "([")
            impl(v.target^, builder)
            sbprintf(builder, " ")
            impl(v.inner_expression^, builder)
            sbprint(builder, ")")
        case Proc_Call:
            sbprint(builder, "(Procedure_Call ")
            impl(v.ident^, builder)
            sbprint(builder, " [")
            if len(v.args) > 0 {
                for i in 0..<len(v.args)-1 {
                    impl(v.args[i], builder)
                    sbprint(builder, ", ")
                }
                impl(v.args[len(v.args) - 1], builder)
            }
            sbprint(builder, "]))")
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}

Unary :: struct {
    op: Lexem_Kind ,
    child: ^Node,
}

Binary :: struct {
    left_child: ^Node,
    op: Lexem_Kind,
    right_child: ^Node,
}

Node :: union {
    string,
    Unary,
    Binary,
    Proc_Call,
    Index
}

Index :: struct {
    target: ^Node,
    inner_expression: ^Node,
}

Proc_Call :: struct {
    ident: ^Node,
    args: [dynamic]Node
}

Parser :: struct {
    scanner: Scanner,
    last_token: Token,
}

consume_token :: proc(using parser: ^Parser) -> Token {
    token_to_return := last_token
    last_token = next_token(&scanner)
    #partial switch token_to_return.kind {
    case .LPAREN..=.RIGHT_SHIFT_EQUAL, .NUMERIC, .IDENT, .COMMA, .LBRACKET, .RBRACKET:
    case:
        fmt.panicf("Expected operator or .NUMERIC, got %v\n", token_to_return.kind)
    }
    return token_to_return
}

infix_binding_power :: proc(op: Lexem_Kind) -> (l_bp: i8, r_bp: i8) {
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

prefix_binding_power :: proc(op: Lexem_Kind) -> i8 {
    #partial switch op {
    case .PLUS, .MINUS: return 13
    case: unreachable()
    }
}

// Pratt parsing. https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
parse_expression :: proc(using parser: ^Parser, allocator: runtime.Allocator, min_bp : i8 = 0) -> Node {
    token := consume_token(parser)

    lhs : Node = ---
    #partial switch token.kind {
    case .NUMERIC, .IDENT:
        lhs = token.value
    case .LPAREN:
        new_lhs := parse_expression(parser, allocator)
        assert(consume_token(parser).kind == .RPAREN)
        lhs = new_lhs
    case .PLUS, .MINUS:
        r_bp := prefix_binding_power(token.kind)
        rhs := new_clone(parse_expression(parser, allocator, r_bp))
        lhs = Unary {child = rhs, op = token.kind}
        case: fmt.panicf("Unexpected token\n")
    }

    for {
        op := parser.last_token
        if op.kind == .EOF {
            break
        }
        
        // foo[1+2]
        if op.kind == .LBRACKET {
            consume_token(parser)
            index_expression := parse_expression(parser, allocator, 0)
            assert(consume_token(parser).kind == .RBRACKET)
            lhs = Index { target = new_clone(lhs, allocator), inner_expression = new_clone(index_expression)}
        }
        // foo(1 + 2)
        if op.kind == .LPAREN {
            consume_token(parser)
            args := make([dynamic]Node, allocator)

            for {
                if parser.last_token.kind != .RPAREN do append(&args, parse_expression(parser, allocator, 0))
                if parser.last_token.kind == .COMMA  do consume_token(parser)
                if parser.last_token.kind == .RPAREN do break
            }
            call : Node = Proc_Call {ident = new_clone(lhs), args = args}
            lhs = call
            consume_token(parser)
            continue
        }

        l_bp, r_bp := infix_binding_power(op.kind)
        if l_bp != -1 {
            if l_bp < min_bp do break

            consume_token(parser)

            rhs := new_clone(parse_expression(parser, allocator, r_bp), allocator)
            new_lhs := new_clone(lhs, allocator)
            lhs = Binary {
                left_child = new_lhs,
                op = op.kind,
                right_child = rhs
            }
            continue
        }
        break
    }
    return lhs
}
