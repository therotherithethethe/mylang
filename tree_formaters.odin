#+feature using-stmt
package main

import "base:runtime"
import "core:fmt"
import "core:strings"

format_ast_tree :: proc(expr: Any_Expr, allocator: runtime.Allocator) -> string {
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

    print_node :: proc(expr: Any_Expr, builder: ^strings.Builder, prefix: string, is_last: bool, is_root: bool) {
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
        switch v in expr {
        case Proc_Expr:
            sbprintf(builder, "%#v", v)
        case Identifier_Expr:
            sbprintf(builder, "%s\n", v.name)
        case Literal_Expr:
            sbprintf(builder, "%s\n", v.text)
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
                print_node(v.callee^, builder, child_prefix, true, false)
            }
        }
    }
    print_node(expr, &builder, "", true, true)
    return string(builder.buf[:])
}

format_ast_sexpr :: proc(expr: Any_Expr, allocator := context.allocator) -> string {
    using strings, fmt
    builder := builder_make(allocator = allocator)
    impl :: proc(expr: Any_Expr, builder: ^strings.Builder) -> string {
        switch v in expr {
        case Proc_Expr:
            sbprintf(builder, "%#v", v)
        case Identifier_Expr:
            sbprint(builder, v.name)
        case Literal_Expr:
            sbprint(builder, v.text)
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
    return impl(expr, &builder)
}
