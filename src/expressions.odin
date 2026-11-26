#+feature using-stmt
package main

import "base:runtime"
import "core:strings"
import "core:fmt"

Parser :: struct {
    tokenizer: ^Tokenizer,
    current_token: Token,
}

Struct_Type_Expr :: struct {
    fields: []Var_Decl_Stmt,
}

Struct_Instance_Expr :: struct {
    type_name: Maybe(string),
    init_fields: []Assign_Stmt,
}

Any_Expr :: union {
    Identifier_Expr,
    Literal_Expr, // 10
    Unary_Expr, // -a
    Binary_Expr, // a + b
    Call_Expr, // a()
    Index_Expr, // a[10]
    Array_Expr,
    Proc_Expr, // () -> type {}
    Struct_Type_Expr, // struct {a: int}
    Struct_Instance_Expr, // Struct_Example.{field = 10}
}

Proc_Expr :: struct {
    parameters: [dynamic]Var_Decl_Stmt,
    body: Block_Stmt,
    return_type: Maybe(string),
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

Array_Expr :: struct {
    element_type: Maybe(Named_Type),
    elements: []Any_Expr,
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
parse_expression :: proc(using parser: ^Parser, allocator: runtime.Allocator, min_bp : i8 = 0, loc := #caller_location) -> Any_Expr {
    token := consume_token(parser)

    lhs : Any_Expr = ---
    switch token.kind {
    case .Ident:
        if parser.current_token.kind == .Period {
            expect_token(parser, .Period)
            if parser.current_token.kind == .Open_Bracket {
                lhs = parse_array_expr(parser, allocator, Named_Type{name = token.text})
                break
            }
            expect_token(parser, .Open_Brace)
            if parser.current_token.kind == .Close_Brace {
                expect_token(parser, .Close_Brace)
                lhs = Struct_Instance_Expr {type_name = token.text}
            } else {
                init_fields := make([dynamic]Assign_Stmt, allocator)
                for {
                    ident_token := expect_token(parser, .Ident)
                    expect_token(parser, .Assign)
                    expr := parse_expression(parser, allocator, 0)
                    append(&init_fields, {name = ident_token.text, value = expr})
                    if parser.current_token.kind == .Comma {
                        expect_token(parser, .Comma)
                    } else if parser.current_token.kind == .Close_Brace {
                        expect_token(parser, .Close_Brace)
                        break
                    } else do fmt.panicf("Expected `}` or `,`. Got `%v`", parser.current_token.text)
                }
                lhs = Struct_Instance_Expr {type_name = token.text, init_fields = init_fields[:]}
            }
        } else {
            lhs = Identifier_Expr{name = token.text}
        }
    case .Integer, .String_Literal, .Char_Literal:
        lhs = Literal_Expr{kind = token.kind, text = token.text}
    case .Period:
        lhs = parse_array_expr(parser, allocator, nil)
    case .Struct:
        expect_token(parser, .Open_Brace)
        fields := make([dynamic]Var_Decl_Stmt, allocator)
        for parser.current_token.kind != .Close_Brace {
            name := expect_token(parser, .Ident).text
            append(&fields, parse_var_decl_stmt_with_name(parser, name, allocator))
        }
        expect_token(parser, .Close_Brace)
        lhs = Struct_Type_Expr {fields = fields[:]}
    case .Open_Paren:
        if parser.current_token.kind == .Ident {
            tokenizer_temp := parser.tokenizer^ // for lookahead
            if next_token(&tokenizer_temp).kind == .Colon {
                parameters := make([dynamic]Var_Decl_Stmt, allocator)

                for {
                    param_name := expect_token(parser, .Ident).text
                    expect_token(parser, .Colon)
                    type := expect_token(parser, .Ident).text
                    append(&parameters, {
                        name = param_name, 
                        type_name = type, 
                        init_expr = nil
                        })
                    if parser.current_token.kind == .Close_Paren {
                        expect_token(parser, .Close_Paren)
                        break
                    }
                    expect_token(parser, .Comma)
                }

                proc_type: Maybe(string)
                if parser.current_token.kind == .Right_Arrow {
                    expect_token(parser, .Right_Arrow)
                    proc_type = expect_token(parser, .Ident).text
                }
                proc_body := parse_block_stmt(parser, allocator)
                lhs = Proc_Expr {
                    parameters = parameters,
                    return_type = proc_type,
                    body = proc_body
                }
            } else {
                lhs = parse_expression(parser, allocator)
                expect_token(parser, .Close_Paren)
            }
        } else if parser.current_token.kind == .Close_Paren {
            expect_token(parser, .Close_Paren)
            proc_type: Maybe(string)
            if parser.current_token.kind == .Right_Arrow {
                expect_token(parser, .Right_Arrow)
                proc_type = expect_token(parser, .Ident).text
            }
            proc_body := parse_block_stmt(parser, allocator)
            lhs = Proc_Expr {
                return_type = proc_type,
                body = proc_body
            }
        } else {
            lhs = parse_expression(parser, allocator)
            expect_token(parser, .Close_Paren)
        }
    case .Plus, .Minus:
        r_bp := prefix_binding_power(token.kind)
        rhs := new_clone(parse_expression(parser, allocator, r_bp), allocator)
        lhs = Unary_Expr {expr = rhs, op = token.kind}
    case .Right_Arrow, .None, .Error, .EOF, .If, .Nil, .Else, .For, .Enum, .Union, .Return, .Close_Paren,
         .Assign, .Asterisk, .Divide, .Modulo, .Plus_Assign, .Minus_Assign, .Multiply_Assign, .Divide_Assign,
         .Logical_Not, .Equal, .Not_Equal, .Logical_And, .Logical_Or, .Less, .Less_Equal,
         .Greater, .Greater_Equal, .Ampersand, .Bit_Or, .Bit_Xor, .Bit_Not, .Left_Shift, .Right_Shift, .Bit_And_Assign,
         .Bit_Or_Assign, .Bit_Xor_Assign, .Left_Shift_Assign, .Right_Shift_Assign, .Open_Brace, .Close_Brace, .Open_Bracket, .Close_Bracket,
         .Double_Dot, .Colon, .Comma, .Semicolon,
         .Compiler_Directive: fmt.panicf("Expected expression, got %v", token, loc = loc)
    }

    for {
        op := parser.current_token
        if op.kind == .EOF {
            break
        }
        
        // foo[1+2]
        if op.kind == .Open_Bracket {
            consume_token(parser)
            index_expression := parse_expression(parser, allocator, 0)
            assert(consume_token(parser).kind == .Close_Bracket)
            lhs = Index_Expr {expr = new_clone(lhs, allocator), index = new_clone(index_expression, allocator)}
            continue
        }
        // foo(1 + 2)
        if op.kind == .Open_Paren {
            consume_token(parser)
            args: [dynamic]Any_Expr
            if parser.current_token.kind == .Close_Paren {
                expect_token(parser, .Close_Paren)
            } else {
                args = make([dynamic]Any_Expr, allocator)
                for {
                    append(&args, parse_expression(parser, allocator, 0))
                    if parser.current_token.kind == .Close_Paren {
                        expect_token(parser, .Close_Paren)
                        break
                    } else {
                        expect_token(parser, .Comma)
                    }
                }
            }
            lhs = Call_Expr {callee = new_clone(lhs, allocator), args = args}
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

parse_array_expr :: proc(p: ^Parser, allocator: runtime.Allocator, element_type: Maybe(Named_Type)) -> Array_Expr {
    expect_token(p, .Open_Bracket)
    elements := make([dynamic]Any_Expr, allocator)
    for p.current_token.kind != .Close_Bracket {
        append(&elements, parse_expression(p, allocator))
        if p.current_token.kind == .Close_Bracket do break
        expect_token(p, .Comma)
    }
    expect_token(p, .Close_Bracket)
    return Array_Expr{element_type = element_type, elements = elements[:]}
}

infix_binding_power :: proc(op: Token_Kind) -> (l_bp: i8, r_bp: i8) {
    #partial switch op {
    case .Logical_Or: return 1, 2
    case .Bit_Xor: return 3, 4
    case .Bit_And: return 5, 6
    case .Right_Shift, .Left_Shift: return 7, 8
    case .Plus, .Minus: return 9, 10
    case .Multiply, .Divide, .Modulo: return 11, 12
    case: return -1, -1
    }
}

prefix_binding_power :: proc(op: Token_Kind) -> i8 {
    #partial switch op {
    case .Plus, .Minus: return 13
    case: fmt.panicf("Awaited for `+` or `-`, got %v", op)
    }
}
