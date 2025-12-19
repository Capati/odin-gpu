package gpu

// Core
import "base:runtime"
import intr "base:intrinsics"

Refcount_Type :: distinct u32

Ref_Count :: struct {
    count: Refcount_Type,
}

ref_count_init :: proc "contextless" (ref: ^Ref_Count, loc: runtime.Source_Code_Location) {
    old_value := intr.atomic_add(&ref.count, 1)
    assert_contextless(old_value == 0, "Reference counter already initialized", loc)
}

ref_count_add :: #force_inline proc "contextless" (
    ref: ^Ref_Count,
    loc: runtime.Source_Code_Location,
) {
    old_count := intr.atomic_add(&ref.count, 1)
    assert_contextless(
        old_count > 0,
        "Attempting to add reference to destroyed/invalid object",
        loc,
    )
}

ref_count_sub :: #force_inline proc "contextless" (
    ref: ^Ref_Count,
    loc: runtime.Source_Code_Location,
) -> (
    should_release: bool,
) {
    old_count := intr.atomic_sub(&ref.count, 1)
    assert_contextless(old_count > 0, "Reference count underflow", loc)
    should_release = old_count == 1 // Was this the last reference?
    return
}

@(require_results)
ref_count_get :: #force_inline proc "contextless" (ref: ^Ref_Count) -> Refcount_Type {
    return intr.atomic_load(&ref.count)
}

@(require_results)
ref_count_is_unique :: #force_inline proc "contextless" (ref: ^Ref_Count) -> bool {
    return ref_count_get(ref) == 1
}
