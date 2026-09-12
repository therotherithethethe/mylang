#+feature using-stmt
package main

// arr[1] -> ([ arr 1)
// 1 + 2 -> (+ 1 2)
main :: proc() {
    s := Scanner {input ="arr[1]"}
    parser := parser_make(s)
    node := parse_expression(&parser, context.allocator)
    node_string := tree_to_string(node, context.allocator)
    fmt.println(node_string)
}

tree_to_string_v2 :: proc(node: Node, allocator: runtime.Allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)
    print_node(node, &builder, "", true, true)
    return string(builder.buf[:])
}

indent_prefix :: proc(prefix: string, is_last: bool) -> string {
    using fmt
    if is_last {
        return aprintf("%s%s", prefix, "    ")
    } else {
        return aprintf("%s%s", prefix, "│   ")
    }
}

print_node :: proc(node: Node, builder: ^strings.Builder, prefix: string, is_last: bool, is_root: bool) {
    using strings, fmt
    if !is_root {
        if is_last {
            sbprintf(builder, "%s└── ", prefix)
        } else {
            sbprintf(builder, "%s├── ", prefix)
        }
    }

    child_prefix := prefix
    if !is_root {
        child_prefix = indent_prefix(prefix, is_last)
    } else {
        child_prefix = ""
    }
    #partial switch v in node {
    case string:
        sbprintf(builder, "%s\n", v)
    case Unary:
        sbprintf(builder, "Unary(%s)\n", op_to_str(v.op))
        print_node(v.child^, builder, child_prefix, true, false)
    case Binary:
        sbprintf(builder, "Binary(%s)\n", op_to_str(v.op))
        print_node(v.left_child^, builder, child_prefix, false, false)
        print_node(v.right_child^, builder, child_prefix, true, false)
    case Proc_Call:
        sbprintf(builder, "Procedure_Call\n")
        if len(v.args) > 0 {
            sbprintf(builder, "%s├── %s\n", child_prefix, v.ident)
            for arg, i in v.args {
                is_last_arg := i == len(v.args)-1
                print_node(arg, builder, child_prefix, is_last_arg, false)
            }
        } else {
            sbprintf(builder, "%s└── %s\n", child_prefix, v.ident)
        }
    }
}

import "core:fmt"
import "core:os"
import "core:strings"
import "base:runtime"
