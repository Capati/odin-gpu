package gpu

// Core
import intr "base:intrinsics"
import "base:runtime"
import "core:sync"

// Resource-state tracker.
//
//  metadata    - occupancy sets keyed by tracker index
//  range       - ordered partitions of a key range
//  uses        - the semantic use sets and selectors
//  stateless   - trackers that only record resource handles
//  blas        - bottom-level acceleration structures
//  query_set   - query sets
//  buffer      - buffer usage scopes, transcripts and device state
//  texture     - texture usage scopes, transcripts and device state
//  memory_init - which subresources hold defined bytes
//  tracker     - the command buffer / device tracker shell
//
// Resource identity: every entry point takes the handle plus the dense tracker
// index it is addressed by, because an Odin handle does not expose one.

// -----------------------------------------------------------------------------
// Tracker index
// -----------------------------------------------------------------------------

// A densely-indexed per-resource-type id used to address the tracker tables.
Tracker_Index :: distinct u32

Tracker_Index_Allocator :: struct {
    unused:     [dynamic]Tracker_Index,
    next_index: Tracker_Index,
}

tracker_index_allocator_init :: proc(a: ^Tracker_Index_Allocator, allocator: runtime.Allocator) {
    a.unused = nil
    a.unused.allocator = allocator
    a.next_index = 0
}

tracker_index_allocator_uninit :: proc(a: ^Tracker_Index_Allocator) {
    delete(a.unused)
    a.unused = nil
}

tracker_index_allocator_alloc :: proc(a: ^Tracker_Index_Allocator) -> Tracker_Index {
    if len(a.unused) > 0 {
        return pop(&a.unused)
    }
    index := a.next_index
    a.next_index += 1
    return index
}

tracker_index_allocator_free :: proc(a: ^Tracker_Index_Allocator, index: Tracker_Index) {
    append(&a.unused, index)
}

// Highest index ever handed out. Used to pre-size tracker storage before doing
// unchecked accesses.
tracker_index_allocator_size :: proc(a: ^Tracker_Index_Allocator) -> int {
    return int(a.next_index)
}

// A thread-safe tracker index allocator. There is one of these per resource type,
// shared by a device and its hubs.
Shared_Tracker_Index_Allocator :: struct {
    mtx:   sync.Mutex,
    inner: Tracker_Index_Allocator,
}

shared_tracker_index_allocator_init :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    allocator: runtime.Allocator,
) {
    sync.guard(&a.mtx)
    tracker_index_allocator_init(&a.inner, allocator)
}

shared_tracker_index_allocator_uninit :: proc(a: ^Shared_Tracker_Index_Allocator) {
    sync.guard(&a.mtx)
    tracker_index_allocator_uninit(&a.inner)
}

shared_tracker_index_allocator_alloc :: proc(a: ^Shared_Tracker_Index_Allocator) -> Tracker_Index {
    sync.guard(&a.mtx)
    return tracker_index_allocator_alloc(&a.inner)
}

shared_tracker_index_allocator_free :: proc(
    a: ^Shared_Tracker_Index_Allocator,
    index: Tracker_Index,
) {
    sync.guard(&a.mtx)
    tracker_index_allocator_free(&a.inner, index)
}

shared_tracker_index_allocator_size :: proc(a: ^Shared_Tracker_Index_Allocator) -> int {
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

tracker_index_allocators_init :: proc(a: ^Tracker_Index_Allocators, allocator: runtime.Allocator) {
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

tracker_index_allocators_uninit :: proc(a: ^Tracker_Index_Allocators) {
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
tracker_index_allocators_buffer_size :: proc(a: ^Tracker_Index_Allocators) -> int {
    return shared_tracker_index_allocator_size(&a.buffers)
}

tracker_index_allocators_texture_size :: proc(a: ^Tracker_Index_Allocators) -> int {
    return shared_tracker_index_allocator_size(&a.textures)
}

// -----------------------------------------------------------------------------
// Metadata
// -----------------------------------------------------------------------------

// A set of resources keyed by tracker index: one occupancy bit per index plus the
// resource stored at it.
//
// The trackers keep their state SOA-style, one flat array per kind of state, and
// use this to answer "is index `i` a member" and to iterate the members without
// touching the empty slots: `Metadata_Index_Iterator` skips whole zero words.
//
// The payload is the resource handle, so membership is plain data and the handle's
// generation travels with it, which is what lets a tracker notice a recycled pool
// slot.

METADATA_WORD_BITS :: size_of(u64) * 8

Resource_Metadata :: struct($T: typeid) {
    // The resource at each index. Only a member's slot is meaningful.
    resources:   [dynamic]T,
    // One bit per index; a set bit means the index is a member.
    owned:       [dynamic]u64,
    // popcount of `owned`, maintained so `resource_metadata_count` is O(1).
    owned_count: u32,
}

resource_metadata_init :: proc(md: ^$R/Resource_Metadata($T), allocator: runtime.Allocator) {
    md.owned = nil
    md.resources = nil
    md.owned.allocator = allocator
    md.resources.allocator = allocator
    md.owned_count = 0
}

resource_metadata_free :: proc(md: ^$R/Resource_Metadata($T)) {
    delete(md.owned)
    delete(md.resources)
    md.owned = nil
    md.resources = nil
    md.owned_count = 0
}

// Drop every member, keeping the backing storage for reuse.
resource_metadata_clear :: proc(md: ^$R/Resource_Metadata($T)) {
    clear(&md.owned)
    clear(&md.resources)
    md.owned_count = 0
}

// How many indexes are members.
resource_metadata_count :: #force_inline proc "contextless" (
    md: ^$R/Resource_Metadata($T),
) -> u32 {
    return md.owned_count
}

resource_metadata_is_empty :: #force_inline proc "contextless" (
    md: ^$R/Resource_Metadata($T),
) -> bool {
    return md.owned_count == 0
}

// Grow so `index` can be a member, keeping the bit words and the payload slots in
// step: `index / 64 + 1` words and `index + 1` slots.
//
// Every mutating entry point grows through here, so an index above the current
// size is never out of bounds on first contact. Growth is amortized: reserve a
// power-of-two overshoot beyond the requested size so a creation spike does not
// cause repeated one-element reallocs (the previous implementation appended one
// word / one slot at a time, which is O(n²) in the number of new indices).
resource_metadata_grow_to :: proc(md: ^$R/Resource_Metadata($T), index: Tracker_Index) {
    i := u32(index)
    words := i / METADATA_WORD_BITS + 1
    if u32(len(md.owned)) < words {
        // Next power of two at or above `words`, at least doubling so we do not
        // thrash on growth spikes.
        new_size := words
        if new_size < u32(len(md.owned)) * 2 {
            new_size = u32(len(md.owned)) * 2
        }
        if new_size < 4 {
            new_size = 4
        }
        // Grow in one allocation.
        new_owned := make([dynamic]u64, new_size, md.owned.allocator)
        copy(new_owned[:], md.owned[:])
        delete(md.owned)
        md.owned = new_owned
    }
    if u32(len(md.resources)) <= i {
        new_size := i + 1
        if new_size < u32(len(md.resources)) * 2 {
            new_size = u32(len(md.resources)) * 2
        }
        if new_size < 8 {
            new_size = 8
        }
        new_resources := make([dynamic]T, new_size, md.resources.allocator)
        copy(new_resources[:], md.resources[:])
        delete(md.resources)
        md.resources = new_resources
    }
}

// Single-probe membership + payload. Replaces the common pattern
// `if contains(md, idx) { get(md, idx) }` which probes twice (and, in the
// buffer tracker, sometimes probes a third time). Returns `(true, ^T)` for a
// live member, `(false, nil)` otherwise. The returned pointer is into
// `md.resources`; mutating through it is safe only while `md` is not being
// grown concurrently (the usual single-threaded caller case).
@(require_results)
resource_metadata_lookup :: #force_inline proc "contextless" (
    md: ^$R/Resource_Metadata($T),
    index: Tracker_Index,
) -> (bool, ^T) {
    if u32(index) >= u32(len(md.resources)) {
        return false, nil
    }
    word := u32(index) / METADATA_WORD_BITS
    if (md.owned[word] & metadata_bit(index)) == 0 {
        return false, nil
    }
    return true, &md.resources[u32(index)]
}

// Presize for the highest possible index, `size - 1`. Only grows: the backing
// storage is reused, and `clear` is what empties the set.
resource_metadata_set_size :: proc(md: ^$R/Resource_Metadata($T), size: u32) {
    if size == 0 {
        return
    }
    resource_metadata_grow_to(md, Tracker_Index(size - 1))
}

// The bit that marks `index`: one bit of the word it falls in.
metadata_bit :: #force_inline proc "contextless" (index: Tracker_Index) -> u64 {
    return 1 << (u32(index) % METADATA_WORD_BITS)
}

resource_metadata_contains :: #force_inline proc "contextless" (
    md: ^$R/Resource_Metadata($T),
    index: Tracker_Index,
) -> bool {
    if u32(index) >= u32(len(md.resources)) {
        return false
    }
    return (md.owned[u32(index) / METADATA_WORD_BITS] & metadata_bit(index)) != 0
}

// Insert `resource` at `index`, or overwrite the member already there. Growing is
// implicit, so an index no `set_size` covered is still valid.
resource_metadata_insert :: proc(
    md: ^$R/Resource_Metadata($T),
    index: Tracker_Index,
    resource: T,
) {
    resource_metadata_grow_to(md, index)
    word := u32(index) / METADATA_WORD_BITS
    mask := metadata_bit(index)
    if (md.owned[word] & mask) == 0 {
        md.owned_count += 1
    }
    md.owned[word] |= mask
    md.resources[u32(index)] = resource
}

// Remove `index` from the set; a no-op when it is not a member.
resource_metadata_remove :: proc(md: ^$R/Resource_Metadata($T), index: Tracker_Index) {
    if !resource_metadata_contains(md, index) {
        return
    }
    word := u32(index) / METADATA_WORD_BITS
    mask := metadata_bit(index)
    if (md.owned[word] & mask) != 0 {
        md.owned_count -= 1
    }
    md.owned[word] &= ~mask
}

// The resource at `index`; only meaningful for a member.
resource_metadata_get :: proc(
    md: ^$R/Resource_Metadata($T),
    index: Tracker_Index,
    loc := #caller_location,
) -> T {
    assert(u32(index) < u32(len(md.resources)), "metadata index past its slots", loc = loc)
    return md.resources[u32(index)]
}

// Iterates a `Resource_Metadata`'s members in ascending index order, whole empty
// words at a time.
Metadata_Index_Iterator :: struct($T: typeid) {
    metadata: ^Resource_Metadata(T),
    // The next word to load; while `bits` is live, one past the word it came from.
    word:     u32,
    bits:     u64,
}

metadata_index_iterator_init :: proc(
    it: ^Metadata_Index_Iterator($T),
    metadata: ^Resource_Metadata(T),
) {
    it.metadata = metadata
    it.word = 0
    it.bits = 0
}

// The next member's index, or false at the end of the set.
metadata_index_iterator_next :: proc(
    it: ^Metadata_Index_Iterator($T),
    index: ^Tracker_Index,
) -> bool {
    for {
        if it.bits == 0 {
            if it.metadata == nil || it.word >= u32(len(it.metadata.owned)) {
                return false
            }
            it.bits = it.metadata.owned[it.word]
            it.word += 1
            continue
        }
        // `ctz` of a live word is the lowest member in it; clearing that bit steps
        // to the next one.
        index^ = Tracker_Index(
            (it.word - 1) * u32(METADATA_WORD_BITS) + u32(intr.count_trailing_zeros(it.bits)),
        )
        it.bits &= it.bits - 1
        return true
    }
}

// -----------------------------------------------------------------------------
// Range
// -----------------------------------------------------------------------------

// Ranged subresource states: an ordered, gap-free partition of a key range into
// entries, each carrying one value.
//
// Texture state is built on this. A mip's array layers are one entry until a use
// splits them, and only the entries a use actually touches are re-split, so the
// sequence stays as short as the states allow.
//
// `ranged_states_isolate` is the only operation that splits;
// `ranged_states_coalesce` is the only one that merges.

// One half-open key range `[start, end)` and the value every key inside has.
Ranged_Entry :: struct($T: typeid) {
    start: u32,
    end:   u32,
    value: T,
}

// A partition of `[ranges[0].start, ranges[last].end)`. Entries never overlap and
// never leave a gap, so an entry's `end` is the next entry's `start`.
Ranged_States :: struct($T: typeid) {
    allocator: runtime.Allocator,
    ranges:    [dynamic]Ranged_Entry(T),
}

ranged_states_init :: proc(rs: ^Ranged_States($T), allocator: runtime.Allocator) {
    rs.ranges = nil
    rs.ranges.allocator = allocator
    rs.allocator = allocator
}

ranged_states_free :: proc(rs: ^Ranged_States($T)) {
    delete(rs.ranges)
    rs.ranges = nil
}

ranged_states_clear :: proc(rs: ^Ranged_States($T)) {
    clear(&rs.ranges)
}

// Replace every entry with one covering `[start, end)`.
ranged_states_set_single :: proc(rs: ^Ranged_States($T), start, end: u32, value: T) {
    clear(&rs.ranges)
    append(&rs.ranges, Ranged_Entry(T){start = start, end = end, value = value})
}

// The number of entries. Not the number of keys covered.
ranged_states_len :: #force_inline proc "contextless" (rs: ^Ranged_States($T)) -> int {
    return len(rs.ranges)
}

// True when the entries are ordered, non-empty and non-overlapping.
//
// Split out from `ranged_states_check_sanity` so a test can assert that a
// malformed sequence is detected instead of crashing the run.
ranged_states_is_sane :: proc(rs: ^Ranged_States($T)) -> bool {
    for entry, i in rs.ranges {
        if entry.start >= entry.end {
            return false
        }
        if i > 0 && rs.ranges[i - 1].end > entry.start {
            return false
        }
    }
    return true
}

// Assert `ranged_states_is_sane`. Every mutation must leave the sequence sane.
ranged_states_check_sanity :: proc(rs: ^Ranged_States($T), loc := #caller_location) {
    valid := rs.ranges == nil || ranged_states_is_sane(rs)
    assert(valid, "ranged states are empty, unordered or overlapping", loc = loc)
}

// Merge neighbouring entries that agree, so the sequence stays as short as the
// states allow.
ranged_states_coalesce :: proc(rs: ^Ranged_States($T)) {
    if len(rs.ranges) < 2 {
        return
    }
    write := 0
    for i in 1 ..< len(rs.ranges) {
        if rs.ranges[write].end == rs.ranges[i].start &&
           rs.ranges[write].value == rs.ranges[i].value {
            rs.ranges[write].end = rs.ranges[i].end
            continue
        }
        write += 1
        if write != i {
            rs.ranges[write] = rs.ranges[i]
        }
    }
    if len(rs.ranges) > write + 1 {
        resize(&rs.ranges, write + 1)
    }
}

// Split entries so that `[lo, hi)` is covered by exactly the returned run of
// entries, filling any gap inside the range with `default_value`. Entries outside
// the range are untouched.
//
// Returns the index of the first covered entry. The run ends at the first entry
// whose `start` is `hi`, or at the end of the list. A caller reads and writes the
// covered values by index:
//
//  for i := first; i < len(rs.ranges) && rs.ranges[i].start < hi; i += 1 {
//      rs.ranges[i].value = VALUE
//  }
//
// A sequence with no entry at or after `lo` gets one covering `[lo, hi)`.
ranged_states_isolate :: proc(rs: ^Ranged_States($T), lo, hi: u32, default_value: T) -> int {
    start_pos := -1
    for i in 0 ..< len(rs.ranges) {
        if rs.ranges[i].end > lo {
            start_pos = i
            break
        }
    }
    if start_pos < 0 {
        pos := len(rs.ranges)
        append(&rs.ranges, Ranged_Entry(T){start = lo, end = hi, value = default_value})
        return pos
    }

    // Split the entry that straddles `lo`, so the covered run starts on a boundary
    // and the part below `lo` keeps its value.
    if rs.ranges[start_pos].start < lo {
        old_start := rs.ranges[start_pos].start
        value := rs.ranges[start_pos].value
        rs.ranges[start_pos].start = lo
        ok, _ := inject_at(
            &rs.ranges,
            start_pos,
            Ranged_Entry(T){start = old_start, end = lo, value = value},
        )
        assert(ok, "ranged states out of memory")
        start_pos += 1
    }

    pos := start_pos
    range_pos := lo
    for {
        cur_start := rs.ranges[pos].start
        cur_end := rs.ranges[pos].end
        if cur_start >= hi {
            // The sequence ended before `hi`: fill the tail.
            ok, _ := inject_at(
                &rs.ranges,
                pos,
                Ranged_Entry(T){start = range_pos, end = hi, value = default_value},
            )
            assert(ok, "ranged states out of memory")
            pos += 1
            break
        }
        if cur_start > range_pos {
            // A gap between entries: fill it with the default.
            ok, _ := inject_at(
                &rs.ranges,
                pos,
                Ranged_Entry(T){start = range_pos, end = cur_start, value = default_value},
            )
            assert(ok, "ranged states out of memory")
            pos += 1
            range_pos = cur_start
        }
        if cur_end >= hi {
            if cur_end != hi {
                // The entry straddles `hi`: keep the part above it.
                value := rs.ranges[pos].value
                rs.ranges[pos].start = hi
                ok, _ := inject_at(
                    &rs.ranges,
                    pos,
                    Ranged_Entry(T){start = range_pos, end = hi, value = value},
                )
                assert(ok, "ranged states out of memory")
            }
            pos += 1
            break
        }
        pos += 1
        range_pos = cur_end
        if pos == len(rs.ranges) {
            // The sequence ended before `hi` and on a boundary.
            append(&rs.ranges, Ranged_Entry(T){start = range_pos, end = hi, value = default_value})
            pos += 1
            break
        }
    }
    return start_pos
}

// -----------------------------------------------------------------------------
// Uses
// -----------------------------------------------------------------------------

// The semantic use sets the trackers reason about.
//
// A tracked state is the set of uses a subresource is currently valid for. Two
// rules drive everything else:
//
// - *Exclusive* uses cannot coexist with any other use in one usage scope. A
//   scope that merges an exclusive use onto a non-empty state is a conflict.
// - *Inclusive* uses may coexist, and the hardware orders accesses within them,
//   so a transition between two states drawn from that set needs no barrier.
//
// `Unknown` and `Uninitialized` are different facts. `Unknown` means the tracker
// knows nothing about the subresource; it never reaches a barrier. `Uninitialized`
// means the tracker knows the contents are undefined; transitioning away from it
// discards them.

// Semantic texture usages. Nineteen bits, so the whole set fits in one word.
Texture_Uses :: bit_set[Texture_Use;u32]
Texture_Use  :: enum {
    // Known to hold undefined contents. Transitions away from it discard.
    Uninitialized,
    // Handed to, or about to be handed to, the presentation engine.
    Present,
    // Source of a copy.
    Copy_Src,
    // Destination of a copy, a clear or a queue write.
    Copy_Dst,
    // Sampled or fetched by a shader.
    Resource,
    // Color attachment of a render pass.
    Color_Target,
    // Read-only depth access.
    Depth_Read,
    // Read-write depth access.
    Depth_Write,
    // Read-only stencil access.
    Stencil_Read,
    // Read-write stencil access.
    Stencil_Write,
    // Read-only storage texture.
    Storage_Read_Only,
    // Write-only storage texture.
    Storage_Write_Only,
    // Read-write storage texture.
    Storage_Read_Write,
    // Storage texture whose accesses may be atomic.
    Storage_Atomic,
    // Requested as a transient attachment; never a tracked state.
    Transient,
    // Tracker bookkeeping: the subresources this texture is split across.
    Complex,
    // The tracker knows nothing about this subresource.
    Unknown,
    // The read-only depth aspect is sampled.
    Depth_Sampled,
    // The read-only stencil aspect is sampled.
    Stencil_Sampled,
}

TEXTURE_USES_EMPTY              :: Texture_Uses{}
TEXTURE_USES_UNINITIALIZED      :: Texture_Uses{.Uninitialized}
TEXTURE_USES_PRESENT            :: Texture_Uses{.Present}
TEXTURE_USES_COPY_SRC           :: Texture_Uses{.Copy_Src}
TEXTURE_USES_COPY_DST           :: Texture_Uses{.Copy_Dst}
TEXTURE_USES_RESOURCE           :: Texture_Uses{.Resource}
TEXTURE_USES_COLOR_TARGET       :: Texture_Uses{.Color_Target}
TEXTURE_USES_DEPTH_READ         :: Texture_Uses{.Depth_Read}
TEXTURE_USES_DEPTH_WRITE        :: Texture_Uses{.Depth_Write}
TEXTURE_USES_STENCIL_READ       :: Texture_Uses{.Stencil_Read}
TEXTURE_USES_STENCIL_WRITE      :: Texture_Uses{.Stencil_Write}
TEXTURE_USES_STORAGE_READ_ONLY  :: Texture_Uses{.Storage_Read_Only}
TEXTURE_USES_STORAGE_WRITE_ONLY :: Texture_Uses{.Storage_Write_Only}
TEXTURE_USES_STORAGE_READ_WRITE :: Texture_Uses{.Storage_Read_Write}
TEXTURE_USES_STORAGE_ATOMIC     :: Texture_Uses{.Storage_Atomic}
TEXTURE_USES_TRANSIENT          :: Texture_Uses{.Transient}
TEXTURE_USES_COMPLEX            :: Texture_Uses{.Complex}
TEXTURE_USES_UNKNOWN            :: Texture_Uses{.Unknown}
TEXTURE_USES_DEPTH_SAMPLED      :: Texture_Uses{.Depth_Sampled}
TEXTURE_USES_STENCIL_SAMPLED    :: Texture_Uses{.Stencil_Sampled}

// Uses that exclude every other use on the same subresource within a usage scope.
TEXTURE_USES_EXCLUSIVE :: Texture_Uses {
    .Copy_Dst,
    .Color_Target,
    .Storage_Write_Only,
    .Storage_Read_Write,
    .Storage_Atomic,
    .Present,
}

// Uses that may coexist: accesses drawn only from this set are ordered by the
// hardware, so a transition between two such states needs no barrier.
TEXTURE_USES_INCLUSIVE :: Texture_Uses {
    .Copy_Src,
    .Resource,
    .Depth_Read,
    .Stencil_Read,
    .Storage_Read_Only,
}

// The device's ordering policy for texture uses; Vulkan's is `INCLUSIVE`.
TEXTURE_USES_ORDERED :: Texture_Uses {
    .Copy_Src,
    .Resource,
    .Depth_Read,
    .Stencil_Read,
    .Storage_Read_Only,
}

// Depth/stencil states that combine a write with a read and are still legal: the
// two aspects address different planes, so one may be written while the other is
// read, and a read-only aspect may additionally be sampled.
@(rodata)
TEXTURE_VALID_DEPTH_STENCIL := [7]Texture_Uses {
    {.Depth_Write, .Stencil_Write},
    {.Depth_Write, .Stencil_Read},
    {.Stencil_Write, .Depth_Read},
    {.Depth_Write, .Resource, .Stencil_Read},
    {.Stencil_Write, .Resource, .Depth_Read},
    {.Depth_Write, .Resource, .Stencil_Read, .Stencil_Sampled},
    {.Stencil_Write, .Resource, .Depth_Read, .Depth_Sampled},
}

// Turns the set into a pile of bits.
texture_uses_bits :: #force_inline proc "contextless" (u: Texture_Uses) -> u32 {
    return transmute(u32)u
}

// True when any bit in `bits` is set.
texture_uses_has :: #force_inline proc "contextless" (u, bits: Texture_Uses) -> bool {
    return (u & bits) != {}
}

// True when the set contains an exclusive use.
texture_uses_any_exclusive :: #force_inline proc "contextless" (u: Texture_Uses) -> bool {
    return (u & TEXTURE_USES_EXCLUSIVE) != {}
}

// True when the contents are known to be undefined.
texture_uses_is_uninitialized :: #force_inline proc "contextless" (u: Texture_Uses) -> bool {
    return .Uninitialized in u
}

// True when moving from `u` to `to` needs no barrier: the state is unchanged and
// consists only of ordered uses.
texture_uses_skip_transition :: #force_inline proc "contextless" (u, to: Texture_Uses) -> bool {
    return u == to && (texture_uses_bits(u) & ~texture_uses_bits(TEXTURE_USES_ORDERED)) == 0
}

// True when the set names a use a `VkImageView` may be created for: Vulkan
// requires the image to carry at least one of them, while WebGPU lets an
// application create a view of any texture.
texture_uses_is_view_capable :: #force_inline proc "contextless" (u: Texture_Uses) -> bool {
    return texture_uses_has(
        u,
        TEXTURE_USES_RESOURCE |
        TEXTURE_USES_COLOR_TARGET |
        TEXTURE_USES_DEPTH_READ |
        TEXTURE_USES_DEPTH_WRITE |
        TEXTURE_USES_STENCIL_READ |
        TEXTURE_USES_STENCIL_WRITE |
        TEXTURE_USES_STORAGE_READ_ONLY |
        TEXTURE_USES_STORAGE_WRITE_ONLY |
        TEXTURE_USES_STORAGE_READ_WRITE |
        TEXTURE_USES_STORAGE_ATOMIC,
    )
}

// True when the set violates the usage-scope rule: an exclusive use combined with
// anything else, or a depth/stencil combination outside the legal table.
texture_uses_is_invalid :: proc "contextless" (u: Texture_Uses) -> bool {
    bits := texture_uses_bits(u)
    if texture_uses_any_exclusive(u) && intr.count_ones(bits) != 1 {
        return true
    }
    if (u & {.Depth_Write, .Stencil_Write}) == {} {
        return false
    }
    if intr.count_ones(bits) == 1 {
        return false
    }
    for valid in TEXTURE_VALID_DEPTH_STENCIL {
        if valid == u {
            return false
        }
    }
    return true
}

// `texture_uses_skip_transition`, ignoring which read-only aspect is sampled:
// sampling the depth aspect and sampling the stencil aspect are the same layout
// and the same access, so the two flags alone must not force a barrier.
texture_uses_skip_transition_ignoring_aspect :: #force_inline proc "contextless" (
    u, ordered, to: Texture_Uses,
) -> bool {
    // Strip the aspect flags from both sides before comparing, so the ordered test
    // sees only the real uses: two sampled reads that differ in which read-only
    // aspect they name are the same access.
    aspects := texture_uses_bits(TEXTURE_USES_DEPTH_SAMPLED | TEXTURE_USES_STENCIL_SAMPLED)
    from_uses := texture_uses_bits(u) & ~aspects
    to_uses := texture_uses_bits(to) & ~aspects
    return from_uses == to_uses && (from_uses & ~texture_uses_bits(ordered)) == 0
}

// Compatibility name for the previous tracker's barrier-skip check.
skip_barrier_ignore_texture_flags :: #force_inline proc "contextless" (
    old_state, ordered_uses_mask, new_state: Texture_Uses,
) -> bool {
    return texture_uses_skip_transition_ignoring_aspect(old_state, ordered_uses_mask, new_state)
}

// Drop the `Unknown` marker from a merged set: it is bookkeeping, not a use.
texture_uses_keep_known :: #force_inline proc "contextless" (u: Texture_Uses) -> Texture_Uses {
    return transmute(Texture_Uses)(texture_uses_bits(u) & ~texture_uses_bits(TEXTURE_USES_UNKNOWN))
}

// True when the set is the zero set: nothing has been recorded yet.
texture_uses_is_empty :: #force_inline proc "contextless" (u: Texture_Uses) -> bool {
    return texture_uses_bits(u) == 0
}

// Semantic buffer usages. Sixteen bits: one state for the whole buffer, no
// selector.
Buffer_Uses :: bit_set[Buffer_Use;u16]
Buffer_Use  :: enum u16 {
    // The argument to a read-only mapping.
    Map_Read,
    // The argument to a write-only mapping.
    Map_Write,
    // The source of a hardware copy.
    Copy_Src,
    // The destination of a hardware copy.
    Copy_Dst,
    // Index buffer of a draw.
    Index,
    // Vertex buffer of a draw.
    Vertex,
    // Uniform buffer in a bind group.
    Uniform,
    // Read-only storage buffer in a bind group.
    Storage_Read_Only,
    // Read-write storage buffer in a bind group.
    Storage_Read_Write,
    // Indirect or count buffer of an indirect draw or dispatch.
    Indirect,
    // Destination of a query resolve.
    Query_Resolve,
    // Scratch storage of an acceleration-structure build.
    Acceleration_Structure_Scratch,
    // Input of a bottom-level acceleration-structure build.
    Bottom_Level_Acceleration_Structure_Input,
    // Input of a top-level acceleration-structure build.
    Top_Level_Acceleration_Structure_Input,
    // Holds a compacted acceleration-structure size.
    Acceleration_Structure_Query,
    // Opaque shader data for ray tracing.
    Ray_Tracing_Pipeline_Shader_Data,
}

BUFFER_USES_UNINITIALIZED                             :: Buffer_Uses{}
BUFFER_USES_MAP_READ                                  :: Buffer_Uses{.Map_Read}
BUFFER_USES_MAP_WRITE                                 :: Buffer_Uses{.Map_Write}
BUFFER_USES_COPY_SRC                                  :: Buffer_Uses{.Copy_Src}
BUFFER_USES_COPY_DST                                  :: Buffer_Uses{.Copy_Dst}
BUFFER_USES_INDEX                                     :: Buffer_Uses{.Index}
BUFFER_USES_VERTEX                                    :: Buffer_Uses{.Vertex}
BUFFER_USES_UNIFORM                                   :: Buffer_Uses{.Uniform}
BUFFER_USES_STORAGE_READ_ONLY                         :: Buffer_Uses{.Storage_Read_Only}
BUFFER_USES_STORAGE_READ_WRITE                        :: Buffer_Uses{.Storage_Read_Write}
BUFFER_USES_INDIRECT                                  :: Buffer_Uses{.Indirect}
BUFFER_USES_QUERY_RESOLVE                             :: Buffer_Uses{.Query_Resolve}
BUFFER_USES_ACCELERATION_STRUCTURE_SCRATCH            :: Buffer_Uses {
    .Acceleration_Structure_Scratch,
}
BUFFER_USES_BOTTOM_LEVEL_ACCELERATION_STRUCTURE_INPUT :: Buffer_Uses {
    .Bottom_Level_Acceleration_Structure_Input,
}
BUFFER_USES_TOP_LEVEL_ACCELERATION_STRUCTURE_INPUT    :: Buffer_Uses {
    .Top_Level_Acceleration_Structure_Input,
}
BUFFER_USES_ACCELERATION_STRUCTURE_QUERY              :: Buffer_Uses{.Acceleration_Structure_Query}
BUFFER_USES_RAY_TRACING_PIPELINE_SHADER_DATA          :: Buffer_Uses {
    .Ray_Tracing_Pipeline_Shader_Data,
}

// Uses that exclude every other use on the buffer within a usage scope.
BUFFER_USES_EXCLUSIVE :: Buffer_Uses {
    .Map_Write,
    .Copy_Dst,
    .Storage_Read_Write,
    .Acceleration_Structure_Scratch,
}

// Uses that may coexist; accesses within this set are ordered.
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
    .Ray_Tracing_Pipeline_Shader_Data,
}

// The device's ordering policy for buffer uses. Mapping for write joins the
// inclusive set: the host cannot order its own writes against later GPU reads
// without a barrier.
BUFFER_USES_ORDERED :: Buffer_Uses {
    .Map_Read,
    .Map_Write,
    .Copy_Src,
    .Index,
    .Vertex,
    .Uniform,
    .Storage_Read_Only,
    .Indirect,
    .Bottom_Level_Acceleration_Structure_Input,
    .Top_Level_Acceleration_Structure_Input,
    .Ray_Tracing_Pipeline_Shader_Data,
}

BUFFER_USES_TIMESTAMP_NORMALIZATION :: Buffer_Uses{.Storage_Read_Write}
BUFFER_USES_MAPPABLE                :: Buffer_Uses{.Map_Read, .Map_Write}
BUFFER_USES_COPY                    :: Buffer_Uses{.Copy_Src, .Copy_Dst}
BUFFER_USES_STAGING                 :: BUFFER_USES_MAPPABLE | BUFFER_USES_COPY

// Turns the set into a pile of bits.
buffer_uses_bits :: #force_inline proc "contextless" (u: Buffer_Uses) -> u16 {
    return transmute(u16)u
}

// True when any bit in `bits` is set.
buffer_uses_has :: #force_inline proc "contextless" (u, bits: Buffer_Uses) -> bool {
    return (u & bits) != {}
}

// True when the set contains an exclusive use.
buffer_uses_any_exclusive :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return (u & BUFFER_USES_EXCLUSIVE) != {}
}

// The zero set: nothing has been recorded for the buffer yet.
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
    return u &~ mask
}

buffer_uses_is_mappable :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return (u & BUFFER_USES_MAPPABLE) != {}
}

// True if `u` contains only bits that are also in `superset` (possibly empty).
buffer_uses_is_subset :: #force_inline proc "contextless" (u, superset: Buffer_Uses) -> bool {
    return u != {} && (u & superset) == u
}

// True when moving from `u` to `to` needs no barrier.
buffer_uses_skip_transition :: #force_inline proc "contextless" (u, to: Buffer_Uses) -> bool {
    return u == to && (buffer_uses_bits(u) & ~buffer_uses_bits(BUFFER_USES_ORDERED)) == 0
}

// True when the set violates the usage-scope rule: an exclusive use may not be
// combined with any other.
buffer_uses_is_invalid :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return buffer_uses_any_exclusive(u) && intr.count_ones(buffer_uses_bits(u)) != 1
}

// True when a buffer in this state holds defined contents afterwards: something
// wrote it. A read-only set does not.
buffer_uses_writes_contents :: #force_inline proc "contextless" (u: Buffer_Uses) -> bool {
    return buffer_uses_has(
        u,
        BUFFER_USES_COPY_DST |
        BUFFER_USES_STORAGE_READ_WRITE |
        BUFFER_USES_QUERY_RESOLVE |
        BUFFER_USES_MAP_WRITE |
        BUFFER_USES_ACCELERATION_STRUCTURE_SCRATCH,
    )
}

// Which subresources (mip levels and array layers) a usage applies to.
//
// The public selector counts levels from a base, the WebGPU shape; the tracker
// works in half-open ranges and converts at its boundary.
Texture_Selector :: struct {
    // First mip level.
    mip_start:   u32,
    // Number of mip levels.
    mip_count:   u32,
    // First array layer.
    layer_start: u32,
    // Number of array layers.
    layer_count: u32,
}

// True when the two selectors share at least one (mip, layer) cell.
texture_selector_overlaps :: #force_inline proc "contextless" (a, b: Texture_Selector) -> bool {
    return(
        a.mip_start < b.mip_start + b.mip_count &&
        b.mip_start < a.mip_start + a.mip_count &&
        a.layer_start < b.layer_start + b.layer_count &&
        b.layer_start < a.layer_start + a.layer_count \
    )
}

// True when both selectors name exactly the same subresources.
texture_selector_equals :: #force_inline proc "contextless" (a, b: Texture_Selector) -> bool {
    return(
        a.mip_start == b.mip_start &&
        a.mip_count == b.mip_count &&
        a.layer_start == b.layer_start &&
        a.layer_count == b.layer_count \
    )
}

// True when the selector names one subresource.
texture_selector_contains_subresource :: #force_inline proc "contextless" (
    sel: Texture_Selector,
    mip: u32,
    layer: u32,
) -> bool {
    if mip < sel.mip_start || mip >= sel.mip_start + sel.mip_count {
        return false
    }
    if layer < sel.layer_start || layer >= sel.layer_start + sel.layer_count {
        return false
    }
    return true
}

// A texture and its full subresource range, keyed by the tracker index the caller
// supplied. The index is the handle's identity for this package: handles do not
// expose one, so it travels next to the handle.
Tracked_Texture :: struct {
    index:   Tracker_Index,
    texture: Texture,
    full:    Texture_Selector,
}

// Build a tracked texture whose full range covers `mip_count` x `layer_count`.
tracked_texture :: proc(
    index: Tracker_Index,
    texture: Texture,
    mip_count, layer_count: u32,
) -> Tracked_Texture {
    return {
        index = index,
        texture = texture,
        full = {
            mip_start   = 0,
            mip_count   = mip_count,
            layer_start = 0,
            layer_count = layer_count,
        },
    }
}

// An abstract "move this texture subresource range from one use-set to another".
// Carries the resource handle, not a backend object, so it stays backend-neutral.
Texture_State_Transition :: struct {
    texture:  Texture,
    selector: Texture_Selector,
    from:     Texture_Uses,
    to:       Texture_Uses,
}

Buffer_State_Transition :: struct {
    buffer: Buffer,
    from:   Buffer_Uses,
    to:     Buffer_Uses,
}

// The use-set a texture's image is created with, derived from its WebGPU usage and
// the format's features: the storage bits follow the format's feature flags and a
// render attachment becomes a color target or depth/stencil access depending on
// the format.
//
// Two guarantees go beyond what the application asked for, and both are about the
// *image*, not about tracking:
//
// - It must be definable. WebGPU's memory initialization defines a range nothing
//   wrote with a zero clear, and both clear commands require the image to carry
//   `TRANSFER_DST` usage. A texture is always initializable, so the bit is always
//   here.
// - It must be viewable. `createView` is legal on any WebGPU texture, while Vulkan
//   requires the image to carry at least one view-capable usage; a colour texture
//   whose uses are all transfer/storage ones gets `Resource`, which every format
//   WebGPU can create supports.
//
// A transient attachment adds no Vulkan image usage beyond the attachment it
// already is, so it contributes nothing here.
texture_descriptor_image_uses :: proc(
    desc: Texture_Descriptor,
    format_features: Texture_Format_Features,
) -> Texture_Uses {
    uses: Texture_Uses
    is_color := !texture_format_is_depth_stencil_format(desc.format)

    if .Copy_Src in desc.usage {
        uses += {.Copy_Src}
    }
    uses += {.Copy_Dst}
    if .Texture_Binding in desc.usage {
        uses += {.Resource}
    }
    if .Storage_Binding in desc.usage {
        if .Storage_Read_Only in format_features.flags {
            uses += {.Storage_Read_Only}
        }
        if .Storage_Write_Only in format_features.flags {
            uses += {.Storage_Write_Only}
        }
        if .Storage_Read_Write in format_features.flags {
            uses += {.Storage_Read_Write}
        }
        if .Storage_Atomic in desc.usage {
            uses += {.Storage_Atomic}
        }
    }
    if .Render_Attachment in desc.usage {
        if is_color {
            uses += {.Color_Target}
        } else {
            uses += {.Depth_Read, .Depth_Write, .Stencil_Read, .Stencil_Write}
        }
    }

    if !is_color {
        // A depth/stencil image is always writable — that is what makes it
        // initializable — and those uses make it viewable too.
        uses += {.Depth_Write, .Stencil_Write}
    } else if !texture_uses_is_view_capable(uses) {
        uses += {.Resource}
    }
    return uses
}

// -----------------------------------------------------------------------------
// Stateless
// -----------------------------------------------------------------------------

// A tracker that only owns resources.
//
// It answers one question at submission time: did this command buffer reference
// that resource? WebGPU requires a submission to fail if a resource in any bind
// group or pipeline the encoder was given has been destroyed, whether or not the
// pipeline actually uses it, so the encoder records the handles it was handed and
// nothing else.

Stateless_Tracker :: struct($T: typeid) {
    resources: [dynamic]T,
}

stateless_tracker_init :: proc(t: ^$S/Stateless_Tracker($T), allocator: runtime.Allocator) {
    t.resources = nil
    t.resources.allocator = allocator
}

stateless_tracker_free :: proc(t: ^$S/Stateless_Tracker($T)) {
    delete(t.resources)
    t.resources = nil
}

stateless_tracker_clear :: proc(t: ^$S/Stateless_Tracker($T)) {
    clear(&t.resources)
}

stateless_tracker_len :: #force_inline proc "contextless" (t: ^$S/Stateless_Tracker($T)) -> int {
    return len(t.resources)
}

// Record `resource` and hand it back, so a caller can keep using one handle.
stateless_tracker_insert_single :: proc(t: ^$S/Stateless_Tracker($T), resource: T) -> T {
    append(&t.resources, resource)
    return resource
}

// True when `resource` was recorded.
stateless_tracker_contains :: proc(t: ^$S/Stateless_Tracker($T), resource: T) -> bool {
    for entry in t.resources {
        if entry == resource {
            return true
        }
    }
    return false
}

// Transfers ownership of the reference list out, leaving an empty list with the
// same allocator behind. The caller releases the returned references under
// whatever lock discipline applies to its tracker.
stateless_tracker_take :: proc(t: ^$S/Stateless_Tracker($T)) -> [dynamic]T {
    refs := t.resources
    t.resources = nil
    t.resources.allocator = refs.allocator
    return refs
}

// -----------------------------------------------------------------------------
// Blas
// -----------------------------------------------------------------------------

// A tracker for bottom-level acceleration structures.
//
// A build has no resource state to move, so the tracker only records which ones a
// command buffer touched.

Blas_Tracker :: struct {
    metadata: Resource_Metadata(Blas),
    size:     u32,
}

blas_tracker_init :: proc(t: ^Blas_Tracker, allocator: runtime.Allocator) {
    t^ = {}
    resource_metadata_init(&t.metadata, allocator)
}

blas_tracker_free :: proc(t: ^Blas_Tracker) {
    resource_metadata_free(&t.metadata)
    t^ = {}
}

blas_tracker_clear :: proc(t: ^Blas_Tracker) {
    resource_metadata_clear(&t.metadata)
    t.size = 0
}

// Record `blas` at `index` and hand it back.
blas_tracker_insert_single :: proc(t: ^Blas_Tracker, index: Tracker_Index, blas: Blas) -> Blas {
    resource_metadata_insert(&t.metadata, index, blas)
    if u32(index) + 1 > t.size {
        t.size = u32(index) + 1
    }
    return blas
}

blas_tracker_count :: #force_inline proc "contextless" (t: ^Blas_Tracker) -> u32 {
    return resource_metadata_count(&t.metadata)
}

blas_tracker_contains :: #force_inline proc "contextless" (
    t: ^Blas_Tracker,
    index: Tracker_Index,
) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

// -----------------------------------------------------------------------------
// Query set
// -----------------------------------------------------------------------------

// A tracker for query sets.
//
// Queries have no state to transition, so the tracker is a set of the query sets a
// command buffer touched: it keeps them alive and lets submission validation see
// them.

Query_Set_Tracker :: struct {
    metadata: Resource_Metadata(Query_Set),
    size:     u32,
}

query_set_tracker_init :: proc(t: ^Query_Set_Tracker, allocator: runtime.Allocator) {
    t^ = {}
    resource_metadata_init(&t.metadata, allocator)
}

query_set_tracker_free :: proc(t: ^Query_Set_Tracker) {
    resource_metadata_free(&t.metadata)
    t^ = {}
}

query_set_tracker_clear :: proc(t: ^Query_Set_Tracker) {
    resource_metadata_clear(&t.metadata)
    t.size = 0
}

// Record `query_set` at `index` and hand it back.
query_set_tracker_insert_single :: proc(
    t: ^Query_Set_Tracker,
    index: Tracker_Index,
    query_set: Query_Set,
) -> Query_Set {
    resource_metadata_insert(&t.metadata, index, query_set)
    if u32(index) + 1 > t.size {
        t.size = u32(index) + 1
    }
    return query_set
}

query_set_tracker_count :: #force_inline proc "contextless" (t: ^Query_Set_Tracker) -> u32 {
    return resource_metadata_count(&t.metadata)
}

query_set_tracker_contains :: #force_inline proc "contextless" (
    t: ^Query_Set_Tracker,
    index: Tracker_Index,
) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

// -----------------------------------------------------------------------------
// Buffer
// -----------------------------------------------------------------------------

// Buffer trackers.
//
// A buffer has one state for the whole resource: a 16-bit set of uses, no
// subresource selector. Three trackers share that shape:
//
// - `Buffer_Usage_Scope` collects the uses of every buffer one render or compute
//   pass touches, so a conflicting use is refused before any state moves.
// - `Buffer_Tracker` is one command buffer's transcript. `start` is the state it
//   assumes on entry, `end` the state it leaves behind, and `temp` the transitions
//   it owes itself.
// - `Device_Buffer_Tracker` is the authoritative state across submissions.
//
// The primitives at the bottom carry the logic: `buffer_insert` on first contact,
// `buffer_barrier` to emit what a move needs, `buffer_update` to record it, and
// the scopes' merge for combining uses inside one pass. Everything above is
// bookkeeping.

// One buffer, its tracker index and the use set a bind group references it with.
Buffer_Bind_Group_Resource :: struct {
    index:  Tracker_Index,
    buffer: Buffer,
    uses:   Buffer_Uses,
}

// The buffers of one bind group, sorted by tracker index so that merging them into
// a tracker walks both arrays forward.
Buffer_Bind_Group_State :: struct {
    buffers: [dynamic]Buffer_Bind_Group_Resource,
}

buffer_bind_group_state_init :: proc(s: ^Buffer_Bind_Group_State, allocator: runtime.Allocator) {
    s.buffers = nil
    s.buffers.allocator = allocator
}

buffer_bind_group_state_free :: proc(s: ^Buffer_Bind_Group_State) {
    delete(s.buffers)
    s.buffers = nil
}

buffer_bind_group_state_clear :: proc(s: ^Buffer_Bind_Group_State) {
    clear(&s.buffers)
}

buffer_bind_group_state_len :: #force_inline proc "contextless" (
    s: ^Buffer_Bind_Group_State,
) -> int {
    return len(s.buffers)
}

// Record one buffer binding. Entries are *not* deduplicated: WebGPU allows a bind
// group to hold conflicting uses for the same buffer, and the conflict has to
// surface when the group is merged into a scope, not be hidden here.
buffer_bind_group_state_insert_single :: proc(
    s: ^Buffer_Bind_Group_State,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
) {
    append(&s.buffers, Buffer_Bind_Group_Resource{index = index, buffer = buffer, uses = uses})
}

// Sort by tracker index. A bind group holds one entry per buffer binding, so the
// insertion sort's constant factors win over a general sort here.
buffer_bind_group_state_optimize :: proc(s: ^Buffer_Bind_Group_State) {
    for i in 1 ..< len(s.buffers) {
        entry := s.buffers[i]
        j := i
        for j > 0 && u32(s.buffers[j - 1].index) > u32(entry.index) {
            s.buffers[j] = s.buffers[j - 1]
            j -= 1
        }
        s.buffers[j] = entry
    }
}

// The merged uses of every buffer one usage scope touches.
Buffer_Usage_Scope :: struct {
    // One state per tracker index; only a member's slot is meaningful.
    state:    [dynamic]Buffer_Uses,
    metadata: Resource_Metadata(Buffer),
    // The device's ordering policy, so a scope and a tracker agree on skips.
    ordered:  Buffer_Uses,
}

buffer_usage_scope_init :: proc(s: ^Buffer_Usage_Scope, allocator: runtime.Allocator) {
    s.state = nil
    s.state.allocator = allocator
    resource_metadata_init(&s.metadata, allocator)
    s.ordered = {}
}

buffer_usage_scope_free :: proc(s: ^Buffer_Usage_Scope) {
    delete(s.state)
    s.state = nil
    resource_metadata_free(&s.metadata)
}

// Drop every member, keeping the backing storage for reuse.
buffer_usage_scope_clear :: proc(s: ^Buffer_Usage_Scope) {
    clear(&s.state)
    resource_metadata_clear(&s.metadata)
}

// Presize for indices below `size`.
buffer_usage_scope_set_size :: proc(s: ^Buffer_Usage_Scope, size: u32) {
    for u32(len(s.state)) < size {
        append(&s.state, Buffer_Uses{})
    }
    resource_metadata_set_size(&s.metadata, size)
}

buffer_usage_scope_set_ordered_uses_mask :: proc(s: ^Buffer_Usage_Scope, mask: Buffer_Uses) {
    s.ordered = mask
}

// Grow so `index` has a state slot.
buffer_usage_scope_allow_index :: proc(s: ^Buffer_Usage_Scope, index: Tracker_Index) {
    if u32(index) >= u32(len(s.state)) {
        buffer_usage_scope_set_size(s, u32(index) + 1)
    }
}

// Merge one buffer's use into the scope. False is a usage conflict, reported
// through the two out parameters as the state the scope had and the use it was
// offered.
buffer_usage_scope_merge_single :: proc(
    s: ^Buffer_Usage_Scope,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
    out_current: ^Buffer_Uses = nil,
    out_new: ^Buffer_Uses = nil,
) -> bool {
    buffer_usage_scope_allow_index(s, index)
    start_provider := Buffer_State_Provider {
        direct = uses,
    }
    resource_provider := Buffer_Metadata_Provider {
        direct = buffer,
    }
    return buffer_usage_scope_insert_or_merge(
        s,
        index,
        &start_provider,
        &resource_provider,
        out_current,
        out_new,
    )
}

// Merge every buffer of a bind group into the scope.
buffer_usage_scope_merge_bind_group :: proc(
    s: ^Buffer_Usage_Scope,
    group: ^Buffer_Bind_Group_State,
    out_current: ^Buffer_Uses = nil,
    out_new: ^Buffer_Uses = nil,
) -> bool {
    for &entry in group.buffers {
        if !buffer_usage_scope_merge_single(
            s,
            entry.index,
            entry.buffer,
            entry.uses,
            out_current,
            out_new,
        ) {
            return false
        }
    }
    return true
}

// Merge all of another scope's members into this one.
buffer_usage_scope_merge_usage_scope :: proc(
    s: ^Buffer_Usage_Scope,
    other: ^Buffer_Usage_Scope,
    out_current: ^Buffer_Uses = nil,
    out_new: ^Buffer_Uses = nil,
) -> bool {
    if u32(len(other.state)) > u32(len(s.state)) {
        buffer_usage_scope_set_size(s, u32(len(other.state)))
    }
    it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&it, &other.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        start_provider := Buffer_State_Provider {
            state = other.state[:],
        }
        resource_provider := Buffer_Metadata_Provider {
            metadata = &other.metadata,
        }
        if !buffer_usage_scope_insert_or_merge(
            s,
            index,
            &start_provider,
            &resource_provider,
            out_current,
            out_new,
        ) {
            return false
        }
    }
    return true
}

// Remove `uses` from a buffer's state, dropping the member when nothing is left.
// Undoes a use that only one command in a pass needed.
buffer_usage_scope_remove_usage :: proc(
    s: ^Buffer_Usage_Scope,
    index: Tracker_Index,
    uses: Buffer_Uses,
) {
    if !resource_metadata_contains(&s.metadata, index) {
        return
    }
    s.state[u32(index)] &~= uses
    if s.state[u32(index)] == {} {
        resource_metadata_remove(&s.metadata, index)
    }
}

// Insert the buffer on first contact, merge it otherwise.
buffer_usage_scope_insert_or_merge :: proc(
    s: ^Buffer_Usage_Scope,
    index: Tracker_Index,
    uses_provider: ^Buffer_State_Provider,
    resource_provider: ^Buffer_Metadata_Provider,
    out_current: ^Buffer_Uses,
    out_new: ^Buffer_Uses,
) -> bool {
    if !resource_metadata_contains(&s.metadata, index) {
        buffer_insert(nil, s.state[:], &s.metadata, index, uses_provider^, nil, resource_provider^)
        return true
    }

    current := s.state[u32(index)]
    added := buffer_state_provider_get(uses_provider^, index)
    if buffer_uses_is_invalid(current | added) {
        if out_current != nil {
            out_current^ = current
        }
        if out_new != nil {
            out_new^ = added
        }
        return false
    }
    s.state[u32(index)] = current | added
    return true
}

// Where a merge reads a use set from: another array, or one value.
Buffer_State_Provider :: struct {
    // Non-nil: read `state[index]` instead of `direct`.
    state:  []Buffer_Uses,
    direct: Buffer_Uses,
}

buffer_state_provider_get :: #force_inline proc "contextless" (
    p: Buffer_State_Provider,
    index: Tracker_Index,
) -> Buffer_Uses {
    if p.state != nil {
        return p.state[u32(index)]
    }
    return p.direct
}

// Where a merge reads the resource handle from: another metadata, or one value.
Buffer_Metadata_Provider :: struct {
    metadata: ^Resource_Metadata(Buffer),
    direct:   Buffer,
}

buffer_metadata_provider_get :: #force_inline proc(
    p: Buffer_Metadata_Provider,
    index: Tracker_Index,
) -> Buffer {
    if p.metadata != nil {
        return resource_metadata_get(p.metadata, index)
    }
    return p.direct
}

// One command buffer's buffer transcript.
Buffer_Tracker :: struct {
    // The state assumed on entry, per index.
    start:    [dynamic]Buffer_Uses,
    // The state left behind, per index.
    end:      [dynamic]Buffer_Uses,
    // Which indices are in the transcript, and which buffer each names.
    metadata: Resource_Metadata(Buffer),
    // Transitions this command buffer owes itself.
    temp:     [dynamic]Buffer_State_Transition,
    ordered:  Buffer_Uses,
}

buffer_tracker_init :: proc(
    t: ^Buffer_Tracker,
    allocator: runtime.Allocator,
    ordered: Buffer_Uses,
) {
    t^ = {}
    t.start.allocator = allocator
    t.end.allocator = allocator
    t.temp.allocator = allocator
    resource_metadata_init(&t.metadata, allocator)
    t.ordered = ordered
}

buffer_tracker_free :: proc(t: ^Buffer_Tracker) {
    delete(t.start)
    delete(t.end)
    delete(t.temp)
    resource_metadata_free(&t.metadata)
    t^ = {}
}

// Drop the transcript, keeping the storage; the ordering policy stays.
buffer_tracker_clear :: proc(t: ^Buffer_Tracker) {
    clear(&t.start)
    clear(&t.end)
    clear(&t.temp)
    resource_metadata_clear(&t.metadata)
}

buffer_tracker_set_size :: proc(t: ^Buffer_Tracker, size: u32) {
    for u32(len(t.start)) < size {
        append(&t.start, Buffer_Uses{})
        append(&t.end, Buffer_Uses{})
    }
    resource_metadata_set_size(&t.metadata, size)
}

buffer_tracker_allow_index :: proc(t: ^Buffer_Tracker, index: Tracker_Index) {
    if u32(index) >= u32(len(t.start)) {
        buffer_tracker_set_size(t, u32(index) + 1)
    }
}

buffer_tracker_contains :: #force_inline proc "contextless" (
    t: ^Buffer_Tracker,
    index: Tracker_Index,
) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

// Move a single buffer to `uses`, recording the transition it needs.
buffer_tracker_set_single :: proc(
    t: ^Buffer_Tracker,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
) {
    buffer_tracker_allow_index(t, index)
    start_provider := Buffer_State_Provider {
        direct = uses,
    }
    resource := Buffer_Metadata_Provider {
        direct = buffer,
    }
    buffer_tracker_insert_or_barrier_update(t, index, start_provider, nil, resource)
}

// Adopt another tracker's `start` as this transcript's start and its `end` as its
// end, recording the transitions in between.
buffer_tracker_set_from_tracker :: proc(t: ^Buffer_Tracker, other: ^Buffer_Tracker) {
    if u32(len(other.start)) > u32(len(t.start)) {
        buffer_tracker_set_size(t, u32(len(other.start)))
    }
    it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&it, &other.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        start_provider := Buffer_State_Provider {
            state = other.start[:],
        }
        end_provider := Buffer_State_Provider {
            state = other.end[:],
        }
        resource := Buffer_Metadata_Provider {
            metadata = &other.metadata,
        }
        buffer_tracker_insert_or_barrier_update(t, index, start_provider, &end_provider, resource)
    }
}

// Adopt every member of a usage scope, starting and ending at its state.
buffer_tracker_set_from_usage_scope :: proc(t: ^Buffer_Tracker, scope: ^Buffer_Usage_Scope) {
    if u32(len(scope.state)) > u32(len(t.start)) {
        buffer_tracker_set_size(t, u32(len(scope.state)))
    }
    it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&it, &scope.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        start_provider := Buffer_State_Provider {
            state = scope.state[:],
        }
        resource := Buffer_Metadata_Provider {
            metadata = &scope.metadata,
        }
        buffer_tracker_insert_or_barrier_update(t, index, start_provider, nil, resource)
    }
}

// Adopt the members named by `indices` and remove them from the scope, so a later
// merge in the same pass does not see them again. This is how a compute pass
// moves one dispatch's bindings into its transcript.
buffer_tracker_set_and_remove_from_usage_scope_sparse :: proc(
    t: ^Buffer_Tracker,
    scope: ^Buffer_Usage_Scope,
    indices: []Tracker_Index,
) {
    if len(scope.state) > len(t.start) {
        buffer_tracker_set_size(t, u32(len(scope.state)))
    }
    for index in indices {
        // A scope member the caller did not add is a caller bug; skipping keeps it
        // from turning into a state for a buffer that was never used.
        if !resource_metadata_contains(&scope.metadata, index) {
            continue
        }
        start_provider := Buffer_State_Provider {
            state = scope.state[:],
        }
        resource := Buffer_Metadata_Provider {
            metadata = &scope.metadata,
        }
        buffer_tracker_insert_or_barrier_update(t, index, start_provider, nil, resource)
        resource_metadata_remove(&scope.metadata, index)
    }
}

// Drop the transitions collected so far.
buffer_tracker_clear_pending :: proc(t: ^Buffer_Tracker) {
    clear(&t.temp)
}

// Insert on first contact, record a transition and advance otherwise.
buffer_tracker_insert_or_barrier_update :: proc(
    t: ^Buffer_Tracker,
    index: Tracker_Index,
    start_provider: Buffer_State_Provider,
    end_provider: ^Buffer_State_Provider,
    resource: Buffer_Metadata_Provider,
) {
    // A recycled pool slot whose previous entry is still here: the device tracker
    // defers `forget` while a release is parked, so the state the old resource left
    // must not be inherited by the new one. The generation in the handle tells them
    // apart.
    if resource_metadata_contains(&t.metadata, index) &&
       resource_metadata_get(&t.metadata, index) != buffer_metadata_provider_get(resource, index) {
        resource_metadata_remove(&t.metadata, index)
    }
    if !resource_metadata_contains(&t.metadata, index) {
        buffer_insert(
            t.start[:],
            t.end[:],
            &t.metadata,
            index,
            start_provider,
            end_provider,
            resource,
        )
        return
    }

    buffer_barrier(
        t.end[:],
        index,
        buffer_metadata_provider_get(resource, index),
        start_provider,
        &t.temp,
        t.ordered,
    )
    update_provider := start_provider
    if end_provider != nil {
        update_provider = end_provider^
    }
    buffer_update(t.end[:], index, update_provider)
}

// The device's authoritative buffer state.
Device_Buffer_Tracker :: struct {
    current:  [dynamic]Buffer_Uses,
    metadata: Resource_Metadata(Buffer),
    ordered:  Buffer_Uses,
}

device_buffer_tracker_init :: proc(
    t: ^Device_Buffer_Tracker,
    allocator: runtime.Allocator,
    ordered: Buffer_Uses,
) {
    t^ = {}
    t.current.allocator = allocator
    resource_metadata_init(&t.metadata, allocator)
    t.ordered = ordered
}

device_buffer_tracker_free :: proc(t: ^Device_Buffer_Tracker) {
    delete(t.current)
    resource_metadata_free(&t.metadata)
    t^ = {}
}

device_buffer_tracker_clear :: proc(t: ^Device_Buffer_Tracker) {
    clear(&t.current)
    resource_metadata_clear(&t.metadata)
}

device_buffer_tracker_allow_index :: proc(t: ^Device_Buffer_Tracker, index: Tracker_Index) {
    for u32(len(t.current)) <= u32(index) {
        append(&t.current, Buffer_Uses{})
    }
    resource_metadata_set_size(&t.metadata, u32(index) + 1)
}

// Make sure `index` holds *this* buffer's state and nothing else's: a pool slot is
// not an identity, so a buffer created into a slot a released buffer used to occupy
// must not inherit that buffer's use. The metadata stores the whole handle, the
// generation included, which is what tells them apart.
device_buffer_tracker_prepare :: proc(
    t: ^Device_Buffer_Tracker,
    index: Tracker_Index,
    buffer: Buffer,
) {
    device_buffer_tracker_allow_index(t, index)
    if resource_metadata_contains(&t.metadata, index) {
        if resource_metadata_get(&t.metadata, index) == buffer {
            return
        }
        resource_metadata_remove(&t.metadata, index)
    }
    t.current[u32(index)] = {}
}

// Overwrite a buffer's state without emitting a transition.
device_buffer_tracker_insert_single :: proc(
    t: ^Device_Buffer_Tracker,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
) {
    device_buffer_tracker_allow_index(t, index)
    t.current[u32(index)] = uses
    resource_metadata_insert(&t.metadata, index, buffer)
}

// Move one buffer to `uses`, appending the transition the current state needs.
// Grows on demand, so no presize call is a precondition.
device_buffer_tracker_set_single :: proc(
    t: ^Device_Buffer_Tracker,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
    out: ^[dynamic]Buffer_State_Transition,
) {
    device_buffer_tracker_prepare(t, index, buffer)
    provider := Buffer_State_Provider {
        direct = uses,
    }
    buffer_barrier(t.current[:], index, buffer, provider, out, t.ordered)
    t.current[u32(index)] = uses
    resource_metadata_insert(&t.metadata, index, buffer)
}

// Move the device state to a command buffer's `start`, then to its `end`, appending
// both sets of transitions.
device_buffer_tracker_set_from_tracker_and_drain_transitions :: proc(
    t: ^Device_Buffer_Tracker,
    tracker: ^Buffer_Tracker,
    out: ^[dynamic]Buffer_State_Transition,
) {
    it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&it, &tracker.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        buffer := resource_metadata_get(&tracker.metadata, index)
        device_buffer_tracker_prepare(t, index, buffer)
        start_provider := Buffer_State_Provider {
            state = tracker.start[:],
        }
        buffer_barrier(t.current[:], index, buffer, start_provider, out, t.ordered)
        t.current[u32(index)] = tracker.end[u32(index)]
        resource_metadata_insert(&t.metadata, index, buffer)
    }
}

// Move the device state to a usage scope's state, appending the transitions.
device_buffer_tracker_set_from_usage_scope_and_drain_transitions :: proc(
    t: ^Device_Buffer_Tracker,
    scope: ^Buffer_Usage_Scope,
    out: ^[dynamic]Buffer_State_Transition,
) {
    it: Metadata_Index_Iterator(Buffer)
    metadata_index_iterator_init(&it, &scope.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        buffer := resource_metadata_get(&scope.metadata, index)
        device_buffer_tracker_prepare(t, index, buffer)
        start_provider := Buffer_State_Provider {
            state = scope.state[:],
        }
        buffer_barrier(t.current[:], index, buffer, start_provider, out, t.ordered)
        t.current[u32(index)] = scope.state[u32(index)]
        resource_metadata_insert(&t.metadata, index, buffer)
    }
}

// Forget a buffer's state, so a recycled index cannot inherit it.
device_buffer_tracker_forget :: proc(t: ^Device_Buffer_Tracker, index: Tracker_Index) {
    resource_metadata_remove(&t.metadata, index)
}

// The state a buffer is in, or `BUFFER_USES_UNINITIALIZED` when the tracker has not
// seen it.
device_buffer_tracker_state_at :: proc(
    t: ^Device_Buffer_Tracker,
    index: Tracker_Index,
    buffer: Buffer,
) -> Buffer_Uses {
    // The slot may have been recycled: the metadata entry is what says which
    // resource the state belongs to.
    if !resource_metadata_contains(&t.metadata, index) ||
       resource_metadata_get(&t.metadata, index) != buffer {
        return BUFFER_USES_UNINITIALIZED
    }
    return t.current[u32(index)]
}

// First contact: write `start` and `end`, `end` defaulting to `start`.
buffer_insert :: proc(
    start: []Buffer_Uses,
    current: []Buffer_Uses,
    metadata: ^Resource_Metadata(Buffer),
    index: Tracker_Index,
    start_provider: Buffer_State_Provider,
    end_provider: ^Buffer_State_Provider,
    resource: Buffer_Metadata_Provider,
) {
    new_start := buffer_state_provider_get(start_provider, index)
    new_end := new_start
    if end_provider != nil {
        new_end = buffer_state_provider_get(end_provider^, index)
    }
    if start != nil {
        start[u32(index)] = new_start
    }
    current[u32(index)] = new_end
    resource_metadata_insert(metadata, index, buffer_metadata_provider_get(resource, index))
}

// Append the transition that moves `states[index]` to `to`, unless the move needs
// none: an unchanged state drawn only from the ordered set is already ordered by
// the hardware.
buffer_barrier :: proc(
    states: []Buffer_Uses,
    index: Tracker_Index,
    buffer: Buffer,
    to: Buffer_State_Provider,
    out: ^[dynamic]Buffer_State_Transition,
    ordered: Buffer_Uses,
) {
    current := states[u32(index)]
    target := buffer_state_provider_get(to, index)
    if current == target && (buffer_uses_bits(current) & ~buffer_uses_bits(ordered)) == 0 {
        return
    }
    append(out, Buffer_State_Transition{buffer = buffer, from = current, to = target})
}

// Record a state without emitting anything.
buffer_update :: proc(states: []Buffer_Uses, index: Tracker_Index, to: Buffer_State_Provider) {
    states[u32(index)] = buffer_state_provider_get(to, index)
}

// -----------------------------------------------------------------------------
// Texture
// -----------------------------------------------------------------------------

// Texture trackers.
//
// A texture's state is either *simple* (one use set valid for every subresource)
// or *complex* (each mip's array layers split into ranges, each with its own set).
// Complexity is rare and expensive, so the two live in separate tables: a flat
// array of simple states plus a sparse array of complex states. Only a use that
// actually differs across subresources promotes a texture, and demoting it back to
// one state is just as explicit.
//
// Two special sets drive the rules:
//
// - `Unknown` means the tracker knows nothing about a subresource. It is never a
//   barrier's source or target, and it is what a complex state starts as.
// - `Uninitialized` means the tracker knows the contents are undefined, so a
//   transition away from it discards them.
//
// The primitives at the bottom — insert, merge, barrier, update — each have four
// arms, one per simple/complex combination on either side. Everything else is
// bookkeeping.

// The most mip levels a texture can have.
MAX_MIP_LEVELS :: 16

// The layer states of every mip of one texture, each mip's layers partitioned into
// ranges that carry one use set.
Complex_Texture_State :: struct {
    allocator: runtime.Allocator,
    mip_count: u32,
    mips:      [MAX_MIP_LEVELS]Ranged_States(Texture_Uses),
}

// Start from `initial` over every subresource: each mip's whole layer range is one
// entry. A complex state is born all-`Unknown` and gains detail as uses split it.
complex_texture_state_init :: proc(
    c: ^Complex_Texture_State,
    allocator: runtime.Allocator,
    mip_count, layer_count: u32,
    initial: Texture_Uses,
    loc := #caller_location,
) {
    assert(mip_count <= MAX_MIP_LEVELS, "mip count past the texture limit", loc = loc)
    c.allocator = allocator
    c.mip_count = mip_count
    for m in 0 ..< mip_count {
        ranged_states_init(&c.mips[m], allocator)
        ranged_states_set_single(&c.mips[m], 0, layer_count, initial)
    }
}

complex_texture_state_free :: proc(c: ^Complex_Texture_State) {
    for m in 0 ..< c.mip_count {
        ranged_states_free(&c.mips[m])
    }
    c.mip_count = 0
}

// Deep copy `source` into this state, which must be empty.
complex_texture_state_copy_from :: proc(
    c: ^Complex_Texture_State,
    source: ^Complex_Texture_State,
    loc := #caller_location,
) {
    assert(c.mip_count == 0, "copying into a complex state that has mips", loc = loc)
    c.mip_count = source.mip_count
    for m in 0 ..< source.mip_count {
        ranged_states_init(&c.mips[m], c.allocator)
        reserve(&c.mips[m].ranges, len(source.mips[m].ranges))
        for entry in source.mips[m].ranges {
            append(&c.mips[m].ranges, entry)
        }
    }
}

// Set every subresource of `selector` to `value`, splitting the ranges it crosses
// and coalescing what it leaves equal. `Unknown` entries it covers are replaced,
// which is how a state gains its first real knowledge of a subresource.
complex_texture_state_assign :: proc(
    c: ^Complex_Texture_State,
    selector: Texture_Selector,
    value: Texture_Uses,
    loc := #caller_location,
) {
    mip_end := selector.mip_start + selector.mip_count
    layer_end := selector.layer_start + selector.layer_count
    assert(mip_end <= c.mip_count, "selector past the tracked mips", loc = loc)
    for m in selector.mip_start ..< mip_end {
        mip := &c.mips[m]
        i := ranged_states_isolate(mip, selector.layer_start, layer_end, TEXTURE_USES_UNKNOWN)
        for ; i < len(mip.ranges) && mip.ranges[i].start < layer_end; i += 1 {
            mip.ranges[i].value = value
        }
        ranged_states_coalesce(mip)
    }
}

// One texture view's use: which texture it reads, which subresources, and with
// which use. The tracker is keyed by texture, so a bind group's views are resolved
// to their parent's index and range when the bind group is created.
Texture_View_Use :: struct {
    view:     Texture_View,
    texture:  Tracked_Texture,
    selector: Texture_Selector,
    uses:     Texture_Uses,
}

Texture_View_Bind_Group_State :: struct {
    views: [dynamic]Texture_View_Use,
}

texture_view_bind_group_state_init :: proc(
    s: ^Texture_View_Bind_Group_State,
    allocator: runtime.Allocator,
) {
    s.views = nil
    s.views.allocator = allocator
}

texture_view_bind_group_state_free :: proc(s: ^Texture_View_Bind_Group_State) {
    delete(s.views)
    s.views = nil
}

texture_view_bind_group_state_clear :: proc(s: ^Texture_View_Bind_Group_State) {
    clear(&s.views)
}

texture_view_bind_group_state_len :: #force_inline proc "contextless" (
    s: ^Texture_View_Bind_Group_State,
) -> int {
    return len(s.views)
}

texture_view_bind_group_state_insert_single :: proc(
    s: ^Texture_View_Bind_Group_State,
    view: Texture_View,
    texture: Tracked_Texture,
    selector: Texture_Selector,
    uses: Texture_Uses,
) {
    append(
        &s.views,
        Texture_View_Use{view = view, texture = texture, selector = selector, uses = uses},
    )
}

// Sort by parent texture index, so a merge walks the tracker forward.
texture_view_bind_group_state_optimize :: proc(s: ^Texture_View_Bind_Group_State) {
    for i in 1 ..< len(s.views) {
        entry := s.views[i]
        j := i
        for j > 0 && u32(s.views[j - 1].texture.index) > u32(entry.texture.index) {
            s.views[j] = s.views[j - 1]
            j -= 1
        }
        s.views[j] = entry
    }
}

// Per-texture state: a flat array of simple states and a sparse array of complex
// ones, indexed by tracker index. A non-nil complex entry is what makes a texture
// complex; the simple slot then holds `Complex` as a marker.
Texture_State_Set :: struct {
    allocator: runtime.Allocator,
    simple:    [dynamic]Texture_Uses,
    complex:   [dynamic]^Complex_Texture_State,
}

texture_state_set_init :: proc(set: ^Texture_State_Set, allocator: runtime.Allocator) {
    set^ = {}
    set.allocator = allocator
    set.simple.allocator = allocator
    set.complex.allocator = allocator
}

texture_state_set_free :: proc(set: ^Texture_State_Set) {
    for state in set.complex {
        if state == nil {
            continue
        }
        complex_texture_state_free(state)
        free(state, set.allocator)
    }
    delete(set.simple)
    delete(set.complex)
    set^ = {}
}

// Drop every state, keeping the tables for reuse.
texture_state_set_clear :: proc(set: ^Texture_State_Set) {
    for i in 0 ..< len(set.complex) {
        state := set.complex[i]
        if state == nil {
            continue
        }
        complex_texture_state_free(state)
        free(state, set.allocator)
        set.complex[i] = nil
    }
    clear(&set.simple)
    clear(&set.complex)
}

// Presize both tables for indices below `size`.
texture_state_set_set_size :: proc(set: ^Texture_State_Set, size: u32) {
    for u32(len(set.simple)) < size {
        append(&set.simple, TEXTURE_USES_UNINITIALIZED)
    }
    for u32(len(set.complex)) < size {
        append(&set.complex, nil)
    }
}

texture_state_set_is_complex :: #force_inline proc "contextless" (
    set: ^Texture_State_Set,
    index: Tracker_Index,
) -> bool {
    return set.complex[u32(index)] != nil
}

texture_state_set_complex_at :: #force_inline proc "contextless" (
    set: ^Texture_State_Set,
    index: Tracker_Index,
) -> ^Complex_Texture_State {
    return set.complex[u32(index)]
}

// Record one state for the whole texture, dropping any complex state.
texture_state_set_insert_simple :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
    state: Texture_Uses,
) {
    texture_state_set_release_complex(set, index)
    set.simple[u32(index)] = state
}

// Record a copy of `source` as this index's complex state.
texture_state_set_insert_complex :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
    source: ^Complex_Texture_State,
) {
    slot := texture_state_set_take_complex(set, index)
    complex_texture_state_copy_from(slot, source)
}

// Collapse this index to one state, freeing its complex state.
texture_state_set_make_simple :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
    state: Texture_Uses,
) {
    texture_state_set_insert_simple(set, index, state)
}

// Promote this index to a complex state and return the empty slot to fill. The
// slot starts with no mips: the caller builds it from `full`.
texture_state_set_make_complex :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
) -> ^Complex_Texture_State {
    return texture_state_set_take_complex(set, index)
}

texture_state_set_release_complex :: proc(set: ^Texture_State_Set, index: Tracker_Index) {
    state := set.complex[u32(index)]
    if state == nil {
        return
    }
    complex_texture_state_free(state)
    free(state, set.allocator)
    set.complex[u32(index)] = nil
}

// The slot for a complex state: the existing one with its mips freed, or a fresh
// one. The simple slot becomes the `Complex` marker either way.
texture_state_set_take_complex :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
) -> ^Complex_Texture_State {
    state := set.complex[u32(index)]
    if state == nil {
        state = new(Complex_Texture_State, set.allocator)
        state.allocator = set.allocator
        set.complex[u32(index)] = state
    } else {
        complex_texture_state_free(state)
    }
    set.simple[u32(index)] = TEXTURE_USES_COMPLEX
    return state
}

// Where a set operation reads its states from: one state for the whole texture, a
// state for one selector, or another state set.
Texture_Provider_Kind :: enum {
    Known_Single,
    Selector,
    Texture_Set,
}

Texture_State_Provider :: struct {
    kind:     Texture_Provider_Kind,
    // Selector: the subresources, in the texture's own coordinates.
    selector: Texture_Selector,
    // Known_Single and Selector: the state to apply.
    state:    Texture_Uses,
    // Texture_Set: where the states come from.
    set:      ^Texture_State_Set,
}

texture_state_provider_single :: proc(state: Texture_Uses) -> Texture_State_Provider {
    return {kind = .Known_Single, state = state}
}

texture_state_provider_selector :: proc(
    selector: Texture_Selector,
    state: Texture_Uses,
) -> Texture_State_Provider {
    return {kind = .Selector, selector = selector, state = state}
}

texture_state_provider_set :: proc(set: ^Texture_State_Set) -> Texture_State_Provider {
    return {kind = .Texture_Set, set = set}
}

// True when the provider has exactly one state for the whole texture, which is the
// cheap arm of every primitive: the whole-range selector collapses to it.
texture_state_provider_is_single :: #force_inline proc "contextless" (
    p: Texture_State_Provider,
    full: Texture_Selector,
    index: Tracker_Index,
) -> bool {
    switch p.kind {
    case .Known_Single:
        return true
    case .Selector:
        return texture_selector_equals(p.selector, full)
    case .Texture_Set:
        return !texture_state_set_is_complex(p.set, index)
    }
    return false
}

// The single state this provider yields; only for `texture_state_provider_is_single`.
texture_state_provider_single_state :: #force_inline proc "contextless" (
    p: Texture_State_Provider,
    index: Tracker_Index,
) -> Texture_Uses {
    if p.kind == .Texture_Set {
        return p.set.simple[u32(index)]
    }
    return p.state
}

// Fill a complex state (already sized from `full`) with this provider's states.
// Only for the non-single case: a single state is written directly.
texture_state_provider_fill_complex :: proc(
    p: Texture_State_Provider,
    out: ^Complex_Texture_State,
    index: Tracker_Index,
) {
    switch p.kind {
    case .Selector:
        complex_texture_state_assign(out, p.selector, p.state)
    case .Texture_Set:
        source := texture_state_set_complex_at(p.set, index)
        for m in 0 ..< source.mip_count {
            for &range in source.mips[m].ranges {
                complex_texture_state_assign(out, {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    }, range.value)
            }
        }
    case .Known_Single:
        // `texture_state_provider_is_single` would have been true.
        panic_contextless("a single state is not complex")
    }
}

// One pass's or one bind group's merged texture uses.
Texture_Usage_Scope :: struct {
    set:      Texture_State_Set,
    metadata: Resource_Metadata(Tracked_Texture),
    ordered:  Texture_Uses,
}

texture_usage_scope_init :: proc(s: ^Texture_Usage_Scope, allocator: runtime.Allocator) {
    texture_state_set_init(&s.set, allocator)
    resource_metadata_init(&s.metadata, allocator)
    s.ordered = {}
}

texture_usage_scope_free :: proc(s: ^Texture_Usage_Scope) {
    texture_state_set_free(&s.set)
    resource_metadata_free(&s.metadata)
    s^ = {}
}

texture_usage_scope_clear :: proc(s: ^Texture_Usage_Scope) {
    texture_state_set_clear(&s.set)
    resource_metadata_clear(&s.metadata)
}

texture_usage_scope_set_size :: proc(s: ^Texture_Usage_Scope, size: u32) {
    texture_state_set_set_size(&s.set, size)
    resource_metadata_set_size(&s.metadata, size)
}

texture_usage_scope_set_ordered_uses_mask :: proc(s: ^Texture_Usage_Scope, mask: Texture_Uses) {
    s.ordered = mask
}

texture_usage_scope_allow_index :: proc(s: ^Texture_Usage_Scope, index: Tracker_Index) {
    if u32(index) >= u32(len(s.set.simple)) {
        texture_usage_scope_set_size(s, u32(index) + 1)
    }
}

// Merge one texture range's use into the scope. False is a usage conflict,
// reported as the state the scope had and the use it was offered, for the
// subresources that could not coexist.
texture_usage_scope_merge_single :: proc(
    s: ^Texture_Usage_Scope,
    texture: Tracked_Texture,
    has_selector: bool,
    selector: Texture_Selector,
    uses: Texture_Uses,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    index := texture.index
    texture_usage_scope_allow_index(s, index)
    provider :=
        has_selector ? texture_state_provider_selector(selector, uses) : texture_state_provider_single(uses)
    return texture_usage_scope_insert_or_merge(
        s,
        index,
        texture,
        provider,
        out_selector,
        out_current,
        out_new,
    )
}

// Merge every view of a bind group into the scope.
texture_usage_scope_merge_bind_group :: proc(
    s: ^Texture_Usage_Scope,
    group: ^Texture_View_Bind_Group_State,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    for &view in group.views {
        if !texture_usage_scope_merge_single(
            s,
            view.texture,
            true,
            view.selector,
            view.uses,
            out_selector,
            out_current,
            out_new,
        ) {
            return false
        }
    }
    return true
}

// Merge all of another scope's members into this one.
texture_usage_scope_merge_usage_scope :: proc(
    s: ^Texture_Usage_Scope,
    other: ^Texture_Usage_Scope,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    if u32(len(other.set.simple)) > u32(len(s.set.simple)) {
        texture_usage_scope_set_size(s, u32(len(other.set.simple)))
    }
    it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&it, &other.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        provider := texture_state_provider_set(&other.set)
        if !texture_usage_scope_insert_or_merge(
            s,
            index,
            resource_metadata_get(&other.metadata, index),
            provider,
            out_selector,
            out_current,
            out_new,
        ) {
            return false
        }
    }
    return true
}

texture_usage_scope_insert_or_merge :: proc(
    s: ^Texture_Usage_Scope,
    index: Tracker_Index,
    texture: Tracked_Texture,
    provider: Texture_State_Provider,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    if !resource_metadata_contains(&s.metadata, index) {
        texture_insert(nil, &s.set, &s.metadata, index, texture, provider, nil)
        return true
    }
    return texture_merge(&s.set, index, texture, provider, out_selector, out_current, out_new)
}

// One command buffer's texture transcript.
Texture_Tracker :: struct {
    start:    Texture_State_Set,
    end:      Texture_State_Set,
    metadata: Resource_Metadata(Tracked_Texture),
    temp:     [dynamic]Texture_State_Transition,
    ordered:  Texture_Uses,
}

texture_tracker_init :: proc(
    t: ^Texture_Tracker,
    allocator: runtime.Allocator,
    ordered: Texture_Uses,
) {
    t^ = {}
    texture_state_set_init(&t.start, allocator)
    texture_state_set_init(&t.end, allocator)
    resource_metadata_init(&t.metadata, allocator)
    t.temp.allocator = allocator
    t.ordered = ordered
}

texture_tracker_free :: proc(t: ^Texture_Tracker) {
    texture_state_set_free(&t.start)
    texture_state_set_free(&t.end)
    resource_metadata_free(&t.metadata)
    delete(t.temp)
    t^ = {}
}

texture_tracker_clear :: proc(t: ^Texture_Tracker) {
    texture_state_set_clear(&t.start)
    texture_state_set_clear(&t.end)
    resource_metadata_clear(&t.metadata)
    clear(&t.temp)
}

texture_tracker_set_size :: proc(t: ^Texture_Tracker, size: u32) {
    texture_state_set_set_size(&t.start, size)
    texture_state_set_set_size(&t.end, size)
    resource_metadata_set_size(&t.metadata, size)
}

texture_tracker_allow_index :: proc(t: ^Texture_Tracker, index: Tracker_Index) {
    if u32(index) >= u32(len(t.start.simple)) {
        texture_tracker_set_size(t, u32(index) + 1)
    }
}

texture_tracker_contains :: #force_inline proc "contextless" (
    t: ^Texture_Tracker,
    index: Tracker_Index,
) -> bool {
    return resource_metadata_contains(&t.metadata, index)
}

// Move one texture range to `uses`, recording the transitions it needs.
texture_tracker_set_single :: proc(
    t: ^Texture_Tracker,
    texture: Tracked_Texture,
    selector: Texture_Selector,
    uses: Texture_Uses,
) {
    index := texture.index
    texture_tracker_allow_index(t, index)
    provider := texture_state_provider_selector(selector, uses)
    texture_tracker_insert_or_barrier_update(t, index, texture, provider, nil)
}

// Adopt another tracker: its start becomes this transcript's start, its end
// becomes the end.
texture_tracker_set_from_tracker :: proc(t: ^Texture_Tracker, other: ^Texture_Tracker) {
    if u32(len(other.start.simple)) > u32(len(t.start.simple)) {
        texture_tracker_set_size(t, u32(len(other.start.simple)))
    }
    it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&it, &other.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        texture := resource_metadata_get(&other.metadata, index)
        end_provider := texture_state_provider_set(&other.end)
        texture_tracker_insert_or_barrier_update(
            t,
            index,
            texture,
            texture_state_provider_set(&other.start),
            &end_provider,
        )
    }
}

// Adopt every member of a usage scope, starting and ending at its state.
texture_tracker_set_from_usage_scope :: proc(t: ^Texture_Tracker, scope: ^Texture_Usage_Scope) {
    if u32(len(scope.set.simple)) > u32(len(t.start.simple)) {
        texture_tracker_set_size(t, u32(len(scope.set.simple)))
    }
    it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&it, &scope.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        texture_tracker_insert_or_barrier_update(
            t,
            index,
            resource_metadata_get(&scope.metadata, index),
            texture_state_provider_set(&scope.set),
            nil,
        )
    }
}

// Adopt the textures a bind group's views name and remove them from the scope, so
// a later merge in the same pass does not see them again. The scope's state is
// adopted over the texture's full range, since the scope already merged every view
// of it.
texture_tracker_set_and_remove_from_usage_scope_sparse :: proc(
    t: ^Texture_Tracker,
    scope: ^Texture_Usage_Scope,
    views: ^Texture_View_Bind_Group_State,
) {
    if u32(len(scope.set.simple)) > u32(len(t.start.simple)) {
        texture_tracker_set_size(t, u32(len(scope.set.simple)))
    }
    for &view in views.views {
        index := view.texture.index
        if !resource_metadata_contains(&scope.metadata, index) {
            continue
        }
        texture_tracker_insert_or_barrier_update(
            t,
            index,
            resource_metadata_get(&scope.metadata, index),
            texture_state_provider_set(&scope.set),
            nil,
        )
        resource_metadata_remove(&scope.metadata, index)
    }
}

texture_tracker_clear_pending :: proc(t: ^Texture_Tracker) {
    clear(&t.temp)
}

// Insert on first contact, record transitions and advance otherwise.
texture_tracker_insert_or_barrier_update :: proc(
    t: ^Texture_Tracker,
    index: Tracker_Index,
    texture: Tracked_Texture,
    start_provider: Texture_State_Provider,
    end_provider: ^Texture_State_Provider,
) {
    // A recycled pool slot whose previous entry is still here: the device tracker
    // defers `forget` while a release is parked, so the state (and the subresource
    // table it may own) must not be inherited by the new resource. The generation in
    // the handle tells them apart.
    if resource_metadata_contains(&t.metadata, index) &&
       resource_metadata_get(&t.metadata, index).texture != texture.texture {
        texture_state_set_release_complex(&t.start, index)
        texture_state_set_release_complex(&t.end, index)
        resource_metadata_remove(&t.metadata, index)
    }
    if !resource_metadata_contains(&t.metadata, index) {
        texture_insert(&t.start, &t.end, &t.metadata, index, texture, start_provider, end_provider)
        return
    }

    texture_barrier(&t.end, index, texture, start_provider, &t.temp, t.ordered, false)
    update_provider := start_provider
    if end_provider != nil {
        update_provider = end_provider^
    }
    texture_update(&t.start, &t.end, index, texture, update_provider)
}

// The device's authoritative texture state.
Device_Texture_Tracker :: struct {
    current:  Texture_State_Set,
    metadata: Resource_Metadata(Tracked_Texture),
    ordered:  Texture_Uses,
}

device_texture_tracker_init :: proc(
    t: ^Device_Texture_Tracker,
    allocator: runtime.Allocator,
    ordered: Texture_Uses,
) {
    t^ = {}
    texture_state_set_init(&t.current, allocator)
    resource_metadata_init(&t.metadata, allocator)
    t.ordered = ordered
}

device_texture_tracker_free :: proc(t: ^Device_Texture_Tracker) {
    texture_state_set_free(&t.current)
    resource_metadata_free(&t.metadata)
    t^ = {}
}

device_texture_tracker_clear :: proc(t: ^Device_Texture_Tracker) {
    texture_state_set_clear(&t.current)
    resource_metadata_clear(&t.metadata)
}

device_texture_tracker_set_size :: proc(t: ^Device_Texture_Tracker, size: u32) {
    texture_state_set_set_size(&t.current, size)
    resource_metadata_set_size(&t.metadata, size)
}

// Overwrite a texture's state without emitting a transition.
device_texture_tracker_insert_single :: proc(
    t: ^Device_Texture_Tracker,
    texture: Tracked_Texture,
    uses: Texture_Uses,
) {
    index := texture.index
    if u32(index) >= u32(len(t.current.simple)) {
        device_texture_tracker_set_size(t, u32(index) + 1)
    }
    texture_state_set_insert_simple(&t.current, index, uses)
    resource_metadata_insert(&t.metadata, index, texture)
}

// Move one texture range to `uses`, appending the transitions the current state
// needs. Grows on demand, so no presize call is a precondition.
device_texture_tracker_set_single :: proc(
    t: ^Device_Texture_Tracker,
    texture: Tracked_Texture,
    selector: Texture_Selector,
    uses: Texture_Uses,
    out: ^[dynamic]Texture_State_Transition,
) {
    index := texture.index
    device_texture_tracker_prepare(t, index, texture)
    texture_barrier(
        &t.current,
        index,
        texture,
        texture_state_provider_selector(selector, uses),
        out,
        t.ordered,
        true,
    )
    texture_update(
        nil,
        &t.current,
        index,
        texture,
        texture_state_provider_selector(selector, uses),
    )
    resource_metadata_insert(&t.metadata, index, texture)
}

// Make sure `index` holds *this* texture's state and nothing else's.
//
// A pool slot is not an identity: the state array is indexed by slot, so a texture
// created into a slot a released texture used to occupy finds that texture's
// layout there. The metadata — which stores the whole handle, generation included —
// is what tells them apart, and a texture the device has never seen starts
// `Uninitialized`, exactly like a fresh slot does.
device_texture_tracker_prepare :: proc(
    t: ^Device_Texture_Tracker,
    index: Tracker_Index,
    texture: Tracked_Texture,
) {
    if u32(index) >= u32(len(t.current.simple)) {
        device_texture_tracker_set_size(t, u32(index) + 1)
    }
    if resource_metadata_contains(&t.metadata, index) {
        if resource_metadata_get(&t.metadata, index).texture == texture.texture {
            return
        }
        texture_state_set_release_complex(&t.current, index)
        resource_metadata_remove(&t.metadata, index)
    }
    texture_state_set_insert_simple(&t.current, index, TEXTURE_USES_UNINITIALIZED)
}

// Move the device state to a command buffer's start, then to its end, appending
// both sets of transitions.
device_texture_tracker_set_from_tracker_and_drain_transitions :: proc(
    t: ^Device_Texture_Tracker,
    tracker: ^Texture_Tracker,
    out: ^[dynamic]Texture_State_Transition,
) {
    it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&it, &tracker.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        texture := resource_metadata_get(&tracker.metadata, index)
        device_texture_tracker_prepare(t, index, texture)
        texture_barrier(
            &t.current,
            index,
            texture,
            texture_state_provider_set(&tracker.start),
            out,
            t.ordered,
            // A subresource the device has never recorded is `Uninitialized`, so its
            // first use still gets the entry transition even though the state array
            // marks it `Unknown`.
            true,
        )
        texture_advance(&t.current, index, texture, &tracker.end)
        resource_metadata_insert(&t.metadata, index, texture)
    }
}

// Move the device state to a usage scope's state, appending the transitions.
device_texture_tracker_set_from_usage_scope_and_drain_transitions :: proc(
    t: ^Device_Texture_Tracker,
    scope: ^Texture_Usage_Scope,
    out: ^[dynamic]Texture_State_Transition,
) {
    it: Metadata_Index_Iterator(Tracked_Texture)
    metadata_index_iterator_init(&it, &scope.metadata)
    index: Tracker_Index
    for metadata_index_iterator_next(&it, &index) {
        texture := resource_metadata_get(&scope.metadata, index)
        device_texture_tracker_prepare(t, index, texture)
        texture_barrier(
            &t.current,
            index,
            texture,
            texture_state_provider_set(&scope.set),
            out,
            t.ordered,
            true,
        )
        texture_advance(&t.current, index, texture, &scope.set)
        resource_metadata_insert(&t.metadata, index, texture)
    }
}

// Forget a texture's state, freeing the subresource table it owns.
device_texture_tracker_forget :: proc(t: ^Device_Texture_Tracker, index: Tracker_Index) {
    if u32(index) >= u32(len(t.current.simple)) {
        return
    }
    texture_state_set_release_complex(&t.current, index)
    resource_metadata_remove(&t.metadata, index)
}

// The state a texture is in: its single state, `Complex` when its subresources
// disagree, or `Unknown` when the tracker has never seen it.
//
// Diagnostic only — it reads the *use* state a submission left behind, never the
// initialisation state (`Texture_Init_Tracker`), which lives on the texture.
device_texture_tracker_state_at :: proc(
    t: ^Device_Texture_Tracker,
    index: Tracker_Index,
    texture: Texture,
) -> Texture_Uses {
    // The slot may have been recycled: the metadata entry is what says which
    // resource the state belongs to.
    if !resource_metadata_contains(&t.metadata, index) ||
       resource_metadata_get(&t.metadata, index).texture != texture {
        return TEXTURE_USES_UNKNOWN
    }
    if texture_state_set_is_complex(&t.current, index) {
        return TEXTURE_USES_COMPLEX
    }
    return t.current.simple[u32(index)]
}

// The state of one subresource. A subresource the tracker knows nothing about
// answers `Unknown`, which is what a per-mip diagnostic has to report.
//
// Diagnostic only, like `device_texture_tracker_state_at`: the use state, not the
// initialisation state.
device_texture_tracker_subresource_state :: proc(
    t: ^Device_Texture_Tracker,
    index: Tracker_Index,
    texture: Texture,
    mip: u32,
    layer: u32,
) -> Texture_Uses {
    if !resource_metadata_contains(&t.metadata, index) ||
       resource_metadata_get(&t.metadata, index).texture != texture {
        return TEXTURE_USES_UNKNOWN
    }
    if !texture_state_set_is_complex(&t.current, index) {
        return t.current.simple[u32(index)]
    }
    complex := texture_state_set_complex_at(&t.current, index)
    if mip >= complex.mip_count {
        return TEXTURE_USES_UNKNOWN
    }
    for &range in complex.mips[mip].ranges {
        if layer >= range.start && layer < range.end {
            return range.value
        }
    }
    return TEXTURE_USES_UNKNOWN
}

// First contact: write start and end, `end` defaulting to `start`.
texture_insert :: proc(
    start: ^Texture_State_Set,
    end: ^Texture_State_Set,
    metadata: ^Resource_Metadata(Tracked_Texture),
    index: Tracker_Index,
    texture: Tracked_Texture,
    start_provider: Texture_State_Provider,
    end_provider: ^Texture_State_Provider,
) {
    full := texture.full

    if texture_state_provider_is_single(start_provider, full, index) {
        state := texture_state_provider_single_state(start_provider, index)
        if start != nil {
            texture_state_set_insert_simple(start, index, state)
        }
        if end_provider == nil {
            texture_state_set_insert_simple(end, index, state)
        }
    } else {
        built: Complex_Texture_State
        complex_texture_state_init(
            &built,
            end.allocator,
            full.mip_count,
            full.layer_count,
            TEXTURE_USES_UNKNOWN,
        )
        texture_state_provider_fill_complex(start_provider, &built, index)
        if start != nil {
            texture_state_set_insert_complex(start, index, &built)
        }
        if end_provider == nil {
            texture_state_set_insert_complex(end, index, &built)
        }
        complex_texture_state_free(&built)
    }

    if end_provider != nil {
        provider := end_provider^
        if texture_state_provider_is_single(provider, full, index) {
            texture_state_set_insert_simple(
                end,
                index,
                texture_state_provider_single_state(provider, index),
            )
        } else {
            built: Complex_Texture_State
            complex_texture_state_init(
                &built,
                end.allocator,
                full.mip_count,
                full.layer_count,
                TEXTURE_USES_UNKNOWN,
            )
            texture_state_provider_fill_complex(provider, &built, index)
            texture_state_set_insert_complex(end, index, &built)
            complex_texture_state_free(&built)
        }
    }

    resource_metadata_insert(metadata, index, texture)
}

// Merge a state into the set, refusing what the usage rules forbid. All four arms
// arrive from different directions: simple over simple is one OR, complex over
// simple applies to every entry, and either side being complex walks ranges.
texture_merge :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
    texture: Tracked_Texture,
    provider: Texture_State_Provider,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    full := texture.full
    new_single := texture_state_provider_is_single(provider, full, index)
    current_complex := texture_state_set_is_complex(set, index)

    if !current_complex && new_single {
        current := set.simple[u32(index)]
        added := texture_state_provider_single_state(provider, index)
        merged := current | added
        if texture_uses_is_invalid(merged) {
            out_selector^ = full
            out_current^ = current
            out_new^ = added
            return false
        }
        set.simple[u32(index)] = merged
        return true
    }

    if !current_complex {
        // Promoting: the whole texture starts at the current simple state, and only
        // the ranges the provider names change.
        current := set.simple[u32(index)]
        built: Complex_Texture_State
        complex_texture_state_init(
            &built,
            set.allocator,
            full.mip_count,
            full.layer_count,
            current,
        )
        ok := texture_merge_into_complex(
            &built,
            provider,
            index,
            out_selector,
            out_current,
            out_new,
        )
        if ok {
            texture_state_set_insert_complex(set, index, &built)
        }
        complex_texture_state_free(&built)
        return ok
    }

    complex := texture_state_set_complex_at(set, index)
    if new_single {
        // Every known entry gains the state; Unknown entries stay unknown.
        added := texture_state_provider_single_state(provider, index)
        for m in 0 ..< complex.mip_count {
            mip := &complex.mips[m]
            for &range in mip.ranges {
                merged := texture_uses_keep_known(range.value | added)
                if texture_uses_is_invalid(merged) {
                    out_selector^ = {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    }
                    out_current^ = range.value
                    out_new^ = added
                    return false
                }
                range.value = merged
            }
            ranged_states_coalesce(mip)
        }
        return true
    }

    return texture_merge_into_complex(complex, provider, index, out_selector, out_current, out_new)
}

// Apply every pair of a complex provider to an existing complex state.
texture_merge_into_complex :: proc(
    complex: ^Complex_Texture_State,
    provider: Texture_State_Provider,
    index: Tracker_Index,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    switch provider.kind {
    case .Selector:
        return texture_merge_range(
            complex,
            provider.selector,
            provider.state,
            out_selector,
            out_current,
            out_new,
        )
    case .Texture_Set:
        source := texture_state_set_complex_at(provider.set, index)
        for m in 0 ..< source.mip_count {
            for &range in source.mips[m].ranges {
                if !texture_merge_range(complex, {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    }, range.value, out_selector, out_current, out_new) {
                    return false
                }
            }
        }
        return true
    case .Known_Single:
        // `texture_state_provider_is_single` would have been true.
        panic_contextless("a single state is not complex")
    }
    return false
}

// Merge one range into a complex state, entry by entry.
texture_merge_range :: proc(
    complex: ^Complex_Texture_State,
    selector: Texture_Selector,
    added: Texture_Uses,
    out_selector: ^Texture_Selector,
    out_current: ^Texture_Uses,
    out_new: ^Texture_Uses,
) -> bool {
    mip_end := selector.mip_start + selector.mip_count
    layer_end := selector.layer_start + selector.layer_count
    for m in selector.mip_start ..< mip_end {
        mip := &complex.mips[m]
        i := ranged_states_isolate(mip, selector.layer_start, layer_end, TEXTURE_USES_UNKNOWN)
        for ; i < len(mip.ranges) && mip.ranges[i].start < layer_end; i += 1 {
            merged := texture_uses_keep_known(mip.ranges[i].value | added)
            // Nothing was known about this subresource: it stays unknown.
            if texture_uses_is_empty(merged) {
                continue
            }
            if texture_uses_is_invalid(merged) {
                out_selector^ = {
                    mip_start   = m,
                    mip_count   = 1,
                    layer_start = mip.ranges[i].start,
                    layer_count = mip.ranges[i].end - mip.ranges[i].start,
                }
                out_current^ = mip.ranges[i].value
                out_new^ = added
                return false
            }
            mip.ranges[i].value = merged
        }
        ranged_states_coalesce(mip)
    }
    return true
}

// Derive the transitions that move `set`'s state at `index` to `provider`,
// appending them to `out`.
//
// `unknown_is_uninitialized` is the device tracker's reading of the `Unknown`
// marker: in a *transcript*, `Unknown` means "this recording never touched the
// subresource", so it has nothing to transition; in the *device* tracker the same
// marker is the filler for a subresource no submission ever recorded, which means
// the image is still in `UNDEFINED` — the next use does need that entry
// transition. Reading it as `Uninitialized` is what makes a multiplexed attachment
// leave `UNDEFINED` for every subresource, not only the first one a submission
// happened to touch.
texture_barrier :: proc(
    set: ^Texture_State_Set,
    index: Tracker_Index,
    texture: Tracked_Texture,
    provider: Texture_State_Provider,
    out: ^[dynamic]Texture_State_Transition,
    ordered: Texture_Uses,
    unknown_is_uninitialized := false,
) {
    full := texture.full
    new_single := texture_state_provider_is_single(provider, full, index)
    current_complex := texture_state_set_is_complex(set, index)

    if !current_complex && new_single {
        current := set.simple[u32(index)]
        if unknown_is_uninitialized && current == TEXTURE_USES_UNKNOWN {
            current = TEXTURE_USES_UNINITIALIZED
        }
        target := texture_state_provider_single_state(provider, index)
        if texture_uses_skip_transition_ignoring_aspect(current, ordered, target) {
            return
        }
        append(out, Texture_State_Transition {
            texture  = texture.texture,
            selector = full,
            from     = current,
            to       = target,
        })
        return
    }

    if !current_complex {
        current := set.simple[u32(index)]
        if unknown_is_uninitialized && current == TEXTURE_USES_UNKNOWN {
            current = TEXTURE_USES_UNINITIALIZED
        }
        texture_barrier_from_simple(out, texture, current, provider, index, ordered)
        return
    }

    complex := texture_state_set_complex_at(set, index)
    if new_single {
        target := texture_state_provider_single_state(provider, index)
        for m in 0 ..< complex.mip_count {
            for &range in complex.mips[m].ranges {
                from := range.value
                if from == TEXTURE_USES_UNKNOWN {
                    if !unknown_is_uninitialized {
                        continue
                    }
                    from = TEXTURE_USES_UNINITIALIZED
                }
                if texture_uses_skip_transition_ignoring_aspect(from, ordered, target) {
                    continue
                }
                append(out, Texture_State_Transition {
                    texture = texture.texture,
                    selector = {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    },
                    from = from,
                    to = target,
                })
            }
        }
        return
    }

    texture_barrier_complex(
        out,
        texture,
        complex,
        provider,
        index,
        ordered,
        unknown_is_uninitialized,
    )
}

// A simple current state against a possibly complex target.
texture_barrier_from_simple :: proc(
    out: ^[dynamic]Texture_State_Transition,
    texture: Tracked_Texture,
    current: Texture_Uses,
    provider: Texture_State_Provider,
    index: Tracker_Index,
    ordered: Texture_Uses,
) {
    switch provider.kind {
    case .Selector:
        if provider.state == TEXTURE_USES_UNKNOWN {
            return
        }
        if texture_uses_skip_transition_ignoring_aspect(current, ordered, provider.state) {
            return
        }
        append(out, Texture_State_Transition {
            texture  = texture.texture,
            selector = provider.selector,
            from     = current,
            to       = provider.state,
        })
    case .Texture_Set:
        source := texture_state_set_complex_at(provider.set, index)
        for m in 0 ..< source.mip_count {
            for &range in source.mips[m].ranges {
                if range.value == TEXTURE_USES_UNKNOWN {
                    continue
                }
                if texture_uses_skip_transition_ignoring_aspect(current, ordered, range.value) {
                    continue
                }
                append(out, Texture_State_Transition {
                    texture = texture.texture,
                    selector = {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    },
                    from = current,
                    to = range.value,
                })
            }
        }
    case .Known_Single:
        // `texture_state_provider_is_single` would have been true.
        panic_contextless("a single target is not complex")
    }
}

// A complex current state against a possibly complex target.
texture_barrier_complex :: proc(
    out: ^[dynamic]Texture_State_Transition,
    texture: Tracked_Texture,
    complex: ^Complex_Texture_State,
    provider: Texture_State_Provider,
    index: Tracker_Index,
    ordered: Texture_Uses,
    unknown_is_uninitialized: bool,
) {
    switch provider.kind {
    case .Selector:
        texture_barrier_complex_range(
            out,
            texture,
            complex,
            provider.selector,
            provider.state,
            ordered,
            unknown_is_uninitialized,
        )
    case .Texture_Set:
        source := texture_state_set_complex_at(provider.set, index)
        for m in 0 ..< source.mip_count {
            for &range in source.mips[m].ranges {
                texture_barrier_complex_range(out, texture, complex, {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    }, range.value, ordered, unknown_is_uninitialized)
            }
        }
    case .Known_Single:
        // `texture_state_provider_is_single` would have been true.
        panic_contextless("a single target is not complex")
    }
}

// Emit one transition per differing intersection of `selector` with the state.
texture_barrier_complex_range :: proc(
    out: ^[dynamic]Texture_State_Transition,
    texture: Tracked_Texture,
    complex: ^Complex_Texture_State,
    selector: Texture_Selector,
    target: Texture_Uses,
    ordered: Texture_Uses,
    unknown_is_uninitialized: bool,
) {
    if target == TEXTURE_USES_UNKNOWN {
        return
    }
    mip_end := selector.mip_start + selector.mip_count
    layer_end := selector.layer_start + selector.layer_count
    for m in selector.mip_start ..< mip_end {
        for &range in complex.mips[m].ranges {
            start := range.start > selector.layer_start ? range.start : selector.layer_start
            end := range.end < layer_end ? range.end : layer_end
            if start >= end {
                continue
            }
            from := range.value
            if from == TEXTURE_USES_UNKNOWN {
                if !unknown_is_uninitialized {
                    continue
                }
                from = TEXTURE_USES_UNINITIALIZED
            }
            if texture_uses_skip_transition_ignoring_aspect(from, ordered, target) {
                continue
            }
            append(out, Texture_State_Transition {
                texture = texture.texture,
                selector = {
                    mip_start   = m,
                    mip_count   = 1,
                    layer_start = start,
                    layer_count = end - start,
                },
                from = from,
                to = target,
            })
        }
    }
}

// Advance the current state to `provider`, and — only while the start state is
// complex — back-fill the start state for subresources the transcript had never
// seen, so the pre-barrier at submit knows where they really began.
texture_update :: proc(
    start: ^Texture_State_Set,
    current: ^Texture_State_Set,
    index: Tracker_Index,
    texture: Tracked_Texture,
    provider: Texture_State_Provider,
) {
    full := texture.full
    new_single := texture_state_provider_is_single(provider, full, index)
    current_complex := texture_state_set_is_complex(current, index)

    // A simple start state was written correctly when the texture was inserted;
    // only a complex one can still be missing subresources.
    start_complex: ^Complex_Texture_State = nil
    if start != nil && texture_state_set_is_complex(start, index) {
        start_complex = texture_state_set_complex_at(start, index)
    }

    if !current_complex && new_single {
        current.simple[u32(index)] = texture_state_provider_single_state(provider, index)
        return
    }

    if !current_complex {
        // Promote: the whole texture at the current simple state, then the
        // provider's ranges overwrite it.
        existing := current.simple[u32(index)]
        complex := texture_state_set_make_complex(current, index)
        complex_texture_state_init(
            complex,
            current.allocator,
            full.mip_count,
            full.layer_count,
            existing,
        )
        texture_overwrite_complex(complex, provider, index)
        return
    }

    complex := texture_state_set_complex_at(current, index)
    if new_single {
        target := texture_state_provider_single_state(provider, index)
        for m in 0 ..< complex.mip_count {
            for &range in complex.mips[m].ranges {
                if range.value != TEXTURE_USES_UNKNOWN {
                    continue
                }
                if start_complex != nil {
                    complex_texture_state_assign(start_complex, {
                            mip_start   = m,
                            mip_count   = 1,
                            layer_start = range.start,
                            layer_count = range.end - range.start,
                        }, target)
                }
            }
        }
        texture_state_set_make_simple(current, index, target)
        return
    }

    texture_overwrite_complex(complex, provider, index)
    if start_complex != nil {
        texture_fix_start(start_complex, complex)
    }
}

// Overwrite a complex state with a complex provider's ranges. `Unknown` values in
// the provider mean "nothing new", so those entries keep what they had.
texture_overwrite_complex :: proc(
    complex: ^Complex_Texture_State,
    provider: Texture_State_Provider,
    index: Tracker_Index,
) {
    switch provider.kind {
    case .Selector:
        if provider.state == TEXTURE_USES_UNKNOWN {
            return
        }
        complex_texture_state_assign(complex, provider.selector, provider.state)
    case .Texture_Set:
        source := texture_state_set_complex_at(provider.set, index)
        for m in 0 ..< source.mip_count {
            for &range in source.mips[m].ranges {
                if range.value == TEXTURE_USES_UNKNOWN {
                    continue
                }
                complex_texture_state_assign(complex, {
                        mip_start   = m,
                        mip_count   = 1,
                        layer_start = range.start,
                        layer_count = range.end - range.start,
                    }, range.value)
            }
        }
    case .Known_Single:
        // `texture_state_provider_is_single` would have been true.
        panic_contextless("a single target is not complex")
    }
}

// Back-fill a start state's `Unknown` subresources from the current state, which
// is where a late first use shows up. Called with both states after an overwrite.
texture_fix_start :: proc(start: ^Complex_Texture_State, current: ^Complex_Texture_State) {
    for m in 0 ..< current.mip_count {
        for &range in current.mips[m].ranges {
            if range.value == TEXTURE_USES_UNKNOWN {
                continue
            }
            start_mip := &start.mips[m]
            i := ranged_states_isolate(start_mip, range.start, range.end, TEXTURE_USES_UNKNOWN)
            for ; i < len(start_mip.ranges) && start_mip.ranges[i].start < range.end; i += 1 {
                // Only a subresource the start did not know about is filled in.
                if start_mip.ranges[i].value != TEXTURE_USES_UNKNOWN {
                    continue
                }
                start_mip.ranges[i].value = range.value
            }
            ranged_states_coalesce(start_mip)
        }
    }
}

// Advance a device state to another set's states, subresource by subresource: a
// simple target replaces the whole texture, a complex one replaces each range.
texture_advance :: proc(
    current: ^Texture_State_Set,
    index: Tracker_Index,
    texture: Tracked_Texture,
    source: ^Texture_State_Set,
) {
    _ = texture
    if !texture_state_set_is_complex(source, index) {
        texture_state_set_insert_simple(current, index, source.simple[u32(index)])
        return
    }
    source_complex := texture_state_set_complex_at(source, index)
    complex := texture_state_set_make_complex(current, index)
    complex_texture_state_copy_from(complex, source_complex)
}

// -----------------------------------------------------------------------------
// Memory initialisation
// -----------------------------------------------------------------------------

// Memory initialisation state: which subresources are known to hold defined bytes.
//
// A texture's contents are undefined when it is created, and undefined again when
// a render pass discards what it wrote. Anything that reads them before a write —
// a `LOAD` attachment, the presentation engine — needs them defined first. That is
// a property of the image, not of its use: a use set says what the image may be
// used for next, while this says whether those bytes exist at all. So the state
// lives on the resource and the use tracker never sees it.
//
// Recording does not touch it. A command buffer records *actions* ("this range is
// implicitly initialized" / "this range needs initialized memory") and submit
// applies them, so an encoder that is discarded never leaves a mark.

// Why a range is being initialized.
Memory_Init_Kind :: enum {
    // The operation writes the range, so its contents are defined afterwards.
    Implicitly_Initialized,
    // The operation reads the range, so its contents must be defined before it
    // runs: a submission that finds the range undefined clears it first, then
    // counts it as defined.
    Needs_Initialized_Memory,
    // The operation *discards* the range: whatever it wrote need not survive, so
    // the contents are undefined afterwards. Distinct from a read that needs
    // contents — nothing is cleared, the range simply becomes undefined again.
    Discarded,
}

// A subresource range in the tracker's own half-open form: mip levels and array
// layers as `[start, end)`, which is what the range tables work in. The public
// selector is count-based and converts at this boundary.
Texture_Init_Range :: struct {
    mip_start:   u32,
    mip_end:     u32,
    layer_start: u32,
    layer_end:   u32,
}

texture_init_range_from_selector :: proc(selector: Texture_Selector) -> Texture_Init_Range {
    return {
        mip_start   = selector.mip_start,
        mip_end     = selector.mip_start + selector.mip_count,
        layer_start = selector.layer_start,
        layer_end   = selector.layer_start + selector.layer_count,
    }
}

// The public selector naming the same subresources as this range.
texture_init_range_to_selector :: #force_inline proc "contextless" (
    r: Texture_Init_Range,
) -> Texture_Selector {
    return {
        mip_start   = r.mip_start,
        mip_count   = r.mip_end - r.mip_start,
        layer_start = r.layer_start,
        layer_count = r.layer_end - r.layer_start,
    }
}

// The extent at a given mip level of a texture descriptor.
texture_descriptor_mip_level_size :: proc(
    desc: Texture_Descriptor,
    level: u32,
) -> (
    size: Extent_3D,
    ok: bool,
) {
    if level >= desc.mip_level_count {
        return {}, false
    }
    width := level < 31 ? desc.size.width >> level : 0
    if width == 0 {
        width = 1
    }
    height: u32 = 1
    if desc.dimension != .D1 {
        height = level < 31 ? desc.size.height >> level : 0
        if height == 0 {
            height = 1
        }
    }
    layers := desc.size.depth_or_array_layers
    if desc.dimension == .D1 {
        layers = 1
    }
    if desc.dimension == .D3 {
        layers = level < 31 ? desc.size.depth_or_array_layers >> level : 0
        if layers == 0 {
            layers = 1
        }
    }
    return Extent_3D{width = width, height = height, depth_or_array_layers = layers}, true
}

// The extent one *plane* of a multi-planar texture occupies at `level`: the mip's
// size divided by the plane's subsampling factor, so plane 1 of a 4:2:0 format is
// half width and half height. Fails like `texture_descriptor_mip_level_size` and
// when `aspect` names no plane of this format; a copy of a plane is expressed in
// these texels.
texture_descriptor_plane_mip_level_size :: proc(
    desc: Texture_Descriptor,
    level: u32,
    aspect: Texture_Aspect,
) -> (
    size: Extent_3D,
    ok: bool,
) {
    size, ok = texture_descriptor_mip_level_size(desc, level)
    if !ok {
        return {}, false
    }
    plane: u32
    switch aspect {
    case .Plane0:
        plane = 0
    case .Plane1:
        plane = 1
    case .Plane2:
        plane = 2
    case .All, .Depth_Only, .Stencil_Only:
        return {}, false
    }
    if plane >= texture_format_planes(desc.format) {
        return {}, false
    }
    subsample_x, subsample_y := texture_format_subsampling_factors(desc.format, plane)
    size.width /= subsample_x
    size.height /= subsample_y
    return size, true
}

// Whether a copy's footprint covers whole texture subresources.
//
// Initialization is tracked per mip x array layer x aspect, not per texel, so a
// copy that writes only part of a subresource cannot say the rest of it holds
// defined bytes: it has to clear the range first and let the copy fill what it
// covers. The three ways a copy can be partial are an extent smaller than the mip,
// a narrower layer range of a 3D image (whose selector is always the whole layer)
// and a copy that names only one aspect of a combined depth-stencil image.
copy_covers_whole_subresource :: proc(
    desc: ^Texture_Descriptor,
    copy: ^Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
) -> bool {
    mip_size, ok := texture_descriptor_mip_level_size(desc^, copy.mip_level)
    if !ok {
        return false
    }
    // A plane of a multi-planar texture is its own subresource: the copy covers it
    // when it spans the plane's extent (half width and height for plane 1 of a
    // 4:2:0 format), not the luma one.
    if plane_size, plane_ok := texture_descriptor_plane_mip_level_size(
        desc^,
        copy.mip_level,
        copy.aspect,
    ); plane_ok {
        mip_size = plane_size
    }
    if copy_size.width != mip_size.width {
        return false
    }
    if copy_size.height != mip_size.height {
        return false
    }
    if desc.dimension == .D3 && copy_size.depth_or_array_layers != mip_size.depth_or_array_layers {
        return false
    }
    // `All` covers a single-aspect format's whole subresource, and a plane covers
    // the whole of its own.
    return copy.aspect == .All || texture_format_is_multi_planar(desc.format)
}

// The initialization action a copy's destination records: it defines the range
// when the copy covers it whole, and asks for it to be cleared when it does not.
copy_destination_init_kind :: proc(
    desc: ^Texture_Descriptor,
    copy: ^Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
) -> Memory_Init_Kind {
    return(
        copy_covers_whole_subresource(desc, copy, copy_size) ? .Implicitly_Initialized : .Needs_Initialized_Memory \
    )
}

// One action a command buffer recorded, applied when it is submitted.
Texture_Init_Action :: struct {
    texture: Texture,
    range:   Texture_Init_Range,
    kind:    Memory_Init_Kind,
    // The subresource aspect the action covers, as the caller named it. A combined
    // depth-stencil format tracks its two aspects separately, so the action is
    // split per aspect when it is applied.
    aspect:  Texture_Aspect,
}

// The tracker's aspect slots: slot 0 is the primary aspect (a colour image's
// colour, a depth-only image's depth, a multi-planar image's plane 0), slot 1 the
// second one (a combined depth-stencil format's stencil, a multi-planar image's
// plane 1).
INIT_ASPECT_PRIMARY :: u32(0)
INIT_ASPECT_STENCIL :: u32(1)
INIT_ASPECT_PLANE1  :: u32(1)

// The tracker slots a selector names: `slots[0..count)`.
Init_Aspects :: struct {
    slots: [2]u32,
    count: u32,
}

// The tracker slots `aspect` names for `format`. A format with one aspect has one
// slot, whatever the selector says: a depth-only format's depth aspect is slot 0,
// and `All` still means just it.
//
// The two multi-aspect families split differently: a combined depth-stencil format
// tracks its depth and stencil aspects apart, and a multi-planar format tracks its
// planes apart, so a write to plane 0 leaves plane 1 undefined.
init_tracked_aspects :: proc(format: Texture_Format, aspect: Texture_Aspect) -> Init_Aspects {
    out := Init_Aspects {
        slots = {INIT_ASPECT_PRIMARY, INIT_ASPECT_PRIMARY},
        count = 1,
    }
    plane_count := texture_format_planes(format)
    if plane_count > 0 {
        assert(plane_count <= 2, "the tracker holds two aspect slots")
        if aspect == .All {
            out.slots[1] = INIT_ASPECT_PLANE1
            out.count = plane_count
            return out
        }
        out.slots[0] = aspect == .Plane1 ? INIT_ASPECT_PLANE1 : INIT_ASPECT_PRIMARY
        return out
    }
    if !(texture_format_has_depth_aspect(format) && texture_format_has_stencil_aspect(format)) {
        return out
    }
    if aspect == .All {
        out.slots[1] = INIT_ASPECT_STENCIL
        out.count = 2
        return out
    }
    out.slots[0] = aspect == .Stencil_Only ? INIT_ASPECT_STENCIL : INIT_ASPECT_PRIMARY
    return out
}

// The public selector naming tracker slot `aspect` of `format`.
init_aspect_for_slot :: proc(format: Texture_Format, aspect: u32) -> Texture_Aspect {
    if texture_format_is_multi_planar(format) {
        return aspect == INIT_ASPECT_PLANE1 ? .Plane1 : .Plane0
    }
    if !(texture_format_has_depth_aspect(format) && texture_format_has_stencil_aspect(format)) {
        return .All
    }
    return aspect == INIT_ASPECT_STENCIL ? .Stencil_Only : .Depth_Only
}

// One bit per tracked chunk. The chunk a caller names is its own concern: the
// texture wrapper lays mip levels, array layers and aspects out over this space.
//
// A texture — and a swapchain image once per frame — is the common case, and it
// fits in one word: its whole state lives in `inline_word`, and `more` is never
// initialized. Only a resource with more than 64 chunks spills into a list.
Memory_Init_Tracker :: struct {
    // The whole state while `chunk_count <= 64`.
    inline_word: u64,
    // The state when it needs more than one word; untouched otherwise.
    more:        [dynamic]u64,
    chunk_count: u32,
}

memory_init_tracker_init :: proc(
    t: ^Memory_Init_Tracker,
    allocator: runtime.Allocator,
    chunk_count: u32,
) {
    t.chunk_count = chunk_count
    t.inline_word = 0
    t.more = nil
    words := (chunk_count + METADATA_WORD_BITS - 1) / METADATA_WORD_BITS
    if words > 1 {
        t.more.allocator = allocator
        for _ in 0 ..< words {
            append(&t.more, 0)
        }
    }
}

memory_init_tracker_free :: proc(t: ^Memory_Init_Tracker) {
    // A tracker that never spilled has nothing to return; `delete` is a no-op for
    // a list that was never initialized.
    delete(t.more)
    t.more = nil
}

// The words holding the state: the inline word, or the list once it spilled.
memory_init_tracker_state_words :: #force_inline proc "contextless" (
    t: ^Memory_Init_Tracker,
) -> [^]u64 {
    if len(t.more) > 0 {
        return raw_data(t.more)
    }
    return ([^]u64)(&t.inline_word)
}

// True when every chunk in `[start, end)` is initialized.
memory_init_tracker_is_initialized :: proc(t: ^Memory_Init_Tracker, start, end: u32) -> bool {
    if start >= end {
        return true
    }
    words := memory_init_tracker_state_words(t)
    first := start / METADATA_WORD_BITS
    last := (end - 1) / METADATA_WORD_BITS
    for w in first ..= last {
        lo := w == first ? start % METADATA_WORD_BITS : 0
        hi := w == last ? (end - 1) % METADATA_WORD_BITS + 1 : METADATA_WORD_BITS
        mask := init_word_mask(lo, hi)
        if (words[w] & mask) != mask {
            return false
        }
    }
    return true
}

// Mark every chunk in `[start, end)` initialized or not.
memory_init_tracker_mark :: proc(t: ^Memory_Init_Tracker, start, end: u32, initialized: bool) {
    if start >= end {
        return
    }
    words := memory_init_tracker_state_words(t)
    first := start / METADATA_WORD_BITS
    last := (end - 1) / METADATA_WORD_BITS
    for w in first ..= last {
        lo := w == first ? start % METADATA_WORD_BITS : 0
        hi := w == last ? (end - 1) % METADATA_WORD_BITS + 1 : METADATA_WORD_BITS
        mask := init_word_mask(lo, hi)
        if initialized {
            words[w] |= mask
        } else {
            words[w] &= ~mask
        }
    }
}

// The bits `[lo, hi)` of one word. The caller keeps both below 64.
init_word_mask :: proc(lo, hi: u32) -> u64 {
    assert(lo < 64 && hi <= 64, "init mask out of one word")
    low: u64 = lo == 0 ? ~u64(0) : ~((u64(1) << lo) - 1)
    high: u64 = hi >= 64 ? ~u64(0) : (u64(1) << hi) - 1
    return low & high
}

// The initialisation state of one texture: one chunk per (mip, layer, aspect),
// laid out aspect-major and mip-major inside each aspect, so a range's layer span
// is a contiguous run within each mip.
//
// A combined depth-stencil format has two aspects, and a multi-planar format has
// two planes; both are tracked apart: a pass that discards its depth store leaves
// the stencil aspect defined, and a write to plane 0 leaves plane 1 undefined, so
// a later read of either clears only what is missing. Every other format has a
// single aspect.
//
// The granularity is the port's subresource: a 3D texture counts as one layer, so
// a depth slice is not tracked apart from its mip.
Texture_Init_Tracker :: struct {
    memory:       Memory_Init_Tracker,
    mip_count:    u32,
    layer_count:  u32,
    // 2 for a combined depth-stencil format or a multi-planar one, 1 otherwise.
    aspect_count: u32,
}

texture_init_tracker_init :: proc(
    t: ^Texture_Init_Tracker,
    allocator: runtime.Allocator,
    mip_count: u32,
    layer_count: u32,
    aspect_count: u32 = 1,
) {
    t.mip_count = mip_count
    t.layer_count = layer_count
    t.aspect_count = aspect_count
    memory_init_tracker_init(&t.memory, allocator, mip_count * layer_count * aspect_count)
}

texture_init_tracker_free :: proc(t: ^Texture_Init_Tracker) {
    memory_init_tracker_free(&t.memory)
    t.mip_count = 0
    t.layer_count = 0
    t.aspect_count = 0
}

// The chunk a subresource aspect occupies.
texture_init_tracker_chunk :: #force_inline proc "contextless" (
    t: ^Texture_Init_Tracker,
    mip, layer, aspect: u32,
) -> u32 {
    return aspect * t.mip_count * t.layer_count + mip * t.layer_count + layer
}

// True when every subresource `range` names holds defined contents in `aspect`.
texture_init_tracker_check_is_initialized :: proc(
    t: ^Texture_Init_Tracker,
    range: Texture_Init_Range,
    aspect: u32 = INIT_ASPECT_PRIMARY,
) -> bool {
    if aspect >= t.aspect_count {
        return true
    }
    if range.mip_end > t.mip_count || range.layer_end > t.layer_count {
        return false
    }
    for m in range.mip_start ..< range.mip_end {
        lo := texture_init_tracker_chunk(t, m, range.layer_start, aspect)
        if !memory_init_tracker_is_initialized(
            &t.memory,
            lo,
            lo + (range.layer_end - range.layer_start),
        ) {
            return false
        }
    }
    return true
}

// True when any subresource `range` names holds defined contents in `aspect`.
texture_init_tracker_is_partially_initialized :: proc(
    t: ^Texture_Init_Tracker,
    range: Texture_Init_Range,
    aspect: u32 = INIT_ASPECT_PRIMARY,
) -> bool {
    if aspect >= t.aspect_count {
        return false
    }
    for m in range.mip_start ..< min(range.mip_end, t.mip_count) {
        for l in range.layer_start ..< min(range.layer_end, t.layer_count) {
            chunk := texture_init_tracker_chunk(t, m, l, aspect)
            if memory_init_tracker_is_initialized(&t.memory, chunk, chunk + 1) {
                return true
            }
        }
    }
    return false
}

// Mark every subresource `range` names as holding undefined contents in `aspect`:
// a store that discarded them. A range that lies outside this texture marks
// nothing.
texture_init_tracker_mark_uninitialized :: proc(
    t: ^Texture_Init_Tracker,
    range: Texture_Init_Range,
    aspect: u32 = INIT_ASPECT_PRIMARY,
) {
    if aspect >= t.aspect_count {
        return
    }
    mip_end := min(range.mip_end, t.mip_count)
    layer_end := min(range.layer_end, t.layer_count)
    for m in range.mip_start ..< mip_end {
        lo := texture_init_tracker_chunk(t, m, range.layer_start, aspect)
        hi := texture_init_tracker_chunk(t, m, layer_end, aspect)
        memory_init_tracker_mark(&t.memory, lo, hi, false)
    }
}

// Mark every subresource `range` names as holding defined contents in `aspect`. A
// range that lies outside this texture marks nothing.
texture_init_tracker_mark_initialized :: proc(
    t: ^Texture_Init_Tracker,
    range: Texture_Init_Range,
    aspect: u32 = INIT_ASPECT_PRIMARY,
) {
    if aspect >= t.aspect_count {
        return
    }
    mip_end := min(range.mip_end, t.mip_count)
    layer_end := min(range.layer_end, t.layer_count)
    for m in range.mip_start ..< mip_end {
        lo := texture_init_tracker_chunk(t, m, range.layer_start, aspect)
        hi := texture_init_tracker_chunk(t, m, layer_end, aspect)
        memory_init_tracker_mark(&t.memory, lo, hi, true)
    }
}

// Hand over the sub-ranges of `range` that do *not* hold defined contents in
// `aspect`, and count the whole range as defined afterwards: a caller that clears
// what it is handed leaves the range usable.
texture_init_tracker_drain_uninitialized :: proc(
    t: ^Texture_Init_Tracker,
    range: Texture_Init_Range,
    out: ^[dynamic]Texture_Init_Range,
    aspect: u32 = INIT_ASPECT_PRIMARY,
) {
    if aspect >= t.aspect_count {
        return
    }
    mip_end := min(range.mip_end, t.mip_count)
    layer_end := min(range.layer_end, t.layer_count)
    for m in range.mip_start ..< mip_end {
        run_start: u32 = 0
        in_run := false
        for l in range.layer_start ..< layer_end {
            chunk := texture_init_tracker_chunk(t, m, l, aspect)
            defined := memory_init_tracker_is_initialized(&t.memory, chunk, chunk + 1)
            if !defined && !in_run {
                run_start = l
                in_run = true
            } else if defined && in_run {
                append(out, Texture_Init_Range {
                    mip_start   = m,
                    mip_end     = m + 1,
                    layer_start = run_start,
                    layer_end   = l,
                })
                in_run = false
            }
        }
        if in_run {
            append(out, Texture_Init_Range {
                mip_start   = m,
                mip_end     = m + 1,
                layer_start = run_start,
                layer_end   = layer_end,
            })
        }
    }
    texture_init_tracker_mark_initialized(t, {
            mip_start   = range.mip_start,
            mip_end     = mip_end,
            layer_start = range.layer_start,
            layer_end   = layer_end,
        }, aspect)
}

// A byte range in the tracker's own half-open form. Buffers are tracked per byte —
// a partially written buffer only needs the holes cleared — so the range is the
// granularity, and there is no chunk table.
Buffer_Init_Range :: struct {
    start: u64,
    end:   u64,
}

// One buffer action a command buffer recorded, applied when it is submitted.
Buffer_Init_Action :: struct {
    buffer: Buffer,
    range:  Buffer_Init_Range,
    kind:   Memory_Init_Kind,
}

// The initialisation state of one buffer: a sorted, non-overlapping list of the
// byte ranges known to be undefined. A fully initialised buffer is the empty list,
// which is the common case, so nothing is allocated for it.
//
// Ranges instead of a bit per byte because a buffer is large and sparsely used: a
// 256 MiB buffer bound in small slices would cost a 32 MiB bitmap, while the list
// holds one entry per hole a caller actually leaves.
Buffer_Init_Tracker :: struct {
    uninitialized: [dynamic]Buffer_Init_Range,
    size:          u64,
}

buffer_init_tracker_init :: proc(
    t: ^Buffer_Init_Tracker,
    allocator: runtime.Allocator,
    size: u64,
) {
    t.uninitialized = nil
    t.uninitialized.allocator = allocator
    t.size = size
    if size != 0 {
        append(&t.uninitialized, Buffer_Init_Range{start = 0, end = size})
    }
}

buffer_init_tracker_free :: proc(t: ^Buffer_Init_Tracker) {
    delete(t.uninitialized)
    t.uninitialized = nil
    t.size = 0
}

// Clamp `[start, end)` to the buffer and report whether anything is left of it.
buffer_init_tracker_clamp :: proc(t: ^Buffer_Init_Tracker, start: ^u64, end: ^u64) -> bool {
    if start^ > t.size {
        start^ = t.size
    }
    if end^ > t.size {
        end^ = t.size
    }
    return start^ < end^
}

// Remove the entry at `index`, keeping the order of what follows. `remove_at` is
// not a dynamic-array builtin, and the buffer init holes must stay sorted.
tracker_dynamic_remove_at :: proc(arr: ^[dynamic]$T, index: int) -> T {
    removed := arr[index]
    for i in index ..< len(arr) - 1 {
        arr[i] = arr[i + 1]
    }
    pop(arr)
    return removed
}

// True when every byte of `[start, end)` is known to hold defined contents.
buffer_init_tracker_check_is_initialized :: proc(
    t: ^Buffer_Init_Tracker,
    start, end: u64,
) -> bool {
    for range in t.uninitialized {
        if range.start < end && start < range.end {
            return false
        }
    }
    return true
}

// Mark `[start, end)` as defined: the caller wrote every byte of it. The undefined
// ranges the write covers are trimmed away, and one it splits is cut in two.
buffer_init_tracker_mark_initialized :: proc(t: ^Buffer_Init_Tracker, start: u64, end: u64) {
    lo := start
    hi := end
    if !buffer_init_tracker_clamp(t, &lo, &hi) {
        return
    }
    i := 0
    for i < len(t.uninitialized) {
        hole := t.uninitialized[i]
        if hole.end <= lo || hi <= hole.start {
            i += 1
            continue
        }
        if hole.start < lo && hi < hole.end {
            // The write lands inside one hole: keep the two pieces around it.
            t.uninitialized[i] = {
                start = hole.start,
                end   = lo,
            }
            ok, _ := inject_at(
                &t.uninitialized,
                i + 1,
                Buffer_Init_Range{start = hi, end = hole.end},
            )
            assert(ok, "buffer init holes out of memory")
            return
        }
        if hole.start < lo {
            t.uninitialized[i] = {
                start = hole.start,
                end   = lo,
            }
            i += 1
            continue
        }
        if hi < hole.end {
            t.uninitialized[i] = {
                start = hi,
                end   = hole.end,
            }
            return
        }
        _ = tracker_dynamic_remove_at(&t.uninitialized, i)
    }
}

// Mark `[start, end)` as undefined: a store discarded whatever it wrote. The range
// is merged into the list so the holes stay disjoint and sorted.
buffer_init_tracker_mark_uninitialized :: proc(t: ^Buffer_Init_Tracker, start: u64, end: u64) {
    lo := start
    hi := end
    if !buffer_init_tracker_clamp(t, &lo, &hi) {
        return
    }
    at := 0
    for at < len(t.uninitialized) && t.uninitialized[at].start < lo {
        at += 1
    }
    ok, _ := inject_at(&t.uninitialized, at, Buffer_Init_Range{start = lo, end = hi})
    assert(ok, "buffer init holes out of memory")
    // Merge with the neighbours it overlaps or touches, then keep the list sorted.
    i := 0
    for i + 1 < len(t.uninitialized) {
        left := t.uninitialized[i]
        right := t.uninitialized[i + 1]
        if right.start > left.end {
            i += 1
            continue
        }
        t.uninitialized[i] = {
            start = left.start,
            end   = right.end > left.end ? right.end : left.end,
        }
        _ = tracker_dynamic_remove_at(&t.uninitialized, i + 1)
    }
}

// Hand over the undefined parts of `[start, end)` and count the whole range as
// defined afterwards: a caller that clears what it is handed leaves the range
// usable. The ranges come out sorted and disjoint.
buffer_init_tracker_drain_uninitialized :: proc(
    t: ^Buffer_Init_Tracker,
    start: u64,
    end: u64,
    out: ^[dynamic]Buffer_Init_Range,
) {
    lo := start
    hi := end
    if !buffer_init_tracker_clamp(t, &lo, &hi) {
        return
    }
    for range in t.uninitialized {
        if range.start >= hi {
            break
        }
        if range.end <= lo {
            continue
        }
        append(out, Buffer_Init_Range {
            start = range.start > lo ? range.start : lo,
            end   = range.end < hi ? range.end : hi,
        })
    }
    buffer_init_tracker_mark_initialized(t, lo, hi)
}

// -----------------------------------------------------------------------------
// Tracker
// -----------------------------------------------------------------------------

// The tracker shell: one pass's usage scope, one command buffer's tracker, the
// device's authoritative state, and the bind group / render bundle state they
// merge.
//
// A usage scope is the only place a *conflict* can be reported: it is the union of
// the uses within one render pass or one compute dispatch, and WebGPU forbids
// exclusive uses from sharing it. A tracker never conflicts — it has already been
// checked — so it only moves state and emits transitions.

// Details of a rejected usage merge: which resource, which subresources and the
// two use sets that could not coexist.
Usage_Conflict :: struct {
    is_texture:          bool,
    texture:             Texture,
    buffer:              Buffer,
    selector:            Texture_Selector,
    current_texture_use: Texture_Uses,
    new_texture_use:     Texture_Uses,
    current_buffer_use:  Buffer_Uses,
    new_buffer_use:      Buffer_Uses,
}

// The merged state of all stateful resources used within one usage scope.
Usage_Scope :: struct {
    allocator: runtime.Allocator,
    buffers:   Buffer_Usage_Scope,
    textures:  Texture_Usage_Scope,
}

usage_scope_init :: proc(s: ^Usage_Scope, allocator: runtime.Allocator) {
    s.allocator = allocator
    buffer_usage_scope_init(&s.buffers, allocator)
    texture_usage_scope_init(&s.textures, allocator)
}

usage_scope_free :: proc(s: ^Usage_Scope) {
    buffer_usage_scope_free(&s.buffers)
    texture_usage_scope_free(&s.textures)
    s^ = {}
}

usage_scope_clear :: proc(s: ^Usage_Scope) {
    buffer_usage_scope_clear(&s.buffers)
    texture_usage_scope_clear(&s.textures)
}

// Presize both sides for the tracker indices this device has handed out.
usage_scope_set_size :: proc(s: ^Usage_Scope, buffers: u32, textures: u32) {
    buffer_usage_scope_set_size(&s.buffers, buffers)
    texture_usage_scope_set_size(&s.textures, textures)
}

usage_scope_set_ordered_uses_masks :: proc(
    s: ^Usage_Scope,
    buffer_mask: Buffer_Uses,
    texture_mask: Texture_Uses,
) {
    buffer_usage_scope_set_ordered_uses_mask(&s.buffers, buffer_mask)
    texture_usage_scope_set_ordered_uses_mask(&s.textures, texture_mask)
}

// Merge one texture range's use. False is a conflict, filled into `conflict`.
usage_scope_add_texture :: proc(
    s: ^Usage_Scope,
    texture: Tracked_Texture,
    selector: Texture_Selector,
    uses: Texture_Uses,
    conflict: ^Usage_Conflict,
) -> bool {
    at: Texture_Selector
    current: Texture_Uses
    added: Texture_Uses
    // A selector that covers the whole texture is the cheap single-state arm.
    has_selector := !texture_selector_equals(selector, texture.full)
    if texture_usage_scope_merge_single(
        &s.textures,
        texture,
        has_selector,
        selector,
        uses,
        &at,
        &current,
        &added,
    ) {
        return true
    }
    conflict.is_texture = true
    conflict.texture = texture.texture
    conflict.selector = at
    conflict.current_texture_use = current
    conflict.new_texture_use = added
    return false
}

// Merge one buffer's use. False is a conflict, filled into `conflict`.
usage_scope_add_buffer :: proc(
    s: ^Usage_Scope,
    index: Tracker_Index,
    buffer: Buffer,
    uses: Buffer_Uses,
    conflict: ^Usage_Conflict,
) -> bool {
    current: Buffer_Uses
    added: Buffer_Uses
    if buffer_usage_scope_merge_single(&s.buffers, index, buffer, uses, &current, &added) {
        return true
    }
    conflict.is_texture = false
    conflict.buffer = buffer
    conflict.current_buffer_use = current
    conflict.new_buffer_use = added
    return false
}

// Merge every stateful resource of a bind group into the scope.
usage_scope_merge_bind_group :: proc(
    s: ^Usage_Scope,
    group: ^Bind_Group_States,
    conflict: ^Usage_Conflict,
) -> bool {
    at: Texture_Selector
    texture_current: Texture_Uses
    texture_added: Texture_Uses
    if !texture_usage_scope_merge_bind_group(
        &s.textures,
        &group.views,
        &at,
        &texture_current,
        &texture_added,
    ) {
        conflict.is_texture = true
        conflict.selector = at
        conflict.current_texture_use = texture_current
        conflict.new_texture_use = texture_added
        return false
    }
    buffer_current: Buffer_Uses
    buffer_added: Buffer_Uses
    if !buffer_usage_scope_merge_bind_group(
        &s.buffers,
        &group.buffers,
        &buffer_current,
        &buffer_added,
    ) {
        conflict.is_texture = false
        conflict.current_buffer_use = buffer_current
        conflict.new_buffer_use = buffer_added
        return false
    }
    return true
}

// Merge every stateful resource of a render bundle scope.
usage_scope_merge_render_bundle :: proc(
    s: ^Usage_Scope,
    bundle: ^Render_Bundle_Scope,
    conflict: ^Usage_Conflict,
) -> bool {
    at: Texture_Selector
    texture_current: Texture_Uses
    texture_added: Texture_Uses
    if !texture_usage_scope_merge_usage_scope(
        &s.textures,
        &bundle.textures,
        &at,
        &texture_current,
        &texture_added,
    ) {
        conflict.is_texture = true
        conflict.selector = at
        conflict.current_texture_use = texture_current
        conflict.new_texture_use = texture_added
        return false
    }
    buffer_current: Buffer_Uses
    buffer_added: Buffer_Uses
    if !buffer_usage_scope_merge_usage_scope(
        &s.buffers,
        &bundle.buffers,
        &buffer_current,
        &buffer_added,
    ) {
        conflict.is_texture = false
        conflict.current_buffer_use = buffer_current
        conflict.new_buffer_use = buffer_added
        return false
    }
    return true
}

// Recycles usage scopes. The tables only grow with the device's tracker indices
// and a scope's contents are discarded on release, so a pass costs no allocation
// after the first few frames.
Usage_Scope_Pool :: struct {
    allocator:       runtime.Allocator,
    idle:            [dynamic]^Usage_Scope,
    buffer_ordered:  Buffer_Uses,
    texture_ordered: Texture_Uses,
}

usage_scope_pool_init :: proc(
    p: ^Usage_Scope_Pool,
    allocator: runtime.Allocator,
    buffer_ordered: Buffer_Uses,
    texture_ordered: Texture_Uses,
) {
    p.allocator = allocator
    p.buffer_ordered = buffer_ordered
    p.texture_ordered = texture_ordered
    p.idle = nil
    p.idle.allocator = allocator
}

usage_scope_pool_free :: proc(p: ^Usage_Scope_Pool) {
    for scope in p.idle {
        usage_scope_free(scope)
        free(scope, p.allocator)
    }
    delete(p.idle)
    p.idle = nil
}

// Take a cleared, sized scope carrying this device's ordering policy.
usage_scope_pool_acquire :: proc(p: ^Usage_Scope_Pool) -> ^Usage_Scope {
    scope: ^Usage_Scope
    if len(p.idle) > 0 {
        scope = pop(&p.idle)
    } else {
        scope = new(Usage_Scope, p.allocator)
        usage_scope_init(scope, p.allocator)
    }
    usage_scope_set_ordered_uses_masks(scope, p.buffer_ordered, p.texture_ordered)
    return scope
}

// Clear a scope and return it to the pool.
usage_scope_pool_release :: proc(p: ^Usage_Scope_Pool, scope: ^Usage_Scope) {
    if scope == nil {
        return
    }
    usage_scope_clear(scope)
    append(&p.idle, scope)
}

// What a bind group contributes to a usage scope, resolved once when the bind group
// is created: the buffers it references and the views (with their parent texture
// and subresource range).
Bind_Group_States :: struct {
    buffers: Buffer_Bind_Group_State,
    views:   Texture_View_Bind_Group_State,
}

bind_group_states_init :: proc(s: ^Bind_Group_States, allocator: runtime.Allocator) {
    buffer_bind_group_state_init(&s.buffers, allocator)
    texture_view_bind_group_state_init(&s.views, allocator)
}

bind_group_states_free :: proc(s: ^Bind_Group_States) {
    buffer_bind_group_state_free(&s.buffers)
    texture_view_bind_group_state_free(&s.views)
}

// Sort both sides by tracker index, so merging them into a scope walks memory
// forward. Called once, when the bind group is created.
bind_group_states_optimize :: proc(s: ^Bind_Group_States) {
    buffer_bind_group_state_optimize(&s.buffers)
    texture_view_bind_group_state_optimize(&s.views)
}

// What a render bundle contributes: the merged uses of its passes, plus the bind
// groups and render pipelines it was recorded with (they must outlive it).
Render_Bundle_Scope :: struct {
    buffers:          Buffer_Usage_Scope,
    textures:         Texture_Usage_Scope,
    bind_groups:      Stateless_Tracker(Bind_Group),
    render_pipelines: Stateless_Tracker(Render_Pipeline),
}

render_bundle_scope_init :: proc(s: ^Render_Bundle_Scope, allocator: runtime.Allocator) {
    buffer_usage_scope_init(&s.buffers, allocator)
    texture_usage_scope_init(&s.textures, allocator)
    stateless_tracker_init(&s.bind_groups, allocator)
    stateless_tracker_init(&s.render_pipelines, allocator)
}

render_bundle_scope_free :: proc(s: ^Render_Bundle_Scope) {
    buffer_usage_scope_free(&s.buffers)
    texture_usage_scope_free(&s.textures)
    stateless_tracker_free(&s.bind_groups)
    stateless_tracker_free(&s.render_pipelines)
}

render_bundle_scope_merge_bind_group :: proc(
    s: ^Render_Bundle_Scope,
    group: ^Bind_Group_States,
    conflict: ^Usage_Conflict,
) -> bool {
    at: Texture_Selector
    texture_current: Texture_Uses
    texture_added: Texture_Uses
    if !texture_usage_scope_merge_bind_group(
        &s.textures,
        &group.views,
        &at,
        &texture_current,
        &texture_added,
    ) {
        conflict.is_texture = true
        conflict.selector = at
        conflict.current_texture_use = texture_current
        conflict.new_texture_use = texture_added
        return false
    }
    buffer_current: Buffer_Uses
    buffer_added: Buffer_Uses
    if !buffer_usage_scope_merge_bind_group(
        &s.buffers,
        &group.buffers,
        &buffer_current,
        &buffer_added,
    ) {
        conflict.is_texture = false
        conflict.current_buffer_use = buffer_current
        conflict.new_buffer_use = buffer_added
        return false
    }
    return true
}

// One query slot a command buffer wrote.
//
// Queries carry no use state, so "did this command buffer write that slot" is the
// only thing a resolve needs from them: a slot this encoder wrote has a result to
// copy, one it did not may still be waiting for its first write.
Query_Set_Write :: struct {
    query_set: Query_Set,
    index:     u32,
}

// One command buffer's tracker: the stateful transcript plus the stateless
// resources it referenced, and the memory-initialisation actions it recorded.
//
// The actions are not applied here: submit applies them, so a discarded encoder
// never leaves a mark.
Tracker :: struct {
    buffers:             Buffer_Tracker,
    textures:            Texture_Tracker,
    views:               Stateless_Tracker(Texture_View),
    bind_groups:         Stateless_Tracker(Bind_Group),
    compute_pipelines:   Stateless_Tracker(Compute_Pipeline),
    render_pipelines:    Stateless_Tracker(Render_Pipeline),
    bundles:             Stateless_Tracker(Render_Bundle),
    query_sets:          Query_Set_Tracker,
    blas_s:              Blas_Tracker,
    tlas_s:              Stateless_Tracker(Tlas),
    init_actions:        [dynamic]Texture_Init_Action,
    // The buffer counterpart: the byte ranges a command buffer defines, needs or
    // discards, in the order it recorded them.
    buffer_init_actions: [dynamic]Buffer_Init_Action,
    // The query slots it wrote: what tells a resolve whether its results exist.
    query_set_writes:    [dynamic]Query_Set_Write,
    // Scratch projection of a bind group's buffers onto tracker indices, reused by
    // `tracker_set_and_remove_from_usage_scope_sparse` so the sparse merge allocates
    // nothing per dispatch. Storage only: `clear` empties it, `free` releases it.
    scratch_indices:     [dynamic]Tracker_Index,
}

tracker_init :: proc(
    t: ^Tracker,
    allocator: runtime.Allocator,
    buffer_ordered: Buffer_Uses,
    texture_ordered: Texture_Uses,
) {
    t^ = {}
    buffer_tracker_init(&t.buffers, allocator, buffer_ordered)
    texture_tracker_init(&t.textures, allocator, texture_ordered)
    stateless_tracker_init(&t.views, allocator)
    stateless_tracker_init(&t.bind_groups, allocator)
    stateless_tracker_init(&t.compute_pipelines, allocator)
    stateless_tracker_init(&t.render_pipelines, allocator)
    stateless_tracker_init(&t.bundles, allocator)
    query_set_tracker_init(&t.query_sets, allocator)
    blas_tracker_init(&t.blas_s, allocator)
    stateless_tracker_init(&t.tlas_s, allocator)
    t.init_actions.allocator = allocator
    t.buffer_init_actions.allocator = allocator
    t.query_set_writes.allocator = allocator
    t.scratch_indices.allocator = allocator
}

tracker_free :: proc(t: ^Tracker) {
    buffer_tracker_free(&t.buffers)
    texture_tracker_free(&t.textures)
    stateless_tracker_free(&t.views)
    stateless_tracker_free(&t.bind_groups)
    stateless_tracker_free(&t.compute_pipelines)
    stateless_tracker_free(&t.render_pipelines)
    stateless_tracker_free(&t.bundles)
    query_set_tracker_free(&t.query_sets)
    blas_tracker_free(&t.blas_s)
    stateless_tracker_free(&t.tlas_s)
    delete(t.init_actions)
    delete(t.buffer_init_actions)
    delete(t.query_set_writes)
    delete(t.scratch_indices)
    t^ = {}
}

// Drop the transcript, keeping the storage: a cleared tracker has the shape a
// fresh one does, minus the allocations. The ordering policy survives — it is
// device policy, not transcript state — and every complex texture state is
// released, so what a cleared tracker retains is list capacity only.
tracker_clear :: proc(t: ^Tracker) {
    buffer_tracker_clear(&t.buffers)
    texture_tracker_clear(&t.textures)
    stateless_tracker_clear(&t.views)
    stateless_tracker_clear(&t.bind_groups)
    stateless_tracker_clear(&t.compute_pipelines)
    stateless_tracker_clear(&t.render_pipelines)
    stateless_tracker_clear(&t.bundles)
    query_set_tracker_clear(&t.query_sets)
    blas_tracker_clear(&t.blas_s)
    stateless_tracker_clear(&t.tlas_s)
    clear(&t.init_actions)
    clear(&t.buffer_init_actions)
    clear(&t.query_set_writes)
    clear(&t.scratch_indices)
}

// Fold a pass's scope into this transcript.
tracker_set_from_usage_scope :: proc(t: ^Tracker, scope: ^Usage_Scope) {
    buffer_tracker_set_from_usage_scope(&t.buffers, &scope.buffers)
    texture_tracker_set_from_usage_scope(&t.textures, &scope.textures)
}

// Fold the resources a bind group names into this transcript and remove them from
// the scope, so a second dispatch in the same compute pass does not merge them
// again. This is how a compute pass moves one dispatch's bindings into its tracker.
tracker_set_and_remove_from_usage_scope_sparse :: proc(
    t: ^Tracker,
    scope: ^Usage_Scope,
    group: ^Bind_Group_States,
) {
    // The buffer side is named by index, the texture side by view (so the texture's
    // own range is used).
    clear(&t.scratch_indices)
    for &entry in group.buffers.buffers {
        append(&t.scratch_indices, entry.index)
    }
    buffer_tracker_set_and_remove_from_usage_scope_sparse(
        &t.buffers,
        &scope.buffers,
        t.scratch_indices[:],
    )
    texture_tracker_set_and_remove_from_usage_scope_sparse(
        &t.textures,
        &scope.textures,
        &group.views,
    )
}

// Record what this encoder did to a texture's contents. Applied at submit, in
// order.
tracker_record_init :: proc(
    t: ^Tracker,
    texture: Texture,
    range: Texture_Init_Range,
    kind: Memory_Init_Kind,
    aspect: Texture_Aspect = .All,
) {
    append(
        &t.init_actions,
        Texture_Init_Action{texture = texture, range = range, kind = kind, aspect = aspect},
    )
}

// Record what this encoder did to a buffer's contents. Buffers are tracked per
// byte, so the caller passes the range it wrote, read or discarded; the submission
// applies the actions in order, exactly as it does for textures.
tracker_record_buffer_init :: proc(
    t: ^Tracker,
    buffer: Buffer,
    range: Buffer_Init_Range,
    kind: Memory_Init_Kind,
) {
    append(&t.buffer_init_actions, Buffer_Init_Action{buffer = buffer, range = range, kind = kind})
}

// True when the latest action this encoder recorded for exactly `range` and
// `aspect` is a discard: a pass about to load it has to clear it first, in place.
// Actions are recorded per aspect, so one that does not name `aspect` (an `All`
// action names both) says nothing about it.
tracker_was_discarded :: proc(
    t: ^Tracker,
    texture: Texture,
    range: Texture_Init_Range,
    aspect: Texture_Aspect = .All,
) -> bool {
    for i := len(t.init_actions) - 1; i >= 0; i -= 1 {
        action := t.init_actions[i]
        if action.texture != texture {
            continue
        }
        if action.range.mip_start != range.mip_start ||
           action.range.mip_end != range.mip_end ||
           action.range.layer_start != range.layer_start ||
           action.range.layer_end != range.layer_end {
            continue
        }
        if action.aspect != .All && aspect != .All && action.aspect != aspect {
            continue
        }
        return action.kind == .Discarded
    }
    return false
}

// Record that this command buffer wrote `query_set`'s slot `index`. The write is
// the one thing that makes a slot's result available to a resolve.
tracker_record_query_write :: proc(t: ^Tracker, query_set: Query_Set, index: u32) {
    if tracker_query_written(t, query_set, index) {
        return
    }
    append(&t.query_set_writes, Query_Set_Write{query_set = query_set, index = index})
}

// True when this command buffer wrote `query_set`'s slot `index`.
tracker_query_written :: proc(t: ^Tracker, query_set: Query_Set, index: u32) -> bool {
    for write in t.query_set_writes {
        if write.query_set == query_set && write.index == index {
            return true
        }
    }
    return false
}

// True when this command buffer wrote every slot of `[first, end)`: the resolve can
// copy the range directly, since no slot depends on an earlier submission.
tracker_query_range_written :: proc(
    t: ^Tracker,
    query_set: Query_Set,
    first: u32,
    end: u32,
) -> bool {
    for index in first ..< end {
        if !tracker_query_written(t, query_set, index) {
            return false
        }
    }
    return true
}

// Drop the transitions collected so far.
tracker_clear_pending :: proc(t: ^Tracker) {
    buffer_tracker_clear_pending(&t.buffers)
    texture_tracker_clear_pending(&t.textures)
}

// The transitions this command buffer owes itself.
tracker_texture_transitions :: proc(t: ^Tracker) -> ^[dynamic]Texture_State_Transition {
    return &t.textures.temp
}

tracker_buffer_transitions :: proc(t: ^Tracker) -> ^[dynamic]Buffer_State_Transition {
    return &t.buffers.temp
}

// The device's authoritative state across submissions.
//
// A submission is applied by bringing the device state to each command buffer's
// `start` state — recording those transitions — and then advancing it to that
// buffer's `end` state.
//
// Every access must hold `VK_Device_Impl.trackers_mtx`. The `prepare` helpers
// grow and rewrite the arrays, so recording takes the exclusive lock even though
// it only reads the state; submit takes it under the submitter lock so the
// advanced state matches submission order.
Device_Tracker :: struct {
    allocator:       runtime.Allocator,
    buffers:         Device_Buffer_Tracker,
    textures:        Device_Texture_Tracker,
    buffer_ordered:  Buffer_Uses,
    texture_ordered: Texture_Uses,
}

device_tracker_init :: proc(
    d: ^Device_Tracker,
    allocator: runtime.Allocator,
    buffer_ordered: Buffer_Uses,
    texture_ordered: Texture_Uses,
) {
    d^ = {}
    d.allocator = allocator
    d.buffer_ordered = buffer_ordered
    d.texture_ordered = texture_ordered
    device_buffer_tracker_init(&d.buffers, allocator, buffer_ordered)
    device_texture_tracker_init(&d.textures, allocator, texture_ordered)
}

device_tracker_free :: proc(d: ^Device_Tracker) {
    device_buffer_tracker_free(&d.buffers)
    device_texture_tracker_free(&d.textures)
    d^ = {}
}

// Apply one submission: for each command buffer, emit the barriers that bring the
// device state to its `start` and advance the device state to its `end`. One
// transition list per command buffer, since each gets its own pre-barrier buffer.
device_tracker_track_submission :: proc(
    d: ^Device_Tracker,
    trackers: []^Tracker,
    texture_transitions: []^[dynamic]Texture_State_Transition,
    buffer_transitions: []^[dynamic]Buffer_State_Transition,
) {
    for tracker, i in trackers {
        if tracker == nil {
            continue
        }
        device_texture_tracker_set_from_tracker_and_drain_transitions(
            &d.textures,
            &tracker.textures,
            texture_transitions[i],
        )
        device_buffer_tracker_set_from_tracker_and_drain_transitions(
            &d.buffers,
            &tracker.buffers,
            buffer_transitions[i],
        )
    }
}
