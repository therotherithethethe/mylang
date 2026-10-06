#+feature using-stmt
package main
import "base:runtime"
import "core:fmt"
import "core:strings"

format_ast_tree :: proc(node: Node, allocator: runtime.Allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)

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
        switch v in node {
        case string:
            sbprintf(builder, "%s\n", v)
        case Unary_Expr:
            sbprintf(builder, "Unary_Expr(%s)\n", token_kind_to_string(v.op))
            print_node(v.expr^, builder, child_prefix, true, false)
        case Binary_Expr:
            sbprintf(builder, "Binary_Expr(%s)\n", token_kind_to_string(v.op))
            print_node(v.left^, builder, child_prefix, false, false)
            print_node(v.right^, builder, child_prefix, true, false)
        case Index_Expr:
            sbprint(builder, "Index_Expr\n")
            print_node(v.expr^, builder, child_prefix, false, false)
            print_node(v.index^, builder, child_prefix, true, false)
        case Call_Expr:
            sbprint(builder, "Call_Expr\n")
            if len(v.args) > 0 {
                print_node(v.callee^, builder, child_prefix, false, false)
                for arg, i in v.args {
                    is_last_arg := i == len(v.args)-1
                    print_node(arg, builder, child_prefix, is_last_arg, false)
                }
            } else {
                sbprintf(builder, "%s└── %s\n", child_prefix, v.callee)
            }
        }
    }
    print_node(node, &builder, "", true, true)
    return string(builder.buf[:])
}

format_ast_sexpr :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)
    impl :: proc(node: Node, builder: ^strings.Builder) -> string {
        switch v in node {
        case string:
            sbprint(builder, v)
        case Unary_Expr:
            sbprintf(builder, "(%s ", token_kind_to_string(v.op))
            impl(v.expr^, builder)
            sbprint(builder, ")")
        case Binary_Expr:
            sbprintf(builder, "(%s ", token_kind_to_string(v.op))
            impl(v.left^, builder)
            sbprintf(builder, " ")
            impl(v.right^, builder)
            sbprint(builder, ")")
        case Index_Expr:
            sbprint(builder, "([")
            impl(v.expr^, builder)
            sbprintf(builder, " ")
            impl(v.index^, builder)
            sbprint(builder, ")")
        case Call_Expr:
            sbprint(builder, "(_call ")
            impl(v.callee^, builder)
            sbprint(builder, " ")
            if len(v.args) > 0 {
                for i in 0..<len(v.args)-1 {
                    impl(v.args[i], builder)
                    sbprint(builder, ", ")
                }
                impl(v.args[len(v.args) - 1], builder)
            }
            sbprint(builder, ")")
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}
format_ast_test1 :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make()
    impl :: proc(node: Node, builder: ^strings.Builder, prefix := "", allocator := context.allocator) -> string {
        next_call_prefix := aprintf("%s│   ", prefix, allocator = allocator)
        #partial switch value in node {
        case string:
            sbprintf(builder, "%s\n", value)
        case Unary_Expr:
            sbprintf(builder, "Unary(%s)\n%s└── ", token_kind_to_string(value.op), prefix)
            impl(value.expr^, builder, next_call_prefix)
        case Index_Expr:
            sbprintf(builder, "Index\n%s├── ", prefix)
            impl(value.expr^, builder, next_call_prefix)

            sbprintf(builder, "%s└── ", prefix)
            impl(value.index^, builder, prefix)
        case Binary_Expr:
            sbprintf(builder, "Binary(%s)\n%s├── ", token_kind_to_string(value.op), prefix)
            impl(value.left^, builder, next_call_prefix)

            sbprintf(builder, "%s├── ", prefix)
            impl(value.right^, builder, next_call_prefix)
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}

format_ast_test2 :: proc(node: Node, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make()
    impl :: proc(node: Node, builder: ^strings.Builder, prefix := "") -> string {
        prefix := prefix
        #partial switch value in node {
        case string:
            sbprintf(builder, "%s%s\n", prefix, value)
        case Binary_Expr:
            sbprintf(builder, "%sBinary(%s)\n", prefix, token_kind_to_string(value.op))
            first_prefix := aprintf("%s│ ", prefix)
            impl(value.left^, builder, first_prefix)
            second_prefix := aprintf("%s│ ", prefix)
            impl(value.right^, builder, second_prefix)
        }
        return string(builder.buf[:])
    }
    return impl(node, &builder)
}
