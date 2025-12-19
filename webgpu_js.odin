#+build js
#+private
package gpu

// Core
import "base:runtime"
import "core:log"
import sa "core:container/small_array"

webgpu_init :: proc(allocator := context.allocator) {
    // Global procedures
    _create_instance                        = js_create_instance

    // Adapter procedures
    adapter_get_info                        = js_adapter_get_info
    adapter_info_free_members               = js_adapter_info_free_members
    adapter_get_features                    = js_adapter_get_features
    adapter_has_feature                     = js_adapter_has_feature
    adapter_get_limits                      = js_adapter_get_limits
    adapter_request_device                  = js_adapter_request_device
    adapter_get_texture_format_capabilities = js_adapter_get_texture_format_capabilities
    adapter_get_label                       = js_adapter_get_label
    adapter_set_label                       = js_adapter_set_label
    adapter_add_ref                         = js_adapter_add_ref
    adapter_release                         = js_adapter_release

    // Bind Group procedures
    bind_group_get_label                    = js_bind_group_get_label
    bind_group_set_label                    = js_bind_group_set_label
    bind_group_add_ref                      = js_bind_group_add_ref
    bind_group_release                      = js_bind_group_release

    // Bind Group Layout procedures
    bind_group_layout_get_label             = js_bind_group_layout_get_label
    bind_group_layout_set_label             = js_bind_group_layout_set_label
    bind_group_layout_add_ref               = js_bind_group_layout_add_ref
    bind_group_layout_release               = js_bind_group_layout_release

    // Buffer procedures
    buffer_destroy                          = js_buffer_destroy
    buffer_get_map_state                    = js_buffer_get_map_state
    buffer_get_size                         = js_buffer_get_size
    buffer_get_usage                        = js_buffer_get_usage
    buffer_map_async                        = js_buffer_map_async
    buffer_unmap                            = js_buffer_unmap
    buffer_set_label                        = js_buffer_set_label
    buffer_get_label                        = js_buffer_get_label
    buffer_add_ref                          = js_buffer_add_ref
    buffer_release                          = js_buffer_release

    // Command Encoder procedures
    // command_encoder_begin_compute_pass   = js_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass       = js_command_encoder_begin_render_pass
    command_encoder_clear_buffer            = js_command_encoder_clear_buffer
    command_encoder_resolve_query_set       = js_ommand_encoder_resolve_query_set
    command_encoder_write_timestamp         = js_command_encoder_write_timestamp
    command_encoder_copy_buffer_to_buffer   = js_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture  = js_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer  = js_command_encoder_copy_texture_to_buffer
    command_encoder_copy_texture_to_texture = js_command_encoder_copy_texture_to_texture
    command_encoder_finish                  = js_command_encoder_finish
    command_encoder_get_label               = js_command_encoder_get_label
    command_encoder_set_label               = js_command_encoder_set_label
    command_encoder_add_ref                 = js_command_encoder_add_ref
    command_encoder_release                 = js_command_encoder_release

    // Command Encoder procedures
    command_buffer_get_label                = js_command_buffer_get_label
    command_buffer_set_label                = js_command_buffer_set_label
    command_buffer_add_ref                  = js_command_buffer_add_ref
    command_buffer_release                  = js_command_buffer_release

    // Device procedures
    device_create_bind_group                = js_device_create_bind_group
    device_create_bind_group_layout         = js_device_create_bind_group_layout
    device_create_pipeline_layout           = js_device_create_pipeline_layout
    device_create_buffer                    = js_device_create_buffer
    device_create_sampler                   = js_device_create_sampler
    device_create_shader_module             = js_device_create_shader_module
    device_create_texture                   = js_device_create_texture
    device_create_command_encoder           = js_device_create_command_encoder
    device_create_render_pipeline           = js_device_create_render_pipeline
    device_get_queue                        = js_device_get_queue
    device_get_features                     = js_device_get_features
    device_get_label                        = js_device_get_label
    device_set_label                        = js_device_set_label
    device_add_ref                          = js_device_add_ref
    device_release                          = js_device_release

    // Instance procedures
    instance_create_surface                 = js_instance_create_surface
    instance_request_adapter                = js_instance_request_adapter
    instance_get_label                      = js_instance_get_label
    instance_set_label                      = js_instance_set_label
    instance_add_ref                        = js_instance_add_ref
    instance_release                        = js_instance_release

    // Pipeline Layout procedures
    pipeline_layout_get_label               = js_pipeline_layout_get_label
    pipeline_layout_set_label               = js_pipeline_layout_set_label
    pipeline_layout_add_ref                 = js_pipeline_layout_add_ref
    pipeline_layout_release                 = js_pipeline_layout_release

    // Queue procedures
    queue_submit                            = js_queue_submit
    queue_write_buffer_impl                     = js_queue_write_buffer
    queue_write_texture                     = js_queue_write_texture
    queue_get_label                         = js_queue_get_label
    queue_set_label                         = js_queue_set_label
    queue_add_ref                           = js_queue_add_ref
    queue_release                           = js_queue_release

    // Render Pass procedures
    render_pass_set_pipeline                = js_render_pass_set_pipeline
    render_pass_set_bind_group              = js_render_pass_set_bind_group
    render_pass_set_vertex_buffer           = js_render_pass_set_vertex_buffer
    render_pass_set_index_buffer            = js_render_pass_set_index_buffer
    render_pass_set_stencil_reference       = js_render_pass_set_stencil_reference
    render_pass_draw                        = js_render_pass_draw
    render_pass_draw_indexed                = js_render_pass_draw_indexed
    render_pass_set_scissor_rect            = js_render_pass_set_scissor_rect
    render_pass_set_viewport                = js_render_pass_set_viewport
    render_pass_end                         = js_render_pass_end
    render_pass_get_label                   = js_render_pass_get_label
    render_pass_set_label                   = js_render_pass_set_label
    render_pass_add_ref                     = js_render_pass_add_ref
    render_pass_release                     = js_render_pass_release

    // Render Pipeline procedures
    render_pipeline_get_label               = js_render_pipeline_get_label
    render_pipeline_set_label               = js_render_pipeline_set_label
    render_pipeline_add_ref                 = js_render_pipeline_add_ref
    render_pipeline_release                 = js_render_pipeline_release

    // Sampler procedures
    sampler_get_label                       = js_sampler_get_label
    sampler_set_label                       = js_sampler_set_label
    sampler_add_ref                         = js_sampler_add_ref
    sampler_release                         = js_sampler_release

    // Shader Module procedures
    shader_module_get_label                 = js_shader_module_get_label
    shader_module_set_label                 = js_shader_module_set_label
    shader_module_add_ref                   = js_shader_module_add_ref
    shader_module_release                   = js_shader_module_release

    // Surface procedures
    surface_configure                       = js_surface_configure
    surface_present                         = js_surface_present
    surface_get_capabilities                = js_surface_get_capabilities
    surface_get_current_texture             = js_surface_get_current_texture
    surface_add_ref                         = js_surface_add_ref
    surface_release                         = js_surface_release

    // Surface Capabilities procedures
    surface_capabilities_free_members       = js_surface_capabilities_free_members

    // Texture procedures
    _texture_create_view                    = js_texture_create_view
    texture_get_label                       = js_texture_get_label
    texture_set_label                       = js_texture_set_label
    texture_add_ref                         = js_texture_add_ref
    texture_release                         = js_texture_release

    // Texture procedures
    texture_get_depth_or_array_layers       = js_texture_get_depth_or_array_layers
    texture_get_dimension                   = js_texture_get_dimension
    texture_get_format                      = js_texture_get_format
    texture_get_height                      = js_texture_get_height
    texture_get_mip_level_count             = js_texture_get_mip_level_count
    texture_get_sample_count                = js_texture_get_sample_count
    texture_get_usage                       = js_texture_get_usage
    texture_get_width                       = js_texture_get_width
    texture_get_size                        = js_texture_get_size
    texture_get_descriptor                  = js_texture_get_descriptor
    texture_view_get_label                  = js_texture_view_get_label
    texture_view_set_label                  = js_texture_view_set_label
    texture_view_add_ref                    = js_texture_view_add_ref
    texture_view_release                    = js_texture_view_release
}

// -----------------------------------------------------------------------------
// WebGPU interface
// -----------------------------------------------------------------------------

WebGPU_Shader_Source_WGSL :: struct {
    label: string,
    code: string,
}

WebGPU_Device_Descriptor :: struct {
    label:                          string,
    required_feature_count:         uint,
    required_features:              [^]Feature `fmt:"v,required_feature_count"`,
    required_limits:                ^Limits,
    default_queue:                  Queue_Descriptor,
    device_lost_callback_info:      Device_Lost_Callback_Info,
    uncaptured_error_callback_info: Uncaptured_Error_Callback_Info,
}

WebGPU_Supported_Features :: struct {
    feature_count: uint,
    features:      [^]Feature `fmt:"v,feature_count"`,
}

WebGPU_Depth_Stencil_State :: struct {
    format:                 Texture_Format,
    depth_write_enabled:    bool,
    depth_compare:          Compare_Function,
    stencil_front:          Stencil_Face_State,
    stencil_back:           Stencil_Face_State,
    stencil_read_mask:      u32,
    stencil_write_mask:     u32,
    depth_bias:             i32,
    depth_bias_slope_scale: f32,
    depth_bias_clamp:       f32,
}

WebGPU_Bind_Group_Entry :: struct {
    binding:      u32,
    buffer:       Buffer,
    offset:       u64,
    size:         u64,
    sampler:      Sampler,
    texture_view: Texture_View,
}

WebGPU_Bind_Group_Descriptor :: struct {
    label:       string,
    layout:      Bind_Group_Layout,
    entry_count: uint,
    entries:     [^]WebGPU_Bind_Group_Entry `fmt:"v,entry_count"`,
}

WebGPU_Bind_Group_Layout_Entry :: struct {
    binding:         u32,
    visibility:      Shader_Stages,
    buffer:          Buffer_Binding_Layout,
    sampler:         Sampler_Binding_Layout,
    texture:         Texture_Binding_Layout,
    storage_texture: Storage_Texture_Binding_Layout,
}

WebGPU_Bind_Group_Layout_Descriptor :: struct {
    label:       string,
    entry_count: uint,
    entries:     [^]WebGPU_Bind_Group_Layout_Entry `fmt:"v,entry_count"`,
}

WebGPU_Pipeline_Layout_Descriptor :: struct {
    label:                   string,
    bind_group_layout_count: uint,
    bind_group_layouts:      [^]Bind_Group_Layout `fmt:"v,bind_group_layout_count"`,
}

foreign import "webgpu"

@(default_calling_convention="contextless")
foreign webgpu {
    // Global procedures
    webgpuCreateInstance :: proc(descriptor: ^Instance_Descriptor) -> Instance ---

    // Adapter procedures
    webgpuAdapterRequestDevice :: proc(
        adapter: Adapter,
        descriptor: ^WebGPU_Device_Descriptor,
        callback_info: ^Request_Device_Callback_Info,
    ) ---
    webgpuAdapterGetFeatures :: proc(adapter: Adapter, features: ^WebGPU_Supported_Features) ---
    webgpuAdapterGetLimits :: proc(adapter: Adapter, limits: ^Limits) -> Status ---
    webgpuAdapterGetLabel :: proc(adapter: Adapter) -> string ---
    webgpuAdapterSetLabel :: proc(adapter: Adapter, label: string) ---
    webgpuAdapterAddRef :: proc(adapter: Adapter) ---
    webgpuAdapterRelease :: proc(adapter: Adapter) ---

    // Bind Group procedures
    webgpuBindGroupGetLabel :: proc(bind_group: Bind_Group) -> string ---
    webgpuBindGroupSetLabel :: proc(bind_group: Bind_Group, label: string) ---
    webgpuBindGroupAddRef :: proc(bind_group: Bind_Group) ---
    webgpuBindGroupRelease :: proc(bind_group: Bind_Group) ---

     // Bind Group layout procedures
    webgpuBindGroupLayoutGetLabel :: proc(bind_group_layout: Bind_Group_Layout) -> string ---
    webgpuBindGroupLayoutSetLabel :: proc(bind_group_layout: Bind_Group_Layout, label: string) ---
    webgpuBindGroupLayoutAddRef :: proc(bind_group_layout: Bind_Group_Layout) ---
    webgpuBindGroupLayoutRelease :: proc(bind_group_layout: Bind_Group_Layout) ---

    // Buffer procedures
    webgpuBufferDestroy :: proc(buffer: Buffer) ---
    webgpuBufferGetConstMappedRange :: proc(
        buffer: Buffer,
        offset: uint,
        size: uint,
    ) -> rawptr ---
    webgpuBufferGetMapState :: proc(buffer: Buffer) -> Buffer_Map_State ---
    webgpuBufferGetMappedRange :: proc(buffer: Buffer, offset: uint, size: uint) -> rawptr ---
    webgpuBufferGetSize :: proc(buffer: Buffer) -> u64 ---
    webgpuBufferGetUsage :: proc(buffer: Buffer) -> Buffer_Usages ---
    webgpuBufferUnmap :: proc(buffer: Buffer) ---
    webgpuBufferGetLabel :: proc(buffer: Buffer) -> string ---
    webgpuBufferSetLabel :: proc(buffer: Buffer, label: string) ---
    webgpuBufferAddRef :: proc(buffer: Buffer) ---
    webgpuBufferRelease :: proc(buffer: Buffer) ---

    // Command Encoder procedures
    webgpuCommandEncoderBeginComputePass :: proc(
        encoder: Command_Encoder,
        descriptor: ^Compute_Pass_Descriptor,
    ) -> Compute_Pass ---
    webgpuCommandEncoderBeginRenderPass :: proc(
        encoder: Command_Encoder,
        descriptor: ^Render_Pass_Descriptor,
    ) -> Render_Pass ---
    webgpuCommandEncoderFinish :: proc(command_encoder: Command_Encoder) -> Command_Buffer ---
    webgpuCommandEncoderGetLabel :: proc(command_encoder: Command_Encoder) -> string ---
    webgpuCommandEncoderSetLabel :: proc(command_encoder: Command_Encoder, label: string) ---
    webgpuCommandEncoderAddRef :: proc(command_encoder: Command_Encoder) ---
    webgpuCommandEncoderRelease :: proc(command_encoder: Command_Encoder) ---

    // Command Buffer procedures
    webgpuCommandBufferGetLabel :: proc(command_buffer: Command_Buffer) -> string ---
    webgpuCommandBufferSetLabel :: proc(command_buffer: Command_Buffer, label: string) ---
    webgpuCommandBufferAddRef :: proc(command_buffer: Command_Buffer) ---
    webgpuCommandBufferRelease :: proc(command_buffer: Command_Buffer) ---

    // Device procedures
    webgpuDeviceCreateBindGroup :: proc(
        device: Device,
        descriptor: ^WebGPU_Bind_Group_Descriptor,
    ) -> Bind_Group ---
    webgpuDeviceCreateBindGroupLayout :: proc(
        device: Device,
        descriptor: ^WebGPU_Bind_Group_Layout_Descriptor,
    ) -> Bind_Group_Layout ---
    webgpuDeviceCreatePipelineLayout :: proc(
        device: Device,
        descriptor: ^WebGPU_Pipeline_Layout_Descriptor,
    ) -> Pipeline_Layout ---
    webgpuDeviceCreateBuffer :: proc(
        device: Device,
        descriptor: ^Buffer_Descriptor,
    ) -> Buffer ---
    webgpuDeviceCreateSampler :: proc(
        device: Device,
        descriptor: ^Sampler_Descriptor = nil,
    ) -> Sampler ---
    webgpuDeviceCreateShaderModule :: proc(
        device: Device,
        source: ^WebGPU_Shader_Source_WGSL,
    ) -> Shader_Module ---
    webgpuDeviceCreateTexture :: proc(
        device: Device,
        source: ^Texture_Descriptor,
    ) -> Texture ---
    webgpuDeviceCreateCommandEncoder :: proc(
        device: Device,
        descriptor: ^Command_Encoder_Descriptor = nil,
    ) -> Command_Encoder ---
    webgpuDeviceCreateRenderPipeline :: proc(
        device: Device,
        descriptor: ^Render_Pipeline_Descriptor,
    ) -> Render_Pipeline ---
    webgpuDeviceGetQueue :: proc(device: Device) -> Queue ---
    webgpuDeviceGetFeatures :: proc(device: Device, features: ^WebGPU_Supported_Features) ---
    webgpuDeviceGetLimits :: proc(device: Device, limits: ^Limits) -> Status ---
    webgpuDeviceGetLabel :: proc(device: Device) -> string ---
    webgpuDeviceSetLabel :: proc(device: Device, label: string) ---
    webgpuDeviceAddRef :: proc(device: Device) ---
    webgpuDeviceRelease :: proc(device: Device) ---

    // Instance procedures
    webgpuInstanceCreateSurface :: proc(
        instance: Instance,
        selector: string,
    ) -> Surface ---
    webgpuInstanceRequestAdapter :: proc(
        instance: Instance,
        options: ^Request_Adapter_Options,
        callback_info: ^Request_Adapter_Callback_Info,
    ) -> Future ---
    webgpuInstanceGetLabel :: proc(instance: Instance) -> string ---
    webgpuInstanceSetLabel :: proc(instance: Instance, label: string) ---
    webgpuInstanceAddRef :: proc(instance: Instance) ---
    webgpuInstanceRelease :: proc(instance: Instance) ---

    // Pipeline Layout procedures
    webgpuPipelineLayoutGetLabel :: proc(pipeline_layout: Pipeline_Layout) -> string ---
    webgpuPipelineLayoutSetLabel :: proc(pipeline_layout: Pipeline_Layout, label: string) ---
    webgpuPipelineLayoutAddRef :: proc(pipeline_layout: Pipeline_Layout) ---
    webgpuPipelineLayoutRelease :: proc(pipeline_layout: Pipeline_Layout) ---

    // Queue procedures
    webgpuQueueSubmit :: proc(
        queue: Queue,
        command_count: uint,
        commands: [^]Command_Buffer,
    ) ---
    webgpuQueueWriteBuffer :: proc(
        queue: Queue,
        buffer: Buffer,
        bufferOffset: u64,
        data: rawptr,
        size: uint,
    ) ---
    webgpuQueueWriteTexture :: proc(
        queue: Queue,
        destination: ^Texel_Copy_Texture_Info,
        data: rawptr,
        data_size: uint,
        data_layout: ^Texel_Copy_Buffer_Layout,
        write_size: ^Extent_3D) ---
    webgpuQueueGetLabel :: proc(queue: Queue) -> string ---
    webgpuQueueSetLabel :: proc(queue: Queue, label: string) ---
    webgpuQueueAddRef :: proc(queue: Queue) ---
    webgpuQueueRelease :: proc(queue: Queue) ---

    // Render Pass procedures
    webgpuRenderPassEncoderSetBindGroup :: proc(
        render_pass_encoder: Render_Pass,
        group_index: u32,
        group: Bind_Group,
        dynamic_offset_count: uint,
        dynamic_offsets: [^]u32,
    ) ---
    webgpuRenderPassEncoderSetPipeline :: proc(
        render_pass_encoder: Render_Pass,
        pipeline: Render_Pipeline,
    ) ---
    webgpuRenderPassEncoderSetVertexBuffer :: proc(
        render_pass_encoder: Render_Pass, slot: u32,
        buffer: Buffer,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderPassEncoderSetIndexBuffer :: proc(
        render_pass_encoder: Render_Pass,
        buffer: Buffer,
        format: Index_Format,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderPassEncoderSetStencilReference :: proc(render_pass: Render_Pass, reference: u32) ---
    webgpuRenderPassEncoderDraw :: proc(
        render_pass_encoder: Render_Pass,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) ---
    webgpuRenderPassEncoderDrawIndexed :: proc(
        render_pass_encoder: Render_Pass,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        base_vertex: i32,
        first_instance: u32,
    ) ---
    webgpuRenderPassEncoderSetScissorRect :: proc(
        render_pass: Render_Pass,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) ---
    webgpuRenderPassEncoderSetViewport :: proc(
        render_pass: Render_Pass,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        min_depth: f32,
        max_depth: f32,
    )---
    webgpuRenderPassEncoderEnd :: proc(render_pass: Render_Pass) ---
    webgpuRenderPassEncoderGetLabel :: proc(render_pass: Render_Pass) -> string ---
    webgpuRenderPassEncoderSetLabel :: proc(render_pass: Render_Pass, label: string) ---
    webgpuRenderPassEncoderAddRef :: proc(render_pass: Render_Pass) ---
    webgpuRenderPassEncoderRelease :: proc(render_pass: Render_Pass) ---

    // Render Pipeline procedures
    webgpuRenderPipelineGetLabel :: proc(render_pipeline: Render_Pipeline) -> string ---
    webgpuRenderPipelineSetLabel :: proc(render_pipeline: Render_Pipeline, label: string) ---
    webgpuRenderPipelineAddRef :: proc(render_pipeline: Render_Pipeline) ---
    webgpuRenderPipelineRelease :: proc(render_pipeline: Render_Pipeline) ---

    // Sampler procedures
    webgpuSamplerGetLabel :: proc(sampler: Sampler) -> string ---
    webgpuSamplerSetLabel :: proc(sampler: Sampler, label: string) ---
    webgpuSamplerAddRef :: proc(sampler: Sampler) ---
    webgpuSamplerRelease :: proc(sampler: Sampler) ---

    // Shader Module procedures
    webgpuShaderModuleGetLabel :: proc(shader_module: Shader_Module) -> string ---
    webgpuShaderModuleSetLabel :: proc(shader_module: Shader_Module, label: string) ---
    webgpuShaderModuleAddRef :: proc(shader_module: Shader_Module) ---
    webgpuShaderModuleRelease :: proc(shader_module: Shader_Module) ---

    // Surface procedures
    webgpuSurfaceConfigure :: proc(
        surface: Surface,
        device: Device,
        config: ^Surface_Configuration) ---
    webgpuSurfaceGetCapabilities :: proc(
        surface: Surface,
        adapter: Adapter,
        capabilities: ^Surface_Capabilities,
    ) -> Status ---
    webgpuSurfaceGetCurrentTexture :: proc(surface: Surface, surface_texture: ^Surface_Texture) ---
    webgpuSurfaceGetLabel :: proc(instance: Surface) -> string ---
    webgpuSurfaceSetLabel :: proc(instance: Surface, label: string) ---
    webgpuSurfaceAddRef :: proc(instance: Surface) ---
    webgpuSurfaceRelease :: proc(instance: Surface) ---

    // Surface Capabilities procedures
    webgpuSurfaceCapabilitiesFreeMembers :: proc(caps: Surface_Capabilities) ---

    // Supported Features procedures
    webgpuSupportedFeaturesFreeMembers :: proc(supported: WebGPU_Supported_Features) ---

    // Texture procedures
    webgpuTextureCreateView :: proc(
        texture: Texture,
        descriptor: ^Texture_View_Descriptor = nil,
    ) -> Texture_View ---
    webgpuTextureGetDepthOrArrayLayers :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetDimension :: proc(texture: Texture) -> Texture_Dimension ---
    webgpuTextureGetFormat :: proc(texture: Texture) -> Texture_Format ---
    webgpuTextureGetHeight :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetMipLevelCount :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetSampleCount :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetUsage :: proc(texture: Texture) -> Texture_Usages ---
    webgpuTextureGetWidth :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetLabel :: proc(texture: Texture) -> string ---
    webgpuTextureSetLabel :: proc(texture: Texture, label: string) ---
    webgpuTextureAddRef :: proc(texture: Texture) ---
    webgpuTextureRelease :: proc(texture: Texture) ---

     // Texture View procedures
    webgpuTextureViewGetLabel :: proc(texture_view: Texture_View) -> string ---
    webgpuTextureViewSetLabel :: proc(texture_view: Texture_View, label: string) ---
    webgpuTextureViewAddRef :: proc(texture_view: Texture_View) ---
    webgpuTextureViewRelease :: proc(texture_view: Texture_View) ---
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------

@(require_results)
js_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> Instance {
    desc := descriptor.? or_else {}
    handle := webgpuCreateInstance(&desc)
    if handle == nil do return nil
    return handle
}

@(require_results)
js_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    selector: string

    #partial switch &t in descriptor.target {
    case Surface_Source_Canvas_HTML_Selector:
        if t.selector == "" {
            log.error("Invalid HTML selector")
            return nil
        }
        selector = t.selector
    case:
        log.error("Unsupported surface descriptor type")
        return nil
    }

    surface := webgpuInstanceCreateSurface(instance, selector)
    if surface == nil do return nil

    return surface
}

js_instance_request_adapter :: proc(
    instance: Instance,
    options: Maybe(Request_Adapter_Options),
    callback_info: Request_Adapter_Callback_Info,
    loc := #caller_location,
) {
    options := options.? or_else {}
    callback_info := callback_info
    webgpuInstanceRequestAdapter(instance, &options, &callback_info)
}

@(require_results)
js_instance_get_label :: proc(instance: Instance, loc := #caller_location) -> string {
    return webgpuInstanceGetLabel(instance)
}

js_instance_set_label :: proc(instance: Instance, label: string, loc := #caller_location) {
    webgpuInstanceSetLabel(instance, label)
}

js_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    webgpuInstanceAddRef(instance)
}

js_instance_release :: proc(instance: Instance, loc := #caller_location) {
    webgpuInstanceRelease(instance)
}

// -----------------------------------------------------------------------------
// Pipeline Layout procedures
// -----------------------------------------------------------------------------

@(require_results)
js_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    return webgpuPipelineLayoutGetLabel(pipeline_layout)
}

js_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    webgpuPipelineLayoutSetLabel(pipeline_layout, label)
}

js_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    webgpuPipelineLayoutAddRef(pipeline_layout)
}

js_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    webgpuPipelineLayoutRelease(pipeline_layout)
}

// -----------------------------------------------------------------------------
// Adapter
// -----------------------------------------------------------------------------

js_adapter_request_device :: proc(
    adapter: Adapter,
    descriptor: Maybe(Device_Descriptor),
    callback_info: Request_Device_Callback_Info,
    loc := #caller_location,
) {
    callback_info := callback_info

    desc, desc_ok := descriptor.?
    if !desc_ok {
        webgpuAdapterRequestDevice(adapter, nil, &callback_info)
    }

    raw_desc := WebGPU_Device_Descriptor {
        label                          = desc.label,
        device_lost_callback_info      = desc.device_lost_callback_info,
        uncaptured_error_callback_info = desc.uncaptured_error_callback_info,
    }

    required_features := desc.required_features
    features: sa.Small_Array(MAX_FEATURES, Feature)
    if required_features != {} {
        for f in required_features {
            sa.push_back(&features, f)
        }
        raw_desc.required_feature_count = uint(sa.len(features))
        raw_desc.required_features = raw_data(sa.slice(&features))
    }

    // If no limits is provided, default to the most restrictive limits
    limits := desc.required_limits if desc.required_limits != {} else LIMITS_MINIMUM_DEFAULT
    raw_desc.required_limits = &limits

    webgpuAdapterRequestDevice(adapter, &raw_desc, &callback_info)
}

@(require_results)
js_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
) {
    unimplemented()
}

js_adapter_info_free_members :: proc(self: Adapter_Info, allocator := context.allocator) {
    unimplemented()
}

@(require_results)
js_adapter_get_features :: proc(
    adapter: Adapter,
    loc := #caller_location,
) -> (
    features: Features,
) {
    supported: WebGPU_Supported_Features
    webgpuAdapterGetFeatures(adapter, &supported)
    defer webgpuSupportedFeaturesFreeMembers(supported)
    raw_features := supported.features[:supported.feature_count]
    features = _webgpu_features_slice_to_flags(raw_features)
    return
}

@(require_results)
js_adapter_has_feature :: proc(
    adapter: Adapter,
    features: Features,
    loc := #caller_location,
) -> bool {
    unimplemented()
}

@(require_results)
js_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> (limits: Limits) {
    unimplemented()
}

@(require_results)
js_adapter_get_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> Texture_Format_Capabilities {
    unimplemented()

}

@(require_results)
js_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    return webgpuAdapterGetLabel(adapter)
}

js_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
    webgpuAdapterSetLabel(adapter, label)
}

js_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    webgpuAdapterAddRef(adapter)
}

js_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    webgpuAdapterRelease(adapter)
}

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------

@(require_results)
js_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    return webgpuBindGroupGetLabel(bind_group)
}

js_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    webgpuBindGroupSetLabel(bind_group, label)
}

js_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    webgpuBindGroupAddRef(bind_group)
}

js_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    webgpuBindGroupRelease(bind_group)
}

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------

@(require_results)
js_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    return webgpuBindGroupLayoutGetLabel(bind_group_layout)
}

js_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    webgpuBindGroupLayoutSetLabel(bind_group_layout, label)
}

js_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    webgpuBindGroupLayoutAddRef(bind_group_layout)
}

js_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    webgpuBindGroupLayoutRelease(bind_group_layout)
}

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------

js_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferDestroy(buffer)
}

buffer_get_const_mapped_range :: proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr {
    return webgpuBufferGetConstMappedRange(buffer, offset, size)
}

js_buffer_get_map_state :: proc(
    buffer: Buffer,
    loc := #caller_location,
) -> Buffer_Map_State {
    return webgpuBufferGetMapState(buffer)
}

js_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    return webgpuBufferGetSize(buffer)
}

js_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    return webgpuBufferGetUsage(buffer)
}

js_buffer_map_async :: proc(
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

buffer_get_mapped_range :: proc(
    buffer: Buffer,
    #any_int offset: uint,
    #any_int size: uint,
    loc := #caller_location,
) -> rawptr {
    return webgpuBufferGetMappedRange(buffer, offset, size)
}

js_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferUnmap(buffer)
}

@(require_results)
js_buffer_get_label :: proc(buffer: Buffer, loc := #caller_location) -> string {
    return webgpuBufferGetLabel(buffer)
}

js_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    webgpuBufferSetLabel(buffer, label)
}

js_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferAddRef(buffer)
}

js_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferRelease(buffer)
}

// -----------------------------------------------------------------------------
// Command Encoder
// -----------------------------------------------------------------------------

js_command_encoder_begin_compute_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Maybe(Compute_Pass_Descriptor) = nil,
    loc := #caller_location,
) -> Compute_Pass {
    if desc, desc_ok := descriptor.?; desc_ok {
        return webgpuCommandEncoderBeginComputePass(encoder, &desc)
    } else {
        return webgpuCommandEncoderBeginComputePass(encoder, nil)
    }
    unreachable()
}

js_command_encoder_begin_render_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    descriptor := descriptor
    return webgpuCommandEncoderBeginRenderPass(encoder, &descriptor)
}

js_command_encoder_clear_buffer :: proc(
    encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented()
}

js_ommand_encoder_resolve_query_set :: proc(
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

js_command_encoder_write_timestamp :: proc(
    encoder: Command_Encoder,
    querySet: Query_Set,
    queryIndex: u32,
    loc := #caller_location,
) {
    unimplemented()
}

js_command_encoder_copy_buffer_to_buffer :: proc(
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

js_command_encoder_copy_buffer_to_texture :: proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

js_command_encoder_copy_texture_to_buffer :: proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Texture_Info,
    destination: ^Texel_Copy_Buffer_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

js_command_encoder_copy_texture_to_texture :: proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Texture_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

@(require_results)
js_command_encoder_finish :: proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer {
    return webgpuCommandEncoderFinish(encoder)
}

@(require_results)
js_command_encoder_get_label :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    return webgpuCommandEncoderGetLabel(command_encoder)
}

js_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    webgpuCommandEncoderSetLabel(command_encoder, label)
}

js_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    webgpuCommandEncoderAddRef(command_encoder)
}

js_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    webgpuCommandEncoderRelease(command_encoder)
}

// -----------------------------------------------------------------------------
// Command Buffer
// -----------------------------------------------------------------------------

@(require_results)
js_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    return webgpuCommandBufferGetLabel(command_buffer)
}

js_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    webgpuCommandBufferSetLabel(command_buffer, label)
}

js_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    webgpuCommandBufferAddRef(command_buffer)
}

js_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    webgpuCommandBufferRelease(command_buffer)
}

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------

js_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    assert(descriptor.layout != nil, "Invalid bind group layout", loc)

    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    ta := context.temp_allocator

    entries_total := len(descriptor.entries)
    entries: []WebGPU_Bind_Group_Entry

    if entries_total > 0 {
        entries = make([]WebGPU_Bind_Group_Entry, entries_total, ta)
    }

    for &entry, i in descriptor.entries {
        raw_entry := &entries[i]
        raw_entry.binding = entry.binding

        switch &res in entry.resource {
        case Buffer_Binding:
            actual_size := buffer_get_size(res.buffer, loc)

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

            raw_entry.buffer = res.buffer
            raw_entry.size = actual_size
            raw_entry.offset = res.offset

        case Sampler:
            raw_entry.sampler = res

        case Texture_View:
            raw_entry.texture_view = res

        case []Buffer_Binding:
        case []Sampler:
        case []Texture_View:
        }
    }

    desc := WebGPU_Bind_Group_Descriptor {
        label       = descriptor.label,
        layout      = descriptor.layout,
        entry_count = len(entries),
        entries     = raw_data(entries),
    }

    return webgpuDeviceCreateBindGroup(device, &desc)
}

js_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
    ta := context.temp_allocator

    entry_count := len(descriptor.entries)

    if entry_count == 0 {
        raw_desc := WebGPU_Bind_Group_Layout_Descriptor {
            label      = descriptor.label,
            entry_count = 0,
            entries    = nil,
        }
        webgpuDeviceCreateBindGroupLayout(device, &raw_desc)
    }

    entries := make([]WebGPU_Bind_Group_Layout_Entry, entry_count, ta)

    for &entry, i in descriptor.entries {
        raw_entry := &entries[i]

        raw_entry.binding = entry.binding
        raw_entry.visibility = entry.visibility

        // Handle binding types
        #partial switch binding_type in entry.type {
        case Buffer_Binding_Layout:
            raw_entry.buffer = binding_type
        case Sampler_Binding_Layout:
            raw_entry.sampler = binding_type
        case Texture_Binding_Layout:
            raw_entry.texture = binding_type
        case Storage_Texture_Binding_Layout:
            raw_entry.storage_texture = binding_type
        }
    }

    raw_desc := WebGPU_Bind_Group_Layout_Descriptor {
        label       = descriptor.label,
        entry_count = uint(entry_count),
        entries     = raw_data(entries),
    }

    return webgpuDeviceCreateBindGroupLayout(device, &raw_desc)
}

js_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    bind_group_layout_count := len(descriptor.bind_group_layouts)

    desc := WebGPU_Pipeline_Layout_Descriptor {
        label = descriptor.label,
        bind_group_layout_count = uint(bind_group_layout_count),
        bind_group_layouts =
            bind_group_layout_count > 0 ? raw_data(descriptor.bind_group_layouts) : nil,
    }

    return webgpuDeviceCreatePipelineLayout(device, &desc)
}

@(require_results)
js_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    descriptor := descriptor
    return webgpuDeviceCreateBuffer(device, &descriptor)
}

@(require_results)
js_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor = SAMPLER_DESCRIPTOR_DEFAULT,
    loc := #caller_location,
) -> Sampler {
    descriptor := descriptor
    return webgpuDeviceCreateSampler(device, &descriptor)
}

@(require_results)
js_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    source := WebGPU_Shader_Source_WGSL{
        label = descriptor.label,
        code = string(descriptor.code),
    }
    return webgpuDeviceCreateShaderModule(device, &source)
}

@(require_results)
js_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    descriptor := descriptor
    return webgpuDeviceCreateTexture(device, &descriptor)
}

@(require_results)
js_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder {
    desc := descriptor.? or_else {}
    return webgpuDeviceCreateCommandEncoder(device, &desc if descriptor != nil else nil)
}

@(require_results)
js_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    descriptor := descriptor
    return webgpuDeviceCreateRenderPipeline(device, &descriptor)
}

@(require_results)
js_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    return webgpuDeviceGetQueue(device)
}

js_device_get_features :: proc(device: Device, loc := #caller_location) -> (features: Features) {
    supported: WebGPU_Supported_Features
    webgpuDeviceGetFeatures(device, &supported)
    defer webgpuSupportedFeaturesFreeMembers(supported)
    raw_features := supported.features[:supported.feature_count]
    features = _webgpu_features_slice_to_flags(raw_features)
    return
}

@(require_results)
js_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    return webgpuDeviceGetLabel(device)
}

js_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    webgpuDeviceSetLabel(device, label)
}

js_device_add_ref :: proc(device: Device, loc := #caller_location) {
    webgpuDeviceAddRef(device)
}

js_device_release :: proc(device: Device, loc := #caller_location) {
    webgpuDeviceRelease(device)
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------

js_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    webgpuQueueSubmit(queue, len(commands), raw_data(commands))
}

js_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    webgpuQueueWriteBuffer(queue, buffer, buffer_offset, data, size)
}

js_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    assert(destination.texture != nil, "Invalid destination texture", loc)

    destination := destination
    dataLayout := data_layout
    size := write_size

    if len(data) == 0 {
        webgpuQueueWriteTexture(queue, &destination, nil, 0, &dataLayout, &size)
    } else {
        webgpuQueueWriteTexture(
            queue,
            &destination,
            raw_data(data),
            uint(len(data)),
            &dataLayout,
            &size,
        )
    }
}

@(require_results)
js_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    return webgpuQueueGetLabel(queue)
}

js_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    webgpuQueueSetLabel(queue, label)
}

js_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    webgpuQueueAddRef(queue)
}

js_queue_release :: proc(queue: Queue, loc := #caller_location) {
    webgpuQueueRelease(queue)
}

// -----------------------------------------------------------------------------
// Render Pass
// -----------------------------------------------------------------------------

js_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetPipeline(render_pass, pipeline)
}

js_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetBindGroup(
        render_pass,
        group_index,
        group,
        len(dynamic_offsets),
        raw_data(dynamic_offsets),
    )
}

js_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    // Calculate remaining size from offset
    buffer_size := js_buffer_get_size(buffer)
    actual_size := size != WHOLE_SIZE ? size : (buffer_size - offset)

    webgpuRenderPassEncoderSetVertexBuffer(render_pass, slot, buffer, offset, actual_size)
}

js_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    buffer_size := buffer_get_size(buffer)
    actual_size := (size > 0 && size != WHOLE_SIZE) ? size : (buffer_size - offset)

    webgpuRenderPassEncoderSetIndexBuffer(render_pass, buffer, format, offset, actual_size)
}

js_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetStencilReference(render_pass, reference)
}

js_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    webgpuRenderPassEncoderDraw(
        render_pass,
        vertices.end - vertices.start,
        instances.end - instances.start,
        vertices.start,
        instances.start,
    )
}

js_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    webgpuRenderPassEncoderDrawIndexed(
        render_pass,
        indices.end - indices.start,
        instances.end - instances.start,
        indices.start,
        base_vertex,
        instances.start,
    )
}

js_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetScissorRect(render_pass, x, y, width, height)
}

js_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetViewport(render_pass, x, y, width, height, min_depth, max_depth)
}

js_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    webgpuRenderPassEncoderEnd(render_pass)
}

@(require_results)
js_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    return webgpuRenderPassEncoderGetLabel(render_pass)
}

js_render_pass_set_label :: proc(render_pass: Render_Pass, label: string, loc := #caller_location) {
    webgpuRenderPassEncoderSetLabel(render_pass, label)
}

js_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
    webgpuRenderPassEncoderAddRef(render_pass)
}

js_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
    webgpuRenderPassEncoderRelease(render_pass)
}

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------

@(require_results)
js_render_pipeline_get_label :: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string {
    return webgpuRenderPipelineGetLabel(render_pipeline)
}

js_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    webgpuRenderPipelineSetLabel(render_pipeline, label)
}

js_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    webgpuRenderPipelineAddRef(render_pipeline)
}

js_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    webgpuRenderPipelineRelease(render_pipeline)
}

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------

@(require_results)
js_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    return webgpuSamplerGetLabel(sampler)
}

js_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    webgpuSamplerSetLabel(sampler, label)
}

js_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    webgpuSamplerAddRef(sampler)
}

js_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    webgpuSamplerRelease(sampler)
}

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------

@(require_results)
js_shader_module_get_label :: proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string {
    return webgpuShaderModuleGetLabel(shader_module)
}

js_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    webgpuShaderModuleSetLabel(shader_module, label)
}

js_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    webgpuShaderModuleAddRef(shader_module)
}

js_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    webgpuShaderModuleRelease(shader_module)
}

// -----------------------------------------------------------------------------
// Surface
// -----------------------------------------------------------------------------

// JS_Surface_Impl :: struct {
//     label:     String_Buffer_Small,
//     ref:       Ref_Count,
//     instance:  ^Instance,
//     device:    ^Device,
//     queue:     ^Queue,
//     allocator: runtime.Allocator,
//     config:    Surface_Configuration,
//     handle:     Surface,
// }

js_surface_configure :: proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    config := config
    webgpuSurfaceConfigure(surface, device, &config)
}

js_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    webgpuSurfaceGetCapabilities(surface, adapter, &caps)
    return
}

@(require_results)
js_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> Surface_Texture {
    ret: Surface_Texture
    webgpuSurfaceGetCurrentTexture(surface, &ret)
    return ret
}

js_surface_present :: proc(surface: Surface, loc := #caller_location) {
    // NOTE: Not really anything to do here.
}

@(require_results)
js_surface_get_label :: proc(surface: Surface, loc := #caller_location) -> string {
    return webgpuSurfaceGetLabel(surface)
}

js_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    webgpuSurfaceSetLabel(surface, label)
}

js_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    webgpuSurfaceAddRef(surface)
}

js_surface_release :: proc(surface: Surface, loc := #caller_location) {
    webgpuSurfaceRelease(surface)
}

// -----------------------------------------------------------------------------
// Surface Capabilities
// -----------------------------------------------------------------------------

js_surface_capabilities_free_members :: proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
) {
    webgpuSurfaceCapabilitiesFreeMembers(caps)
}

// -----------------------------------------------------------------------------
// Texture
// -----------------------------------------------------------------------------

@(require_results)
js_texture_create_view :: proc(
    texture: Texture,
    descriptor: Maybe(Texture_View_Descriptor) = nil,
    loc := #caller_location,
) -> (
    texture_view: Texture_View,
) {
    if desc, desc_ok := descriptor.?; desc_ok {
        texture_view = webgpuTextureCreateView(texture, &desc)
    } else {
        texture_view = webgpuTextureCreateView(texture, nil)
    }
    return
}

js_texture_get_depth_or_array_layers :: proc(
    texture: Texture,
    loc := #caller_location,
) -> u32 {
    return webgpuTextureGetDepthOrArrayLayers(texture)
}

js_texture_get_dimension :: proc(texture: Texture, loc := #caller_location) -> Texture_Dimension {
    return webgpuTextureGetDimension(texture)
}

js_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    return webgpuTextureGetFormat(texture)
}

js_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetHeight(texture)
}

js_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetMipLevelCount(texture)
}

js_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetSampleCount(texture)
}

js_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    return webgpuTextureGetUsage(texture)
}

js_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetWidth(texture)
}

js_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    return {
        width                 = webgpuTextureGetWidth(texture),
        height                = webgpuTextureGetHeight(texture),
        depth_or_array_layers = webgpuTextureGetDepthOrArrayLayers(texture),
    }
}

js_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> (
    desc: Texture_Descriptor,
) {
    desc.usage           = js_texture_get_usage(texture)
    desc.dimension       = js_texture_get_dimension(texture)
    desc.size            = js_texture_get_size(texture)
    desc.format          = js_texture_get_format(texture)
    desc.mip_level_count = js_texture_get_mip_level_count(texture)
    desc.sample_count    = js_texture_get_sample_count(texture)
    return
}

@(require_results)
js_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    return webgpuTextureGetLabel(texture)
}

js_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    webgpuTextureSetLabel(texture, label)
}

js_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    webgpuTextureAddRef(texture)
}

js_texture_release :: proc(texture: Texture, loc := #caller_location) {
    webgpuTextureRelease(texture)
}

// -----------------------------------------------------------------------------
// Texture View
// -----------------------------------------------------------------------------

@(require_results)
js_texture_view_get_label :: proc(texture_view: Texture_View, loc := #caller_location) -> string {
    return webgpuTextureViewGetLabel(texture_view)
}

js_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    webgpuTextureViewSetLabel(texture_view, label)
}

js_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    webgpuTextureViewAddRef(texture_view)
}

js_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    webgpuTextureViewRelease(texture_view)
}
