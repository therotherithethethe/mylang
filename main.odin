#+feature using-stmt
package main

main :: proc() {
    s := Scanner {input ="arr(1, 2)[1+2](5+3*4)"}
    parser := parser_make(s)
    node := parse_expression(&parser, context.allocator)
    node_string := tree_node_to_string_llm(node, context.allocator)
    fmt.println(node_string)
}

import "core:fmt"
