package gpu

// Core
import "core:reflect"
import "core:strings"
import sa "core:container/small_array"

// Represents the sets of limits an adapter/device supports.
Limits :: struct {
    // Maximum allowed value for the `size.width` of a texture created with
    // `Texture_Dimension.D1`. Defaults to 8192. Higher is "better".
    max_texture_dimension_1d: u32,
    // Maximum allowed value for the `size.width` and `size.height` of a texture
    // created with `Texture_Dimension.D2`. Defaults to 8192. Higher is "better".
    max_texture_dimension_2d: u32,
    // Maximum allowed value for the `size.width`, `size.height`, and
    // `size.depth_or_array_layers` of a texture created with
    // `Texture_Dimension.D3`. Defaults to 2048. Higher is "better".
    max_texture_dimension_3d: u32,
    // Maximum allowed value for the `size.depth_or_array_layers` of a texture
    // created with `Texture_Dimension.D2`. Defaults to 256. Higher is "better".
    max_texture_array_layers: u32,
    // Amount of bind groups that can be attached to a pipeline at the same
    // time. Defaults to 4. Higher is "better".
    max_bind_groups: u32,
    // TODO
    max_bind_groups_plus_vertex_buffers: u32,
    // Maximum binding index allowed in `device_create_bind_group_layout`.
    // Defaults to 1000. Higher is "better".
    max_bindings_per_bind_group: u32,
    // Amount of uniform buffer bindings that can be dynamic in a single
    // pipeline. Defaults to 8. Higher is "better".
    max_dynamic_uniform_buffers_per_pipeline_layout: u32,
    // Amount of storage buffer bindings that can be dynamic in a single
    // pipeline. Defaults to 4. Higher is "better".
    max_dynamic_storage_buffers_per_pipeline_layout: u32,
    // Amount of sampled textures visible in a single shader stage. Defaults to 16.
    // Higher is "better".
    max_sampled_textures_per_shader_stage: u32,
    // Amount of samplers visible in a single shader stage. Defaults to 16.
    // Higher is "better".
    max_samplers_per_shader_stage: u32,
    // Amount of storage buffers visible in a single shader stage. Defaults to 8.
    // Higher is "better".
    max_storage_buffers_per_shader_stage: u32,
    // Amount of storage textures visible in a single shader stage. Defaults to 4.
    // Higher is "better".
    max_storage_textures_per_shader_stage: u32,
    // Amount of uniform buffers visible in a single shader stage. Defaults to 12.
    // Higher is "better".
    max_uniform_buffers_per_shader_stage: u32,
    // Maximum size in bytes of a binding to a uniform buffer. Defaults to 64
    // KiB. Higher is "better".
    max_uniform_buffer_binding_size: u64,
    // Maximum size in bytes of a binding to a storage buffer. Defaults to 128
    // MiB. Higher is "better".
    max_storage_buffer_binding_size: u64,
    // Required `BufferBindingType.Uniform` alignment for
    // `Buffer_Binding.offset` when creating a `Bind_Group`, or for
    // `set_bind_group` `dynamic_offsets`. Defaults to 256. Lower is "better".
    min_uniform_buffer_offset_alignment: u32,
    // Required `BufferBindingType.Storage` alignment for
    // `Buffer_Binding.offset` when creating a `Bind_Group`, or for
    // `set_bind_group` `dynamic_offsets`. Defaults to 256. Lower is "better".
    min_storage_buffer_offset_alignment: u32,
    // Maximum length of `Vertex_State.buffers` when creating a
    // `Render_Pipeline`. Defaults to 8. Higher is "better".
    max_vertex_buffers: u32,
    // A limit above which buffer allocations are guaranteed to fail. Defaults
    // to 256 MiB. Higher is "better".
    //
    // Buffer allocations below the maximum buffer size may not succeed
    // depending on available memory, fragmentation and other factors.
    max_buffer_size: u64,
    // Maximum length of `Vertex_Buffer_Layout.attributes`, summed over all
    // `Vertex_State.buffers`, when creating a `Render_Pipeline`. Defaults to 16.
    // Higher is "better".
    max_vertex_attributes: u32,
    // Maximum value for `Vertex_Buffer_Layout.array_stride` when creating a
    // `Render_Pipeline`. Defaults to 2048. Higher is "better".
    max_vertex_buffer_array_stride: u32,
    // Maximum allowed number of components (scalars) of input or output
    // locations for inter-stage communication (vertex outputs to fragment
    // inputs). Defaults to 60. Higher is "better".
    max_inter_stage_shader_variables: u32,
    // The maximum allowed number of color attachments.
    max_color_attachments: u32,
    // The maximum number of bytes necessary to hold one sample (pixel or
    // subpixel) of render pipeline output data, across all color attachments as
    // described by `Texture_Format.target_pixel_byte_cost` and
    // `Texture_Format.target_component_alignment`. Defaults to 32. Higher is
    // "better".
    //
    // ⚠️ `Rgba_8Unorm`/`Rgba8_Snorm`/`Bgra8_Unorm`/`Bgra8_Snorm` are
    // deceptively 8 bytes per sample. ⚠️
    max_color_attachment_bytes_per_sample: u32,
    // Maximum number of bytes used for workgroup memory in a compute entry
    // point. Defaults to 16384. Higher is "better".
    max_compute_workgroup_storage_size: u32,
    // Maximum value of the product of the `workgroup_size` dimensions for a
    // compute entry-point. Defaults to 256. Higher is "better".
    max_compute_invocations_per_workgroup: u32,
    // The maximum value of the `workgroup_size` X dimension for a compute stage
    // `Shader_Module` entry-point. Defaults to 256. Higher is "better".
    max_compute_workgroup_size_x: u32,
    // The maximum value of the `workgroup_size` Y dimension for a compute stage
    // `Shader_Module` entry-point. Defaults to 256. Higher is "better".
    max_compute_workgroup_size_y: u32,
    // The maximum value of the `workgroup_size` Z dimension for a compute stage
    // `Shader_Module` entry-point. Defaults to 64. Higher is "better".
    max_compute_workgroup_size_z: u32,
    // The maximum value for each dimension of a `compute_pass_dispatch(x, y,
    // z)` operation. Defaults to 65535. Higher is "better".
    max_compute_workgroups_per_dimension: u32,

    // Minimal number of invocations in a subgroup. Higher is "better".
    min_subgroup_size: u32,
    // Maximal number of invocations in a subgroup. Lower is "better".
    max_subgroup_size: u32,
    // Amount of storage available for push constants in bytes. Defaults to 0.
    // Higher is "better". Requesting more than 0 during device creation
    // requires `Features.push_constants` to be enabled.
    //
    // Expect the size to be:
    // - Vulkan: 128-256 bytes
    // - DX12: 256 bytes
    // - Metal: 4096 bytes
    // - OpenGL doesn't natively support push constants, and are emulated with
    //   uniforms, so this number is less useful but likely 256.
    max_push_constant_size: u32,
    // Maximum number of live non-sampler bindings.
    //
    // This limit only affects the d3d12 backend. Using a large number will
    // allow the device to create many bind groups at the cost of a large
    // up-front allocation at device creation.
    max_non_sampler_bindings: u32,

    // The maximum total value of x*y*z for a given `draw_mesh_tasks` command
    max_task_workgroup_total_count: u32,
    // The maximum value for each dimension of a `render_pass_draw_mesh_tasks(x,
    // y, z)` operation. Defaults to 65535. Higher is "better".
    max_task_workgroups_per_dimension: u32,
    // The maximum number of layers that can be output from a mesh shader
    max_mesh_output_layers: u32,
    // The maximum number of views that can be used by a mesh shader
    max_mesh_multiview_count: u32,

    // The maximum number of primitive (ex: triangles, aabbs) a BLAS is allowed
    // to have. Requesting more than 0 during device creation only makes sense
    // if `Features.experimental_ray_query` is enabled.
    max_blas_primitive_count: u32,
    // The maximum number of geometry descriptors a BLAS is allowed to have.
    // Requesting more than 0 during device creation only makes sense if
    // `Features.experimental_ray_query` is enabled.
    max_blas_geometry_count: u32,
    // The maximum number of instances a TLAS is allowed to have. Requesting
    // more than 0 during device creation only makes sense if
    // `Features.experimental_ray_query` is enabled.
    max_tlas_instance_count: u32,
    // The maximum number of acceleration structures allowed to be used in a
    // shader stage. Requesting more than 0 during device creation only makes
    // sense if `Features.experimental_ray_query` is enabled.
    max_acceleration_structures_per_shader_stage: u32,
}

// Total number of available limits.
LIMITS_TOTAL :: 43

// These default limits are guaranteed to to work on all modern backends and
// guaranteed to be supported by WebGPU.
LIMITS_DEFAULT :: Limits {
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
    // max_binding_array_elements_per_shader_stage         = 0,
    // max_binding_array_sampler_elements_per_shader_stage = 0,
    max_uniform_buffer_binding_size                     = 64 << 10, // (64 KiB)
    max_storage_buffer_binding_size                     = 128 << 20, // (128 MiB)
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 2048,
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_inter_stage_shader_variables                   = 16,
    max_color_attachments                               = 8,
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 16384,
    max_compute_invocations_per_workgroup               = 256,
    max_compute_workgroup_size_x                        = 256,
    max_compute_workgroup_size_y                        = 256,
    max_compute_workgroup_size_z                        = 64,
    max_compute_workgroups_per_dimension                = 65535,
    min_subgroup_size                                   = 0,
    max_subgroup_size                                   = 0,
    max_push_constant_size                              = 0,
    max_non_sampler_bindings                            = 1_000_000,
    max_task_workgroup_total_count                      = 0,
    max_task_workgroups_per_dimension                   = 0,
    max_mesh_multiview_count                            = 0,
    max_mesh_output_layers                              = 0,
    max_blas_primitive_count                            = 0,
    max_blas_geometry_count                             = 0,
    max_tlas_instance_count                             = 0,
    max_acceleration_structures_per_shader_stage        = 0,
}

// These default limits are guaranteed to be compatible with GLES-3.1, and D3D11.
//
// Those limits are as follows (different from default are marked with *):
LIMITS_DOWNLEVEL :: Limits {
    max_texture_dimension_1d                            = 2048, // *
    max_texture_dimension_2d                            = 2048, // *
    max_texture_dimension_3d                            = 256, // *
    max_texture_array_layers                            = 256,
    max_bind_groups                                     = 4,
    max_bind_groups_plus_vertex_buffers                 = 24,
    max_bindings_per_bind_group                         = 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout     = 8,
    max_dynamic_storage_buffers_per_pipeline_layout     = 4,
    max_sampled_textures_per_shader_stage               = 16,
    max_samplers_per_shader_stage                       = 16,
    max_storage_buffers_per_shader_stage                = 4, // *
    max_storage_textures_per_shader_stage               = 4,
    max_uniform_buffers_per_shader_stage                = 12,
    // max_binding_array_elements_per_shader_stage         = 0,
    // max_binding_array_sampler_elements_per_shader_stage = 0,
    max_uniform_buffer_binding_size                     = 16 << 10, // * (16 KiB)
    max_storage_buffer_binding_size                     = 128 << 20, // (128 MiB)
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 2048,
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_inter_stage_shader_variables                   = 16,
    max_color_attachments                               = 4, // *
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 16352, // *
    max_compute_invocations_per_workgroup               = 256,
    max_compute_workgroup_size_x                        = 256,
    max_compute_workgroup_size_y                        = 256,
    max_compute_workgroup_size_z                        = 64,
    max_compute_workgroups_per_dimension                = 65535,
    min_subgroup_size                                   = 0,
    max_subgroup_size                                   = 0,
    max_push_constant_size                              = 0,
    max_non_sampler_bindings                            = 1_000_000,
    max_task_workgroup_total_count                      = 0,
    max_task_workgroups_per_dimension                   = 0,
    max_mesh_multiview_count                            = 0,
    max_mesh_output_layers                              = 0,
    max_blas_primitive_count                            = 0,
    max_blas_geometry_count                             = 0,
    max_tlas_instance_count                             = 0,
    max_acceleration_structures_per_shader_stage        = 0,
}

// These default limits are guaranteed to be compatible with GLES-3.0, and
// D3D11, and WebGL2
//
// Those limits are as follows (different from `LIMITS_DOWNLEVEL` are marked
// with +, *'s from `LIMITS_DOWNLEVEL` shown as well.):
LIMITS_DOWNLEVEL_WEBGL2 :: Limits {
    max_texture_dimension_1d                            = 2048, // *
    max_texture_dimension_2d                            = 2048, // *
    max_texture_dimension_3d                            = 256, // *
    max_texture_array_layers                            = 256,
    max_bind_groups                                     = 4,
    max_bind_groups_plus_vertex_buffers                 = 24,
    max_bindings_per_bind_group                         = 1000,
    max_dynamic_uniform_buffers_per_pipeline_layout     = 8,
    max_dynamic_storage_buffers_per_pipeline_layout     = 0, // +
    max_sampled_textures_per_shader_stage               = 16,
    max_samplers_per_shader_stage                       = 16,
    max_storage_buffers_per_shader_stage                = 0, // * +
    max_storage_textures_per_shader_stage               = 0, // +
    max_uniform_buffers_per_shader_stage                = 11, // +
    // max_binding_array_elements_per_shader_stage         = 0,
    // max_binding_array_sampler_elements_per_shader_stage = 0,
    max_uniform_buffer_binding_size                     = 16 << 10, // * (16 KiB)
    max_storage_buffer_binding_size                     = 0, // * +
    max_vertex_buffers                                  = 8,
    max_buffer_size                                     = 256 << 20, // (256 MiB)
    max_vertex_attributes                               = 16,
    max_vertex_buffer_array_stride                      = 255, // +
    min_uniform_buffer_offset_alignment                 = 256,
    min_storage_buffer_offset_alignment                 = 256,
    max_inter_stage_shader_variables                   = 16, // *
    max_color_attachments                               = 4, // *
    max_color_attachment_bytes_per_sample               = 32,
    max_compute_workgroup_storage_size                  = 0, // +
    max_compute_invocations_per_workgroup               = 0, // +
    max_compute_workgroup_size_x                        = 0, // +
    max_compute_workgroup_size_y                        = 0, // +
    max_compute_workgroup_size_z                        = 0, // +
    max_compute_workgroups_per_dimension                = 0, // +
    min_subgroup_size                                   = 0,
    max_subgroup_size                                   = 0,
    max_push_constant_size                              = 0,
    max_non_sampler_bindings                            = 1_000_000,
    max_task_workgroup_total_count                      = 0,
    max_task_workgroups_per_dimension                   = 0,
    max_mesh_multiview_count                            = 0,
    max_mesh_output_layers                              = 0,
    max_blas_primitive_count                            = 0,
    max_blas_geometry_count                             = 0,
    max_tlas_instance_count                             = 0,
    max_acceleration_structures_per_shader_stage        = 0,
}

// Use the minimum limits.
LIMITS_MINIMUM_DEFAULT :: LIMITS_DOWNLEVEL

// Modify the current limits to use the resolution limits of the other.
//
// This is useful because the swapchain might need to be larger than any other
// image in the application.
//
// If your application only needs 512x512, you might be running on a 4k display and
// need extremely high resolution limits.
limits_using_resolution :: proc(self, other: Limits) -> Limits {
    self := self
    self.max_texture_dimension_1d = other.max_texture_dimension_1d
    self.max_texture_dimension_2d = other.max_texture_dimension_2d
    self.max_texture_dimension_3d = other.max_texture_dimension_3d
    return self
}

// Modify the current limits to use the buffer alignment limits of the adapter.
//
// This is useful for when you'd like to dynamically use the "best" supported
// buffer alignments.
limits_using_alignment :: proc(self, other: Limits) -> Limits {
    self := self
    self.min_uniform_buffer_offset_alignment = other.min_uniform_buffer_offset_alignment
    self.min_storage_buffer_offset_alignment = other.min_storage_buffer_offset_alignment
    return self
}

// The minimum guaranteed limits for acceleration structures.
limits_using_minimum_supported_acceleration_structure_values :: proc(self: Limits) -> Limits {
    self := self
    self.max_blas_geometry_count = (1 << 24) - 1 // 2^24 - 1: Vulkan's minimum
    self.max_tlas_instance_count = (1 << 24) - 1 // 2^24 - 1: Vulkan's minimum
    self.max_blas_primitive_count = 1 << 28      // 2^28: Metal's minimum
    self.max_acceleration_structures_per_shader_stage = 16 // Vulkan's minimum
    return self
}

// Modify the current limits to use the acceleration structure limits of `other`
// (`other` could be the limits of the adapter).
limits_using_acceleration_structure_values :: proc(self, other: Limits) -> Limits {
    self := self
    self.max_blas_geometry_count = other.max_blas_geometry_count
    self.max_tlas_instance_count = other.max_tlas_instance_count
    self.max_blas_primitive_count = other.max_blas_primitive_count
    self.max_acceleration_structures_per_shader_stage =
        other.max_acceleration_structures_per_shader_stage
    return self
}

// The recommended minimum limits for mesh shaders if you enable
// `Features.Experimental_Mesh_Shader`.
//
// These are chosen somewhat arbitrarily. They are small enough that they should
// cover all physical devices, but not necessarily all use cases.
limits_using_recommended_minimum_mesh_shader_values :: proc(self: Limits) -> Limits {
    self := self
    // Literally just made this up as 256^2 or 2^16.
    // My GPU supports 2^22, and compute shaders don't have this kind of limit.
    // This very likely is never a real limiter
    self.max_task_workgroup_total_count = 65536
    self.max_task_workgroups_per_dimension = 256
    // llvmpipe reports 0 multiview count, which just means no multiview is allowed
    self.max_mesh_multiview_count = 0
    // llvmpipe once again requires this to be 8. An RTX 3060 supports well over 1024.
    self.max_mesh_output_layers = 8
    return self
}

// A single limit violation.
Limits_Violation_Value :: struct {
    name:    string,
    current: u64,
    allowed: u64,
}

// Total number of possible limits violations, is the total of available limits + 1.
LIMITS_MAX_VIOLATIONS :: LIMITS_TOTAL + 1

// List of possible limits violations.
Limits_Violation_List :: sa.Small_Array(LIMITS_MAX_VIOLATIONS, Limits_Violation_Value)

// Return value for `limits_check`.
Limits_Violations :: struct {
    values: Limits_Violation_List,
    ok:     bool,
}

// Compares two `Limits` structures and identifies any violations where the
// `self` limits exceed or fall short of the `allowed` limits.
//
// Inputs:
//
// - `self: Limits`: The limits to be checked.
// - `allowed: Limits`: The reference limits that `self` is checked against.
//
// Returns:
//
// - `violations: Limits_Violations`: A structure containing information about
//   any limit violations.
@(require_results)
limits_check :: proc (
    self: Limits,
    allowed: Limits,
) -> (
    violations: Limits_Violations,
    ok: bool,
) {
    self := self
    allowed := allowed

    add_violation :: proc(
        violations: ^Limits_Violation_List,
        name: string,
        current, allowed: u64,
    ) {
        violation := Limits_Violation_Value {
            name = name,
            current    = current,
            allowed    = allowed,
        }

        ensure(sa.append(violations, violation), "Too many limit violations")
    }

    check_max :: proc(
        violations: ^Limits_Violation_List,
        name: string,
        #any_int current, allowed: u64,
    ) {
        if current > allowed {
            add_violation(violations, name, current, allowed)
        }
    }

    check_min :: proc(
        violations: ^Limits_Violation_List,
        name: string,
        #any_int current, allowed: u64,
    ) {
        if current < allowed {
            add_violation(violations, name, current, allowed)
        }
    }

    fields := reflect.struct_fields_zipped(Limits)
    assert(len(fields) == LIMITS_MAX_VIOLATIONS, "Mismatch violations entries")

    for &field in fields {
        name := field.name

        // Get field values using offsets
        self_ptr := rawptr(uintptr(&self) + field.offset)
        allowed_ptr := rawptr(uintptr(&allowed) + field.offset)

        value1, value2: u64

        // Convert based on field type
        switch field.type.id {
        case u32:
            value1 = u64((^u32)(self_ptr)^)
            value2 = u64((^u32)(allowed_ptr)^)
        case u64:
            value1 = (^u64)(self_ptr)^
            value2 = (^u64)(allowed_ptr)^
        case:
            unreachable()
        }

        if strings.has_prefix(name, "max_") {
            check_max(&violations.values, name, value1, value2)
        } else if strings.has_prefix(name, "min_") {
            check_min(&violations.values, name, value1, value2)
        }
    }

    violations.ok = sa.len(violations.values) == 0
    ok = violations.ok
    return
}
