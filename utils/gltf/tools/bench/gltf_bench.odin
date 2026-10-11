package main

// Initial-load benchmark: vendor:cgltf vs utils/gltf.
//
// Build (release, optimized - see utils\gltf\tools\bench\gltf_bench.ps1):
//   odin build utils/gltf/tools/bench -o:size -disable-assert -no-bounds-check -out:tests/build/gltf_bench.exe
//
// Run:
//   gltf_bench [model_path] [iterations]

import "core:c"
import "core:fmt"
import "core:os"
import "core:sort"
import "core:strconv"
import "core:strings"
import "core:time"

import cgltf "vendor:cgltf"
import gltf "../.."

DEFAULT_MODEL_PATH :: "examples/build/assets/models/DamagedHelmet.glb"
DEFAULT_ITERATIONS :: 30
WARMUP_ITERATIONS :: 1

PHASE_COUNT :: 3
PHASE_NAMES :: [PHASE_COUNT]string{"parse", "load_buffers", "total"}

Samples :: struct {
    phase: [PHASE_COUNT][]f64, // seconds, one entry per timed iteration
}

Stats :: struct {
    min, median, mean, max: f64, // seconds
}

fail :: proc(format: string, args: ..any) {
    fmt.eprint("FAIL: ")
    fmt.eprintfln(format, ..args)
    os.exit(1)
}

cgltf_find_attribute :: proc(primitive: ^cgltf.primitive, kind: cgltf.attribute_type, set: c.int = 0) -> ^cgltf.accessor {
    for &attribute in primitive.attributes {
        if attribute.type == kind && attribute.index == set {
            return attribute.data
        }
    }
    return nil
}

// -----------------------------------------------------------------------------
// Sanity check
//
// Load the model with both parsers once and verify they agree on the shape of
// the document. A partial or failed load must never be mistaken for a fast one.
// -----------------------------------------------------------------------------

sanity_check :: proc(path: string) -> (mesh_count: int, attribute_count: int) {
    c_path := strings.clone_to_cstring(path, context.temp_allocator)

    cgltf_options: cgltf.options
    c_data, c_result := cgltf.parse_file(cgltf_options, c_path)
    if c_result != .success || c_data == nil {
        fail("cgltf parse failed for %s: %v", path, c_result)
    }
    defer cgltf.free(c_data)
    if cgltf.load_buffers(cgltf_options, c_data, c_path) != .success {
        fail("cgltf buffer loading failed for %s", path)
    }

    odin_doc, odin_err := gltf.parse_file(path)
    if odin_err != .None {
        fail("utils/gltf parse failed for %s: %v", path, odin_err)
    }
    defer gltf.destroy(odin_doc)
    if load_err := gltf.load_buffers(odin_doc); load_err != .None {
        fail("utils/gltf buffer loading failed for %s: %v", path, load_err)
    }

    mesh_count = len(c_data.meshes)
    if mesh_count == 0 {
        fail("%s contains no meshes", path)
    }
    if len(odin_doc.meshes) != mesh_count {
        fail("mesh count differs (utils/gltf=%d, cgltf=%d)", len(odin_doc.meshes), mesh_count)
    }

    c_primitives := c_data.meshes[0].primitives
    odin_primitives := odin_doc.meshes[0].primitives
    if len(odin_primitives) == 0 || len(c_primitives) == 0 {
        fail("first mesh has no primitives in %s", path)
    }
    primitive_count := len(c_primitives)
    if len(odin_primitives) != primitive_count {
        fail(
            "first mesh primitive count differs (utils/gltf=%d, cgltf=%d)",
            len(odin_primitives), primitive_count,
        )
    }

    c_first := &c_primitives[0]
    odin_first := &odin_primitives[0]
    if len(c_first.attributes) != len(odin_first.attributes) {
        fail(
            "first primitive attribute count differs (utils/gltf=%d, cgltf=%d)",
            len(odin_first.attributes), len(c_first.attributes),
        )
    }
    if (c_first.indices != nil) != (odin_first.indices != nil) {
        fail(
            "first primitive index presence differs (utils/gltf=%v, cgltf=%v)",
            odin_first.indices != nil, c_first.indices != nil,
        )
    }

    // The three attributes gltf_compare verifies in depth; here only their
    // presence and element counts, which is enough to catch a truncated load.
    position := cgltf_find_attribute(c_first, .position)
    normal := cgltf_find_attribute(c_first, .normal)
    texcoord := cgltf_find_attribute(c_first, .texcoord)
    if position == nil || normal == nil || texcoord == nil {
        fail("cgltf first primitive is missing POSITION, NORMAL, or TEXCOORD_0")
    }

    check := proc(label: string, odin_accessor: ^gltf.Accessor, c_accessor: ^cgltf.accessor) {
        if odin_accessor == nil || c_accessor == nil {
            fail("%s accessor presence differs (utils/gltf=%v, cgltf=%v)",
                label, odin_accessor != nil, c_accessor != nil)
        }
        if odin_accessor.count != int(c_accessor.count) {
            fail("%s count differs (utils/gltf=%d, cgltf=%d)",
                label, odin_accessor.count, c_accessor.count)
        }
    }
    check("POSITION", gltf.find_accessor(odin_first, .Position), position)
    check("NORMAL", gltf.find_accessor(odin_first, .Normal), normal)
    check("TEXCOORD_0", gltf.find_accessor(odin_first, .Texcoord, 0), texcoord)
    if odin_first.indices != nil {
        check("INDICES", odin_first.indices, c_first.indices)
    }

    return mesh_count, len(odin_first.attributes)
}

// -----------------------------------------------------------------------------
// Timed loops
//
// One discarded warmup load precedes the timed iterations so the OS file cache
// and allocator state have settled. Per iteration the three phases are:
//   parse        file read + JSON/GLB parse (parse_file)
//   load_buffers buffer resolution (load_buffers)
//   total        the two combined; teardown (free/destroy) is not timed
// -----------------------------------------------------------------------------

bench_cgltf :: proc(path: string, iterations: int, warmup: int) -> (s: Samples) {
    for i in 0..<PHASE_COUNT {
        s.phase[i] = make([]f64, iterations, context.allocator)
    }
    c_path := strings.clone_to_cstring(path, context.temp_allocator)
    options: cgltf.options

    for i in 0 ..< warmup + iterations {
        start := time.tick_now()
        data, result := cgltf.parse_file(options, c_path)
        parsed := time.tick_now()
        if result != .success || data == nil {
            fail("cgltf parse failed for %s: %v", path, result)
        }
        if cgltf.load_buffers(options, data, c_path) != .success {
            cgltf.free(data)
            fail("cgltf buffer loading failed for %s", path)
        }
        loaded := time.tick_now()
        cgltf.free(data)

        if i >= warmup {
            j := i - warmup
            s.phase[0][j] = f64(time.duration_seconds(time.tick_diff(start, parsed)))
            s.phase[1][j] = f64(time.duration_seconds(time.tick_diff(parsed, loaded)))
            s.phase[2][j] = f64(time.duration_seconds(time.tick_diff(start, loaded)))
        }
    }
    return s
}

bench_gltf :: proc(path: string, iterations: int, warmup: int) -> (s: Samples) {
    for i in 0..<PHASE_COUNT {
        s.phase[i] = make([]f64, iterations, context.allocator)
    }

    for i in 0 ..< warmup + iterations {
        start := time.tick_now()
        document, parse_err := gltf.parse_file(path)
        parsed := time.tick_now()
        if parse_err != .None {
            fail("utils/gltf parse failed for %s: %v", path, parse_err)
        }
        if load_err := gltf.load_buffers(document); load_err != .None {
            gltf.destroy(document)
            fail("utils/gltf buffer loading failed for %s: %v", path, load_err)
        }
        loaded := time.tick_now()

        if i >= warmup {
            j := i - warmup
            s.phase[0][j] = f64(time.duration_seconds(time.tick_diff(start, parsed)))
            s.phase[1][j] = f64(time.duration_seconds(time.tick_diff(parsed, loaded)))
            s.phase[2][j] = f64(time.duration_seconds(time.tick_diff(start, loaded)))
        }
        gltf.destroy(document)
    }
    return s
}

// -----------------------------------------------------------------------------
// Statistics and report
// -----------------------------------------------------------------------------

compute_stats :: proc(samples: []f64) -> Stats {
    if len(samples) == 0 {
        return {}
    }
    sorted := make([]f64, len(samples), context.temp_allocator)
    copy(sorted, samples)
    sort.quick_sort(sorted)

    result := Stats{min = sorted[0], max = sorted[len(sorted) - 1]}
    mid := len(sorted) / 2
    if len(sorted) % 2 == 1 {
        result.median = sorted[mid]
    } else {
        result.median = (sorted[mid - 1] + sorted[mid]) / 2
    }
    sum: f64
    for value in sorted {
        sum += value
    }
    result.mean = sum / f64(len(sorted))
    return result
}

sample_delete :: proc(s: Samples) {
    for phase in s.phase {
        delete(phase)
    }
}

print_phase :: proc(name: string, cgltf_stats, odin_stats: Stats) {
    fmt.printfln("%s (ms)", name)
    fmt.printfln(
        "  %-14s  min %.3f  median %.3f  mean %.3f  max %.3f",
        "vendor:cgltf",
        cgltf_stats.min * 1000, cgltf_stats.median * 1000,
        cgltf_stats.mean * 1000, cgltf_stats.max * 1000,
    )
    fmt.printfln(
        "  %-14s  min %.3f  median %.3f  mean %.3f  max %.3f",
        "utils/gltf",
        odin_stats.min * 1000, odin_stats.median * 1000,
        odin_stats.mean * 1000, odin_stats.max * 1000,
    )
    NOISE_FLOOR :: 1e-5 // ten microseconds, in seconds (Stats are seconds)
    if cgltf_stats.median < NOISE_FLOOR && odin_stats.median < NOISE_FLOOR {
        fmt.println("  -> below noise floor, ratio not meaningful")
    } else if cgltf_stats.median <= 0 || odin_stats.median <= 0 {
        fmt.println("  -> medians too small to ratio")
    } else if ratio := cgltf_stats.median / odin_stats.median; ratio >= 1 {
        fmt.printfln("  -> utils/gltf is %.2fx faster (median)", ratio)
    } else {
        fmt.printfln("  -> utils/gltf is %.2fx slower (median)", odin_stats.median / cgltf_stats.median)
    }
    fmt.println("")
}

print_report :: proc(path: string, file_size: i64, iterations, warmup: int, mesh_count, attribute_count: int, cgltf_samples, odin_samples: Samples) {
    fmt.println("=== glTF initial-load benchmark ===")
    fmt.printfln("model      : %s (%.1f MB)", path, f64(file_size) / (1024 * 1024))
    fmt.printfln("iterations : %d (%d warmup per parser)", iterations, warmup)
    fmt.printfln("parsers    : vendor:cgltf vs utils/gltf")
    fmt.printfln("sanity     : OK (%d meshes, %d attributes on first primitive, accessors agree)", mesh_count, attribute_count)
    fmt.println("")

    phase_names := PHASE_NAMES
    for phase in 0 ..< PHASE_COUNT {
        print_phase(
            phase_names[phase],
            compute_stats(cgltf_samples.phase[phase]),
            compute_stats(odin_samples.phase[phase]),
        )
    }
}

// -----------------------------------------------------------------------------

main :: proc() {
    path := DEFAULT_MODEL_PATH
    iterations := DEFAULT_ITERATIONS

    if len(os.args) > 1 {
        path = os.args[1]
    }
    if len(os.args) > 2 {
        parsed, ok := strconv.parse_int(os.args[2])
        if !ok || parsed < 1 {
            fail("invalid iteration count %q (need a positive integer)", os.args[2])
        }
        iterations = parsed
    }

    file_info, stat_err := os.stat(path, context.allocator)
    if stat_err != nil {
        fail("cannot stat %s: %v", path, stat_err)
    }
    defer os.file_info_delete(file_info, context.allocator)

    mesh_count, attribute_count := sanity_check(path)

    fmt.printfln("running cgltf (%d timed iterations)...", iterations)
    cgltf_samples := bench_cgltf(path, iterations, WARMUP_ITERATIONS)
    defer sample_delete(cgltf_samples)

    fmt.printfln("running utils/gltf (%d timed iterations)...", iterations)
    odin_samples := bench_gltf(path, iterations, WARMUP_ITERATIONS)
    defer sample_delete(odin_samples)

    print_report(
        path, file_info.size, iterations, WARMUP_ITERATIONS,
        mesh_count, attribute_count, cgltf_samples, odin_samples,
    )
}
