#+feature using-stmt
package main

import "core:fmt"
import r "base:runtime"

Block_Stmt :: struct {
	stmts: [dynamic]Any_Stmt,
}

Var_Decl_Stmt :: struct {
	name:      string,
	type_name: Maybe(string),
	init_expr: Maybe(Any_Expr),
}

Assign_Stmt :: struct {
	name:  string,
	value: Any_Expr,
}

Empty_Stmt :: struct {}

Any_Stmt :: union {
	Var_Decl_Stmt,
	Assign_Stmt,
	Empty_Stmt,
    Block_Stmt,
    If_Stmt,
    Return_Stmt,
}

Return_Stmt :: struct {
    expr: Maybe(Any_Expr)
}

If_Stmt :: struct {
    cond_expr: Any_Expr,
    blk_stmt: Block_Stmt,
    else_branch: Maybe(^Any_Stmt)
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
    expr := parse_expression(p, context.allocator)
    then_blk := parse_block_stmt(p, allocator)
    else_blk: ^Any_Stmt
    if p.current_token.kind == .ELSE {
        expect_token(p, .ELSE)
        if p.current_token.kind == .IF {
            else_blk = new_clone(Any_Stmt(parse_if_stmt(p, allocator)))
        } else {
            else_blk = new_clone(Any_Stmt(parse_block_stmt(p, allocator)))
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
	ident_token := expect_token(p, .IDENT)

    #partial switch p.current_token.kind {
    case .ASSIGNMENT:
        expect_token(p, .ASSIGNMENT)
        expr := parse_expression(p, allocator)
        expect_token(p, .SEMICOLON)
        return Assign_Stmt {
            name = ident_token.text,
            value = expr
        }
    case .COLON:
        expect_token(p, .COLON)
        type_name : Maybe(string)
        if p.current_token.kind ==  .IDENT {
            type_name = expect_token(p, .IDENT).text
        }
        tree: Maybe(Any_Expr)
        if p.current_token.kind == .ASSIGNMENT {
            expect_token(p, .ASSIGNMENT)
            tree = parse_expression(p, allocator)
        }
        if _, is_proc := tree.(Any_Expr).(Proc_Expr); !is_proc {
            expect_token(p, .SEMICOLON)
        }
        return Var_Decl_Stmt {
            name = ident_token.text,
            type_name = type_name,
            init_expr = tree,
        }
    case: fmt.panicf("Unexpected token `%v` while parsing statements.", p.current_token.text)
    }
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
