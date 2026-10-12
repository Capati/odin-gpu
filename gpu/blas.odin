package gpu

Blas :: distinct rawptr

blas_set_label: proc(blas: Blas, label: string, loc := #caller_location)

blas_add_ref: proc(blas: Blas, loc := #caller_location)

blas_release: proc(blas: Blas, loc := #caller_location)
