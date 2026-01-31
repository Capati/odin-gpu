package gpu

VERSION_MAJOR :: 0
VERSION_MINOR :: 0
VERSION_PATCH :: 0

Version :: struct {
    major, minor, patch: u32,
}

get_version :: #force_inline proc "contextless" () -> Version {
    return { VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH }
}
