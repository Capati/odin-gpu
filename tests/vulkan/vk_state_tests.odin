#+build !js
package vulkan_tests

// Core
import "core:testing"

// Vendor
import vk "vendor:vulkan"

// Local
import gpu "../../gpu"

// Vulkan resource-state mapping tests: image layouts and stage/access masks.

@(private = "file")
test_queue_flags :: proc() -> vk.QueueFlags {
    return {.GRAPHICS, .COMPUTE}
}

@(test)
test_vk_texture_uses_mapping :: proc(t: ^testing.T) {
    queue_flags := test_queue_flags()
    shader_stages := vk.PipelineStageFlags{.VERTEX_SHADER, .FRAGMENT_SHADER, .COMPUTE_SHADER}

    layouts := [?]struct {
        uses:     gpu.Texture_Uses,
        expected: vk.ImageLayout,
    } {
        {gpu.TEXTURE_USES_UNINITIALIZED, .UNDEFINED},
        {{.Copy_Src}, .TRANSFER_SRC_OPTIMAL},
        {{.Copy_Dst}, .TRANSFER_DST_OPTIMAL},
        {gpu.TEXTURE_USES_RESOURCE, .SHADER_READ_ONLY_OPTIMAL},
        {gpu.TEXTURE_USES_COLOR_TARGET, .COLOR_ATTACHMENT_OPTIMAL},
        {gpu.TEXTURE_USES_COLOR_TARGET | gpu.TEXTURE_USES_RESOURCE, .COLOR_ATTACHMENT_OPTIMAL},
        {gpu.TEXTURE_USES_STORAGE_READ_ONLY, .GENERAL},
        {gpu.TEXTURE_USES_STORAGE_WRITE_ONLY, .GENERAL},
        {gpu.TEXTURE_USES_STORAGE_READ_WRITE, .GENERAL},
        {gpu.TEXTURE_USES_PRESENT, .PRESENT_SRC_KHR},
        {gpu.TEXTURE_USES_DEPTH_READ, .DEPTH_STENCIL_READ_ONLY_OPTIMAL},
        {gpu.TEXTURE_USES_DEPTH_WRITE, .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL},
        {gpu.TEXTURE_USES_STENCIL_WRITE, .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL},
        {
            gpu.TEXTURE_USES_DEPTH_WRITE | gpu.TEXTURE_USES_STENCIL_WRITE,
            .DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        },
        {gpu.TEXTURE_USES_COPY_DST | gpu.TEXTURE_USES_RESOURCE, .SHADER_READ_ONLY_OPTIMAL},
    }
    for row in layouts {
        actual := gpu.vk_conv_texture_uses_to_image_layout(row.uses)
        testing.expectf(t, actual == row.expected,
            "layout for %v: expected %v, got %v", row.uses, row.expected, actual)
    }

    access_rows := [?]struct {
        uses:     gpu.Texture_Uses,
        expected: vk.AccessFlags,
    } {
        {gpu.TEXTURE_USES_UNINITIALIZED, {}},
        {gpu.TEXTURE_USES_COPY_SRC, {.TRANSFER_READ}},
        {gpu.TEXTURE_USES_COPY_DST, {.TRANSFER_WRITE}},
        {gpu.TEXTURE_USES_RESOURCE, {.SHADER_READ}},
        {gpu.TEXTURE_USES_STORAGE_WRITE_ONLY, {.SHADER_WRITE}},
        {
            gpu.TEXTURE_USES_STORAGE_READ_WRITE,
            {.SHADER_READ, .SHADER_WRITE},
        },
        {
            gpu.TEXTURE_USES_COLOR_TARGET,
            {.COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE},
        },
        {
            gpu.TEXTURE_USES_DEPTH_READ,
            {.DEPTH_STENCIL_ATTACHMENT_READ, .DEPTH_STENCIL_ATTACHMENT_WRITE},
        },
        {gpu.TEXTURE_USES_PRESENT, {}},
    }
    for row in access_rows {
        actual := gpu.vk_access_for_texture_uses(row.uses)
        testing.expectf(t, actual == row.expected,
            "access for %v: expected %v, got %v", row.uses, row.expected, actual)
    }

    stage_rows := [?]struct {
        uses:     gpu.Texture_Uses,
        expected: vk.PipelineStageFlags,
    } {
        {{}, {.TOP_OF_PIPE}},
        {gpu.TEXTURE_USES_COPY_SRC, {.TRANSFER}},
        {gpu.TEXTURE_USES_RESOURCE, shader_stages},
        {gpu.TEXTURE_USES_COLOR_TARGET, {.COLOR_ATTACHMENT_OUTPUT}},
        {gpu.TEXTURE_USES_DEPTH_WRITE, {.EARLY_FRAGMENT_TESTS, .LATE_FRAGMENT_TESTS}},
        {
            gpu.TEXTURE_USES_COPY_DST | gpu.TEXTURE_USES_COLOR_TARGET,
            {.TRANSFER, .COLOR_ATTACHMENT_OUTPUT},
        },
    }
    for row in stage_rows {
        actual := gpu.vk_stage_for_texture_uses(row.uses, queue_flags)
        testing.expectf(t, actual == row.expected,
            "stage for %v: expected %v, got %v", row.uses, row.expected, actual)
    }
}

@(test)
test_vk_buffer_uses_mapping :: proc(t: ^testing.T) {
    queue_flags := test_queue_flags()
    shader_stages := vk.PipelineStageFlags{.VERTEX_SHADER, .FRAGMENT_SHADER, .COMPUTE_SHADER}

    access_rows := [?]struct {
        uses:     gpu.Buffer_Uses,
        expected: vk.AccessFlags,
    } {
        {gpu.BUFFER_USES_UNINITIALIZED, {}},
        {gpu.BUFFER_USES_MAP_READ, {.HOST_READ}},
        {gpu.BUFFER_USES_MAP_WRITE, {.HOST_WRITE}},
        {gpu.BUFFER_USES_COPY_SRC, {.TRANSFER_READ}},
        {gpu.BUFFER_USES_COPY_DST, {.TRANSFER_WRITE}},
        {gpu.BUFFER_USES_INDEX, {.INDEX_READ}},
        {gpu.BUFFER_USES_VERTEX, {.VERTEX_ATTRIBUTE_READ}},
        {gpu.BUFFER_USES_UNIFORM, {.UNIFORM_READ}},
        {gpu.BUFFER_USES_STORAGE_READ_ONLY, {.SHADER_READ}},
        {gpu.BUFFER_USES_STORAGE_READ_WRITE, {.SHADER_READ, .SHADER_WRITE}},
        {gpu.BUFFER_USES_INDIRECT, {.INDIRECT_COMMAND_READ}},
        {
            gpu.BUFFER_USES_COPY_SRC | gpu.BUFFER_USES_UNIFORM,
            {.TRANSFER_READ, .UNIFORM_READ},
        },
    }
    for row in access_rows {
        _, actual := gpu.vk_conv_buffer_uses_to_barrier(row.uses, queue_flags)
        testing.expectf(t, actual == row.expected,
            "access for %v: expected %v, got %v", row.uses, row.expected, actual)
    }

    stage_rows := [?]struct {
        uses:     gpu.Buffer_Uses,
        expected: vk.PipelineStageFlags,
    } {
        {gpu.BUFFER_USES_MAP_READ, {.HOST}},
        {gpu.BUFFER_USES_COPY_SRC, {.TRANSFER}},
        {gpu.BUFFER_USES_INDEX, {.VERTEX_INPUT}},
        {gpu.BUFFER_USES_VERTEX, {.VERTEX_INPUT}},
        {gpu.BUFFER_USES_UNIFORM, shader_stages},
        {gpu.BUFFER_USES_STORAGE_READ_ONLY, shader_stages},
        {gpu.BUFFER_USES_STORAGE_READ_WRITE, shader_stages},
        {gpu.BUFFER_USES_INDIRECT, {.DRAW_INDIRECT}},
        {
            gpu.BUFFER_USES_VERTEX | gpu.BUFFER_USES_UNIFORM,
            {.VERTEX_INPUT} | shader_stages,
        },
    }
    for row in stage_rows {
        actual, _ := gpu.vk_conv_buffer_uses_to_barrier(row.uses, queue_flags)
        testing.expectf(t, actual == row.expected,
            "stage for %v: expected %v, got %v", row.uses, row.expected, actual)
    }
}
