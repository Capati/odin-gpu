#+build !js
package texture_3d

// Core
import "core:thread"
import info "core:sys/info"

@(private)
Noise_Job :: struct {
    noise: ^Perlin_Noise,
    data:  []u8,
}

@(private)
noise_slice_task :: proc(t: thread.Task) {
    job := (^Noise_Job)(t.data)
    generate_noise_slice(job.noise, job.data, t.user_index)
}

generate_noise_texture_data :: proc(noise: ^Perlin_Noise, data: []u8) {
    // Each worker owns one disjoint Z slice, while sharing the read-only
    // permutation table for the duration of generation.
    job := Noise_Job{noise, data}

    _, logical_cores, core_count_ok := info.cpu_core_count()
    worker_count := 1
    if core_count_ok {
        worker_count = max(1, min(logical_cores, NOISE_TEX_DEPTH))
    }

    pool: thread.Pool
    thread.pool_init(&pool, context.allocator, worker_count)
    defer thread.pool_destroy(&pool)

    for z in 0..<NOISE_TEX_DEPTH {
        thread.pool_add_task(&pool, context.allocator, noise_slice_task, &job, z)
    }
    thread.pool_start(&pool)
    thread.pool_finish(&pool)
}
