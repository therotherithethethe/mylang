#+feature using-stmt
package main

import "core:fmt"
import r "base:runtime"

Any_Stmt :: union {
    Empty_Stmt,
    Assign_Stmt,
    Var_Decl_Stmt,
    Return_Stmt,
    Block_Stmt,
    If_Stmt,
    Expr_Stmt,
}

Empty_Stmt :: struct {}

Assign_Stmt :: struct {
    name:  string,
    value: Any_Expr,
}

Var_Decl_Stmt :: struct {
	name:      string,
    is_constant: bool,
	type_name: Maybe(string),
	init_expr: Maybe(Any_Expr),
}

Return_Stmt :: struct {
    expr: Maybe(Any_Expr)
}

Block_Stmt :: struct {
    stmts: [dynamic]Any_Stmt,
}

If_Stmt :: struct {
    cond_expr: Any_Expr,
    blk_stmt: Block_Stmt,
    else_branch: Maybe(^Any_Stmt)
}

Expr_Stmt :: struct {
    expr: Any_Expr
}

parse_block_stmt :: proc(p: ^Parser, allocator: r.Allocator) -> Block_Stmt {
    expect_token(p, .LBRACE)
    if p.current_token.kind == .RBRACE { 
        expect_token(p, .RBRACE)
        return {}
    }

    stmts := make([dynamic]Any_Stmt, allocator)
    for {
        if p.current_token.kind == .EOF || p.current_token.kind == .RBRACE do break
        append(&stmts, parse_statement(p, allocator))
    }
    expect_token(p, .RBRACE)
    return {stmts}
}

parse_if_stmt :: proc(p: ^Parser, allocator: r.Allocator) -> If_Stmt {
    expect_token(p, .IF)
    expr := parse_expression(p, allocator)
    then_blk := parse_block_stmt(p, allocator)
    else_blk: ^Any_Stmt
    if p.current_token.kind == .ELSE {
        expect_token(p, .ELSE)
        if p.current_token.kind == .IF {
            else_blk = new_clone(Any_Stmt(parse_if_stmt(p, allocator)), allocator)
        } else {
            else_blk = new_clone(Any_Stmt(parse_block_stmt(p, allocator)), allocator)
        }
    }
    return If_Stmt {
        cond_expr = expr,
        blk_stmt = then_blk,
        else_branch = else_blk
    }
}

parse_statement :: proc(p: ^Parser, allocator: r.Allocator) -> Any_Stmt {
	if p.current_token.kind == .EOF do return Empty_Stmt{}

    if p.current_token.kind == .LBRACE {
        return parse_block_stmt(p, allocator)
    }
    if p.current_token.kind == .IF {
        return parse_if_stmt(p, allocator)
    }
    if p.current_token.kind == .RETURN {
        expect_token(p, .RETURN)
        return_expr: Maybe(Any_Expr)
        if p.current_token.kind != .SEMICOLON {
            return_expr = parse_expression(p, allocator)
        }
        expect_token(p, .SEMICOLON)
        return Return_Stmt {
            expr = return_expr
        }
    }
    foo := parse_expression(p, allocator)

    #partial switch p.current_token.kind {
    case .ASSIGNMENT:
        ident := foo.(Identifier_Expr) or_else fmt.panicf("Expected identifier, got %v\n", foo)
        expect_token(p, .ASSIGNMENT)
        expr := parse_expression(p, allocator)
        expect_token(p, .SEMICOLON)
        return Assign_Stmt {
            name = ident.name,
            value = expr
        }
    case .COLON:
        ident := foo.(Identifier_Expr) or_else fmt.panicf("Expected identifier, got %v\n", foo)
        return parse_var_decl_stmt_with_name(p, ident.name, allocator)
    case: 
        expect_token(p, .SEMICOLON)
        return Expr_Stmt {expr = foo}
    }
}

parse_var_decl_stmt_with_name :: proc(p: ^Parser, name: string, allocator: r.Allocator) -> Var_Decl_Stmt {
    decl := Var_Decl_Stmt {name = name}
    expect_token(p, .COLON)

    if p.current_token.kind == .IDENT {
        decl.type_name = expect_token(p, .IDENT).text
    }

    #partial switch p.current_token.kind {
    case .SEMICOLON:
        if _, has_type := decl.type_name.(string); !has_type {
            fmt.panicf("Declaration `%s` requires a type or initializer.", name)
        }
        expect_token(p, .SEMICOLON)
        return decl
    case .ASSIGNMENT, .COLON:
        decl.is_constant = consume_token(p).kind == .COLON
    case:
        fmt.panicf("Expected '=', ':' or ';' after declaration `%s`, got %v.", name, p.current_token.kind)
    }

    init_expr := parse_expression(p, allocator)
    decl.init_expr = init_expr

    #partial switch _ in init_expr {
    case Proc_Expr, Struct_Type_Expression:
    case: expect_token(p, .SEMICOLON)
    }
    return decl
}

expect_token :: proc(p: ^Parser, expected: Token_Kind, loc := #caller_location) -> Token {
    tok := p.current_token
    if tok.kind != expected {
        fmt.panicf(
            "%s:%d:%d: expected %v, got %v",
            p.tokenizer.file_name,
            tok.line,
            tok.col,
            expected,
            tok.kind,
            loc=loc
        )
    }

    return consume_token(p)
}
