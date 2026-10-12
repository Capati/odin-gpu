package gpu

Tlas :: distinct Handle

tlas_set_label: proc(tlas: Tlas, label: string, loc := #caller_location)

tlas_add_ref: proc(tlas: Tlas, loc := #caller_location)

tlas_release: proc(tlas: Tlas, loc := #caller_location)
