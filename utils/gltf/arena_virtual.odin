#+build !js
package gltf

// Core
import "core:mem"
import "core:mem/virtual"

Document_Arena :: virtual.Arena

document_arena_init :: proc(
    arena: ^Document_Arena,
    allocator: mem.Allocator,
    minimum_block_size: uint,
) -> mem.Allocator_Error {
    _ = allocator
    return virtual.arena_init_growing(arena, minimum_block_size)
}

document_arena_allocator :: proc(arena: ^Document_Arena) -> mem.Allocator {
    return virtual.arena_allocator(arena)
}

document_arena_destroy :: proc(arena: ^Document_Arena) {
    virtual.arena_destroy(arena)
}
