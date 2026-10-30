package main

import "core:fmt"
import "core:strings"

block_stmt_to_cliteral :: proc(blk_stmt: Block_Stmt, ident_level := 0) -> string {
    builder := strings.builder_make()
    fmt.sbprint(&builder, "{\n")
    for stmt in blk_stmt.stmts {
        fmt.sbprintf(&builder, "%s\n", stmt_to_cliteral(stmt, 1))
    }
    fmt.sbprint(&builder, "}")
    return strings.to_string(builder)
}
stmt_to_cliteral :: proc(stmt: Any_Stmt, ident_level := 0) -> string {
    builder := strings.builder_make()

    for _ in 0..<ident_level {
        fmt.sbprint(&builder, "    ")
    }

    switch v in stmt {
    case Return_Stmt:
        if expr, ok := v.expr.(Any_Expr); ok {
            fmt.sbprintf(&builder, "return %s;", expr_to_cliteral(expr))
        } else {
            fmt.sbprint(&builder, "return;")
        }
    case If_Stmt:
        fmt.sbprint(&builder, "if(%s) %s", expr_to_cliteral(v.cond_expr), block_stmt_to_cliteral(v.blk_stmt))

    case Block_Stmt:
        fmt.sbprint(&builder, block_stmt_to_cliteral(v))
    case Var_Decl_Stmt:
        type_name := v.type_name.(string) or_else "void"
        if init_expr, ok := v.init_expr.(Any_Expr); ok {
            if proc_expr, is_proc_expr := init_expr.(Proc_Expr); is_proc_expr {
                fmt.sbprintf(&builder, "%s %s%s", type_name, v.name, proc_expr_to_cliteral(&proc_expr))
            } else {
                fmt.sbprintf(&builder, "%s %s %s %s;", type_name, v.name, ":" if v.is_constant else "=", expr_to_cliteral(init_expr))
            }
        } else {
            fmt.sbprintf(&builder, "%s %s = {0};", v.type_name.(string), v.name)
        }
    case Assign_Stmt:
        assign_expr := v.value
        fmt.sbprintf(&builder, "%s = %s;", v.name, expr_to_cliteral(assign_expr))
    case Expr_Stmt:
        expr := v.expr
        fmt.sbprint(&builder, expr_to_cliteral(expr))
        fmt.sbprint(&builder, ";")
    case Empty_Stmt:
    }
    return strings.to_string(builder)
}

proc_expr_to_cliteral :: proc(proc_expr: ^Proc_Expr, ident_level := 0) -> string {
    builder := strings.builder_make()
    if len(proc_expr.parameters) == 0 {
        fmt.sbprint(&builder, "()")
    } else {
        fmt.sbprint(&builder, "(")
        for param in proc_expr.parameters[:len(proc_expr.parameters)-1] {
            fmt.sbprintf(&builder, "%s %s, ", param.type_name.(string), param.name)
        }
        last := proc_expr.parameters[len(proc_expr.parameters)-1]
        fmt.sbprintf(&builder, "%s %s)", last.type_name.(string), last.name)
    }
    fmt.sbprintf(&builder, " %s", stmt_to_cliteral(Any_Stmt(proc_expr.body)))
    return strings.to_string(builder)
}

expr_to_cliteral :: proc(expr: Any_Expr) -> string {
    builder := strings.builder_make()
    switch v in expr {
    case Identifier_Expr: 
        fmt.sbprint(&builder, v.name)
    case Literal_Expr: 
        fmt.sbprint(&builder, v.text)
    case Binary_Expr:
        lhs := expr_to_cliteral(v.left^)
        rhs := expr_to_cliteral(v.right^)
        fmt.sbprintf(&builder, "(%s %s %s)", lhs, token_kind_to_string(v.op), rhs)
    case Unary_Expr:
        fmt.sbprintf(&builder, "%s %s", token_kind_to_string(v.op), expr_to_cliteral(v.expr^))
    case Index_Expr:
        fmt.sbprintf(&builder, "%s[%s]", expr_to_cliteral(v.expr^), expr_to_cliteral(v.index^))
    case Call_Expr:
        if len(v.args) == 0 {
            fmt.sbprintf(&builder, "%s()", expr_to_cliteral(v.callee^))
        } else {
            fmt.sbprintf(&builder, "%s(", expr_to_cliteral(v.callee^))
            for &expr in v.args[:len(v.args)-1] {
                fmt.sbprintf(&builder, "%s,", expr_to_cliteral(expr))
            }
            fmt.sbprintf(&builder, "%s)", expr_to_cliteral(v.args[len(v.args) - 1]))
        }
    case Proc_Expr:
        if len(v.parameters) == 0 {
            fmt.sbprint(&builder, "()")
        } else {
            fmt.sbprint(&builder, "(")
            for param in v.parameters[:len(v.parameters)-1] {
                fmt.sbprintf(&builder, "%s %s, ", param.type_name.(string), param.name)
            }
            last := v.parameters[len(v.parameters)-1]
            fmt.sbprintf(&builder, "%s %s)", last.type_name.(string), last.name)
        }
    }
    return string(builder.buf[:])
}
