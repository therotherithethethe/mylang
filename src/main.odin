#+feature using-stmt
package main

main :: proc() {
    file_name :: "./tests/main.mylang"
    data := os.read_entire_file_from_path(
        file_name,
        context.temp_allocator,
        ) or_else fmt.panicf("Error reading a file `%s`\n", file_name)
    
    path := os.get_relative_path(
        ".",
        file_name,
        context.temp_allocator
        ) or_else fmt.panicf("Error getting a path to a file `%s`\n", file_name)

    fmt.printfln(path)
    tokenizer := Tokenizer {
        input = string(data),
        line = 1,
        col = 1,
        file_name = path,
    }

    ast_arena: mem.Dynamic_Arena
    mem.dynamic_arena_init(&ast_arena)
    ast_allocator := mem.dynamic_arena_allocator(&ast_arena)

    parser := make_parser(&tokenizer)
    builder := strings.builder_make(ast_allocator)

    global_symbol_table := make(map[string]Var_Decl_Stmt)
    global_decls := make([dynamic]Var_Decl_Stmt)
    for {
        stmt := parse_statement(&parser, ast_allocator)

        _, is_empty_stmt := stmt.(Empty_Stmt)
        if is_empty_stmt do break

        var_decl_stmt := stmt.(Var_Decl_Stmt)
        if var_decl_stmt.name in global_symbol_table {
            fmt.panicf("Symbol `%v` is already defined.", var_decl_stmt.name)
        }
        global_symbol_table[var_decl_stmt.name] = var_decl_stmt
        append(&global_decls, var_decl_stmt)
    }

    global_scope := Scope_Context {
        global_table = global_symbol_table,
        current_table = make(map[string]Var_Decl_Stmt)
    }
    for decl in global_decls {
        proc_expr := decl.init_expr.(Any_Expr).(Proc_Expr)
        analyze_procedure(proc_expr, global_scope)
    }

}

import "core:mem"
import "core:strings"
import "core:fmt"
import "core:os"
