package gpu

// Core
import intr "base:intrinsics"
import "base:runtime"
import "core:math/bits"
import "core:slice"
import "core:sync"

// -----------------------------------------------------------------------------
// Retain/Release Hooks
// -----------------------------------------------------------------------------

// Strong command/usage trackers own the resources they hold for as long as
// they hold them, so a resource recorded into a command buffer stays alive
// until that command buffer's scope is dropped. Device trackers are explicitly
// weak and opt out of these hooks. The actual reference counting is delegated
// to the active backend through these hooks.
//
// They are left nil by default so the tracker stays backend-agnostic and can be
// exercised by unit tests without a device. A nil hook is a no-op, which is why
// tests may pass zero-valued resources.

tracker_retain_buffer: proc(buffer: Buffer, loc := #caller_location)
tracker_release_buffer: proc(buffer: Buffer, loc := #caller_location)
tracker_retain_texture: proc(texture: Texture, loc := #caller_location)
tracker_release_texture: proc(texture: Texture, loc := #caller_location)
tracker_retain_texture_view: proc(view: Texture_View, loc := #caller_location)
tracker_release_texture_view: proc(view: Texture_View, loc := #caller_location)

// Retain/release of a texture, used by the texture trackers and the
// texture-view bind group state.
resource_retain_texture :: proc(texture: Texture, loc := #caller_location) {
    if tracker_retain_texture != nil {
        tracker_retain_texture(texture, loc)
    }
}

resource_release_texture :: proc(texture: Texture, loc := #caller_location) {
    if tracker_release_texture != nil {
        tracker_release_texture(texture, loc)
    }
}

// Retain/release of a buffer, used by the buffer trackers and the buffer bind
// group state.
resource_retain_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    if tracker_retain_buffer != nil {
        tracker_retain_buffer(buffer, loc)
    }
}

resource_release_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    if tracker_release_buffer != nil {
        tracker_release_buffer(buffer, loc)
    }
}

bind_group_retain_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    resource_retain_buffer(buffer, loc)
}

bind_group_release_buffer :: proc(buffer: Buffer, loc := #caller_location) {
    resource_release_buffer(buffer, loc)
}

// Retain/release of a texture view, used by the texture-view bind group state.
// The view is what the bind group holds, and it in turn keeps its parent
// texture alive.
bind_group_retain_texture_view :: proc(view: Texture_View, loc := #caller_location) {
    if tracker_retain_texture_view != nil {
        tracker_retain_texture_view(view, loc)
    }
}

bind_group_release_texture_view :: proc(view: Texture_View, loc := #caller_location) {
    if tracker_release_texture_view != nil {
        tracker_release_texture_view(view, loc)
    }
}

// -----------------------------------------------------------------------------
// Buffer
// -----------------------------------------------------------------------------

// Similar to `Buffer_Usages`, but for internal use.
Buffer_Uses :: bit_set[Buffer_Use;u16]
Buffer_Use :: enum u16 {
    // The argument to a read-only mapping.
    Map_Read,
    // The argument to a write-only mapping.
    Map_Write,
    // The source of a hardware copy.
    // cbindgen:ignore
    Copy_Src,
    // The destination of a hardware copy.
    // cbindgen:ignore
    Copy_Dst,
    // The index buffer used for drawing.
    Index,
    // A vertex buffer used for drawing.
    Vertex,
    // A uniform buffer bound in a bind group.
    Uniform,
    // A read-only storage buffer used in a bind group.
    // cbindgen:ignore
    Storage_Read_Only,
    // A read-write buffer used in a bind group.
    // cbindgen:ignore
    Storage_Read_Write,
    // The indirect or count buffer in a indirect draw or dispatch.
    Indirect,
    // A buffer used to store query results.
    Query_Resolve,
    // Buffer used for acceleration structure building.
    Acceleration_Structure_Scratch,
    // Buffer used for bottom level acceleration structure building.
    Bottom_Level_Acceleration_Structure_Input,
    // Buffer used for top level acceleration structure building.
    Top_Level_Acceleration_Structure_Input,
    // A buffer used to store the compacted size of an acceleration structure
    Acceleration_Structure_Query,
}

// The combination of states that a buffer may be in _at the same time_.
BUFFER_USES_INCLUSIVE :: Buffer_Uses {
    .Map_Read,
    .Copy_Src,
    .Index,
    .Vertex,
    .Uniform,
    .Storage_Read_Only,
    .Indirect,
    .Bottom_Level_Acceleration_Structure_Input,
    .Top_Level_Acceleration_Structure_Input,
}

// The combination of states that a buffer must exclusively be in.
BUFFER_USES_EXCLUSIVE :: Buffer_Uses {
    .Map_Write,
    .Copy_Dst,
    .Storage_Read_Write,
    .Acceleration_Structure_Scratch,
}

BUFFER_USES_TIMESTAMP_NORMALIZATION :: Buffer_Uses{.Storage_Read_Write}

BUFFER_USES_MAPPABLE :: Buffer_Uses{.Map_Read, .Map_Write}

BUFFER_USES_COPY :: Buffer_Uses{.Copy_Src, .Copy_Dst}

BUFFER_USES_STAGING :: BUFFER_USES_MAPPABLE | BUFFER_USES_COPY

buffer_uses_is_empty :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return u == {}
}

buffer_uses_intersects :: #force_inline proc "contextless" (u, mask: Buffer_Uses) -> bool {
    return (u & mask) != {}
}

buffer_uses_contains :: #force_inline proc "contextless" (u, other: Buffer_Uses) -> bool {
    return (u & other) == other
}

buffer_uses_remove :: #force_inline proc "contextless" (u, mask: Buffer_Uses) -> Buffer_Uses {
    return u & ~mask
}

// Returns true if any of the uses are exclusive.
buffer_uses_any_exclusive :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return buffer_uses_intersects(u, BUFFER_USES_EXCLUSIVE)
}

// Returns true if the given state violates the usage scope rule of
// any(inclusive) XOR one(exclusive).
buffer_uses_is_invalid :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return buffer_uses_any_exclusive(u) && bits.count_ones(transmute(u16)u) != 1
}

buffer_uses_is_mappable :: #force_inline proc "contextless" (uses: Buffer_Uses) -> bool {
    return (uses & BUFFER_USES_MAPPABLE) != {}
}

// True if `uses` contains only bits that are also in `superset` (possibly empty).
buffer_uses_is_subset :: #force_inline proc "contextless" (
    uses: Buffer_Uses,
    superset: Buffer_Uses,
) -> bool {
    return uses != {} && (uses & superset) == uses
}

// Turns the resource into a pile of bits.
buffer_uses_bits :: proc(u: Buffer_Uses) -> u32 {
    return u32(transmute(u16)u)
}

Buffer_Usage_Error :: struct {
    buffer:        Buffer,
    current_state: Buffer_Uses,
    new_state:     Buffer_Uses,
}

// The conflicting usage pair of a failed texture merge.
Texture_Usage_Error :: struct {
    texture:       Texture,
    mip_levels:    Range(u32),
    array_layers:  Range(u32),
    current_state: Texture_Uses,
    new_state:     Texture_Uses,
}

// Error returned when merging two resource usages conflicts.
Usage_Error :: union {
    Buffer_Usage_Error,
    Texture_Usage_Error,
}

// A barrier between two states of a resource.
State_Transition :: struct($T: typeid) {
    from: T,
    to:   T,
}

Buffer_Barrier :: struct {
    buffer: Buffer,
    usage:  State_Transition(Buffer_Uses),
}

// A single ordered range `start..end` associated with a value.
Ranged_State_Entry :: struct($I: typeid, $T: typeid) {
    using range: Range(I),
    value:       T,
}

// Keeps track of an index -> value mapping, optimized for the case where
// keys of the same value are often grouped together linearly. Ranges of
// keys must be non-intersecting and ordered.
Ranged_States :: struct($I: typeid, $T: typeid) {
    ranges: [dynamic]Ranged_State_Entry(I, T),
}

ranged_states_init :: proc(
    rs: ^$R/Ranged_States($I, $T),
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(rs != nil, loc = loc)
    rs^ = {} // reset memory
    rs.ranges.allocator = allocator
}

ranged_states_uninit :: proc(rs: ^$R/Ranged_States($I, $T), loc := #caller_location) {
    assert(rs != nil, loc = loc)
    delete(rs.ranges)
    rs^ = {} // reset memory
}

// Constructs a new instance holding a single range. `value` is copied into
// the table.
ranged_states_init_from_range :: proc(
    rs: ^$R/Ranged_States($I, $T),
    range: Range(I),
    value: T,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(rs != nil, loc = loc)
    rs^ = {} // reset memory
    rs.ranges.allocator = allocator
    append(
        &rs.ranges,
        Ranged_State_Entry(I, T){start = range.start, end = range.end, value = value},
    )
}

// Constructs a new instance from a slice of ranges. Each `value` is copied
// into the table.
ranged_states_init_from_slice :: proc(
    rs: ^$R/Ranged_States($I, $T),
    values: []Ranged_State_Entry(I, T),
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(rs != nil, loc = loc)
    rs^ = {} // reset memory
    rs.ranges = make([dynamic]Ranged_State_Entry(I, T), 0, len(values), allocator)
    for &e in values {
        append(&rs.ranges, e)
    }
}

// Deep clone. Unlike a struct copy, the result owns its own backing, so the
// two instances can be mutated and freed independently.
ranged_states_clone :: proc(
    rs: ^$R/Ranged_States($I, $T),
    rs_out: ^Ranged_States(I, T),
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(rs != nil, loc = loc)
    assert(rs_out != nil, loc = loc)
    rs_out^ = {} // reset memory
    ranged_states_init(rs_out, allocator)
    resize(&rs_out.ranges, len(rs.ranges))
    copy(rs_out.ranges[:], rs.ranges[:])
}

// Check that all ranges are non-intersecting and ordered. Panics otherwise.
ranged_states_check_sanity :: proc(rs: ^$R/Ranged_States($I, $T), loc := #caller_location) {
    for e in 0 ..< len(rs.ranges) {
        assert(rs.ranges[e].start < rs.ranges[e].end, loc = loc)
    }
    for e in 1 ..< len(rs.ranges) {
        assert(rs.ranges[e - 1].end <= rs.ranges[e].start, loc = loc)
    }
}

// Merge neighboring ranges together where possible.
ranged_states_coalesce :: proc(rs: ^$R/Ranged_States($I, $T)) {
    if len(rs.ranges) == 0 {return}

    write := 1
    prev := &rs.ranges[0]
    for read in 1 ..< len(rs.ranges) {
        entry := rs.ranges[read]
        if prev.range.end == entry.range.start && prev.value == entry.value {
            prev.range.end = entry.range.end
        } else {
            rs.ranges[write] = entry
            prev = &rs.ranges[write]
            write += 1
        }
    }
    if write != len(rs.ranges) {
        resize(&rs.ranges, write)
    }
}

ranged_states_isolate :: proc(
    rs: ^$R/Ranged_States($I, $T),
    index: Range(I),
    default: T,
) -> []Ranged_State_Entry(I, T) {
    start_pos := 0
    for start_pos < len(rs.ranges) && rs.ranges[start_pos].end <= index.start {
        start_pos += 1
    }
    if start_pos == len(rs.ranges) {
        append(
            &rs.ranges,
            Ranged_State_Entry(I, T){start = index.start, end = index.end, value = default},
        )
        return rs.ranges[start_pos:]
    }

    {
        e := rs.ranges[start_pos]
        if e.start < index.start {
            rs.ranges[start_pos].start = index.start
            ok, _ := inject_at(
                &rs.ranges,
                start_pos,
                Ranged_State_Entry(I, T){start = e.start, end = index.start, value = e.value},
            )
            assert(ok)
            start_pos += 1
        }
    }

    pos := start_pos
    range_pos := index.start
    for {
        e := rs.ranges[pos]
        if e.start >= index.end {
            ok, _ := inject_at(
                &rs.ranges,
                pos,
                Ranged_State_Entry(I, T){start = range_pos, end = index.end, value = default},
            )
            assert(ok)
            pos += 1
            break
        }
        if e.start > range_pos {
            ok, _ := inject_at(
                &rs.ranges,
                pos,
                Ranged_State_Entry(I, T){start = range_pos, end = e.start, value = default},
            )
            assert(ok)
            pos += 1
            range_pos = e.start
        }
        if e.end >= index.end {
            if e.end != index.end {
                rs.ranges[pos].start = index.end
                ok, _ := inject_at(
                    &rs.ranges,
                    pos,
                    Ranged_State_Entry(I, T){start = range_pos, end = index.end, value = e.value},
                )
                assert(ok)
            }
            pos += 1
            break
        }
        pos += 1
        range_pos = e.end
        if pos == len(rs.ranges) {
            append(
                &rs.ranges,
                Ranged_State_Entry(I, T){start = range_pos, end = index.end, value = default},
            )
            pos += 1
            break
        }
    }

    return rs.ranges[start_pos:pos]
}

// Iterator over the entries overlapping `[range_start, range_end)`, with each
// returned range clipped to the requested one.
Ranged_Filter_Iterator :: struct($I: typeid, $T: typeid) {
    rs:          ^Ranged_States(I, T),
    range_start: I,
    range_end:   I,
    pos:         int,
}

ranged_filter_iterator :: proc(
    rs: ^$R/Ranged_States($I, $T),
    range_start, range_end: I,
) -> Ranged_Filter_Iterator(I, T) {
    return {rs = rs, range_start = range_start, range_end = range_end}
}

Ranged_Filter_Iterator_Result :: struct($T: typeid) {
    start: u32,
    end:   u32,
    value: ^T,
}

ranged_filter_iterator_next :: proc(
    it: ^$R/Ranged_Filter_Iterator($I, $T),
) -> (
    res: Ranged_Filter_Iterator_Result(T),
    cond: bool,
) {
    for it.pos < len(it.rs.ranges) {
        e := &it.rs.ranges[it.pos]
        it.pos += 1
        if e.end > it.range_start && e.start < it.range_end {
            res.start = max(e.start, it.range_start)
            res.end = min(e.end, it.range_end)
            res.value = &e.value
            return res, true
        }
    }
    return {0, 0, {}}, false
}

BITS_PER_WORD :: 64

// A dense, growable bit set.
//
// `size` is the logical index space. The backing `words` array is always
// exactly `ceil(size / BITS_PER_WORD)` words long, and the invariant
// "no bit with index >= size is ever set" is maintained by masking the tail
// word on every size-changing operation. As a consequence, `any`, `count_ones`,
// and `next_set_bit` never observe stale bits, and shrinking then growing a
// vector does not resurrect bits that were dropped.
//
// The backing array retains its capacity across shrinks, so resizing up and
// down within the same range does not reallocate.
Bit_Vector :: struct {
    words: [dynamic]u64, // ceil(size / BITS_PER_WORD) words
    size:  int, // logical length in bits
}

bits_per_word :: #force_inline proc "contextless" (size: int) -> int {
    return (size + BITS_PER_WORD - 1) / BITS_PER_WORD
}

bit_vector_init :: proc(
    bv: ^Bit_Vector,
    size: int,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(bv != nil, loc = loc)
    n := max(size, 0)
    // bv.words = make([dynamic]u64, bits_per_word(n), allocator)
    bv.words.allocator = allocator
    bit_vector_resize(bv, size)
    bv.size = n
}

bit_vector_uninit :: proc(bv: ^Bit_Vector, loc := #caller_location) {
    assert(bv != nil, loc = loc)
    delete(bv.words)
    bv^ = {}
}

// Number of bits in the pre-sized index space.
bit_vector_len :: #force_inline proc "contextless" (
    bv: ^Bit_Vector,
    loc := #caller_location,
) -> int {
    assert_contextless(bv != nil, loc = loc)
    return bv.size
}

// Sets the logical `size`, growing the backing as needed, masks the tail word past
// `size`, and wipes the words that drop off the end when shrinking so `any` and
// the index iterators never observe stale bits.
bit_vector_resize :: proc(bv: ^Bit_Vector, size: int) {
    needed_words := bits_per_word(size)
    old_words := len(bv.words)
    resize(&bv.words, needed_words)
    for i in old_words ..< needed_words {
        bv.words[i] = 0
    }
    // Mask off any bits beyond the new length that still live in the
    // last word, so a shrink-then-grow doesn't resurrect stale bits.
    if needed_words > 0 {
        valid_bits := uint(size - (needed_words - 1) * BITS_PER_WORD)
        if valid_bits < BITS_PER_WORD {
            mask := (u64(1) << valid_bits) - 1
            bv.words[needed_words - 1] &= mask
        }
    }
    bv.size = size
}

// Zeroes every bit without changing the vector's length or capacity.
bit_vector_clear :: proc(bv: ^Bit_Vector) {
    for i in 0 ..< len(bv.words) {
        bv.words[i] = 0
    }
}

bit_vector_get :: proc(bv: ^Bit_Vector, #any_int index: int) -> bool {
    if index < 0 || index >= bv.size {
        return false
    }
    word := bv.words[index / BITS_PER_WORD]
    return word & (u64(1) << uint(index % BITS_PER_WORD)) != 0
}

bit_vector_set :: proc(bv: ^Bit_Vector, #any_int index: int, value: bool) {
    word_index := index / BITS_PER_WORD
    bit := u64(1) << uint(index % BITS_PER_WORD)
    if value {
        bv.words[word_index] |= bit
    } else {
        bv.words[word_index] &~= bit
    }
}

// Returns true if any bit is set. O(words) in the number of words.
bit_vector_any :: proc(bv: ^Bit_Vector) -> bool {
    for w in bv.words {
        if w != 0 {
            return true
        }
    }
    return false
}

bit_vector_count_ones :: proc(bv: ^Bit_Vector) -> int {
    total: u64
    for w in bv.words {
        total += bits.count_ones(w)
    }
    return int(total)
}

bit_vector_fill :: proc(bv: ^Bit_Vector, value: bool) {
    w := u64(0) if !value else ~u64(0)
    for i in 0 ..< len(bv.words) {
        bv.words[i] = w
    }
    // Mask the tail word so no bit >= size is set. Without this, `any`,
    // `count_ones`, and the iterator would observe bits beyond the logical
    // length, while `get` would hide them behind its bounds check.
    if len(bv.words) > 0 {
        if ri := bv.size % BITS_PER_WORD; ri != 0 {
            bv.words[len(bv.words) - 1] &= (u64(1) << uint(ri)) - 1
        }
    }
}

// Iterates set bit indices in ascending order. Whole zero words are
// skipped with one comparison.
Bit_Vector_Iterator :: struct {
    bv:         ^Bit_Vector,
    word_index: int,
    cur_word:   u64,
    base:       int,
}

bit_vector_iterate :: proc(bv: ^Bit_Vector) -> Bit_Vector_Iterator {
    it := Bit_Vector_Iterator {
        bv         = bv,
        word_index = 0,
    }
    if len(bv.words) > 0 {
        it.cur_word = bv.words[0]
    }
    return it
}

@(require_results)
bit_vector_iterator_next :: proc(it: ^Bit_Vector_Iterator) -> (index: int, ok: bool) {
    for {
        if it.cur_word == 0 {
            it.word_index += 1
            if it.word_index >= len(it.bv.words) {
                return 0, false
            }
            it.cur_word = it.bv.words[it.word_index]
            it.base = it.word_index * BITS_PER_WORD
            continue
        }
        bit := intr.count_trailing_zeros(it.cur_word)
        it.cur_word &~= u64(1) << bit
        return it.base + int(bit), true
    }
}

// A set of resources.
Resource_Metadata :: struct($T: typeid) {
    owned:     Bit_Vector,
    resources: [dynamic]T,
}

resource_metadata_init :: proc(
    md: ^$R/Resource_Metadata($T),
    size: int,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(md != nil, loc = loc)
    md^ = {} // reset memory
    md.resources.allocator = allocator
    bit_vector_init(&md.owned, size, allocator, loc)
    resource_metadata_set_size(md, size, loc)
}

resource_metadata_uninit :: proc(md: ^$R/Resource_Metadata($T), loc := #caller_location) {
    assert(md != nil, loc = loc)
    delete(md.resources)
    bit_vector_uninit(&md.owned)
    md^ = {} // reset memory
}

// Returns true if the tracker owns no resources. O(n) in the number of words.
resource_metadata_is_empty :: proc(
    md: ^$R/Resource_Metadata($T),
    loc := #caller_location,
) -> bool {
    assert(md != nil, loc = loc)
    return !bit_vector_any(&md.owned)
}

// Returns true if the set contains the resource with the given index.
resource_metadata_contains :: proc(
    md: ^$R/Resource_Metadata($T),
    #any_int index: int,
    loc := #caller_location,
) -> bool {
    assert(md != nil, loc = loc)
    if index < 0 || index >= bit_vector_len(&md.owned) {
        return false
    }
    return bit_vector_get(&md.owned, index)
}

// Same as contains, but the index must be in bounds.
resource_metadata_contains_unchecked :: proc(
    md: ^$R/Resource_Metadata($T),
    #any_int index: int,
    loc := #caller_location,
) -> bool {
    assert(md != nil, loc = loc)
    return bit_vector_get(&md.owned, index)
}

// Grows (or, in principle, shrinks) the tables to cover `size` indices.
resource_metadata_set_size :: proc(
    md: ^$R/Resource_Metadata($T),
    size: int,
    loc := #caller_location,
) {
    assert(md != nil, loc = loc)
    resize(&md.resources, size)
    bit_vector_resize(&md.owned, size)
}

// Drops every owned resource and resets the tables to zero length. The
// caller is responsible for releasing the resources, since this table is
// type-generic and cannot know how.
resource_metadata_clear :: proc(md: ^$R/Resource_Metadata($T), loc := #caller_location) {
    assert(md != nil, loc = loc)
    for index in 0 ..< bit_vector_len(&md.owned) {
        if bit_vector_get(&md.owned, index) {
            md.resources[index] = {}
        }
    }
    clear(&md.resources)
    bit_vector_resize(&md.owned, 0)
}

resource_metadata_assert_in_bounds :: proc(
    m: ^$R/Resource_Metadata($T),
    #any_int index: int,
    loc := #caller_location,
) {
    assert(m != nil, loc = loc)
    assert(index < m.owned.size, loc = loc)
    assert(index < len(m.resources), loc = loc)
}

// Adds the resource with the given index to the set and returns a reference
// to the stored copy. If the set already owns the index, the stored copy is
// replaced without changing ownership, so the caller must retain only when
// the index was not already owned. This table is type-generic and cannot know
// how to retain; see `buffer_state_insert` for the buffer path.
resource_metadata_insert :: proc(
    md: ^$R/Resource_Metadata($T),
    #any_int index: int,
    resource: T,
    loc := #caller_location,
) -> ^T {
    assert(md != nil, loc = loc)
    assert(index >= 0 && index < bit_vector_len(&md.owned), "index out of bounds")
    bit_vector_set(&md.owned, index, true)
    #no_bounds_check {
        md.resources[index] = resource
    }
    return &md.resources[index]
}

// Returns a pointer to the stored resource at the given owned index.
resource_metadata_get_unchecked :: proc(
    md: ^$R/Resource_Metadata($T),
    #any_int index: int,
    loc := #caller_location,
) -> T {
    assert(md != nil, loc = loc)
    assert(bit_vector_get(&md.owned, index), "resource not owned")
    #no_bounds_check {
        return md.resources[index]
    }
}

// Removes the resource with the given index from the set, dropping it. The
// caller is responsible for releasing the resource, since this table is
// type-generic and cannot know how.
resource_metadata_remove :: proc(
    md: ^$R/Resource_Metadata($T),
    #any_int index: int,
    loc := #caller_location,
) {
    assert(md != nil, loc = loc)
    assert(bit_vector_get(&md.owned, index), "resource not owned")
    md.resources[index] = {}
    bit_vector_set(&md.owned, index, false)
}

// Releases every resource held strongly by a command/usage metadata table,
// then clears it. Device tracker metadata is weak and must not use these
// helpers; tables of unref-counted types have nothing to do.
buffer_metadata_release_all :: proc(md: ^Resource_Metadata(Buffer), loc := #caller_location) {
    assert(md != nil, loc = loc)
    for index in 0 ..< bit_vector_len(&md.owned) {
        if bit_vector_get(&md.owned, index) {
            resource_release_buffer(md.resources[index], loc)
        }
    }
    resource_metadata_clear(md, loc)
}

texture_metadata_release_all :: proc(md: ^Resource_Metadata(Texture), loc := #caller_location) {
    assert(md != nil, loc = loc)
    for index in 0 ..< bit_vector_len(&md.owned) {
        if bit_vector_get(&md.owned, index) {
            resource_release_texture(md.resources[index], loc)
        }
    }
    resource_metadata_clear(md, loc)
}

// Iterate every tracked index, ascending. See resource_metadata_owned_resources
// below for the version that yields the stored T instead.
resource_metadata_indices :: proc(md: ^$R/Resource_Metadata($T)) -> Bit_Vector_Iterator {
    return bit_vector_iterate(&md.owned)
}

Resource_Metadata_Iterator :: struct($T: typeid) {
    metadata: ^Resource_Metadata(T),
    bits:     Bit_Vector_Iterator,
}

resource_metadata_iterate :: proc(
    m: ^Resource_Metadata($T),
    loc := #caller_location,
) -> Resource_Metadata_Iterator(T) {
    return Resource_Metadata_Iterator(T){metadata = m, bits = bit_vector_iterate(&m.owned)}
}

resource_metadata_iterate_next :: proc(
    it: ^Resource_Metadata_Iterator($T),
    loc := #caller_location,
) -> (
    resource: T,
    ok: bool,
) {
    index := bit_vector_iterator_next(&it.bits) or_return
    return it.metadata.resources[index], true
}

Direct_Resource_Provider :: struct($T: typeid) {
    resource: T,
}

Indirect_Resource_Provider :: struct($T: typeid) {
    metadata: ^Resource_Metadata(T),
}

Resource_Metadata_Provider :: union($T: typeid) {
    Direct_Resource_Provider(T),
    Indirect_Resource_Provider(T),
}

resource_metadata_provider_direct :: #force_inline proc "contextless" (
    resource: $T,
) -> Resource_Metadata_Provider(T) {
    return Direct_Resource_Provider(T){resource}
}

resource_metadata_provider_indirect :: #force_inline proc "contextless" (
    metadata: ^Resource_Metadata($T),
) -> Resource_Metadata_Provider(T) {
    return Indirect_Resource_Provider(T){metadata}
}

// Caller must ensure `index` is in bounds for the indirect source.
resource_metadata_provider_get :: #force_inline proc(
    p: ^$D/Resource_Metadata_Provider($T),
    #any_int index: int,
    loc := #caller_location,
) -> T {
    assert(p != nil, loc = loc)
    switch v in p {
    case Direct_Resource_Provider(T):
        return v.resource
    case Indirect_Resource_Provider(T):
        return resource_metadata_get_unchecked(v.metadata, index, loc)
    case:
        panic("invalid resource provider type", loc)
    }
}

// A structure containing all the information about a particular resource
// transition. User code can build a pipeline barrier from its contents.
Pending_Transition :: struct($Uses: typeid, $Selector: typeid) {
    id:       u32,
    selector: Selector,
    usage:    State_Transition(Uses),
}

// Buffers have no subresources, so their transitions carry a unit selector.
Pending_Buffer_Transition :: Pending_Transition(Buffer_Uses, struct {})

// A densely-indexed per-resource-type id used to address the tracker tables.
Tracker_Index :: distinct u32

Tracker_Index_Allocator :: struct {
    unused:     [dynamic]Tracker_Index,
    next_index: Tracker_Index,
}

tracker_index_allocator_init :: proc(
    a: ^Tracker_Index_Allocator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    a.unused.allocator = allocator
}

tracker_index_allocator_uninit :: proc(a: ^Tracker_Index_Allocator, loc := #caller_location) {
    assert(a != nil, loc = loc)
    delete(a.unused)
}

tracker_index_allocator_alloc :: proc(
    a: ^Tracker_Index_Allocator,
    loc := #caller_location,
) -> Tracker_Index {
    assert(a != nil, loc = loc)
    if len(a.unused) > 0 {
        return pop(&a.unused)
    }
    index := a.next_index
    a.next_index += 1
    return index
}

tracker_index_allocator_free :: proc(
    a: ^Tracker_Index_Allocator,
    #any_int index: Tracker_Index,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    append(&a.unused, index)
}

// Highest index ever handed out. Used to pre-size tracker storage with
// resource_metadata_set_size / etc. before doing unchecked accesses.
tracker_index_allocator_size :: proc(a: ^Tracker_Index_Allocator, loc := #caller_location) -> int {
    assert(a != nil, loc = loc)
    return int(a.next_index)
}

// A thread-safe tracker index allocator. There is one of these per resource
// type, shared by a device and its hubs.
Shared_Tracker_Index_Allocator :: struct {
    mtx:   sync.Mutex,
    inner: Tracker_Index_Allocator,
}

shared_tracker_index_allocator_init :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    tracker_index_allocator_init(&a.inner, allocator)
}

shared_tracker_index_allocator_uninit :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    tracker_index_allocator_uninit(&a.inner)
}

shared_tracker_index_allocator_alloc :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    loc := #caller_location,
) -> Tracker_Index {
    assert(a != nil, loc = loc)
    sync.guard(&a.mtx)
    return tracker_index_allocator_alloc(&a.inner)
}

shared_tracker_index_allocator_free :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    #any_int index: Tracker_Index,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    sync.guard(&a.mtx)
    tracker_index_allocator_free(&a.inner, index)
}

shared_tracker_index_allocator_size :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    loc := #caller_location,
) -> int {
    assert(a != nil, loc = loc)
    sync.guard(&a.mtx)
    return tracker_index_allocator_size(&a.inner)
}

// One allocator per resource kind that gets tracked.
Tracker_Index_Allocators :: struct {
    buffers:           Shared_Tracker_Index_Allocator,
    textures:          Shared_Tracker_Index_Allocator,
    samplers:          Shared_Tracker_Index_Allocator,
    bind_groups:       Shared_Tracker_Index_Allocator,
    compute_pipelines: Shared_Tracker_Index_Allocator,
    render_pipelines:  Shared_Tracker_Index_Allocator,
    bundles:           Shared_Tracker_Index_Allocator,
    query_sets:        Shared_Tracker_Index_Allocator,
    blas_s:            Shared_Tracker_Index_Allocator,
}

tracker_index_allocators_init :: proc(
    a: ^Tracker_Index_Allocators,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(a != nil, loc = loc)
    shared_tracker_index_allocator_init(&a.buffers, allocator)
    shared_tracker_index_allocator_init(&a.textures, allocator)
    shared_tracker_index_allocator_init(&a.samplers, allocator)
    shared_tracker_index_allocator_init(&a.bind_groups, allocator)
    shared_tracker_index_allocator_init(&a.compute_pipelines, allocator)
    shared_tracker_index_allocator_init(&a.render_pipelines, allocator)
    shared_tracker_index_allocator_init(&a.bundles, allocator)
    shared_tracker_index_allocator_init(&a.query_sets, allocator)
    shared_tracker_index_allocator_init(&a.blas_s, allocator)
}

tracker_index_allocators_uninit :: proc(a: ^Tracker_Index_Allocators, loc := #caller_location) {
    assert(a != nil, loc = loc)
    shared_tracker_index_allocator_uninit(&a.buffers)
    shared_tracker_index_allocator_uninit(&a.textures)
    shared_tracker_index_allocator_uninit(&a.samplers)
    shared_tracker_index_allocator_uninit(&a.bind_groups)
    shared_tracker_index_allocator_uninit(&a.compute_pipelines)
    shared_tracker_index_allocator_uninit(&a.render_pipelines)
    shared_tracker_index_allocator_uninit(&a.bundles)
    shared_tracker_index_allocator_uninit(&a.query_sets)
    shared_tracker_index_allocator_uninit(&a.blas_s)
}

// Convenience wrappers used to size the buffer tracker tables.
tracker_index_allocators_buffer_size :: proc(
    a: ^Tracker_Index_Allocators,
    loc := #caller_location,
) -> int {
    return shared_tracker_index_allocator_size(&a.buffers)
}

tracker_index_allocators_texture_size :: proc(
    a: ^Tracker_Index_Allocators,
    loc := #caller_location,
) -> int {
    return shared_tracker_index_allocator_size(&a.textures)
}

Stateless_Tracker :: struct($T: typeid) {
    resources: [dynamic]T,
}

stateless_tracker_init :: proc(
    t: ^$S/Stateless_Tracker($T),
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t.resources.allocator = allocator
}

stateless_tracker_uninit :: proc(t: ^$S/Stateless_Tracker($T), loc := #caller_location) {
    assert(t != nil, loc = loc)
    delete(t.resources)
}

// Returns a pointer to the stored copy.
stateless_tracker_insert_single :: proc(
    t: ^$S/Stateless_Tracker($T),
    resource: T,
    loc := #caller_location,
) -> ^T {
    assert(t != nil, loc = loc)
    append(&t.resources, resource)
    return &t.resources[len(t.resources) - 1]
}

stateless_tracker_clear :: proc(t: ^$A/Stateless_Tracker($T), loc := #caller_location) {
    assert(t != nil, loc = loc)
    clear(&t.resources)
}

// Transfers ownership of the reference list out, leaving an empty list with
// the same allocator behind. The caller releases the returned references
// under whatever lock discipline applies to its tracker.
stateless_tracker_take :: proc(t: ^$S/Stateless_Tracker($T)) -> [dynamic]T {
    refs := t.resources
    t.resources = [dynamic]T{}
    t.resources.allocator = refs.allocator
    return refs
}

// Blas_Tracker
Blas_Tracker :: struct {
    metadata: Resource_Metadata(Blas),
    size:     int,
}

blas_tracker_init :: proc(
    t: ^Blas_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    resource_metadata_init(&t.metadata, 0, allocator)
}

blas_tracker_uninit :: proc(t: ^Blas_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    resource_metadata_uninit(&t.metadata, loc)
    t^ = {} // reset memory
}

blas_tracker_clear :: proc(t: ^Blas_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    resource_metadata_clear(&t.metadata, loc)
}

blas_tracker_set_size :: proc(t: ^Blas_Tracker, size: int, loc := #caller_location) {
    assert(t != nil, loc = loc)
    t.size = size
    resource_metadata_set_size(&t.metadata, size, loc)
}

blas_tracker_allow_index :: proc(t: ^Blas_Tracker, #any_int index: int, loc := #caller_location) {
    assert(t != nil, loc = loc)
    if index >= t.size {
        blas_tracker_set_size(t, index + 1, loc)
    }
}

// Returns a pointer to the stored copy.
blas_tracker_insert_single :: proc(
    t: ^Blas_Tracker,
    #any_int index: Tracker_Index,
    resource: Blas,
    loc := #caller_location,
) -> ^Blas {
    blas_tracker_allow_index(t, index, loc)
    return resource_metadata_insert(&t.metadata, index, resource)
}

blas_tracker_contains :: proc(t: ^Blas_Tracker, #any_int index: Tracker_Index) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

blas_tracker_used_resources :: proc(t: ^Blas_Tracker) -> Resource_Metadata_Iterator(Blas) {
    return resource_metadata_iterate(&t.metadata)
}

// Query_Set_Tracker
Query_Set_Tracker :: struct {
    metadata: Resource_Metadata(Query_Set),
    size:     int,
}

query_set_tracker_init :: proc(
    t: ^Query_Set_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    resource_metadata_init(&t.metadata, 0, allocator)
}

query_set_tracker_uninit :: proc(t: ^Query_Set_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    resource_metadata_uninit(&t.metadata, loc)
    t^ = {} // reset memory
}

query_set_tracker_clear :: proc(t: ^Query_Set_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    resource_metadata_clear(&t.metadata, loc)
}

query_set_tracker_set_size :: proc(t: ^Query_Set_Tracker, size: int, loc := #caller_location) {
    assert(t != nil, loc = loc)
    t.size = size
    resource_metadata_set_size(&t.metadata, size, loc)
}

query_set_tracker_allow_index :: proc(
    t: ^Query_Set_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    if index >= t.size {
        query_set_tracker_set_size(t, index + 1, loc)
    }
}

// Returns a pointer to the stored copy.
query_set_tracker_insert_single :: proc(
    t: ^Query_Set_Tracker,
    #any_int index: Tracker_Index,
    resource: Query_Set,
    loc := #caller_location,
) -> ^Query_Set {
    query_set_tracker_allow_index(t, index, loc)
    return resource_metadata_insert(&t.metadata, index, resource)
}

query_set_tracker_contains :: proc(t: ^Query_Set_Tracker, #any_int index: Tracker_Index) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

query_set_tracker_used_resources :: proc(
    t: ^Query_Set_Tracker,
) -> Resource_Metadata_Iterator(Query_Set) {
    return resource_metadata_iterate(&t.metadata)
}

Buffer_Bind_Group_Entry :: struct {
    index:  Tracker_Index,
    buffer: Buffer,
    state:  Buffer_Uses,
}

Buffer_Bind_Group_State :: struct {
    buffers: [dynamic]Buffer_Bind_Group_Entry,
}

buffer_bind_group_state_init :: proc(
    s: ^Buffer_Bind_Group_State,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    s.buffers.allocator = allocator
}

buffer_bind_group_state_uninit :: proc(s: ^Buffer_Bind_Group_State, loc := #caller_location) {
    assert(s != nil, loc = loc)
    buffer_bind_group_state_clear(s, loc)
    delete(s.buffers)
}

// Releases every buffer the state owns and empties the list, without changing
// the allocator.
buffer_bind_group_state_clear :: proc(s: ^Buffer_Bind_Group_State, loc := #caller_location) {
    assert(s != nil, loc = loc)
    for entry in s.buffers {
        bind_group_release_buffer(entry.buffer, loc)
    }
    clear(&s.buffers)
}

buffer_bind_group_state_insert_single :: proc(
    s: ^Buffer_Bind_Group_State,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    state: Buffer_Uses,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    bind_group_retain_buffer(buffer, loc)
    append(&s.buffers, Buffer_Bind_Group_Entry{index, buffer, state})
}

// Sorts by tracker index, so merging this bind group into a tracker
// later walks memory in ascending order.
buffer_bind_group_state_optimize :: proc(s: ^Buffer_Bind_Group_State) {
    slice.sort_by(s.buffers[:], proc(a, b: Buffer_Bind_Group_Entry) -> bool {
        return a.index < b.index
    })
}

Direct_Buffer_State :: struct {
    state: Buffer_Uses,
}

Indirect_Buffer_State :: struct {
    state: []Buffer_Uses,
}

Buffer_State_Provider :: union {
    Direct_Buffer_State,
    Indirect_Buffer_State,
}

buffer_state_provider_get :: #force_inline proc(
    p: ^Buffer_State_Provider,
    #any_int index: int,
    loc := #caller_location,
) -> Buffer_Uses {
    assert(p != nil, loc = loc)
    switch v in p {
    case Direct_Buffer_State:
        return v.state
    case Indirect_Buffer_State:
        #no_bounds_check {
            return v.state[index]
        }
    }
    return {}
}

buffer_state_provider_direct :: proc(state: Buffer_Uses) -> (out: Buffer_State_Provider) {
    out = Direct_Buffer_State {
        state = state,
    }
    return
}

buffer_state_provider_indirect :: proc(state: []Buffer_Uses) -> (out: Buffer_State_Provider) {
    out = Indirect_Buffer_State {
        state = state,
    }
    return
}

buffer_state_insert :: proc(
    start_states: []Buffer_Uses, // nil => don't record a start state
    current_states: []Buffer_Uses,
    resource_metadata: ^Resource_Metadata(Buffer),
    #any_int index: int,
    start_state_provider: ^Buffer_State_Provider,
    end_state_provider: ^Buffer_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Buffer),
    retain_resource := true,
    loc := #caller_location,
) {
    new_start_state := buffer_state_provider_get(start_state_provider, index, loc)
    new_end_state := new_start_state
    if end_state_provider != nil {
        new_end_state = buffer_state_provider_get(end_state_provider, index, loc)
    }

    // This should only ever happen with a bug.
    assert(!buffer_uses_is_invalid(new_start_state), loc = loc)
    assert(!buffer_uses_is_invalid(new_end_state), loc = loc)

    if start_states != nil {
        start_states[index] = new_start_state
    }
    current_states[index] = new_end_state

    resource := resource_metadata_provider_get(metadata_provider, index, loc)
    // Strong command/usage trackers retain on first insertion. The device
    // tracker passes `retain_resource = false` because its metadata is weak.
    if retain_resource && !resource_metadata_contains(resource_metadata, index) {
        resource_retain_buffer(resource, loc)
    }
    resource_metadata_insert(resource_metadata, index, resource, loc)
}

// If `index` is already tracked: merges the incoming state with the current one,
// reporting a conflict if the result would be invalid.
buffer_state_merge :: proc(
    current_states: []Buffer_Uses,
    #any_int index: int,
    state_provider: ^Buffer_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Buffer),
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    current_state := current_states[index]
    new_state := buffer_state_provider_get(state_provider, index)

    merged_state := current_state | new_state

    if buffer_uses_is_invalid(merged_state) {
        resource := resource_metadata_provider_get(metadata_provider, index)
        return Buffer_Usage_Error{resource, current_state, new_state}
    }

    current_states[index] = merged_state
    return
}

// True if going from old_state to new_state needs no barrier: the state didn't
// change, and every usage involved is one the backend already guarantees ordering
// for (ordered_uses_mask), so hardware/driver order is enough on its own.
skip_barrier :: #force_inline proc "contextless" (
    old_state, ordered_uses_mask, new_state: $F,
) -> bool {
    return old_state == new_state && old_state <= ordered_uses_mask
}

// Compares the current state against the incoming one and, if a real transition is
// needed, appends a pending barrier.
buffer_state_barrier :: proc(
    current_states: []Buffer_Uses,
    #any_int index: int,
    state_provider: ^Buffer_State_Provider,
    barriers: ^[dynamic]Pending_Buffer_Transition,
    ordered_uses_mask: Buffer_Uses,
    loc := #caller_location,
) {
    current_state := current_states[index]
    new_state := buffer_state_provider_get(state_provider, index, loc)

    if skip_barrier(current_state, ordered_uses_mask, new_state) {
        return
    }

    append(
        barriers,
        Pending_Buffer_Transition {
            id = u32(index),
            selector = {},
            usage = {from = current_state, to = new_state},
        },
    )
}

buffer_state_update :: proc(
    current_states: []Buffer_Uses,
    #any_int index: int,
    state_provider: ^Buffer_State_Provider,
    loc := #caller_location,
) {
    current_states[index] = buffer_state_provider_get(state_provider, index, loc)
}

// All buffer state touched within a single usage scope (a render pass, a
// compute dispatch, ...). Uses of the same buffer within the scope are merged;
// a conflicting merge (e.g. Storage_Read_Write + Vertex) is reported rather
// than silently resolved.
Buffer_Usage_Scope :: struct {
    state:             [dynamic]Buffer_Uses,
    metadata:          Resource_Metadata(Buffer),
    ordered_uses_mask: Buffer_Uses,
}

buffer_usage_scope_init :: proc(
    s: ^Buffer_Usage_Scope,
    size: int,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    s.state = make([dynamic]Buffer_Uses, allocator)
    resize(&s.state, size)
    resource_metadata_init(&s.metadata, size, allocator)
}

buffer_usage_scope_uninit :: proc(s: ^Buffer_Usage_Scope, loc := #caller_location) {
    assert(s != nil, loc = loc)
    delete(s.state)
    buffer_metadata_release_all(&s.metadata, loc)
    resource_metadata_uninit(&s.metadata)
}

buffer_usage_scope_assert_in_bounds :: proc(
    s: ^Buffer_Usage_Scope,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    assert(index < len(s.state), loc = loc)
    resource_metadata_assert_in_bounds(&s.metadata, index, loc)
}

buffer_usage_scope_clear :: proc(s: ^Buffer_Usage_Scope, loc := #caller_location) {
    assert(s != nil, loc = loc)
    clear(&s.state)
    buffer_metadata_release_all(&s.metadata, loc)
}

// Must be called with the highest possible buffer tracker index before any
// of the *_unchecked-backed operations below run.
buffer_usage_scope_set_size :: proc(s: ^Buffer_Usage_Scope, size: int, loc := #caller_location) {
    assert(s != nil, loc = loc)
    resize(&s.state, size)
    resource_metadata_set_size(&s.metadata, size)
}

buffer_usage_scope_set_ordered_uses_mask :: proc(
    s: ^Buffer_Usage_Scope,
    mask: Buffer_Uses,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    s.ordered_uses_mask = mask
}

buffer_usage_scope_allow_index :: proc(
    s: ^Buffer_Usage_Scope,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    if index >= len(s.state) {
        buffer_usage_scope_set_size(s, index + 1, loc)
    }
}

buffer_usage_scope_insert_or_merge :: proc(
    s: ^Buffer_Usage_Scope,
    #any_int index: int,
    state_provider: ^Buffer_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Buffer),
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(s != nil, loc = loc)
    if !resource_metadata_contains_unchecked(&s.metadata, index) {
        buffer_state_insert(
            nil,
            s.state[:],
            &s.metadata,
            index,
            state_provider,
            {},
            metadata_provider,
            retain_resource = true,
            loc = loc,
        )
        return
    }
    return buffer_state_merge(s.state[:], index, state_provider, metadata_provider, loc)
}

// Merges a bind group's buffer states into this scope. Because bind groups don't
// pre-validate their own internal usage union, this may legitimately fail on the
// very first bind group merged in.
//
// The scope grows as needed, so no prior `set_size` call is required: a bind
// group can reference buffers whose tracker indices outrun anything the pass has
// touched so far. This mirrors `texture_usage_scope_merge_single`.
buffer_usage_scope_merge_bind_group :: proc(
    s: ^Buffer_Usage_Scope,
    bind_group: ^Buffer_Bind_Group_State,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(s != nil, loc = loc)
    assert(bind_group != nil, loc = loc)
    for entry in bind_group.buffers {
        err = buffer_usage_scope_merge_single(s, entry.index, entry.buffer, entry.state, loc)
        if err != nil {
            return
        }
    }
    return
}

// Merges another usage scope's state into this one, growing this scope if
// needed, no prior set_size call required.
buffer_usage_scope_merge_usage_scope :: proc(
    s: ^Buffer_Usage_Scope,
    other: ^Buffer_Usage_Scope,
) -> (
    err: Usage_Error,
) {
    incoming_size := len(other.state)
    if incoming_size > len(s.state) {
        buffer_usage_scope_set_size(s, incoming_size)
    }

    it := resource_metadata_indices(&other.metadata)
    for index in bit_vector_iterator_next(&it) {
        buffer_usage_scope_assert_in_bounds(s, index)
        buffer_usage_scope_assert_in_bounds(other, index)

        buffer_direct := buffer_state_provider_indirect(other.state[:])
        metadata_indirect := resource_metadata_provider_indirect(&other.metadata)
        buffer_usage_scope_insert_or_merge(s, index, &buffer_direct, &metadata_indirect) or_return
    }
    return
}

// Merges a single buffer's state into this scope, growing the scope if
// needed, no prior set_size call required.
buffer_usage_scope_merge_single :: proc(
    s: ^Buffer_Usage_Scope,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    new_state: Buffer_Uses,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    buffer_usage_scope_allow_index(s, index, loc)
    buffer_usage_scope_assert_in_bounds(s, index, loc)

    buffer_direct := buffer_state_provider_direct(new_state)
    metadata_indirect := resource_metadata_provider_direct(buffer)

    return buffer_usage_scope_insert_or_merge(s, index, &buffer_direct, &metadata_indirect)
}

// Clears the given usage bits for a buffer already in this scope. Only safe to
// call when you're certain you won't be erasing a usage you don't know about —
// repeated uses of the same buffer get merged together, so this can't selectively
// undo just "your" contribution.
buffer_usage_scope_remove_usage :: proc(
    s: ^Buffer_Usage_Scope,
    #any_int index: Tracker_Index,
    usage: Buffer_Uses,
    loc := #caller_location,
) {
    if resource_metadata_contains(&s.metadata, index) {
        s.state[index] &~= usage
    }
}

// All buffer state touched within a single command buffer: a start state (what
// the buffer needs to be in when this command buffer begins) and an end state
// (what it's left in). Diffing start against the device's current state
// produces the transitions needed before this command buffer's work can run.
Buffer_Tracker :: struct {
    start:             [dynamic]Buffer_Uses,
    end:               [dynamic]Buffer_Uses,
    metadata:          Resource_Metadata(Buffer),
    temp:              [dynamic]Pending_Buffer_Transition,
    ordered_uses_mask: Buffer_Uses,
}

buffer_tracker_init :: proc(
    t: ^Buffer_Tracker,
    ordered_uses_mask: Buffer_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t.start.allocator = allocator
    t.end.allocator = allocator
    resource_metadata_init(&t.metadata, 0, allocator)
    t.end.allocator = allocator
    t.ordered_uses_mask = ordered_uses_mask
}

buffer_tracker_uninit :: proc(t: ^Buffer_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    delete(t.start)
    delete(t.end)
    buffer_metadata_release_all(&t.metadata, loc)
    resource_metadata_uninit(&t.metadata)
    delete(t.temp)
    t^ = {}
}

buffer_tracker_clear :: proc(t: ^Buffer_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    clear(&t.start)
    clear(&t.end)
    buffer_metadata_release_all(&t.metadata, loc)
    clear(&t.temp)
}

buffer_tracker_assert_in_bounds :: proc(
    t: ^Buffer_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(index < len(t.start), loc = loc)
    assert(index < len(t.end), loc = loc)
    resource_metadata_assert_in_bounds(&t.metadata, index, loc)
}

buffer_tracker_set_size :: proc(t: ^Buffer_Tracker, size: int, loc := #caller_location) {
    assert(t != nil, loc = loc)
    resize(&t.start, size)
    resize(&t.end, size)
    resource_metadata_set_size(&t.metadata, size)
}

buffer_tracker_allow_index :: proc(t: ^Buffer_Tracker, #any_int index: int) {
    if index >= len(t.start) {
        buffer_tracker_set_size(t, index + 1)
    }
}

buffer_tracker_contains :: proc(
    t: ^Buffer_Tracker,
    #any_int index: Tracker_Index,
    loc := #caller_location,
) -> bool {
    assert(t != nil, loc = loc)
    return resource_metadata_contains(&t.metadata, index)
}

buffer_tracker_used_resources :: proc(t: ^Buffer_Tracker) -> Resource_Metadata_Iterator(Buffer) {
    return resource_metadata_iterate(&t.metadata)
}

// Returns every pending transition accumulated so far and empties the
// internal buffer (capacity is kept for reuse). The caller owns the
// returned slice and should `delete()` it once done.
buffer_tracker_drain_transitions :: proc(
    t: ^Buffer_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Buffer_Transition {
    assert(t != nil, loc = loc)
    result := make([]Pending_Buffer_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

buffer_tracker_insert_or_barrier_update :: proc(
    t: ^Buffer_Tracker,
    #any_int index: int,
    start_state_provider: ^Buffer_State_Provider,
    end_state_provider: ^Buffer_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Buffer),
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)

    if !resource_metadata_contains_unchecked(&t.metadata, index) {
        buffer_state_insert(
            t.start[:],
            t.end[:],
            &t.metadata,
            index,
            start_state_provider,
            end_state_provider,
            metadata_provider,
            retain_resource = true,
            loc = loc,
        )
        return
    }

    update_state_provider := end_state_provider
    if update_state_provider == nil {
        update_state_provider = start_state_provider
    }

    buffer_state_barrier(t.end[:], index, start_state_provider, &t.temp, t.ordered_uses_mask)
    buffer_state_update(t.end[:], index, update_state_provider)
}

// Sets a single buffer's state, growing the tracker if needed. Returns the
// one transition needed (if any) to reach that state.
buffer_tracker_set_single :: proc(
    t: ^Buffer_Tracker,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    state: Buffer_Uses,
    loc := #caller_location,
) -> (
    transition: Pending_Buffer_Transition,
    ok: bool,
) {
    assert(t != nil, loc = loc)

    buffer_tracker_allow_index(t, index)
    buffer_tracker_assert_in_bounds(t, index)

    direct_buffer := buffer_state_provider_direct(state)
    direct_provider := resource_metadata_provider_direct(buffer)

    buffer_tracker_insert_or_barrier_update(t, index, &direct_buffer, {}, &direct_provider)

    assert(len(t.temp) <= 1)
    if len(t.temp) == 0 {
        return
    }
    transition = t.temp[0]
    clear(&t.temp)
    return transition, true
}

// Adopts every buffer's (start, end) state from `other`, growing this tracker if
// needed. Transitions are accumulated in `t.temp`: call
// `buffer_tracker_drain_transitions` afterward to collect them.
buffer_tracker_set_from_tracker :: proc(
    t: ^Buffer_Tracker,
    other: ^Buffer_Tracker,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(other != nil, loc = loc)

    incoming_size := len(other.start)
    if incoming_size > len(t.start) {
        buffer_tracker_set_size(t, incoming_size, loc)
    }

    it := resource_metadata_indices(&other.metadata)
    for index in bit_vector_iterator_next(&it) {
        buffer_tracker_assert_in_bounds(t, index, loc)
        buffer_tracker_assert_in_bounds(other, index, loc)

        buffer_indirect := buffer_state_provider_indirect(other.start[:])
        resource_indirect := resource_metadata_provider_indirect(&other.metadata)
        end_provider := buffer_state_provider_indirect(other.end[:])

        buffer_tracker_insert_or_barrier_update(
            t,
            index,
            &buffer_indirect,
            &end_provider,
            &resource_indirect,
            loc,
        )
    }
}

// Adopts every buffer's state from a usage scope, growing this tracker if needed.
// Transitions are accumulated in `t.temp`.
buffer_tracker_set_from_usage_scope :: proc(
    t: ^Buffer_Tracker,
    scope: ^Buffer_Usage_Scope,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(scope != nil, loc = loc)

    incoming_size := len(scope.state)
    if incoming_size > len(t.start) {
        buffer_tracker_set_size(t, incoming_size, loc)
    }

    it := resource_metadata_indices(&scope.metadata)
    for index in bit_vector_iterator_next(&it) {
        buffer_tracker_assert_in_bounds(t, index, loc)
        buffer_usage_scope_assert_in_bounds(scope, index, loc)

        buffer_indirect := buffer_state_provider_indirect(scope.state[:])
        resource_indirect := resource_metadata_provider_indirect(&scope.metadata)

        buffer_tracker_insert_or_barrier_update(
            t,
            index,
            &buffer_indirect,
            {},
            &resource_indirect,
            loc,
        )
    }
}

// Compute-pass barrier shortcut: for every buffer used by `bind_group`, adopts its
// state from `scope` (which the bind group must already have been merged into) and
// removes it from `scope`. Lets barriers be generated after a dispatch by walking
// only the bind group's resources instead of the whole usage scope. Panics
// (asserts, in debug builds) if a bind group resource isn't present in `scope`.
buffer_tracker_set_and_remove_from_usage_scope_sparse :: proc(
    t: ^Buffer_Tracker,
    scope: ^Buffer_Usage_Scope,
    indices: []Tracker_Index,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(scope != nil, loc = loc)

    incoming_size := len(scope.state)
    if incoming_size > len(t.start) {
        buffer_tracker_set_size(t, incoming_size, loc)
    }

    for tracker_index in indices {
        buffer_usage_scope_assert_in_bounds(scope, tracker_index)

        if !resource_metadata_contains_unchecked(&scope.metadata, tracker_index) {
            continue
        }

        buffer_indirect := buffer_state_provider_indirect(scope.state[:])
        resource_indirect := resource_metadata_provider_indirect(&scope.metadata)

        buffer_tracker_insert_or_barrier_update(
            t,
            tracker_index,
            &buffer_indirect,
            {},
            &resource_indirect,
            loc,
        )

        // Ownership moves to the command-buffer tracker, which retained it on
        // insert, so the usage scope gives up its reference here.
        resource_release_buffer(
            resource_metadata_get_unchecked(&scope.metadata, tracker_index, loc),
            loc,
        )
        resource_metadata_remove(&scope.metadata, tracker_index)
    }
}

// Stores the current state of every buffer used by a device. Its metadata is
// weak: the device tracker must not keep buffers alive, as their final release
// schedules deferred destruction and removes the tracker entry.
//
// Unlike a command-buffer tracker, this one belongs to the device and is reached
// from every thread that creates a buffer, records against it, writes to it, or
// destroys it. `mtx` serializes all of that; see the locking notes on
// `Device_Tracker` for the lock ordering rules.
Device_Buffer_Tracker :: struct {
    current_states:    [dynamic]Buffer_Uses,
    metadata:          Resource_Metadata(Buffer),
    temp:              [dynamic]Pending_Buffer_Transition,
    ordered_uses_mask: Buffer_Uses,
    mtx:               sync.RW_Mutex,
}

device_buffer_tracker_init :: proc(
    t: ^Device_Buffer_Tracker,
    ordered_uses_mask: Buffer_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    t.current_states.allocator = allocator
    t.temp.allocator = allocator
    t.ordered_uses_mask = ordered_uses_mask
    resource_metadata_init(&t.metadata, 0, allocator)
}

device_buffer_tracker_uninit :: proc(t: ^Device_Buffer_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    delete(t.current_states)
    resource_metadata_uninit(&t.metadata)
    delete(t.temp)
    t^ = {} // reset memory
}

// The buffer tracker is shared by every thread touching a device, so each of the
// operations below takes `mtx` itself. Helpers whose name ends in `_locked` assume
// the caller already holds the exclusive lock; they exist so composite operations
// can hold the lock once across a read-modify-write instead of re-entering the
// non-recursive `RW_Mutex`.
device_buffer_tracker_assert_in_bounds :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(index < len(t.current_states), loc = loc)
    resource_metadata_assert_in_bounds(&t.metadata, index, loc)
}

device_buffer_tracker_allow_index_locked :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    if index >= len(t.current_states) {
        resize(&t.current_states, index + 1)
        resource_metadata_set_size(&t.metadata, index + 1, loc)
    }
}

device_buffer_tracker_allow_index :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    sync.guard(&t.mtx)
    device_buffer_tracker_allow_index_locked(t, index, loc)
}

// Returns an iterator over every tracked buffer (weak).
//
// The iterator borrows `t`'s tables rather than copying them, so it is only valid
// while nothing else can mutate the tracker: either hold `mtx` exclusively for the
// whole walk, or be the tracker's only user. There is deliberately no lock taken
// here, because one would be released before the caller iterated, a lock that
// guards nothing is worse than none. Nothing in the backend uses this; it exists for
// introspection and tests.
device_buffer_tracker_used_resources :: proc(
    t: ^Device_Buffer_Tracker,
    loc := #caller_location,
) -> Resource_Metadata_Iterator(Buffer) {
    assert(t != nil, loc = loc)
    return resource_metadata_iterate(&t.metadata)
}

// Inserts (or overwrites) a single buffer's current state.
device_buffer_tracker_insert_single :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    state: Buffer_Uses,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)

    sync.guard(&t.mtx)
    device_buffer_tracker_insert_single_locked(t, index, buffer, state, loc)
}

// Exclusive-lock body of `device_buffer_tracker_insert_single`.
device_buffer_tracker_insert_single_locked :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    state: Buffer_Uses,
    loc := #caller_location,
) {
    device_buffer_tracker_allow_index_locked(t, index, loc)
    device_buffer_tracker_assert_in_bounds(t, index, loc)

    direct_buffer := buffer_state_provider_direct(state)
    direct_provider := resource_metadata_provider_direct(buffer)

    buffer_state_insert(
        start_states = nil,
        current_states = t.current_states[:],
        resource_metadata = &t.metadata,
        index = index,
        start_state_provider = &direct_buffer,
        end_state_provider = {},
        metadata_provider = &direct_provider,
        retain_resource = false,
        loc = loc,
    )
}

// Sets a single buffer's state. Returns the one transition needed (if
// any) to reach it.
@(require_results)
device_buffer_tracker_set_single :: proc(
    t: ^Device_Buffer_Tracker,
    #any_int index: Tracker_Index,
    buffer: Buffer,
    state: Buffer_Uses,
    loc := #caller_location,
) -> (
    transition: Pending_Buffer_Transition,
    ok: bool,
) {
    sync.guard(&t.mtx)
    device_buffer_tracker_assert_in_bounds(t, index, loc)

    start_state_provider := buffer_state_provider_direct(state)
    buffer_state_barrier(
        t.current_states[:],
        index,
        &start_state_provider,
        &t.temp,
        t.ordered_uses_mask,
    )
    buffer_state_update(t.current_states[:], index, &start_state_provider)

    assert(len(t.temp) <= 1, loc = loc)
    if len(t.temp) == 0 {
        return
    }
    transition = t.temp[0]
    clear(&t.temp)
    return transition, true
}

// Diffs every buffer in `tracker`'s start state against this device's current
// state, appends the needed transitions to `t.temp`, and adopts `tracker`'s end
// state as the new current state. Returns the collected transitions (caller owns
// the slice, `delete()` it when done).
//
// The whole diff-and-commit runs under one exclusive acquisition: two threads
// interleaving here would each diff against a current state the other had already
// advanced, producing barriers that are missing or duplicated.
device_buffer_tracker_set_from_tracker_and_drain_transitions :: proc(
    t: ^Device_Buffer_Tracker,
    tracker: ^Buffer_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Buffer_Transition {
    sync.guard(&t.mtx)

    it := resource_metadata_indices(&tracker.metadata)
    for index in bit_vector_iterator_next(&it) {
        device_buffer_tracker_assert_in_bounds(t, index, loc)

        start_state_provider := buffer_state_provider_indirect(tracker.start[:])
        end_state_provider := buffer_state_provider_indirect(tracker.end[:])

        buffer_state_barrier(
            current_states = t.current_states[:],
            index = index,
            state_provider = &start_state_provider,
            barriers = &t.temp,
            ordered_uses_mask = t.ordered_uses_mask,
            loc = loc,
        )
        buffer_state_update(t.current_states[:], index, &end_state_provider)
    }

    // The result is copied out and the scratch buffer cleared before the lock is
    // released, so the caller owns an independent slice and nothing aliases `t`.
    result := make([]Pending_Buffer_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

device_buffer_tracker_remove :: proc(t: ^Device_Buffer_Tracker, #any_int index: Tracker_Index) {
    sync.guard(&t.mtx)
    // Device tracker metadata is weak and does not own a reference.
    resource_metadata_remove(&t.metadata, index)
    // t.current_states[index] is left stale but unreachable, bit_vector_get
    // will report "not contained" for this index until it's reused, at which
    // point device_buffer_tracker_insert_single overwrites it fresh.
}

// -----------------------------------------------------------------------------
// Texture
// -----------------------------------------------------------------------------

// Similar to `Texture_Usages`, but for internal use.
Texture_Uses :: bit_set[Texture_Use;u32]
Texture_Use :: enum {
    // The texture is in unknown state.
    Uninitialized,
    // Ready to present image to the surface.
    Present,
    // The source of a hardware copy.
    Copy_Src,
    // The destination of a hardware copy.
    Copy_Dst,
    // Read-only sampled or fetched resource.
    Resource,
    // The color target of a renderpass.
    Color_Target,
    // Read-only depth usage.
    Depth_Read,
    // Read-write depth usage.
    Depth_Write,
    // Read-only stencil usage.
    Stencil_Read,
    // Read-write stencil usage.
    Stencil_Write,
    // Read-only storage texture usage. Corresponds to a UAV in d3d, so is
    // exclusive, despite being read only.
    Storage_Read_Only,
    // Write-only storage texture usage.
    Storage_Write_Only,
    // Read-write storage texture usage.
    Storage_Read_Write,
    // Image atomic enabled storage.
    Storage_Atomic,
    // Transient texture that may not have any backing memory. Not a resource
    // state stored in the trackers, only used for passing down usages to
    // `device_create_texture`.
    Transient,
    // Flag used for texture tracker to say a texture is in different states for
    // every sub-resource.
    Complex,
    // Flag used for texture tracker to say that the tracker does not know the
    // state of the sub-resource. This is different from `Uninitialized` as
    // that says the tracker does know, but the texture has not been
    // initialized.
    Unknown,
    // Flag used by texture tracker to say the read-only depth aspect of
    // texture is sampled.
    Depth_Sampled,
    // Flag used by texture tracker to say the read-only stencil aspect of
    // texture is sampled.
    Stencil_Sampled,
}

// The combination of states that a texture may be in _at the same time_.
TEXTURE_USES_INCLUSIVE :: Texture_Uses {
    .Copy_Src,
    .Resource,
    .Depth_Read,
    .Stencil_Read,
    .Storage_Read_Only,
}

// The combination of states that a texture must exclusively be in.
TEXTURE_USES_EXCLUSIVE :: Texture_Uses {
    .Copy_Dst,
    .Color_Target,
    .Storage_Write_Only,
    .Storage_Read_Write,
    .Storage_Atomic,
    .Present,
}

TEXTURE_USES_EMPTY :: Texture_Uses{}
TEXTURE_USES_UNKNOWN :: Texture_Uses{.Unknown}
TEXTURE_USES_UNINITIALIZED :: Texture_Uses{.Uninitialized}
TEXTURE_USES_COMPLEX :: Texture_Uses{.Complex}

// Turns the resource into a pile of bits.
texture_uses_bits :: #force_inline proc "contextless" (u: Texture_Uses) -> u32 {
    return transmute(u32)u
}

texture_uses_any_exclusive :: #force_inline proc "contextless" (u: Texture_Uses) -> bool {
    return (u & TEXTURE_USES_EXCLUSIVE) != {}
}

@(rodata)
VALID_DS_COMBINATIONS := [7]Texture_Uses {
    {.Depth_Write, .Stencil_Write},
    {.Depth_Write, .Stencil_Read},
    {.Stencil_Write, .Depth_Read},
    {.Depth_Write, .Resource, .Stencil_Read},
    {.Stencil_Write, .Resource, .Depth_Read},
    {.Depth_Write, .Resource, .Stencil_Read, .Stencil_Sampled},
    {.Stencil_Write, .Resource, .Depth_Read, .Depth_Sampled},
}

texture_uses_in_valid_ds :: proc(u: Texture_Uses) -> bool {
    for v in VALID_DS_COMBINATIONS {
        if u == v {
            return true
        }
    }
    return false
}

//  Check if this set mixes states in a way that the tracker cannot legally represent.
texture_uses_is_invalid :: #force_inline proc(u: Texture_Uses) -> bool {
    popcount := intr.count_ones(texture_uses_bits(u))
    if texture_uses_any_exclusive(u) && popcount != 1 {
        return true
    }
    ds := Texture_Uses{.Depth_Write, .Stencil_Write}
    if (u & ds) != {} && popcount != 1 && !texture_uses_in_valid_ds(u) {
        return true
    }
    return false
}

// Returns true if the transition from `old` to `new` does not require a barrier,
// ignoring which read-only aspect was sampled (`DEPTH_SAMPLED` /
// `STENCIL_SAMPLED`).
skip_barrier_ignore_texture_flags :: proc(
    old_state, ordered_uses_mask, new_state: Texture_Uses,
) -> bool {
    aspect_sampled := Texture_Uses{.Depth_Sampled, .Stencil_Sampled}
    return skip_barrier(
        old_state & ~aspect_sampled,
        ordered_uses_mask,
        new_state & ~aspect_sampled,
    )
}

// Range of texture subresources a pending transition touches.
//
// Convention is exclusive `[start, end)` on both axes, matching
// `Image_Subresource_Range`'s `base_*` + `*_count` pairs after they have been
// added together. Producers construct selectors directly in this form; there
// is deliberately no `{start, count}` -> `[start, end)` conversion step, since
// applying one to an already-exclusive selector silently widens the tracked
// range (a view of layers 2..3 would be tracked as 2..5).
Texture_Selector :: struct {
    mips:   Range(u32),
    layers: Range(u32),
}

MAX_MIP_LEVELS :: 32

// Represents the complex state of a texture where every subresource is
// potentially in a different state
Complex_Texture_State :: struct {
    mips:              [dynamic; MAX_MIP_LEVELS]Ranged_States(u32, Texture_Uses),
    mip_count:         int,
    mip_level_count:   u32,
    array_layer_count: u32,
}

// Creates complex texture state for the given sizes, initialized with the
// `Unknown` state: a special state which means the tracker knows nothing about
// those subresources.
complex_texture_state_init :: proc(
    c: ^Complex_Texture_State,
    mip_level_count, array_layer_count: u32,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(c != nil, loc = loc)
    assert(mip_level_count <= MAX_MIP_LEVELS, loc = loc)
    c^ = {} // reset memory
    c.mip_level_count = mip_level_count
    c.array_layer_count = array_layer_count
    resize(&c.mips, int(mip_level_count))
    for i in 0 ..< int(mip_level_count) {
        rs: Ranged_States(u32, Texture_Uses)
        ranged_states_init_from_range(
            &rs,
            Range(u32){0, array_layer_count},
            Texture_Uses{.Unknown},
            allocator,
        )
        c.mips[i] = rs
    }
}

complex_texture_state_uninit :: proc(c: ^Complex_Texture_State, loc := #caller_location) {
    assert(c != nil, loc = loc)
    for &m in c.mips {
        ranged_states_uninit(&m)
    }
    clear(&c.mips)
    c^ = {}
}

Selector_State_Iterator_Kind :: enum u8 {
    Once,
    Complex,
}

// An iterator over `(Texture_Selector, Texture_Uses)`.
Selector_State_Iterator :: struct {
    kind:          Selector_State_Iterator_Kind,
    once_selector: Texture_Selector,
    once_state:    Texture_Uses,
    once_done:     bool,
    complex:       ^Complex_Texture_State,
    mip_index:     int,
    entry_index:   int,
}

selector_state_iterator_once :: proc(
    selector: Texture_Selector,
    state: Texture_Uses,
) -> Selector_State_Iterator {
    return {kind = .Once, once_selector = selector, once_state = state}
}

selector_state_iterator_from_complex :: proc(
    complex: ^Complex_Texture_State,
) -> Selector_State_Iterator {
    return {kind = .Complex, complex = complex}
}

Selector_State_Iterator_Result :: struct {
    selector: Texture_Selector,
    state:    Texture_Uses,
}

selector_state_iterator_next :: proc(
    it: ^Selector_State_Iterator,
    loc := #caller_location,
) -> (
    res: Selector_State_Iterator_Result,
    cond: bool,
) {
    switch it.kind {
    case .Once:
        if it.once_done {
            return
        }
        it.once_done = true
        return {it.once_selector, it.once_state}, true
    case .Complex:
        ct := it.complex
        for it.mip_index < len(ct.mips) {
            mip := &ct.mips[it.mip_index]
            if it.entry_index < len(mip.ranges) {
                e := &mip.ranges[it.entry_index]
                it.entry_index += 1
                mip_id := u32(it.mip_index)
                res = {
                    selector = {
                        mips = Range(u32){mip_id, mip_id + 1},
                        layers = Range(u32){e.start, e.end},
                    },
                    state = e.value,
                }
                return res, true
            }
            it.mip_index += 1
            it.entry_index = 0
        }
        return
    }
    return
}

// Builds a complex state from a full-range selector and a stream of selectors that
// must all lie inside it.
complex_texture_state_from_selector_state_iterator :: proc(
    full_range: Texture_Selector,
    it: ^Selector_State_Iterator,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> Complex_Texture_State {
    assert(it != nil, loc = loc)
    assert(full_range.layers.start == 0, loc = loc)
    assert(full_range.mips.start == 0, loc = loc)
    complex: Complex_Texture_State
    complex_texture_state_init(
        &complex,
        full_range.mips.end - full_range.mips.start,
        full_range.layers.end - full_range.layers.start,
        allocator,
    )
    for res in selector_state_iterator_next(it) {
        assert(res.selector.layers.end <= full_range.layers.end)
        assert(res.selector.mips.end <= full_range.mips.end)
        // This should only ever happen with a bug; states cannot conflict here.
        assert(!texture_uses_is_invalid(res.state), loc = loc)
        for mip_id in res.selector.mips.start ..< res.selector.mips.end {
            mip := &complex.mips[cast(int)mip_id]
            isolated := ranged_states_isolate(
                mip,
                Range(u32){res.selector.layers.start, res.selector.layers.end},
                TEXTURE_USES_UNKNOWN,
            )
            for &entry in isolated {
                entry.value = res.state
            }
        }
    }
    return complex
}

// Flattens a complex state back into a stream of `(selector, state)` pairs.
complex_texture_state_to_selector_state_iterator :: proc(
    complex: ^Complex_Texture_State,
    loc := #caller_location,
) -> Selector_State_Iterator {
    assert(complex != nil, loc = loc)
    return selector_state_iterator_from_complex(complex)
}

// Deep clone: the result owns its own backings and can be mutated and freed
// independently from the source.
complex_texture_state_clone :: proc(
    complex: ^Complex_Texture_State,
    complex_out: ^Complex_Texture_State,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(complex != nil, loc = loc)
    assert(complex_out != nil, loc = loc)
    assert(complex != complex_out, "clone source and destination must differ", loc = loc)

    complex_out^ = {}
    complex_out.mip_level_count = complex.mip_level_count
    complex_out.array_layer_count = complex.array_layer_count

    resize(&complex_out.mips, len(complex.mips))
    for &mip, i in complex.mips {
        ranged_states_clone(&mip, &complex_out.mips[i], allocator)
    }
}

// A single texture state or a reference to the complex state stored for that
// subresource set. Used for reads.
//
// `complex` points into the owning `Texture_State_Set`, so this type is only valid
// while that set is not being mutated. It is fine inside the tracker (barrier
// computation runs under no lock but on a single-owner command-buffer tracker) and
// wrong to return from a device tracker, which is shared: see
// `Device_Texture_State` for the form that is safe to hand across a lock.
Single_Or_Many :: struct {
    is_single: bool,
    state:     Texture_Uses,
    complex:   ^Complex_Texture_State,
    iter:      Selector_State_Iterator,
}

// A texture's tracked state as reported by a device tracker, resolved to a value
// with no reference into the tracker's own storage.
//
// `Device_Texture_Tracker` is shared by every thread touching a texture, and a
// `Texture_State_Set`'s complex states live in a map, so a pointer handed back to a
// caller could be invalidated by another thread inserting a subresource state or
// growing the set. The tracker keeps all of its complex logic; this type only
// carries what is safe to leave the lock with.
Device_Texture_State :: struct {
    // False when the texture's subresources are in divergent states, in which case
    // the caller must resolve per-subresource rather than assume one layout.
    is_single: bool,
    // Only meaningful when `is_single`.
    state:     Texture_Uses,
}

// A single texture state or a reference to the complex state stored for that
// subresource set. Used for in-place mutation.
Single_Or_Many_Ref :: struct {
    is_single: bool,
    single:    ^Texture_Uses,
    complex:   ^Complex_Texture_State,
}

// Container for the corresponding simple and complex texture states.
Texture_State_Set :: struct {
    simple:    [dynamic]Texture_Uses,
    complex:   map[int]Complex_Texture_State,
    allocator: runtime.Allocator,
}

texture_state_set_init :: proc(
    set: ^Texture_State_Set,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    set^ = {} // reset memory
    set.simple.allocator = allocator
    set.complex.allocator = allocator
    set.allocator = allocator
}

// Releases every complex state plus the simple table.
texture_state_set_uninit :: proc(set: ^Texture_State_Set, loc := #caller_location) {
    assert(set != nil, loc = loc)
    for _, &ct in set.complex {
        complex_texture_state_uninit(&ct, loc)
    }
    delete(set.complex)
    delete(set.simple)
    set^ = {} // reset memory
}

texture_state_set_clear :: proc(set: ^Texture_State_Set, loc := #caller_location) {
    assert(set != nil, loc = loc)

    // Free the complex states' inner backings before dropping the map
    // entries that reference them.
    for _, &ct in set.complex {
        complex_texture_state_uninit(&ct, loc)
    }

    clear(&set.simple)
    clear(&set.complex)
}

// Grows the simple table padding the new slots with UNINITIALIZED.
texture_state_set_resize :: proc(set: ^Texture_State_Set, size: int, loc := #caller_location) {
    assert(set != nil, loc = loc)
    old_len := len(set.simple)
    resize(&set.simple, size)
    for i in old_len ..< size {
        set.simple[i] = TEXTURE_USES_UNINITIALIZED
    }
}

texture_state_set_len :: proc(set: ^Texture_State_Set, loc := #caller_location) -> int {
    assert(set != nil, loc = loc)
    return len(set.simple)
}

texture_state_set_assert_in_bounds :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    assert(index < len(set.simple), loc = loc)
}

texture_state_set_get_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    loc := #caller_location,
) -> Single_Or_Many {
    assert(set != nil, loc = loc)
    assert(index >= 0 && index < len(set.simple), loc = loc)
    simple := set.simple[index]
    if simple == TEXTURE_USES_COMPLEX {
        complex, ok := &set.complex[index]
        assert(
            ok,
            "tracker invariant violated: " + "simple says complex but complex map has no entry",
            loc = loc,
        )
        return {is_single = false, complex = complex}
    }
    return {is_single = true, state = simple}
}

texture_state_set_get_mut_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    loc := #caller_location,
) -> Single_Or_Many_Ref {
    assert(set != nil, loc = loc)
    assert(index >= 0 && index < len(set.simple), loc = loc)
    simple := set.simple[index]
    if simple == TEXTURE_USES_COMPLEX {
        complex, ok := &set.complex[index]
        assert(
            ok,
            "tracker invariant violated: " + "simple says complex but complex map has no entry",
            loc = loc,
        )
        return {is_single = false, complex = complex}
    }
    return {is_single = true, single = &set.simple[index]}
}

texture_state_set_insert_simple_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    state: Texture_Uses,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    set.simple[index] = state
}

texture_state_set_insert_complex_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    complex: Complex_Texture_State,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    set.simple[index] = TEXTURE_USES_COMPLEX
    set.complex[index] = complex
}

texture_state_set_make_simple_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    state: Texture_Uses,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    set.simple[index] = state
    if ct, ok := set.complex[index]; ok {
        complex_texture_state_uninit(&ct)
    }
    delete_key(&set.complex, index)
}

texture_state_set_make_complex_unchecked :: proc(
    set: ^Texture_State_Set,
    #any_int index: int,
    complex: Complex_Texture_State,
    loc := #caller_location,
) {
    assert(set != nil, loc = loc)
    set.simple[index] = TEXTURE_USES_COMPLEX
    set.complex[index] = complex
}

Texture_State_Provider_Kind :: enum u8 {
    Known_Single,
    Selector,
    Texture_Set,
}

// A source of texture state.
Texture_State_Provider :: struct {
    kind:     Texture_State_Provider_Kind,
    state:    Texture_Uses,
    selector: Texture_Selector,
    set:      ^Texture_State_Set,
}

usage_error_texture :: proc(
    texture: Texture,
    selector: Texture_Selector,
    current_state, new_state: Texture_Uses,
) -> Usage_Error {
    return Usage_Error(
        Texture_Usage_Error {
            texture = texture,
            mip_levels = selector.mips,
            array_layers = selector.layers,
            current_state = current_state,
            new_state = new_state,
        },
    )
}

// Convenience constructor turning a `Texture_Selector` (zero means "whole
// texture") into this enum.
//
// `selector` is already in the tracker's exclusive `[start, end)` convention.
// Selectors reaching the tracker are built as such by every producer: view
// creation (`vk_texture_create_view`), the queue-write path
// (`vk_queue_write_texture`), and error reporting. It must be stored verbatim.
texture_state_provider_from_option :: proc(
    selector: Texture_Selector,
    state: Texture_Uses,
    loc := #caller_location,
) -> Texture_State_Provider {
    if selector != {} {
        return {kind = .Selector, selector = selector, state = state}
    }
    return {kind = .Known_Single, state = state}
}

texture_state_provider_known_single :: proc(state: Texture_Uses) -> Texture_State_Provider {
    return {kind = .Known_Single, state = state}
}

// Wraps an explicit `Texture_Selector`.
//
// `selector` is already in the tracker's exclusive `[start, end)` convention
// and must be stored verbatim. See `texture_state_provider_from_option`.
texture_state_provider_selector :: proc(
    selector: Texture_Selector,
    state: Texture_Uses,
) -> Texture_State_Provider {
    return {kind = .Selector, selector = selector, state = state}
}

texture_state_provider_texture_set :: proc(set: ^Texture_State_Set) -> Texture_State_Provider {
    return {kind = .Texture_Set, set = set}
}

// Gets the state provided for a resource id.
//
// A selector that exactly matches the texture's full range is promoted to a
// simple state; any smaller selector is demoted to a selector iterator.
texture_state_provider_get_state :: proc(
    p: ^Texture_State_Provider,
    texture_selector: Texture_Selector,
    #any_int index: int,
    loc := #caller_location,
) -> Single_Or_Many {
    assert(p != nil, loc = loc)
    switch p.kind {
    case .Known_Single:
        return {is_single = true, state = p.state}
    case .Selector:
        assert(texture_selector != {}, loc = loc)
        if texture_selector == p.selector {
            return {is_single = true, state = p.state}
        }
        return {is_single = false, iter = selector_state_iterator_once(p.selector, p.state)}
    case .Texture_Set:
        cur := texture_state_set_get_unchecked(p.set, index, loc)
        if cur.is_single {
            return {is_single = true, state = cur.state}
        }
        return {
            is_single = false,
            iter = complex_texture_state_to_selector_state_iterator(cur.complex, loc),
        }
    }
    return {}
}

// Records the start and end states for a single resource index into the
// provided tracker sets.
texture_state_insert :: proc(
    texture_selector: Texture_Selector,
    start_state_set: ^Texture_State_Set, // optional
    end_state_set: ^Texture_State_Set, // required
    resource_metadata: ^Resource_Metadata(Texture),
    #any_int index: int,
    start_state_provider: ^Texture_State_Provider,
    end_state_provider: ^Texture_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Texture),
    retain_resource := true,
    loc := #caller_location,
) {
    assert(end_state_set != nil, loc = loc)
    assert(resource_metadata != nil, loc = loc)
    assert(start_state_provider != nil, loc = loc)
    assert(metadata_provider != nil, loc = loc)

    texture_state_set_assert_in_bounds(end_state_set, index, loc)
    if start_state_set != nil {
        texture_state_set_assert_in_bounds(start_state_set, index, loc)
        // The complex state is built once and then cloned into the start set,
        // so both sets must agree on the allocator.
        assert(
            start_state_set.allocator == end_state_set.allocator,
            "start and end state sets must share an allocator",
            loc = loc,
        )
    }

    allocator := end_state_set.allocator

    // Start state
    start := texture_state_provider_get_state(start_state_provider, texture_selector, index, loc)

    if start.is_single {
        state := start.state
        assert(!texture_uses_is_invalid(state), "resource state cannot be invalid", loc)

        if start_state_set != nil {
            texture_state_set_insert_simple_unchecked(start_state_set, index, state, loc)
        }
        if end_state_provider == nil {
            texture_state_set_insert_simple_unchecked(end_state_set, index, state, loc)
        }
    } else {
        assert(texture_selector != {}, "complex start requires a full-range selector", loc = loc)

        ct := complex_texture_state_from_selector_state_iterator(
            texture_selector,
            &start.iter,
            allocator,
            loc,
        )

        if start_state_set != nil {
            complex_out: Complex_Texture_State
            complex_texture_state_clone(&ct, &complex_out, allocator, loc)
            texture_state_set_insert_complex_unchecked(start_state_set, index, complex_out, loc)
        }

        // If there is no end state provider we move the freshly built state
        // into the end set; otherwise the state is not consumed by anyone and
        // must be released here.
        if end_state_provider == nil {
            texture_state_set_insert_complex_unchecked(end_state_set, index, ct, loc)
        } else {
            complex_texture_state_uninit(&ct, loc)
        }
    }

    // End state (only when a provider is supplied)
    if end_state_provider != nil {
        end := texture_state_provider_get_state(end_state_provider, texture_selector, index, loc)

        if end.is_single {
            state := end.state
            assert(!texture_uses_is_invalid(state), "resource state cannot be invalid", loc)

            // A start state provider is guaranteed to exist, so the start
            // set has already been handled above; the end set is the only
            // destination we still need to write.
            texture_state_set_insert_simple_unchecked(end_state_set, index, state, loc)
        } else {
            assert(texture_selector != {}, "complex end requires a full-range selector", loc = loc)

            ct := complex_texture_state_from_selector_state_iterator(
                texture_selector,
                &end.iter,
                allocator,
                loc,
            )
            texture_state_set_insert_complex_unchecked(end_state_set, index, ct, loc)
        }
    }

    // Metadata
    resource := resource_metadata_provider_get(metadata_provider, index)
    // Strong command/usage trackers retain on first insertion. The device
    // tracker passes `retain_resource = false` and stores weak metadata.
    if retain_resource && !resource_metadata_contains(resource_metadata, index) {
        resource_retain_texture(resource, loc)
    }
    resource_metadata_insert(resource_metadata, index, resource)
}

texture_state_merge :: proc(
    texture_selector: Texture_Selector,
    current_state_set: ^Texture_State_Set,
    #any_int index: int,
    state_provider: ^Texture_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Texture),
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(current_state_set != nil, loc = loc)
    assert(state_provider != nil, loc = loc)
    assert(metadata_provider != nil, loc = loc)

    allocator := current_state_set.allocator

    current := texture_state_set_get_mut_unchecked(current_state_set, index, loc)
    new_state := texture_state_provider_get_state(state_provider, texture_selector, index, loc)

    if current.is_single && new_state.is_single {
        merged := current.single^ | new_state.state
        if texture_uses_is_invalid(merged) {
            resource := resource_metadata_provider_get(metadata_provider, index)
            return usage_error_texture(
                resource,
                texture_selector,
                current.single^,
                new_state.state,
            )
        }
        current.single^ = merged
        return nil
    }

    if current.is_single && !new_state.is_single {
        cur_state := current.single^
        // We are now demoting this simple state to a complex state, so we need
        // a whole new complex state as there wasn't one before.
        once := selector_state_iterator_once(texture_selector, cur_state)
        new_complex := complex_texture_state_from_selector_state_iterator(
            texture_selector,
            &once,
            allocator,
            loc,
        )

        for sel in selector_state_iterator_next(&new_state.iter) {
            merged := cur_state | sel.state
            if texture_uses_is_invalid(merged) {
                complex_texture_state_uninit(&new_complex, loc)
                resource := resource_metadata_provider_get(metadata_provider, index)
                return usage_error_texture(resource, sel.selector, cur_state, sel.state)
            }
            for mip_id in sel.selector.mips.start ..< sel.selector.mips.end {
                mip := &new_complex.mips[cast(int)mip_id]
                isolated := ranged_states_isolate(
                    mip,
                    Range(u32){sel.selector.layers.start, sel.selector.layers.end},
                    TEXTURE_USES_UNKNOWN,
                )
                for &entry in isolated {
                    entry.value = merged
                }
                ranged_states_coalesce(mip)
            }
        }
        texture_state_set_make_complex_unchecked(current_state_set, index, new_complex)
        return
    }

    if !current.is_single && new_state.is_single {
        for mip_id in 0 ..< len(current.complex.mips) {
            mip := &current.complex.mips[mip_id]
            for &entry in mip.ranges[:] {
                merged := entry.value | new_state.state
                // Once we remove unknown this will never be empty, as simple
                // states are never unknown.
                merged = merged & ~TEXTURE_USES_UNKNOWN
                if texture_uses_is_invalid(merged) {
                    resource := resource_metadata_provider_get(metadata_provider, index)
                    mip_id_32 := u32(mip_id)
                    return usage_error_texture(
                        resource,
                        Texture_Selector {
                            mips = Range(u32){mip_id_32, mip_id_32 + 1},
                            layers = Range(u32){entry.start, entry.end},
                        },
                        entry.value,
                        new_state.state,
                    )
                }
                entry.value = merged
            }
            ranged_states_coalesce(mip)
        }
        return
    }

    // many x many
    for sel in selector_state_iterator_next(&new_state.iter) {
        for mip_id in sel.selector.mips.start ..< sel.selector.mips.end {
            assert(cast(int)mip_id < len(current.complex.mips))
            mip := &current.complex.mips[cast(int)mip_id]
            isolated := ranged_states_isolate(
                mip,
                Range(u32){sel.selector.layers.start, sel.selector.layers.end},
                TEXTURE_USES_UNKNOWN,
            )
            for &entry in isolated {
                merged := entry.value | sel.state
                merged = merged & ~TEXTURE_USES_UNKNOWN
                if merged == TEXTURE_USES_EMPTY {
                    // We know nothing about this state; just move on.
                    continue
                }
                if texture_uses_is_invalid(merged) {
                    resource := resource_metadata_provider_get(metadata_provider, index)
                    return usage_error_texture(
                        resource,
                        Texture_Selector {
                            mips = Range(u32){mip_id, mip_id + 1},
                            layers = Range(u32){entry.start, entry.end},
                        },
                        entry.value,
                        sel.state,
                    )
                }
                entry.value = merged
            }
            ranged_states_coalesce(mip)
        }
    }

    return
}

texture_state_barrier :: proc(
    texture_selector: Texture_Selector,
    current_state_set: ^Texture_State_Set,
    #any_int index: int,
    state_provider: ^Texture_State_Provider,
    barriers: ^[dynamic]Pending_Texture_Transition,
    ordered_uses_mask: Texture_Uses,
    loc := #caller_location,
) {
    assert(current_state_set != nil, loc = loc)
    assert(state_provider != nil, loc = loc)
    assert(barriers != nil, loc = loc)

    current := texture_state_set_get_unchecked(current_state_set, index)
    new_state := texture_state_provider_get_state(state_provider, texture_selector, index)

    if current.is_single && new_state.is_single {
        if skip_barrier_ignore_texture_flags(current.state, ordered_uses_mask, new_state.state) {
            return
        }
        append(
            barriers,
            Pending_Texture_Transition {
                id = u32(index),
                selector = texture_selector,
                usage = {from = current.state, to = new_state.state},
            },
        )
        return
    }

    if current.is_single && !new_state.is_single {
        for sel in selector_state_iterator_next(&new_state.iter) {
            if sel.state == TEXTURE_USES_UNKNOWN {
                continue
            }
            if skip_barrier_ignore_texture_flags(current.state, ordered_uses_mask, sel.state) {
                continue
            }
            append(
                barriers,
                Pending_Texture_Transition {
                    id = u32(index),
                    selector = sel.selector,
                    usage = {from = current.state, to = sel.state},
                },
            )
        }
        return
    }

    if !current.is_single && new_state.is_single {
        for mip_id in 0 ..< len(current.complex.mips) {
            mip := &current.complex.mips[mip_id]
            for &entry in mip.ranges[:] {
                if entry.value == TEXTURE_USES_UNKNOWN {
                    continue
                }
                if skip_barrier_ignore_texture_flags(
                    entry.value,
                    ordered_uses_mask,
                    new_state.state,
                ) {
                    continue
                }
                mip_id_32 := u32(mip_id)
                append(
                    barriers,
                    Pending_Texture_Transition {
                        id = u32(index),
                        selector = {
                            mips = Range(u32){mip_id_32, mip_id_32 + 1},
                            layers = Range(u32){entry.start, entry.end},
                        },
                        usage = {from = entry.value, to = new_state.state},
                    },
                )
            }
        }
        return
    }

    // many x many
    for sel in selector_state_iterator_next(&new_state.iter) {
        for mip_id in sel.selector.mips.start ..< sel.selector.mips.end {
            assert(cast(int)mip_id < len(current.complex.mips))
            mip := &current.complex.mips[cast(int)mip_id]
            fit := ranged_filter_iterator(mip, sel.selector.layers.start, sel.selector.layers.end)
            for res in ranged_filter_iterator_next(&fit) {
                if res.value^ == TEXTURE_USES_UNKNOWN || sel.state == TEXTURE_USES_UNKNOWN {
                    continue
                }
                if skip_barrier_ignore_texture_flags(res.value^, ordered_uses_mask, sel.state) {
                    continue
                }
                append(
                    barriers,
                    Pending_Texture_Transition {
                        id = u32(index),
                        selector = {
                            mips = Range(u32){mip_id, mip_id + 1},
                            layers = Range(u32){res.start, res.end},
                        },
                        usage = State_Transition(Texture_Uses){from = res.value^, to = sel.state},
                    },
                )
            }
        }
    }
}

texture_state_update :: proc(
    texture_selector: Texture_Selector,
    start_state_set: ^Texture_State_Set,
    current_state_set: ^Texture_State_Set,
    #any_int index: int,
    state_provider: ^Texture_State_Provider,
    loc := #caller_location,
) {
    // assert(start_state_set != nil, loc = loc)
    assert(current_state_set != nil, loc = loc)
    assert(state_provider != nil, loc = loc)

    // We only ever need to update the start state here if the state is complex.
    // If the state is simple, the first insert to the tracker covers it.
    start_complex: ^Complex_Texture_State
    if start_state_set != nil {
        start_ref := texture_state_set_get_mut_unchecked(start_state_set, index)
        if !start_ref.is_single {
            start_complex = start_ref.complex
        }
    }

    current := texture_state_set_get_mut_unchecked(current_state_set, index)
    new_state := texture_state_provider_get_state(state_provider, texture_selector, index)

    if current.is_single && new_state.is_single {
        current.single^ = new_state.state
        return
    }

    if current.is_single && !new_state.is_single {
        current_simple := current.single^
        // We are now demoting this simple state to a complex state, so we need
        // a whole new complex state as there wasn't one before.
        once := selector_state_iterator_once(texture_selector, current_simple)
        new_complex := complex_texture_state_from_selector_state_iterator(
            texture_selector,
            &once,
            current_state_set.allocator,
        )
        for sel in selector_state_iterator_next(&new_state.iter) {
            ns := sel.state
            if sel.state == TEXTURE_USES_UNKNOWN {
                ns = current_simple
            }
            for mip_id in sel.selector.mips.start ..< sel.selector.mips.end {
                mip := &new_complex.mips[cast(int)mip_id]
                isolated := ranged_states_isolate(
                    mip,
                    Range(u32){sel.selector.layers.start, sel.selector.layers.end},
                    TEXTURE_USES_UNKNOWN,
                )
                for &entry in isolated {
                    entry.value = ns
                }
                ranged_states_coalesce(mip)
            }
        }
        texture_state_set_make_complex_unchecked(current_state_set, index, new_complex)
        return
    }

    if !current.is_single && new_state.is_single {
        for mip_id in 0 ..< len(current.complex.mips) {
            mip := &current.complex.mips[mip_id]
            for &entry in mip.ranges[:] {
                // If this state is unknown, the start is _also_ unknown.
                if entry.value == TEXTURE_USES_UNKNOWN {
                    if start_complex != nil {
                        assert(mip_id < len(start_complex.mips))
                        start_mip := &start_complex.mips[mip_id]
                        iso := ranged_states_isolate(
                            start_mip,
                            Range(u32){entry.start, entry.end},
                            TEXTURE_USES_UNKNOWN,
                        )
                        for &se in iso {
                            assert(se.value == TEXTURE_USES_UNKNOWN)
                            se.value = new_state.state
                        }
                        ranged_states_coalesce(start_mip)
                    }
                }
            }
        }
        texture_state_set_make_simple_unchecked(current_state_set, index, new_state.state)
        return
    }

    // many x many
    for sel in selector_state_iterator_next(&new_state.iter) {
        if sel.state == TEXTURE_USES_UNKNOWN {
            // We know nothing new.
            continue
        }
        for mip_id in sel.selector.mips.start ..< sel.selector.mips.end {
            mip_id_int := cast(int)mip_id
            assert(mip_id_int < len(current.complex.mips))
            mip := &current.complex.mips[mip_id_int]
            isolated := ranged_states_isolate(
                mip,
                Range(u32){sel.selector.layers.start, sel.selector.layers.end},
                TEXTURE_USES_UNKNOWN,
            )
            for &entry in isolated {
                if entry.value == TEXTURE_USES_UNKNOWN && sel.state != TEXTURE_USES_UNKNOWN {
                    // We now know something about this subresource that we
                    // didn't before, so we go back and update the start state.
                    assert(start_complex != nil)
                    assert(mip_id_int < len(start_complex.mips))
                    start_mip := &start_complex.mips[mip_id_int]
                    iso_start := ranged_states_isolate(
                        start_mip,
                        Range(u32){entry.start, entry.end},
                        TEXTURE_USES_UNKNOWN,
                    )
                    for &se in iso_start {
                        assert(se.value == TEXTURE_USES_UNKNOWN)
                        se.value = sel.state
                    }
                    ranged_states_coalesce(start_mip)
                }
                entry.value = sel.state
            }
            ranged_states_coalesce(mip)
        }
    }
}

// Does an insertion operation if the index isn't tracked in the given
// metadata, otherwise merges the given state with the current state. If the
// merging would cause a conflict, returns that usage conflict.
texture_insert_or_merge :: proc(
    texture_selector: Texture_Selector,
    current_state_set: ^Texture_State_Set,
    resource_metadata: ^Resource_Metadata(Texture),
    #any_int index: int,
    state_provider: ^Texture_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Texture),
) -> (
    err: Usage_Error,
) {
    currently_owned := resource_metadata_contains_unchecked(resource_metadata, index)
    if !currently_owned {
        texture_state_insert(
            texture_selector,
            nil,
            current_state_set,
            resource_metadata,
            index,
            state_provider,
            nil,
            metadata_provider,
        )
        return
    }
    return texture_state_merge(
        texture_selector,
        current_state_set,
        index,
        state_provider,
        metadata_provider,
    )
}

// If the resource isn't tracked:
//
//   - inserts it;
//   - uses `start_state_provider` to populate `start_states`;
//   - uses either `end_state_provider` or `start_state_provider` for
//     `current_states`.
//
// If the resource is tracked:
//
//   - inserts barriers from the state in `current_states` to the state provided by
//     `start_state_provider`;
//   - updates `current_states` with either the state from `end_state_provider` or
//     `start_state_provider`.
//
// Any barriers are added to the barrier vector.
texture_insert_or_barrier_update :: proc(
    texture_selector: Texture_Selector,
    start_state: ^Texture_State_Set,
    current_state_set: ^Texture_State_Set,
    resource_metadata: ^Resource_Metadata(Texture),
    #any_int index: int,
    start_state_provider: ^Texture_State_Provider,
    end_state_provider: ^Texture_State_Provider,
    metadata_provider: ^Resource_Metadata_Provider(Texture),
    barriers: ^[dynamic]Pending_Texture_Transition,
    ordered_uses_mask: Texture_Uses,
    loc := #caller_location,
) {
    assert(start_state != nil, loc = loc)
    assert(current_state_set != nil, loc = loc)
    assert(start_state_provider != nil, loc = loc)
    assert(metadata_provider != nil, loc = loc)
    assert(barriers != nil, loc = loc)

    currently_owned := resource_metadata_contains_unchecked(resource_metadata, index)
    if !currently_owned {
        texture_state_insert(
            texture_selector,
            start_state,
            current_state_set,
            resource_metadata,
            index,
            start_state_provider,
            end_state_provider,
            metadata_provider,
        )
        return
    }

    update_state_provider := end_state_provider
    if update_state_provider == nil {
        update_state_provider = start_state_provider
    }
    texture_state_barrier(
        texture_selector,
        current_state_set,
        index,
        start_state_provider,
        barriers,
        ordered_uses_mask,
    )
    texture_state_update(
        texture_selector,
        start_state,
        current_state_set,
        index,
        update_state_provider,
    )
}

Texture_View_Bind_Group_Entry :: struct {
    // `Tracker_Index` of the view's *parent* texture, captured at insert time.
    // This is the key merges address state by, so it is also the key the bind
    // group has to be sorted by; see `texture_view_bind_group_state_optimize`.
    index: Tracker_Index,
    view:  Texture_View,
    usage: Texture_Uses,
}

// Stores a bind group's texture views and their usages within the bind group.
Texture_View_Bind_Group_State :: struct {
    views: [dynamic]Texture_View_Bind_Group_Entry,
}

texture_view_bind_group_state_init :: proc(
    t: ^Texture_View_Bind_Group_State,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    t.views.allocator = allocator
}

texture_view_bind_group_state_clear :: proc(
    t: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    for entry in t.views {
        bind_group_release_texture_view(entry.view, loc)
    }
    clear(&t.views)
}

texture_view_bind_group_state_uninit :: proc(
    t: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    texture_view_bind_group_state_clear(t, loc)
    delete(t.views)
    t^ = {} // reset memory
}

texture_view_bind_group_state_insert_single :: proc(
    s: ^Texture_View_Bind_Group_State,
    #any_int index: Tracker_Index,
    view: Texture_View,
    state: Texture_Uses,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    bind_group_retain_texture_view(view, loc)
    append(&s.views, Texture_View_Bind_Group_Entry{index, view, state})
}

// Sorts by parent-texture tracker index, so merging this bind group into a
// tracker later walks memory in ascending order.
texture_view_bind_group_state_optimize :: proc(
    t: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    slice.sort_by(t.views[:], proc(a, b: Texture_View_Bind_Group_Entry) -> bool {
        return a.index < b.index
    })
}

// Iterator over the parent textures of the tracked views. May yield duplicates.
Texture_Viewed_Textures_Iterator :: struct {
    state: ^Texture_View_Bind_Group_State,
    pos:   int,
}

texture_view_bind_group_state_used_textures :: proc(
    s: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) -> Texture_Viewed_Textures_Iterator {
    assert(s != nil, loc = loc)
    return Texture_Viewed_Textures_Iterator{state = s}
}

texture_viewed_textures_next :: proc(
    it: ^Texture_Viewed_Textures_Iterator,
    loc := #caller_location,
) -> (
    res: Texture,
    cond: bool,
) {
    assert(it != nil, loc = loc)
    if it.pos >= len(it.state.views) {
        return {}, false
    }
    entry := &it.state.views[it.pos]
    it.pos += 1
    view_impl := texture_view_get_public_impl(entry.view, loc)
    return view_impl.texture, true
}

// Stores all texture state within a single usage scope.
Texture_Usage_Scope :: struct {
    set:               Texture_State_Set,
    metadata:          Resource_Metadata(Texture),
    ordered_uses_mask: Texture_Uses,
}

texture_usage_scope_init :: proc(
    s: ^Texture_Usage_Scope,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    s^ = {} // reset memory
    texture_state_set_init(&s.set, allocator)
    resource_metadata_init(&s.metadata, 0, allocator)
}

texture_usage_scope_uninit :: proc(s: ^Texture_Usage_Scope, loc := #caller_location) {
    assert(s != nil, loc = loc)
    texture_state_set_uninit(&s.set)
    texture_metadata_release_all(&s.metadata, loc)
    resource_metadata_uninit(&s.metadata)
    s^ = {}
}

texture_usage_scope_assert_in_bounds :: proc(
    scope: ^Texture_Usage_Scope,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(scope != nil, loc = loc)
    resource_metadata_assert_in_bounds(&scope.metadata, index, loc)
    texture_state_set_assert_in_bounds(&scope.set, index, loc)
}

texture_usage_scope_clear :: proc(scope: ^Texture_Usage_Scope, loc := #caller_location) {
    assert(scope != nil, loc = loc)
    texture_state_set_clear(&scope.set, loc)
    texture_metadata_release_all(&scope.metadata, loc)
}

// Sets the size of all the vectors inside the tracker.
texture_usage_scope_set_size :: proc(s: ^Texture_Usage_Scope, size: int, loc := #caller_location) {
    assert(s != nil, loc = loc)
    texture_state_set_resize(&s.set, size)
    resource_metadata_set_size(&s.metadata, size, loc)
}

texture_usage_scope_set_ordered_uses_mask :: proc(
    s: ^Texture_Usage_Scope,
    mask: Texture_Uses,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    s.ordered_uses_mask = mask
}

texture_usage_scope_allow_index :: proc(
    s: ^Texture_Usage_Scope,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(s != nil, loc = loc)
    if index >= len(s.set.simple) {
        texture_usage_scope_set_size(s, index + 1, loc)
    }
}

// Returns true if the tracker owns no resources. O(n) operation.
texture_usage_scope_is_empty :: proc(s: ^Texture_Usage_Scope, loc := #caller_location) -> bool {
    assert(s != nil, loc = loc)
    return resource_metadata_is_empty(&s.metadata)
}

// Merges the texture states in the given usage scope into this one. If any of
// the resulting states is invalid, stops and returns a usage conflict.
texture_usage_scope_merge_usage_scope :: proc(
    s: ^Texture_Usage_Scope,
    other: ^Texture_Usage_Scope,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(s != nil, loc = loc)
    assert(other != nil, loc = loc)

    incoming_size := texture_state_set_len(&other.set)
    if incoming_size > texture_state_set_len(&s.set) {
        texture_usage_scope_set_size(s, incoming_size, loc)
    }

    state_provider := texture_state_provider_texture_set(&other.set)
    metadata_provider := resource_metadata_provider_indirect(&other.metadata)

    it := resource_metadata_indices(&other.metadata)
    for index in bit_vector_iterator_next(&it) {
        texture_usage_scope_assert_in_bounds(s, index, loc)
        texture_usage_scope_assert_in_bounds(other, index, loc)

        tex := resource_metadata_get_unchecked(&other.metadata, index)
        texture_impl := texture_get_public_impl(tex, loc)
        e := texture_insert_or_merge(
            texture_impl.full_range,
            &s.set,
            &s.metadata,
            index,
            &state_provider,
            &metadata_provider,
        )
        if e != nil {
            return e
        }
    }
    return nil
}

// Merges a single state into the usage scope. If the resulting state is
// invalid, returns a usage conflict.
texture_usage_scope_merge_single :: proc(
    s: ^Texture_Usage_Scope,
    texture: Texture,
    selector: Texture_Selector,
    new_state: Texture_Uses,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    texture_impl := texture_get_public_impl(texture, loc)
    index := texture_impl.tracker_index
    texture_usage_scope_allow_index(s, index, loc)
    texture_usage_scope_assert_in_bounds(s, index, loc)
    state_provider := texture_state_provider_from_option(selector, new_state)
    metadata_provider := resource_metadata_provider_direct(texture)
    return texture_insert_or_merge(
        texture_impl.full_range,
        &s.set,
        &s.metadata,
        index,
        &state_provider,
        &metadata_provider,
    )
}

// Merges the texture states in the given bind group into this usage scope.
// Bind groups are not checked for conflicts between their own entries, so
// this may return an error on the first bind group bound.
texture_usage_scope_merge_bind_group :: proc(
    s: ^Texture_Usage_Scope,
    bind_group: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(s != nil, loc = loc)
    for i in 0 ..< len(bind_group.views) {
        entry := &bind_group.views[i]
        view_impl := texture_view_get_public_impl(entry.view, loc)
        e := texture_usage_scope_merge_single(
            s,
            view_impl.texture,
            view_impl.selector,
            entry.usage,
            loc,
        )
        if e != nil {
            return e
        }
    }
    return nil
}

// Encodes a single texture transition once `pending_transition_texture` has
// turned it into a backend barrier.
Texture_Barrier :: struct {
    texture:  Texture,
    selector: Texture_Selector,
    usage:    State_Transition(Texture_Uses),
}

// A pending texture state transition.
Pending_Texture_Transition :: Pending_Transition(Texture_Uses, Texture_Selector)

// Produce the backend barrier corresponding to the transition.
pending_transition_texture :: proc(
    pending: Pending_Texture_Transition,
    texture: Texture,
    loc := #caller_location,
) -> Texture_Barrier {
    // These showing up in a barrier is always a bug.
    assert(pending.usage.from != TEXTURE_USES_UNKNOWN, loc = loc)
    assert(pending.usage.to != TEXTURE_USES_UNKNOWN, loc = loc)
    assert(pending.selector.mips.end - pending.selector.mips.start != 0, loc = loc)
    assert(pending.selector.layers.end - pending.selector.layers.start != 0, loc = loc)
    return Texture_Barrier{texture = texture, selector = pending.selector, usage = pending.usage}
}

// Stores all texture state within a command buffer.
Texture_Tracker :: struct {
    start_set:         Texture_State_Set,
    end_set:           Texture_State_Set,
    metadata:          Resource_Metadata(Texture),
    temp:              [dynamic]Pending_Texture_Transition,
    ordered_uses_mask: Texture_Uses,
}

texture_tracker_init :: proc(
    t: ^Texture_Tracker,
    ordered_uses_mask: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    texture_state_set_init(&t.start_set, allocator)
    texture_state_set_init(&t.end_set, allocator)
    resource_metadata_init(&t.metadata, 0, allocator)
    t.temp.allocator = allocator
    t.ordered_uses_mask = ordered_uses_mask
}

texture_tracker_uninit :: proc(t: ^Texture_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    texture_state_set_uninit(&t.start_set)
    texture_state_set_uninit(&t.end_set)
    texture_metadata_release_all(&t.metadata, loc)
    resource_metadata_uninit(&t.metadata)
    delete(t.temp)
    t^ = {} // reset memory
}

texture_tracker_clear :: proc(t: ^Texture_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    texture_state_set_clear(&t.start_set)
    texture_state_set_clear(&t.end_set)
    texture_metadata_release_all(&t.metadata, loc)
    clear(&t.temp)
}

texture_tracker_assert_in_bounds :: proc(
    t: ^Texture_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(index < len(t.start_set.simple), loc = loc)
    assert(index < len(t.end_set.simple), loc = loc)
    resource_metadata_assert_in_bounds(&t.metadata, index, loc)
}

// Sets the size of all the vectors inside the tracker.
texture_tracker_set_size :: proc(t: ^Texture_Tracker, size: int, loc := #caller_location) {
    assert(t != nil, loc = loc)
    texture_state_set_resize(&t.start_set, size, loc)
    texture_state_set_resize(&t.end_set, size, loc)
    resource_metadata_set_size(&t.metadata, size, loc)
}

// Extends the vectors so the given index is valid.
texture_tracker_allow_index :: proc(
    t: ^Texture_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    if index >= texture_state_set_len(&t.start_set) {
        texture_tracker_set_size(t, index + 1, loc)
    }
}

// Returns true if the tracker owns the given texture.
texture_tracker_contains :: proc(
    t: ^Texture_Tracker,
    texture: Texture,
    loc := #caller_location,
) -> bool {
    assert(t != nil, loc = loc)
    return resource_metadata_contains(&t.metadata, texture_tracker_index(texture, loc))
}

// Returns an iterator over references to all tracked textures.
texture_tracker_used_resources :: proc(
    t: ^Texture_Tracker,
    loc := #caller_location,
) -> Resource_Metadata_Iterator(Texture) {
    assert(t != nil, loc = loc)
    return resource_metadata_iterate(&t.metadata)
}

// Returns every pending transition accumulated so far and empties the
// internal buffer (capacity is kept for reuse). The caller owns the returned
// slice and should `delete()` it once done.
texture_tracker_drain_transitions :: proc(
    t: ^Texture_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Texture_Transition {
    assert(t != nil, loc = loc)
    result := make([]Pending_Texture_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

// Sets the state of a single texture, returning the transitions needed to get
// the texture into that state. The vectors are extended as needed.
texture_tracker_set_single :: proc(
    t: ^Texture_Tracker,
    texture: Texture,
    selector: Texture_Selector,
    new_state: Texture_Uses,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    texture_impl := texture_get_public_impl(texture, loc)
    index := texture_impl.tracker_index
    texture_tracker_allow_index(t, index, loc)
    texture_tracker_assert_in_bounds(t, index, loc)

    state_provider := texture_state_provider_selector(selector, new_state)
    metadata_provider := resource_metadata_provider_direct(texture)

    texture_insert_or_barrier_update(
        texture_impl.full_range,
        &t.start_set,
        &t.end_set,
        &t.metadata,
        index,
        &state_provider,
        nil,
        &metadata_provider,
        &t.temp,
        t.ordered_uses_mask,
    )
}

// Sets the given state for all textures in the given tracker.
texture_tracker_set_from_tracker :: proc(
    t: ^Texture_Tracker,
    other: ^Texture_Tracker,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(other != nil, loc = loc)

    incoming_size := texture_state_set_len(&other.start_set)
    if incoming_size > texture_state_set_len(&t.start_set) {
        texture_tracker_set_size(t, incoming_size, loc)
    }

    it := resource_metadata_indices(&other.metadata)
    for index in bit_vector_iterator_next(&it) {
        texture_tracker_assert_in_bounds(t, index, loc)
        texture_tracker_assert_in_bounds(other, index, loc)

        tex := resource_metadata_get_unchecked(&other.metadata, index)
        texture_impl := texture_get_public_impl(tex, loc)

        start_provider := texture_state_provider_texture_set(&other.start_set)
        end_provider := texture_state_provider_texture_set(&other.end_set)
        metadata_privder := resource_metadata_provider_indirect(&other.metadata)

        texture_insert_or_barrier_update(
            texture_impl.full_range,
            &t.start_set,
            &t.end_set,
            &t.metadata,
            index,
            &start_provider,
            &end_provider,
            &metadata_privder,
            &t.temp,
            t.ordered_uses_mask,
        )
    }
}

// Sets the given state for all textures in the given usage scope.
texture_tracker_set_from_usage_scope :: proc(
    t: ^Texture_Tracker,
    scope: ^Texture_Usage_Scope,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(scope != nil, loc = loc)

    incoming_size := texture_state_set_len(&scope.set)
    if incoming_size > texture_state_set_len(&t.start_set) {
        texture_tracker_set_size(t, incoming_size, loc)
    }

    it := resource_metadata_indices(&scope.metadata)
    for index in bit_vector_iterator_next(&it) {
        texture_tracker_assert_in_bounds(t, index, loc)
        texture_usage_scope_assert_in_bounds(scope, index, loc)

        tex := resource_metadata_get_unchecked(&scope.metadata, index)
        texture_impl := texture_get_public_impl(tex, loc)

        state_provider := texture_state_provider_texture_set(&scope.set)
        metadata_provider := resource_metadata_provider_indirect(&scope.metadata)

        texture_insert_or_barrier_update(
            texture_impl.full_range,
            &t.start_set,
            &t.end_set,
            &t.metadata,
            index,
            &state_provider,
            nil,
            &metadata_provider,
            &t.temp,
            t.ordered_uses_mask,
        )
    }
}

// Iterates through all textures in the given bind group and adopts their
// state from the usage scope, removing the touched textures from the scope.
//
// Used by compute passes to generate barriers after a dispatch without
// iterating the whole usage scope. Every texture of the bind group must have
// been added to the scope first.
texture_tracker_set_and_remove_from_usage_scope_sparse :: proc(
    t: ^Texture_Tracker,
    scope: ^Texture_Usage_Scope,
    bind_group: ^Texture_View_Bind_Group_State,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)

    incoming_size := texture_state_set_len(&scope.set)
    if incoming_size > texture_state_set_len(&t.start_set) {
        texture_tracker_set_size(t, incoming_size, loc)
    }

    for i in 0 ..< len(bind_group.views) {
        entry := &bind_group.views[i]
        view_impl := texture_view_get_public_impl(entry.view, loc)
        parent := view_impl.texture
        texture_impl := texture_get_public_impl(parent, loc)
        index := texture_impl.tracker_index
        texture_usage_scope_assert_in_bounds(scope, index, loc)

        if !resource_metadata_contains_unchecked(&scope.metadata, index) {
            continue
        }

        state_provider := texture_state_provider_texture_set(&scope.set)
        metadata_provider := resource_metadata_provider_indirect(&scope.metadata)

        // The index is valid for the scope and `set_size` was called to make
        // it valid for `self`.
        texture_insert_or_barrier_update(
            texture_impl.full_range,
            &t.start_set,
            &t.end_set,
            &t.metadata,
            index,
            &state_provider,
            nil,
            &metadata_provider,
            &t.temp,
            t.ordered_uses_mask,
        )
        // Ownership moves to the bind group's state, which retained it on
        // insert, so the scope gives up its reference here.
        resource_release_texture(resource_metadata_get_unchecked(&scope.metadata, index))
        resource_metadata_remove(&scope.metadata, index)
    }
}

// Stores the current state of every texture used by a device. Its metadata is
// weak: the device tracker must not keep textures alive, as their final release
// schedules deferred destruction and removes the tracker entry.
Device_Texture_Tracker :: struct {
    current_state_set: Texture_State_Set,
    metadata:          Resource_Metadata(Texture),
    temp:              [dynamic]Pending_Texture_Transition,
    ordered_uses_mask: Texture_Uses,
    mtx:               sync.RW_Mutex,
}

device_texture_tracker_init :: proc(
    t: ^Device_Texture_Tracker,
    ordered_uses_mask: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    texture_state_set_init(&t.current_state_set, allocator)
    resource_metadata_init(&t.metadata, 0, allocator)
    t.temp.allocator = allocator
    t.ordered_uses_mask = ordered_uses_mask
}

device_texture_tracker_uninit :: proc(t: ^Device_Texture_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    texture_state_set_uninit(&t.current_state_set)
    resource_metadata_uninit(&t.metadata)
    delete(t.temp)
    t^ = {} // reset memory
}

device_texture_tracker_assert_in_bounds :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    assert(index < len(t.current_state_set.simple), loc = loc)
    texture_state_set_assert_in_bounds(&t.current_state_set, index, loc)
    resource_metadata_assert_in_bounds(&t.metadata, index, loc)
}

// Extends the vectors so the given index is valid. Exclusive-lock body; the
// public wrapper acquires `mtx`.
device_texture_tracker_allow_index_locked :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    if index >= texture_state_set_len(&t.current_state_set) {
        texture_state_set_resize(&t.current_state_set, index + 1)
        resource_metadata_set_size(&t.metadata, index + 1, loc)
    }
}

// Extends the vectors so the given index is valid.
device_texture_tracker_allow_index :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: int,
    loc := #caller_location,
) {
    sync.guard(&t.mtx)
    device_texture_tracker_allow_index_locked(t, index, loc)
}

// Returns an iterator over every tracked texture (weak).
//
// As with `device_buffer_tracker_used_resources`, the iterator borrows `t`'s tables,
// so it is only valid while the caller holds `mtx` exclusively or is the tracker's
// only user. No lock is taken here; see that function for why.
device_texture_tracker_used_resources :: proc(
    t: ^Device_Texture_Tracker,
    loc := #caller_location,
) -> Resource_Metadata_Iterator(Texture) {
    assert(t != nil, loc = loc)
    return resource_metadata_iterate(&t.metadata)
}

// Inserts a single texture and its state into the resource tracker. If the
// resource already exists it is overwritten.
device_texture_tracker_insert_single :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: Tracker_Index,
    texture: Texture,
    state: Texture_Uses,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)

    sync.guard(&t.mtx)
    device_texture_tracker_insert_single_locked(t, index, texture, state, loc)
}

// Exclusive-lock body of `device_texture_tracker_insert_single`.
device_texture_tracker_insert_single_locked :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: Tracker_Index,
    texture: Texture,
    state: Texture_Uses,
    loc := #caller_location,
) {
    device_texture_tracker_allow_index_locked(t, index, loc)
    device_texture_tracker_assert_in_bounds(t, index, loc)

    state_provider := texture_state_provider_known_single(state)
    metadata_provider := resource_metadata_provider_direct(texture)

    texture_state_insert(
        {},
        nil,
        &t.current_state_set,
        &t.metadata,
        index,
        &state_provider,
        nil,
        &metadata_provider,
        retain_resource = false,
    )
}

// Returns the state a texture is currently in. `is_single` is false when the
// texture's subresources are in divergent states, in which case the caller must
// resolve per-subresource rather than assume one layout.
device_texture_tracker_get_state :: proc(
    t: ^Device_Texture_Tracker,
    texture: Texture,
    loc := #caller_location,
) -> Device_Texture_State {
    assert(t != nil, loc = loc)
    texture_impl := texture_get_public_impl(texture, loc)
    return device_texture_tracker_get_state_at(t, texture_impl.tracker_index, loc)
}

// Index-based body of `device_texture_tracker_get_state`, so a caller that already
// holds a tracker index does not have to resolve the handle again.
//
// Resolved under the shared lock and returned by value: the divergent case is
// reduced to a flag, so no reference into `current_state_set.complex`, a map
// another thread can rehash, outlives this call. The tracker's complex machinery
// is untouched; only what crosses the lock boundary is simplified.
device_texture_tracker_get_state_at :: proc(
    t: ^Device_Texture_Tracker,
    #any_int index: Tracker_Index,
    loc := #caller_location,
) -> Device_Texture_State {
    assert(t != nil, loc = loc)

    sync.shared_guard(&t.mtx)
    device_texture_tracker_assert_in_bounds(t, index, loc)

    cur := texture_state_set_get_unchecked(&t.current_state_set, index, loc)
    if cur.is_single {
        return {is_single = true, state = cur.state}
    }
    return {}
}

// Sets the state of a single texture without producing a transition, for the
// cases where the caller records the transition itself.
device_texture_tracker_set_state :: proc(
    t: ^Device_Texture_Tracker,
    texture: Texture,
    new_state: Texture_Uses,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    texture_impl := texture_get_public_impl(texture, loc)
    index := texture_impl.tracker_index

    sync.guard(&t.mtx)
    device_texture_tracker_assert_in_bounds(t, index, loc)

    state_provider := texture_state_provider_known_single(new_state)

    texture_state_update(
        texture_impl.full_range,
        nil,
        &t.current_state_set,
        index,
        &state_provider,
    )
}

// Sets the state of a single texture within a given selector, returning the
// transitions needed.
device_texture_tracker_set_single :: proc(
    t: ^Device_Texture_Tracker,
    texture: Texture,
    selector: Texture_Selector,
    new_state: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Texture_Transition {
    assert(t != nil, loc = loc)
    texture_impl := texture_get_public_impl(texture, loc)
    index := texture_impl.tracker_index

    sync.guard(&t.mtx)
    device_texture_tracker_allow_index_locked(t, index, loc)
    device_texture_tracker_assert_in_bounds(t, index, loc)

    state_provider := texture_state_provider_selector(selector, new_state)

    texture_state_barrier(
        texture_impl.full_range,
        &t.current_state_set,
        index,
        &state_provider,
        &t.temp,
        t.ordered_uses_mask,
    )
    texture_state_update(
        texture_impl.full_range,
        nil,
        &t.current_state_set,
        index,
        &state_provider,
    )

    result := make([]Pending_Texture_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

// Removes the texture from the device tracker.
device_texture_tracker_remove :: proc(t: ^Device_Texture_Tracker, #any_int index: Tracker_Index) {
    sync.guard(&t.mtx)
    // Device tracker metadata is weak and does not own a reference.
    resource_metadata_remove(&t.metadata, index)
    // t.current_state_set.simple[index] is left stale but unreachable, the
    // bit vector will report "not contained" for this index until it's
    // reused, at which point device_texture_tracker_insert_single overwrites
    // it fresh.
}

// Sets the given state for all textures in the given tracker, returning the
// needed transitions.
device_texture_tracker_set_from_tracker_and_drain_transitions :: proc(
    t: ^Device_Texture_Tracker,
    tracker: ^Texture_Tracker,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Texture_Transition {
    assert(t != nil, loc = loc)
    assert(tracker != nil, loc = loc)

    // One exclusive acquisition covers the whole diff-and-commit: two threads
    // interleaving here would each diff against a current state the other had
    // already advanced, producing barriers that are missing or duplicated.
    sync.guard(&t.mtx)

    it := resource_metadata_indices(&tracker.metadata)
    for index in bit_vector_iterator_next(&it) {
        device_texture_tracker_assert_in_bounds(t, index, loc)
        tex := resource_metadata_get_unchecked(&tracker.metadata, index)
        texture_impl := texture_get_public_impl(tex, loc)
        start_provider := texture_state_provider_texture_set(&tracker.start_set)
        end_provider := texture_state_provider_texture_set(&tracker.end_set)
        texture_state_barrier(
            texture_impl.full_range,
            &t.current_state_set,
            index,
            &start_provider,
            &t.temp,
            t.ordered_uses_mask,
        )
        texture_state_update(
            texture_impl.full_range,
            nil,
            &t.current_state_set,
            index,
            &end_provider,
        )
    }

    result := make([]Pending_Texture_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

// Sets the given state for all textures in the given usage scope, returning
// the needed transitions.
device_texture_tracker_set_from_usage_scope_and_drain_transitions :: proc(
    t: ^Device_Texture_Tracker,
    scope: ^Texture_Usage_Scope,
    allocator: runtime.Allocator,
    loc := #caller_location,
) -> []Pending_Texture_Transition {
    assert(t != nil, loc = loc)
    assert(scope != nil, loc = loc)

    sync.guard(&t.mtx)

    it := resource_metadata_indices(&scope.metadata)
    for index in bit_vector_iterator_next(&it) {
        device_texture_tracker_assert_in_bounds(t, index, loc)

        tex := resource_metadata_get_unchecked(&scope.metadata, index)
        texture_impl := texture_get_public_impl(tex, loc)
        scope_provider := texture_state_provider_texture_set(&scope.set)
        texture_state_barrier(
            texture_impl.full_range,
            &t.current_state_set,
            index,
            &scope_provider,
            &t.temp,
            t.ordered_uses_mask,
        )
        texture_state_update(
            texture_impl.full_range,
            nil,
            &t.current_state_set,
            index,
            &scope_provider,
        )
    }

    result := make([]Pending_Texture_Transition, len(t.temp), allocator)
    copy(result, t.temp[:])
    clear(&t.temp)
    return result
}

// A tracker used by Device.
//
// Unlike a command-buffer `Tracker`, which is single-owner (one encoder records
// into one buffer), these belong to the device and are reached from every thread
// that creates, records against, writes to, or destroys a resource. Each carries
// its own `sync.RW_Mutex`; they are separate locks, not one device-wide lock, so
// buffer work and texture work do not block each other.
//
// Lock ordering: a device tracker lock is a leaf. It is never held while
// acquiring the submit-context lock or the deferred-deletion lock, and device
// tracker metadata is weak so `resource_metadata_insert`/`remove` never fire the
// retain/release hooks. `vk_deferred_destroy_*` takes the tracker lock, releases
// it, and only then takes the shared tracker-index allocator's lock.
Device_Tracker :: struct {
    buffers:  Device_Buffer_Tracker,
    textures: Device_Texture_Tracker,
}

device_tracker_init :: proc(
    t: ^Device_Tracker,
    ordered_buffer_usages: Buffer_Uses,
    ordered_texture_usages: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    device_buffer_tracker_init(&t.buffers, ordered_buffer_usages, allocator)
    device_texture_tracker_init(&t.textures, ordered_texture_usages, allocator)
}

device_tracker_uninit :: proc(t: ^Device_Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    device_buffer_tracker_uninit(&t.buffers)
    device_texture_tracker_uninit(&t.textures)
    t^ = {} // reset memory
}

// The full double-sided tracker used by command buffers: it knows the state a
// resource first enters the command buffer with (`start_set`) and the state it
// is left in (`end_set`), so transitions between command buffers can be
// generated by comparing the previous end against this start.
Tracker :: struct {
    buffers:           Buffer_Tracker,
    textures:          Texture_Tracker,
    blas_s:            Blas_Tracker,
    tlas_s:            Stateless_Tracker(Tlas),
    views:             Stateless_Tracker(Texture_View),
    bind_groups:       Stateless_Tracker(Bind_Group),
    compute_pipelines: Stateless_Tracker(Compute_Pipeline),
    render_pipelines:  Stateless_Tracker(Render_Pipeline),
    bundles:           Stateless_Tracker(Render_Bundle),
    query_sets:        Query_Set_Tracker,
}

tracker_init :: proc(
    t: ^Tracker,
    ordered_buffer_usages: Buffer_Uses,
    ordered_texture_usages: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(t != nil, loc = loc)
    t^ = {} // reset memory
    buffer_tracker_init(&t.buffers, ordered_buffer_usages, allocator)
    texture_tracker_init(&t.textures, ordered_texture_usages, allocator)
    blas_tracker_init(&t.blas_s, allocator)
    stateless_tracker_init(&t.tlas_s, allocator)
    stateless_tracker_init(&t.views, allocator)
    stateless_tracker_init(&t.bind_groups, allocator)
    stateless_tracker_init(&t.compute_pipelines, allocator)
    stateless_tracker_init(&t.render_pipelines, allocator)
    stateless_tracker_init(&t.bundles, allocator)
    query_set_tracker_init(&t.query_sets, allocator)
}

tracker_uninit :: proc(t: ^Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    buffer_tracker_uninit(&t.buffers)
    texture_tracker_uninit(&t.textures)
    blas_tracker_uninit(&t.blas_s)
    stateless_tracker_uninit(&t.tlas_s)
    stateless_tracker_uninit(&t.views)
    stateless_tracker_uninit(&t.bind_groups)
    stateless_tracker_uninit(&t.compute_pipelines)
    stateless_tracker_uninit(&t.render_pipelines)
    stateless_tracker_uninit(&t.bundles)
    query_set_tracker_uninit(&t.query_sets)
    t^ = {} // reset memory
}

tracker_clear :: proc(t: ^Tracker, loc := #caller_location) {
    assert(t != nil, loc = loc)
    buffer_tracker_clear(&t.buffers)
    texture_tracker_clear(&t.textures)
    stateless_tracker_clear(&t.tlas_s)
    stateless_tracker_clear(&t.views)
    stateless_tracker_clear(&t.bind_groups)
    stateless_tracker_clear(&t.compute_pipelines)
    stateless_tracker_clear(&t.render_pipelines)
    stateless_tracker_clear(&t.bundles)
    blas_tracker_clear(&t.blas_s)
    query_set_tracker_clear(&t.query_sets)
}

// All the usages a bind group contains. The uses are not deduplicated in any
// way and may include conflicting uses; this is compliant with the WebGPU
// spec.
//
// All bind group states are sorted by their tracker index so that when adding
// them to a tracker, they are added in the most efficient order possible
// (ascending order).
Bind_Group_States :: struct {
    buffers:                 Buffer_Bind_Group_State,
    views:                   Texture_View_Bind_Group_State,
    external_textures:       Stateless_Tracker(External_Texture),
    samplers:                Stateless_Tracker(Sampler),
    acceleration_structures: Stateless_Tracker(Tlas),
}

bind_group_state_init :: proc(
    b: ^Bind_Group_States,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(b != nil, loc = loc)
    buffer_bind_group_state_init(&b.buffers, allocator, loc)
    texture_view_bind_group_state_init(&b.views, allocator, loc)
    stateless_tracker_init(&b.external_textures, allocator, loc)
    stateless_tracker_init(&b.samplers, allocator, loc)
    stateless_tracker_init(&b.acceleration_structures, allocator, loc)
}

bind_group_state_uiinit :: proc(b: ^Bind_Group_States, loc := #caller_location) {
    assert(b != nil, loc = loc)
    buffer_bind_group_state_uninit(&b.buffers, loc)
    texture_view_bind_group_state_uninit(&b.views, loc)
    stateless_tracker_uninit(&b.external_textures, loc)
    stateless_tracker_uninit(&b.samplers, loc)
    stateless_tracker_uninit(&b.acceleration_structures, loc)
}

// Optimize the bind group states by sorting them by tracker index.
bind_group_states_optimize :: proc(b: ^Bind_Group_States, loc := #caller_location) {
    assert(b != nil, loc = loc)
    buffer_bind_group_state_optimize(&b.buffers)
    // Views are stateless as resources, however `Texture_View_Bind_Group_State`
    // is special as it will be merged with the texture trackers, so it is
    // sorted too.
    texture_view_bind_group_state_optimize(&b.views, loc)
    // External textures, samplers and TLASes are stateless and never merged
    // with another tracker, so they don't need to be optimized.
}

// A render bundle specific usage scope. It includes the stateless resources
// that are not normally in a usage scope, but are used by render bundles and
// need to be owned by them.
Render_Bundle_Scope :: struct {
    buffers:          Buffer_Usage_Scope,
    textures:         Texture_Usage_Scope,
    bind_groups:      Stateless_Tracker(Bind_Group),
    render_pipelines: Stateless_Tracker(Render_Pipeline),
}

render_bundle_scope_init :: proc(
    scope: ^Render_Bundle_Scope,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(scope != nil, loc = loc)
    scope^ = {}
    buffer_usage_scope_init(&scope.buffers, 0, allocator, loc)
    texture_usage_scope_init(&scope.textures, allocator, loc)
    stateless_tracker_init(&scope.bind_groups, allocator, loc)
    stateless_tracker_init(&scope.render_pipelines, allocator, loc)
}

render_bundle_scope_uninit :: proc(scope: ^Render_Bundle_Scope, loc := #caller_location) {
    assert(scope != nil, loc = loc)
    buffer_usage_scope_uninit(&scope.buffers, loc)
    texture_usage_scope_uninit(&scope.textures, loc)
    stateless_tracker_uninit(&scope.bind_groups, loc)
    stateless_tracker_uninit(&scope.render_pipelines, loc)
    scope^ = {}
}

// Merges the inner contents of a bind group into the render bundle scope. Only
// stateful things are merged in; the other resources are owned indirectly by
// the bind group.
render_bundle_scope_merge_bind_group :: proc(
    scope: ^Render_Bundle_Scope,
    bind_group: ^Bind_Group_States,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(scope != nil, loc = loc)
    assert(bind_group != nil, loc = loc)
    err = buffer_usage_scope_merge_bind_group(&scope.buffers, &bind_group.buffers)
    if err != nil {
        return
    }
    return texture_usage_scope_merge_bind_group(&scope.textures, &bind_group.views, loc)
}

// A pool for the memory used by usage scopes. The memory is returned to the
// pool when a scope is dropped to avoid reallocation: the required memory only
// grows and allocation is significant when a large number of resources have
// been used.
Usage_Scope_Pair :: struct {
    buffers:  Buffer_Usage_Scope,
    textures: Texture_Usage_Scope,
}

Usage_Scope_Pool :: struct {
    mtx:   sync.Mutex,
    pairs: [dynamic]Usage_Scope_Pair,
}

usage_scope_pool_init :: proc(
    pool: ^Usage_Scope_Pool,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(pool != nil, loc = loc)
    pool^ = {} // reset memory
    pool.pairs = make([dynamic]Usage_Scope_Pair, allocator)
}

usage_scope_pool_uninit :: proc(pool: ^Usage_Scope_Pool, loc := #caller_location) {
    assert(pool != nil, loc = loc)
    sync.guard(&pool.mtx)
    for &pair in pool.pairs {
        buffer_usage_scope_uninit(&pair.buffers, loc)
        texture_usage_scope_uninit(&pair.textures, loc)
    }
    delete(pool.pairs)
    pool^ = {} // reset memory
}

usage_scope_pool_push :: proc(
    pool: ^Usage_Scope_Pool,
    buffers: Buffer_Usage_Scope,
    textures: Texture_Usage_Scope,
    loc := #caller_location,
) {
    assert(pool != nil, loc = loc)
    sync.guard(&pool.mtx)
    append(&pool.pairs, Usage_Scope_Pair{buffers = buffers, textures = textures})
}

usage_scope_pool_pop :: proc(
    pool: ^Usage_Scope_Pool,
    loc := #caller_location,
) -> (
    pair: Usage_Scope_Pair,
    ok: bool,
) {
    assert(pool != nil, loc = loc)
    sync.guard(&pool.mtx)
    if len(pool.pairs) > 0 {
        return pop(&pool.pairs), true
    }
    return {}, false
}

// Moves the scope tables out of `scope`, leaving a fresh empty scope in place.
buffer_usage_scope_take :: proc(
    scope: ^Buffer_Usage_Scope,
    loc := #caller_location,
) -> Buffer_Usage_Scope {
    assert(scope != nil, loc = loc)
    out := scope^
    buffer_usage_scope_clear(scope, loc)
    return out
}

texture_usage_scope_take :: proc(
    scope: ^Texture_Usage_Scope,
    loc := #caller_location,
) -> Texture_Usage_Scope {
    assert(scope != nil, loc = loc)
    out := scope^
    texture_usage_scope_clear(scope, loc)
    return out
}

// A usage scope tracker. Only stores stateful resources because stateless
// resources cannot have a usage conflict. The buffer and texture tables are
// pooled: dropping a scope clears it and returns the allocation to the pool.
Usage_Scope :: struct {
    pool:     ^Usage_Scope_Pool,
    buffers:  Buffer_Usage_Scope,
    textures: Texture_Usage_Scope,
}

// Creates a usage scope sized for the tracker indices of every allocated
// resource of the given allocators, pulling storage from the pool when
// available.
usage_scope_init :: proc(
    scope: ^Usage_Scope,
    pool: ^Usage_Scope_Pool,
    allocators: ^Tracker_Index_Allocators,
    ordered_buffer_usages: Buffer_Uses,
    ordered_texture_usages: Texture_Uses,
    allocator: runtime.Allocator,
    loc := #caller_location,
) {
    assert(scope != nil, loc = loc)
    scope^ = {}
    if pair, ok := usage_scope_pool_pop(pool, loc); ok {
        scope.pool = pool
        scope.buffers = pair.buffers
        scope.textures = pair.textures
    } else {
        scope.pool = pool
        buffer_usage_scope_init(&scope.buffers, 0, allocator, loc)
        texture_usage_scope_init(&scope.textures, allocator, loc)
    }
    buffer_usage_scope_set_size(
        &scope.buffers,
        shared_tracker_index_allocator_size(&allocators.buffers, loc),
        loc,
    )
    buffer_usage_scope_set_ordered_uses_mask(&scope.buffers, ordered_buffer_usages, loc)
    texture_usage_scope_set_size(
        &scope.textures,
        shared_tracker_index_allocator_size(&allocators.textures, loc),
        loc,
    )
    texture_usage_scope_set_ordered_uses_mask(&scope.textures, ordered_texture_usages, loc)
}

usage_scope_uninit :: proc(scope: ^Usage_Scope, loc := #caller_location) {
    assert(scope != nil, loc = loc)
    buffer_usage_scope_uninit(&scope.buffers, loc)
    texture_usage_scope_uninit(&scope.textures, loc)
    scope^ = {}
}

// Merges the inner contents of a bind group into the usage scope. Only
// stateful things are merged in; the other resources are owned indirectly by
// the bind group.
usage_scope_merge_bind_group :: proc(
    scope: ^Usage_Scope,
    bind_group: ^Bind_Group_States,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(scope != nil, loc = loc)
    assert(bind_group != nil, loc = loc)
    err = buffer_usage_scope_merge_bind_group(&scope.buffers, &bind_group.buffers)
    if err != nil {
        return
    }
    return texture_usage_scope_merge_bind_group(&scope.textures, &bind_group.views, loc)
}

// Merges the inner contents of a render bundle into the usage scope.
usage_scope_merge_render_bundle :: proc(
    scope: ^Usage_Scope,
    render_bundle: ^Render_Bundle_Scope,
    loc := #caller_location,
) -> (
    err: Usage_Error,
) {
    assert(scope != nil, loc = loc)
    assert(render_bundle != nil, loc = loc)
    err = buffer_usage_scope_merge_usage_scope(&scope.buffers, &render_bundle.buffers)
    if err != nil {
        return
    }
    return texture_usage_scope_merge_usage_scope(&scope.textures, &render_bundle.textures, loc)
}

// Clears the scope and returns its storage to the pool.
usage_scope_drop :: proc(scope: ^Usage_Scope, loc := #caller_location) {
    assert(scope != nil, loc = loc)
    buffer_usage_scope_clear(&scope.buffers, loc)
    texture_usage_scope_clear(&scope.textures, loc)
    usage_scope_pool_push(
        scope.pool,
        buffer_usage_scope_take(&scope.buffers, loc),
        texture_usage_scope_take(&scope.textures, loc),
        loc,
    )
}
