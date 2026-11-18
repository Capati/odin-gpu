package cts

// Core
import "core:testing"

// Local
import gpu "../../gpu"

// Ported from the CTS's `api/validation/encoding/cmds/compute_pass.spec.ts`:
// pipeline state/device, direct
// dispatch per-dimension budgets and the indirect dispatch argument buffer.

cts_compute_run :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    pipeline: gpu.Compute_Pipeline,
    sizes: [3]u32,
    indirect: gpu.Buffer,
    use_indirect: bool,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    testing.expect(t, encoder != {}, "failed to create the command encoder")
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, pipeline)
    if use_indirect {
        gpu.compute_pass_dispatch_workgroups_indirect(pass, indirect, 0)
    } else {
        gpu.compute_pass_dispatch_workgroups(pass, sizes[0], sizes[1], sizes[2])
    }
    gpu.compute_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

cts_compute_set_pipeline :: proc(
    t: ^testing.T,
    f: CTS_Fixture,
    pipeline: gpu.Compute_Pipeline,
) -> bool {
    before := cts_errors()
    encoder := gpu.device_create_command_encoder(f.device)
    pass := gpu.command_encoder_begin_compute_pass(encoder)
    gpu.compute_pass_set_pipeline(pass, pipeline)
    gpu.compute_pass_end(pass)
    command_buffer := gpu.command_encoder_finish(encoder)
    errors := cts_errors() - before
    if command_buffer != {} {
        gpu.command_buffer_release(command_buffer)
    }
    gpu.command_encoder_release(encoder)
    return errors > 0
}

@(test)
cts_compute_pass_set_pipeline :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    pipeline := cts_make_compute_pipeline(f.device)
    testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
    defer gpu.compute_pipeline_release(pipeline)

    errors := cts_compute_set_pipeline(t, f, pipeline)
    cts_expect_outcome(t, errors ? 1 : 0, false, "setPipeline with a live pipeline")

    errors = cts_compute_set_pipeline(t, f, {})
    cts_expect_outcome(t, errors ? 1 : 0, true, "setPipeline with an empty pipeline")
}

@(test)
cts_compute_pass_pipeline_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)

    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : f.device
        pipeline := cts_make_compute_pipeline(device)
        testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
        errors := cts_compute_set_pipeline(t, f, pipeline)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "compute pipeline device mismatch")
        gpu.compute_pipeline_release(pipeline)
    }
}

@(test)
cts_compute_pass_dispatch_sizes :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    pipeline := cts_make_compute_pipeline(f.device)
    testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
    defer gpu.compute_pipeline_release(pipeline)

    max_workgroups := gpu.device_get_limits(f.device).max_compute_workgroups_per_dimension
    rows := [6][2]u64{
        {0, 0},
        {1, 0},
        {u64(max_workgroups), 0},
        {u64(max_workgroups) + 1, 1},
        {0x7FFFFFFF, 1},
        {0xFFFFFFFF, 1},
    }
    indirect := gpu.device_create_buffer(f.device, {size = 12, usage = {.Indirect}})
    defer gpu.buffer_release(indirect)

    for dimension in 0 ..< 3 {
        for row in rows {
            sizes: [3]u32 = {1, 1, 1}
            sizes[dimension] = u32(row[0])
            errors := cts_compute_run(t, f, pipeline, sizes, {}, false)
            cts_expect_outcome(t, errors ? 1 : 0, row[1] != 0,
                "dispatch workgroup count row")

            errors = cts_compute_run(t, f, pipeline, sizes, indirect, true)
            cts_expect_outcome(t, errors ? 1 : 0, false, "indirect dispatch row")
        }
    }
}

@(test)
cts_compute_pass_indirect_state :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    pipeline := cts_make_compute_pipeline(f.device)
    testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
    defer gpu.compute_pipeline_release(pipeline)

    offsets := [5]u64{0, 4, 12, 1, 16}
    for state in 0 ..< 3 {
        for offset in offsets {
            buffer: gpu.Buffer
            switch state {
            case 0:
                buffer = gpu.device_create_buffer(f.device, {size = 24, usage = {.Indirect}})
            case 1:
                buffer = {}
            case:
                buffer = gpu.device_create_buffer(f.device, {size = 24, usage = {.Indirect}})
                gpu.buffer_release(buffer)
            }
            before := cts_errors()
            encoder := gpu.device_create_command_encoder(f.device)
            pass := gpu.command_encoder_begin_compute_pass(encoder)
            gpu.compute_pass_set_pipeline(pass, pipeline)
            gpu.compute_pass_dispatch_workgroups_indirect(pass, buffer, offset)
            gpu.compute_pass_end(pass)
            command_buffer := gpu.command_encoder_finish(encoder)
            errors := cts_errors() - before
            if command_buffer != {} {
                gpu.command_buffer_release(command_buffer)
            }
            gpu.command_encoder_release(encoder)
            should_fail := state != 0 || offset % 4 != 0 || offset + 12 > 24
            cts_expect_outcome(t, errors, should_fail, "indirect dispatch state row")
            if state == 0 {
                gpu.buffer_release(buffer)
            }
        }
    }
}

@(test)
cts_compute_pass_indirect_device_mismatch :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    other := cts_make_device(f.adapter)
    testing.expect(t, other != nil, "failed to create the second device")
    defer gpu.device_release(other)
    pipeline := cts_make_compute_pipeline(f.device)
    testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
    defer gpu.compute_pipeline_release(pipeline)

    for mismatched in 0 ..< 2 {
        device := mismatched != 0 ? other : f.device
        buffer := gpu.device_create_buffer(device, {size = 16, usage = {.Indirect}})
        errors := cts_compute_run(t, f, pipeline, {}, buffer, true)
        cts_expect_outcome(t, errors ? 1 : 0, mismatched != 0,
            "indirect dispatch device mismatch")
        gpu.buffer_release(buffer)
    }
}

@(test)
cts_compute_pass_indirect_usage :: proc(t: ^testing.T) {
    f := cts_make_fixture()
    defer cts_destroy_fixture(f)
    pipeline := cts_make_compute_pipeline(f.device)
    testing.expect(t, pipeline != {}, "failed to create the compute pipeline")
    defer gpu.compute_pipeline_release(pipeline)

    Row :: struct {
        usage:    gpu.Buffer_Usages,
        accepted: bool,
    }
    rows := [6]Row{
        {{.Indirect}, true},
        {{.Indirect, .Copy_Dst}, true},
        {{.Copy_Dst}, false},
        {{.Vertex}, false},
        {{.Uniform}, false},
        {{.Storage}, false},
    }
    for row in rows {
        buffer := gpu.device_create_buffer(f.device, {size = 16, usage = row.usage})
        errors := cts_compute_run(t, f, pipeline, {}, buffer, true)
        cts_expect_outcome(t, errors ? 1 : 0, !row.accepted, "indirect dispatch usage row")
        gpu.buffer_release(buffer)
    }
}
