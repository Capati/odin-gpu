#+build !js
package application

// Core
import "core:fmt"
import "core:slice"

// Opt-in frame pacing measurement.
//
// Enabled by passing `measure` to `build.bat`.
//
//     examples\build.bat examples\rotating_cube measure
//
// A pacing regression shows up as a *minority* of frames landing past a vsync
// deadline, so an average or a total frame count hides it completely. Report
// the distribution instead, and derive the miss budget from the observed median
// rather than hardcoding a refresh rate, so this stays valid at 30/60/120Hz and
// for uncapped runs.
//
// Output is written to stdout rather than through `context.logger`, because
// examples only install a logger in debug builds and measurement is most
// useful against release binaries.
MEASURE_FRAME_TIME :: #config(MEASURE_FRAME_TIME, false)

when MEASURE_FRAME_TIME {
    // Frames averaged into one reported window (~2s at 60Hz).
    FRAME_TIME_WINDOW :: 120

    // Frames discarded before measuring. Shader compilation and pipeline creation
    // always produce outliers and would poison the first window.
    FRAME_TIME_WARMUP :: 30

    // A frame counts as missed if it exceeds this multiple of the observed median.
    FRAME_TIME_MISS_RATIO :: 1.5

    frame_time_samples: [FRAME_TIME_WINDOW]f64
    frame_time_count: int
    frame_time_warmup: int

    frame_time_record :: proc(delta: f32) {
        if frame_time_warmup < FRAME_TIME_WARMUP {
            frame_time_warmup += 1
            return
        }

        frame_time_samples[frame_time_count] = f64(delta)
        frame_time_count += 1

        if frame_time_count == FRAME_TIME_WINDOW {
            frame_time_report()
            frame_time_count = 0
        }
    }

    @(private = "file")
    frame_time_report :: proc() {
        when MEASURE_FRAME_TIME {
            count := frame_time_count
            if count == 0 {
                return
            }

            // Sorting in place is fine: only the distribution matters, not the
            // original ordering.
            slice.sort(frame_time_samples[:count])

            median_ms := frame_time_samples[count / 2] * 1000
            p95_ms := frame_time_samples[min(int(f64(count) * 0.95), count - 1)] * 1000
            max_ms := frame_time_samples[count - 1] * 1000

            miss_threshold_ms := median_ms * FRAME_TIME_MISS_RATIO
            miss := 0
            for sample in frame_time_samples[:count] {
                if sample * 1000 > miss_threshold_ms {
                    miss += 1
                }
            }

            fmt.printfln(
                "FRAME_TIME frames=%d median=%.2f p95=%.2f max=%.2f miss=%d",
                count,
                median_ms,
                p95_ms,
                max_ms,
                miss,
            )
        }
    }
} else {
    _ :: slice
    _ :: fmt
    @(disabled = !MEASURE_FRAME_TIME)
    frame_time_record :: proc(delta: f32) {}
}

// Shared by both platform loops so there is exactly one measurement site.
iterate_frame :: proc(delta: f32) -> bool {
    frame_time_record(delta)
    return g_ctx.desc.iterate_cb(&g_ctx, delta)
}
