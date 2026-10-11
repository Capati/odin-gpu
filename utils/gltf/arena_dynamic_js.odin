#+build js
package gltf

// Core
import "core:mem"

Document_Arena :: mem.Dynamic_Arena

document_arena_init :: proc(
    arena: ^Document_Arena,
    allocator: mem.Allocator,
    minimum_block_size: uint,
) -> mem.Allocator_Error {
    mem.dynamic_arena_init(
        arena,
        block_allocator = allocator,
        array_allocator = allocator,
        block_size = int(minimum_block_size),
    )
    return nil
}

document_arena_allocator :: proc(arena: ^Document_Arena) -> mem.Allocator {
    return mem.dynamic_arena_allocator(arena)
}

document_arena_destroy :: proc(arena: ^Document_Arena) {
    mem.dynamic_arena_destroy(arena)
}
