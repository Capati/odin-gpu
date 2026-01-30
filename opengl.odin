#+build windows, linux
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:slice"
import "core:strings"
import "core:sync"
import sa "core:container/small_array"
import intr "base:intrinsics"

// Vendor
import gl "vendor:OpenGL"

gl_init :: proc(allocator := context.allocator) {
    // Set platform specific procedures
    when ODIN_OS == .Windows {
        // Global procedures
        create_instance_impl     = gl_win32_create_instance

        // Adapter procedures
        adapter_release          = gl_win32_adapter_release

        // Instance procedures
        instance_create_surface  = gl_win32_instance_create_surface
        instance_request_adapter = gl_win32_instance_request_adapter
        instance_release         = gl_win32_instance_release

        // Surface procedures
        surface_get_capabilities = gl_win32_surface_get_capabilities
        surface_release          = gl_win32_surface_release
    } else  when ODIN_OS == .Linux  {
        // Global procedures
        create_instance_impl     = gl_linux_create_instance

        // Adapter procedures
        adapter_release          = gl_linux_adapter_release

        // Instance procedures
        instance_create_surface  = gl_linux_instance_create_surface
        instance_request_adapter = gl_linux_instance_request_adapter
        instance_release         = gl_linux_instance_release

        // Surface procedures
        surface_get_capabilities = gl_linux_surface_get_capabilities
        surface_release          = gl_linux_surface_release
    } else {
        unreachable()
    }

    // Adapter procedures
    adapter_get_info                          = gl_adapter_get_info
    adapter_info_free_members                 = gl_adapter_info_free_members
    adapter_get_features                      = gl_adapter_get_features
    adapter_get_limits                        = gl_adapter_get_limits
    adapter_has_feature                       = gl_adapter_has_feature
    adapter_request_device                    = gl_adapter_request_device
    adapter_get_texture_format_capabilities   = gl_adapter_get_texture_format_capabilities
    adapter_get_label                         = gl_adapter_get_label
    adapter_set_label                         = gl_adapter_set_label
    adapter_add_ref                           = gl_adapter_add_ref

    // Bind Group procedures
    bind_group_get_label                      = gl_bind_group_get_label
    bind_group_set_label                      = gl_bind_group_set_label
    bind_group_add_ref                        = gl_bind_group_add_ref
    bind_group_release                        = gl_bind_group_release

    // Bind Group Layout procedures
    bind_group_layout_get_label               = gl_bind_group_layout_get_label
    bind_group_layout_set_label               = gl_bind_group_layout_set_label
    bind_group_layout_add_ref                 = gl_bind_group_layout_add_ref
    bind_group_layout_release                 = gl_bind_group_layout_release

    // Buffer procedures
    buffer_destroy                            = gl_buffer_destroy
    buffer_get_map_state                      = gl_buffer_get_map_state
    buffer_get_size                           = gl_buffer_get_size
    buffer_get_usage                          = gl_buffer_get_usage
    buffer_map_async                          = gl_buffer_map_async
    buffer_unmap                              = gl_buffer_unmap
    buffer_get_label                          = gl_buffer_get_label
    buffer_set_label                          = gl_buffer_set_label
    buffer_add_ref                            = gl_buffer_add_ref
    buffer_release                            = gl_buffer_release

    // Command Buffer procedures
    command_buffer_get_label                  = gl_command_buffer_get_label
    command_buffer_set_label                  = gl_command_buffer_set_label
    command_buffer_add_ref                    = gl_command_buffer_add_ref
    command_buffer_release                    = gl_command_buffer_release

    // Command Encoder procedures
    command_encoder_begin_compute_pass        = gl_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass         = gl_command_encoder_begin_render_pass
    command_encoder_clear_buffer              = gl_command_encoder_clear_buffer
    command_encoder_resolve_query_set         = gl_ommand_encoder_resolve_query_set
    command_encoder_write_timestamp           = gl_command_encoder_write_timestamp
    command_encoder_copy_buffer_to_buffer     = gl_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture    = gl_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer    = gl_command_encoder_copy_texture_to_buffer
    command_encoder_copy_texture_to_texture   = gl_command_encoder_copy_texture_to_texture
    command_encoder_finish                    = gl_command_encoder_finish
    command_encoder_get_label                 = gl_command_encoder_get_label
    command_encoder_set_label                 = gl_command_encoder_set_label
    command_encoder_add_ref                   = gl_command_encoder_add_ref
    command_encoder_release                   = gl_command_encoder_release

    // Compute Pass procedures
    compute_pass_dispatch_workgroups          = gl_compute_pass_dispatch_workgroups
    compute_pass_dispatch_workgroups_indirect = gl_compute_pass_dispatch_workgroups_indirect
    compute_pass_end                          = gl_compute_pass_end
    compute_pass_insert_debug_marker          = gl_compute_pass_insert_debug_marker
    compute_pass_pop_debug_group              = gl_compute_pass_pop_debug_group
    compute_pass_push_debug_group             = gl_compute_pass_push_debug_group
    compute_pass_set_bind_group               = gl_compute_pass_set_bind_group
    compute_pass_set_pipeline                 = gl_compute_pass_set_pipeline
    compute_pass_get_label                    = gl_compute_pass_get_label
    compute_pass_set_label                    = gl_compute_pass_set_label
    compute_pass_add_ref                      = gl_compute_pass_add_ref
    compute_pass_release                      = gl_compute_pass_release

    // Compute Pipeline procedures
    compute_pipeline_get_bind_group_layout    = gl_compute_pipeline_get_bind_group_layout
    compute_pipeline_get_label                = gl_compute_pipeline_get_label
    compute_pipeline_set_label                = gl_compute_pipeline_set_label
    compute_pipeline_add_ref                  = gl_compute_pipeline_add_ref
    compute_pipeline_release                  = gl_compute_pipeline_release

    // Device procedures
    device_create_bind_group                  = gl_device_create_bind_group
    device_create_bind_group_layout           = gl_device_create_bind_group_layout
    device_create_buffer                      = gl_device_create_buffer
    device_get_queue                          = gl_device_get_queue
    device_create_texture                     = gl_device_create_texture
    device_create_sampler                     = gl_device_create_sampler
    device_create_command_encoder             = gl_device_create_command_encoder
    device_create_pipeline_layout             = gl_device_create_pipeline_layout
    device_create_shader_module               = gl_device_create_shader_module
    device_create_render_pipeline             = gl_device_create_render_pipeline
    device_get_features                       = gl_device_get_features
    device_get_limits                         = gl_device_get_limits
    device_get_label                          = gl_device_get_label
    device_set_label                          = gl_device_set_label
    device_add_ref                            = gl_device_add_ref
    device_release                            = gl_device_release

    // Instance procedures
    instance_enumarate_adapters               = gl_instance_enumarate_adapters
    instance_get_label                        = gl_instance_get_label
    instance_set_label                        = gl_instance_set_label
    instance_add_ref                          = gl_instance_add_ref

    // Pipeline Layout procedures
    pipeline_layout_get_label                 = gl_pipeline_layout_get_label
    pipeline_layout_set_label                 = gl_pipeline_layout_set_label
    pipeline_layout_add_ref                   = gl_pipeline_layout_add_ref
    pipeline_layout_release                   = gl_pipeline_layout_release

    // Surface procedures
    surface_capabilities_free_members         = gl_surface_capabilities_free_members
    surface_configure                         = gl_surface_configure
    surface_get_current_texture               = gl_surface_get_current_texture
    surface_present                           = gl_surface_present
    surface_get_label                         = gl_surface_get_label
    surface_set_label                         = gl_surface_set_label
    surface_add_ref                           = gl_surface_add_ref

    // Queue procedures
    queue_submit                              = gl_queue_submit
    queue_write_buffer_impl                   = gl_queue_write_buffer
    queue_write_texture                       = gl_queue_write_texture
    queue_get_label                           = gl_queue_get_label
    queue_set_label                           = gl_queue_set_label
    queue_add_ref                             = gl_queue_add_ref
    queue_release                             = gl_queue_release

    // Sampler procedures
    sampler_get_label                         = gl_sampler_get_label
    sampler_set_label                         = gl_sampler_set_label
    sampler_add_ref                           = gl_sampler_add_ref
    sampler_release                           = gl_sampler_release

    // Texture procedures
    texture_create_view_impl                  = gl_texture_create_view
    texture_get_usage                         = gl_texture_get_usage
    texture_get_dimension                     = gl_texture_get_dimension
    texture_get_size                          = gl_texture_get_size
    texture_get_width                         = gl_texture_get_width
    texture_get_height                        = gl_texture_get_height
    texture_get_format                        = gl_texture_get_format
    texture_get_mip_level_count               = gl_texture_get_mip_level_count
    texture_get_sample_count                  = gl_texture_get_sample_count
    texture_get_descriptor                    = gl_texture_get_descriptor
    texture_get_label                         = gl_texture_get_label
    texture_set_label                         = gl_texture_set_label
    texture_add_ref                           = gl_texture_add_ref
    texture_release                           = gl_texture_release

    // Texture View procedures
    texture_view_get_label                    = gl_texture_view_get_label
    texture_view_set_label                    = gl_texture_view_set_label
    texture_view_add_ref                      = gl_texture_view_add_ref
    texture_view_release                      = gl_texture_view_release

    // Render Pass procedures
    render_pass_begin_occlusion_query         = gl_render_pass_begin_occlusion_query
    render_pass_set_scissor_rect              = gl_render_pass_set_scissor_rect
    render_pass_set_viewport                  = gl_render_pass_set_viewport
    render_pass_set_stencil_reference         = gl_render_pass_set_stencil_reference
    render_pass_draw                          = gl_render_pass_draw
    render_pass_draw_indexed                  = gl_render_pass_draw_indexed
    render_pass_draw_indexed_indirect         = gl_render_pass_draw_indexed_indirect
    render_pass_draw_indirect                 = gl_render_pass_draw_indirect
    render_pass_end_occlusion_query           = gl_render_pass_end_occlusion_query
    render_pass_execute_bundles               = gl_render_pass_execute_bundles
    render_pass_insert_debug_marker           = gl_render_pass_insert_debug_marker
    render_pass_pop_debug_group               = gl_render_pass_pop_debug_group
    render_pass_push_debug_group              = gl_render_pass_push_debug_group
    render_pass_set_bind_group                = gl_render_pass_set_bind_group
    render_pass_set_pipeline                  = gl_render_pass_set_pipeline
    render_pass_set_vertex_buffer             = gl_render_pass_set_vertex_buffer
    render_pass_set_index_buffer              = gl_render_pass_set_index_buffer
    render_pass_end                           = gl_render_pass_end
    render_pass_get_label                     = gl_render_pass_get_label
    render_pass_set_label                     = gl_render_pass_set_label
    render_pass_add_ref                       = gl_render_pass_add_ref
    render_pass_release                       = gl_render_pass_release

     // Render Bundle procedures
    render_bundle_get_label                   = gl_render_bundle_get_label
    render_bundle_set_label                   = gl_render_bundle_set_label
    render_bundle_add_ref                     = gl_render_bundle_add_ref
    render_bundle_release                     = gl_render_bundle_release

    // Shader Module procedures
    shader_module_get_label                   = gl_shader_module_get_label
    shader_module_set_label                   = gl_shader_module_set_label
    shader_module_add_ref                     = gl_shader_module_add_ref
    shader_module_release                     = gl_shader_module_release

    // Render Pipeline procedures
    render_pipeline_get_bind_group_layout     = gl_render_pipeline_get_bind_group_layout
    render_pipeline_get_label                 = gl_render_pipeline_get_label
    render_pipeline_set_label                 = gl_render_pipeline_set_label
    render_pipeline_add_ref                   = gl_render_pipeline_add_ref
    render_pipeline_release                   = gl_render_pipeline_release
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------

// Note: Platform specific

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


@(require_results)
gl_adapter_get_features :: proc(
    adapter: Adapter,
    loc := #caller_location,
) -> (features: Features) {
    major, minor := GL_MAJOR_VERSION, GL_MINOR_VERSION
    version := major * 10 + minor

    // Helper to check if version meets a threshold
    supported :: proc(#any_int version, maj, min: u32) -> bool {
        return version >= (maj * 10 + min)
    }

    // Always enabled (emulated or core basics).
    features += {
        // Emulated with uniforms in GL.
        .Push_Constants,
        // Always (queryable formats).
        .Texture_Adapter_Specific_Format_Features,
        // Core in GL 4.4+ (ARB_clear_texture), but emulatable earlier.
        .Clear_Texture,
        // Core since GL 3.0 (packed depth-stencil).
        .Depth32_Float_Stencil8,
        // Core since GL 1.5 (glMapBuffer).
        .Mappable_Primary_Buffers,
        // Core since GL 1.0 (GL_LINE).
        .Polygon_Mode_Line,
        // Core since GL 1.0 (GL_POINT).
        .Polygon_Mode_Point,
        // Core since GL 1.3, but full support via ARB_texture_border_clamp
        // (core 1.3) or EXT_texture_border_clamp.
        .Address_Mode_Clamp_To_Border,
        // Core since GL 3.0, but requires ARB_color_buffer_float or
        // EXT_color_buffer_float for full filtering.
        .Float32_Filterable,
        // Core since GL 3.0 (gl_ClipDistance), or EXT_clip_cull_distance.
        .Clip_Distances,
        // Core since GL 3.0 (e.g., GL_RG16_SNORM).
        .Texture_Format_16Bit_Norm,
        // Core since GL 3.2 (gl_PrimitiveID), or via OES_geometry_shader/ARB_geometry_shader4.
        .Shader_Primitive_Index,
        // Core since GL 4.1 (ARB_vertex_attrib_64bit).
        .Vertex_Attribute_64Bit,
        // Core since GL 3.1 (ARB_uniform_buffer_object).
        // .Uniform_Buffer_Binding_Arrays,
    }

    // Version-gated core features.
    if supported(version, 3, 3) {
        features += {
            // Core since GL 3.3 (ARB_timer_query).
            .Timestamp_Query,
            // Core since GL 3.3.
            .Timestamp_Query_Inside_Encoders,
            // Core since GL 3.3.
            .Timestamp_Query_Inside_Passes,
            // Core since GL 3.3 (ARB_blend_func_extended).
            .Dual_Source_Blending,
        }
    }

    if supported(version, 4, 0) {
        features += {
            // Core since GL 4.0 (ARB_gpu_shader_fp64).
            .Shader_F64,
            // Core since GL 4.0 (ARB_gpu_shader_int64).
            .Shader_Int64,
        }
    }

    if supported(version, 4, 2) {
        features += {
            // Core since GL 4.2 (ARB_base_instance), requires
            // ARB_shader_draw_parameters for full.
            .Indirect_First_Instance,
            // Core since GL 4.2 (ARB_shader_atomic_counters).
            // .Shader_Float32_Atomic,
            // Core since GL 4.2 (ARB_shader_image_load_store).
            .Texture_Atomic,
            // Core since GL 4.2 (layout(early_fragment_tests)).
            .Shader_Early_Depth_Test,
            // Core since GL 4.2 (ARB_shader_image_load_store).
            .Bgra8_Unorm_Storage,
        }
    }

    if supported(version, 4, 3) {
        features += {
            // Core since GL 4.3 (ARB_shader_storage_buffer_object).
            .Buffer_Binding_Array,
            // Core since GL 4.3.
            .Storage_Resource_Binding_Array,
            // Core since GL 4.3 (SSBOs in vertex shaders).
            .Vertex_Writable_Storage,
            // Core since GL 4.3, or ARB_ES3_compatibility.
            .Texture_Compression_ETC2,
        }
    }

    if supported(version, 4, 4) {
        features += {
            // Core since GL 4.4 (ARB_clear_texture).
            .Clear_Texture,
        }
    }

    if supported(version, 4, 5) {
        features += {
            // Core since 3.3 (ARB_depth_clamp)
            // but clip control is ARB_clip_control (core 4.5)
            .Depth_Clip_Control,
        }
    }

    if supported(version, 4, 6) {
        features += {
            // Core since GL 4.6 (ARB_pipeline_statistics_query).
            .Pipeline_Statistics_Query,
            // Core since GL 4.6 (ARB_indirect_parameters).
            .Multi_Draw_Indirect_Count,
        }
    }

    // Extension-based features.
    if gl_check_extension_support("GL_ARB_depth_clamp") ||
       gl_check_extension_support("GL_EXT_depth_clamp") {
        features += {.Depth_Clip_Control}  // Enables depth clamping (unclipped depth).
    }

    if gl_check_extension_support("GL_EXT_texture_compression_s3tc") ||
       gl_check_extension_support("GL_ARB_texture_compression_bptc") {
        features += {.Texture_Compression_BC, .Texture_Compression_BC_Sliced_3D}
    }

    if gl_check_extension_support("GL_KHR_texture_compression_astc_ldr") ||
       gl_check_extension_support("WEBGL_compressed_texture_astc") ||
       gl_check_extension_support("GL_OES_texture_compression_astc") {
        features += {.Texture_Compression_ASTC, .Texture_Compression_ASTC_Sliced_3D}
    }

    if gl_check_extension_support("GL_KHR_texture_compression_astc_hdr") {
        features += {.Texture_Compression_ASTC_Hdr}
    }

    if gl_check_extension_support("GL_ARB_bindless_texture") {
        features += {.Texture_Binding_Array}
    }

    if gl_check_extension_support("GL_ARB_gpu_shader5") || supported(version, 4, 0) {
        features += {
            .Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
            // .Storage_Texture_Array_Non_Uniform_Indexing,
        }
    }

    if gl_check_extension_support("GL_NV_conservative_raster") ||
       gl_check_extension_support("GL_INTEL_conservative_rasterization") {
        features += {.Conservative_Rasterization}
    }

    if gl_check_extension_support("GL_OVR_multiview") ||
       gl_check_extension_support("GL_OVR_multiview2") {
        features += {.Multiview}
    }

    if gl_check_extension_support("GL_ARB_shader_ballot") &&
       gl_check_extension_support("GL_ARB_shader_group_vote") {
        features += {.Subgroup, .Subgroup_Vertex, .Subgroup_Barrier}
    }

    // if gl_check_extension_support("GL_NV_shader_atomic_int64") {
    //     features += {.Shader_Int64_Atomic_Min_Max, .Shader_Int64_Atomic_All_Ops}
    // }

    if gl_check_extension_support("GL_AMD_gpu_shader_half_float") ||
       gl_check_extension_support("GL_NV_gpu_shader5") {
        features += {.Shader_F16}
    }

    if gl_check_extension_support("GL_AMD_gpu_shader_int16") ||
       gl_check_extension_support("GL_NV_gpu_shader5") {
        features += {.Shader_I16}
    }

    if gl_is_format_renderable(gl.R11F_G11F_B10F) {
        features += {.Rg11B10_Ufloat_Renderable}
    }

    if gl_check_extension_support("GL_ARB_sparse_texture") {
        features += {.Partially_Bound_Binding_Array}
    }

    // if gl_check_extension_support("GL_ARB_get_program_binary") || supported(version, 4, 1) {
    //     features += {.Pipeline_Cache}
    // }

    if gl_check_extension_support("GL_ARB_timer_query") {
        features += {
            .Timestamp_Query,
            .Timestamp_Query_Inside_Encoders,
            .Timestamp_Query_Inside_Passes,
        }
    }

    if gl_check_extension_support("GL_EXT_blend_func_extended") ||
       gl_check_extension_support("GL_ARB_blend_func_extended") {
        features += {.Dual_Source_Blending}
    }

    if gl_check_extension_support("GL_EXT_clip_cull_distance") || supported(version, 3, 0) {
        features += {.Clip_Distances}
    }

    if gl_check_extension_support("GL_ARB_color_buffer_float") ||
       gl_check_extension_support("GL_EXT_color_buffer_float") ||
       gl_check_extension_support("OES_texture_float_linear") {
        features += {.Float32_Filterable}
    }

    return
}

@(require_results)
gl_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc: runtime.Source_Code_Location,
) -> (
    info: Adapter_Info,
) {
    impl := get_impl(GL_Adapter_Impl, adapter, loc)

    info.name = strings.clone(string(impl.renderer), allocator)
    info.vendor = 0
    info.device = 0
    info.device_type = .Other
    // info.driver = strings.clone(string(impl.vendor), allocator)
    info.driver_info = strings.clone(string(impl.version), allocator)
    info.backend = .Gl

    return
}

gl_adapter_info_free_members :: proc(self: Adapter_Info, allocator := context.allocator) {
    context.allocator = allocator
    if len(self.name) > 0 do delete(self.name)
    // if len(self.driver) > 0 do delete(self.driver)
    if len(self.driver_info) > 0 do delete(self.driver_info)
}

@(require_results)
gl_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> (limits: Limits) {
    major, minor := GL_MAJOR_VERSION, GL_MINOR_VERSION
    version := u32(major * 10 + minor)

    supported :: proc(version, maj, min: u32) -> bool {
        return version >= (maj * 10 + min)
    }

    // Start with default limits
    limits = LIMITS_DOWNLEVEL

    // Texture Limits
    max_texture_size: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_SIZE, &max_texture_size)
    limits.max_texture_dimension_1d = u32(max_texture_size)
    limits.max_texture_dimension_2d = u32(max_texture_size)

    max_texture_3d_size: i32
    gl.GetIntegerv(gl.MAX_3D_TEXTURE_SIZE, &max_texture_3d_size)
    limits.max_texture_dimension_3d = u32(max_texture_3d_size)

    max_array_texture_layers: i32
    gl.GetIntegerv(gl.MAX_ARRAY_TEXTURE_LAYERS, &max_array_texture_layers)
    limits.max_texture_array_layers = u32(max_array_texture_layers)

    // Binding Limits
    //
    // Since we flatten bindings in OpenGL, leave max_bind_groups and
    // max_bindings_per_bind_group at default values

    max_uniform_buffer_bindings: i32
    gl.GetIntegerv(gl.MAX_UNIFORM_BUFFER_BINDINGS, &max_uniform_buffer_bindings)
    limits.max_dynamic_uniform_buffers_per_pipeline_layout = u32(max_uniform_buffer_bindings)

    max_shader_storage_buffer_bindings: i32 = 0
    if supported(version, 4, 3) ||
       gl_check_extension_support("GL_ARB_shader_storage_buffer_object") {
        gl.GetIntegerv(gl.MAX_SHADER_STORAGE_BUFFER_BINDINGS, &max_shader_storage_buffer_bindings)
        limits.max_dynamic_storage_buffers_per_pipeline_layout =
            u32(max_shader_storage_buffer_bindings)
    }

    // Per-Stage Sampler Limits
    max_texture_image_units: i32
    gl.GetIntegerv(gl.MAX_TEXTURE_IMAGE_UNITS, &max_texture_image_units)

    max_vertex_texture_image_units: i32
    gl.GetIntegerv(gl.MAX_VERTEX_TEXTURE_IMAGE_UNITS, &max_vertex_texture_image_units)

    // Use the minimum across stages
    limits.max_sampled_textures_per_shader_stage = u32(min(
        max_texture_image_units,
        max_vertex_texture_image_units,
    ))
    limits.max_samplers_per_shader_stage = u32(max_texture_image_units)

    // Storage Buffer Limits
    max_storage_buffer_bindings: i32 = 0
    if supported(version, 4, 3) ||
       gl_check_extension_support("GL_ARB_shader_storage_buffer_object") {
        gl.GetIntegerv(gl.MAX_SHADER_STORAGE_BUFFER_BINDINGS, &max_storage_buffer_bindings)
        limits.max_storage_buffers_per_shader_stage = u32(max_storage_buffer_bindings)

        // Per-stage storage buffer limits for compatibility
        max_fragment_ss_blocks: i32
        gl.GetIntegerv(gl.MAX_FRAGMENT_SHADER_STORAGE_BLOCKS, &max_fragment_ss_blocks)

        max_vertex_ss_blocks: i32
        gl.GetIntegerv(gl.MAX_VERTEX_SHADER_STORAGE_BLOCKS, &max_vertex_ss_blocks)
    }

    // Storage Texture Limits
    if supported(version, 4, 2) || gl_check_extension_support("GL_ARB_shader_image_load_store") {
        // Note: OpenGL ES can have zero vertex image uniforms, so use compute as reference
        max_compute_image_uniforms: i32
        gl.GetIntegerv(gl.MAX_COMPUTE_IMAGE_UNIFORMS, &max_compute_image_uniforms)
        limits.max_storage_textures_per_shader_stage = u32(max_compute_image_uniforms)

        // Per-stage limits for compatibility
        max_fragment_image_uniforms: i32
        gl.GetIntegerv(gl.MAX_FRAGMENT_IMAGE_UNIFORMS, &max_fragment_image_uniforms)

        max_vertex_image_uniforms: i32
        gl.GetIntegerv(gl.MAX_VERTEX_IMAGE_UNIFORMS, &max_vertex_image_uniforms)
    }

    // Uniform Buffer Limits
    limits.max_uniform_buffers_per_shader_stage = u32(max_uniform_buffer_bindings)

    max_uniform_block_size: i32
    gl.GetIntegerv(gl.MAX_UNIFORM_BLOCK_SIZE, &max_uniform_block_size)
    limits.max_uniform_buffer_binding_size = u64(max_uniform_block_size)

    max_shader_storage_block_size: i32 = 0
    if supported(version, 4, 3) ||
       gl_check_extension_support("GL_ARB_shader_storage_buffer_object") {
        gl.GetIntegerv(gl.MAX_SHADER_STORAGE_BLOCK_SIZE, &max_shader_storage_block_size)
        limits.max_storage_buffer_binding_size = u64(max_shader_storage_block_size)
    }

    // Alignment Requirements
    min_uniform_offset_alignment: i32
    gl.GetIntegerv(gl.UNIFORM_BUFFER_OFFSET_ALIGNMENT, &min_uniform_offset_alignment)
    limits.min_uniform_buffer_offset_alignment = u32(min_uniform_offset_alignment)

    min_storage_offset_alignment: i32 = 256
    if supported(version, 4, 3) ||
       gl_check_extension_support("GL_ARB_shader_storage_buffer_object") {
        gl.GetIntegerv(gl.SHADER_STORAGE_BUFFER_OFFSET_ALIGNMENT, &min_storage_offset_alignment)
    }
    limits.min_storage_buffer_offset_alignment = u32(min_storage_offset_alignment)

    // Vertex Limits
    max_vertex_attrib_bindings: i32 = 16
    if supported(version, 4, 3) || gl_check_extension_support("GL_ARB_vertex_attrib_binding") {
        gl.GetIntegerv(gl.MAX_VERTEX_ATTRIB_BINDINGS, &max_vertex_attrib_bindings)
    }
    limits.max_vertex_buffers = u32(max_vertex_attrib_bindings)

    limits.max_buffer_size = MAX_BUFFER_SIZE

    max_vertex_attribs: i32
    gl.GetIntegerv(gl.MAX_VERTEX_ATTRIBS, &max_vertex_attribs)
    limits.max_vertex_attributes = u32(max_vertex_attribs)

    max_vertex_attrib_stride: i32 = 2048
    if supported(version, 4, 3) || gl_check_extension_support("GL_ARB_vertex_attrib_binding") {
        gl.GetIntegerv(gl.MAX_VERTEX_ATTRIB_STRIDE, &max_vertex_attrib_stride)
        if max_vertex_attrib_stride == 0 {
            max_vertex_attrib_stride = 2048  // Driver fallback
        }
    }
    limits.max_vertex_buffer_array_stride = u32(max_vertex_attrib_stride)

    // Inter-Stage Shader Limits
    max_varying_vectors: i32
    gl.GetIntegerv(gl.MAX_VARYING_VECTORS, &max_varying_vectors)

    limits.max_inter_stage_shader_variables = min(
        u32(max_varying_vectors * 4),  // Convert vectors to components
        MAX_INTER_STAGE_SHADER_VARIABLES * 4,
    )

    // Render Target Limits
    max_color_attachments: i32
    gl.GetIntegerv(gl.MAX_COLOR_ATTACHMENTS, &max_color_attachments)

    max_draw_buffers: i32
    gl.GetIntegerv(gl.MAX_DRAW_BUFFERS, &max_draw_buffers)

    // Use minimum of both limits
    limits.max_color_attachments = u32(min(max_color_attachments, max_draw_buffers))

    // Dawn leaves this undefined for GL - we can calculate a conservative value
    // Assume RGBA32F (16 bytes) per attachment as maximum
    limits.max_color_attachment_bytes_per_sample = limits.max_color_attachments * 16

    // Compute Limits
    if supported(version, 4, 3) || gl_check_extension_support("GL_ARB_compute_shader") {
        max_compute_shared_memory: i32
        gl.GetIntegerv(gl.MAX_COMPUTE_SHARED_MEMORY_SIZE, &max_compute_shared_memory)
        limits.max_compute_workgroup_storage_size = u32(max_compute_shared_memory)

        max_compute_invocations: i32
        gl.GetIntegerv(gl.MAX_COMPUTE_WORK_GROUP_INVOCATIONS, &max_compute_invocations)
        limits.max_compute_invocations_per_workgroup = u32(max_compute_invocations)

        max_wg_size_x: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_SIZE, 0, &max_wg_size_x)
        limits.max_compute_workgroup_size_x = u32(max_wg_size_x)

        max_wg_size_y: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_SIZE, 1, &max_wg_size_y)
        limits.max_compute_workgroup_size_y = u32(max_wg_size_y)

        max_wg_size_z: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_SIZE, 2, &max_wg_size_z)
        limits.max_compute_workgroup_size_z = u32(max_wg_size_z)

        // Get minimum across all dimensions for workgroups per dimension
        max_wg_count_x: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_COUNT, 0, &max_wg_count_x)

        max_wg_count_y: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_COUNT, 1, &max_wg_count_y)

        max_wg_count_z: i32
        gl.GetIntegeri_v(gl.MAX_COMPUTE_WORK_GROUP_COUNT, 2, &max_wg_count_z)

        limits.max_compute_workgroups_per_dimension = u32(min(
            max_wg_count_x,
            max_wg_count_y,
            max_wg_count_z,
        ))
    }

    // Unsupported in OpenGL
    limits.min_subgroup_size = 0
    limits.max_subgroup_size = 0
    limits.max_push_constant_size = 256  // Emulated via uniforms
    limits.max_non_sampler_bindings = 1000000  // Effectively unlimited

    // Mesh/Task shaders - not in OpenGL
    limits.max_task_workgroup_total_count = 0
    limits.max_task_workgroups_per_dimension = 0
    limits.max_mesh_output_layers = 0
    limits.max_mesh_multiview_count = 0

    // Ray tracing - not in OpenGL
    limits.max_blas_primitive_count = 0
    limits.max_blas_geometry_count = 0
    limits.max_tlas_instance_count = 0
    limits.max_acceleration_structures_per_shader_stage = 0

    return
}

@(require_results)
gl_adapter_has_feature :: proc(
    adapter: Adapter,
    features: Features,
    loc := #caller_location,
) -> bool {
    unimplemented()
}

gl_adapter_request_device :: proc(
    adapter: Adapter,
    callback_info: Request_Device_Callback_Info,
    descriptor: Maybe(Device_Descriptor) = nil,
    loc := #caller_location,
) {
    impl := get_impl(GL_Adapter_Impl, adapter, loc)

    assert(callback_info.callback != nil, "No callback provided for device request", loc)
    assert(adapter != nil, "Invalid adapter", loc)
    assert(impl.instance != nil, "Invalid instance", loc)

    instance_impl := get_impl(GL_Instance_Impl, impl.instance, loc)

    invoke_callback :: proc(
        callback_info: Request_Device_Callback_Info,
        status: Request_Device_Status,
        device: Device,
        message: string,
    ) {
        callback_info.callback(
            status,
            device,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }

     // Default state
    gl.Enable(gl.SCISSOR_TEST)
    gl.Enable(gl.PRIMITIVE_RESTART_FIXED_INDEX)
    gl.Enable(gl.TEXTURE_CUBE_MAP_SEAMLESS)

    if .Debug in instance_impl.flags {
        gl.Enable(gl.DEBUG_OUTPUT)
        gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
        gl.DebugMessageCallback(gl_message_callback, instance_impl)
    }

    device_impl := adapter_new_handle(GL_Device_Impl, adapter, loc)
    queue_impl := device_new_handle(GL_Queue_Impl, Device(device_impl), loc)
    device_impl.queue = queue_impl
    device_impl.backend = instance_impl.backend
    device_impl.shader_formats = instance_impl.shader_formats

    // Initialize base command allocator
    cmd_impl := device_new_handle(GL_Command_Encoder_Impl, Device(device_impl), loc)
    gl_adapter_add_ref(adapter, loc)

    command_allocator_init(&cmd_impl.cmd_allocator, allocator = impl.allocator, loc = loc)
    device_impl.encoder = cmd_impl

    cmdbuf_impl := command_encoder_new_handle(GL_Command_Buffer_Impl, Command_Encoder(cmd_impl), loc)
    cmd_impl.cmdbuf = cmdbuf_impl

    // Check if polygon offset clamp is supported
    if GL_MAJOR_VERSION == 4 && GL_MINOR_VERSION >= 6 {
        device_impl.polygon_offset_clamp = true
    } else {
        device_impl.polygon_offset_clamp =
            gl_check_extension_support("GL_ARB_polygon_offset_clamp")
    }

    pool_init(&device_impl.pending_maps, impl.allocator)

    invoke_callback(callback_info, .Success, Device(device_impl), "")
}

gl_adapter_get_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities {
    unimplemented()
}

@(require_results)
gl_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    impl := get_impl(GL_Adapter_Impl, adapter, loc)
    return string_buffer_get_string(&impl.label)
}

gl_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
    impl := get_impl(GL_Adapter_Impl, adapter, loc)
    string_buffer_init(&impl.label, label)
}

gl_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    impl := get_impl(GL_Adapter_Impl, adapter, loc)
    ref_count_add(&impl.ref, loc)
}

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------


GL_Bind_Group_Entry :: struct {
    binding:  u32,
    resource: GL_Binding_Resource,
}

GL_Binding_Resource :: union {
    GL_Buffer_Binding,
    GL_Sampler_Binding,
    GL_Texture_View_Binding,
    []GL_Buffer_Binding,
    []GL_Sampler_Binding,
    []GL_Texture_View_Binding,
}

GL_Buffer_Binding :: struct {
    buffer: ^GL_Buffer_Impl,
    offset: u64,
    size:   u64,
}

GL_Sampler_Binding :: struct {
    sampler: ^GL_Sampler_Impl,
}

GL_Texture_View_Binding :: struct {
    texture_view: ^GL_Texture_View_Impl,
}

GL_Bind_Group_Impl :: struct {
    using base: Bind_Group_Base,
    entries:    []GL_Bind_Group_Entry,
}

@(require_results)
gl_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    impl := get_impl(GL_Bind_Group_Impl, bind_group, loc)
    return string_buffer_get_string(&impl.label)
}

gl_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    impl := get_impl(GL_Bind_Group_Impl, bind_group, loc)
    string_buffer_init(&impl.label, label)
}

gl_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(GL_Bind_Group_Impl, bind_group, loc)
    ref_count_add(&impl.ref, loc)
}

gl_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(GL_Bind_Group_Impl, bind_group, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        for &entry in impl.entries {
            switch &res in entry.resource {
            case GL_Buffer_Binding:
                gl_buffer_release(Buffer(res.buffer), loc)
            case GL_Sampler_Binding:
                gl_sampler_release(Sampler(res.sampler), loc)
            case GL_Texture_View_Binding:
                gl_texture_view_release(Texture_View(res.texture_view), loc)
            case []GL_Buffer_Binding:
                for &buffer_entry in res {
                    gl_buffer_release(Buffer(buffer_entry.buffer), loc)
                }
            case []GL_Sampler_Binding:
                for &sampler_entry in res {
                    gl_sampler_release(Sampler(sampler_entry.sampler), loc)
                }
            case []GL_Texture_View_Binding:
                for &view_entry in res {
                    gl_texture_view_release(Texture_View(view_entry.texture_view), loc)
                }
            }
        }
        delete(impl.entries)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------


GL_Bind_Group_Layout_Impl :: struct {
    using base: Bind_Group_Layout_Base,
    entries:    []GL_Bind_Group_Layout_Entry,
}

GL_Bind_Group_Layout_Entry :: struct {
    binding:    u32,
    visibility: Shader_Stages,
    type:       GL_Binding_Type,
    count:      u32,
}

GL_Binding_Type :: union {
    GL_Buffer_Binding_Layout,
    GL_Sampler_Binding_Layout,
    GL_Texture_Binding_Layout,
    GL_Storage_Texture_Binding_Layout,
    GL_Acceleration_Structure_Binding_Layout,
}

GL_Buffer_Binding_Layout :: struct {
    type:               Buffer_Binding_Type,
    has_dynamic_offset: bool,
    min_binding_size:   u64,
    gl_target:          u32, // GL_UNIFORM_BUFFER or GL_SHADER_STORAGE_BUFFER
}

GL_Sampler_Binding_Layout :: struct {
    type: Sampler_Binding_Type,
}

GL_Texture_Binding_Layout :: struct {
    sample_type:    Texture_Sample_Type,
    view_dimension: Texture_View_Dimension,
    multisampled:   bool,
    gl_target:      u32, // GL_TEXTURE_2D, GL_TEXTURE_CUBE_MAP, etc.
}

GL_Storage_Texture_Binding_Layout :: struct {
    access:         Storage_Texture_Access,
    format:         Texture_Format,
    view_dimension: Texture_View_Dimension,
    gl_target:      u32, // GL_TEXTURE_2D, etc.
    gl_format:      u32, // Internal format for glBindImageTexture
}

GL_Acceleration_Structure_Binding_Layout :: struct {
    vertex_return: bool,
}

@(require_results)
gl_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Bind_Group_Layout_Impl, bind_group_layout, loc)
    return string_buffer_get_string(&impl.label)
}

gl_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Bind_Group_Layout_Impl, bind_group_layout, loc)
    string_buffer_init(&impl.label, label)
}

gl_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := get_impl(GL_Bind_Group_Layout_Impl, bind_group_layout, loc)
    ref_count_add(&impl.ref, loc)
}

gl_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := get_impl(GL_Bind_Group_Layout_Impl, bind_group_layout, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if len(impl.entries) > 0 {
            delete(impl.entries)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------


GL_Buffer_Impl :: struct {
    using base:     Buffer_Base,
    handle:         u32,
    allocated_size: Buffer_Address,
}

gl_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)

    // Unmap if still mapped
    if impl.map_state != .Unmapped {
        gl.UnmapNamedBuffer(impl.handle)
        impl.mapped_ptr = nil
        impl.map_state = .Unmapped
    }

    if impl.handle != 0 {
        gl.DeleteBuffers(1, &impl.handle)
        impl.handle = 0
    }
}

gl_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    return impl.map_state
}

gl_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    return impl.size
}

gl_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    return impl.usage
}

GL_Pending_Map_Request :: struct {
    buffer:        Buffer,
    mode:          Map_Modes,
    offset:        uint,
    size:          uint,
    callback_info: Buffer_Map_Callback_Info,
    fence:         gl.sync_t,
    future:        Future,
}

gl_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Modes,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> (
    future: Future,
) {
    assert(callback_info.callback != nil, "Invalid buffer map callback", loc)

    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    device_impl := get_impl(GL_Device_Impl, impl.device, loc)

    // Create a sync object to wait for GPU to finish
    sync_obj := gl.FenceSync(gl.SYNC_GPU_COMMANDS_COMPLETE, 0)

    // Store pending map request
    pending_map := GL_Pending_Map_Request {
        buffer        = buffer,
        mode          = mode,
        offset        = offset,
        size          = size,
        callback_info = callback_info,
        fence         = sync_obj,
    }

    sync.guard(&device_impl.pending_map_mutex)
    future.id = from_handle(pool_create(&device_impl.pending_maps, pending_map))

    return

    // invoke_callback :: proc(
    //     callback_info: Buffer_Map_Callback_Info,
    //     status: Map_Async_Status,
    //     message: string,
    // ) {
    //     callback_info.callback(
    //         status, message, callback_info.userdata1, callback_info.userdata2)
    // }

    // // Validate buffer state
    // if impl.map_state != .Unmapped {
    //     invoke_callback(callback_info, .Error, "Buffer is already mapped")
    //     return
    // }

    // // Validate range
    // if offset + size > uint(impl.size) {
    //     invoke_callback(callback_info, .Error, "Map range exceeds buffer size")
    //     return
    // }

    // size := size
    // offset := offset

    // // OpenGL requires a non-empty range for buffer mapping. We ensure this by
    // // mapping a minimum of 4 bytes, which our buffer always provides.
    // if size == 0 {
    //     if offset != 0 {
    //         offset -= 4
    //     }
    //     size = 4
    // }

    // // Determine map flags
    // map_flags: u32
    // switch {
    // case .Read in mode:
    //     assert(.Map_Read in impl.usage, "Buffer not created with Map_Read usage", loc)
    //     map_flags = gl.MAP_READ_BIT
    //     impl.map_state = .Mapped_For_Read

    // case .Write in mode:
    //     assert(.Map_Write in impl.usage, "Buffer not created with Map_Write usage", loc)
    //     map_flags = gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT
    //     impl.map_state = .Mapped_For_Write
    // }

    // impl.mapped_ptr = gl.MapNamedBufferRange(impl.handle, int(offset), int(size), map_flags)

    // assert(impl.mapped_ptr != nil, "Failed to map buffer", loc)
    // impl.mapped_range = {start = u64(offset), end = u64(size)}

    // return
}

gl_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)

    assert(impl.map_state != .Unmapped, "Buffer not mapped", loc)

    // Unmap the buffer
    success := gl.UnmapNamedBuffer(impl.handle)
    assert(success == gl.TRUE, "Failed to unmap buffer", loc)

    impl.mapped_ptr = nil
    impl.map_state = .Unmapped
    impl.mapped_range = {}
}

@(require_results)
gl_buffer_get_label :: proc(
    buffer: Buffer,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    return string_buffer_get_string(&impl.label)
}

gl_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location)  {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    string_buffer_init(&impl.label, label)
}

gl_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location)  {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    ref_count_add(&impl.ref, loc)
}

gl_buffer_release :: proc(buffer: Buffer, loc := #caller_location)  {
    impl := get_impl(GL_Buffer_Impl, buffer, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        gl_buffer_destroy(buffer, loc)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------


GL_Device_Impl :: struct {
    using base:           Device_Base,
    queue:                ^GL_Queue_Impl,
    encoder:              ^GL_Command_Encoder_Impl,
    polygon_offset_clamp: bool,
    pending_maps:         Pool(GL_Pending_Map_Request),
    format_table:         GL_Format_Table,
    pending_map_mutex:    sync.Mutex,
}

@(require_results)
gl_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := get_impl(GL_Device_Impl, device, loc)
    layout := device_new_handle(GL_Bind_Group_Layout_Impl, device, loc)

    // Convert entries to GL-specific format
    if len(descriptor.entries) > 0 {
        layout.entries =
            make([]GL_Bind_Group_Layout_Entry, len(descriptor.entries), impl.allocator)

        for entry, i in descriptor.entries {
            gl_entry := &layout.entries[i]
            gl_entry.binding = entry.binding
            gl_entry.visibility = entry.visibility
            gl_entry.count = entry.count

            // Convert binding type to GL-specific type
            switch bind_type in entry.type {
            case Buffer_Binding_Layout:
                gl_target: u32
                #partial switch bind_type.type {
                case .Uniform:
                    gl_target = gl.UNIFORM_BUFFER
                case .Storage, .Read_Only_Storage:
                    gl_target = gl.SHADER_STORAGE_BUFFER
                case:
                    unreachable()
                }

                gl_entry.type = GL_Buffer_Binding_Layout {
                    type               = bind_type.type,
                    has_dynamic_offset = bind_type.has_dynamic_offset,
                    min_binding_size   = bind_type.min_binding_size,
                    gl_target          = gl_target,
                }

            case Sampler_Binding_Layout:
                gl_entry.type = GL_Sampler_Binding_Layout{
                    type = bind_type.type,
                }

            case Texture_Binding_Layout:
                gl_target := gl_texture_view_dimension_to_target(bind_type.view_dimension)

                gl_entry.type = GL_Texture_Binding_Layout {
                    sample_type    = bind_type.sample_type,
                    view_dimension = bind_type.view_dimension,
                    multisampled   = bind_type.multisampled,
                    gl_target      = gl_target,
                }

            case Storage_Texture_Binding_Layout:
                gl_target := gl_texture_view_dimension_to_target(bind_type.view_dimension)
                gl_format := GL_FORMAT_TABLE[bind_type.format].internal_format

                gl_entry.type = GL_Storage_Texture_Binding_Layout {
                    access         = bind_type.access,
                    format         = bind_type.format,
                    view_dimension = bind_type.view_dimension,
                    gl_target      = gl_target,
                    gl_format      = gl_format,
                }

            case Acceleration_Structure_Binding_Layout:
                unimplemented("Ray tracing acceleration structures not supported")
            }
        }

        // Sort entries by binding in ascending order
        slice.sort_by(layout.entries, proc(a, b: GL_Bind_Group_Layout_Entry) -> bool {
            return a.binding < b.binding
        })
    }

    return Bind_Group_Layout(layout)
}

@(require_results)
gl_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    impl := get_impl(GL_Device_Impl, device, loc)

    assert(descriptor.layout != nil, "Invalid bind group layout", loc)
    layout_impl := get_impl(GL_Bind_Group_Layout_Impl, descriptor.layout, loc)

    // Allocate new bind group
    bind_group := device_new_handle(GL_Bind_Group_Impl, device, loc)

    if len(descriptor.label) > 0 {
        string_buffer_init(&bind_group.label, descriptor.label)
    }

    // Convert entries to GL-specific format
    if len(descriptor.entries) > 0 {
        bind_group.entries =
            make([]GL_Bind_Group_Entry, len(descriptor.entries), bind_group.allocator)

        for entry, i in descriptor.entries {
            gl_entry := &bind_group.entries[i]
            gl_entry.binding = entry.binding

            // Convert resource types
            switch &res in entry.resource {
            case Buffer_Binding:
                buffer := get_impl(GL_Buffer_Impl, Buffer(res.buffer), loc)
                gl_buffer_add_ref(Buffer(buffer), loc)
                gl_entry.resource = GL_Buffer_Binding{
                    buffer = buffer,
                    offset = res.offset,
                    size   = res.size,
                }

            case Sampler:
                sampler := get_impl(GL_Sampler_Impl, Sampler(res), loc)
                gl_sampler_add_ref(Sampler(sampler), loc)
                gl_entry.resource = GL_Sampler_Binding{
                    sampler = sampler,
                }

            case Texture_View:
                texture_view := get_impl(GL_Texture_View_Impl, Texture_View(res), loc)
                gl_texture_view_add_ref(Texture_View(texture_view), loc)
                gl_entry.resource = GL_Texture_View_Binding{
                    texture_view = texture_view,
                }

            case []Buffer_Binding:
                gl_buffers := make([]GL_Buffer_Binding, len(res), impl.allocator)
                for &buf, j in res {
                    buffer_impl := get_impl(GL_Buffer_Impl, Buffer(buf.buffer), loc)
                    gl_buffer_add_ref(Buffer(buffer_impl), loc)
                    gl_buffers[j] = GL_Buffer_Binding{
                        buffer = buffer_impl,
                        offset = buf.offset,
                        size   = buf.size,
                    }
                }
                gl_entry.resource = gl_buffers

            case []Sampler:
                gl_samplers := make([]GL_Sampler_Binding, len(res), impl.allocator)
                for sampler, j in res {
                    sampler_impl := get_impl(GL_Sampler_Impl, Sampler(sampler), loc)
                    gl_sampler_add_ref(Sampler(sampler_impl), loc)
                    gl_samplers[j] = GL_Sampler_Binding{
                        sampler = sampler_impl,
                    }
                }
                gl_entry.resource = gl_samplers

            case []Texture_View:
                gl_texture_views := make([]GL_Texture_View_Binding, len(res), impl.allocator)
                for view, j in res {
                    view_impl := get_impl(GL_Texture_View_Impl, Texture_View(view), loc)
                    gl_texture_view_add_ref(Texture_View(view_impl), loc)
                    gl_texture_views[j] = GL_Texture_View_Binding{
                        texture_view = view_impl,
                    }
                }
                gl_entry.resource = gl_texture_views
            }
        }

        // Sort entries by binding in ascending order
        slice.sort_by(bind_group.entries, proc(a, b: GL_Bind_Group_Entry) -> bool {
            return a.binding < b.binding
        })

        // Validate against layout
        assert(len(bind_group.entries) == len(layout_impl.entries),
            "Mismatched number of bind group entries", loc)
        for i in 0 ..< len(bind_group.entries) {
            assert(bind_group.entries[i].binding == layout_impl.entries[i].binding,
                "Mismatched bind group entry binding", loc)
        }
    }

    return Bind_Group(bind_group)
}

@(require_results)
gl_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    // impl := get_impl(GL_Device_Impl, device, loc)

    // Validate descriptor
    assert(descriptor.size > 0, "Buffer size must be greater than 0", loc)
    if descriptor.mapped_at_creation {
        assert(
            descriptor.size % COPY_BUFFER_ALIGNMENT == 0,
            "Mapped at creation buffers must have size aligned to COPY_BUFFER_ALIGNMENT",
            loc,
        )
    }

    handle: u32 = ---
    gl.CreateBuffers(1, &handle)

    // Allocate at least 4 bytes, aligned to 4 bytes for GL compatibility
    allocated_size := align(max(descriptor.size, GL_DEFAULT_BUFFER_SIZE), 4)

    storage_flags := gl_get_buffer_storage_flags(descriptor.usage, descriptor.mapped_at_creation)
    gl.NamedBufferStorage(handle, int(allocated_size), nil, storage_flags)

    buffer_impl := device_new_handle(GL_Buffer_Impl, device, loc)

    buffer_impl.handle             = handle
    buffer_impl.allocated_size     = allocated_size
    buffer_impl.size               = descriptor.size
    buffer_impl.usage              = descriptor.usage
    buffer_impl.map_state          = .Unmapped

    if descriptor.mapped_at_creation {
        // Map the buffer immediately with write access
        map_flags : u32 = gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_BUFFER_BIT

        // Persistent mapping
        if storage_flags & gl.MAP_PERSISTENT_BIT != 0 {
            map_flags |= gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT
        }

        buffer_impl.mapped_ptr = gl.MapNamedBufferRange(
            handle,
            0,
            int(allocated_size),
            map_flags,
        )
        assert(buffer_impl.mapped_ptr != nil, "Failed to map buffer at creation", loc)

        buffer_impl.map_state = .Mapped
        buffer_impl.mapped_range = { start = 0, end = descriptor.size }
    }

    return Buffer(buffer_impl)
}

@(require_results)
gl_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    impl := get_impl(GL_Device_Impl, device, loc)
    return Queue(impl.queue)
}

gl_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    impl := get_impl(GL_Device_Impl, device, loc)

    // Validate descriptor
    texture_descriptor_validade(descriptor, impl.features, loc)

    texture := device_new_handle(GL_Texture_Impl, device, loc)

    // Store descriptor info
    texture.size = descriptor.size
    texture.mip_level_count = descriptor.mip_level_count
    texture.sample_count = descriptor.sample_count
    texture.dimension = descriptor.dimension
    texture.format = descriptor.format
    texture.usage = descriptor.usage

    // Detect if this is a cubemap
    is_cubemap := descriptor.dimension == .D2 &&
                  descriptor.size.depth_or_array_layers >= 6 &&
                  descriptor.size.depth_or_array_layers % 6 == 0 &&
                  descriptor.size.width == descriptor.size.height

    // Convert to GL texture target
    if is_cubemap {
        texture.gl_target = descriptor.size.depth_or_array_layers == 6 ? \
                    gl.TEXTURE_CUBE_MAP : gl.TEXTURE_CUBE_MAP_ARRAY
    } else {
        texture.gl_target = gl_texture_dimension_to_target(
            descriptor.dimension,
            descriptor.sample_count,
            descriptor.size.depth_or_array_layers,
        )
    }

    // Get GL internal format
    gl_internal_format := GL_FORMAT_TABLE[descriptor.format].internal_format
    texture.gl_format = gl_internal_format

    // Create texture object
    gl.CreateTextures(texture.gl_target, 1, &texture.handle)
    assert(texture.handle != 0, "Failed to create GL texture", loc)

    // Allocate storage based on texture type
    width := i32(descriptor.size.width)
    height := i32(descriptor.size.height)
    depth := i32(descriptor.size.depth_or_array_layers)
    levels := i32(descriptor.mip_level_count)

    #partial switch descriptor.dimension {
    case .D1:
        if descriptor.size.depth_or_array_layers > 1 {
            // 1D Array
            gl.TextureStorage2D(
                texture.handle,
                levels,
                gl_internal_format,
                width,
                depth,  // layers
            )
        } else {
            // 1D
            gl.TextureStorage1D(
                texture.handle,
                levels,
                gl_internal_format,
                width,
            )
        }

    case .D2:
        if descriptor.sample_count > 1 {
            // 2D Multisample
            if descriptor.size.depth_or_array_layers > 1 {
                // 2D Multisample Array
                gl.TextureStorage3DMultisample(
                    texture.handle,
                    i32(descriptor.sample_count),
                    gl_internal_format,
                    width,
                    height,
                    depth,  // layers
                    gl.TRUE,  // fixed sample locations
                )
            } else {
                // 2D Multisample
                gl.TextureStorage2DMultisample(
                    texture.handle,
                    i32(descriptor.sample_count),
                    gl_internal_format,
                    width,
                    height,
                    gl.TRUE,  // fixed sample locations
                )
            }
        } else {
            // Regular 2D or Cubemap
            if is_cubemap {
                // Cubemap handling
                if descriptor.size.depth_or_array_layers == 6 {
                    // Regular cubemap - use TextureStorage2D
                    // The 6 faces are implicit in GL_TEXTURE_CUBE_MAP
                    gl.TextureStorage2D(
                        texture.handle,
                        levels,
                        gl_internal_format,
                        width,
                        height,
                    )
                } else {
                    // Cubemap array - use TextureStorage3D
                    gl.TextureStorage3D(
                        texture.handle,
                        levels,
                        gl_internal_format,
                        width,
                        height,
                        depth,  // 6 * num_cubemaps
                    )
                }
            } else if descriptor.size.depth_or_array_layers > 1 {
                // 2D Array
                gl.TextureStorage3D(
                    texture.handle,
                    levels,
                    gl_internal_format,
                    width,
                    height,
                    depth,  // layers
                )
            } else {
                // Single 2D texture
                if texture_format_has_depth_aspect(descriptor.format) {
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_BASE_LEVEL, 0)
                    gl.TextureParameteri(texture.handle, gl.TEXTURE_MAX_LEVEL, 0)
                }

                gl.TextureStorage2D(
                    texture.handle,
                    levels,
                    gl_internal_format,
                    width,
                    height,
                )
            }
        }

    case .D3:
        // 3D texture (no array support)
        assert(descriptor.sample_count == 1, "3D textures cannot be multisampled", loc)
        gl.TextureStorage3D(
            texture.handle,
            levels,
            gl_internal_format,
            width,
            height,
            depth,
        )

    case:
        unreachable()
    }

    // Set default texture parameters (can be overridden with samplers)
    if descriptor.sample_count == 1 {
        if is_cubemap {
            // Cubemap-specific parameters
            gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)

            // If using mipmaps, use linear mipmap filtering
            if descriptor.mip_level_count > 1 {
                gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
            }
        } else {
            // Regular texture parameters
            gl.TextureParameteri(texture.handle, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
            gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

            if descriptor.dimension == .D3 {
                gl.TextureParameteri(texture.handle, gl.TEXTURE_WRAP_R, gl.CLAMP_TO_EDGE)
            }
        }
    }

    // Set debug label if available
    if len(descriptor.label) > 0 {
        string_buffer_init(&texture.label, descriptor.label)
        label_cstr := string_buffer_get_cstring(&texture.label)
        gl.ObjectLabel(gl.TEXTURE, texture.handle, i32(len(label_cstr)), label_cstr)
    }

    return Texture(texture)
}

@(require_results)
gl_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    // impl := get_impl(GL_Device_Impl, device, loc)

    sampler_id: u32
    gl.CreateSamplers(1, &sampler_id)
    assert(sampler_id > 0, "Invalid Sampler ID", loc)

    // Convert filter modes to OpenGL constants
    min_filter := gl_get_min_filter(descriptor.min_filter, descriptor.mipmap_filter)
    mag_filter := gl_get_mag_filter(descriptor.mag_filter)

    // Set min and mag filters
    gl.SamplerParameteri(sampler_id, gl.TEXTURE_MIN_FILTER, min_filter)
    gl.SamplerParameteri(sampler_id, gl.TEXTURE_MAG_FILTER, mag_filter)

    // Set address modes
    gl.SamplerParameteri(
        sampler_id, gl.TEXTURE_WRAP_S, gl_get_address_mode(descriptor.address_mode_u))
    gl.SamplerParameteri(
        sampler_id, gl.TEXTURE_WRAP_T, gl_get_address_mode(descriptor.address_mode_v))
    gl.SamplerParameteri(
        sampler_id, gl.TEXTURE_WRAP_R, gl_get_address_mode(descriptor.address_mode_w))

    // Set LOD parameters
    gl.SamplerParameterf(sampler_id, gl.TEXTURE_MIN_LOD, descriptor.lod_min_clamp)
    gl.SamplerParameterf(sampler_id, gl.TEXTURE_MAX_LOD, descriptor.lod_max_clamp)

    // Set anisotropy if enabled
    if descriptor.max_anisotropy > 1 {
        gl.SamplerParameterf(
            sampler_id, gl.TEXTURE_MAX_ANISOTROPY, f32(descriptor.max_anisotropy))
    }

    // Set comparison mode if enabled
    if descriptor.compare != .Undefined {
        gl.SamplerParameteri(sampler_id, gl.TEXTURE_COMPARE_MODE, gl.COMPARE_REF_TO_TEXTURE)
        gl.SamplerParameteri(
            sampler_id, gl.TEXTURE_COMPARE_FUNC, gl_get_compare_function(descriptor.compare))
    } else {
        gl.SamplerParameteri(sampler_id, gl.TEXTURE_COMPARE_MODE, gl.NONE)
    }

    // Set border color if using clamp to border
    if descriptor.address_mode_u == .Clamp_To_Border ||
       descriptor.address_mode_v == .Clamp_To_Border ||
       descriptor.address_mode_w == .Clamp_To_Border {
        border_color := gl_get_border_color(descriptor.border_color)
        gl.SamplerParameterfv(sampler_id, gl.TEXTURE_BORDER_COLOR, &border_color[0])
    }

    sampler := device_new_handle(GL_Sampler_Impl, device, loc)
    sampler.handle = sampler_id

    return Sampler(sampler)
}

@(require_results)
gl_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder {
    impl := get_impl(GL_Device_Impl, device, loc)
    impl.encoder.encoding = true
    return Command_Encoder(impl.encoder)
}

@(require_results)
gl_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    impl := get_impl(GL_Device_Impl, device, loc)

    layout := device_new_handle(GL_Pipeline_Layout_Impl, device, loc)

    if len(descriptor.label) > 0 {
        string_buffer_init(&layout.label, descriptor.label)
    }

    // Store bind group layouts
    if len(descriptor.bind_group_layouts) > 0 {
        layout.group_layouts = make(
            []^GL_Bind_Group_Layout_Impl,
            len(descriptor.bind_group_layouts),
            impl.allocator,
        )

        for bg_layout, i in descriptor.bind_group_layouts {
            gl_bg_layout := get_impl(GL_Bind_Group_Layout_Impl, bg_layout, loc)
            layout.group_layouts[i] = gl_bg_layout
            gl_bind_group_layout_add_ref(bg_layout, loc)
        }
    }

    // Store push constant ranges
    if len(descriptor.push_constant_ranges) > 0 {
        layout.push_constants = make(
            []Push_Constant_Range,
            len(descriptor.push_constant_ranges),
            impl.allocator,
        )
        copy(layout.push_constants, descriptor.push_constant_ranges)
    }

    return Pipeline_Layout(layout)
}

@(require_results)
gl_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    impl := get_impl(GL_Device_Impl, device, loc)

    // Validate shader format, only GLSL supported
    assert(.Glsl in impl.shader_formats, "OpenGL backend requires GLSL shaders", loc)

    // Determine shader type and entry point
    shader_type: u32
    #partial switch descriptor.stage {
    case .Vertex:
        shader_type = gl.VERTEX_SHADER
    case .Fragment:
        shader_type = gl.FRAGMENT_SHADER
    case .Compute:
        shader_type = gl.COMPUTE_SHADER
    }

    assert(shader_type != 0, "Unsupported shader type", loc)

    // Create shader object
    handle := gl.CreateShader(shader_type)

    // Load GLSL shader
    {
        source := cstring(raw_data(descriptor.code))
        length := i32(len(source))
        gl.ShaderSource(handle, 1, &source, &length)
        gl.CompileShader(handle)
    }

    // // Load SPIR-V binary
    // {
    //     spirv_data := raw_data(descriptor.code)
    //     spirv_size := i32(len(descriptor.code))

    //     // Use glShaderBinary for SPIR-V
    //     gl.ShaderBinary(1, &handle, gl.SHADER_BINARY_FORMAT_SPIR_V, spirv_data, spirv_size)

    //     // Specialize the shader (required for SPIR-V)
    //     gl.SpecializeShader(handle, "main", 0, nil, nil)
    // }

    // Check compilation status
    success: i32 = ---
    gl.GetShaderiv(handle, gl.COMPILE_STATUS, &success)
    if success == 0 {
        // Get the actual info log length first
        length: i32
        gl.GetShaderiv(handle, gl.INFO_LOG_LENGTH, &length)

        // Get the info log
        actual_length: i32
        info_log: [GL_MAX_LOG_LENGTH]byte = ---
        gl.GetShaderInfoLog(handle, GL_MAX_LOG_LENGTH, &actual_length, raw_data(info_log[:]))

        // Make sure we don't exceed the buffer size
        actual_length = min(actual_length, GL_MAX_LOG_LENGTH)

        // Convert to string, trimming any trailing null terminators
        info_str := strings.trim_right(string(info_log[:actual_length]), "\x00")

        remove_last_newline :: proc(s: string) -> string {
            if len(s) > 0 && s[len(s) - 1] == '\n' {
                return s[:len(s) - 1]
            }
            return s
        }

        info_str = remove_last_newline(info_str)

        log.errorf("%s shader [%d]:\n  %s", descriptor.stage, handle, info_str)
    }

    assert(success != 0, "Invalid shader", loc)

    shader_module := device_new_handle(GL_Shader_Module_Impl, device, loc)
    shader_module.handle = handle

    // Set label
    if len(descriptor.label) > 0 {
        string_buffer_init(&shader_module.label, descriptor.label)
        label_cstr := string_buffer_get_cstring(&shader_module.label)
        gl.ObjectLabel(gl.SHADER, handle, i32(len(label_cstr)), label_cstr)
    }

    return Shader_Module(shader_module)
}

@(require_results)
gl_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    // device_impl := get_impl(GL_Device_Impl, device, loc)

    impl := device_new_handle(GL_Render_Pipeline_Impl, device, loc)

    assert(descriptor.vertex.module != nil, "Invalid vertex shader module", loc)
    vertex_shader_impl := get_impl(GL_Shader_Module_Impl, descriptor.vertex.module, loc)

    // Compile fragment shader if present
    fragment_shader_impl: ^GL_Shader_Module_Impl
    if descriptor.fragment != nil {
        fragment_shader_impl = get_impl(GL_Shader_Module_Impl, descriptor.fragment.module, loc)
    }

    // Store or create the pipeline
    if descriptor.layout != nil {
        impl.layout = get_impl(GL_Pipeline_Layout_Impl, descriptor.layout, loc)
        gl_pipeline_layout_add_ref(descriptor.layout, loc)
    }

    // Vertex State
    gl.CreateVertexArrays(1, &impl.vao)

    // Count total attributes
    attribute_count := 0
    for buffer_layout in descriptor.vertex.buffers {
        attribute_count += len(buffer_layout.attributes)
    }

    // Allocate attributes
    impl.attributes = make([]GL_Vertex_Attribute, attribute_count, impl.allocator)
    impl.buffer_attributes =
        make([][]GL_Vertex_Attribute, len(descriptor.vertex.buffers), impl.allocator)

    // Build attributes per buffer
    attr_idx := 0
    for buffer_layout, buffer_idx in descriptor.vertex.buffers {
        attributes_begin := attr_idx

        for attrib in buffer_layout.attributes {
            format_info := gl_get_vertex_format_info(attrib.format)

            location := u32(attrib.shader_location)

            impl.attributes[attr_idx] = GL_Vertex_Attribute{
                is_int      = format_info.is_integer,
                index       = location,
                count       = format_info.components,
                vertex_type = format_info.type,
                normalized  = format_info.normalized,
                stride      = i32(buffer_layout.array_stride),
                offset      = u32(attrib.offset),
            }

            // Enable attribute (done when setting a vertex buffer later)
            // gl.EnableVertexArrayAttrib(impl.vao, location)

            // Set format
            if format_info.is_integer {
                gl.VertexArrayAttribIFormat(
                    impl.vao,
                    location,
                    format_info.components,
                    format_info.type,
                    u32(attrib.offset),
                )
            } else {
                gl.VertexArrayAttribFormat(
                    impl.vao,
                    location,
                    format_info.components,
                    format_info.type,
                    format_info.normalized,
                    u32(attrib.offset),
                )
            }

            // Associate attribute with binding point
            gl.VertexArrayAttribBinding(impl.vao, location, u32(buffer_idx))

            // Set binding divisor for instancing
            divisor: u32 = buffer_layout.step_mode == .Instance ? 1 : 0
            gl.VertexArrayBindingDivisor(impl.vao, u32(buffer_idx), divisor)

            attr_idx += 1
        }

        impl.buffer_attributes[buffer_idx] = impl.attributes[attributes_begin:attr_idx]
    }

    // Primitive State
    impl.mode = gl_get_primitive_mode(descriptor.primitive.topology)
    impl.front_face = gl_get_front_face(descriptor.primitive.front_face)
    impl.cull_enabled = gl_get_cull_enabled(descriptor.primitive.cull_mode)
    if impl.cull_enabled {
        impl.cull_face = gl_get_cull_face(descriptor.primitive.cull_mode)
    }

    // Depth Stencil State
    if descriptor.depth_stencil != nil {
        depth_stencil := descriptor.depth_stencil

        impl.depth_test_enabled = gl_depth_test_enabled(depth_stencil)
        impl.depth_write_mask = depth_stencil.depth_write_enabled
        impl.depth_func = gl_get_compare_func(depth_stencil.depth_compare)

        impl.stencil_test_enabled = gl_stencil_test_enabled(depth_stencil)
        impl.stencil_read_mask = depth_stencil.stencil.read_mask & 0xff
        impl.stencil_write_mask = depth_stencil.stencil.write_mask & 0xff

        impl.stencil_back_compare_func = gl_get_compare_func(depth_stencil.stencil.back.compare)
        impl.stencil_back_fail_op = gl_get_stencil_op(depth_stencil.stencil.back.fail_op)
        impl.stencil_back_depth_fail_op =
            gl_get_stencil_op(depth_stencil.stencil.back.depth_fail_op)
        impl.stencil_back_pass_op = gl_get_stencil_op(depth_stencil.stencil.back.pass_op)

        impl.stencil_front_compare_func = gl_get_compare_func(depth_stencil.stencil.front.compare)
        impl.stencil_front_fail_op = gl_get_stencil_op(depth_stencil.stencil.front.fail_op)
        impl.stencil_front_depth_fail_op =
            gl_get_stencil_op(depth_stencil.stencil.front.depth_fail_op)
        impl.stencil_front_pass_op = gl_get_stencil_op(depth_stencil.stencil.front.pass_op)

        impl.polygon_offset_enabled = depth_stencil.bias.constant != 0
        impl.depth_bias = f32(depth_stencil.bias.constant)
        impl.depth_bias_slope_scale = depth_stencil.bias.slope_scale
        impl.depth_bias_clamp = depth_stencil.bias.clamp
    } else {
        impl.depth_test_enabled          = false
        impl.depth_write_mask            = false
        impl.depth_func                  = gl.LESS
        impl.stencil_test_enabled        = false
        impl.stencil_read_mask           = 0xff
        impl.stencil_write_mask          = 0xff
        impl.stencil_back_compare_func   = gl.ALWAYS
        impl.stencil_back_fail_op        = gl.KEEP
        impl.stencil_back_depth_fail_op  = gl.KEEP
        impl.stencil_back_pass_op        = gl.KEEP
        impl.stencil_front_compare_func  = gl.ALWAYS
        impl.stencil_front_fail_op       = gl.KEEP
        impl.stencil_front_depth_fail_op = gl.KEEP
        impl.stencil_front_pass_op       = gl.KEEP
        impl.polygon_offset_enabled      = false
        impl.depth_bias                  = 0.0
        impl.depth_bias_slope_scale      = 0.0
        impl.depth_bias_clamp            = 0.0
    }

    // Multisample State
    impl.multisample_enabled = descriptor.multisample.count > 1
    impl.sample_mask_enabled = descriptor.multisample.mask != max(u32)
    impl.sample_mask_value = descriptor.multisample.mask
    impl.alpha_to_coverage_enabled = descriptor.multisample.alpha_to_coverage_enabled

    // Fragment State
    target_count := 0
    if descriptor.fragment != nil {
        target_count = len(descriptor.fragment.targets)
    }

    impl.color_targets = make([]GL_Color_Target, target_count, impl.allocator)

    if descriptor.fragment != nil {
        for &target, i in descriptor.fragment.targets {
            color_target := GL_Color_Target{
                blend_enabled   = false,
                color_op        = gl.FUNC_ADD,
                alpha_op        = gl.FUNC_ADD,
                src_color_blend = gl.ONE,
                dst_color_blend = gl.ZERO,
                src_alpha_blend = gl.ONE,
                dst_alpha_blend = gl.ZERO,
                write_red       = .Red in target.write_mask,
                write_green     = .Green in target.write_mask,
                write_blue      = .Blue in target.write_mask,
                write_alpha     = .Alpha in target.write_mask,
            }

            if target.blend != nil {
                blend := target.blend
                color_target.blend_enabled = true
                color_target.color_op = gl_get_blend_op(blend.color.operation)
                color_target.alpha_op = gl_get_blend_op(blend.alpha.operation)
                color_target.src_color_blend = gl_get_blend_factor(blend.color.src_factor, true)
                color_target.dst_color_blend = gl_get_blend_factor(blend.color.dst_factor, true)
                color_target.src_alpha_blend = gl_get_blend_factor(blend.alpha.src_factor, false)
                color_target.dst_alpha_blend = gl_get_blend_factor(blend.alpha.dst_factor, false)
            }

            impl.color_targets[i] = color_target
        }
    }

    // Create and Link Program
    impl.program = gl.CreateProgram()

    gl.AttachShader(impl.program, vertex_shader_impl.handle)
    if fragment_shader_impl != nil {
        gl.AttachShader(impl.program, fragment_shader_impl.handle)
    }

    gl.LinkProgram(impl.program)

    // Check link status
    success: i32
    gl.GetProgramiv(impl.program, gl.LINK_STATUS, &success)
    if success == 0 {
        gl_handle_program_error(impl.program, "linking", loc)
    }

    // Validates a program object.
    gl.ValidateProgram(impl.program)
    gl.GetProgramiv(impl.program, gl.VALIDATE_STATUS, &success)
    if success == 0 {
        gl_handle_program_error(impl.program, "validation", loc)
    }

    // Detach shaders after linking
    gl.DetachShader(impl.program, vertex_shader_impl.handle)
    if fragment_shader_impl != nil {
        gl.DetachShader(impl.program, fragment_shader_impl.handle)
    }

    // Set debug label
    if len(descriptor.label) > 0 {
        string_buffer_init(&impl.label, descriptor.label)
        label_cstr := string_buffer_get_cstring(&impl.label)
        gl.ObjectLabel(gl.PROGRAM, impl.program, i32(len(label_cstr)), label_cstr)
        gl.ObjectLabel(gl.VERTEX_ARRAY, impl.vao, i32(len(label_cstr)), label_cstr)
    }

    return Render_Pipeline(impl)
}

@(require_results)
gl_device_get_features :: proc(device: Device, loc := #caller_location) -> Features {
    impl := get_impl(GL_Device_Impl, device, loc)
    return impl.features
}

@(require_results)
gl_device_get_limits :: proc(device: Device, loc := #caller_location) -> Limits {
    impl := get_impl(GL_Device_Impl, device, loc)
    return impl.limits
}

@(require_results)
gl_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    impl := get_impl(GL_Device_Impl, device, loc)
    return string_buffer_get_string(&impl.label)
}

gl_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    impl := get_impl(GL_Device_Impl, device, loc)
    string_buffer_init(&impl.label, label)
}

gl_device_add_ref :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(GL_Device_Impl, device, loc)
    ref_count_add(&impl.ref, loc)
}

gl_device_release :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(GL_Device_Impl, device, loc)

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        // Release pending maps
        pool_destroy(&impl.pending_maps)

        // Release default command allocator
        command_allocator_destroy(&impl.encoder.cmd_allocator, loc)
        free(impl.encoder, impl.encoder.allocator)
        free(impl.encoder.cmdbuf, impl.encoder.cmdbuf.allocator)

        // Release adapter for the current platform
        when ODIN_OS == .Windows {
            gl_win32_adapter_release(impl.adapter, loc)
        } else  when ODIN_OS == .Linux  {
            gl_linux_adapter_release(impl.adapter, loc)
        } else {
            unreachable()
        }

        // Release default command queue
        if impl.queue != nil {
            queue_impl := get_impl(GL_Queue_Impl, impl.queue, loc)
            free(queue_impl, queue_impl.allocator)
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Instance procedures
// -----------------------------------------------------------------------------


gl_instance_enumarate_adapters :: proc(
    instance: Instance,
    allocator := context.allocator,
    loc := #caller_location,
) -> []Adapter {
    Request_Adapter_Result :: struct {
        status:  Request_Adapter_Status,
        adapter: Adapter,
    }

    on_adpater_sync :: proc "c" (
        status: Request_Adapter_Status,
        adapter: Adapter,
        message: string,
        userdata1: rawptr,
        userdata2: rawptr,
    ) {
        res := cast(^Request_Adapter_Result)userdata1
        res.status = status
        res.adapter = adapter
    }

    adapter_res: Request_Adapter_Result
    adapter_callback_info := Request_Adapter_Callback_Info {
        callback  = on_adpater_sync,
        userdata1 = &adapter_res,
    }

    instance_request_adapter(instance, adapter_callback_info, nil)
    if (adapter_res.status != .Success) {
        return {}
    }

    // We always use one adapter in OpenGL
    adpaters := make([]^GL_Adapter_Impl, 1, allocator)
    adapter_impl := instance_new_handle(GL_Adapter_Impl, instance, loc)

    // Get features and limits
    adapter_impl.features = gl_adapter_get_features(Adapter(adapter_impl), loc)
    adapter_impl.limits = gl_adapter_get_limits(Adapter(adapter_impl), loc)

    adpaters[0] = adapter_impl

    return transmute([]Adapter)adpaters[:]
}

@(require_results)
gl_instance_get_label :: proc(instance: Instance, loc := #caller_location) -> string {
    impl := get_impl(GL_Instance_Impl, instance, loc)
    return string_buffer_get_string(&impl.label)
}

gl_instance_set_label :: proc(instance: Instance, label: string, loc := #caller_location) {
    impl := get_impl(GL_Instance_Impl, instance, loc)
    string_buffer_init(&impl.label, label)
}

gl_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    impl := get_impl(GL_Instance_Impl, instance, loc)
    ref_count_add(&impl.ref, loc)
}

// -----------------------------------------------------------------------------
// Pipeline Layout procedures
// -----------------------------------------------------------------------------


GL_Pipeline_Layout_Impl :: struct {
    using base:     Pipeline_Layout_Base,
    group_layouts:  []^GL_Bind_Group_Layout_Impl,
    push_constants: []Push_Constant_Range,
}

gl_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Pipeline_Layout_Impl, pipeline_layout, loc)
    return string_buffer_get_string(&impl.label)
}

gl_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Pipeline_Layout_Impl, pipeline_layout, loc)
    string_buffer_init(&impl.label, label)
}

gl_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(GL_Pipeline_Layout_Impl, pipeline_layout, loc)
    ref_count_add(&impl.ref, loc)
}

gl_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(GL_Pipeline_Layout_Impl, pipeline_layout, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        if len(impl.group_layouts) > 0 {
            for &bg_layout in impl.group_layouts {
                gl_bind_group_layout_release(Bind_Group_Layout(bg_layout), loc)
            }
            delete(impl.group_layouts)
        }
        if len(impl.push_constants) > 0 {
            delete(impl.push_constants)
        }
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Surface procedures
// -----------------------------------------------------------------------------


gl_surface_capabilities_free_members :: proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
) {
    context.allocator = allocator
    delete(caps.formats)
    delete(caps.present_modes)
    delete(caps.alpha_modes)
}

gl_surface_cleanup_resources :: proc(impl: ^GL_Surface_Impl, loc := #caller_location) {
    // Delete framebuffers
    framebuffers := sa.slice(&impl.framebuffers)
    for &fbo in framebuffers {
        gl.DeleteFramebuffers(1, &fbo)
    }

    // Delete textures
    textures := sa.slice(&impl.textures)
    for texture in textures {
        texture_impl := get_impl(GL_Texture_Impl, Texture(texture), loc)
        if texture_impl.handle != 0 {
            gl.DeleteTextures(1, &texture_impl.handle)
        }
    }

    // Clear views
    // TODO
}

gl_surface_configure :: proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    assert(config.width != 0, loc = loc)
    assert(config.height != 0, loc = loc)

    impl := get_impl(GL_Surface_Impl, surface, loc)

    impl.back_buffer_count = config.present_mode == .Mailbox ? 3 : 2
    impl.device = device
    impl.config = config
    impl.current_frame_index = 0

    // Clean up old resources if reconfiguring
    if sa.len(impl.textures) > 0 {
        gl_surface_cleanup_resources(impl)
    } else {
        // Otherwise, create initial resources
        for _ in 0 ..< impl.back_buffer_count {
            texture_impl := device_new_handle(GL_Texture_Impl, device, loc)
            sa.push_back(&impl.textures, texture_impl)

            view_impl := texture_new_handle(GL_Texture_View_Impl, Texture(texture_impl), loc)
            sa.push_back(&impl.views, view_impl)
        }

        gl_device_add_ref(device, loc)
    }

    for i in 0 ..< int(impl.back_buffer_count) {
        // Configure texture
        texture_impl := sa.get(impl.textures, i)
        texture_impl.handle          = 0
        texture_impl.surface         = surface
        texture_impl.usage           = config.usage
        texture_impl.dimension       = .D2
        texture_impl.size            = { config.width, config.height, 1 }
        texture_impl.format          = config.format
        texture_impl.mip_level_count = 1
        texture_impl.sample_count    = 1
        texture_impl.is_swapchain    = true
        texture_impl.gl_target       = gl.TEXTURE_2D

        // Create the actual OpenGL texture
        gl.CreateTextures(gl.TEXTURE_2D, 1, &texture_impl.handle)
        gl.TextureParameteri(texture_impl.handle, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
        gl.TextureParameteri(texture_impl.handle, gl.TEXTURE_MAG_FILTER, gl.LINEAR)
        gl.TextureParameteri(texture_impl.handle, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
        gl.TextureParameteri(texture_impl.handle, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)

        internal_format := GL_FORMAT_TABLE[texture_impl.format].internal_format
        gl.TextureStorage2D(
            texture        = texture_impl.handle,
            levels         = 1,
            internalformat = internal_format,
            width          = i32(config.width),
            height         = i32(config.height),
        )

        // Configure texture view
        texture_view_dimension := texture_dimension_compatible_texture_view_dimension(.D2, 1)
        view_descriptor := Texture_View_Descriptor {
            format            = texture_impl.format,
            dimension         = texture_view_dimension,
            usage             = texture_impl.usage,
            aspect            = .All,
            mip_level_count   = 1,
            array_layer_count = 1,
        }

        view_impl := sa.get(impl.views, i)
        view_impl.handle            = texture_impl.handle
        view_impl.format            = view_descriptor.format
        view_impl.dimension         = view_descriptor.dimension
        view_impl.usage             = view_descriptor.usage
        view_impl.is_swapchain      = true
        view_impl.texture           = Texture(texture_impl)
        view_impl.aspect            = .All
        view_impl.base_mip_level    = 0
        view_impl.mip_level_count   = 1
        view_impl.base_array_layer  = 0
        view_impl.array_layer_count = 1

        // Create framebuffer
        fbo: u32
        gl.CreateFramebuffers(1, &fbo)
        gl.NamedFramebufferTexture(
            fbo,
            gl.COLOR_ATTACHMENT0,
            texture_impl.handle,
            0,
        )

        // Set up draw/read buffers for the framebuffer
        gl.NamedFramebufferDrawBuffer(fbo, gl.COLOR_ATTACHMENT0)
        gl.NamedFramebufferReadBuffer(fbo, gl.COLOR_ATTACHMENT0)

        // Check framebuffer completeness
        status := gl.CheckNamedFramebufferStatus(fbo, gl.FRAMEBUFFER)
        assert(status == gl.FRAMEBUFFER_COMPLETE, "Framebuffer not complete", loc)

        sa.push_back(&impl.framebuffers, fbo)
    }
}

@(require_results)
gl_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    texture: Surface_Texture,
) {
    impl := get_impl(GL_Surface_Impl, surface, loc)

    // Textures and framebuffers are already created, just return current one
    current_index := impl.current_frame_index % impl.back_buffer_count
    texture_impl := sa.get(impl.textures, int(current_index))

    ref_count_add(&texture_impl.ref, loc)

    texture.status = .Success_Optimal
    texture.surface = surface
    texture.texture = Texture(texture_impl)

    return
}

gl_surface_present :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(GL_Surface_Impl, surface, loc)

    // Get current framebuffer
    current_index := impl.current_frame_index % impl.back_buffer_count
    fbo := impl.framebuffers.data[current_index]

    // Blit from custom framebuffer to default framebuffer
    gl.BlitNamedFramebuffer(
        fbo,
        0,
        0, 0,
        i32(impl.config.width),
        i32(impl.config.height),
        0, 0,
        i32(impl.config.width),
        i32(impl.config.height),
        gl.COLOR_BUFFER_BIT,
        gl.NEAREST,
    )

    // Advance to next frame
    impl.current_frame_index += 1

    // SwapBuffers
    when ODIN_OS == .Windows {
        gl_win32_surface_present(impl, loc)
    } else when ODIN_OS == .Linux {
        gl_linux_surface_present(impl, loc)
    } else {
        unreachable()
    }
}

@(require_results)
gl_surface_get_label :: proc(surface: Surface, loc := #caller_location) -> string {
    impl := get_impl(GL_Surface_Impl, surface, loc)
    return string_buffer_get_string(&impl.label)
}

gl_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    impl := get_impl(GL_Surface_Impl, surface, loc)
    string_buffer_init(&impl.label, label)
}

gl_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(GL_Surface_Impl, surface, loc)
    ref_count_add(&impl.ref, loc)
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------


GL_Queue_Impl :: struct {
    using base: Queue_Base,
}

gl_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    impl := get_impl(GL_Queue_Impl, queue, loc)

    // Process each command buffer in order
    for cmdbuf in commands {
        cmdbuf_impl := get_impl(GL_Command_Buffer_Impl, cmdbuf, loc)
        encoder_impl := get_impl(GL_Command_Encoder_Impl, cmdbuf_impl.encoder, loc)

        // Iterate through all commands in the allocator
        for &cmd in encoder_impl.cmd_allocator.data {
            gl_execute_command(impl, &cmd)
        }

        command_allocator_reset(&encoder_impl.cmd_allocator)
    }

    // Ensure all commands are executed
    gl.Flush()
}

gl_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    assert(queue != nil, "Invalid queue", loc)
    assert(buffer != nil, "Invalid buffer", loc)
    assert(data != nil, "Invalid data pointer", loc)
    assert(size > 0, "Size must be greater than 0", loc)

    buffer_impl := get_impl(GL_Buffer_Impl, buffer, loc)

    assert(buffer_offset + u64(size) <= buffer_impl.size,
           "Write would exceed buffer bounds", loc)
    assert(.Copy_Dst in buffer_impl.usage,
           "Buffer must have Copy_Dst usage flag", loc)

    // Orphan buffer if writing from the start - tells driver to allocate new storage
    if buffer_offset == 0 && size == uint(buffer_impl.size) {
        // Invalidate old buffer data
        gl.InvalidateBufferData(buffer_impl.handle)
    }

    gl.NamedBufferSubData(
        buffer_impl.handle,
        int(buffer_offset),
        int(size),
        data,
    )
}

gl_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    assert(destination.texture != nil, "Invalid destination texture", loc)

    texture_impl := get_impl(GL_Texture_Impl, destination.texture, loc)

    gl_format := GL_FORMAT_TABLE[texture_impl.format]

    // Offset into data
    data_ptr := rawptr(uintptr(raw_data(data)) + uintptr(data_layout.offset))

    x, y, z := expand_values(destination.origin)
    block_size := texture_format_block_copy_size(texture_impl.format, destination.aspect)
    block_width, block_height := texture_format_block_dimensions(texture_impl.format)

    if texture_format_is_compressed(texture_impl.format) {
        // Compressed texture upload
        row_size := write_size.width / block_width * block_size
        image_size := row_size * (write_size.height / block_height) *
                     write_size.depth_or_array_layers

        // Set compressed block parameters
        gl.PixelStorei(gl.UNPACK_ROW_LENGTH,
                      i32(data_layout.bytes_per_row / block_size * block_width))
        gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_SIZE, i32(block_size))
        gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_WIDTH, i32(block_width))
        gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_HEIGHT, i32(block_height))
        gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_DEPTH, 1)

        defer {
            // Reset compressed block parameters
            gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
            gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_SIZE, 0)
            gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_WIDTH, 0)
            gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_HEIGHT, 0)
            gl.PixelStorei(gl.UNPACK_COMPRESSED_BLOCK_DEPTH, 0)
        }

        switch texture_impl.gl_target {
        case gl.TEXTURE_2D:
            gl.CompressedTextureSubImage2D(
                texture_impl.handle,
                i32(destination.mip_level),
                i32(x), i32(y),
                i32(write_size.width), i32(write_size.height),
                gl_format.internal_format,
                i32(image_size),
                data_ptr,
            )

        case gl.TEXTURE_CUBE_MAP:
            pointer := ([^]u8)(data_ptr)
            base_layer := destination.origin.z
            for l in 0..<write_size.depth_or_array_layers {
                layer_offset := i32(base_layer + l)
                gl.CompressedTextureSubImage3D(
                    texture_impl.handle,
                    i32(destination.mip_level),
                    i32(x), i32(y), layer_offset,
                    i32(write_size.width), i32(write_size.height), 1,
                    gl_format.internal_format,
                    i32(image_size),
                    pointer,
                )
                pointer = pointer[data_layout.rows_per_image * data_layout.bytes_per_row:]
            }

        case gl.TEXTURE_3D, gl.TEXTURE_2D_ARRAY, gl.TEXTURE_CUBE_MAP_ARRAY:
            gl.PixelStorei(gl.UNPACK_IMAGE_HEIGHT,
                          i32(data_layout.rows_per_image * block_height))
            defer gl.PixelStorei(gl.UNPACK_IMAGE_HEIGHT, 0)
            gl.CompressedTextureSubImage3D(
                texture_impl.handle,
                i32(destination.mip_level),
                i32(x), i32(y), i32(z),
                i32(write_size.width), i32(write_size.height),
                i32(write_size.depth_or_array_layers),
                gl_format.internal_format,
                i32(image_size),
                data_ptr,
            )
        }
    } else {
        // Uncompressed texture upload
        width := write_size.width
        height := write_size.height

        // Set alignment (valid values: 1, 2, 4, 8)
        alignment := min(8, block_size)
        gl.PixelStorei(gl.UNPACK_ALIGNMENT, i32(alignment))
        gl.PixelStorei(gl.UNPACK_ROW_LENGTH,
                      i32(data_layout.bytes_per_row / block_size * block_width))

        defer {
            // Reset parameters
            gl.PixelStorei(gl.UNPACK_ROW_LENGTH, 0)
            gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)
        }

        switch texture_impl.gl_target {
        case gl.TEXTURE_2D:
            gl.TextureSubImage2D(
                texture_impl.handle,
                i32(destination.mip_level),
                i32(x), i32(y),
                i32(width), i32(height),
                gl_format.format,
                gl_format.type,
                data_ptr,
            )

        case gl.TEXTURE_CUBE_MAP:
            pointer := ([^]u8)(data_ptr)
            base_layer := destination.origin.z
            for l in 0..<write_size.depth_or_array_layers {
                layer_offset := i32(base_layer + l)
                gl.TextureSubImage3D(
                    texture_impl.handle,
                    i32(destination.mip_level),
                    i32(x), i32(y), layer_offset,
                    i32(width), i32(height), 1,
                    gl_format.format,
                    gl_format.type,
                    pointer,
                )
                pointer = pointer[data_layout.rows_per_image * data_layout.bytes_per_row:]
            }

        case gl.TEXTURE_3D, gl.TEXTURE_2D_ARRAY, gl.TEXTURE_CUBE_MAP_ARRAY:
            gl.PixelStorei(gl.UNPACK_IMAGE_HEIGHT,
                          i32(data_layout.rows_per_image * block_height))
            defer gl.PixelStorei(gl.UNPACK_IMAGE_HEIGHT, 0)
            gl.TextureSubImage3D(
                texture_impl.handle,
                i32(destination.mip_level),
                i32(x), i32(y), i32(z),
                i32(width), i32(height), i32(write_size.depth_or_array_layers),
                gl_format.format,
                gl_format.type,
                data_ptr,
            )
        }
    }
}

@(require_results)
gl_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    impl := get_impl(GL_Queue_Impl, queue, loc)
    return string_buffer_get_string(&impl.label)
}

gl_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    impl := get_impl(GL_Queue_Impl, queue, loc)
    string_buffer_init(&impl.label, label)
}

gl_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    impl := get_impl(GL_Queue_Impl, queue, loc)
    ref_count_add(&impl.ref, loc)
}

@(disabled = true)
gl_queue_release :: proc(queue: Queue, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------


GL_Sampler_Impl :: struct {
    // Base
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,

    // Backend
    handle:     u32,
}

@(require_results)
gl_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    impl := get_impl(GL_Sampler_Impl, sampler, loc)
    return string_buffer_get_string(&impl.label)
}

gl_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    impl := get_impl(GL_Sampler_Impl, sampler, loc)
    string_buffer_init(&impl.label, label)
}

gl_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(GL_Sampler_Impl, sampler, loc)
    ref_count_add(&impl.ref, loc)
}

gl_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(GL_Sampler_Impl, sampler, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Command Encoder
// -----------------------------------------------------------------------------

GL_Command_Allocator :: struct {
    using base: Command_Allocator,
    in_use:     bool,
}

GL_Command_Encoder_Impl :: struct {
    using base:    Command_Encoder_Base,
    cmd_allocator: GL_Command_Allocator,
    cmdbuf:        ^GL_Command_Buffer_Impl,
}

gl_command_encoder_begin_compute_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Maybe(Compute_Pass_Descriptor) = nil,
    loc := #caller_location,
) -> Compute_Pass {
    unimplemented()
}

gl_command_encoder_begin_render_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    assert(len(descriptor.color_attachments) > 0, "No color attachments", loc)

    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)

    cmd := command_allocator_allocate(&impl.cmd_allocator, Command_Begin_Render_Pass)
    assert(cmd != nil)

    // Copy color attachments
    sa.resize(&cmd.color_attachments, len(descriptor.color_attachments))
    for color_att, i in descriptor.color_attachments {
        sa.set(&cmd.color_attachments, i, color_att)
    }

    // Copy depth stencil attachment if present
    if descriptor.depth_stencil_attachment != nil {
        cmd.depth_stencil_attachment = descriptor.depth_stencil_attachment^
    }

    // Create render pass wrapper
    rpass_impl := command_encoder_new_handle(GL_Render_Pass_Impl, encoder, loc)
    rpass_impl.encoding = true

    color0 := sa.get(cmd.color_attachments, 0)
    view_impl := get_impl(GL_Texture_View_Impl, color0.view, loc)
    texture_impl := get_impl(GL_Texture_Impl, view_impl.texture, loc)
    cmd.width = texture_impl.size.width
    cmd.height = texture_impl.size.height

    return Render_Pass(rpass_impl)
}

gl_command_encoder_clear_buffer :: proc(
    encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_ommand_encoder_resolve_query_set :: proc(
    encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_command_encoder_write_timestamp :: proc(
    encoder: Command_Encoder,
    querySet: Query_Set,
    queryIndex: u32,
    loc := #caller_location,
) {
    unimplemented()
}

gl_command_encoder_copy_buffer_to_buffer :: proc(
    encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_command_encoder_copy_buffer_to_texture :: proc(
    encoder: Command_Encoder,
    source: Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

gl_command_encoder_copy_texture_to_buffer :: proc(
    encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

gl_command_encoder_copy_texture_to_texture :: proc(
    encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    cmd := command_allocator_allocate(&impl.cmd_allocator, Command_Copy_Texture_To_Texture)
    cmd.source = source
    cmd.destination = destination
    cmd.copy_size = copy_size
}

gl_command_encoder_finish :: proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    impl.encoding = false
    return Command_Buffer(impl.cmdbuf)
}

@(require_results)
gl_command_encoder_get_label :: proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    return string_buffer_get_string(&impl.label)
}

gl_command_encoder_set_label :: proc(
    encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    string_buffer_init(&impl.label, label)
}

gl_command_encoder_add_ref :: proc(encoder: Command_Encoder, loc := #caller_location) {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    ref_count_add(&impl.ref, loc)
}

gl_command_encoder_release :: proc(encoder: Command_Encoder, loc := #caller_location) {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    assert(impl.encoding == false, "Command encoder still encoding", loc)
    // if release := ref_count_sub(&impl.ref, loc); release {
    //     gl_device_release(impl.device, loc)
    // }
}

// -----------------------------------------------------------------------------
// Compute Pass procedures
// -----------------------------------------------------------------------------

gl_compute_pass_dispatch_workgroups :: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_dispatch_workgroups_indirect :: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_end :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    unimplemented()
}

gl_compute_pass_insert_debug_marker :: proc(
    compute_pass: Compute_Pass,
    markerLabel: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_pop_debug_group :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    unimplemented()
}

gl_compute_pass_push_debug_group :: proc(
    compute_pass: Compute_Pass,
    groupLabel: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_set_bind_group :: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_set_pipeline :: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_get_label :: proc(compute_pass: Compute_Pass, loc := #caller_location) -> string {
    unimplemented()
}

gl_compute_pass_set_label :: proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pass_add_ref :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    unimplemented()
}

gl_compute_pass_release :: proc(compute_pass: Compute_Pass, loc := #caller_location) {
    unimplemented()
}

// -----------------------------------------------------------------------------
// Compute Pipeline procesures
// -----------------------------------------------------------------------------

gl_compute_pipeline_get_bind_group_layout :: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented()
}

gl_compute_pipeline_get_label :: proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) -> string {
    unimplemented()
}

gl_compute_pipeline_set_label :: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pipeline_add_ref :: proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    unimplemented()
}

gl_compute_pipeline_release :: proc(
    compute_pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    unimplemented()
}

// -----------------------------------------------------------------------------
// Texture procedures
// -----------------------------------------------------------------------------


GL_Texture_Impl :: struct {
    // Base
    label:           String_Buffer_Small,
    ref:             Ref_Count,
    device:          Device,
    allocator:       runtime.Allocator,
    usage:           Texture_Usages,
    dimension:       Texture_Dimension,
    size:            Extent_3D,
    format:          Texture_Format,
    mip_level_count: u32,
    sample_count:    u32,
    is_swapchain:    bool,

    // Backend
    handle:          u32,
    surface:         Surface,
    gl_target:       u32,
    gl_format:       u32,
}

@(require_results)
gl_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View {
    impl := get_impl(GL_Texture_Impl, texture, loc)

    if impl.is_swapchain {
        surface_impl := get_impl(GL_Surface_Impl, impl.surface, loc)
        current_index := surface_impl.current_frame_index % surface_impl.back_buffer_count
        view_impl := sa.get(surface_impl.views, int(current_index))
        gl_texture_add_ref(texture, loc)
        gl_texture_view_add_ref(Texture_View(view_impl), loc)
        return Texture_View(view_impl)
    } else {
        view_impl := texture_new_handle(GL_Texture_View_Impl, texture, loc)

        view_impl.format = descriptor.format
        view_impl.dimension = descriptor.dimension
        view_impl.usage = descriptor.usage
        view_impl.aspect = descriptor.aspect
        view_impl.base_mip_level = descriptor.base_mip_level
        view_impl.mip_level_count = descriptor.mip_level_count
        view_impl.base_array_layer = descriptor.base_array_layer
        view_impl.array_layer_count = descriptor.array_layer_count

        if len(descriptor.label) > 0 {
            string_buffer_init(&view_impl.label, descriptor.label)
        }

        return Texture_View(view_impl)
    }
}

@(require_results)
gl_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.usage
}

@(require_results)
gl_texture_get_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Dimension {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.dimension
}

@(require_results)
gl_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.size
}

@(require_results)
gl_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.size.width
}

@(require_results)
gl_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.size.height
}

@(require_results)
gl_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.format
}

@(require_results)
gl_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.mip_level_count
}

@(require_results)
gl_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return impl.sample_count
}

@(require_results)
gl_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    desc: Texture_Descriptor
    // label
    desc.usage = impl.usage
    desc.dimension = impl.dimension
    desc.size = impl.size
    desc.size = impl.size
    desc.format = impl.format
    desc.mip_level_count = impl.mip_level_count
    desc.sample_count = impl.sample_count
    // view_formats
    return desc
}

@(require_results)
gl_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    return string_buffer_get_string(&impl.label)
}

gl_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    string_buffer_init(&impl.label, label)
}

gl_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    ref_count_add(&impl.ref, loc)
}

gl_texture_release :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(GL_Texture_Impl, texture, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        if !impl.is_swapchain {
            free(impl)
        }
    }
}

// -----------------------------------------------------------------------------
// Texture View procedures
// -----------------------------------------------------------------------------


GL_Texture_View_Impl :: struct {
    // Base
    label:             String_Buffer_Small,
    ref:               Ref_Count,
    device:            Device,
    texture:           Texture,
    allocator:         runtime.Allocator,
    format:            Texture_Format,
    dimension:         Texture_View_Dimension,
    usage:             Texture_Usages,
    aspect:            Texture_Aspect,
    base_mip_level:    u32,
    mip_level_count:   u32,
    base_array_layer:  u32,
    array_layer_count: u32,
    is_swapchain:      bool,

    // Backend
    handle:            u32,
}

@(require_results)
gl_texture_view_get_label :: proc(texture_view: Texture_View, loc := #caller_location) -> string {
    impl := get_impl(GL_Texture_View_Impl, texture_view, loc)
    return string_buffer_get_string(&impl.label)
}

gl_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Texture_View_Impl, texture_view, loc)
    string_buffer_init(&impl.label, label)
}

gl_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := get_impl(GL_Texture_View_Impl, texture_view, loc)
    ref_count_add(&impl.ref, loc)
}

gl_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := get_impl(GL_Texture_View_Impl, texture_view, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        gl_texture_release(impl.texture, loc)
        if !impl.is_swapchain {
            free(impl)
        }
    }
}

// -----------------------------------------------------------------------------
// Render Pass procedures
// -----------------------------------------------------------------------------


GL_Render_Pass_Impl :: struct {
    // Base
    label:                  String_Buffer_Small,
    ref:                    Ref_Count,
    device:                 Device,
    encoder:                Command_Encoder,
    allocator:              runtime.Allocator,
    encoding:               bool,

    // Backend
    pipeline:               Render_Pipeline,
    enabled_vertex_buffers: bit_set[0 ..< u32(MAX_VERTEX_BUFFERS); u32],
    index_buffer:           u32,
    index_type:             u32,
    index_offset:           u64,
}

gl_render_pass_begin_occlusion_query :: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Scissor_Rect)
    assert(cmd != nil)

    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
}

gl_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Viewport)
    assert(cmd != nil)

    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
    cmd.min_depth = min_depth
    cmd.max_depth = max_depth
}

gl_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Stencil_Reference)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.reference = reference
}

gl_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Draw)
    assert(cmd != nil, loc = loc)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.vertex_count = vertices.end - vertices.start
    cmd.instance_count = instances.end - instances.start
    cmd.first_vertex = vertices.start
    cmd.first_instance = instances.start
}

gl_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Draw_Indexed)
    assert(cmd != nil, loc = loc)

    cmd.render_pass = render_pass
    cmd.index_count = indices.end - indices.start
    cmd.instance_count = instances.end - instances.start
    cmd.first_index = indices.start
    cmd.vertex_offset = base_vertex
    cmd.first_instance = instances.start
}

gl_render_pass_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_draw_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_end_occlusion_query :: proc(render_pass: Render_Pass, loc := #caller_location) {
    unimplemented()
}

gl_render_pass_execute_bundles :: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_insert_debug_marker :: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_pop_debug_group :: proc(render_pass: Render_Pass, loc := #caller_location) {
    unimplemented()
}

gl_render_pass_push_debug_group :: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented()
}

gl_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
) {
    assert(group != nil, "Invalid bind group", loc)
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Bind_Group)
    cmd.render_pass = render_pass
    cmd.group_index = group_index
    cmd.group = group
    if len(dynamic_offsets) > 0 {
        cmd.dynamic_offsets =
            make([]u32, len(dynamic_offsets), encoder_impl.cmd_allocator.allocator)
        copy(cmd.dynamic_offsets, dynamic_offsets)
    }

    assert(cmd != nil, loc = loc)
}

gl_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    assert(pipeline != nil, "Invalid render pipeline", loc)
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    impl.pipeline = pipeline
    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Render_Pipeline)
    cmd.render_pass = render_pass
    cmd.pipeline = pipeline
    assert(cmd != nil)
}

gl_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid vertex buffer", loc)
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    assert(impl.pipeline != nil, "No Render Pipeline is bound", loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Vertex_Buffer)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.slot = slot
    cmd.buffer = buffer
    cmd.offset = offset
    cmd.size = size
}

gl_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid index buffer", loc)
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    assert(impl.pipeline != nil, "No Render Pipeline is bound", loc)

    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Index_Buffer)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.buffer = buffer
    cmd.format = format
    cmd.offset = offset
    cmd.size = size
}

gl_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    impl.encoding = false
    encoder_impl := get_impl(GL_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(&encoder_impl.cmd_allocator, Command_Render_Pass_End, loc)
    cmd.render_pass = render_pass
    assert(cmd != nil, loc = loc)
}

@(require_results)
gl_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    return string_buffer_get_string(&impl.label)
}

gl_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    string_buffer_init(&impl.label, label)
}

gl_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    ref_count_add(&impl.ref, loc)
}

gl_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(GL_Render_Pass_Impl, render_pass, loc)
    assert(impl.encoding == false, "Render pass encoder still recording", loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Command Buffer
// -----------------------------------------------------------------------------

GL_Command_Buffer_Impl :: struct {
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    encoder:   Command_Encoder,
    allocator: runtime.Allocator,
}

@(require_results)
gl_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Command_Buffer_Impl, command_buffer, loc)
    return string_buffer_get_string(&impl.label)
}

gl_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Command_Buffer_Impl, command_buffer, loc)
    string_buffer_init(&impl.label, label)
}

gl_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    impl := get_impl(GL_Command_Buffer_Impl, command_buffer, loc)
    ref_count_add(&impl.ref, loc)
}

gl_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    // impl := get_impl(GL_Command_Buffer_Impl, command_buffer, loc)
    // if release := ref_count_sub(&impl.ref, loc); release {
    //     gl_command_encoder_release(impl.encoder, loc)
    // }
}

// -----------------------------------------------------------------------------
// Render Bundle procedures
// -----------------------------------------------------------------------------


GL_Render_Bundle_Impl :: struct {
    // Base
    label:  String_Buffer_Small,
    ref:    Ref_Count,
    device: Device,
    allocator:       runtime.Allocator,

    // Backend
    handle: u32,
}

@(require_results)
gl_render_bundle_get_label :: proc(
    render_bundle: Render_Bundle,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Render_Bundle_Impl, render_bundle, loc)
    return string_buffer_get_string(&impl.label)
}

gl_render_bundle_set_label :: proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Bundle_Impl, render_bundle, loc)
    string_buffer_init(&impl.label, label)
}

gl_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    impl := get_impl(GL_Render_Bundle_Impl, render_bundle, loc)
    ref_count_add(&impl.ref, loc)
}

gl_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    impl := get_impl(GL_Render_Bundle_Impl, render_bundle, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------


GL_Shader_Module_Impl :: struct {
    // Base
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    allocator: runtime.Allocator,

    // Backend
    handle:    u32,
}

@(require_results)
gl_shader_module_get_label :: proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Shader_Module_Impl, shader_module, loc)
    return string_buffer_get_string(&impl.label)
}

gl_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Shader_Module_Impl, shader_module, loc)
    string_buffer_init(&impl.label, label)
}

gl_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(GL_Shader_Module_Impl, shader_module, loc)
    ref_count_add(&impl.ref, loc)
}

gl_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(GL_Shader_Module_Impl, shader_module, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------


GL_Vertex_Attribute :: struct {
    is_int:      bool,
    index:       u32,
    count:       i32,
    vertex_type: u32,
    normalized:  bool,
    stride:      i32,
    offset:      u32,
}

GL_Color_Target :: struct {
    blend_enabled:    bool,
    color_op:         u32,
    alpha_op:         u32,
    src_color_blend:  u32,
    dst_color_blend:  u32,
    src_alpha_blend:  u32,
    dst_alpha_blend:  u32,
    write_red:        bool,
    write_green:      bool,
    write_blue:       bool,
    write_alpha:      bool,
}

GL_Render_Pipeline_Impl :: struct {
    // Base
    label:                       String_Buffer_Small,
    ref:                         Ref_Count,
    device:                      Device,
    allocator:                   runtime.Allocator,

    // Backend
    program:                     u32,
    vao:                         u32,

    // Layout
    layout:                      ^GL_Pipeline_Layout_Impl,

    // Vertex attributes organized by buffer
    attributes:                  []GL_Vertex_Attribute,
    buffer_attributes:           [][]GL_Vertex_Attribute,

    // Primitive state
    mode:                        u32, // GL topology
    front_face:                  u32,
    cull_enabled:                bool,
    cull_face:                   u32,

    // Depth state
    depth_test_enabled:          bool,
    depth_write_mask:            bool,
    depth_func:                  u32,

    // Stencil state
    stencil_test_enabled:        bool,
    stencil_read_mask:           u32,
    stencil_write_mask:          u32,
    stencil_back_compare_func:   u32,
    stencil_back_fail_op:        u32,
    stencil_back_depth_fail_op:  u32,
    stencil_back_pass_op:        u32,
    stencil_front_compare_func:  u32,
    stencil_front_fail_op:       u32,
    stencil_front_depth_fail_op: u32,
    stencil_front_pass_op:       u32,

    // Depth bias (polygon offset)
    polygon_offset_enabled:      bool,
    depth_bias:                  f32,
    depth_bias_slope_scale:      f32,
    depth_bias_clamp:            f32,

    // Multisample state
    multisample_enabled:         bool,
    sample_mask_enabled:         bool,
    sample_mask_value:           u32,
    alpha_to_coverage_enabled:   bool,

    // Color targets blend state
    color_targets:               []GL_Color_Target,
}

@(require_results)
gl_render_pipeline_get_bind_group_layout :: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := get_impl(GL_Render_Pipeline_Impl, render_pipeline, loc)
    group_layout := impl.layout.group_layouts[group_index]
    gl_bind_group_layout_add_ref(Bind_Group_Layout(group_layout), loc)
    return Bind_Group_Layout(group_layout)
}

@(require_results)
gl_render_pipeline_get_label :: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string {
    impl := get_impl(GL_Render_Pipeline_Impl, render_pipeline, loc)
    return string_buffer_get_string(&impl.label)
}

gl_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(GL_Render_Pipeline_Impl, render_pipeline, loc)
    string_buffer_init(&impl.label, label)
}

gl_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(GL_Render_Pipeline_Impl, render_pipeline, loc)
    ref_count_add(&impl.ref, loc)
}

gl_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(GL_Render_Pipeline_Impl, render_pipeline, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.layout != nil {
            gl_pipeline_layout_release(Pipeline_Layout(impl.layout), loc)
        }

        if impl.program != 0 {
            gl.DeleteProgram(impl.program)
        }

        if impl.vao != 0 {
            gl.DeleteVertexArrays(1, &impl.vao)
        }

        delete(impl.attributes)
        delete(impl.buffer_attributes)
        delete(impl.color_targets)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Utils
// -----------------------------------------------------------------------------

// Check if an OpenGL extension is supported.
@(require_results)
gl_check_extension_support :: proc(extension: cstring) -> bool {
    num_extensions: i32
    gl.GetIntegerv(gl.NUM_EXTENSIONS, &num_extensions)

    for i in 0..< num_extensions {
        ext := gl.GetStringi(gl.EXTENSIONS, u32(i))
        if ext == extension {
            return true
        }
    }

    return false
}

// Helper procedure to handle program errors (linking or validation).
gl_handle_program_error :: proc(
    program: u32,
    error_type: string,
    loc: runtime.Source_Code_Location,
) -> ! {
    // Get the info log
    actual_length: i32
    info_log: [GL_MAX_LOG_LENGTH]byte = ---
    gl.GetProgramInfoLog(program, GL_MAX_LOG_LENGTH, &actual_length, raw_data(info_log[:]))

    // Make sure we don't exceed the buffer size
    actual_length = min(actual_length, GL_MAX_LOG_LENGTH)

    // Convert to string, trimming any trailing null terminators
    info_str := strings.trim_right(string(info_log[:actual_length]), "\x00")

    remove_last_newline :: proc(s: string) -> string {
        if len(s) > 0 && s[len(s) - 1] == '\n' {
            return s[:len(s) - 1]
        }
        return s
    }

    info_str = remove_last_newline(info_str)

    log.errorf("Program %s error [%d]:\n   %s", error_type, program, info_str)
    panic("Program error", loc)
}

gl_message_callback :: proc "c" (
    source: u32,
    type: u32,
    id: u32,
    severity: u32,
    length: i32,
    message: cstring,
    userParam: rawptr,
) {
    instance := get_impl(GL_Instance_Impl, cast(Instance)userParam, {})
    context = instance.ctx

    // ignore non-significant error/warning codes
    if id == 131169 || id == 131185 || id == 131218 || id == 131204 {
        return
    }

    source_str := ""
    switch source {
    case gl.DEBUG_SOURCE_API:
        source_str = "Source: API"
    case gl.DEBUG_SOURCE_WINDOW_SYSTEM:
        source_str = "Source: Window System"
    case gl.DEBUG_SOURCE_SHADER_COMPILER:
        source_str = "Source: Shader Compiler"
    case gl.DEBUG_SOURCE_THIRD_PARTY:
        source_str = "Source: Third Party"
    case gl.DEBUG_SOURCE_APPLICATION:
        source_str = "Source: Application"
    case gl.DEBUG_SOURCE_OTHER:
        source_str = "Source: Other"
    }

    type_str := ""
    switch type {
    case gl.DEBUG_TYPE_ERROR:
        type_str = "Type: Error"
    case gl.DEBUG_TYPE_DEPRECATED_BEHAVIOR:
        type_str = "Type: Deprecated Behaviour"
    case gl.DEBUG_TYPE_UNDEFINED_BEHAVIOR:
        type_str = "Type: Undefined Behaviour"
    case gl.DEBUG_TYPE_PORTABILITY:
        type_str = "Type: Portability"
    case gl.DEBUG_TYPE_PERFORMANCE:
        type_str = "Type: Performance"
    case gl.DEBUG_TYPE_MARKER:
        type_str = "Type: Marker"
    case gl.DEBUG_TYPE_PUSH_GROUP:
        type_str = "Type: Push Group"
    case gl.DEBUG_TYPE_POP_GROUP:
        type_str = "Type: Pop Group"
    case gl.DEBUG_TYPE_OTHER:
        type_str = "Type: Other"
    }

    severity_str := ""
    switch severity {
    case gl.DEBUG_SEVERITY_HIGH:
        severity_str = "Severity: high"
    case gl.DEBUG_SEVERITY_MEDIUM:
        severity_str = "Severity: medium"
    case gl.DEBUG_SEVERITY_LOW:
        severity_str = "Severity: low"
    case gl.DEBUG_SEVERITY_NOTIFICATION:
        severity_str = "Severity: notification"
    }

    if type == gl.DEBUG_TYPE_ERROR {
        log.errorf(
            "[%d]: %s\n" + "   %s, " + "%s, " + "%s",
            id,
            string(message),
            source_str,
            type_str,
            severity_str,
        )
        runtime.debug_trap()
    } else {
        log.debugf(
            "[%d]: %s\n" + "   %s, " + "%s, " + "%s",
            id,
            string(message),
            source_str,
            type_str,
            severity_str,
        )
    }
}
