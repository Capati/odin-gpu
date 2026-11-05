package gpu

VERSION        :: [4]u8{0, 1, 0, 0}
VERSION_STRING :: "0.1.0.0"

// Returns the current `odin-gpu` version.
get_version :: proc(loc := #caller_location) -> u32 {
    return 0
}
