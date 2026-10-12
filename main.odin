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
    for {
        stmt := parse_statement(&parser, ast_allocator)
        _, ok := stmt.(Empty_Stmt)
        if ok do break
        fmt.printfln("%#v", stmt)
    }
}

import "core:mem"
import "core:fmt"
import "core:os"
