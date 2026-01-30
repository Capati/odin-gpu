#+build js
package gpu

/*
NOTE: All casts/transmutes are guaranteed to be compatible across wgpu bindings.
*/

// Core
import "base:runtime"
import "core:log"
import "core:slice"
import "core:strings"
import sa "core:container/small_array"

// Vendor
import "vendor:wgpu"

wgpu_init :: proc(allocator := context.allocator) {
    // Global procedures
    create_instance_impl                    = wgpu_create_instance

    // Adapter procedures
    adapter_get_info                        = wgpu_adapter_get_info
    adapter_info_free_members               = wgpu_adapter_info_free_members
    adapter_get_features                    = wgpu_adapter_get_features
    adapter_has_feature                     = wgpu_adapter_has_feature
    adapter_get_limits                      = wgpu_adapter_get_limits
    adapter_request_device                  = wgpu_adapter_request_device
    adapter_get_texture_format_capabilities = wgpu_adapter_get_texture_format_capabilities
    adapter_get_label                       = wgpu_adapter_get_label
    adapter_set_label                       = wgpu_adapter_set_label
    adapter_add_ref                         = wgpu_adapter_add_ref
    adapter_release                         = wgpu_adapter_release

    // Bind Group procedures
    bind_group_get_label                    = wgpu_bind_group_get_label
    bind_group_set_label                    = wgpu_bind_group_set_label
    bind_group_add_ref                      = wgpu_bind_group_add_ref
    bind_group_release                      = wgpu_bind_group_release

    // Bind Group Layout procedures
    bind_group_layout_get_label             = wgpu_bind_group_layout_get_label
    bind_group_layout_set_label             = wgpu_bind_group_layout_set_label
    bind_group_layout_add_ref               = wgpu_bind_group_layout_add_ref
    bind_group_layout_release               = wgpu_bind_group_layout_release

    // Buffer procedures
    buffer_destroy                          = wgpu_buffer_destroy
    buffer_unmap                            = wgpu_buffer_unmap
    buffer_get_map_state                    = wgpu_buffer_get_map_state
    buffer_get_size                         = wgpu_buffer_get_size
    buffer_get_usage                        = wgpu_buffer_get_usage
    buffer_map_async                        = wgpu_buffer_map_async
    buffer_set_label                        = wgpu_buffer_set_label
    buffer_get_label                        = wgpu_buffer_get_label
    buffer_add_ref                          = wgpu_buffer_add_ref
    buffer_release                          = wgpu_buffer_release

    // Command Encoder procedures
    command_buffer_get_label                = wgpu_command_buffer_get_label
    command_buffer_set_label                = wgpu_command_buffer_set_label
    command_buffer_add_ref                  = wgpu_command_buffer_add_ref
    command_buffer_release                  = wgpu_command_buffer_release

    // Command Encoder procedures
    command_encoder_begin_compute_pass      = wgpu_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass       = wgpu_command_encoder_begin_render_pass
    command_encoder_copy_texture_to_texture = wgpu_command_encoder_copy_texture_to_texture
    command_encoder_finish                  = wgpu_command_encoder_finish
    command_encoder_clear_buffer            = wgpu_command_encoder_clear_buffer
    command_encoder_resolve_query_set       = wgpu_command_encoder_resolve_query_set
    command_encoder_write_timestamp         = wgpu_command_encoder_write_timestamp
    command_encoder_copy_buffer_to_buffer   = wgpu_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture  = wgpu_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer  = wgpu_command_encoder_copy_texture_to_buffer
    command_encoder_get_label               = wgpu_command_encoder_get_label
    command_encoder_set_label               = wgpu_command_encoder_set_label
    command_encoder_add_ref                 = wgpu_command_encoder_add_ref
    command_encoder_release                 = wgpu_command_encoder_release

    // Device procedures
    device_create_bind_group                = wgpu_device_create_bind_group
    device_create_bind_group_layout         = wgpu_device_create_bind_group_layout
    device_create_pipeline_layout           = wgpu_device_create_pipeline_layout
    device_create_buffer                    = wgpu_device_create_buffer
    device_create_sampler                   = wgpu_device_create_sampler
    device_create_shader_module             = wgpu_device_create_shader_module
    device_create_texture                   = wgpu_device_create_texture
    device_create_command_encoder           = wgpu_device_create_command_encoder
    device_create_render_pipeline           = wgpu_device_create_render_pipeline
    device_get_queue                        = wgpu_device_get_queue
    device_get_features                     = wgpu_device_get_features
    device_get_label                        = wgpu_device_get_label
    device_set_label                        = wgpu_device_set_label
    device_add_ref                          = wgpu_device_add_ref
    device_release                          = wgpu_device_release

    // // Instance procedures
    instance_create_surface                 = wgpu_instance_create_surface
    instance_request_adapter                = wgpu_instance_request_adapter
    instance_get_label                      = wgpu_instance_get_label
    instance_set_label                      = wgpu_instance_set_label
    instance_add_ref                        = wgpu_instance_add_ref
    instance_release                        = wgpu_instance_release

    // Pipeline Layout procedures
    pipeline_layout_get_label               = wgpu_pipeline_layout_get_label
    pipeline_layout_set_label               = wgpu_pipeline_layout_set_label
    pipeline_layout_add_ref                 = wgpu_pipeline_layout_add_ref
    pipeline_layout_release                 = wgpu_pipeline_layout_release

    // Queue procedures
    queue_submit                            = wgpu_queue_submit
    queue_write_buffer_impl                 = wgpu_queue_write_buffer
    queue_write_texture                     = wgpu_queue_write_texture
    queue_get_label                         = wgpu_queue_get_label
    queue_set_label                         = wgpu_queue_set_label
    queue_add_ref                           = wgpu_queue_add_ref
    queue_release                           = wgpu_queue_release

    // Render Pass procedures
    render_pass_set_pipeline                = wgpu_render_pass_set_pipeline
    render_pass_set_bind_group              = wgpu_render_pass_set_bind_group
    render_pass_set_vertex_buffer           = wgpu_render_pass_set_vertex_buffer
    render_pass_set_index_buffer            = wgpu_render_pass_set_index_buffer
    render_pass_set_stencil_reference       = wgpu_render_pass_set_stencil_reference
    render_pass_draw                        = wgpu_render_pass_draw
    render_pass_draw_indexed                = wgpu_render_pass_draw_indexed
    render_pass_set_scissor_rect            = wgpu_render_pass_set_scissor_rect
    render_pass_set_viewport                = wgpu_render_pass_set_viewport
    render_pass_end                         = wgpu_render_pass_end
    render_pass_get_label                   = wgpu_render_pass_get_label
    render_pass_set_label                   = wgpu_render_pass_set_label
    render_pass_add_ref                     = wgpu_render_pass_add_ref
    render_pass_release                     = wgpu_render_pass_release

    // Render Pipeline procedures
    render_pipeline_get_label               = wgpu_render_pipeline_get_label
    render_pipeline_set_label               = wgpu_render_pipeline_set_label
    render_pipeline_add_ref                 = wgpu_render_pipeline_add_ref
    render_pipeline_release                 = wgpu_render_pipeline_release

    // Sampler procedures
    sampler_get_label                       = wgpu_sampler_get_label
    sampler_set_label                       = wgpu_sampler_set_label
    sampler_add_ref                         = wgpu_sampler_add_ref
    sampler_release                         = wgpu_sampler_release

    // Shader Module procedures
    shader_module_get_label                 = wgpu_shader_module_get_label
    shader_module_set_label                 = wgpu_shader_module_set_label
    shader_module_add_ref                   = wgpu_shader_module_add_ref
    shader_module_release                   = wgpu_shader_module_release

    // Surface procedures
    surface_configure                       = wgpu_surface_configure
    surface_present                         = wgpu_surface_present
    surface_get_capabilities                = wgpu_surface_get_capabilities
    surface_get_current_texture             = wgpu_surface_get_current_texture
    surface_get_label                       = wgpu_surface_get_label
    surface_set_label                       = wgpu_surface_set_label
    surface_add_ref                         = wgpu_surface_add_ref
    surface_release                         = wgpu_surface_release

    // Surface Capabilities procedures
    surface_capabilities_free_members       = wgpu_surface_capabilities_free_members

    // Texture procedures
    texture_create_view_impl                = wgpu_texture_create_view
    texture_get_label                       = wgpu_texture_get_label
    texture_set_label                       = wgpu_texture_set_label
    texture_add_ref                         = wgpu_texture_add_ref
    texture_release                         = wgpu_texture_release
    texture_get_depth_or_array_layers       = wgpu_texture_get_depth_or_array_layers
    texture_get_dimension                   = wgpu_texture_get_dimension
    texture_get_format                      = wgpu_texture_get_format
    texture_get_height                      = wgpu_texture_get_height
    texture_get_mip_level_count             = wgpu_texture_get_mip_level_count
    texture_get_sample_count                = wgpu_texture_get_sample_count
    texture_get_usage                       = wgpu_texture_get_usage
    texture_get_width                       = wgpu_texture_get_width
    texture_get_size                        = wgpu_texture_get_size
    texture_get_descriptor                  = wgpu_texture_get_descriptor

    // Texture view procedures
    texture_view_get_label                  = wgpu_texture_view_get_label
    texture_view_set_label                  = wgpu_texture_view_set_label
    texture_view_add_ref                    = wgpu_texture_view_add_ref
    texture_view_release                    = wgpu_texture_view_release
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------


@(require_results)
wgpu_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> Instance {
    return Instance(wgpu.CreateInstance(nil))
}

@(require_results)
wgpu_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    selector := wgpu.SurfaceSourceCanvasHTMLSelector {
        chain = {
            sType = .SurfaceSourceCanvasHTMLSelector,
        },
    }

    #partial switch &t in descriptor.target {
    case Surface_Source_Canvas_HTML_Selector:
        if t.selector == "" {
            panic("Invalid HTML selector", loc)
        }
        selector.selector = t.selector
    case:
        panic("Unsupported surface descriptor target", loc)
    }

    desc := wgpu.SurfaceDescriptor {
        nextInChain = &selector.chain,
        label = descriptor.label,
    }

    surface := wgpu.InstanceCreateSurface(wgpu.Instance(instance), &desc)

    return Surface(surface)
}

wgpu_instance_request_adapter :: proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
) {
    raw_callback_info := wgpu.RequestAdapterCallbackInfo {
        callback  = cast(wgpu.RequestAdapterCallback)callback_info.callback,
        userdata1 = callback_info.userdata1,
        userdata2 = callback_info.userdata2,
    }

    if opt, opt_ok := options.?; opt_ok {
        raw_options := wgpu.RequestAdapterOptions {
            // featureLevel         = {},
            powerPreference      = wgpu.PowerPreference(opt.power_preference),
            forceFallbackAdapter = b32(opt.force_fallback_adapter),
            backendType          = .WebGPU,
            compatibleSurface    = wgpu.Surface(opt.compatible_surface),
        }

        wgpu.InstanceRequestAdapter(wgpu.Instance(instance), &raw_options, raw_callback_info)
    } else {
        wgpu.InstanceRequestAdapter(wgpu.Instance(instance), nil, raw_callback_info)
    }
}

@(require_results)
wgpu_instance_get_label :: proc(instance: Instance, loc := #caller_location) -> string {
    return ""
}

wgpu_instance_set_label :: proc(instance: Instance, label: string, loc := #caller_location) {
}

wgpu_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    wgpu.InstanceAddRef(wgpu.Instance(instance))
}

wgpu_instance_release :: proc(instance: Instance, loc := #caller_location) {
    wgpu.InstanceRelease(wgpu.Instance(instance))
}

// -----------------------------------------------------------------------------
// Pipeline Layout procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    return ""
}

wgpu_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    wgpu.PipelineLayoutSetLabel(wgpu.PipelineLayout(pipeline_layout), label)
}

wgpu_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    wgpu.PipelineLayoutAddRef(wgpu.PipelineLayout(pipeline_layout))
}

wgpu_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    wgpu.PipelineLayoutRelease(wgpu.PipelineLayout(pipeline_layout))
}

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
) {
    raw_info, status := wgpu.AdapterGetInfo(wgpu.Adapter(adapter))
    if status != .Success { return }

    info.name = strings.clone(raw_info.device, allocator)
    info.vendor = raw_info.vendorID
    info.device = raw_info.deviceID
    info.device_type = wgpu_conv_from_adapter_type(raw_info.adapterType)
    info.driver = strings.clone(raw_info.vendor, allocator)
    info.driver_info = strings.clone(raw_info.description, allocator)
    info.backend = wgpu_conv_from_backend_type(raw_info.backendType)

    return
}

wgpu_adapter_info_free_members :: proc(self: Adapter_Info, allocator := context.allocator) {
    context.allocator = allocator
    delete(self.name)
    delete(self.driver)
    delete(self.driver_info)
}

@(require_results)
wgpu_adapter_get_features :: proc(
    adapter: Adapter,
    loc := #caller_location,
) -> (
    features: Features,
) {
    supported := wgpu.AdapterGetFeatures(wgpu.Adapter(adapter))
    defer wgpu.SupportedFeaturesFreeMembers(supported)
    feature_names := supported.features[:supported.featureCount]
    return wgpu_conv_from_feature_names(feature_names)
}

@(require_results)
wgpu_adapter_has_feature :: proc(
    adapter: Adapter,
    features: Features,
    loc := #caller_location,
) -> bool {
    if features == {} {
        return true
    }
    available := wgpu_adapter_get_features(adapter)
    if available == {} {
        return false
    }
    for f in features {
        if f not_in available {
            return false
        }
    }
    return true
}

@(require_results)
wgpu_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> (limits: Limits) {
    raw_limits, status := wgpu.AdapterGetLimits(wgpu.Adapter(adapter))
    if status != .Success {
        return
    }
    return wgpu_conv_from_limits(raw_limits)
}

wgpu_adapter_request_device :: proc(
    adapter: Adapter,
    callback_info: Request_Device_Callback_Info,
    descriptor: Maybe(Device_Descriptor) = nil,
    loc := #caller_location,
) {
    raw_callback_info := wgpu.RequestDeviceCallbackInfo {
        callback = cast(wgpu.RequestDeviceCallback)callback_info.callback,
        userdata1 = callback_info.userdata1,
        userdata2 = callback_info.userdata2,
    }

    desc, desc_ok := descriptor.?
    if !desc_ok {
        wgpu.AdapterRequestDevice(wgpu.Adapter(adapter), nil, raw_callback_info)
        return
    }

    raw_desc: wgpu.DeviceDescriptor
    raw_desc.label = desc.label

    features: sa.Small_Array(len(wgpu.FeatureName), wgpu.FeatureName)

    // Check for unsupported features
    if desc.required_features != {} {
        for f in desc.required_features {
            to_feature := WGPU_CONV_TO_FEATURE_NAME_LUT[f]
            if to_feature != .Undefined {
                sa.push_back(&features, WGPU_CONV_TO_FEATURE_NAME_LUT[f])
            }
        }

        raw_desc.requiredFeatureCount = uint(sa.len(features))
        raw_desc.requiredFeatures = raw_data(sa.slice(&features))
    }

    // If no limits is provided, default to the most restrictive limits
    limits := desc.required_limits if desc.required_limits != {} else LIMITS_MINIMUM_DEFAULT

    raw_limits := wgpu.Limits {
        maxTextureDimension1D                     = limits.max_texture_dimension_1d,
        maxTextureDimension2D                     = limits.max_texture_dimension_2d,
        maxTextureDimension3D                     = limits.max_texture_dimension_3d,
        maxTextureArrayLayers                     = limits.max_texture_array_layers,
        maxBindGroups                             = limits.max_bind_groups,
        maxBindGroupsPlusVertexBuffers            = limits.max_bind_groups_plus_vertex_buffers,
        maxBindingsPerBindGroup                   = limits.max_bindings_per_bind_group,
        maxDynamicUniformBuffersPerPipelineLayout = limits.max_dynamic_uniform_buffers_per_pipeline_layout,
        maxDynamicStorageBuffersPerPipelineLayout = limits.max_dynamic_storage_buffers_per_pipeline_layout,
        maxSampledTexturesPerShaderStage          = limits.max_sampled_textures_per_shader_stage,
        maxSamplersPerShaderStage                 = limits.max_samplers_per_shader_stage,
        maxStorageBuffersPerShaderStage           = limits.max_storage_buffers_per_shader_stage,
        maxStorageTexturesPerShaderStage          = limits.max_storage_textures_per_shader_stage,
        maxUniformBuffersPerShaderStage           = limits.max_uniform_buffers_per_shader_stage,
        maxUniformBufferBindingSize               = limits.max_uniform_buffer_binding_size,
        maxStorageBufferBindingSize               = limits.max_storage_buffer_binding_size,
        minUniformBufferOffsetAlignment           = limits.min_uniform_buffer_offset_alignment,
        minStorageBufferOffsetAlignment           = limits.min_storage_buffer_offset_alignment,
        maxVertexBuffers                          = limits.max_vertex_buffers,
        maxBufferSize                             = limits.max_buffer_size,
        maxVertexAttributes                       = limits.max_vertex_attributes,
        maxVertexBufferArrayStride                = limits.max_vertex_buffer_array_stride,
        maxInterStageShaderVariables              = limits.max_inter_stage_shader_variables,
        maxColorAttachments                       = limits.max_color_attachments,
        maxColorAttachmentBytesPerSample          = limits.max_color_attachment_bytes_per_sample,
        maxComputeWorkgroupStorageSize            = limits.max_compute_workgroup_storage_size,
        maxComputeInvocationsPerWorkgroup         = limits.max_compute_invocations_per_workgroup,
        maxComputeWorkgroupSizeX                  = limits.max_compute_workgroup_size_x,
        maxComputeWorkgroupSizeY                  = limits.max_compute_workgroup_size_y,
        maxComputeWorkgroupSizeZ                  = limits.max_compute_workgroup_size_z,
        maxComputeWorkgroupsPerDimension          = limits.max_compute_workgroups_per_dimension,
    }

    raw_desc.requiredLimits = &raw_limits

    raw_desc.deviceLostCallbackInfo = {
        callback = cast(wgpu.DeviceLostCallback)desc.device_lost_callback_info.callback,
        userdata1 = desc.device_lost_callback_info.userdata1,
        userdata2 = desc.device_lost_callback_info.userdata2,
    }

    raw_desc.uncapturedErrorCallbackInfo = {
        callback = cast(wgpu.UncapturedErrorCallback)desc.uncaptured_error_callback_info.callback,
        userdata1 = desc.uncaptured_error_callback_info.userdata1,
        userdata2 = desc.uncaptured_error_callback_info.userdata2,
    }

    wgpu.AdapterRequestDevice(wgpu.Adapter(adapter), &raw_desc, raw_callback_info)
}

@(require_results)
wgpu_adapter_get_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities {
    unimplemented()
}

@(require_results)
wgpu_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    return ""
}

wgpu_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
}

wgpu_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    wgpu.AdapterAddRef(wgpu.Adapter(adapter))
}

wgpu_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    wgpu.AdapterRelease(wgpu.Adapter(adapter))
}

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    return ""
}

wgpu_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    wgpu.BindGroupSetLabel(wgpu.BindGroup(bind_group), label)
}

wgpu_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    wgpu.BindGroupAddRef(wgpu.BindGroup(bind_group))
}

wgpu_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    wgpu.BindGroupRelease(wgpu.BindGroup(bind_group))
}

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    return ""
}

// @(default_calling_convention="c")
// foreign _ {
//     // FIX(bindings): label should be a string (StringView), not a cstring
//     wgpuBindGroupLayoutSetLabel :: proc(bindGroupLayout: wgpu.BindGroupLayout, label: string) ---
// }

wgpu_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    // wgpuBindGroupLayoutSetLabel(wgpu.BindGroupLayout(bind_group_layout), label)
}

wgpu_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    wgpu.BindGroupLayoutAddRef(wgpu.BindGroupLayout(bind_group_layout))
}

wgpu_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    wgpu.BindGroupLayoutRelease(wgpu.BindGroupLayout(bind_group_layout))
}

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------


wgpu_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    wgpu.BufferDestroy(wgpu.Buffer(buffer))
}

wgpu_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    wgpu.BufferUnmap(wgpu.Buffer(buffer))
}

wgpu_buffer_get_map_state :: proc(
    buffer: Buffer,
    loc := #caller_location,
) -> Buffer_Map_State {
    return cast(Buffer_Map_State)wgpu.BufferGetMapState(wgpu.Buffer(buffer))
}

wgpu_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    return wgpu.BufferGetSize(wgpu.Buffer(buffer))
}

wgpu_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> (ret: Buffer_Usages) {
    return wgpu_conv_from_buffer_usage_flags(wgpu.BufferGetUsage(wgpu.Buffer(buffer)))
}

buffer_get_const_mapped_range :: proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr {
    return wgpu.RawBufferGetConstMappedRange(wgpu.Buffer(buffer), offset, size)
}

buffer_get_mapped_range :: proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr {
    return wgpu.RawBufferGetMappedRange(wgpu.Buffer(buffer), offset, size)
}

wgpu_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Modes,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> (
    future: Future,
) {
    unimplemented()
}

@(require_results)
wgpu_buffer_get_label :: proc(buffer: Buffer, loc := #caller_location) -> string {
    return ""
}

wgpu_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    wgpu.BufferSetLabel(wgpu.Buffer(buffer), label)
}

wgpu_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    wgpu.BufferAddRef(wgpu.Buffer(buffer))
}

wgpu_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    wgpu.BufferRelease(wgpu.Buffer(buffer))
}

// -----------------------------------------------------------------------------
// Command Buffer procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    return ""
}

wgpu_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    wgpu.CommandBufferSetLabel(wgpu.CommandBuffer(command_buffer), label)
}

wgpu_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wgpu.CommandBufferAddRef(wgpu.CommandBuffer(command_buffer))
}

wgpu_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    wgpu.CommandBufferRelease(wgpu.CommandBuffer(command_buffer))
}

// -----------------------------------------------------------------------------
// Command Encoder procedures
// -----------------------------------------------------------------------------


wgpu_command_encoder_begin_compute_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Maybe(Compute_Pass_Descriptor) = nil,
    loc := #caller_location,
) -> Compute_Pass {
    unimplemented()
}

wgpu_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    desc: wgpu.RenderPassDescriptor
    desc.label = descriptor.label

    // Color attachments
    color_attachments: sa.Small_Array(MAX_COLOR_ATTACHMENTS, wgpu.RenderPassColorAttachment)

    if len(descriptor.color_attachments) > 0 {
        // Validate color attachment count doesn't exceed maximum
        assert(len(descriptor.color_attachments) <= MAX_COLOR_ATTACHMENTS,
               "Too many color attachments", loc)

        for &attachment in descriptor.color_attachments {
            attachment_raw := wgpu.RenderPassColorAttachment {
                view          = wgpu.TextureView(attachment.view),
                resolveTarget = wgpu.TextureView(attachment.resolve_target),
                depthSlice    = DEPTH_SLICE_UNDEFINED,
                loadOp        = cast(wgpu.LoadOp)attachment.ops.load,
                storeOp       = cast(wgpu.StoreOp)attachment.ops.store,
                clearValue    = wgpu.Color {
                    attachment.ops.clear_value.r,
                    attachment.ops.clear_value.g,
                    attachment.ops.clear_value.b,
                    attachment.ops.clear_value.a,
                },
            }
            sa.push_back(&color_attachments, attachment_raw)
        }

        desc.colorAttachmentCount = uint(sa.len(color_attachments))
        desc.colorAttachments = raw_data(sa.slice(&color_attachments))
    }

    // Depth/Stencil attachment
    depth_stencil: wgpu.RenderPassDepthStencilAttachment
    if descriptor.depth_stencil_attachment != nil {
        dsa := descriptor.depth_stencil_attachment
        depth_stencil.view = wgpu.TextureView(dsa.view)

        // Handle depth operations
        depth_stencil.depthLoadOp     = cast(wgpu.LoadOp)dsa.depth_ops.load
        depth_stencil.depthStoreOp    = cast(wgpu.StoreOp)dsa.depth_ops.store
        depth_stencil.depthClearValue = dsa.depth_ops.clear_value
        depth_stencil.depthReadOnly   = b32(dsa.depth_ops.read_only)

        // Handle stencil operations
        depth_stencil.stencilLoadOp     = cast(wgpu.LoadOp)dsa.stencil_ops.load
        depth_stencil.stencilStoreOp    = cast(wgpu.StoreOp)dsa.stencil_ops.store
        depth_stencil.stencilClearValue = dsa.stencil_ops.clear_value
        depth_stencil.stencilReadOnly   = b32(dsa.stencil_ops.read_only)

        desc.depthStencilAttachment = &depth_stencil
    }

    timestamp_writes: wgpu.RenderPassTimestampWrites
    if descriptor.timestamp_writes != nil {
        tw := descriptor.timestamp_writes
        timestamp_writes.beginningOfPassWriteIndex = tw.beginning_of_pass_write_index
        timestamp_writes.endOfPassWriteIndex = tw.end_of_pass_write_index
        timestamp_writes.querySet = wgpu.QuerySet(tw.query_set)
        desc.timestampWrites = &timestamp_writes
    }

    if descriptor.occlusion_query_set != nil {
        desc.occlusionQuerySet = wgpu.QuerySet(descriptor.occlusion_query_set)
    }

    return Render_Pass(wgpu.CommandEncoderBeginRenderPass(wgpu.CommandEncoder(command_encoder), &desc))
}

wgpu_command_encoder_clear_buffer :: proc(
    encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented()
}

wgpu_command_encoder_resolve_query_set :: proc(
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

wgpu_command_encoder_write_timestamp :: proc(
    encoder: Command_Encoder,
    querySet: Query_Set,
    queryIndex: u32,
    loc := #caller_location,
) {
    unimplemented()
}

wgpu_command_encoder_copy_buffer_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    wgpu.CommandEncoderCopyBufferToBuffer(
        wgpu.CommandEncoder(command_encoder),
        wgpu.Buffer(source),
        source_offset,
        wgpu.Buffer(destination),
        destination_offset,
        size,
    )
}

wgpu_command_encoder_copy_buffer_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Buffer_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    raw_source := wgpu.TexelCopyBufferInfo {
        layout = transmute(wgpu.TexelCopyBufferLayout)source.layout,
        buffer = wgpu.Buffer(source.buffer),
    }

    raw_dst := wgpu.TexelCopyTextureInfo {
        texture  = wgpu.Texture(destination.texture),
        mipLevel = destination.mip_level,
        origin   = wgpu_conv_to_origin_3d(destination.origin),
        aspect   = wgpu_conv_to_texture_aspect(destination.aspect),
    }

    raw_copy_size := transmute(wgpu.Extent3D)copy_size

    wgpu.CommandEncoderCopyBufferToTexture(
        wgpu.CommandEncoder(command_encoder),
        &raw_source,
        &raw_dst,
        &raw_copy_size,
    )
}

wgpu_command_encoder_copy_texture_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    raw_source := wgpu.TexelCopyTextureInfo {
        texture  = wgpu.Texture(source.texture),
        mipLevel = source.mip_level,
        origin   = wgpu_conv_to_origin_3d(source.origin),
        aspect   = wgpu_conv_to_texture_aspect(source.aspect),
    }

    raw_dst := wgpu.TexelCopyBufferInfo {
        layout = transmute(wgpu.TexelCopyBufferLayout)destination.layout,
        buffer = wgpu.Buffer(destination.buffer),
    }

    raw_copy_size := transmute(wgpu.Extent3D)copy_size

    wgpu.CommandEncoderCopyTextureToBuffer(
        wgpu.CommandEncoder(command_encoder),
        &raw_source,
        &raw_dst,
        &raw_copy_size,
    )
}

wgpu_command_encoder_copy_texture_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    raw_source := wgpu.TexelCopyTextureInfo {
        texture  = wgpu.Texture(source.texture),
        mipLevel = source.mip_level,
        origin   = wgpu_conv_to_origin_3d(source.origin),
        aspect   = wgpu_conv_to_texture_aspect(source.aspect),
    }

    raw_dst := wgpu.TexelCopyTextureInfo {
        texture  = wgpu.Texture(destination.texture),
        mipLevel = destination.mip_level,
        origin   = wgpu_conv_to_origin_3d(destination.origin),
        aspect   = wgpu_conv_to_texture_aspect(destination.aspect),
    }

    raw_copy_size := transmute(wgpu.Extent3D)copy_size

    wgpu.CommandEncoderCopyTextureToTexture(
        wgpu.CommandEncoder(command_encoder),
        &raw_source,
        &raw_dst,
        &raw_copy_size,
    )
}

@(require_results)
wgpu_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer {
    return Command_Buffer(wgpu.CommandEncoderFinish(wgpu.CommandEncoder(command_encoder)))
}

@(require_results)
wgpu_command_encoder_get_label :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    return ""
}

wgpu_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    wgpu.CommandEncoderSetLabel(wgpu.CommandEncoder(command_encoder), label)
}

wgpu_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    wgpu.CommandEncoderAddRef(wgpu.CommandEncoder(command_encoder))
}

wgpu_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    wgpu.CommandEncoderRelease(wgpu.CommandEncoder(command_encoder))
}

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------


wgpu_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    assert(descriptor.layout != nil, "Invalid bind group layout", loc)

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    entries_total := len(descriptor.entries)
    entries: []wgpu.BindGroupEntry

    if entries_total > 0 {
        entries = make([]wgpu.BindGroupEntry, entries_total, ta)
    }

    for &entry, i in descriptor.entries {
        raw_entry := &entries[i]
        raw_entry.binding = entry.binding

        switch &res in entry.resource {
        case Buffer_Binding:
            actual_size := wgpu_buffer_get_size(res.buffer, loc)

            assert(res.offset <= actual_size, "buffer offset exceeds buffer size", loc)

            if res.size == 0 || res.size == WHOLE_SIZE {
                // Use remaining buffer from offset to end
                actual_size = actual_size - res.offset
            } else {
                // Validate the requested region fits within the buffer
                assert(res.offset + res.size <= actual_size,
                    "buffer region (offset + size) exceeds buffer bounds", loc)
                actual_size = res.size
            }

            raw_entry.buffer = wgpu.Buffer(res.buffer)
            raw_entry.size = actual_size
            raw_entry.offset = res.offset

        case Sampler:
            raw_entry.sampler = wgpu.Sampler(res)

        case Texture_View:
            raw_entry.textureView = wgpu.TextureView(res)

        case []Buffer_Binding:
            // TODO

        case []Sampler:
            // TODO

        case []Texture_View:
            // TODO
        }
    }

    desc := wgpu.BindGroupDescriptor {
        label      = descriptor.label,
        layout     = wgpu.BindGroupLayout(descriptor.layout),
        entryCount = len(entries),
        entries    = raw_data(entries),
    }

    return Bind_Group(wgpu.DeviceCreateBindGroup(wgpu.Device(device), &desc))
}

wgpu_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    entry_count := len(descriptor.entries)

    if entry_count == 0 {
        raw_desc := wgpu.BindGroupLayoutDescriptor {
            label = descriptor.label,
        }
        return Bind_Group_Layout(wgpu.DeviceCreateBindGroupLayout(wgpu.Device(device), &raw_desc))
    }

    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    entries := make([]wgpu.BindGroupLayoutEntry, entry_count, ta)

    for &entry, i in descriptor.entries {
        raw_entry := &entries[i]

        raw_entry.binding = entry.binding
        raw_entry.visibility = wgpu_conv_to_shader_stage_flags(entry.visibility)

        // Handle binding types
        #partial switch type in entry.type {
        case Buffer_Binding_Layout:
            raw_entry.buffer = {
                type = wgpu.BufferBindingType(type.type),
                hasDynamicOffset = b32(type.has_dynamic_offset),
                minBindingSize = type.min_binding_size,
            }

        case Sampler_Binding_Layout:
            raw_entry.sampler = {
                type = wgpu.SamplerBindingType(type.type),
            }

        case Texture_Binding_Layout:
            raw_entry.texture = {
                sampleType = wgpu.TextureSampleType(type.sample_type),
                viewDimension = wgpu.TextureViewDimension(type.view_dimension),
                multisampled = b32(type.multisampled),
            }

        case Storage_Texture_Binding_Layout:
            format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[type.format]
            if type.format != .Undefined && format == .Undefined {
                log.warnf("WebGPU: Unsupported texture format: %v", type.format)
            }
            raw_entry.storageTexture = {
                access = wgpu.StorageTextureAccess(type.access),
                format = format,
                viewDimension = wgpu.TextureViewDimension(type.view_dimension),
            }
        }
    }

    raw_desc := wgpu.BindGroupLayoutDescriptor {
        label      = descriptor.label,
        entryCount = uint(entry_count),
        entries    = raw_data(entries),
    }

    return Bind_Group_Layout(wgpu.DeviceCreateBindGroupLayout(wgpu.Device(device), &raw_desc))
}

wgpu_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    bind_group_layout_count := len(descriptor.bind_group_layouts)
    bind_group_layouts := cast([^]wgpu.BindGroupLayout)raw_data(descriptor.bind_group_layouts)

    desc := wgpu.PipelineLayoutDescriptor {
        label                = descriptor.label,
        bindGroupLayoutCount = uint(bind_group_layout_count),
        bindGroupLayouts     = bind_group_layout_count > 0 ? bind_group_layouts : nil,
    }

    return Pipeline_Layout(wgpu.DeviceCreatePipelineLayout(wgpu.Device(device), &desc))
}

@(require_results)
wgpu_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    descriptor := wgpu.BufferDescriptor {
        label            = descriptor.label,
        usage            = wgpu_conv_to_buffer_usage_flags(descriptor.usage),
        size             = descriptor.size,
        mappedAtCreation = b32(descriptor.mapped_at_creation),
    }
    return Buffer(wgpu.DeviceCreateBuffer(wgpu.Device(device), &descriptor))
}

@(require_results)
wgpu_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor = SAMPLER_DESCRIPTOR_DEFAULT,
    loc := #caller_location,
) -> Sampler {
    desc := wgpu.SamplerDescriptor {
        label         = descriptor.label,
        addressModeU  = wgpu.AddressMode(descriptor.address_mode_u),
        addressModeV  = wgpu.AddressMode(descriptor.address_mode_v),
        addressModeW  = wgpu.AddressMode(descriptor.address_mode_w),
        magFilter     = wgpu.FilterMode(descriptor.mag_filter),
        minFilter     = wgpu.FilterMode(descriptor.mipmap_filter),
        mipmapFilter  = wgpu.MipmapFilterMode(descriptor.mipmap_filter),
        lodMinClamp   = descriptor.lod_min_clamp,
        lodMaxClamp   = descriptor.lod_max_clamp,
        compare       = wgpu.CompareFunction(descriptor.compare),
        maxAnisotropy = descriptor.max_anisotropy,
    }
    return Sampler(wgpu.DeviceCreateSampler(wgpu.Device(device), &desc))
}

@(require_results)
wgpu_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    source := wgpu.ShaderSourceWGSL{
        chain = { sType = .ShaderSourceWGSL },
        code = string(descriptor.code),
    }

    raw_desc := wgpu.ShaderModuleDescriptor {
        nextInChain = &source.chain,
        label = descriptor.label,
    }

    return Shader_Module(wgpu.DeviceCreateShaderModule(wgpu.Device(device), &raw_desc))
}

@(require_results)
wgpu_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[descriptor.format]
    if format == .Undefined {
        log.warnf("WebGPU: Unsupported texture format: %v", descriptor.format)
    }

    raw_desc := wgpu.TextureDescriptor {
        label         = descriptor.label,
        usage         = wgpu_conv_to_texture_usage_flags(descriptor.usage),
        dimension     = wgpu.TextureDimension(descriptor.dimension),
        size          = transmute(wgpu.Extent3D)descriptor.size,
        format        = format,
        mipLevelCount = descriptor.mip_level_count,
        sampleCount   = descriptor.sample_count,
    }

    // TODO: view formats

    return Texture(wgpu.DeviceCreateTexture(wgpu.Device(device), &raw_desc))
}

@(require_results)
wgpu_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder {
    raw_desc: wgpu.CommandEncoderDescriptor
    if desc, desc_ok := descriptor.?; desc_ok {
        raw_desc.label = desc.label
    }
    return Command_Encoder(wgpu.DeviceCreateCommandEncoder(
        wgpu.Device(device), &raw_desc if descriptor != nil else nil))
}

@(require_results)
wgpu_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    ta := context.temp_allocator
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // Main descriptor
    raw_desc := wgpu.RenderPipelineDescriptor {
        label  = descriptor.label,
        layout = wgpu.PipelineLayout(descriptor.layout),
    }

    // Vertex state
    raw_desc.vertex.module = wgpu.ShaderModule(descriptor.vertex.module)
    raw_desc.vertex.entryPoint = descriptor.vertex.entry_point

    // Vertex constants
    vertex_constant_count := len(descriptor.vertex.constants)
    if vertex_constant_count > 0 {
        constants := descriptor.vertex.constants
        raw_constants := make([]wgpu.ConstantEntry, vertex_constant_count, ta)

        for i in 0 ..< vertex_constant_count {
            raw_constants[i] = {
                key = constants[i].key,
                value = constants[i].value,
            }
        }

        raw_desc.vertex.constantCount = uint(len(raw_constants))
        raw_desc.vertex.constants = raw_data(raw_constants)
    }

    // Vertex buffers
    vertex_buffers: sa.Small_Array(MAX_VERTEX_BUFFERS, wgpu.VertexBufferLayout)
    if len(descriptor.vertex.buffers) > 0 {
        for &buffer in descriptor.vertex.buffers {
            vertexBuffer: wgpu.VertexBufferLayout

            vertexBuffer.arrayStride = buffer.array_stride
            vertexBuffer.stepMode    = wgpu.VertexStepMode(buffer.step_mode)

            attribute_count := len(buffer.attributes)
            if attribute_count > 0 {
                raw_attributes := make([]wgpu.VertexAttribute, attribute_count, ta)

                for i in 0 ..< attribute_count {
                    raw_attributes[i] = {
                        format = wgpu_conv_to_vertex_format(buffer.attributes[i].format),
                        offset = buffer.attributes[i].offset,
                        shaderLocation = buffer.attributes[i].shader_location,
                    }
                }

                vertexBuffer.attributeCount = uint(len(raw_attributes))
                vertexBuffer.attributes = raw_data(raw_attributes)
            }

            sa.push_back(&vertex_buffers, vertexBuffer)
        }

        raw_desc.vertex.bufferCount = uint(sa.len(vertex_buffers))
        raw_desc.vertex.buffers = raw_data(sa.slice(&vertex_buffers))
    }

    // Primitive state
    raw_desc.primitive = {
        topology         = wgpu.PrimitiveTopology(descriptor.primitive.topology),
        stripIndexFormat = wgpu.IndexFormat(descriptor.primitive.strip_index_format),
        frontFace        = wgpu.FrontFace(descriptor.primitive.front_face),
        cullMode         = wgpu.CullMode(descriptor.primitive.cull_mode),
        unclippedDepth   = b32(descriptor.primitive.unclipped_depth),
    }

    // Depth stencil state
    raw_depth_stencil: wgpu.DepthStencilState

    if descriptor.depth_stencil != nil {
        ds := descriptor.depth_stencil

        ds_format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[ds.format]
        if ds_format == .Undefined {
            log.warnf("WebGPU: Unsupported depth texture format: %v", ds.format)
        }

        raw_depth_stencil = {
            format              = ds_format,
            depthWriteEnabled   = .True if ds.depth_write_enabled else .False,
            depthCompare        = wgpu.CompareFunction(ds.depth_compare),
            stencilFront        = transmute(wgpu.StencilFaceState)ds.stencil.front,
            stencilBack         = transmute(wgpu.StencilFaceState)ds.stencil.back,
            stencilReadMask     = ds.stencil.read_mask,
            stencilWriteMask    = ds.stencil.write_mask,
            depthBias           = ds.bias.constant,
            depthBiasSlopeScale = ds.bias.slope_scale,
            depthBiasClamp      = ds.bias.clamp,
        }
        raw_desc.depthStencil = &raw_depth_stencil
    }

    // Multisample state
    raw_desc.multisample = {
        count = descriptor.multisample.count,
        mask = descriptor.multisample.mask,
        alphaToCoverageEnabled = b32(descriptor.multisample.alpha_to_coverage_enabled),
    }
    if raw_desc.multisample.count == 0 {
        raw_desc.multisample.count = 1 // Cannot be 0, default to 1
    }

    // Fragment state (optional)
    raw_fragment: wgpu.FragmentState

    if descriptor.fragment != nil {
        raw_fragment.module = wgpu.ShaderModule(descriptor.fragment.module)
        raw_fragment.entryPoint = descriptor.fragment.entry_point

        // Fragment constants
        fragment_constant_count := len(descriptor.fragment.constants)
        if fragment_constant_count > 0 {
            constants := descriptor.fragment.constants
            raw_constants := make([]wgpu.ConstantEntry, vertex_constant_count, ta)

            for i in 0 ..< vertex_constant_count {
                raw_constants[i] = {
                    key = constants[i].key,
                    value = constants[i].value,
                }
            }

            raw_fragment.constantCount = uint(len(raw_constants))
            raw_fragment.constants = raw_data(raw_constants)
        }

        // Fragment targets
        target_count := len(descriptor.fragment.targets)
        if target_count > 0 {
            raw_targets := make([]wgpu.ColorTargetState, target_count, ta)
            targets := descriptor.fragment.targets

            for i in 0 ..< target_count {
                target_format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[targets[i].format]
                if target_format == .Undefined {
                    log.warnf("WebGPU: Unsupported depth texture format: %v", targets[i].format)
                }

                raw_targets[i].format = target_format

                if targets[i].blend != nil {
                    raw_targets[i].blend = cast(^wgpu.BlendState)targets[i].blend
                }

                raw_targets[i].writeMask = wgpu_conv_to_color_write_mask(targets[i].write_mask)
            }

            raw_fragment.targetCount = uint(len(raw_targets))
            raw_fragment.targets = raw_data(raw_targets)
        }

        raw_desc.fragment = &raw_fragment
    }

    return Render_Pipeline(wgpu.DeviceCreateRenderPipeline(wgpu.Device(device), &raw_desc))
}

@(require_results)
wgpu_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    return Queue(wgpu.DeviceGetQueue(wgpu.Device(device)))
}

wgpu_device_get_features :: proc(device: Device, loc := #caller_location) -> (features: Features) {
    supported := wgpu.DeviceGetFeatures(wgpu.Device(device))
    defer wgpu.SupportedFeaturesFreeMembers(supported)
    feature_names := supported.features[:supported.featureCount]
    return wgpu_conv_from_feature_names(feature_names)
}

@(require_results)
wgpu_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    return ""
}

wgpu_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    wgpu.DeviceSetLabel(wgpu.Device(device), label)
}

wgpu_device_add_ref :: proc(device: Device, loc := #caller_location) {
    wgpu.DeviceAddRef(wgpu.Device(device))
}

wgpu_device_release :: proc(device: Device, loc := #caller_location) {
    wgpu.DeviceRelease(wgpu.Device(device))
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------


wgpu_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    wgpu.QueueSubmit(wgpu.Queue(queue), transmute([]wgpu.CommandBuffer)commands)
}

wgpu_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    wgpu.QueueWriteBuffer(wgpu.Queue(queue), wgpu.Buffer(buffer), buffer_offset, data, size)
}

wgpu_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    assert(destination.texture != nil, "Invalid destination texture", loc)

    raw_dst := wgpu.TexelCopyTextureInfo {
        texture  = wgpu.Texture(destination.texture),
        mipLevel = destination.mip_level,
        origin   = wgpu_conv_to_origin_3d(destination.origin),
        aspect   = wgpu_conv_to_texture_aspect(destination.aspect),
    }

    raw_data_layout := transmute(wgpu.TexelCopyBufferLayout)data_layout

    raw_write_size := transmute(wgpu.Extent3D)write_size

    if len(data) == 0 {
        wgpu.QueueWriteTexture(wgpu.Queue(queue), &raw_dst, nil, 0, &raw_data_layout, &raw_write_size)
    } else {
        wgpu.QueueWriteTexture(
            wgpu.Queue(queue),
            &raw_dst,
            raw_data(data),
            uint(len(data)),
            &raw_data_layout,
            &raw_write_size,
        )
    }
}

@(require_results)
wgpu_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    return ""
}

wgpu_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    wgpu.QueueSetLabel(wgpu.Queue(queue), label)
}

wgpu_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    wgpu.QueueAddRef(wgpu.Queue(queue))
}

wgpu_queue_release :: proc(queue: Queue, loc := #caller_location) {
    wgpu.QueueRelease(wgpu.Queue(queue))
}

// -----------------------------------------------------------------------------
// Render Pass procedures
// -----------------------------------------------------------------------------


wgpu_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderSetPipeline(wgpu.RenderPassEncoder(render_pass), wgpu.RenderPipeline(pipeline))
}

wgpu_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderSetBindGroup(
        wgpu.RenderPassEncoder(render_pass),
        group_index,
        wgpu.BindGroup(group),
        dynamic_offsets,
    )
}

wgpu_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    actual_size := wgpu_buffer_get_size(buffer)

    if size == 0 || size == WHOLE_SIZE {
        // Use remaining buffer from offset to end
        actual_size = actual_size - offset
    } else {
        // Validate the requested region fits within the buffer
        assert(offset + size <= actual_size,
            "buffer region (offset + size) exceeds buffer bounds", loc)
        actual_size = size
    }

    wgpu.RenderPassEncoderSetVertexBuffer(
        wgpu.RenderPassEncoder(render_pass),
        slot,
        wgpu.Buffer(buffer),
        offset,
        actual_size)
}

wgpu_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    actual_size := wgpu_buffer_get_size(buffer)

    if size == 0 || size == WHOLE_SIZE {
        // Use remaining buffer from offset to end
        actual_size = actual_size - offset
    } else {
        // Validate the requested region fits within the buffer
        assert(offset + size <= actual_size,
            "buffer region (offset + size) exceeds buffer bounds", loc)
        actual_size = size
    }

    wgpu.RenderPassEncoderSetIndexBuffer(
        wgpu.RenderPassEncoder(render_pass),
        wgpu.Buffer(buffer),
        wgpu.IndexFormat(format),
        offset,
        actual_size,
    )
}

wgpu_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderSetStencilReference(wgpu.RenderPassEncoder(render_pass), reference)
}

wgpu_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderDraw(
        wgpu.RenderPassEncoder(render_pass),
        vertices.end - vertices.start,
        instances.end - instances.start,
        vertices.start,
        instances.start,
    )
}

wgpu_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderDrawIndexed(
        wgpu.RenderPassEncoder(render_pass),
        indices.end - indices.start,
        instances.end - instances.start,
        indices.start,
        base_vertex,
        instances.start,
    )
}

wgpu_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderSetScissorRect(wgpu.RenderPassEncoder(render_pass), x, y, width, height)
}

wgpu_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    wgpu.RenderPassEncoderSetViewport(
        wgpu.RenderPassEncoder(render_pass), x, y, width, height, min_depth, max_depth)
}

wgpu_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    wgpu.RenderPassEncoderEnd(wgpu.RenderPassEncoder(render_pass))
}

@(require_results)
wgpu_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    return ""
}

wgpu_render_pass_set_label :: proc(render_pass: Render_Pass, label: string, loc := #caller_location) {
    wgpu.RenderPassEncoderSetLabel(wgpu.RenderPassEncoder(render_pass), label)
}

wgpu_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
    wgpu.RenderPassEncoderAddRef(wgpu.RenderPassEncoder(render_pass))
}

wgpu_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
    wgpu.RenderPassEncoderRelease(wgpu.RenderPassEncoder(render_pass))
}

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_render_pipeline_get_label :: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string {
    return ""
}

wgpu_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    wgpu.RenderPipelineSetLabel(wgpu.RenderPipeline(render_pipeline), label)
}

wgpu_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    wgpu.RenderPipelineAddRef(wgpu.RenderPipeline(render_pipeline))
}

wgpu_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    wgpu.RenderPipelineRelease(wgpu.RenderPipeline(render_pipeline))
}

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    return ""
}

wgpu_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    wgpu.SamplerSetLabel(wgpu.Sampler(sampler), label)
}

wgpu_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    wgpu.SamplerAddRef(wgpu.Sampler(sampler))
}

wgpu_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    wgpu.SamplerRelease(wgpu.Sampler(sampler))
}

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_shader_module_get_label :: proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string {
    return ""
}

wgpu_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    wgpu.ShaderModuleSetLabel(wgpu.ShaderModule(shader_module), label)
}

wgpu_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    wgpu.ShaderModuleAddRef(wgpu.ShaderModule(shader_module))
}

wgpu_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    wgpu.ShaderModuleRelease(wgpu.ShaderModule(shader_module))
}

// -----------------------------------------------------------------------------
// Surface procedures
// -----------------------------------------------------------------------------


wgpu_surface_configure :: proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    assert(config.format != .Undefined, "Invalid texture format", loc)
    assert(config.width != 0, "Surface width must be > 0", loc)
    assert(config.height != 0, "Surface height must be > 0", loc)

    format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[config.format]
    if format == .Undefined {
        log.warnf("WebGPU: Unsupported texture format: %v", config.format)
    }

    raw_config := wgpu.SurfaceConfiguration {
        device      = wgpu.Device(device),
        format      = format,
        usage       = wgpu_conv_to_texture_usage_flags(config.usage),
        width       = config.width,
        height      = config.height,
        alphaMode   = wgpu.CompositeAlphaMode(config.alpha_mode),
        presentMode = wgpu.PresentMode(config.present_mode),
    }

    // TODO: view formats

    wgpu.SurfaceConfigure(wgpu.Surface(surface), &raw_config)
}

wgpu_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    raw_caps, status := wgpu.SurfaceGetCapabilities(wgpu.Surface(surface), wgpu.Adapter(adapter))
    if status != .Success { return }

    defer wgpu.SurfaceCapabilitiesFreeMembers(raw_caps)

    caps.usages = wgpu_conv_from_texture_usage_flags(raw_caps.usages)

    context.allocator = allocator

    if raw_caps.formatCount > 0 {
        caps.formats = make([]Texture_Format, raw_caps.formatCount)
        raw_formats := slice.from_ptr(raw_caps.formats, int(raw_caps.formatCount))
        for v, i in raw_formats {
            caps.formats[i] = wgpu_conv_from_texture_format(v)
        }
    }

    if raw_caps.presentModeCount > 0 {
        caps.present_modes = make([]Present_Mode, raw_caps.presentModeCount)
        raw_present_modes :=
            transmute([]Present_Mode)slice.from_ptr(
                raw_caps.presentModes, int(raw_caps.presentModeCount))
        copy(caps.present_modes, raw_present_modes)
    }

    if raw_caps.alphaModeCount > 0 {
        caps.alpha_modes = make([]Composite_Alpha_Mode, raw_caps.alphaModeCount)
        raw_alpha_modes :=
            transmute([]Composite_Alpha_Mode)slice.from_ptr(
                raw_caps.alphaModes, int(raw_caps.alphaModeCount))
        copy(caps.alpha_modes, raw_alpha_modes)
    }

    return
}

@(require_results)
wgpu_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    ret: Surface_Texture,
) {
    raw_texture := wgpu.SurfaceGetCurrentTexture(wgpu.Surface(surface))

    ret.surface = surface
    ret.texture = Texture(raw_texture.texture)
    ret.status = Surface_Texture_Status(raw_texture.status)

    return
}

wgpu_surface_present :: proc(surface: Surface, loc := #caller_location) {
    // NOTE: Not really anything to do here.
}

@(require_results)
wgpu_surface_get_label :: proc(surface: Surface, loc := #caller_location) -> string {
    return ""
}

wgpu_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    wgpu.SurfaceSetLabel(wgpu.Surface(surface), label)
}

wgpu_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    wgpu.SurfaceAddRef(wgpu.Surface(surface))
}

wgpu_surface_release :: proc(surface: Surface, loc := #caller_location) {
    wgpu.SurfaceRelease(wgpu.Surface(surface))
}

// -----------------------------------------------------------------------------
// Surface Capabilities procedures
// -----------------------------------------------------------------------------


wgpu_surface_capabilities_free_members :: proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
) {
    context.allocator = allocator
    delete(caps.formats)
    delete(caps.present_modes)
    delete(caps.alpha_modes)
}

// -----------------------------------------------------------------------------
// Texture procedures
// -----------------------------------------------------------------------------


@(require_results)
wgpu_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View {
    format := WGPU_CONV_TO_TEXTURE_FORMAT_LUT[descriptor.format]
    if format == .Undefined {
        log.warnf("WebGPU: Unsupported texture format: %v", descriptor.format)
    }

    raw_desc := wgpu.TextureViewDescriptor {
        label           = descriptor.label,
        format          = format,
        dimension       = wgpu.TextureViewDimension(descriptor.dimension),
        baseMipLevel    = descriptor.base_mip_level,
        mipLevelCount   = descriptor.mip_level_count,
        baseArrayLayer  = descriptor.base_array_layer,
        arrayLayerCount = descriptor.array_layer_count,
        aspect          = wgpu_conv_to_texture_aspect(descriptor.aspect),
        usage           = wgpu_conv_to_texture_usage_flags(descriptor.usage),
    }

    return Texture_View(wgpu.TextureCreateView(wgpu.Texture(texture), &raw_desc))
}

wgpu_texture_get_depth_or_array_layers :: proc(
    texture: Texture,
    loc := #caller_location,
) -> u32 {
    return wgpu.TextureGetDepthOrArrayLayers(wgpu.Texture(texture))
}

wgpu_texture_get_dimension :: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension {
    return Texture_Dimension(wgpu.TextureGetDimension(wgpu.Texture(texture)))
}

wgpu_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    return wgpu_conv_from_texture_format(wgpu.TextureGetFormat(wgpu.Texture(texture)))
}

wgpu_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return wgpu.TextureGetHeight(wgpu.Texture(texture))
}

wgpu_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return wgpu.TextureGetMipLevelCount(wgpu.Texture(texture))
}

wgpu_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return wgpu.TextureGetSampleCount(wgpu.Texture(texture))
}

wgpu_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    return wgpu_conv_from_texture_usage_flags(wgpu.TextureGetUsage(wgpu.Texture(texture)))
}

wgpu_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return wgpu.TextureGetWidth(wgpu.Texture(texture))
}

wgpu_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    return {
        width                 = wgpu.TextureGetWidth(wgpu.Texture(texture)),
        height                = wgpu.TextureGetHeight(wgpu.Texture(texture)),
        depth_or_array_layers = wgpu.TextureGetDepthOrArrayLayers(wgpu.Texture(texture)),
    }
}

wgpu_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> (
    desc: Texture_Descriptor,
) {
    desc.usage           = wgpu_texture_get_usage(texture)
    desc.dimension       = wgpu_texture_get_dimension(texture)
    desc.size            = wgpu_texture_get_size(texture)
    desc.format          = wgpu_texture_get_format(texture)
    desc.mip_level_count = wgpu_texture_get_mip_level_count(texture)
    desc.sample_count    = wgpu_texture_get_sample_count(texture)
    return
}

@(require_results)
wgpu_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    return ""
}

wgpu_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    wgpu.TextureSetLabel(wgpu.Texture(texture), label)
}

wgpu_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    wgpu.TextureAddRef(wgpu.Texture(texture))
}

wgpu_texture_release :: proc(texture: Texture, loc := #caller_location) {
    wgpu.TextureRelease(wgpu.Texture(texture))
}

// -----------------------------------------------------------------------------
// Texture View procedure
// -----------------------------------------------------------------------------


@(require_results)
wgpu_texture_view_get_label :: proc(texture_view: Texture_View, loc := #caller_location) -> string {
    return ""
}

wgpu_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    wgpu.TextureViewSetLabel(wgpu.TextureView(texture_view), label)
}

wgpu_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    wgpu.TextureViewAddRef(wgpu.TextureView(texture_view))
}

wgpu_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    wgpu.TextureViewRelease(wgpu.TextureView(texture_view))
}
