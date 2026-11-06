#+feature using-stmt
package main

import "core:fmt"
import "core:strings"

builder_append_block_stmt_to_c :: proc(builder: ^strings.Builder, blk_stmt: Block_Stmt, indent_level: int) {
    fmt.sbprint(builder, "{\n")
    for stmt in blk_stmt.stmts {
        builder_indent(builder, indent_level)
        builder_append_stmt_to_c(builder, stmt, indent_level)
        fmt.sbprint(builder, "\n")
    }
    builder_indent(builder, indent_level - 1)
    fmt.sbprint(builder, "} ")
}

builder_indent :: proc(builder: ^strings.Builder, indent_level: int) {
    for _ in 0..<indent_level do fmt.sbprint(builder, "    ")
}

builder_append_stmt_to_c :: proc(builder: ^strings.Builder, any_stmt: Any_Stmt, indent_level: int) {
    using fmt
    switch concrete_stmt in any_stmt {
    case Return_Stmt:
        if expr, ok := concrete_stmt.expr.(Any_Expr); ok {
            sbprint(builder, "return ")
            builder_append_expr_to_c(builder, expr)
            sbprint(builder, ";")
        } else {
            sbprint(builder, "return;")
        }
    case If_Stmt:
        sbprint(builder, "if(")
        builder_append_expr_to_c(builder, concrete_stmt.cond_expr)
        sbprint(builder, ") ")
        builder_append_block_stmt_to_c(builder, concrete_stmt.blk_stmt, indent_level + 1)

        if else_stmt, ok := concrete_stmt.else_branch.(^Any_Stmt); ok {
            sbprint(builder, "else ")
            builder_append_stmt_to_c(builder, else_stmt^, indent_level)
        }
    case Block_Stmt:
        builder_append_block_stmt_to_c(builder, concrete_stmt, indent_level)
    case Var_Decl_Stmt:
        init_expr, init_expr_is_present := concrete_stmt.init_expr.(Any_Expr)
        if init_expr_is_present {
            #partial switch concrete_expr in init_expr {
            case Proc_Expr: 
                sbprintf(
                    builder, 
                    "%s %s", 
                    concrete_expr.return_type.(string) or_else "void",
                    concrete_stmt.name)
                builder_append_proc_expr_to_c(builder, concrete_expr, indent_level + 1)
            case Struct_Type_Expression:
                fmt.sbprint(builder, "typedef struct {\n")
                for field in concrete_expr.fields {
                    if _, has_init_expr := field.init_expr.(Any_Expr); has_init_expr {
                        fmt.panicf(
                            "Default value for field `%s` is not supported yet.",
                            field.name,
                        )
                    }
                    type_name := field.type_name.(string) or_else fmt.panicf(
                            "Field `%s` requires an explicit type.",
                            field.name,
                        )
                    sbprintf(builder, "%s %s;\n", type_name, field.name)
                }
                sbprintf(builder, "} %s;", concrete_stmt.name)
            case:
                sbprintf(
                    builder, 
                    "%s %s = ",
                    concrete_stmt.type_name.(string) or_else fmt.panicf("Type inference is not supported yet."),
                    concrete_stmt.name)
                builder_append_expr_to_c(builder, init_expr)
                sbprint(builder, ";")
            }
        } else {
            fmt.sbprintf(builder, "%s %s = {{0}};", concrete_stmt.type_name.(string), concrete_stmt.name)
        }
    case Assign_Stmt:
        sbprintf(builder, "%s = ", concrete_stmt.name)
        builder_append_expr_to_c(builder, concrete_stmt.value)
        sbprint(builder, ";")
    case Expr_Stmt:
        builder_append_expr_to_c(builder, concrete_stmt.expr)
        sbprint(builder, ";")
    case Empty_Stmt:
    }
}

builder_append_proc_expr_to_c :: proc(builder: ^strings.Builder, proc_expr: Proc_Expr, indent_level: int) {
    if len(proc_expr.parameters) == 0 {
        fmt.sbprint(builder, "() ")
    } else {
        fmt.sbprint(builder, "(")
        for param in proc_expr.parameters[:len(proc_expr.parameters)-1] {
            fmt.sbprintf(builder, "%s %s, ", param.type_name.(string), param.name)
        }
        last := proc_expr.parameters[len(proc_expr.parameters)-1]
        fmt.sbprintf(builder, "%s %s) ", last.type_name.(string), last.name)
    }
    builder_append_block_stmt_to_c(builder, proc_expr.body, indent_level)
}

builder_append_expr_to_c :: proc(builder: ^strings.Builder, any_expr: Any_Expr, parent_bp: i8 = 0) {
    using fmt
    switch concrete_expr in any_expr {
    case Struct_Type_Expression:
        fmt.sbprint(builder, "struct {")
        for field in concrete_expr.fields {
            fmt.sbprintf(builder, "%s %s;\n", field.type_name.(string), field.name)
        }
        fmt.sbprint(builder, "}")
    case Identifier_Expr: 
        fmt.sbprint(builder, concrete_expr.name)
    case Literal_Expr: 
        if concrete_expr.kind == .STRING_LIT {
            fmt.sbprintf(builder, "\"%s\"", concrete_expr.text)
        } else if concrete_expr.kind == .CHAR_LIT {
            fmt.sbprintf(builder, "\'%s\'", concrete_expr.text)
        } else {
            fmt.sbprint(builder, concrete_expr.text)
        }
    case Binary_Expr:
        l_bp, r_bp := infix_binding_power(concrete_expr.op) 
        if l_bp < parent_bp {
            sbprint(builder, "(")
        }
        builder_append_expr_to_c(builder, concrete_expr.left^, l_bp)
        sbprint(builder, " ")
        sbprint(builder, token_kind_to_string(concrete_expr.op))
        sbprint(builder, " ")
        builder_append_expr_to_c(builder, concrete_expr.right^, r_bp)
        if l_bp < parent_bp {
            sbprint(builder, ")")
        }
    case Unary_Expr:
		inner_expr := concrete_expr.expr^
		    need_parens: bool = ---
		#partial switch v in inner_expr {
		         case Unary_Expr, Binary_Expr: need_parens = true
		         case: need_parens = false
		}
		sbprint(builder, token_kind_to_string(concrete_expr.op))

        if need_parens do sbprint(builder, "(")

        builder_append_expr_to_c(builder, inner_expr)

        if need_parens do sbprint(builder, ")")
    case Index_Expr:
        builder_append_expr_to_c(builder, concrete_expr.expr^)
        sbprint(builder, "[")
        builder_append_expr_to_c(builder, concrete_expr.index^)
        sbprint(builder, "]")
    case Call_Expr:
        if len(concrete_expr.args) == 0 {
            builder_append_expr_to_c(builder, concrete_expr.callee^)
            sbprint(builder, "()")
        } else {
            builder_append_expr_to_c(builder, concrete_expr.callee^)
            sbprint(builder, "(")
            for &any_expr in concrete_expr.args[:len(concrete_expr.args)-1] {
                builder_append_expr_to_c(builder, any_expr)
                sbprint(builder, ",")
            }
            builder_append_expr_to_c(builder, concrete_expr.args[len(concrete_expr.args) - 1])
            sbprint(builder, ")")
        }
    case Proc_Expr:
        panicf("Procedure expression is not supported yet.")
    }
}
