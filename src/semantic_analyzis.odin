#+feature using-stmt
package main

import "core:fmt"

Scope_Context :: struct {
    global_table, current_table: map[string]Var_Decl_Stmt, // TODO
    prev: Maybe(^Scope_Context) // One has to be null so scope_get_symbol can actually do usefull work
}

scope_get_symbol :: proc(scope: Scope_Context, symbol: string) -> (symbol_declaration: Var_Decl_Stmt, exist: bool) {
    current_scope_to_check := scope
    for {
        if symbol in current_scope_to_check.current_table {
            return current_scope_to_check.current_table[symbol], true
        } else {
            if current_scope_to_check.prev == nil {
                return {}, false
            } else {
                current_scope_to_check = current_scope_to_check.prev.(^Scope_Context)^
            }
        }
    }
    assert(false, "Unreachable")
    unreachable()
}

scope_add :: proc(using scope: ^Scope_Context, var_decl: Var_Decl_Stmt) {
    if var_decl.name in current_table do fmt.panicf("Redefinition of `%v`", var_decl.name)

    current_table[var_decl.name] = var_decl
}

analyze_procedure :: proc(proc_expr: Proc_Expr, scope: Scope_Context) {
    scope := scope
    new_scope := Scope_Context {
        global_table = scope.global_table,
        current_table = make(map[string]Var_Decl_Stmt),
        prev = &scope
    }
    for param_decl in proc_expr.parameters do scope_add(&new_scope, param_decl)
    analyze_block_stmt(proc_expr.body, new_scope)
}

analyze_block_stmt :: proc(block_stmt: Block_Stmt, scope: Scope_Context) {
    scope := scope
    
    for stmt in block_stmt.stmts {
        #partial switch concrete_stmt in stmt {
        case Var_Decl_Stmt:
            if expr, ok := concrete_stmt.init_expr.(Any_Expr); ok {
                expression_type := check_expression(scope, expr)
                if expression_type != concrete_stmt.type_name {
                    fmt.panicf("Required type `%v` does not match with given type `%v` in the expression.", concrete_stmt.type_name, expression_type)
                }
            }

            scope_add(&scope, concrete_stmt)

            // add procedure parameters
            if init_expr, expr_present := concrete_stmt.init_expr.(Any_Expr); expr_present {
                if proc_expr, is_proc_expr := init_expr.(Proc_Expr); is_proc_expr {
                    for param_decl in proc_expr.parameters do scope_add(&scope, param_decl)
                }
            }
        case Block_Stmt:
            new_scope := Scope_Context {
                global_table = scope.global_table,
                current_table = make(map[string]Var_Decl_Stmt),
                prev = &scope
            }
            analyze_block_stmt(concrete_stmt, new_scope)
        case Assign_Stmt:
            if _, exist := scope_get_symbol(scope, concrete_stmt.name); !exist {
                fmt.panicf("Symbol `%v` does not exist.", concrete_stmt.name)
            }
        }
    }
}

check_expression :: proc(scope: Scope_Context, any_expr: Any_Expr) -> Any_Type {
    switch expr in any_expr {
    case Identifier_Expr:
        if declaration, exist := scope_get_symbol(scope, expr.name); !exist {
            fmt.panicf("Variable `%v` does not exist.", expr.name)
        } else {
            return declaration.type_name.(string)
        }
    case Literal_Expr:
        return token_kind_to_type(expr.kind)
    case Binary_Expr:
        left_type,  ok1 := check_expression(scope, expr.left^).(Named_Type)
        right_type, ok2 := check_expression(scope, expr.right^).(Named_Type)
        if !ok1 || !ok2 || left_type.name != "int" || right_type.name != "int" {
            fmt.panicf("Expr cannot be binary expression.")
        }
        return Named_Type {name = "int"}
    case Unary_Expr:
        expr_type, ok1 := check_expression(scope, expr.expr^).(Named_Type)
        if !ok1 || expr_type.name != "int" {
            fmt.panicf("Expr cannot be unary expression.")
        }
        return Named_Type {name = "int"}
    case Index_Expr: // mama[lol]
        expr_type, ok := check_expression(scope, expr.index^).(Named_Type)
        if !ok || expr_type.name != "int" {
            fmt.panicf("Index could be only an integer.")
        }
        check_expression(scope, expr.expr^).(Array_Type) or_else fmt.panicf("Variable has to be indexable.")
    case Array_Expr:
        unimplemented("Checking array literals")
    case Call_Expr: // asd()

    // case Proc_Expr:
    // case Struct_Type_Expr:
    // case Struct_Instance_Expr:
    }
    unreachable()
}
