#+build !js
package vk_bench

// Allocation-count instrumentation for the benchmark executable.
//
// `--track-allocs 1` installs this allocator as `context.allocator` before the
// GPU instance exists, so it sees every Odin heap allocation the backend makes:
// the instance, adapter and device capture the allocator they were created with,
// and the command-buffer/pass arenas back themselves from that captured
// allocator too. Worker threads install the same allocator on their own contexts
// (`parallel_worker_proc`), and callbacks that restore `context.allocator =
// impl.allocator` keep pointing at it.
//
// Counting starts on the first measured frame (`frame == warmup`) and stops when
// the report is printed, so instance/device creation, pipeline and resource setup
// and the warm-up frames are excluded. Nothing is locked or recorded while the
// tracker is not measuring, so runs without the flag pay one predictable branch
// per allocation.
//
// The tracker never allocates on its own behalf: the site table is a fixed array,
// and the report copies it out and disables tracking before formatting anything
// (formatting itself allocates).
//
// This counts Odin heap traffic, not driver/VMA allocations. It answers "does the
// steady-state frame allocate, and from which call site", which is the churn that
// shows up as malloc contention and unpredictable frame times.

import "base:runtime"
import "core:fmt"
import "core:sync"

ALLOC_SITE_MAX :: 512

Alloc_Site :: struct {
    file:    string,
    line:    i32,
    allocs:  u64,
    resizes: u64,
    bytes:   u64,
}

Alloc_Tracker :: struct {
    backing:     runtime.Allocator,
    mtx:         sync.Mutex,
    installed:   bool,
    measuring:   bool,
    allocs:      u64,
    alloc_bytes: u64,
    frees:       u64,
    resizes:     u64,
    grow_bytes:  u64,
    free_all:    u64,
    sites:       [ALLOC_SITE_MAX]Alloc_Site,
    site_count:  int,
    overflow:    u64,
    // Calibration: when set, `begin_measure` performs one allocation so the
    // report must show exactly one event at this file. A zero report with the
    // marker absent means the instrument, not the code under test.
    selftest:    bool,
}

@(private = "file")
g_alloc_tracker: Alloc_Tracker

// Installs the tracker. Call before creating the instance so every object
// captures the tracked allocator.
alloc_tracker_install :: proc(backing: runtime.Allocator, selftest := false) {
    g_alloc_tracker = {}
    g_alloc_tracker.backing = backing
    g_alloc_tracker.installed = true
    g_alloc_tracker.selftest = selftest
}

alloc_tracker_allocator :: proc() -> runtime.Allocator {
    return runtime.Allocator{procedure = _alloc_tracker_proc, data = &g_alloc_tracker}
}

alloc_tracker_enabled :: proc() -> bool {
    return g_alloc_tracker.installed
}

// Diagnostic: is the calling thread's context actually routed through the
// tracker? Used by the self-test to prove the instrument, not the code.
alloc_tracker_context_active :: proc() -> bool {
    return context.allocator.data == rawptr(&g_alloc_tracker)
}

// Idempotent: the first measured frame resets the counters, later calls do
// nothing. Called from each suite's `frame >= warmup` branch.
alloc_tracker_begin_measure :: proc() {
    t := &g_alloc_tracker
    if !t.installed {
        return
    }

    sync.lock(&t.mtx)
    if t.measuring {
        sync.unlock(&t.mtx)
        return
    }

    t.measuring = true
    t.allocs = 0
    t.alloc_bytes = 0
    t.frees = 0
    t.resizes = 0
    t.grow_bytes = 0
    t.free_all = 0
    t.site_count = 0
    t.overflow = 0
    for i in 0 ..< ALLOC_SITE_MAX {
        t.sites[i] = {}
    }
    selftest := t.selftest
    sync.unlock(&t.mtx)

    // Outside the lock: the tracker is live now, and the mutex is not
    // reentrant.
    if selftest {
        fmt.printfln(
            "ALLOC-SELFTEST installed=%v measuring=%v context_is_tracker=%v",
            t.installed,
            t.measuring,
            alloc_tracker_context_active(),
        )
        p := new(u64)
        free(p)
        fmt.printfln("ALLOC-SELFTEST after allocs=%d sites=%d", t.allocs, t.site_count)
    }
}

alloc_tracker_report :: proc(suite: string, frames, top: int) {
    t := &g_alloc_tracker
    if !t.installed {
        return
    }

    sync.lock(&t.mtx)
    t.installed = false
    t.measuring = false
    allocs := t.allocs
    alloc_bytes := t.alloc_bytes
    frees := t.frees
    resizes := t.resizes
    grow_bytes := t.grow_bytes
    free_all := t.free_all
    overflow := t.overflow
    site_count := t.site_count
    sites := t.sites
    sync.unlock(&t.mtx)

    measured := max(frames, 1)
    fmt.printfln(
        "MEASURE-GPU-ALLOC suite=%s frames=%d allocs=%d allocs_per_frame=%.2f alloc_bytes=%d frees=%d resizes=%d grow_bytes=%d free_all=%d sites=%d overflow=%d",
        suite,
        measured,
        allocs,
        f64(allocs) / f64(measured),
        alloc_bytes,
        frees,
        resizes,
        grow_bytes,
        free_all,
        site_count,
        overflow,
    )

    // Selection sort, no allocation: sites are few and the report runs once.
    shown := min(top, site_count)
    used: [ALLOC_SITE_MAX]bool
    for _ in 0 ..< shown {
        best := -1
        for i in 0 ..< site_count {
            if used[i] {
                continue
            }
            if best < 0 || sites[i].allocs + sites[i].resizes > sites[best].allocs + sites[best].resizes {
                best = i
            }
        }
        if best < 0 {
            break
        }
        used[best] = true
        fmt.printfln(
            "MEASURE-GPU-ALLOC-SITE allocs=%d resizes=%d bytes=%d %s:%d",
            sites[best].allocs,
            sites[best].resizes,
            sites[best].bytes,
            sites[best].file,
            sites[best].line,
        )
    }
}

@(private = "file")
_alloc_tracker_record_locked :: proc(
    t: ^Alloc_Tracker,
    allocs, resizes, bytes: u64,
    loc: runtime.Source_Code_Location,
) {
    t.alloc_bytes += bytes
    for i in 0 ..< t.site_count {
        site := &t.sites[i]
        if site.line == loc.line && site.file == loc.file_path {
            site.allocs += allocs
            site.resizes += resizes
            site.bytes += bytes
            return
        }
    }
    if t.site_count >= ALLOC_SITE_MAX {
        t.overflow += 1
        return
    }
    t.sites[t.site_count] = Alloc_Site {
        file    = loc.file_path,
        line    = loc.line,
        allocs  = allocs,
        resizes = resizes,
        bytes   = bytes,
    }
    t.site_count += 1
}

@(private = "file")
_alloc_tracker_proc :: proc(
    allocator_data: rawptr,
    mode: runtime.Allocator_Mode,
    size, alignment: int,
    old_memory: rawptr,
    old_size: int,
    loc := #caller_location,
) -> ([]byte, runtime.Allocator_Error) {
    t := (^Alloc_Tracker)(allocator_data)
    data, err := t.backing.procedure(
        t.backing.data,
        mode,
        size,
        alignment,
        old_memory,
        old_size,
        loc,
    )
    // Query modes are feature negotiation, not allocation.
    if !t.installed || err != .None {
        return data, err
    }

    sync.lock(&t.mtx)
    defer sync.unlock(&t.mtx)
    if !t.measuring {
        return data, err
    }

    switch mode {
    case .Alloc, .Alloc_Non_Zeroed:
        n := max(size, 0)
        t.allocs += 1
        _alloc_tracker_record_locked(t, 1, 0, u64(n), loc)
    case .Resize, .Resize_Non_Zeroed:
        // Only growth is an allocation-class event; a shrink is still a resize.
        t.resizes += 1
        growth := 0
        if size > old_size {
            growth = size - old_size
            t.grow_bytes += u64(growth)
        }
        _alloc_tracker_record_locked(t, 0, 1, u64(growth), loc)
    case .Free:
        t.frees += 1
    case .Free_All:
        t.free_all += 1
    case .Query_Features, .Query_Info:
    }
    return data, err
}
