#+feature using-stmt
package main

import "base:runtime"
import "core:strings"
import "core:fmt"

Var_Decl_Stmt :: struct {
    name: string,
    type_name: string,
    init_expr: Node,
}

Assign_Stmt :: struct {
    name: string,
    value: Node,
}

Empty_Stmt :: struct {}

Statement :: union {
    Var_Decl_Stmt,
    Assign_Stmt,
    Empty_Stmt,
}

parse_assign_stmt :: proc(tokenizer: ^Tokenizer, name: string) -> Assign_Stmt {
    p := make_parser(tokenizer)
    tree := parse_expression(&p, context.allocator)
    expect_token(p.current_token.kind, .SEMICOLON)
    return {name = name, value = tree}
}

parse_var_decl_stmt :: proc(tokenizer: ^Tokenizer) -> Statement {
    ident_token := next_token(tokenizer)
    if ident_token.kind == .EOF do return Empty_Stmt{}
    expect_token(ident_token.kind, .IDENT)

    if tok := next_token(tokenizer); tok.kind == .ASSIGNMENT {
        return parse_assign_stmt(tokenizer, ident_token.text)
    } else {
        expect_token(tok.kind, .COLON)
        type_name := next_token(tokenizer)
        if type_name.kind == .IDENT {
            expect_token(type_name.kind, .IDENT)
            expect_token(next_token(tokenizer).kind, .ASSIGNMENT)

            p := make_parser(tokenizer)
            tree := parse_expression(&p, context.allocator)
            expect_token(p.current_token.kind, .SEMICOLON)
            return Var_Decl_Stmt{name = ident_token.text, type_name = type_name.text, init_expr = tree}
        } else {
            expect_token(type_name.kind, .ASSIGNMENT)

            p := make_parser(tokenizer)
            tree := parse_expression(&p, context.allocator)
            expect_token(p.current_token.kind, .SEMICOLON)
            return Var_Decl_Stmt{name = ident_token.text, type_name = type_name.text, init_expr = tree}
        }
    }
}

expect_token :: proc(tok: Token_Kind, expected_token_kind: Token_Kind, expr := #caller_expression(tok), loc := #caller_location) {
	if tok != expected_token_kind {
        fmt.panicf("expected %v to be %v", tok, expected_token_kind, loc=loc)
	}
}

Parser :: struct {
    tokenizer: ^Tokenizer,
    current_token: Token,
}

make_parser :: proc(tokenizer: ^Tokenizer) -> Parser {
    parser := Parser {tokenizer = tokenizer}
    token := next_token(parser.tokenizer)
    parser.current_token = token
    return parser
}

Unary_Expr :: struct {
    op: Token_Kind,
    expr: ^Node,
}

Binary_Expr :: struct {
    left: ^Node,
    op: Token_Kind,
    right: ^Node,
}

Node :: union {
    string,
    Unary_Expr,
    Binary_Expr,
    Call_Expr,
    Index_Expr,
}

Index_Expr :: struct {
    expr: ^Node,
    index: ^Node,
}

Call_Expr :: struct {
    callee: ^Node,
    args: [dynamic]Node,
}

consume_token :: proc(using parser: ^Parser) -> Token {
    token_to_return := current_token
    current_token = next_token(tokenizer)
    #partial switch token_to_return.kind {
    case .LPAREN..=.RIGHT_SHIFT_EQUAL, .NUMERIC, .IDENT, .COMMA, .LBRACKET, .RBRACKET:
    case:
        fmt.panicf("Expected operator or .NUMERIC, got %v\n", token_to_return.kind)
    }
    return token_to_return
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

// Pratt parsing. https://matklad.github.io/2020/04/13/simple-but-powerful-pratt-parsing.html
parse_expression :: proc(using parser: ^Parser, allocator: runtime.Allocator, min_bp : i8 = 0) -> Node {
    token := consume_token(parser)

    lhs : Node = ---
    switch token.kind {
    case .NUMERIC, .IDENT:
        lhs = token.text
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
         .COMPILER_DIRECTIVE: fmt.panicf("Unexpected token\n")
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
            args := make([dynamic]Node, allocator)

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
            new_lhs := new_clone(lhs, allocator)
            lhs = Binary_Expr {
                left = new_lhs,
                op = op.kind,
                right = rhs,
            }
            continue
        }
        break
    }
    return lhs
}

format_ast_test1 :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make()
    impl :: proc(node: Node, builder: ^strings.Builder, prefix := "", allocator := context.allocator) -> string {
        next_call_prefix := aprintf("%s│   ", prefix, allocator = allocator)
        #partial switch value in node {
        case string:
            sbprintf(builder, "%s\n", value)
        case Unary_Expr:
            sbprintf(builder, "Unary(%s)\n%s└── ", token_kind_to_string(value.op), prefix)
            impl(value.expr^, builder, next_call_prefix)
        case Index_Expr:
            sbprintf(builder, "Index\n%s├── ", prefix)
            impl(value.expr^, builder, next_call_prefix)

            sbprintf(builder, "%s└── ", prefix)
            impl(value.index^, builder, prefix)
        case Binary_Expr:
            sbprintf(builder, "Binary(%s)\n%s├── ", token_kind_to_string(value.op), prefix)
            impl(value.left^, builder, next_call_prefix)

            sbprintf(builder, "%s├── ", prefix)
            impl(value.right^, builder, next_call_prefix)
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}

format_ast_test2 :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make()
    impl :: proc(node: Node, builder: ^strings.Builder, prefix := "") -> string {
        prefix := prefix
        #partial switch value in node {
        case string:
            sbprintf(builder, "%s%s\n", prefix, value)
        case Binary_Expr:
            sbprintf(builder, "%sBinary(%s)\n", prefix, token_kind_to_string(value.op))
            first_prefix := aprintf("%s│ ", prefix)
            impl(value.left^, builder, first_prefix)
            second_prefix := aprintf("%s│ ", prefix)
            impl(value.right^, builder, second_prefix)
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}

format_ast_tree :: proc(node: Node, allocator: runtime.Allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)

    indent_prefix :: proc(prefix: string, is_last: bool) -> string {
        using fmt
        if is_last {
            return aprintf("%s%s", prefix, "    ")
        } else {
            return aprintf("%s%s", prefix, "│   ")
        }
    }

    print_node :: proc(node: Node, builder: ^strings.Builder, prefix: string, is_last: bool, is_root: bool) {
        using strings, fmt
        if !is_root {
            if is_last {
                sbprintf(builder, "%s└── ", prefix)
            } else {
                sbprintf(builder, "%s├── ", prefix)
            }
        }

        child_prefix := prefix
        if !is_root {
            child_prefix = indent_prefix(prefix, is_last)
        } else {
            child_prefix = ""
        }
        switch v in node {
        case string:
            sbprintf(builder, "%s\n", v)
        case Unary_Expr:
            sbprintf(builder, "Unary_Expr(%s)\n", token_kind_to_string(v.op))
            print_node(v.expr^, builder, child_prefix, true, false)
        case Binary_Expr:
            sbprintf(builder, "Binary_Expr(%s)\n", token_kind_to_string(v.op))
            print_node(v.left^, builder, child_prefix, false, false)
            print_node(v.right^, builder, child_prefix, true, false)
        case Index_Expr:
            sbprint(builder, "Index_Expr\n")
            print_node(v.expr^, builder, child_prefix, false, false)
            print_node(v.index^, builder, child_prefix, true, false)
        case Call_Expr:
            sbprint(builder, "Call_Expr\n")
            if len(v.args) > 0 {
                print_node(v.callee^, builder, child_prefix, false, false)
                for arg, i in v.args {
                    is_last_arg := i == len(v.args)-1
                    print_node(arg, builder, child_prefix, is_last_arg, false)
                }
            } else {
                sbprintf(builder, "%s└── %s\n", child_prefix, v.callee)
            }
        }
    }
    print_node(node, &builder, "", true, true)
    return string(builder.buf[:])
}

format_ast_sexpr :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)
    impl :: proc(node: Node, builder: ^strings.Builder) -> string {
        switch v in node {
        case string:
            sbprint(builder, v)
        case Unary_Expr:
            sbprintf(builder, "(%s ", token_kind_to_string(v.op))
            impl(v.expr^, builder)
            sbprint(builder, ")")
        case Binary_Expr:
            sbprintf(builder, "(%s ", token_kind_to_string(v.op))
            impl(v.left^, builder)
            sbprintf(builder, " ")
            impl(v.right^, builder)
            sbprint(builder, ")")
        case Index_Expr:
            sbprint(builder, "([")
            impl(v.expr^, builder)
            sbprintf(builder, " ")
            impl(v.index^, builder)
            sbprint(builder, ")")
        case Call_Expr:
            sbprint(builder, "(_call ")
            impl(v.callee^, builder)
            sbprint(builder, " ")
            if len(v.args) > 0 {
                for i in 0..<len(v.args)-1 {
                    impl(v.args[i], builder)
                    sbprint(builder, ", ")
                }
                impl(v.args[len(v.args) - 1], builder)
            }
            sbprint(builder, ")")
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}
