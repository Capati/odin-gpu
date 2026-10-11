/*
Loads glTF 2.0 documents (`.gltf` text or `.glb` binary).

This is a pure-Odin glTF 2.0 implementation.  It parses with a hand written
streaming tokenizer, keeps the document graph in an arena so that loading is
a handful of allocations, with strict validation that rejects spec
violations (see `validate.odin` and `accessor.odin`).

# Basic use

    doc, err := gltf.parse_file("assets/scene.gltf")
    if err != nil { ... }
    defer gltf.destroy(doc)

    if verr := gltf.validate(doc); verr != nil { ... }

# Ownership

Everything a `Document` owns (all slices, all strings, decoded buffer
payloads) lives in an arena embedded in the `Document`, so `destroy` releases
all of it in one call. Native targets use virtual-memory blocks; JS uses
`core:mem.Dynamic_Arena` backed by the configured allocator.

The exceptions are the chunks that are deliberately *not* copied:

- `Document.json` points into the bytes given to `parse`,
- `Document.bin` points into the GLB chunk (or the file bytes) of the input,
- `Document.file_data` is owned by the document only for `parse_file`.

On web targets, call `parse` or `parse_string` with bytes obtained through
the browser. `parse_file` is native-only and returns `Error.Unknown_Format`
on JS targets. To fetch external buffer URIs in the browser, provide
`Options.read_file` to `load_buffers`.

`strings` that point at those bytes (names, URIs, generator, ...) therefore
remain valid exactly as long as the input slice does.  Do not append to a
slice that was passed to `parse`, and do not append to a slice that is still
referenced by `Document.json` or `Document.bin`: appending may reallocate
and invalidate every `Document` that points into it.

# Versions

Only glTF 2.x is accepted.  A document whose `asset.version` is older than
2.0 is rejected with `Error.Legacy_Gltf`; a document with no parseable
version at all is rejected with `Error.Invalid_Gltf`.
*/
package gltf
