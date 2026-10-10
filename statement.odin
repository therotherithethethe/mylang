#+feature using-stmt
package main

import "core:fmt"
import r "base:runtime"

Block_Stmt :: struct {
	stmts: [dynamic]Statement,
}

parse_block_stmt :: proc(p: ^Parser, allocator: r.Allocator) -> Block_Stmt {
	expect_token(p, .LBRACE)
	stmts := make([dynamic]Statement)
	for {
		stmt := parse_statement(p, allocator)
		_, ok := stmt.(Empty_Stmt)
		if ok do break

        if p.current_token.kind == .RBRACE { 
            consume_token(p)
            break
        }

        append(&stmts, stmt)
	}
	return {stmts = stmts}
}

Var_Decl_Stmt :: struct {
	name:      string,
	type_name: Maybe(string),
	init_expr: Any_Expr,
}

Assign_Stmt :: struct {
	name:  string,
	value: Any_Expr,
}

Empty_Stmt :: struct {}

Statement :: union {
	Var_Decl_Stmt,
	Assign_Stmt,
	Empty_Stmt,
    Block_Stmt
}

parse_assign_stmt :: proc(p: ^Parser, name: string, allocator: r.Allocator) -> Assign_Stmt {
	tree := parse_expression(p, allocator)
	expect_token(p, .SEMICOLON)
	consume_token(p)
	return {name = name, value = tree}
}

parse_statement :: proc(p: ^Parser, allocator: r.Allocator) -> Statement {
	if p.current_token.kind == .EOF do return Empty_Stmt{}
    if p.current_token.kind == .LBRACE { // {stmt1; stmt2;}
        return parse_block_stmt(p, allocator)
    }
	ident_token := expect_token(p, .IDENT)

    #partial switch p.current_token.kind {
    case .ASSIGNMENT:
        expect_token(p, .ASSIGNMENT)
        tree := parse_expression(p, context.allocator)
        expect_token(p, .SEMICOLON)
        consume_token(p)
        return Assign_Stmt {
            name = ident_token.text,
            value = tree
        }
    case .COLON:
        expect_token(p, .COLON)
        type_name : Maybe(string)
        if p.current_token.kind ==  .IDENT {
            type_name = expect_token(p, .IDENT).text
        }
        expect_token(p, .ASSIGNMENT)
        tree := parse_expression(p, context.allocator)
        expect_token(p, .SEMICOLON)
        consume_token(p)
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
