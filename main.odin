#+feature using-stmt
package main

main :: proc() {
    // src, err := os.read_entire_file_from_path("./tests/main.mylang", context.allocator)
    // assert(err == nil)
    // src_string := string(src)
    // fmt.println(src_string)
    //
    // scanner := Scanner {input = src_string}
    // for {
    //     tok := get_next_token(&scanner)
    //     if tok.value == "" do fmt.printfln("Token{{kind = \"%v\"}", tok.kind)
    //     else do fmt.println(tok)
    //
    //     if tok.kind == .EOF do break
    // }

    scanner := Scanner {input = "1 + 2"}
    parser := Parser {scanner = scanner}
    token := get_next_token(&parser.scanner)
    parser.last_token = token
    node := make_tree(&parser)
    lhs := node.(Binary).lhs_number
    rhs := node.(Binary).lhs_number
    fmt.println(lhs.(string))
}

print_tree :: proc(node: Node) {
    switch v in node {
    case string: fmt.print(v)
    case Unary: 
        op := v.op
        fmt.print("(")
        print_tree(v.number^)
        fmt.print(")")
    case Binary:
        fmt.print("(")
        print_tree(v.lhs_number^)
        // fmt.print("+")
        // print_tree(v.rhs_number^)
        // fmt.print(")")
    case EOF:
    }
}

Operation :: enum {
    PLUS, MINUS, MULTIPLY, DIVIDE
}

Unary :: struct {
    op: Operation,
    number: ^Node,
}

Binary :: struct {
    lhs_number: ^Node,
    op: Operation,
    rhs_number: ^Node,
}

Node :: union {
    string,
    Unary,
    Binary,
    EOF,
}

EOF :: struct {}

Parser :: struct {
    scanner: Scanner,
    last_token: Token,
}

peek_token :: proc(using parser: ^Parser) -> Token {
    assert(last_token != Token{})
    return last_token
}

consume_token :: proc(using parser: ^Parser) -> Token {
    token_to_return := last_token
    last_token = get_next_token(&scanner)
    #partial switch token_to_return.kind {
    case .PLUS, .MINUS, .MULTIPLY, .DIVIDE, .NUMERIC:
    case:
        fmt.printfln("Operation %s is not supported.", last_token.kind)
        panic("");
    }
    return token_to_return
}

infix_binding_power :: proc(op: Lexem_Kind) -> (l_bp: i8, r_bp: i8) {
    #partial switch op {
        case .PLUS, .MINUS: return 1, 2
        case .MULTIPLY, .DIVIDE: return 3, 4
        case: panicf("Unexpexted op %v\n", op)
    }
}

panicf :: proc(format: string, args: ..any, allocator := context.allocator, newline := false) -> ! {
    panic(fmt.aprintf(format, args, allocator, newline))
}

lexem_to_op :: proc(lexem: Lexem_Kind) -> Operation {
    #partial switch lexem {
    case .PLUS: return .PLUS
    case .MINUS: return .MINUS
    case .MULTIPLY: return .MULTIPLY
    case .DIVIDE: return .DIVIDE
    case: panicf("Unsupported")
    }
}

// Pratt parsing. https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
make_tree :: proc(using parser: ^Parser, min_bp : i8 = 0) -> ^Node {
    token := consume_token(parser)
    assert(token.kind == .NUMERIC, fmt.aprintf("Expected .NUMERIC, got %v\n", token.kind))
    lhs := new(Node)
    lhs^ = token.value
    for {
        op := peek_token(parser)
        if op.kind == .EOF {
            break
        }
        #partial switch op.kind {
        case .PLUS, .MINUS, .MULTIPLY, .DIVIDE:
        case:
            panicf("Got %v", last_token.kind)
        }

        l_bp, r_bp := infix_binding_power(op.kind)
        if l_bp < min_bp {
            break
        }
        consume_token(parser)
        rhs := make_tree(parser, r_bp)
        lhs^ = Binary {
            lhs_number = lhs,
            op = lexem_to_op(op.kind),
            rhs_number = rhs
        }
    }
    return lhs
}

// -1 + 2 * 3 + 4 -> (((-1) + (2 * 3)) + 4)
//         +
//        / \
//       +   4
//      / \
//     *   -
//    / \   \
//   2   3   1

import "core:fmt"
import "core:os"
