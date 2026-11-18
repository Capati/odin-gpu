#+build !js
package render_bundles

import "core:os"
import "core:strconv"

// Command-line parsing for the scripted measurement mode. Lives in its own
// file because `core:os` has no js/wasm implementation (importing it under
// that target panics), and this file is excluded from web builds; there the
// compile-time #config defaults stand. Mirrored file-for-file in
// the comparison example so the two cannot drift.
when MEASURE {
    measure_parse_args :: proc() {
        args := os.args
        i := 1
        for i < len(args) {
            value: string
            if i + 1 < len(args) {
                value = args[i + 1]
            }
            consumed := false

            if args[i] == "--asteroids" && value != "" {
                if n, ok := strconv.parse_int(value, 10); ok {
                    measure_runtime.asteroids = n
                }
                consumed = true
            }
            if args[i] == "--bundle" && value != "" {
                if n, ok := strconv.parse_int(value, 10); ok {
                    measure_runtime.bundle = n != 0
                }
                consumed = true
            }
            if args[i] == "--frames" && value != "" {
                if n, ok := strconv.parse_int(value, 10); ok {
                    measure_runtime.frames = n
                }
                consumed = true
            }

            i += consumed ? 2 : 1
        }
    }
}
