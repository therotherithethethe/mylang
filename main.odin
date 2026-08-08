#+feature using-stmt
package main

import "core:fmt"
import "core:os"

main :: proc() {
    src, err := os.read_entire_file_from_path("./tests/main.mylang", context.allocator)
    assert(err == nil)
    src_string := string(src)
    fmt.println(src_string)

    scanner := Scanner {input = src_string}
    for {
        tok := get_next_token(&scanner)
        if tok.value == "" do fmt.printfln("Token{{kind = \"%v\"}", tok.kind)
        else do fmt.println(tok)

        if tok.kind == .EOF do break
    }
}
