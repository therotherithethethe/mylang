#+feature using-stmt
package main

main :: proc() {
    file_name := "./tests/main.mylang"
    data, err := os.read_entire_file_from_path(file_name, context.allocator)
    if err != nil do fmt.panicf("Error reading a file\n")

    path, _ := os.get_relative_path(".", file_name, context.allocator)
    fmt.printfln("\x1b[1m%s\x1b[0m", path)
    s := Tokenizer {input = string(data), line = 1, col = 1, file_name = path}
    for {
        stmt := parse_decl_assign_stmt(&s)
        _, ok := stmt.(Empty_Stmt)
        if ok do break
        fmt.println(stmt)

    }
    // parser := parser_make(s)
    // node := parse_expression(&parser, context.allocator)
    // node_string := tree_node_to_string_llm(node, context.allocator)
    // fmt.println(node_string)
}

import "core:fmt"
import "core:os"
