package gpu

// Core
import "core:reflect"
import "core:slice"

// Guaranteed to be no bigger than max(i32) which is the maximum size of an
// allocation, except on 16-bit platforms which we certainly don’t fit in.
LIMIT_U32_MAX :: u32(max(i32))

// Guaranteed to be no bigger than max(i32) which is the maximum size of an
// allocation, except on 16-bit platforms which we certainly don’t fit in.
LIMIT_U64_MAX :: u64(max(i32))

// Represents the sets of limits an adapter/device supports.
//
// We provide three different defaults.
//
// - `DEFAULT_DOWNLEVEL_LIMITS`. This is a set of limits that is guaranteed to
//   work on almost all backends, including the "downlevel" OpenGL backend, but
//   excluding WebGL2. For most applications we recommend using these limits,
//   assuming they are high enough for your application, and you do not intend
//   to support WebGL.
// - `DEFAULT_DOWNLEVEL_WEBGL2_LIMITS` This is a set of limits that is lower
//   even than the `DEFAULT_DOWNLEVEL_LIMITS`, configured to be low enough to
//   support running in the browser using WebGL2.
// - `DEFAULT_LIMITS`. This is the set of limits that is guaranteed to work on
//   all modern backends and is guaranteed to be supported by WebGPU.
//   Applications needing more modern features can use this as a reasonable set
//   of limits if they are targeting only desktop and modern mobile devices.
//
// We recommend starting with the most restrictive limits you can and manually
// increasing the limits you need boosted. This will let you stay running on all
// hardware that supports the limits you need.
//
// Limits "better" than the default must be supported by the adapter and
// requested when requesting a device. If limits "better" than the adapter
// supports are requested, requesting a device will panic. Once a device is
// requested, you may only use resources up to the limits requested _even_ if
// the adapter supports "better" limits.
//
// Requesting limits that are "better" than you need may cause performance to
// decrease because the implementation needs to support more than is needed. You
// should ideally only request exactly what you need.
//
// Corresponds to [WebGPU `GPUSupportedLimits`](
// https://gpuweb.github.io/gpuweb/#gpusupportedlimits).
Limits :: struct {
    // WebGPU

    // Maximum allowed value for the `size.width` of a texture created with
    // `Texture_Dimension.D1`. Defaults to `8192`. Higher is "better".
    max_texture_dimension_1d:                            u32,
    // Maximum allowed value for the `size.width` and `size.height` of a texture
    // created with `Texture_Dimension.D2`. Defaults to `8192`. Higher is "better".
    max_texture_dimension_2d:                            u32,
    // Maximum allowed value for the `size.width`, `size.height`, and
    // `size.depth_or_array_layers` of a texture created with
    // `Texture_Dimension.D3`. Defaults to `2048`. Higher is "better".
    max_texture_dimension_3d:                            u32,
    // Maximum allowed value for the `size.depth_or_array_layers` of a texture
    // created with `Texture_Dimension.D2`. Defaults to `256`. Higher is "better".
    max_texture_array_layers:                            u32,
    // Amount of bind groups that can be attached to a pipeline at the same
    // time. Defaults to `4`. Higher is "better".
    max_bind_groups:                                     u32,
    // The maximum number of bind group and vertex buffer slots used
    // simultaneously, counting any empty slots below the highest index.
    // Defaults to `24`. Higher is "better".
    max_bind_groups_plus_vertex_buffers:                 u32,
    // Maximum binding index allowed in `device_create_bind_group_layout`.
    // Defaults to `1000`. Higher is "better".
    max_bindings_per_bind_group:                         u32,
    // Amount of uniform buffer bindings that can be dynamic in a single
    // pipeline. Defaults to `8`. Higher is "better".
    max_dynamic_uniform_buffers_per_pipeline_layout:     u32 `ord:"greater"`,
    // Amount of storage buffer bindings that can be dynamic in a single
    // pipeline. Defaults to `4`. Higher is "better".
    max_dynamic_storage_buffers_per_pipeline_layout:     u32 `ord:"greater"`,
    // Amount of sampled textures visible in a single shader stage. Defaults to
    // `16`. Higher is "better".
    max_sampled_textures_per_shader_stage:               u32,
    // Amount of samplers visible in a single shader stage. Defaults to `16`.
    // Higher is "better".
    max_samplers_per_shader_stage:                       u32,
    // Amount of storage buffers visible in a single shader stage. Defaults to `8`.
    // Higher is "better".
    max_storage_buffers_per_shader_stage:                u32,
    // Amount of storage textures visible in a single shader stage. Defaults to `4`.
    // Higher is "better".
    max_storage_textures_per_shader_stage:               u32,
    // Amount of uniform buffers visible in a single shader stage. Defaults to `12`.
    // Higher is "better".
    max_uniform_buffers_per_shader_stage:                u32,
    // Maximum size in bytes of a binding to a uniform buffer. Defaults to `64`
    // KiB. Higher is "better".
    max_uniform_buffer_binding_size:                     u64,
    // Maximum size in bytes of a binding to a storage buffer. Defaults to `128`
    // MiB. Higher is "better".
    max_storage_buffer_binding_size:                     u64,
    // Required `Buffer_Binding_Type.Uniform` alignment for
    // `Buffer_Binding.offset` when creating a `Bind_Group`, or for
    // `set_bind_group` `dynamic_offsets`. Defaults to `256`. Lower is "better".
    min_uniform_buffer_offset_alignment:                 u32,
    // Required `Buffer_Binding_Type.Storage` alignment for
    // `Buffer_Binding.offset` when creating a `Bind_Group`, or for
    // `set_bind_group` `dynamic_offsets`. Defaults to `256`. Lower is "better".
    min_storage_buffer_offset_alignment:                 u32,
    // Maximum length of `Vertex_State.buffers` when creating a `Render_Pipeline`.
    // Defaults to `8`. Higher is "better".
    max_vertex_buffers:                                  u32,
    // A limit above which buffer allocations are guaranteed to fail. Defaults
    // to `256` MiB. Higher is "better".
    //
    // Buffer allocations below the maximum buffer size may not succeed
    // depending on available memory, fragmentation and other factors.
    max_buffer_size:                                     u64,
    // Maximum length of `Vertex_Buffer_Layout.attributes`, summed over all
    // `Vertex_State.buffers`, when creating a `Render_Pipeline`. Defaults to
    // `16`. Higher is "better".
    max_vertex_attributes:                               u32,
    // Maximum value for `Vertex_Buffer_Layout.array_stride` when creating a
    // `Render_Pipeline`. Defaults to `2048`. Higher is "better".
    max_vertex_buffer_array_stride:                      u32,
    // Maximum value for the number of input or output variables for inter-stage
    // communication (like vertex outputs or fragment inputs)  when creating a
    // `Render_Pipeline`. Defaults to `16`. Higher is "better".
    max_inter_stage_shader_variables:                    u32,
    // The maximum allowed number of color attachments.
    max_color_attachments:                               u32,
    // The maximum number of bytes necessary to hold one sample (pixel or
    // subpixel) of render pipeline output data, across all color attachments as
    // described by `Texture_Format.target_pixel_byte_cost` and
    // `Texture_Format.target_component_alignment`. Defaults to `32`. Higher is
    // "better".
    //
    // ⚠️ `RGBA8_Unorm`/`RGBA8_Snorm`/`BGRA8_Unorm`/`BGRA8_Snorm` are
    // deceptively `8` bytes per sample. ⚠️
    max_color_attachment_bytes_per_sample:               u32,
    // Maximum number of bytes used for workgroup memory in a compute entry
    // point. Defaults to `16384`. Higher is "better".
    max_compute_workgroup_storage_size:                  u32,
    // Maximum value of the product of the `workgroup_size` dimensions for a
    // compute entry-point. Defaults to `256`. Higher is "better".
    max_compute_invocations_per_workgroup:               u32,
    // The maximum value of the `workgroup_size` X dimension for a compute stage
    // `ShaderModule` entry-point. Defaults to `256`. Higher is "better".
    max_compute_workgroup_size_x:                        u32,
    // The maximum value of the `workgroup_size` Y dimension for a compute stage
    // `ShaderModule` entry-point. Defaults to `256`. Higher is "better".
    max_compute_workgroup_size_y:                        u32,
    // The maximum value of the `workgroup_size` Z dimension for a compute stage
    // `ShaderModule` entry-point. Defaults to `64`. Higher is "better".
    max_compute_workgroup_size_z:                        u32,
    // The maximum value for each dimension of a
    // `compute_pass_dispatch_workgroups(x, y, z)` operation. Defaults to
    // `65535`. Higher is "better".
    max_compute_workgroups_per_dimension:                u32,
    // Amount of storage available for immediates in bytes. Defaults to `0`.
    // Higher is "better". Requesting more than 0 during device creation
    // requires `Features.Immediates` to be enabled.
    //
    // Expect the size to be:
    //
    // - Vulkan: 128-256 bytes
    // - DX12: 128 bytes
    // - Metal: 4096 bytes
    // - OpenGL doesn't natively support immediates, and are emulated with
    //   uniforms, so this number is less useful but likely 256.
    max_immediate_size:                                  u32,

    // Native

    // Maximum number of live non-sampler bindings.
    //
    // ⚠️ The default value is **1_000_000**, On systems with integrated GPUs
    // (iGPUs)—particularly on Windows using the D3D12 backend—this can lead to
    // significant system RAM consumption since iGPUs share system memory
    // directly with the CPU. ⚠️
    //
    // This limit only affects the d3d12 backend. Using a large number will
    // allow the device to create many bind groups at the cost of a large
    // up-front allocation at device creation.
    max_non_sampler_bindings:                            u32,
    // Amount of individual resources within binding arrays that can be accessed
    // in a single shader stage. Applies to all types of bindings except
    // samplers.
    //
    // This "defaults" to `0`. However if binding arrays are supported, all
    // devices can support `500,000`. Higher is "better".
    max_binding_array_elements_per_shader_stage:         u32,
    // Amount of individual samplers within binding arrays that can be accessed
    // in a single shader stage.
    //
    // This "defaults" to `0`. However if binding arrays are supported, all
    // devices can support `1,000`. Higher is "better".
    max_binding_array_sampler_elements_per_shader_stage: u32,
    // The maximum number of views that can be used in multiview rendering
    max_multiview_view_count:                            u32,
}

DEFAULT_LIMITS :: Limits {
    // WebGPU
    max_texture_dimension_1d                            = 8192,
    max_texture_dimension_2d                            = 8192,
    max_texture_dimension_3d                            = 2048,
    max_texture_array_layers                            = 256,
    max_bind_groups                                     = 4,
    max_bind_groups_plus_vertex_buffers                 = 24,
    max_bindings_per_bind_group                         = 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout     = 8,
    max_dynamic_storage_buffers_per_pipeline_layout     = 4,
    max_sampled_textures_per_shader_stage               = 16,
    max_samplers_per_shader_stage                       = 16,
    max_storage_buffers_per_shader_stage                = 8,
    max_storage_textures_per_shader_stage               = 4,
    max_uniform_buffers_per_shader_stage                = 12,
    max_uniform_buffer_binding_size                     = 64 << 10, // (64 KiB)
    max_storage_buffer_binding_size                     = 128 << 20, // (128 MiB)
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 2048,
    max_inter_stage_shader_variables                    = 16,
    max_color_attachments                               = 8,
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 16384,
    max_compute_invocations_per_workgroup               = 256,
    max_compute_workgroup_size_x                        = 256,
    max_compute_workgroup_size_y                        = 256,
    max_compute_workgroup_size_z                        = 64,
    max_compute_workgroups_per_dimension                = 65535,
    max_immediate_size                                  = 0,

    // Native
    max_non_sampler_bindings                            = 1_000_000,
    max_binding_array_elements_per_shader_stage         = 0,
    max_binding_array_sampler_elements_per_shader_stage = 0,
    max_multiview_view_count                            = 0,
}

// These default limits are guaranteed to be compatible with GLES-3.1.
//
// Those limits are as follows (different from `DEFAULT_LIMITS` are marked with *):
DEFAULT_DOWNLEVEL_LIMITS :: Limits {
    // WebGPU
    max_texture_dimension_1d                            = 2048, // *
    max_texture_dimension_2d                            = 2048, // *
    max_texture_dimension_3d                            = 256, // *
    max_texture_array_layers                            = 256,
    max_bind_groups                                     = 4,
    max_bind_groups_plus_vertex_buffers                 = 15,
    max_bindings_per_bind_group                         = 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout     = 8,
    max_dynamic_storage_buffers_per_pipeline_layout     = 4,
    max_sampled_textures_per_shader_stage               = 16,
    max_samplers_per_shader_stage                       = 16,
    max_storage_buffers_per_shader_stage                = 4, // *
    max_storage_textures_per_shader_stage               = 4,
    max_uniform_buffers_per_shader_stage                = 12,
    max_uniform_buffer_binding_size                     = 16 << 10, // * (16 KiB)
    max_storage_buffer_binding_size                     = 128 << 20, // (128 MiB)
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 2048,
    max_inter_stage_shader_variables                    = 16,
    max_color_attachments                               = 4,
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 16352, // *
    max_compute_invocations_per_workgroup               = 256,
    max_compute_workgroup_size_x                        = 256,
    max_compute_workgroup_size_y                        = 256,
    max_compute_workgroup_size_z                        = 64,
    max_compute_workgroups_per_dimension                = 65535,
    max_immediate_size                                  = 0,

    // Native
    max_non_sampler_bindings                            = 1_000_000,
    max_binding_array_elements_per_shader_stage         = 0,
    max_binding_array_sampler_elements_per_shader_stage = 0,
    max_multiview_view_count                            = 0,
}

// These default limits are guaranteed to be compatible with GLES-3.0 and WebGL2
//
// Those limits are as follows (different from `DEFAULT_DOWNLEVEL_LIMITS` are
// marked with +,
DEFAULT_DOWNLEVEL_WEBGL2_LIMITS :: Limits {
    // WebGPU
    max_texture_dimension_1d                            = 2048, // *
    max_texture_dimension_2d                            = 2048, // *
    max_texture_dimension_3d                            = 256, // *
    max_texture_array_layers                            = 256,
    max_bind_groups                                     = 4,
    max_bind_groups_plus_vertex_buffers                 = 15,
    max_bindings_per_bind_group                         = 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout     = 8,
    max_dynamic_storage_buffers_per_pipeline_layout     = 0, // +
    max_sampled_textures_per_shader_stage               = 16,
    max_samplers_per_shader_stage                       = 16,
    max_storage_buffers_per_shader_stage                = 0, // * +
    max_storage_textures_per_shader_stage               = 0, // +
    max_uniform_buffers_per_shader_stage                = 11, // +
    max_uniform_buffer_binding_size                     = 16 << 10, // * (16 KiB)
    max_storage_buffer_binding_size                     = 0, // * +
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 255, // +
    max_inter_stage_shader_variables                    = 15,
    max_color_attachments                               = 4,
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 0, // +
    max_compute_invocations_per_workgroup               = 0, // +
    max_compute_workgroup_size_x                        = 0, // +
    max_compute_workgroup_size_y                        = 0, // +
    max_compute_workgroup_size_z                        = 0, // +
    max_compute_workgroups_per_dimension                = 0, // +
    max_immediate_size                                  = 0,

    // Native
    max_non_sampler_bindings                            = 1_000_000,
    max_binding_array_elements_per_shader_stage         = 0,
    max_binding_array_sampler_elements_per_shader_stage = 0,
    max_multiview_view_count                            = 0,
}

// Sets each limit to `max(i32)` (or 1, in the case of lower-is-better limits).
//
// These values do not reflect the capabilities of any actual device. They are
// used by the noop backend, and by the test that makes sure `limits_check` is
// exhaustive.
UNLIMITED_LIMITS :: Limits {
    // WebGPU
    max_texture_dimension_1d                            = LIMIT_U32_MAX,
    max_texture_dimension_2d                            = LIMIT_U32_MAX,
    max_texture_dimension_3d                            = LIMIT_U32_MAX,
    max_texture_array_layers                            = LIMIT_U32_MAX,
    max_bind_groups                                     = LIMIT_U32_MAX,
    max_bind_groups_plus_vertex_buffers                 = LIMIT_U32_MAX,
    max_bindings_per_bind_group                         = LIMIT_U32_MAX,
    max_dynamic_uniform_buffers_per_pipeline_layout     = LIMIT_U32_MAX,
    max_dynamic_storage_buffers_per_pipeline_layout     = LIMIT_U32_MAX,
    max_sampled_textures_per_shader_stage               = LIMIT_U32_MAX,
    max_samplers_per_shader_stage                       = LIMIT_U32_MAX,
    max_storage_buffers_per_shader_stage                = LIMIT_U32_MAX,
    max_storage_textures_per_shader_stage               = LIMIT_U32_MAX,
    max_uniform_buffers_per_shader_stage                = LIMIT_U32_MAX,
    max_uniform_buffer_binding_size                     = LIMIT_U64_MAX,
    max_storage_buffer_binding_size                     = LIMIT_U64_MAX,
    min_uniform_buffer_offset_alignment                 = 1,
    min_storage_buffer_offset_alignment                 = 1,
    max_vertex_buffers                                  = LIMIT_U32_MAX,
    max_buffer_size                                     = LIMIT_U64_MAX,
    max_vertex_attributes                               = LIMIT_U32_MAX,
    max_vertex_buffer_array_stride                      = LIMIT_U32_MAX,
    max_inter_stage_shader_variables                    = LIMIT_U32_MAX,
    max_color_attachments                               = LIMIT_U32_MAX,
    max_color_attachment_bytes_per_sample               = LIMIT_U32_MAX,
    max_compute_workgroup_storage_size                  = LIMIT_U32_MAX,
    max_compute_invocations_per_workgroup               = LIMIT_U32_MAX,
    max_compute_workgroup_size_x                        = LIMIT_U32_MAX,
    max_compute_workgroup_size_y                        = LIMIT_U32_MAX,
    max_compute_workgroup_size_z                        = LIMIT_U32_MAX,
    max_compute_workgroups_per_dimension                = LIMIT_U32_MAX,
    max_immediate_size                                  = LIMIT_U32_MAX,

    // Native
    max_non_sampler_bindings                            = LIMIT_U32_MAX,
    max_binding_array_elements_per_shader_stage         = LIMIT_U32_MAX,
    max_binding_array_sampler_elements_per_shader_stage = LIMIT_U32_MAX,
    max_multiview_view_count                            = LIMIT_U32_MAX,
}

// Compares every limit in `requested` against the limits in `allowed`.
//
// Returns `true` if every field in `requested` is within `allowed`.
limits_check :: proc(requested, allowed: Limits) -> bool {
    within := true

    fail_proc :: proc(name: string, self_value: u64, allowed_value: u64, user_data: rawptr) {
        within := cast(^bool)user_data
        within^ = false
    }

    limits_check_ex(requested, allowed, true, fail_proc, &within)
    return within
}

Limits_Fail_Proc :: #type proc(
    name: string,
    requested_value: u64,
    allowed_value: u64,
    user_data: rawptr,
)

@private
limits_field_ordering :: proc(tag: reflect.Struct_Tag) -> slice.Ordering {
    value := reflect.struct_tag_get(tag, "ord")
    if value == "greater" {
        return .Greater
    }
    return .Less
}

// Compares every limit in `requested` against the limits in `allowed`.
//
// For any field not within the allowed limit, calls `fail_proc` with the field
// name, requested's value, and allowed's value (both widened to u64).
//
// If `fatal` is true, returns after the first failure instead of checking
// every remaining field.
limits_check_ex :: proc(
    requested: Limits,
    allowed: Limits,
    fatal: bool,
    fail_proc: Limits_Fail_Proc,
    user_data: rawptr = nil,
) {
    requested := requested
    allowed   := allowed

    fields := reflect.struct_fields_zipped(Limits)

    for field in fields {
        requested_value := (^u64)(uintptr(&requested) + field.offset)^
        alowed_value    := (^u64)(uintptr(&allowed) + field.offset)^

        invalid: bool
        switch limits_field_ordering(field.tag) {
        case .Less:    invalid = requested_value < alowed_value
        case .Greater: invalid = requested_value > alowed_value
        case .Equal:
            unreachable()
        }

        if invalid {
            fail_proc(field.name, requested_value, alowed_value, user_data)
            if fatal {
                return
            }
        }
    }
}
