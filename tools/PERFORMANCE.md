# Backend performance checklist

Performance is judged **same-session**, not by absolute numbers: frame times drift
20%+ between sessions, so a change is compared against a binary built from the
pre-change source in the same session, interleaved with the candidate. The published
bundle cost is 0.219 us/draw (`a` = 121 us, R2 = 0.998).

Every backend change runs the following, in this order. The short version:

```powershell
odin check gpu -vet -vet-style -strict-style -vet-using-param -warnings-as-errors -no-entry-point
odin test tests/unit; odin test tests/vulkan; odin test tests/cts
tools/measure_allocs.ps1 -FailOnAllocs
tools/measure_bench.ps1 -Suite <relevant> -Runs 5 -BaselineExe tests/build/vk_bench_baseline.exe
tests/harness/harness.ps1 -Targets <...> -Modes release -SkipTests -PaceSeconds 3 -PaceCount 4
```

A refused measurement is a result, not a pass; see section 4.

## 0. Keep the baselines current

- Correctness first: `odin check gpu` with the vet/style set above, then
  `odin test tests/unit`, `odin test tests/vulkan`, `odin test tests/cts`.
  A change that fails CTS is not benchmarked.
- After a validated change:
  `copy tests/build/vk_bench.exe tests/build/vk_bench_baseline.exe`
- Record the allocation baseline for the suites you touch (see below) alongside the
  timing baseline. The benchmark binary embeds the tracker, so the two artifacts
  stay in step.

## 1. Rebuild both sides

Build the pre-change source and the candidate in the same session. A stale binary
has read +2.4% where a fair rebuild read -4.3%; identical source built twice has
differed by 25% on one workload. Never compare against an exe from an earlier session.

## 2. Headless A/B (timing attribution)

```powershell
tools/measure_bench.ps1 -Suite <relevant> -Runs 5 -BaselineExe tests/build/vk_bench_baseline.exe
```

- Use the suites that exercise the changed path.
- Report median-of-medians and spread. Build-to-build variance is +/-3-5%; a delta
  under ~5% without a clean spread is **neutral**, not a win.
- If spread >5% or runs are unsettled, re-run; do not quote the first number.

## 3. Heap allocations (every change)

```powershell
tools/measure_allocs.ps1 -FailOnAllocs
```

This measures Odin heap traffic, not driver/VMA memory. It is the only instrument
that sees upload/submit churn inside the real scene, because those costs are far
below the timing harness's resolution.

Acceptance:

- **Steady state stays at the floor.** Every hot suite currently reads
  0.01-0.03 allocations/frame. The script's hard gate is `-MaxAllocsPerFrame 0.25`
  (catches anything scaling with frames, tolerates one-time growth); a change that
  adds a repeating site should be treated as a regression even below that.
- **No site scales with frames.** Check `MEASURE-GPU-ALLOC-SITE` lines: counts that
  track the measured frame count are churn; early-window counts that stop are
  high-water growth.
- **The touched path does not grow.** Read the per-site table for the changed
  suites before and after; the affected site's count and bytes must not increase.
- **Bytes count too.** A fixed per-resource cost (e.g. 4 KiB per bundle) multiplied
  by thousands of resources is a memory problem even when the allocation count looks
  constant.

Rules that make the numbers usable:

- The gate takes the lower of `-Runs` (default 2) runs. `queue_write_buffer` can take
  the staged path instead of the direct host write when the queue is busy; the
  minimum is the steady floor, not an average.
- **Calibrate the instrument.** `--track-allocs 1 --alloc-selftest 1` must report
  exactly one allocation at measurement start. A clean zero with the calibration
  missing means the tracker is broken, not that the code is clean. (The first
  version of the tracker reported a perfect zero because Odin restores `context` at
  block exit; the installation must be at function scope.)
- For paths that create resources, measure per call:
  ```powershell
  tests/build/vk_bench.exe --bench churn --op bind_group   --count 32 --frames 400 --track-allocs 1
  tests/build/vk_bench.exe --bench churn --op bundle       --count 32 --frames 400 --track-allocs 1
  tests/build/vk_bench.exe --bench churn --op view         --count 32 --frames 400 --track-allocs 1
  tests/build/vk_bench.exe --bench churn --op texture_write --count 32 --frames 400 --track-allocs 1
  tests/build/vk_bench.exe --bench churn --op map_readback --count 32 --frames 400 --track-allocs 1
  ```
  Creation costs are proportional to creation, not frames; compare per-call counts
  and bytes before/after rather than expecting zero.

## 4. Real-scene check

The headless suites do not cover the full recording/submit boundary. Build the
`render_bundles` example with `-define:MEASURE=true` and run the same count against
the pre-change binary in the same session, interleaved:

```powershell
odin build examples/render_bundles -out:<candidate>.exe -o:speed -disable-assert -no-bounds-check -subsystem:windows -define:MEASURE=true -define:SHARED_BINDS=false
<candidate>.exe --asteroids 5000 --bundle 1 --frames 1200
```

- Compare medians only within the session; the example prints `MEASURE-GPU` with
  median and p95.
- Discard runs that lose vsync pacing, and require at least three clean runs per
  side before quoting a delta.
- For a published per-draw number, run the count sweep (`--asteroids 0/2500/5000`)
  and fit `a + b*n`; quote the spreads together with the fit.

## 5. Frame pacing

```powershell
tests/harness/harness.ps1 -Targets render_bundles,threaded_upload,two_cubes -Modes release -SkipTests -PaceSeconds 3 -PaceCount 4
```

Green means medians of 16.66-16.69 ms and `failures: 0 warnings: 0`. An occasional
`miss` is usually compositor noise; a shifted median is a real latency regression.

## 6. If something moved

Profile before changing code. Build the benchmark with a linker map, sample the
running process with a flat profiler, and compare per-symbol shares, not just totals;
inlining redistributes percentages. Re-run the A/B on the suspect path alone and keep
or revert on the target metric.

## 7. What each kind of change must run

| change | timing | allocations |
| --- | --- | --- |
| recording / validation | `manual`, `bundle`, `state` + real scene | all suites (steady state) |
| uploads / writes | `write_buffer`, `dyn_offset` | `write_buffer`, `dyn_offset` |
| submit / queue | `multipass`, `parallel`, `bundle` | all suites |
| resource creation | `--bench churn --op ...` | matching churn op |
| descriptors / bind groups | `state --op bind_group`, `manual_shared` | `state`, `manual_shared` |
| surface / present | examples harness + `tests/surface_stress` | `texture_write`, churn |
| shaders / pipelines | CTS + examples harness | creation churn ops |

## 8. Record the result

- Put the measured delta **and its spread** in
  `C:\Users\Rafael\.opencode\plan\vulkan-performance-and-benchmarks.md`.
- Update `examples/render_bundles/README.md` only for same-session, gated numbers.
- Record refusals as refusals; a refused measurement is information, not a zero.
