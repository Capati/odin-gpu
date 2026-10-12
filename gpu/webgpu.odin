#+build js
package gpu

// Core
import "base:runtime"

// --- Confirmed passing on your wasm32 build ---
#assert(size_of(Device_Lost_Callback_Info) == 12)
#assert(size_of(Uncaptured_Error_Callback_Info) == 12)
#assert(size_of(Queue_Descriptor) == 8)

// --- Handles ({device: rawptr, handle: u64}) ---
#assert(size_of(Queue) == 16)
#assert(offset_of(Queue, handle) == 8)
#assert(size_of(Command_Buffer) == 16)
#assert(offset_of(Command_Buffer, handle) == 8)
#assert(size_of(Bind_Group_Layout) == 16)

// --- Device descriptor (from my first layout; unverified, I later switched to the cursor) ---
#assert(offset_of(Device_Descriptor, required_limits) == 16)
#assert(size_of(Limits) == 160)
#assert(offset_of(Limits, max_uniform_buffer_binding_size) == 56)
#assert(offset_of(Limits, max_buffer_size) == 88)
#assert(offset_of(Device_Descriptor, lost_callback_info) == 184)
#assert(offset_of(Device_Descriptor, uncaptured_error_callback_info) == 196)
#assert(offset_of(Device_Descriptor, default_queue) == 176)
#assert(size_of(Device_Descriptor) == 240)

// --- Enum sizes ---
#assert(size_of(Texture_Format) == 4)
#assert(size_of(Present_Mode) == 4)
#assert(size_of(Composite_Alpha_Mode) == 4)
#assert(size_of(Surface_Color_Space) == 4)
#assert(size_of(Surface_Get_Current_Texture_Status) == 4)
#assert(size_of(Feature_Name) == 4)
#assert(int(Present_Mode.Fifo) == 0)

// --- Texture usages (u64 bit_set) ---
#assert(size_of(Texture_Usages) == 8)

// --- Surface capabilities ---
#assert(size_of(Surface_Format_Capabilities) == 8)
#assert(offset_of(Surface_Capabilities, format_capabilities) == 8)
#assert(offset_of(Surface_Capabilities, usages) == 32)
#assert(size_of(Surface_Capabilities) == 40)

// --- Surface configuration (matches your word dump) ---
#assert(offset_of(Surface_Configuration, usage) == 8)
#assert(offset_of(Surface_Configuration, format) == 16)
#assert(offset_of(Surface_Configuration, color_space) == 20)
#assert(offset_of(Surface_Configuration, width) == 24)
#assert(offset_of(Surface_Configuration, present_mode) == 32)
#assert(offset_of(Surface_Configuration, alpha_mode) == 40)
#assert(offset_of(Surface_Configuration, view_formats) == 44)
#assert(size_of(Surface_Configuration) == 56)

// --- Surface texture ---
#assert(size_of(Surface_Texture) == 32)
#assert(offset_of(Surface_Texture, texture) == 8)
#assert(offset_of(Surface_Texture, status) == 24)

// --- Render pass ---
#assert(size_of(Render_Pass_Descriptor) == 48)
#assert(offset_of(Render_Pass_Descriptor, occlusion_query_set) == 24)
#assert(offset_of(Render_Pass_Descriptor, multiview_mask) == 40)
#assert(size_of(Render_Pass_Color_Attachment) == 80)
#assert(offset_of(Render_Pass_Color_Attachment, resolve_target) == 24)
#assert(offset_of(Render_Pass_Color_Attachment, ops) == 40)
#assert(offset_of(Operations(Color), clear_value) == 8)
#assert(size_of(Operations(f32)) == 12)
#assert(size_of(Render_Pass_Depth_Stencil_Attachment) == 48)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, depth_ops) == 16)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, stencil_ops) == 28)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, depth_read_only) == 40)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, stencil_read_only) == 41)
#assert(size_of(Render_Pass_Timestamp_Writes) == 24)

// --- Vertex state ---
#assert(size_of(Vertex_State) == 48)
#assert(offset_of(Vertex_State, entry_point) == 16)
#assert(offset_of(Vertex_State, compilation_options) == 24)
#assert(size_of(Pipeline_Compilation_Options) == 12)
#assert(offset_of(Vertex_State, buffers) == 36)
#assert(size_of(Constant_Entry) == 16)
#assert(size_of(Vertex_Buffer_Layout) == 24)
#assert(offset_of(Vertex_Buffer_Layout, step_mode) == 8)
#assert(offset_of(Vertex_Buffer_Layout, attributes) == 12)
#assert(size_of(Vertex_Attribute) == 24)
#assert(offset_of(Vertex_Attribute, offset) == 8)
#assert(offset_of(Vertex_Attribute, shader_location) == 16)

// --- Texture descriptor ---
#assert(size_of(Extent_3D) == 12)
#assert(offset_of(Texture_Descriptor, size) == 8)
#assert(offset_of(Texture_Descriptor, mip_level_count) == 20)
#assert(offset_of(Texture_Descriptor, dimension) == 28)
#assert(offset_of(Texture_Descriptor, format) == 32)
#assert(offset_of(Texture_Descriptor, usage) == 40)
#assert(offset_of(Texture_Descriptor, view_formats) == 48)
#assert(size_of(Texture_Descriptor) == 56)

// --- Bind group layout / bind group (assumes Shader_Stages is u64, External_Texture <= 16 bytes) ---
#assert(size_of(Shader_Stages) == 8)
#assert(size_of(Buffer_Binding_Layout) == 16)
#assert(size_of(Texture_Binding_Layout) == 12)
#assert(size_of(Binding_Type) == 24)
#assert(size_of(Bind_Group_Layout_Entry) == 48)
#assert(offset_of(Bind_Group_Layout_Entry, visibility) == 8)
#assert(offset_of(Bind_Group_Layout_Entry, type) == 16)
#assert(offset_of(Bind_Group_Layout_Entry, count) == 40)
#assert(size_of(Bind_Group_Layout_Descriptor) == 16)
#assert(size_of(Buffer_Binding) == 32)
#assert(size_of(Binding_Resource) == 40)
#assert(size_of(Bind_Group_Entry) == 48)
#assert(offset_of(Bind_Group_Entry, resource) == 8)
#assert(size_of(Bind_Group_Descriptor) == 32)
#assert(offset_of(Bind_Group_Descriptor, layout) == 8)
#assert(offset_of(Bind_Group_Descriptor, entries) == 24)

// --- Pipeline layout ---
#assert(offset_of(Pipeline_Layout_Descriptor, bind_group_layouts) == 8)
#assert(offset_of(Pipeline_Layout_Descriptor, immediate_size) == 16)
#assert(size_of(Pipeline_Layout_Descriptor) == 20)

// --- Texel copy (assumes Origin_3D / Texel_Copy_Buffer_Layout shapes) ---
#assert(size_of(Origin_3D) == 12)
#assert(size_of(Texel_Copy_Buffer_Layout) == 16)
#assert(offset_of(Texel_Copy_Buffer_Layout, bytes_per_row) == 8)
#assert(size_of(Texel_Copy_Texture_Info) == 40)
#assert(offset_of(Texel_Copy_Texture_Info, origin) == 20)
#assert(offset_of(Texel_Copy_Texture_Info, aspect) == 32)
#assert(size_of(Texel_Copy_Buffer_Info) == 32)
#assert(offset_of(Texel_Copy_Buffer_Info, layout) == 16)

// --- Sampler ---
#assert(offset_of(Sampler_Descriptor, address_mode_u) == 8)
#assert(offset_of(Sampler_Descriptor, lod_min_clamp) == 32)
#assert(offset_of(Sampler_Descriptor, compare) == 40)
#assert(offset_of(Sampler_Descriptor, anisotropy_clamp) == 44)
#assert(offset_of(Sampler_Descriptor, border_color) == 48)

// --- Slices ---
#assert(size_of([]Command_Buffer) == 8)

// --- Features (the 72 is my count; the assert will tell you the real one) ---
#assert(FEATURE_COUNT == 72)
#assert(size_of(Features) == 292)

#assert(size_of(Handle) == 16 && offset_of(Handle, handle) == 8)
#assert(size_of(Device) == 4)
#assert(size_of(Texture_Usages) == 8 && size_of(Shader_Stages) == 8)
#assert(size_of(Limits) == 160)
#assert(size_of(Device_Descriptor) == 240)
#assert(offset_of(Device_Descriptor, default_queue) == 176)
#assert(size_of(Surface_Configuration) == 56)
#assert(size_of(Surface_Texture) == 32)
#assert(size_of(Render_Pass_Descriptor) == 48)
#assert(size_of(Render_Pass_Color_Attachment) == 80)
#assert(size_of(Operations(Color)) == 40)
#assert(size_of(Render_Pass_Depth_Stencil_Attachment) == 48)
#assert(size_of(Vertex_State) == 48)
#assert(size_of(Texture_Descriptor) == 56)
#assert(size_of(Sampler_Descriptor) == 52)
#assert(size_of(Binding_Type) == 24 && size_of(Binding_Resource) == 40)
#assert(size_of(Bind_Group_Layout_Entry) == 48 && size_of(Bind_Group_Entry) == 48)
#assert(size_of(Features) == 292)

foreign import "webgpu"
@(default_calling_convention = "c")
foreign webgpu {
    // -----------------------------------------------------------------------------
    // Global procedures
    // -----------------------------------------------------------------------------

    webgpuCreateInstance :: proc(descriptor: ^Instance_Descriptor) -> Instance ---
    webgpuGetInstanceFeatures :: proc(features: ^Supported_Instance_Features) ---
    webgpuGetInstanceLimits :: proc(limits: ^Instance_Limits) ---
    webgpuHasInstanceFeature :: proc(feature: Instance_Feature_Name) -> bool ---
    webgpuGetProcAddress :: proc(proc_name: string) -> Proc ---

    // -----------------------------------------------------------------------------
    // Procedures of Adapter
    // -----------------------------------------------------------------------------

    webgpuAdapterGetFeatures :: proc(
        adapter: Adapter,
        features: ^Features,
    ) ---
    webgpuAdapterGetInfo :: proc(
        adapter: Adapter,
        info: ^Adapter_Info,
    ) ---
    webgpuAdapterGetLimits :: proc(adapter: Adapter, limits: ^Limits) ---
    webgpuAdapterHasFeature :: proc(adapter: Adapter, feature: Feature_Name) -> bool ---
    webgpuAdapterRequestDevice :: proc(
        adapter: Adapter,
        #by_ptr descriptor: Device_Descriptor = {},
    ) -> Device ---
    webgpuAdapterAddRef :: proc(adapter: Adapter) ---
    webgpuAdapterRelease :: proc(adapter: Adapter) ---

    // -----------------------------------------------------------------------------
    // Procedures of Adapter_Info
    // -----------------------------------------------------------------------------

    webgpuAdapterInfoFreeMembers :: proc(adapter_info: Adapter_Info) ---

    // -----------------------------------------------------------------------------
    // Procedures of Bind_Group
    // -----------------------------------------------------------------------------

    webgpuBindGroupSetLabel :: proc(bind_group: Bind_Group, label: string) ---
    webgpuBindGroupAddRef :: proc(bind_group: Bind_Group) ---
    webgpuBindGroupRelease :: proc(bind_group: Bind_Group) ---

    // -----------------------------------------------------------------------------
    // Procedures of Bind_Group_Layout
    // -----------------------------------------------------------------------------

    webgpuBindGroupLayoutSetLabel :: proc(
        bind_group_layout: Bind_Group_Layout,
        label: string,
    ) ---
    webgpuBindGroupLayoutAddRef :: proc(bind_group_layout: Bind_Group_Layout) ---
    webgpuBindGroupLayoutRelease :: proc(bind_group_layout: Bind_Group_Layout) ---

    // -----------------------------------------------------------------------------
    // Procedures of Buffer
    // -----------------------------------------------------------------------------

    webgpuBufferDestroy :: proc(buffer: Buffer) ---
    webgpuBufferGetConstMappedRange :: proc(
        buffer: Buffer,
        offset: uint,
        size: uint,
    ) -> rawptr ---
    webgpuBufferGetMappedRange :: proc(
        buffer: Buffer,
        offset: uint,
        size: uint,
    ) -> rawptr ---
    webgpuBufferGetMapState :: proc(buffer: Buffer) -> Buffer_Map_State ---
    webgpuBufferGetSize :: proc(buffer: Buffer) -> u64 ---
    webgpuBufferGetUsage :: proc(buffer: Buffer) -> Buffer_Usages ---
    webgpuBufferMapAsync :: proc(
        buffer: Buffer,
        mode: Map_Modes,
        offset: uint,
        size: uint,
        callback_info: Buffer_Map_Callback_Info,
    ) -> Future ---
    webgpuBufferReadMappedRange :: proc(
        buffer: Buffer,
        offset: uint,
        data: rawptr,
        size: uint,
    ) -> Status ---
    webgpuBufferSetLabel :: proc(buffer: Buffer, label: string) ---
    webgpuBufferUnmap :: proc(buffer: Buffer) ---
    webgpuBufferWriteMappedRange :: proc(
        buffer: Buffer,
        offset: uint,
        data: rawptr,
        size: uint,
    ) -> Status ---
    webgpuBufferAddRef :: proc(buffer: Buffer) ---
    webgpuBufferRelease :: proc(buffer: Buffer) ---

    // -----------------------------------------------------------------------------
    // Procedures of command_buffer
    // -----------------------------------------------------------------------------

    webgpuCommandBufferSetLabel :: proc(
        command_buffer: Command_Buffer,
        label: string,
    ) ---
    webgpuCommandBufferAddRef :: proc(command_buffer: Command_Buffer) ---
    webgpuCommandBufferRelease :: proc(command_buffer: Command_Buffer) ---

    // -----------------------------------------------------------------------------
    // Procedures of Command_Encoder
    // -----------------------------------------------------------------------------

    webgpuCommandEncoderBeginComputePass :: proc(
        command_encoder: Command_Encoder,
        descriptor: ^Compute_Pass_Descriptor,
    ) -> Compute_Pass ---
    webgpuCommandEncoderBeginRenderPass :: proc(
        #by_ptr command_encoder: Command_Encoder,
        #by_ptr descriptor: Render_Pass_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuCommandEncoderClearBuffer :: proc(
        command_encoder: Command_Encoder,
        buffer: Buffer,
        offset: u64,
        size: u64,
    ) ---
    webgpuCommandEncoderCopyBufferToBuffer :: proc(
        command_encoder: Command_Encoder,
        source: Buffer,
        source_offset: u64,
        destination: Buffer,
        destination_offset: u64,
        size: u64,
    ) ---
    webgpuCommandEncoderCopyBufferToTexture :: proc(
        command_encoder: Command_Encoder,
        source: ^Texel_Copy_Buffer_Info,
        destination: ^Texel_Copy_Texture_Info,
        copy_size: ^Extent_3D,
    ) ---
    webgpuCommandEncoderCopyTextureToBuffer :: proc(
        command_encoder: Command_Encoder,
        #by_ptr source: Texel_Copy_Texture_Info,
        #by_ptr destination: Texel_Copy_Buffer_Info,
        #by_ptr copy_size: Extent_3D,
    ) ---
    webgpuCommandEncoderCopyTextureToTexture :: proc(
        command_encoder: Command_Encoder,
        #by_ptr source: Texel_Copy_Texture_Info,
        #by_ptr destination: Texel_Copy_Texture_Info,
        #by_ptr copy_size: Extent_3D,
    ) ---
    webgpuCommandEncoderFinish :: proc(
        #by_ptr command_encoder: Command_Encoder,
        #by_ptr descriptor: Command_Buffer_Descriptor = {},
        out: ^Handle_Packed,
    ) ---
    webgpuCommandEncoderInsertDebugMarker :: proc(
        command_encoder: Command_Encoder,
        marker_label: string,
    ) ---
    webgpuCommandEncoderPopDebugGroup :: proc(command_encoder: Command_Encoder) ---
    webgpuCommandEncoderPushDebugGroup :: proc(
        command_encoder: Command_Encoder,
        group_label: string,
    ) ---
    webgpuCommandEncoderResolveQuerySet :: proc(
        command_encoder: Command_Encoder,
        query_set: Query_Set,
        first_query: u32,
        query_count: u32,
        destination: Buffer,
        destination_offset: u64,
    ) ---
    webgpuCommandEncoderSetLabel :: proc(
        command_encoder: Command_Encoder,
        label: string,
    ) ---
    webgpuCommandEncoderWriteTimestamp :: proc(
        command_encoder: Command_Encoder,
        query_set: Query_Set,
        query_index: u32,
    ) ---
    webgpuCommandEncoderAddRef :: proc(command_encoder: Command_Encoder) ---
    webgpuCommandEncoderRelease :: proc(command_encoder: Command_Encoder) ---

    // -----------------------------------------------------------------------------
    // Procedures of Compute_Pass
    // -----------------------------------------------------------------------------

    webgpuComputePassEncoderDispatchWorkgroups :: proc(
        compute_pass_encoder: Compute_Pass,
        workgroup_count_x: u32,
        workgroup_count_y: u32,
        workgroup_count_z: u32,
    ) ---
    webgpuComputePassEncoderDispatchWorkgroupsIndirect :: proc(
        compute_pass_encoder: Compute_Pass,
        indirect_buffer: Buffer,
        indirect_offset: u64,
    ) ---
    webgpuComputePassEncoderEnd :: proc(compute_pass_encoder: Compute_Pass) ---
    webgpuComputePassEncoderInsertDebugMarker :: proc(
        compute_pass_encoder: Compute_Pass,
        marker_label: string,
    ) ---
    webgpuComputePassEncoderPopDebugGroup :: proc(
        compute_pass_encoder: Compute_Pass,
    ) ---
    webgpuComputePassEncoderPushDebugGroup :: proc(
        compute_pass_encoder: Compute_Pass,
        group_label: string,
    ) ---
    webgpuComputePassEncoderSetBindGroup :: proc(
        compute_pass_encoder: Compute_Pass,
        group_index: u32,
        group: Bind_Group,
        dynamic_offset_count: uint,
        dynamic_offsets: [^]u32,
    ) ---
    webgpuComputePassEncoderSetImmediates :: proc(
        compute_pass_encoder: Compute_Pass,
        offset: u32,
        data: rawptr,
        size: uint,
    ) ---
    webgpuComputePassEncoderSetLabel :: proc(
        compute_pass_encoder: Compute_Pass,
        label: string,
    ) ---
    webgpuComputePassEncoderSetPipeline :: proc(
        compute_pass_encoder: Compute_Pass,
        pipeline: Compute_Pipeline,
    ) ---
    webgpuComputePassEncoderAddRef :: proc(
        compute_pass_encoder: Compute_Pass,
    ) ---
    webgpuComputePassEncoderRelease :: proc(
        compute_pass_encoder: Compute_Pass,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Compute_Pipeline
    // -----------------------------------------------------------------------------

    webgpuComputePipelineGetBindGroupLayout :: proc(
        compute_pipeline: Compute_Pipeline,
        group_index: u32,
    ) -> Bind_Group_Layout ---
    webgpuComputePipelineSetLabel :: proc(
        compute_pipeline: Compute_Pipeline,
        label: string,
    ) ---
    webgpuComputePipelineAddRef :: proc(compute_pipeline: Compute_Pipeline) ---
    webgpuComputePipelineRelease :: proc(compute_pipeline: Compute_Pipeline) ---

    // -----------------------------------------------------------------------------
    // Procedures of Device
    // -----------------------------------------------------------------------------

    webgpuDeviceCreateBindGroup :: proc(
        device: Device,
        #by_ptr descriptor: Bind_Group_Descriptor,
        out: ^Handle_Packed
    ) ---
    webgpuDeviceCreateBindGroupLayout :: proc(
        device: Device,
        #by_ptr descriptor: Bind_Group_Layout_Descriptor,
        out: ^Handle_Packed
    ) ---
    webgpuDeviceCreateBuffer :: proc(
        device: Device,
        #by_ptr descriptor: Buffer_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateCommandEncoder :: proc(
        device: Device,
        #by_ptr descriptor: Command_Encoder_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateComputePipeline :: proc(
        device: Device,
        descriptor: ^Compute_Pipeline_Descriptor,
    ) -> Compute_Pipeline ---
    webgpuDeviceCreateComputePipelineAsync :: proc(
        device: Device,
        descriptor: ^Compute_Pipeline_Descriptor,
        callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    ) -> Future ---
    webgpuDeviceCreatePipelineLayout :: proc(
        device: Device,
        #by_ptr descriptor: Pipeline_Layout_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateQuerySet :: proc(
        device: Device,
        descriptor: ^Query_Set_Descriptor,
    ) -> Query_Set ---
    webgpuDeviceCreateRenderBundleEncoder :: proc(
        device: Device,
        descriptor: ^Render_Bundle_Encoder_Descriptor,
    ) -> Render_Bundle_Encoder ---
    webgpuDeviceCreateRenderPipeline :: proc(
        device: Device,
        #by_ptr descriptor: Render_Pipeline_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateRenderPipelineAsync :: proc(
        device: Device,
        descriptor: ^Render_Pipeline_Descriptor,
        callback_info: Create_Render_Pipeline_Async_Callback_Info,
    ) -> Future ---
    webgpuDeviceCreateSampler :: proc(
        device: Device,
        #by_ptr descriptor: Sampler_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateShaderModule :: proc(
        device: Device,
        #by_ptr descriptor: Shader_Module_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceCreateTexture :: proc(
        device: Device,
        #by_ptr descriptor: Texture_Descriptor,
        out: ^Handle_Packed,
    ) ---
    webgpuDeviceDestroy :: proc(device: Device) ---
    webgpuDeviceGetAdapterInfo :: proc(
        device: Device,
        adapter_info: ^Adapter_Info,
    ) -> Status ---
    webgpuDeviceGetFeatures :: proc(device: Device, features: ^Supported_Features) ---
    webgpuDeviceGetLimits :: proc(device: Device, limits: ^Limits) -> Status ---
    webgpuDeviceGetLostFuture :: proc(device: Device) -> Future ---
    webgpuDeviceGetQueue :: proc(device: Device, out: ^Handle_Packed) ---
    webgpuDeviceHasFeature :: proc(device: Device, feature: Feature_Name) -> bool ---
    webgpuDevicePopErrorScope :: proc(
        device: Device,
        callback_info: Pop_Error_Scope_Callback_Info,
    ) -> Future ---
    webgpuDevicePushErrorScope :: proc(device: Device, filter: Error_Filter) ---
    webgpuDeviceSetLabel :: proc(device: Device, label: string) ---
    webgpuDeviceAddRef :: proc(device: Device) ---
    webgpuDeviceRelease :: proc(device: Device) ---

    // -----------------------------------------------------------------------------
    // Procedures of External_Texture
    // -----------------------------------------------------------------------------

    webgpuExternalTextureSetLabel :: proc(
        external_texture: External_Texture,
        label: string,
    ) ---
    webgpuExternalTextureAddRef :: proc(external_texture: External_Texture) ---
    webgpuExternalTextureRelease :: proc(external_texture: External_Texture) ---

    // -----------------------------------------------------------------------------
    // Procedures of Instance
    // -----------------------------------------------------------------------------

    webgpuInstanceCreateSurface :: proc(
        instance: Instance,
        #by_ptr selector: Surface_Source_Canvas_HTML_Selector,
    ) -> Surface ---
    webgpuInstanceGetWGSLLanguageFeatures :: proc(
        instance: Instance,
        features: ^Supported_WGSL_Language_Features,
    ) ---
    webgpuInstanceHasWGSLLanguageFeature :: proc(
        instance: Instance,
        feature: WGSL_Language_Feature_Name,
    ) -> bool ---
    webgpuInstanceProcessEvents :: proc(instance: Instance) ---
    webgpuInstanceRequestAdapter :: proc(
        instance: Instance,
        #by_ptr options: Request_Adapter_Options = {},
    ) -> Adapter ---
    webgpuInstanceWaitAny :: proc(
        instance: Instance,
        future_count: uint,
        futures: [^]^Future_Wait_Info,
        timeout_ns: u64 = max(u64),
    ) -> Wait_Status ---
    webgpuInstanceAddRef :: proc(instance: Instance) ---
    webgpuInstanceRelease :: proc(instance: Instance) ---

    // -----------------------------------------------------------------------------
    // Procedures of Pipeline_Layout
    // -----------------------------------------------------------------------------

    webgpuPipelineLayoutSetLabel :: proc(
        pipeline_layout: Pipeline_Layout,
        label: string,
    ) ---
    webgpuPipelineLayoutAddRef :: proc(pipeline_layout: Pipeline_Layout) ---
    webgpuPipelineLayoutRelease :: proc(pipeline_layout: Pipeline_Layout) ---

    // -----------------------------------------------------------------------------
    // Procedures of Query_Set
    // -----------------------------------------------------------------------------

    webgpuQuerySetDestroy :: proc(query_set: Query_Set) ---
    webgpuQuerySetGetCount :: proc(query_set: Query_Set) -> u32 ---
    webgpuQuerySetGetType :: proc(query_set: Query_Set) -> Query_Type ---
    webgpuQuerySetSetLabel :: proc(query_set: Query_Set, label: string) ---
    webgpuQuerySetAddRef :: proc(query_set: Query_Set) ---
    webgpuQuerySetRelease :: proc(query_set: Query_Set) ---

    // -----------------------------------------------------------------------------
    // Procedures of Queue
    // -----------------------------------------------------------------------------

    webgpuQueueOnSubmittedWorkDone :: proc(
        queue: Queue,
        callback_info: Queue_Work_Done_Callback_Info,
    ) -> Future ---
    webgpuQueueSetLabel :: proc(queue: Queue, label: string) ---
    webgpuQueueSubmit :: proc(#by_ptr queue: Queue, commands: []Command_Buffer) ---
    webgpuQueueWriteBuffer :: proc(
        queue: Queue,
        buffer: Buffer,
        buffer_offset: u64,
        data: rawptr,
        size: uint,
    ) ---
    webgpuQueueWriteTexture :: proc(
        queue: Queue,
        #by_ptr destination: Texel_Copy_Texture_Info,
        data: rawptr,
        data_size: uint,
        #by_ptr data_layout: Texel_Copy_Buffer_Layout,
        #by_ptr write_size: Extent_3D,
    ) ---
    webgpuQueueAddRef :: proc(queue: Queue) ---
    webgpuQueueRelease :: proc(queue: Queue) ---

    // -----------------------------------------------------------------------------
    // Procedures of Render_Bundle
    // -----------------------------------------------------------------------------

    webgpuRenderBundleSetLabel :: proc(render_bundle: Render_Bundle, label: string) ---
    webgpuRenderBundleAddRef :: proc(render_bundle: Render_Bundle) ---
    webgpuRenderBundleRelease :: proc(render_bundle: Render_Bundle) ---

    // -----------------------------------------------------------------------------
    // Procedures of Render_Bundle_Encoder
    // -----------------------------------------------------------------------------

    webgpuRenderBundleEncoderDraw :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        vertex_count: u32,
        instance_count: u32,
        first_vertex: u32,
        first_instance: u32,
    ) ---
    webgpuRenderBundleEncoderDrawIndexed :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        index_count: u32,
        instance_count: u32,
        first_index: u32,
        base_vertex: i32,
        first_instance: u32,
    ) ---
    webgpuRenderBundleEncoderDrawIndexedIndirect :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        indirect_buffer: Buffer,
        indirect_offset: u64,
    ) ---
    webgpuRenderBundleEncoderDrawIndirect :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        indirect_buffer: Buffer,
        indirect_offset: u64,
    ) ---
    webgpuRenderBundleEncoderFinish :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        descriptor: ^Render_Bundle_Descriptor,
    ) -> Render_Bundle ---
    webgpuRenderBundleEncoderInsertDebugMarker :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        marker_label: string,
    ) ---
    webgpuRenderBundleEncoderPopDebugGroup :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
    ) ---
    webgpuRenderBundleEncoderPushDebugGroup :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        group_label: string,
    ) ---
    webgpuRenderBundleEncoderSetBindGroup :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        group_index: u32,
        group: Bind_Group,
        dynamic_offset_count: uint,
        dynamic_offsets: [^]u32,
    ) ---
    webgpuRenderBundleEncoderSetImmediates :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        offset: u32,
        data: rawptr,
        size: uint,
    ) ---
    webgpuRenderBundleEncoderSetIndexBuffer :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        buffer: Buffer,
        format: Index_Format,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderBundleEncoderSetLabel :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        label: string,
    ) ---
    webgpuRenderBundleEncoderSetPipeline :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        pipeline: Render_Pipeline,
    ) ---
    webgpuRenderBundleEncoderSetVertexBuffer :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
        slot: u32,
        buffer: Buffer,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderBundleEncoderAddRef :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
    ) ---
    webgpuRenderBundleEncoderRelease :: proc(
        render_bundle_encoder: Render_Bundle_Encoder,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Render_Pass
    // -----------------------------------------------------------------------------

    webgpuRenderPassEncoderBeginOcclusionQuery :: proc(
        render_pass_encoder: Render_Pass,
        query_index: u32,
    ) ---
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
    webgpuRenderPassEncoderDrawIndexedIndirect :: proc(
        render_pass_encoder: Render_Pass,
        indirect_buffer: Buffer,
        indirect_offset: u64,
    ) ---
    webgpuRenderPassEncoderDrawIndirect :: proc(
        render_pass_encoder: Render_Pass,
        indirect_buffer: Buffer,
        indirect_offset: u64,
    ) ---
    webgpuRenderPassEncoderEnd :: proc(#by_ptr render_pass_encoder: Render_Pass) ---
    webgpuRenderPassEncoderEndOcclusionQuery :: proc(
        render_pass_encoder: Render_Pass,
    ) ---
    webgpuRenderPassEncoderExecuteBundles :: proc(
        render_pass_encoder: Render_Pass,
        bundle_count: uint,
        bundles: [^]Render_Bundle,
    ) ---
    webgpuRenderPassEncoderInsertDebugMarker :: proc(
        render_pass_encoder: Render_Pass,
        marker_label: string,
    ) ---
    webgpuRenderPassEncoderPopDebugGroup :: proc(
        render_pass_encoder: Render_Pass,
    ) ---
    webgpuRenderPassEncoderPushDebugGroup :: proc(
        render_pass_encoder: Render_Pass,
        group_label: string,
    ) ---
    webgpuRenderPassEncoderSetBindGroup :: proc(
        render_pass_encoder: Render_Pass,
        group_index: u32,
        group: Bind_Group,
        dynamic_offsets: []u32,
    ) ---
    webgpuRenderPassEncoderSetBlendConstant :: proc(
        render_pass_encoder: Render_Pass,
        color: Color,
    ) ---
    webgpuRenderPassEncoderSetImmediates :: proc(
        render_pass_encoder: Render_Pass,
        offset: u32,
        data: rawptr,
        size: uint,
    ) ---
    webgpuRenderPassEncoderSetIndexBuffer :: proc(
        render_pass_encoder: Render_Pass,
        buffer: Buffer,
        format: Index_Format,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderPassEncoderSetLabel :: proc(
        render_pass_encoder: Render_Pass,
        label: string,
    ) ---
    webgpuRenderPassEncoderSetPipeline :: proc(
        render_pass_encoder: Render_Pass,
        pipeline: Render_Pipeline,
    ) ---
    webgpuRenderPassEncoderSetScissorRect :: proc(
        render_pass_encoder: Render_Pass,
        x: u32,
        y: u32,
        width: u32,
        height: u32,
    ) ---
    webgpuRenderPassEncoderSetStencilReference :: proc(
        render_pass_encoder: Render_Pass,
        reference: u32,
    ) ---
    webgpuRenderPassEncoderSetVertexBuffer :: proc(
        render_pass_encoder: Render_Pass,
        slot: u32,
        buffer: Buffer,
        offset: u64,
        size: u64,
    ) ---
    webgpuRenderPassEncoderSetViewport :: proc(
        render_pass_encoder: Render_Pass,
        x: f32,
        y: f32,
        width: f32,
        height: f32,
        min_depth: f32,
        max_depth: f32,
    ) ---
    webgpuRenderPassEncoderAddRef :: proc(
        render_pass_encoder: Render_Pass,
    ) ---
    webgpuRenderPassEncoderRelease :: proc(
        render_pass_encoder: Render_Pass,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Render_Pipeline
    // -----------------------------------------------------------------------------

    webgpuRenderPipelineGetBindGroupLayout :: proc(
        render_pipeline: Render_Pipeline,
        group_index: u32,
    ) -> Bind_Group_Layout ---
    webgpuRenderPipelineSetLabel :: proc(
        render_pipeline: Render_Pipeline,
        label: string,
    ) ---
    webgpuRenderPipelineAddRef :: proc(render_pipeline: Render_Pipeline) ---
    webgpuRenderPipelineRelease :: proc(render_pipeline: Render_Pipeline) ---

    // -----------------------------------------------------------------------------
    // Procedures of Sampler
    // -----------------------------------------------------------------------------

    webgpuSamplerSetLabel :: proc(sampler: Sampler, label: string) ---
    webgpuSamplerAddRef :: proc(sampler: Sampler) ---
    webgpuSamplerRelease :: proc(sampler: Sampler) ---

    // -----------------------------------------------------------------------------
    // Procedures of Shader_Module
    // -----------------------------------------------------------------------------

    webgpuShaderModuleGetCompilationInfo :: proc(
        shader_module: Shader_Module,
        callback_info: Compilation_Info_Callback_Info,
    ) -> Future ---
    webgpuShaderModuleSetLabel :: proc(shader_module: Shader_Module, label: string) ---
    webgpuShaderModuleAddRef :: proc(shader_module: Shader_Module) ---
    webgpuShaderModuleRelease :: proc(shader_module: Shader_Module) ---

    // -----------------------------------------------------------------------------
    // Procedures of Supported_Features
    // -----------------------------------------------------------------------------

    webgpuSupportedFeaturesFreeMembers :: proc(
        supported_features: Supported_Features,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Supported_Instance_Features
    // -----------------------------------------------------------------------------

    webgpuSupportedInstanceFeaturesFreeMembers :: proc(
        supported_instance_features: Supported_Instance_Features,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Supported_WGSL_Language_Features
    // -----------------------------------------------------------------------------

    webgpuSupportedWGSLLanguageFeaturesFreeMembers :: proc(
        supported_wgsl_language_features: Supported_WGSL_Language_Features,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of surface
    // -----------------------------------------------------------------------------

    webgpuSurfaceConfigure :: proc(surface: Surface, #by_ptr config: Surface_Configuration) ---
    webgpuSurfaceGetCapabilities :: proc(
        surface: Surface,
        adapter: Adapter,
        capabilities: ^Surface_Capabilities,
    ) -> Status ---
    webgpuSurfaceGetCurrentTexture :: proc(surface: Surface, surface_texture: ^Surface_Texture) ---
    webgpuSurfacePresent :: proc(surface: Surface) -> Status ---
    webgpuSurfaceSetLabel :: proc(surface: Surface, label: string) ---
    webgpuSurfaceUnconfigure :: proc(surface: Surface) ---
    webgpuSurfaceAddRef :: proc(surface: Surface) ---
    webgpuSurfaceRelease :: proc(surface: Surface) ---

    // -----------------------------------------------------------------------------
    // Procedures of Surface_Capabilities
    // -----------------------------------------------------------------------------

    webgpuSurfaceCapabilitiesFreeMembers :: proc(
        surface_capabilities: Surface_Capabilities,
    ) ---

    // -----------------------------------------------------------------------------
    // Procedures of Texture
    // -----------------------------------------------------------------------------

    webgpuTextureCreateView :: proc(
        #by_ptr texture: Texture,
        descriptor: ^Texture_View_Descriptor = nil,
        out: ^Handle_Packed,
    ) ---
    webgpuTextureDestroy :: proc(texture: Texture) ---
    webgpuTextureGetDepthOrArrayLayers :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetDimension :: proc(texture: Texture) -> Texture_Dimension ---
    webgpuTextureGetFormat :: proc(texture: Texture) -> Texture_Format ---
    webgpuTextureGetHeight :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetMipLevelCount :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetSampleCount :: proc(texture: Texture) -> u32 ---
    webgpuTextureGetSize :: proc(texture: Texture, out: ^Extent_3D) ---
    webgpuTextureGetTextureBindingViewDimension :: proc(
        texture: Texture,
    ) -> Texture_View_Dimension ---
    webgpuTextureGetUsage :: proc(texture: Texture) -> Texture_Usages ---
    webgpuTextureGetWidth :: proc(texture: Texture) -> u32 ---
    webgpuTextureSetLabel :: proc(texture: Texture, label: string) ---
    webgpuTextureAddRef :: proc(texture: Texture) ---
    webgpuTextureRelease :: proc(texture: Texture) ---

    // -----------------------------------------------------------------------------
    // Procedures of Texture_View
    // -----------------------------------------------------------------------------

    webgpuTextureViewSetLabel :: proc(texture_view: Texture_View, label: string) ---
    webgpuTextureViewAddRef :: proc(texture_view: Texture_View) ---
    webgpuTextureViewRelease :: proc(texture_view: Texture_View) ---
}

webgpu_set_procedures :: proc() {
    // Global procedures
    get_instance_features = webgpu_get_instance_features
    get_instance_limits = webgpu_get_instance_limits
    has_instance_feature = webgpu_has_instance_feature

    // Procedures of Adapter
    adapter_get_features = webgpu_adapter_get_features
    adapter_get_info = webgpu_adapter_get_info
    adapter_create_device = webgpu_adapter_create_device
    adapter_add_ref = webgpu_adapter_add_ref
    adapter_release = webgpu_adapter_release

    // Private procedures of Adapter
    adapter_texture_format_capabilities = webgpu_adapter_texture_format_capabilities

    // Procedures of Bind_Group
    bind_group_set_label = webgpu_bind_group_set_label
    bind_group_add_ref = webgpu_bind_group_add_ref
    bind_group_release = webgpu_bind_group_release
    bind_group_layout_set_label = webgpu_bind_group_layout_set_label
    bind_group_layout_add_ref = webgpu_bind_group_layout_add_ref
    bind_group_layout_release = webgpu_bind_group_layout_release

    // Procedures of Buffer
    buffer_destroy = webgpu_buffer_destroy
    buffer_get_const_mapped_range = webgpu_buffer_get_const_mapped_range
    buffer_get_mapped_range = webgpu_buffer_get_mapped_range
    buffer_get_map_state = webgpu_buffer_get_map_state
    buffer_get_size = webgpu_buffer_get_size
    buffer_get_usage = webgpu_buffer_get_usage
    buffer_map_async = webgpu_buffer_map_async
    buffer_map_sync = webgpu_buffer_map_sync
    buffer_read_mapped_range = webgpu_buffer_read_mapped_range
    buffer_set_label = webgpu_buffer_set_label
    buffer_unmap = webgpu_buffer_unmap
    buffer_write_mapped_range = webgpu_buffer_write_mapped_range
    buffer_add_ref = webgpu_buffer_add_ref
    buffer_release = webgpu_buffer_release

    // Procedures of Command_Buffer
    command_buffer_set_label = webgpu_command_buffer_set_label
    command_buffer_add_ref = webgpu_command_buffer_add_ref
    command_buffer_release = webgpu_command_buffer_release

    // Procedures of Command_Encoder
    command_encoder_begin_compute_pass = webgpu_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass = webgpu_command_encoder_begin_render_pass
    command_encoder_clear_buffer = webgpu_command_encoder_clear_buffer
    command_encoder_copy_buffer_to_buffer = webgpu_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture = webgpu_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer = webgpu_command_encoder_copy_texture_to_buffer
    command_encoder_copy_texture_to_texture = webgpu_command_encoder_copy_texture_to_texture
    command_encoder_finish = webgpu_command_encoder_finish
    command_encoder_insert_debug_marker = webgpu_command_encoder_insert_debug_marker
    command_encoder_pop_debug_group = webgpu_command_encoder_pop_debug_group
    command_encoder_push_debug_group = webgpu_command_encoder_push_debug_group
    command_encoder_resolve_query_set = webgpu_command_encoder_resolve_query_set
    command_encoder_set_label = webgpu_command_encoder_set_label
    command_encoder_write_timestamp = webgpu_command_encoder_write_timestamp
    command_encoder_add_ref = webgpu_command_encoder_add_ref
    command_encoder_release = webgpu_command_encoder_release

    // Procedures of Compute_Pass
    compute_pass_dispatch_workgroups = webgpu_compute_pass_dispatch_workgroups
    compute_pass_dispatch_workgroups_indirect =
        webgpu_compute_pass_dispatch_workgroups_indirect
    compute_pass_end = webgpu_compute_pass_end
    compute_pass_insert_debug_marker = webgpu_compute_pass_insert_debug_marker
    compute_pass_pop_debug_group = webgpu_compute_pass_pop_debug_group
    compute_pass_push_debug_group = webgpu_compute_pass_push_debug_group
    compute_pass_set_bind_group = webgpu_compute_pass_set_bind_group
    compute_pass_set_immediates = webgpu_compute_pass_set_immediates
    compute_pass_set_label = webgpu_compute_pass_set_label
    compute_pass_set_pipeline = webgpu_compute_pass_set_pipeline
    compute_pass_add_ref = webgpu_compute_pass_add_ref
    compute_pass_release = webgpu_compute_pass_release

    // Procedures of Compute_Pipeline
    compute_pipeline_get_bind_group_layout = webgpu_compute_pipeline_get_bind_group_layout
    compute_pipeline_set_label = webgpu_compute_pipeline_set_label
    compute_pipeline_add_ref = webgpu_compute_pipeline_add_ref
    compute_pipeline_release = webgpu_compute_pipeline_release

    // Procedures of Device
    device_create_bind_group        = webgpu_device_create_bind_group
    device_create_bind_group_layout      = webgpu_device_create_bind_group_layout
    device_create_buffer                 = webgpu_device_create_buffer
    device_create_command_encoder        = webgpu_device_create_command_encoder
    device_create_compute_pipeline       = webgpu_device_create_compute_pipeline
    device_create_compute_pipeline_async = webgpu_device_create_compute_pipeline_async
    device_create_pipeline_layout        = webgpu_device_create_pipeline_layout
    device_create_query_set              = webgpu_device_create_query_set
    device_create_render_bundle_encoder  = webgpu_device_create_render_bundle_encoder
    device_create_render_pipeline        = webgpu_device_create_render_pipeline
    device_create_render_pipeline_async  = webgpu_device_create_render_pipeline_async
    device_create_sampler                = webgpu_device_create_sampler
    device_create_shader_module          = webgpu_device_create_shader_module
    device_create_texture                = webgpu_device_create_texture
    device_destroy                       = webgpu_device_destroy
    device_get_adapter_info              = webgpu_device_get_adapter_info
    device_get_lost_future               = webgpu_device_get_lost_future
    device_get_queue                     = webgpu_device_get_queue
    device_pop_error_scope               = webgpu_device_pop_error_scope
    device_push_error_scope              = webgpu_device_push_error_scope
    device_backend = webgpu_device_backend
    device_is_embedded = webgpu_device_is_embedded
    device_set_label                     = webgpu_device_set_label
    device_add_ref                       = webgpu_device_add_ref
    device_release                       = webgpu_device_release

    // Procedures of External_Texture
    external_texture_set_label = webgpu_external_texture_set_label
    external_texture_add_ref = webgpu_external_texture_add_ref
    external_texture_release = webgpu_external_texture_release

    // Procedures of Instance
    instance_create_surface = webgpu_instance_create_surface
    instance_get_wgsl_language_features = webgpu_instance_get_wgsl_language_features
    instance_has_wgsl_language_feature = webgpu_instance_has_wgsl_language_feature
    instance_process_events = webgpu_instance_process_events
    instance_create_adapter = webgpu_instance_create_adapter
    instance_wait_any = webgpu_instance_wait_any
    instance_add_ref = webgpu_instance_add_ref
    instance_release = webgpu_instance_release

    // Procedures of Pipeline_Layout
    pipeline_layout_set_label = webgpu_pipeline_layout_set_label
    pipeline_layout_add_ref = webgpu_pipeline_layout_add_ref
    pipeline_layout_release = webgpu_pipeline_layout_release

    // Procedures of Query_Set
    query_set_destroy = webgpu_query_set_destroy
    query_set_get_count = webgpu_query_set_get_count
    query_set_get_type = webgpu_query_set_get_type
    query_set_set_label = webgpu_query_set_set_label
    query_set_add_ref = webgpu_query_set_add_ref
    query_set_release = webgpu_query_set_release

    // Procedures of Queue
    queue_on_submitted_work_done = webgpu_queue_on_submitted_work_done
    queue_set_label = webgpu_queue_set_label
    queue_submit = webgpu_queue_submit
    queue_write_buffer_raw = webgpu_queue_write_buffer_raw
    queue_write_texture = webgpu_queue_write_texture
    queue_add_ref = webgpu_queue_add_ref
    queue_release = webgpu_queue_release

    // Procedures of Render_Bundle
    render_bundle_set_label = webgpu_render_bundle_set_label
    render_bundle_add_ref = webgpu_render_bundle_add_ref
    render_bundle_release = webgpu_render_bundle_release

    // Procedures of Render_Bundle_Encoder
    render_bundle_encoder_draw = webgpu_render_bundle_encoder_draw
    render_bundle_encoder_draw_indexed = webgpu_render_bundle_encoder_draw_indexed
    render_bundle_encoder_draw_indexed_indirect = webgpu_render_bundle_encoder_draw_indexed_indirect
    render_bundle_encoder_draw_indirect = webgpu_render_bundle_encoder_draw_indirect
    render_bundle_encoder_finish = webgpu_render_bundle_encoder_finish
    render_bundle_encoder_insert_debug_marker = webgpu_render_bundle_encoder_insert_debug_marker
    render_bundle_encoder_pop_debug_group = webgpu_render_bundle_encoder_pop_debug_group
    render_bundle_encoder_push_debug_group = webgpu_render_bundle_encoder_push_debug_group
    render_bundle_encoder_set_bind_group = webgpu_render_bundle_encoder_set_bind_group
    render_bundle_encoder_set_immediates = webgpu_render_bundle_encoder_set_immediates
    render_bundle_encoder_set_index_buffer = webgpu_render_bundle_encoder_set_index_buffer
    render_bundle_encoder_set_label = webgpu_render_bundle_encoder_set_label
    render_bundle_encoder_set_pipeline = webgpu_render_bundle_encoder_set_pipeline
    render_bundle_encoder_set_vertex_buffer = webgpu_render_bundle_encoder_set_vertex_buffer
    render_bundle_encoder_add_ref = webgpu_render_bundle_encoder_add_ref
    render_bundle_encoder_release = webgpu_render_bundle_encoder_release

    // Procedures of Render_Pass
    render_pass_begin_occlusion_query = webgpu_render_pass_begin_occlusion_query
    render_pass_draw = webgpu_render_pass_draw
    render_pass_draw_indexed = webgpu_render_pass_draw_indexed
    render_pass_draw_indexed_indirect = webgpu_render_pass_draw_indexed_indirect
    render_pass_draw_indirect = webgpu_render_pass_draw_indirect
    render_pass_end = webgpu_render_pass_end
    render_pass_end_occlusion_query = webgpu_render_pass_end_occlusion_query
    render_pass_execute_bundles = webgpu_render_pass_execute_bundles
    render_pass_insert_debug_marker = webgpu_render_pass_insert_debug_marker
    render_pass_pop_debug_group = webgpu_render_pass_pop_debug_group
    render_pass_push_debug_group = webgpu_render_pass_push_debug_group
    render_pass_set_bind_group = webgpu_render_pass_set_bind_group
    render_pass_set_blend_constant = webgpu_render_pass_set_blend_constant
    render_pass_set_immediates = webgpu_render_pass_set_immediates
    render_pass_set_index_buffer = webgpu_render_pass_set_index_buffer
    render_pass_set_label = webgpu_render_pass_set_label
    render_pass_set_pipeline = webgpu_render_pass_set_pipeline
    render_pass_set_scissor_rect = webgpu_render_pass_set_scissor_rect
    render_pass_set_stencil_reference = webgpu_render_pass_set_stencil_reference
    render_pass_set_vertex_buffer = webgpu_render_pass_set_vertex_buffer
    render_pass_set_viewport = webgpu_render_pass_set_viewport
    render_pass_add_ref = webgpu_render_pass_add_ref
    render_pass_release = webgpu_render_pass_release

    // Procedures of Render_Pipeline
    render_pipeline_get_bind_group_layout = webgpu_render_pipeline_get_bind_group_layout
    render_pipeline_set_label = webgpu_render_pipeline_set_label
    render_pipeline_add_ref = webgpu_render_pipeline_add_ref
    render_pipeline_release = webgpu_render_pipeline_release

    // Procedures of Sampler
    sampler_set_label = webgpu_sampler_set_label
    sampler_add_ref = webgpu_sampler_add_ref
    sampler_release = webgpu_sampler_release

    // Procedures of Shader_Module
    shader_module_get_compilation_info = webgpu_shader_module_get_compilation_info
    shader_module_set_label = webgpu_shader_module_set_label
    shader_module_add_ref = webgpu_shader_module_add_ref
    shader_module_release = webgpu_shader_module_release

    // Procedures of Supported_Features
    supported_features_free_members = webgpu_supported_features_free_members

    // Procedures of Supported_Instance_Features
    supported_instance_features_free_members = webgpu_supported_instance_features_free_members

    // Procedures of Supported_WGSL_Language_Features
    supported_wgsl_language_features_free_members =
        webgpu_supported_wgsl_language_features_free_members

    // Procedures of Surface
    surface_configure = webgpu_surface_configure
    surface_get_capabilities = webgpu_surface_get_capabilities
    surface_get_current_texture = webgpu_surface_get_current_texture
    surface_present = webgpu_surface_present
    surface_set_label = webgpu_surface_set_label
    surface_unconfigure = webgpu_surface_unconfigure
    surface_add_ref = webgpu_surface_add_ref
    surface_release = webgpu_surface_release
    surface_texture_present = webgpu_surface_texture_present
    surface_capabilities_free_members = webgpu_surface_capabilities_free_members

    // Procedures of Texture
    texture_create_view = webgpu_texture_create_view
    texture_destroy = webgpu_texture_destroy
    texture_get_depth_or_array_layers = webgpu_texture_get_depth_or_array_layers
    texture_get_descriptor = webgpu_texture_get_descriptor
    texture_get_dimension = webgpu_texture_get_dimension
    texture_get_format = webgpu_texture_get_format
    texture_get_height = webgpu_texture_get_height
    texture_get_mip_level_count = webgpu_texture_get_mip_level_count
    texture_get_sample_count = webgpu_texture_get_sample_count
    texture_get_size = webgpu_texture_get_size
    texture_get_texture_binding_view_dimension = webgpu_texture_get_texture_binding_view_dimension
    texture_get_usage = webgpu_texture_get_usage
    texture_get_width = webgpu_texture_get_width
    texture_set_label = webgpu_texture_set_label
    texture_add_ref = webgpu_texture_add_ref
    texture_release = webgpu_texture_release

    // Procedures of Texture_View
    texture_view_set_label = webgpu_texture_view_set_label
    texture_view_add_ref = webgpu_texture_view_add_ref
    texture_view_release = webgpu_texture_view_release
}

// -----------------------------------------------------------------------------
// Global procedures
// -----------------------------------------------------------------------------

webgpu_create_instance :: proc(
    allocator: runtime.Allocator,
    descriptor: Instance_Descriptor = {},
    loc := #caller_location,
) -> Instance {
    webgpu_set_procedures()
    return webgpuCreateInstance(nil)
}

webgpu_get_instance_features :: proc(loc := #caller_location) -> Instance_Features {
    unimplemented(loc = loc)
}

webgpu_get_instance_limits :: proc(loc := #caller_location) -> (limits: Instance_Limits) {
    unimplemented(loc = loc)
}

webgpu_has_instance_feature :: proc(feature: Instance_Feature_Name, loc := #caller_location) -> bool {
    unimplemented(loc = loc)
}

webgpu_set_log_callback :: proc(callback: Log_Callback, userdata: rawptr, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_set_log_level :: proc(level: Log_Level, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_get_version :: proc(loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Adapter
// -----------------------------------------------------------------------------

webgpu_adapter_get_features :: proc(
    adapter: Adapter,
    loc := #caller_location,
) -> (features: Features) {
    webgpuAdapterGetFeatures(adapter, &features)
    return
}

webgpu_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
) {
    webgpuAdapterGetInfo(adapter, &info)
    return
}

webgpu_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
    limits: Limits
    webgpuAdapterGetLimits(adapter, &limits)
    return limits
}

webgpu_adapter_has_feature :: proc(
    adapter: Adapter,
    features: []Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

webgpu_adapter_create_device :: proc(
    adapter: Adapter,
    descriptor: Device_Descriptor = {},
    loc := #caller_location,
) -> Device {
    return webgpuAdapterRequestDevice(adapter, descriptor)
}

webgpu_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    webgpuAdapterAddRef(adapter)
}

webgpu_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    webgpuAdapterRelease(adapter)
}

// -----------------------------------------------------------------------------
// Adapter private procedures
// -----------------------------------------------------------------------------

webgpu_adapter_texture_format_capabilities :: proc(
    adapter: Adapter,
    format: Texture_Format,
    loc := #caller_location,
) -> (caps: Texture_Format_Capabilities) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Adapter_Info
// -----------------------------------------------------------------------------

webgpu_adapter_info_free_members :: proc(
    adapter_info: Adapter_Info,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Bind_Group
// -----------------------------------------------------------------------------

webgpu_bind_group_set_label :: proc(bind_group: Bind_Group, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    webgpuBindGroupAddRef(bind_group)
}

webgpu_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    webgpuBindGroupRelease(bind_group)
}

// -----------------------------------------------------------------------------
// Procedures of Bind_Group_Layout
// -----------------------------------------------------------------------------

webgpu_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    webgpuBindGroupLayoutAddRef(bind_group_layout)
}

webgpu_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    webgpuBindGroupLayoutRelease(bind_group_layout)
}

// -----------------------------------------------------------------------------
// Procedures of Buffer
// -----------------------------------------------------------------------------

webgpu_buffer_destroy :: proc(buffer: Buffer, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_buffer_get_const_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    unimplemented(loc = loc)
}

webgpu_buffer_get_mapped_range :: proc(
    buffer: Buffer,
    offset: uint = 0,
    size: uint = WHOLE_MAP_SIZE,
    loc := #caller_location,
) -> rawptr {
    return webgpuBufferGetMappedRange(buffer, offset, size)
}

webgpu_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    unimplemented(loc = loc)
}

webgpu_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    return webgpuBufferGetSize(buffer)
}

webgpu_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    unimplemented(loc = loc)
}

webgpu_buffer_map_async :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    callback_info: Buffer_Map_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

webgpu_buffer_map_sync :: proc(
    buffer: Buffer,
    mode: Map_Mode,
    offset: uint,
    size: uint,
    loc := #caller_location,
) -> rawptr {
    unimplemented(loc = loc)
}

webgpu_buffer_read_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    unimplemented(loc = loc)
}

webgpu_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferUnmap(buffer)
}

webgpu_buffer_write_mapped_range :: proc(
    buffer: Buffer,
    offset: uint,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) -> Status {
    unimplemented(loc = loc)
}

webgpu_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferAddRef(buffer)
}

webgpu_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    webgpuBufferRelease(buffer)
}

// -----------------------------------------------------------------------------
// Procedures of Command_Buffer
// -----------------------------------------------------------------------------

webgpu_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    webgpuCommandBufferAddRef(command_buffer)
}

webgpu_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
    webgpuCommandBufferRelease(command_buffer)
}

// -----------------------------------------------------------------------------
// Procedures of D3d12_Command_Encoder_Impl
// -----------------------------------------------------------------------------

webgpu_command_encoder_begin_compute_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Compute_Pass_Descriptor = {},
    loc := #caller_location,
) -> Compute_Pass {
    unimplemented(loc = loc)
}

webgpu_command_encoder_begin_render_pass :: proc(
    command_encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    out: Handle_Packed
    webgpuCommandEncoderBeginRenderPass(command_encoder, descriptor, &out)
    return new_handle_packed(Render_Pass, command_encoder.device, out)
}

webgpu_command_encoder_clear_buffer :: proc(
    command_encoder: Command_Encoder,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_copy_buffer_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Buffer,
    source_offset: u64,
    destination: Buffer,
    destination_offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_copy_buffer_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_copy_texture_to_buffer :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Buffer_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    webgpuCommandEncoderCopyTextureToBuffer(command_encoder, source, destination, copy_size)
}

webgpu_command_encoder_copy_texture_to_texture :: proc(
    command_encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    webgpuCommandEncoderCopyTextureToTexture(command_encoder, source, destination, copy_size)
}

webgpu_command_encoder_finish :: proc(
    command_encoder: Command_Encoder,
    descriptor: Command_Buffer_Descriptor = {},
    loc := #caller_location,
) -> Command_Buffer {
    out: Handle_Packed
    webgpuCommandEncoderFinish(command_encoder, descriptor, &out)
    return new_handle_packed(Command_Buffer, command_encoder.device, out)
}

webgpu_command_encoder_insert_debug_marker :: proc(
    command_encoder: Command_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_pop_debug_group :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_push_debug_group :: proc(
    command_encoder: Command_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_resolve_query_set :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    first_query: u32,
    query_count: u32,
    destination: Buffer,
    destination_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_write_timestamp :: proc(
    command_encoder: Command_Encoder,
    query_set: Query_Set,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    webgpuCommandEncoderAddRef(command_encoder)
}

webgpu_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
    webgpuCommandEncoderRelease(command_encoder)
}

// -----------------------------------------------------------------------------
// Procedures of Compute_Pass
// -----------------------------------------------------------------------------

webgpu_compute_pass_dispatch_workgroups :: proc(
    compute_pass: Compute_Pass,
    workgroup_count_x: u32,
    workgroup_count_y: u32,
    workgroup_count_z: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_dispatch_workgroups_indirect :: proc(
    compute_pass: Compute_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_end :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_insert_debug_marker :: proc(
    compute_pass: Compute_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_pop_debug_group :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_push_debug_group :: proc(
    compute_pass: Compute_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_set_bind_group :: proc(
    compute_pass: Compute_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_set_immediates :: proc(
    compute_pass: Compute_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_set_label :: proc(
    compute_pass: Compute_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_set_pipeline :: proc(
    compute_pass: Compute_Pass,
    pipeline: Compute_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_add_ref :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pass_release :: proc(
    compute_pass: Compute_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Compute_Pipeline
// -----------------------------------------------------------------------------

webgpu_compute_pipeline_get_bind_group_layout :: proc(
    compute_pipeline: Compute_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

webgpu_compute_pipeline_set_label :: proc(
    compute_pipeline: Compute_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_compute_pipeline_add_ref :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_compute_pipeline_release :: proc(compute_pipeline: Compute_Pipeline, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of D3d12_Device_Impl
// -----------------------------------------------------------------------------

webgpu_device_get_adapter :: proc(device: Device, loc := #caller_location) -> Adapter {
    unimplemented(loc = loc)
}

webgpu_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    out: Handle_Packed
    webgpuDeviceCreateBindGroup(device, descriptor, &out)
    return new_handle_packed(Bind_Group, device, out)
}

webgpu_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    out: Handle_Packed
    webgpuDeviceCreateBindGroupLayout(device, descriptor, &out)
    return new_handle_packed(Bind_Group_Layout, device, out)
}

webgpu_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    out: Handle_Packed
    webgpuDeviceCreateBuffer(device, descriptor, &out)
    return new_handle_packed(Buffer, device, out)
}

webgpu_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Command_Encoder_Descriptor,
    loc := #caller_location,
) -> Command_Encoder {
    out: Handle_Packed
    webgpuDeviceCreateCommandEncoder(device, descriptor, &out)
    return new_handle_packed(Command_Encoder, device, out)
}

webgpu_device_create_compute_pipeline :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    loc := #caller_location,
) -> Compute_Pipeline {
    unimplemented(loc = loc)
}

webgpu_device_create_compute_pipeline_async :: proc(
    device: Device,
    descriptor: Compute_Pipeline_Descriptor,
    callback_info: Create_Compute_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

webgpu_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    out: Handle_Packed
    webgpuDeviceCreatePipelineLayout(device, descriptor, &out)
    return new_handle_packed(Pipeline_Layout, device, out)
}

webgpu_device_create_query_set :: proc(
    device: Device,
    descriptor: Query_Set_Descriptor,
    loc := #caller_location,
) -> Query_Set {
    unimplemented(loc = loc)
}

webgpu_device_create_render_bundle_encoder :: proc(
    device: Device,
    descriptor: Render_Bundle_Encoder_Descriptor,
    loc := #caller_location,
) -> Render_Bundle_Encoder {
    unimplemented(loc = loc)
}

webgpu_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    out: Handle_Packed
    webgpuDeviceCreateRenderPipeline(device, descriptor, &out)
    return new_handle_packed(Render_Pipeline, device, out)
}

webgpu_device_create_render_pipeline_async :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    callback_info: Create_Render_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

webgpu_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    out: Handle_Packed
    webgpuDeviceCreateSampler(device, descriptor, &out)
    return new_handle_packed(Sampler, device, out)
}

webgpu_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    #partial switch source in descriptor.source {
    case Shader_Source_WGSL:
        out: Handle_Packed
        webgpuDeviceCreateShaderModule(device, descriptor, &out)
        return new_handle_packed(Shader_Module, device, out)
    case:
        panic("WebGPU: Invalid shader source", loc)
    }
}

webgpu_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    out: Handle_Packed
    webgpuDeviceCreateTexture(device, descriptor, &out)
    return new_handle_packed(Texture, device, out)
}

webgpu_device_destroy :: proc(device: Device, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_device_get_adapter_info :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    info: Adapter_Info,
    status: Status,
) {
    unimplemented(loc = loc)
}

webgpu_device_get_features :: proc(
    device: Device,
    allocator := context.allocator,
    loc := #caller_location,
) -> []Feature_Name {
    unimplemented(loc = loc)
}

webgpu_device_get_features_view :: proc(
    device: Device,
    loc := #caller_location,
) -> []Feature_Name {
    unimplemented(loc = loc)
}

webgpu_device_get_limits :: proc(
    device: Device,
    loc := #caller_location,
) -> (
    limits: Limits,
    status: Status,
) {
    unimplemented(loc = loc)
}

webgpu_device_get_lost_future :: proc(device: Device, loc := #caller_location) -> Future {
    return webgpuDeviceGetLostFuture(device)
}

webgpu_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    queue_packed: Handle_Packed
    webgpuDeviceGetQueue(device, &queue_packed)
    return new_handle_packed(Queue, device, queue_packed)
}

webgpu_device_has_feature :: proc(
    device: Device,
    feature: Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

webgpu_device_pop_error_scope :: proc(
    device: Device,
    callback_info: Pop_Error_Scope_Callback_Info,
    loc := #caller_location,
) -> Future {
    return webgpuDevicePopErrorScope(device, callback_info)
}

webgpu_device_push_error_scope :: proc(
    device: Device,
    filter: Error_Filter,
    loc := #caller_location,
) {
    webgpuDevicePushErrorScope(device, filter)
}

webgpu_device_backend :: proc(device: Device, loc := #caller_location) -> Backend_Type {
    return .WebGPU
}

webgpu_device_is_embedded :: proc(device: Device, loc := #caller_location) -> bool {
    return false
}

webgpu_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    webgpuDeviceSetLabel(device, label)
}

webgpu_device_add_ref :: proc(device: Device, loc := #caller_location) {
    webgpuDeviceAddRef(device)
}

webgpu_device_release :: proc(device: Device, loc := #caller_location) {
    webgpuDeviceRelease(device)
}

// -----------------------------------------------------------------------------
// Procedures of External_Texture
// -----------------------------------------------------------------------------

webgpu_external_texture_set_label :: proc(
    external_texture: External_Texture,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_external_texture_add_ref :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_external_texture_release :: proc(external_texture: External_Texture, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Instance
// -----------------------------------------------------------------------------

webgpu_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    #partial switch source in descriptor.source {
    case Surface_Source_Canvas_HTML_Selector:
        assert(source.selector != "", "WebGPU: Invalid HTML selector", loc)
        return webgpuInstanceCreateSurface(instance, source)
    case:
        panic("WebGPU: Invalid surface source", loc)
    }
    unreachable()
}

webgpu_instance_get_wgsl_language_features :: proc(
    instance: Instance,
    loc := #caller_location,
) -> Supported_WGSL_Language_Features {
    unimplemented(loc = loc)
}

webgpu_instance_has_wgsl_language_feature :: proc(
    instance: Instance,
    feature: WGSL_Language_Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

webgpu_instance_process_events :: proc(instance: Instance, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_instance_create_adapter :: proc(
    instance: Instance,
    options: Request_Adapter_Options = {},
    loc := #caller_location,
) -> Adapter {
    return webgpuInstanceRequestAdapter(instance, options)
}

webgpu_instance_wait_any :: proc(
    instance: Instance,
    futures: []^Future_Wait_Info,
    timeout_ns: u64 = max(u64),
    loc := #caller_location,
) -> Wait_Status {
    unimplemented(loc = loc)
}

webgpu_generate_report :: proc(
    instance: Instance,
    loc := #caller_location,
) -> (
    report: Global_Report,
) {
    unimplemented(loc = loc)
}

webgpu_instance_enumerate_adapters :: proc(
    instance: Instance,
    options: ^Instance_Enumerate_Adapter_Options = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    adapters: []Adapter,
) {
    unimplemented(loc = loc)
}

webgpu_instance_backend :: proc(instance: Instance, loc := #caller_location) -> Backend_Type {
    return .WebGPU
}

webgpu_instance_is_embedded :: proc(instance: Instance, loc := #caller_location) -> bool {
    return false
}

webgpu_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    webgpuInstanceAddRef(instance)
}

webgpu_instance_release :: proc(instance: Instance, loc := #caller_location) {
    webgpuInstanceRelease(instance)
}

// -----------------------------------------------------------------------------
// Procedures of Pipeline_Layout
// -----------------------------------------------------------------------------

webgpu_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    webgpuPipelineLayoutAddRef(pipeline_layout)
}

webgpu_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    webgpuPipelineLayoutRelease(pipeline_layout)
}

// -----------------------------------------------------------------------------
// Procedures of Query_Set
// -----------------------------------------------------------------------------

webgpu_query_set_destroy :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_query_set_get_count :: proc(query_set: Query_Set, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

webgpu_query_set_get_type :: proc(query_set: Query_Set, loc := #caller_location) -> Query_Type {
    unimplemented(loc = loc)
}

webgpu_query_set_set_label :: proc(query_set: Query_Set, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_query_set_add_ref :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_query_set_release :: proc(query_set: Query_Set, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Queue
// -----------------------------------------------------------------------------

webgpu_queue_on_submitted_work_done :: proc(
    queue: Queue,
    callback_info: Queue_Work_Done_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

webgpu_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}
webgpu_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    webgpuQueueSubmit(queue, commands)
}

webgpu_queue_write_buffer_raw :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    webgpuQueueWriteBuffer(queue, buffer, buffer_offset, data, size)
}

webgpu_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []u8,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    webgpuQueueWriteTexture(
        queue, destination, raw_data(data), len(data), data_layout, write_size)
}

webgpu_queue_submit_for_index :: proc(
    queue: Queue,
    commands: []Command_Buffer,
    loc := #caller_location,
) -> Submission_Index {
    unimplemented(loc = loc)
}

webgpu_queue_get_timestamp_period :: proc(queue: Queue, loc := #caller_location) -> f32 {
    unimplemented(loc = loc)
}

webgpu_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_queue_release :: proc(queue: Queue, loc := #caller_location) {
    webgpuQueueRelease(queue)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle
// -----------------------------------------------------------------------------

webgpu_render_bundle_set_label :: proc(
    render_bundle: Render_Bundle,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_add_ref :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_release :: proc(render_bundle: Render_Bundle, loc := #caller_location) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Bundle_Encoder
// -----------------------------------------------------------------------------

webgpu_render_bundle_encoder_draw :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_draw_indexed :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_draw_indexed_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_draw_indirect :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_finish :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    descriptor: Render_Bundle_Descriptor,
    loc := #caller_location,
) -> Render_Bundle {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_insert_debug_marker :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_pop_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_push_debug_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_bind_group :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_immediates :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_index_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_label :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_pipeline :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_set_vertex_buffer :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_add_ref :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_bundle_encoder_release :: proc(
    render_bundle_encoder: Render_Bundle_Encoder,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Pass
// -----------------------------------------------------------------------------

webgpu_render_pass_begin_occlusion_query :: proc(
    render_pass: Render_Pass,
    query_index: u32,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderDraw(render_pass, vertex_count, instance_count, first_vertex, first_instance)
}

webgpu_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    base_vertex: i32,
    first_instance: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderDrawIndexed(render_pass, index_count, instance_count, first_index, base_vertex, first_instance)
}

webgpu_render_pass_draw_indexed_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_draw_indirect :: proc(
    render_pass: Render_Pass,
    indirect_buffer: Buffer,
    indirect_offset: u64,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_end :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderEnd(render_pass)
}

webgpu_render_pass_end_occlusion_query :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_execute_bundles :: proc(
    render_pass: Render_Pass,
    bundles: []Render_Bundle,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_insert_debug_marker :: proc(
    render_pass: Render_Pass,
    marker_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_pop_debug_group :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_push_debug_group :: proc(
    render_pass: Render_Pass,
    group_label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetBindGroup(render_pass, group_index, group, dynamic_offsets)
}

webgpu_render_pass_set_blend_constant :: proc(
    render_pass: Render_Pass,
    color: Color,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_set_immediates :: proc(
    render_pass: Render_Pass,
    offset: u32,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetIndexBuffer(render_pass, buffer, format, offset, size)
}

webgpu_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetPipeline(render_pass, pipeline)
}

webgpu_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetScissorRect(render_pass, x, y, width, height)
}

webgpu_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetStencilReference(render_pass, reference)
}

webgpu_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderSetVertexBuffer(render_pass, slot, buffer, offset, size)
}

webgpu_render_pass_set_viewport :: proc(
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

webgpu_render_pass_add_ref :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderAddRef(render_pass)
}

webgpu_render_pass_release :: proc(
    render_pass: Render_Pass,
    loc := #caller_location,
) {
    webgpuRenderPassEncoderRelease(render_pass)
}

// -----------------------------------------------------------------------------
// Procedures of Render_Pipeline
// -----------------------------------------------------------------------------

webgpu_render_pipeline_get_bind_group_layout :: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

webgpu_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    webgpuRenderPipelineAddRef(render_pipeline)
}

webgpu_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    webgpuRenderPipelineRelease(render_pipeline)
}

// -----------------------------------------------------------------------------
// Procedures of Sampler
// -----------------------------------------------------------------------------

webgpu_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    webgpuSamplerAddRef(sampler)
}

webgpu_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    webgpuSamplerRelease(sampler)
}

// -----------------------------------------------------------------------------
// Procedures of Shader_Module
// -----------------------------------------------------------------------------

webgpu_shader_module_get_compilation_info :: proc(
    shader_module: Shader_Module,
    callback_info: Compilation_Info_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

webgpu_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    webgpuShaderModuleAddRef(shader_module)
}

webgpu_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    webgpuShaderModuleRelease(shader_module)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_Features
// -----------------------------------------------------------------------------

webgpu_supported_features_free_members :: proc(
    features: []Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_Instance_Features
// -----------------------------------------------------------------------------

webgpu_supported_instance_features_free_members :: proc(
    features: []Instance_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_WGSL_Language_Features
// -----------------------------------------------------------------------------

webgpu_supported_wgsl_language_features_free_members :: proc(
    features: []WGSL_Language_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

// -----------------------------------------------------------------------------
// Procedures of Surface
// -----------------------------------------------------------------------------

webgpu_surface_configure :: proc(
    surface: Surface,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    webgpuSurfaceConfigure(surface, config)
}

webgpu_surface_get_capabilities :: proc(
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

webgpu_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (surface_texture: Surface_Texture) {
    webgpuSurfaceGetCurrentTexture(surface, &surface_texture)
    surface_texture.surface = surface
    return
}

webgpu_surface_present :: proc(surface: Surface, loc := #caller_location) -> Status {
    return webgpuSurfacePresent(surface)
}

webgpu_surface_texture_present :: proc(
    texture: Surface_Texture,
    loc := #caller_location,
) -> Status {
    assert(texture.surface != {}, "Surface texture has no surface", loc)
    return webgpu_surface_present(texture.surface, loc)
}

webgpu_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    webgpuSurfaceSetLabel(surface, label)
}

webgpu_surface_unconfigure :: proc(surface: Surface, loc := #caller_location) {
    webgpuSurfaceUnconfigure(surface)
}

webgpu_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    webgpuSurfaceAddRef(surface)
}

webgpu_surface_release :: proc(surface: Surface, loc := #caller_location) {
    webgpuSurfaceRelease(surface)
}

// -----------------------------------------------------------------------------
// Procedures of Surface_Capabilities
// -----------------------------------------------------------------------------

webgpu_surface_capabilities_free_members :: proc(
    surface_capabilities: Surface_Capabilities,
    allocator := context.allocator,
    loc := #caller_location,
) {
    webgpuSurfaceCapabilitiesFreeMembers(surface_capabilities)
}

// -----------------------------------------------------------------------------
// Procedures of Texture
// -----------------------------------------------------------------------------

webgpu_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor = {},
    loc := #caller_location,
) -> Texture_View {
    descriptor := descriptor
    view_packed: Handle_Packed
    webgpuTextureCreateView(texture, &descriptor if descriptor != {} else nil, &view_packed)
    return new_handle_packed(Texture_View, texture.device, view_packed)
}

webgpu_texture_destroy :: proc(texture: Texture, loc := #caller_location) {
    webgpuTextureDestroy(texture)
}

webgpu_texture_get_depth_or_array_layers :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetDepthOrArrayLayers(texture)
}

webgpu_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    unimplemented(loc = loc)
}

webgpu_texture_get_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Dimension {
    return webgpuTextureGetDimension(texture)
}

webgpu_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    return webgpuTextureGetFormat(texture)
}

webgpu_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetHeight(texture)
}

webgpu_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

webgpu_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetSampleCount(texture)
}

webgpu_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    out: Extent_3D
    webgpuTextureGetSize(texture, &out)
    return out
}

webgpu_texture_get_texture_binding_view_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_View_Dimension {
    return webgpuTextureGetTextureBindingViewDimension(texture)
}

webgpu_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    return webgpuTextureGetUsage(texture)
}

webgpu_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    return webgpuTextureGetWidth(texture)
}

webgpu_texture_set_label :: proc(texture: Texture, label: string, loc := #caller_location) {
    unimplemented(loc = loc)
}

webgpu_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    webgpuTextureAddRef(texture)
}

webgpu_texture_release :: proc(texture: Texture, loc := #caller_location) {
    webgpuTextureRelease(texture)
}

// -----------------------------------------------------------------------------
// Procedures of Texture_View
// -----------------------------------------------------------------------------

webgpu_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

webgpu_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    webgpuTextureViewAddRef(texture_view)
}

webgpu_texture_view_release :: proc(texture_view: Texture_View, loc := #caller_location) {
    webgpuTextureViewRelease(texture_view)
}
