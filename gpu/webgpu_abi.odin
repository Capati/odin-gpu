#+build js
package gpu

// Compile-time ABI contract for `wasm/webgpu.js`.
//
// The JS shim decodes and encodes these structs by hand out of linear memory,
// so field order, field sizes and offsets below are a hard contract: changing
// any of them requires the matching edit in `wasm/webgpu.js`. Every block names
// the shim function that reads or writes it.

// -----------------------------------------------------------------------------
// genericGetLimits / LimitsInline (webgpu.js `LIMIT_FIELDS`)
// -----------------------------------------------------------------------------
//
// The table in webgpu.js walks the fields in declaration order, using the
// field size for alignment, so u32/u64 order and offsets must match exactly.
#assert(offset_of(Limits, max_texture_dimension_1d) == 0)
#assert(offset_of(Limits, max_uniform_buffers_per_shader_stage) == 52)
#assert(offset_of(Limits, max_uniform_buffer_binding_size) == 56)
#assert(offset_of(Limits, max_storage_buffer_binding_size) == 64)
#assert(offset_of(Limits, min_uniform_buffer_offset_alignment) == 72)
#assert(offset_of(Limits, min_storage_buffer_offset_alignment) == 76)
#assert(offset_of(Limits, max_vertex_buffers) == 80)
#assert(offset_of(Limits, max_buffer_size) == 88)
#assert(offset_of(Limits, max_vertex_attributes) == 96)
#assert(offset_of(Limits, max_compute_workgroups_per_dimension) == 136)
#assert(offset_of(Limits, max_immediate_size) == 140)
#assert(offset_of(Limits, max_non_sampler_bindings) == 144)
#assert(offset_of(Limits, max_binding_array_elements_per_shader_stage) == 148)
#assert(offset_of(Limits, max_binding_array_sampler_elements_per_shader_stage) == 152)
#assert(offset_of(Limits, max_multiview_view_count) == 156)
#assert(size_of(Limits) == 160)

// -----------------------------------------------------------------------------
// genericGetFeatures (`sizes.Features`)
// -----------------------------------------------------------------------------
//
// `[dynamic; N]T` stores the elements inline followed by `len`, so the shim
// derives the length offset from this size instead of hardcoding a capacity.
#assert(FEATURE_COUNT == 83)
#assert(size_of(Features) == FEATURE_COUNT * size_of(Feature_Name) + size_of(int))

// -----------------------------------------------------------------------------
// CallbackInfo / UncapturedErrorCallbackInfo / DeviceLostCallbackInfo
// -----------------------------------------------------------------------------
//
// Two different shapes are in play:
//   * the async entry points take `{mode, callback, userdata1, userdata2}` (16)
//   * `Device_Descriptor` takes `{callback, userdata1, userdata2}` (12)
#assert(size_of(Callback_Mode) == 4)
#assert(size_of(Buffer_Map_Callback_Info) == 16)
#assert(offset_of(Buffer_Map_Callback_Info, mode) == 0)
#assert(offset_of(Buffer_Map_Callback_Info, callback) == 4)
#assert(offset_of(Buffer_Map_Callback_Info, userdata1) == 8)
#assert(offset_of(Buffer_Map_Callback_Info, userdata2) == 12)
#assert(size_of(Pop_Error_Scope_Callback_Info) == 16)
#assert(offset_of(Pop_Error_Scope_Callback_Info, callback) == 4)
#assert(size_of(Queue_Work_Done_Callback_Info) == 16)
#assert(size_of(Compilation_Info_Callback_Info) == 16)
#assert(size_of(Create_Compute_Pipeline_Async_Callback_Info) == 16)
#assert(size_of(Create_Render_Pipeline_Async_Callback_Info) == 16)

#assert(size_of(Device_Lost_Callback_Info) == 12)
#assert(offset_of(Device_Lost_Callback_Info, callback) == 0)
#assert(offset_of(Device_Lost_Callback_Info, userdata1) == 4)
#assert(offset_of(Device_Lost_Callback_Info, userdata2) == 8)
#assert(size_of(Uncaptured_Error_Callback_Info) == 12)
#assert(offset_of(Uncaptured_Error_Callback_Info, callback) == 0)

// -----------------------------------------------------------------------------
// webgpuAdapterRequestDevice (`Device_Descriptor` walk)
// -----------------------------------------------------------------------------

#assert(offset_of(Device_Descriptor, label) == 0)
#assert(offset_of(Device_Descriptor, required_features) == 8)
#assert(offset_of(Device_Descriptor, required_limits) == 16)
#assert(offset_of(Device_Descriptor, default_queue) == 176)
#assert(offset_of(Device_Descriptor, lost_callback_info) == 184)
#assert(offset_of(Device_Descriptor, uncaptured_error_callback_info) == 196)
#assert(size_of(Device_Descriptor) == 240)

// -----------------------------------------------------------------------------
// genericGetAdapterInfo / webgpuAdapterInfoFreeMembers
// -----------------------------------------------------------------------------

#assert(size_of(Adapter_Info) == 56)
#assert(offset_of(Adapter_Info, name) == 0)
#assert(offset_of(Adapter_Info, vendor) == 8)
#assert(offset_of(Adapter_Info, device) == 12)
#assert(offset_of(Adapter_Info, device_type) == 16)
#assert(offset_of(Adapter_Info, device_pci_bus_id) == 20)
#assert(offset_of(Adapter_Info, driver) == 28)
#assert(offset_of(Adapter_Info, driver_info) == 36)
#assert(offset_of(Adapter_Info, backend) == 44)
#assert(offset_of(Adapter_Info, subgroup_min_size) == 48)
#assert(offset_of(Adapter_Info, subgroup_max_size) == 52)

// -----------------------------------------------------------------------------
// webgpuDeviceCreateShaderModule (`Shader_Module_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Shader_Module_Descriptor) == 32)
#assert(offset_of(Shader_Module_Descriptor, label) == 0)
#assert(offset_of(Shader_Module_Descriptor, source) == 8)

// `gpu.Shader_Source` is a union: the 20-byte payload (its largest variant)
// followed by the tag byte, rounded to 24 with 4-byte alignment. The shim reads
// the WGSL string at the payload start and the tag at payload_size (`+20`), and
// expects the WGSL variant to be tag 2 (variants are tagged 1-based in
// declaration order: SPIRV=1, WGSL=2, ...).
#assert(size_of(Shader_Source) == 24)
#assert(align_of(Shader_Source) == 4)
#assert(size_of(Shader_Source_SLANG) == 20)
#assert(size_of(Shader_Source_MSL) == 20)
#assert(size_of(Shader_Source_Metallib) == 20)
#assert(size_of(Shader_Source_WGSL) == 8)

// -----------------------------------------------------------------------------
// ComputePipelineDescriptor (`Compute_Pipeline_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Compute_Pipeline_Descriptor) == 80)
#assert(offset_of(Compute_Pipeline_Descriptor, label) == 0)
#assert(offset_of(Compute_Pipeline_Descriptor, layout) == 8)
#assert(offset_of(Compute_Pipeline_Descriptor, module) == 24)
#assert(offset_of(Compute_Pipeline_Descriptor, entry_point) == 40)
#assert(offset_of(Compute_Pipeline_Descriptor, compilation_options) == 48)
#assert(offset_of(Compute_Pipeline_Descriptor, cache) == 64)

// -----------------------------------------------------------------------------
// webgpuDeviceCreateQuerySet (`Query_Set_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Query_Set_Descriptor) == 24)
#assert(offset_of(Query_Set_Descriptor, label) == 0)
#assert(offset_of(Query_Set_Descriptor, type) == 8)
#assert(offset_of(Query_Set_Descriptor, count) == 12)
#assert(offset_of(Query_Set_Descriptor, pipeline_statistics) == 16)
#assert(size_of(Query_Set) == 16) // distinct Handle: array element / descriptor field

// -----------------------------------------------------------------------------
// webgpuDeviceCreateRenderBundleEncoder (`Render_Bundle_Encoder_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Render_Bundle_Encoder_Descriptor) == 28)
#assert(offset_of(Render_Bundle_Encoder_Descriptor, label) == 0)
#assert(offset_of(Render_Bundle_Encoder_Descriptor, color_formats) == 8)
#assert(offset_of(Render_Bundle_Encoder_Descriptor, depth_stencil) == 16)
#assert(offset_of(Render_Bundle_Encoder_Descriptor, sample_count) == 20)
#assert(offset_of(Render_Bundle_Encoder_Descriptor, multiview) == 24)
#assert(size_of(Render_Bundle_Depth_Stencil) == 8)
#assert(offset_of(Render_Bundle_Depth_Stencil, depth_stencil_format) == 0)
#assert(offset_of(Render_Bundle_Depth_Stencil, depth_read_only) == 4)
#assert(offset_of(Render_Bundle_Depth_Stencil, stencil_read_only) == 5)

// -----------------------------------------------------------------------------
// webgpuRenderBundleEncoderFinish (`Render_Bundle_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Render_Bundle_Descriptor) == 8)
#assert(offset_of(Render_Bundle_Descriptor, label) == 0)

// -----------------------------------------------------------------------------
// webgpuCommandEncoderBeginComputePass (`Compute_Pass_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Compute_Pass_Descriptor) == 12)
#assert(offset_of(Compute_Pass_Descriptor, label) == 0)
#assert(offset_of(Compute_Pass_Descriptor, timestamp_writes) == 8)

// -----------------------------------------------------------------------------
// webgpuShaderModuleGetCompilationInfo
// -----------------------------------------------------------------------------
//
// The shim allocates `Compilation_Info`, `messages` and each message by hand.
#assert(size_of(Compilation_Info) == 8)
#assert(offset_of(Compilation_Info, messages) == 0)
#assert(size_of(Compilation_Message) == 48)
#assert(offset_of(Compilation_Message, message) == 0)
#assert(offset_of(Compilation_Message, message_type) == 8)
#assert(offset_of(Compilation_Message, line_num) == 16)
#assert(offset_of(Compilation_Message, line_pos) == 24)
#assert(offset_of(Compilation_Message, offset) == 32)
#assert(offset_of(Compilation_Message, length) == 40)

// -----------------------------------------------------------------------------
// webgpuRenderPassEncoderSetBlendConstant (`Color`)
// -----------------------------------------------------------------------------

#assert(size_of(Color) == 32)
#assert(align_of(Color) == 8)

// -----------------------------------------------------------------------------
// webgpuTextureCreateView (`Texture_View_Descriptor`)
// -----------------------------------------------------------------------------

#assert(size_of(Texture_View_Descriptor) == 64)
#assert(offset_of(Texture_View_Descriptor, swizzle) == 44)

// -----------------------------------------------------------------------------
// webgpuDeviceCreateSampler (`Sampler_Descriptor`)
// -----------------------------------------------------------------------------

#assert(offset_of(Sampler_Descriptor, mipmap_filter) == 28)
#assert(offset_of(Sampler_Descriptor, lod_max_clamp) == 36)
#assert(offset_of(Sampler_Descriptor, anisotropy_clamp) == 44)
#assert(offset_of(Sampler_Descriptor, border_color) == 48)
#assert(size_of(Sampler_Descriptor) == 52)

// -----------------------------------------------------------------------------
// Bind group unions: the shim reads the union tag at the end of the payload
// -----------------------------------------------------------------------------
//
// `Bind_Group_Entry.resource` @8 holds a 40-byte union (32-byte payload + tag),
// so the JS reads the tag at `start + 40`. `Bind_Group_Layout_Entry.type` @16
// holds a 24-byte union (16-byte payload + tag), so the tag is at `start + 32`.
#assert(size_of(Binding_Resource) == 40)
#assert(size_of(Buffer_Binding) == 32)
#assert(size_of(Binding_Type) == 24)
#assert(size_of(External_Texture_Binding_Layout) == 16)

// -----------------------------------------------------------------------------
// webgpuInstanceWaitAny (`Future` / `Future_Wait_Info`)
// -----------------------------------------------------------------------------
//
// The shim keeps a promise per future id and suspends the wasm stack until one
// of them settles, then writes `completed` for each entry.
#assert(size_of(Future) == 8)
#assert(offset_of(Future, id) == 0)
#assert(size_of(Future_Wait_Info) == 16)
#assert(offset_of(Future_Wait_Info, future) == 0)
#assert(offset_of(Future_Wait_Info, completed) == 8)

// -----------------------------------------------------------------------------
// webgpuGetInstanceFeatures / webgpuGetInstanceLimits
// -----------------------------------------------------------------------------
//
// `webgpu.js` builds `Supported_Instance_Features` and writes
// `Instance_Limits.timed_wait_any_max_count`, and it maps
// `Instance_Feature_Name` ordinals through the `InstanceFeatureName` table.
#assert(size_of(Supported_Instance_Features) == 8) // { features: []Instance_Feature_Name }
#assert(size_of(Instance_Limits) == 4)
#assert(offset_of(Instance_Limits, timed_wait_any_max_count) == 0)
#assert(size_of(Instance_Feature_Name) == 4)
// Ordinals walk the declaration order: extra features must be appended, not
// inserted, or the shim's answers shift.
#assert(int(Instance_Feature_Name.Timed_Wait_Any) == 0)
#assert(int(Instance_Feature_Name.Shader_Source_SPIRV) == 1)
#assert(int(Instance_Feature_Name.Multiple_Devices_Per_Adapter) == 2)

// -----------------------------------------------------------------------------
// Buffer_Map_State / Map_Async_Status ordinals
// -----------------------------------------------------------------------------

#assert(int(Buffer_Map_State.Unmapped) == 0)
#assert(int(Buffer_Map_State.Pending) == 1)
#assert(int(Buffer_Map_State.Mapped) == 2)
#assert(int(Map_Async_Status.Success) == 0)

// -----------------------------------------------------------------------------
// Handle: every resource type is `distinct Handle`
// -----------------------------------------------------------------------------

#assert(size_of(Handle) == 16)
#assert(offset_of(Handle, device) == 0)
#assert(offset_of(Handle, handle) == 8)
#assert(size_of(Command_Buffer) == 16)
#assert(size_of(Render_Bundle) == 16)
#assert(size_of(Texture) == 16)
#assert(size_of(Texture_View) == 16)
#assert(size_of(Buffer) == 16)
#assert(size_of(Sampler) == 16)
#assert(size_of(Bind_Group) == 16)
#assert(size_of(Bind_Group_Layout) == 16)
#assert(size_of(Pipeline_Layout) == 16)
#assert(size_of(Shader_Module) == 16)

// -----------------------------------------------------------------------------
// Queue
// -----------------------------------------------------------------------------

#assert(size_of(Queue_Descriptor) == 8)
#assert(size_of(Queue) == 16)
#assert(offset_of(Queue, handle) == 8)
#assert(offset_of(Command_Buffer, handle) == 8)

// -----------------------------------------------------------------------------
// Enum width (`odinEnum` / `odinEnumValue` read and write i32)
// -----------------------------------------------------------------------------

#assert(size_of(Texture_Format) == 4)
#assert(size_of(Present_Mode) == 4)
#assert(size_of(Composite_Alpha_Mode) == 4)
#assert(size_of(Surface_Color_Space) == 4)
#assert(size_of(Surface_Get_Current_Texture_Status) == 4)
#assert(size_of(Feature_Name) == 4)
#assert(int(Present_Mode.Fifo) == 0)

// -----------------------------------------------------------------------------
// Bit sets and raw pointers
// -----------------------------------------------------------------------------

#assert(size_of(Texture_Usages) == 8)
#assert(size_of(Shader_Stages) == 8)
#assert(size_of(Device) == 4)

// -----------------------------------------------------------------------------
// Surface
// -----------------------------------------------------------------------------

#assert(size_of(Surface_Format_Capabilities) == 8)
#assert(offset_of(Surface_Capabilities, format_capabilities) == 8)
#assert(offset_of(Surface_Capabilities, usages) == 32)
#assert(size_of(Surface_Capabilities) == 40)
#assert(offset_of(Surface_Configuration, usage) == 8)
#assert(offset_of(Surface_Configuration, format) == 16)
#assert(offset_of(Surface_Configuration, color_space) == 20)
#assert(offset_of(Surface_Configuration, width) == 24)
#assert(offset_of(Surface_Configuration, present_mode) == 32)
#assert(offset_of(Surface_Configuration, alpha_mode) == 40)
#assert(offset_of(Surface_Configuration, view_formats) == 44)
#assert(size_of(Surface_Configuration) == 56)
#assert(size_of(Surface_Texture) == 32)
#assert(offset_of(Surface_Texture, texture) == 8)
#assert(offset_of(Surface_Texture, status) == 24)

// -----------------------------------------------------------------------------
// Render pass
// -----------------------------------------------------------------------------

#assert(size_of(Render_Pass_Descriptor) == 48)
#assert(offset_of(Render_Pass_Descriptor, occlusion_query_set) == 24)
#assert(offset_of(Render_Pass_Descriptor, multiview_mask) == 40)
#assert(size_of(Render_Pass_Color_Attachment) == 80)
#assert(offset_of(Render_Pass_Color_Attachment, resolve_target) == 24)
#assert(offset_of(Render_Pass_Color_Attachment, ops) == 40)
#assert(offset_of(Operations(Color), clear_value) == 8)
#assert(size_of(Operations(Color)) == 40)
#assert(size_of(Operations(f32)) == 12)
#assert(size_of(Render_Pass_Depth_Stencil_Attachment) == 48)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, depth_ops) == 16)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, stencil_ops) == 28)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, depth_read_only) == 40)
#assert(offset_of(Render_Pass_Depth_Stencil_Attachment, stencil_read_only) == 41)
#assert(size_of(Render_Pass_Timestamp_Writes) == 24)

// -----------------------------------------------------------------------------
// Vertex state
// -----------------------------------------------------------------------------

#assert(size_of(Vertex_State) == 48)
#assert(offset_of(Vertex_State, entry_point) == 16)
#assert(offset_of(Vertex_State, compilation_options) == 24)
#assert(offset_of(Vertex_State, buffers) == 36)
#assert(size_of(Pipeline_Compilation_Options) == 12)
#assert(size_of(Constant_Entry) == 16)
#assert(size_of(Vertex_Buffer_Layout) == 24)
#assert(offset_of(Vertex_Buffer_Layout, step_mode) == 8)
#assert(offset_of(Vertex_Buffer_Layout, attributes) == 12)
#assert(size_of(Vertex_Attribute) == 24)
#assert(offset_of(Vertex_Attribute, offset) == 8)
#assert(offset_of(Vertex_Attribute, shader_location) == 16)

// -----------------------------------------------------------------------------
// Texture descriptor
// -----------------------------------------------------------------------------

#assert(size_of(Extent_3D) == 12)
#assert(offset_of(Texture_Descriptor, size) == 8)
#assert(offset_of(Texture_Descriptor, mip_level_count) == 20)
#assert(offset_of(Texture_Descriptor, dimension) == 28)
#assert(offset_of(Texture_Descriptor, format) == 32)
#assert(offset_of(Texture_Descriptor, usage) == 40)
#assert(offset_of(Texture_Descriptor, view_formats) == 48)
#assert(size_of(Texture_Descriptor) == 56)

// -----------------------------------------------------------------------------
// Bind group layout / bind group
// -----------------------------------------------------------------------------

#assert(size_of(Buffer_Binding_Layout) == 16)
#assert(size_of(Texture_Binding_Layout) == 12)
#assert(size_of(Bind_Group_Layout_Entry) == 48)
#assert(offset_of(Bind_Group_Layout_Entry, visibility) == 8)
#assert(offset_of(Bind_Group_Layout_Entry, type) == 16)
#assert(offset_of(Bind_Group_Layout_Entry, count) == 40)
#assert(size_of(Bind_Group_Layout_Descriptor) == 16)
#assert(size_of(Bind_Group_Entry) == 48)
#assert(offset_of(Bind_Group_Entry, resource) == 8)
#assert(size_of(Bind_Group_Descriptor) == 32)
#assert(offset_of(Bind_Group_Descriptor, layout) == 8)
#assert(offset_of(Bind_Group_Descriptor, entries) == 24)

// -----------------------------------------------------------------------------
// Pipeline layout
// -----------------------------------------------------------------------------

#assert(offset_of(Pipeline_Layout_Descriptor, bind_group_layouts) == 8)
#assert(offset_of(Pipeline_Layout_Descriptor, immediate_size) == 16)
#assert(size_of(Pipeline_Layout_Descriptor) == 20)

// -----------------------------------------------------------------------------
// Texel copy
// -----------------------------------------------------------------------------

#assert(size_of(Origin_3D) == 12)
#assert(size_of(Texel_Copy_Buffer_Layout) == 16)
#assert(offset_of(Texel_Copy_Buffer_Layout, bytes_per_row) == 8)
#assert(size_of(Texel_Copy_Texture_Info) == 40)
#assert(offset_of(Texel_Copy_Texture_Info, origin) == 20)
#assert(offset_of(Texel_Copy_Texture_Info, aspect) == 32)
#assert(size_of(Texel_Copy_Buffer_Info) == 32)
#assert(offset_of(Texel_Copy_Buffer_Info, layout) == 16)

// -----------------------------------------------------------------------------
// Sampler
// -----------------------------------------------------------------------------

#assert(offset_of(Sampler_Descriptor, address_mode_u) == 8)
#assert(offset_of(Sampler_Descriptor, lod_min_clamp) == 32)
#assert(offset_of(Sampler_Descriptor, compare) == 40)

// -----------------------------------------------------------------------------
// Slices passed on the stack
// -----------------------------------------------------------------------------

#assert(size_of([]Command_Buffer) == 8)
