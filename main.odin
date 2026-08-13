#+feature using-stmt
package main

main :: proc() {
    src, err := os.read_entire_file_from_path("./tests/main.mylang", context.allocator)
    assert(err == nil)
    src_string := string(src)
    fmt.println(src_string)

    scanner := Scanner {input = src_string}
    for {
        tok := next_token(&scanner)
        if tok.value == "" do fmt.printfln("Token{{kind = \"%v\"}", tok.kind)
        else do fmt.println(tok)

        if tok.kind == .EOF do break
    }

    // scanner := Scanner {input = "-1 + 2 * 3 + 4"}
    // parser := init_parser(scanner)
    // node := tree_from_expr(&parser, context.allocator)
    // // fmt.println(node.(Binary))
    // str := tree_to_string(node)
    // fmt.println(str)
}

init_parser :: proc(scanner: Scanner) -> Parser {
    parser := Parser {scanner = scanner}
    token := next_token(&parser.scanner)
    parser.last_token = token
    return parser
}

tree_to_string :: proc(node: Node) -> string {
    using strings, fmt
    builder := builder_make()
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
}

Parser :: struct {
    scanner: Scanner,
    last_token: Token,
}

consume_token :: proc(using parser: ^Parser) -> Token {
    token_to_return := last_token
    last_token = next_token(&scanner)
    #partial switch token_to_return.kind {
    case .LPAREN..=.RIGHT_SHIFT_EQUAL, .NUMERIC:
    case:
        fmt.panicf("Expected operator or .NUMERIC, got %v\n", token_to_return.kind)
    }
    return token_to_return
}

infix_binding_power :: proc(op: Lexem_Kind) -> (l_bp: i8, r_bp: i8) {
    #partial switch op {
        case .PLUS, .MINUS: return 1, 2
        case .MULTIPLY, .DIVIDE: return 3, 4
        case: unreachable()
    }
}

prefix_binding_power :: proc(op: Lexem_Kind) -> i8 {
    #partial switch op {
    case .PLUS, .MINUS: return 5
    case: unreachable()
    }
}

// Pratt parsing. https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
tree_from_expr :: proc(using parser: ^Parser, allocator: runtime.Allocator, min_bp : i8 = 0) -> Node {
    token := consume_token(parser)

    lhs : Node = ---
    #partial switch token.kind {
    case .NUMERIC:
        lhs = token.value
    case .LPAREN:
        new_lhs := tree_from_expr(parser, allocator)
        assert(consume_token(parser).kind == .RPAREN)
        lhs = new_lhs
    case .PLUS, .MINUS:
        r_bp := prefix_binding_power(token.kind)
        rhs := new_clone(tree_from_expr(parser, allocator, r_bp))
        lhs = Unary {child = rhs, op = token.kind}
    case: fmt.panicf("Unexpected token\n")
    }

    for {
        op := parser.last_token
        if op.kind == .EOF {
            break
        }

        l_bp, r_bp := infix_binding_power(op.kind)
        if l_bp < min_bp {
            break
        }

        consume_token(parser)

        rhs := new_clone(tree_from_expr(parser, allocator, r_bp), allocator)
        new_lhs := new_clone(lhs, allocator)
        lhs = Binary {
            left_child = new_lhs,
            op = op.kind,
            right_child = rhs
        }
    }
    return lhs
}

import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
