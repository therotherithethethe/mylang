package main

import "base:runtime"
import "core:bufio"
import "core:fmt"
import "core:io"
import "core:os"
import "core:reflect"

// Each struct, container, or pointer consumes one depth level. Unions and any
// are transparent wrappers. Scalars are always printed, even at depth zero.
print_value :: proc(value: any, depth: int) {
    buffer: [1024]byte
    writer: bufio.Writer
    bufio.writer_init_with_buf(&writer, os.to_stream(os.stdout), buffer[:])
    output := bufio.writer_to_writer(&writer)
    write_debug_value(output, value, max(depth, 0), 0)
    io.write_byte(output, '\n')
    io.flush(output)
}

@(private)
write_debug_indent :: proc(output: io.Writer, indent: int) {
    for _ in 0..<indent do io.write_string(output, "    ")
}

@(private)
write_debug_elements :: proc(output: io.Writer, data: rawptr, elem: typeid, elem_size, count, depth, indent: int) {
    if depth == 0 {
        io.write_string(output, "[...]")
        return
    }
    if count == 0 {
        io.write_string(output, "[]")
        return
    }
    io.write_string(output, "[\n")
    for i in 0..<count {
        write_debug_indent(output, indent + 1)
        value := any{rawptr(uintptr(data) + uintptr(i * elem_size)), elem}
        write_debug_value(output, value, depth - 1, indent + 1)
        io.write_string(output, ",\n")
    }
    write_debug_indent(output, indent)
    io.write_byte(output, ']')
}

@(private)
write_debug_value :: proc(output: io.Writer, value: any, depth, indent: int) {
    if value.id == nil || value.data == nil {
        io.write_string(output, "nil")
        return
    }

    base := reflect.type_info_base(type_info_of(value.id))
    #partial switch info in base.variant {
    case reflect.Type_Info_Any:
        write_debug_value(output, (^any)(value.data)^, depth, indent)
    case reflect.Type_Info_Union:
        write_debug_value(output, reflect.get_union_variant(value), depth, indent)
    case reflect.Type_Info_Pointer:
        pointer := (^rawptr)(value.data)^
        if pointer == nil {
            io.write_string(output, "nil")
        } else if depth == 0 || info.elem == nil {
            fmt.wprintf(output, "%p", pointer, flush = false)
        } else {
            io.write_byte(output, '&')
            write_debug_value(output, any{pointer, info.elem.id}, depth - 1, indent)
        }
    case reflect.Type_Info_Struct:
        // Raw unions have no active-variant tag; inspecting all fields can
        // mistake inactive bytes for pointers. SoA layouts need their own view.
        if .raw_union in info.flags || info.soa_kind != .None {
            fmt.wprintf(output, "%T", value, flush = false)
            io.write_string(output, "{...}")
            return
        }
        fmt.wprintf(output, "%T", value, flush = false)
        io.write_byte(output, '{')
        if depth == 0 {
            io.write_string(output, "...}")
            return
        }
        if info.field_count > 0 {
            io.write_byte(output, '\n')
            for i in 0..<int(info.field_count) {
                write_debug_indent(output, indent + 1)
                fmt.wprintf(output, "%s = ", info.names[i], flush = false)
                field := any{rawptr(uintptr(value.data) + info.offsets[i]), info.types[i].id}
                write_debug_value(output, field, depth - 1, indent + 1)
                io.write_string(output, ",\n")
            }
            write_debug_indent(output, indent)
        }
        io.write_byte(output, '}')
    case reflect.Type_Info_Array:
        write_debug_elements(output, value.data, info.elem.id, info.elem_size, info.count, depth, indent)
    case reflect.Type_Info_Enumerated_Array:
        write_debug_elements(output, value.data, info.elem.id, info.elem_size, info.count, depth, indent)
    case reflect.Type_Info_Slice:
        array := (^runtime.Raw_Slice)(value.data)
        write_debug_elements(output, array.data, info.elem.id, info.elem_size, array.len, depth, indent)
    case reflect.Type_Info_Dynamic_Array:
        array := (^runtime.Raw_Dynamic_Array)(value.data)
        write_debug_elements(output, array.data, info.elem.id, info.elem_size, array.len, depth, indent)
    case reflect.Type_Info_Fixed_Capacity_Dynamic_Array:
        count := (^int)(uintptr(value.data) + info.len_offset)^
        write_debug_elements(output, value.data, info.elem.id, info.elem_size, count, depth, indent)
    case reflect.Type_Info_Map:
        io.write_string(output, "map{")
        if depth == 0 {
            io.write_string(output, "...}")
            return
        }
        iterator: int
        has_entries := false
        for key, item in reflect.iterate_map(value, &iterator) {
            if !has_entries do io.write_byte(output, '\n')
            has_entries = true
            write_debug_indent(output, indent + 1)
            write_debug_value(output, key, depth - 1, indent + 1)
            io.write_string(output, " = ")
            write_debug_value(output, item, depth - 1, indent + 1)
            io.write_string(output, ",\n")
        }
        if has_entries do write_debug_indent(output, indent)
        io.write_byte(output, '}')
    case reflect.Type_Info_String:
        fmt.wprintf(output, "%q", value, flush = false)
    case:
        fmt.wprintf(output, "%#v", value, flush = false)
    }
}
