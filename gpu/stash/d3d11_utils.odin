#+build windows
package gpu

// // Vendor
// import "vendor:directx/d3d11"

// d3d11_encode_basic_filter :: #force_inline proc(
//     min, mag, mip: d3d11.FILTER_TYPE,
//     reduction: d3d11.FILTER_REDUCTION_TYPE,
// ) -> d3d11.FILTER {
//     return d3d11.FILTER(
//         ((u32(min) & d3d11.FILTER_TYPE_MASK) << d3d11.MIN_FILTER_SHIFT) |
//         ((u32(mag) & d3d11.FILTER_TYPE_MASK) << d3d11.MAG_FILTER_SHIFT) |
//         ((u32(mip) & d3d11.FILTER_TYPE_MASK) << d3d11.MIP_FILTER_SHIFT) |
//         ((u32(reduction) & d3d11.FILTER_REDUCTION_TYPE_MASK) << d3d11.FILTER_REDUCTION_TYPE_SHIFT))
// }

// d3d11_encode_anisotropic_filter :: #force_inline proc(
//     reduction: d3d11.FILTER_REDUCTION_TYPE = .STANDARD,
// ) -> d3d11.FILTER {
//     return d3d11.FILTER(
//         u32(d3d11.ANISOTROPIC_FILTERING_BIT) |
//         u32(d3d11_encode_basic_filter(
//             .LINEAR,
//             .LINEAR,
//             .LINEAR,
//             reduction)))
// }

// D3D11_CONSTANT_BUFFER_ALIGNMENT :: size_of(f32) * 4 * 16  // 256 bytes
// D3D11_STORAGE_BUFFER_ALIGNMENT  :: size_of(u32)           // 4 bytes

// d3d11_buffer_size_alignment :: proc(usage: Buffer_Usages) -> u32 {
//     if .Uniform in usage {
//         // Each number of constants must be a multiple of 16 shader constants
//         return D3D11_CONSTANT_BUFFER_ALIGNMENT
//     }

//     if .Storage in usage || .Copy_Src in usage || .Copy_Dst in usage {
//         // Unordered access buffers must be 4-byte aligned
//         // Also for Copy_Dst/Copy_Src buffers used in compute shaders
//         return D3D11_STORAGE_BUFFER_ALIGNMENT
//     }

//     return 1
// }

// D3D11_Command_Recording_Context :: struct {
//     d3d_device:              ^D3D11_IDevice3,
//     d3d_context:             ^D3D11_IDeviceContext3,
//     d3d_context_fence:       ^D3D11_IDeviceContext4,
//     uniform_buffer:          ^d3d11.IBuffer,
//     user_defined_annotation: ^D3D11_ID3DUserDefinedAnnotation,
//     device_context_state:    ^D3D11_ID3DDeviceContextState,
//     is_recording:            bool,
//     has_fence:               bool,
// }

// d3d11_command_recording_context_init :: proc(
//     self: ^D3D11_Command_Recording_Context,
//     d3d_device: ^D3D11_IDevice3,
//     has_fence: bool,
//     loc := #caller_location,
// ) {
//     self.d3d_device = d3d_device
//     self.has_fence = has_fence

//     // Create the temp base context
//     context_base: ^d3d11.IDeviceContext
//     self.d3d_device->GetImmediateContext(&context_base)
//     defer context_base->Release()

//     // Query the required context
//     d3d_check(context_base->QueryInterface(
//         D3D11_IDeviceContext3_UUID, (^rawptr)(&self.d3d_context)), loc = loc)

//     // Query for user defined annotation
//     d3d_check(self.d3d_context->QueryInterface(d3d11.IUserDefinedAnnotation_UUID,
//         cast(^rawptr)&self.user_defined_annotation), loc = loc)

//     if self.has_fence {
//         d3d_check(context_base->QueryInterface(
//             D3D11_IDeviceContext4_UUID, (^rawptr)(&self.d3d_context_fence)))
//     }

//     // Create internal uniform buffer for immediates
//     buf_desc := d3d11.BUFFER_DESC {
//         ByteWidth      = MAX_IMMEDIATE_DATA_BYTES * 4,
//         Usage          = .DYNAMIC,
//         BindFlags      = {.CONSTANT_BUFFER},
//         CPUAccessFlags = {.WRITE},
//         MiscFlags      = {},
//     }
//     self.d3d_device->CreateBuffer(&buf_desc, nil, &self.uniform_buffer)
// }

// d3d11_command_recording_context_uninit :: proc(self: ^D3D11_Command_Recording_Context) {
//     if self.d3d_context_fence != nil { self.d3d_context_fence->Release() }
//     if self.d3d_context != nil { self.d3d_context->Release() }
//     if self.uniform_buffer != nil { self.uniform_buffer->Release() }
//     if self.user_defined_annotation != nil { self.user_defined_annotation->Release() }
// }

// D3D11_Temp_Resource :: union {
//     Staging_Buffer,
// }

// D3D11_Transfer_Batch :: struct {
//     temp_resources: [dynamic]D3D11_Temp_Resource,
//     dst_buffers:    map[Buffer]bool,
// }

// d3d11_transfer_batch_insert_buffer :: proc(batch: ^D3D11_Transfer_Batch, buffer: Buffer) {
//     batch.dst_buffers[buffer] = true
// }

// d3d11_transfer_batch_contains_buffer :: proc(
//     batch: ^D3D11_Transfer_Batch, buffer: Buffer,
// ) -> bool {
//     return buffer in batch.dst_buffers
// }

// d3d11_transfer_batch_consume :: proc(batch: ^D3D11_Transfer_Batch, resource: D3D11_Temp_Resource) {
//     append(&batch.temp_resources, resource)
// }

// d3d11_transfer_batch_flush :: proc(
//     batch: ^D3D11_Transfer_Batch,
//     device: Device,
//     loc := #caller_location,
// ) {
//     if len(batch.dst_buffers) == 0 && len(batch.temp_resources) == 0 {
//         return
//     }

//     impl := d3d11_device_get_impl(device, loc)
//     cmdbuf_impl := &impl.queue.stgbuf
//     d3d11_record_commands(device, cmdbuf_impl, loc)

//     for res in batch.temp_resources {
//         switch v in res {
//         case Staging_Buffer:
//             d3d11_buffer_release(v.buffer, loc)
//         }
//     }

//     command_allocator_reset(&cmdbuf_impl.commands)

//     clear(&batch.temp_resources)
//     clear(&batch.dst_buffers)
// }

// // Type of buffer where each is a different real GPU resource that might exist
// // for the same logical buffer.
// D3D11_Buffer_Storage_Type :: enum u8 {
//     // write-mapping + constant buffer usage
//     CPU_Writable_Constant_Buffer,
//     // CopyB2B dst with constant buffer usage
//     GPU_Copy_Dst_Constant_Buffer,
//     // write-mapping + other usages
//     CPU_Writable_Non_Constant_Buffer,
//     // GPU writes + other usages
//     GPU_Writable_Non_Constant_Buffer,
//     // CPU read (and CPU write fallback when no default-storage aliasing)
//     Staging,
// }

// D3D11_BUFFER_STORAGE_COUNT :: len(D3D11_Buffer_Storage_Type)

// D3D11_Buffer_Storage :: struct {
//     buffer:                  ^d3d11.IBuffer,
//     revision:                u64,
//     usage:                   d3d11.USAGE,
//     is_constant_buffer:      bool,
//     mappable_copyable_flags: Buffer_Usages,
//     storage_type:            D3D11_Buffer_Storage_Type,
// }

// d3d11_buffer_storage_init :: proc(
//     self: ^D3D11_Buffer_Storage,
//     buffer: ^d3d11.IBuffer,
//     storage_type: D3D11_Buffer_Storage_Type,
// ) {
//     self.buffer       = buffer
//     self.storage_type = storage_type

//     desc: d3d11.BUFFER_DESC
//     buffer->GetDesc(&desc)
//     self.usage = desc.Usage

//     self.mappable_copyable_flags = {.Copy_Src}

//     #partial switch self.usage {
//     case .STAGING, .DEFAULT:
//         self.mappable_copyable_flags |= {.Copy_Dst}
//     }

//     if .READ in desc.CPUAccessFlags {
//         self.mappable_copyable_flags |= {.Map_Read}
//     }
//     if .WRITE in desc.CPUAccessFlags {
//         self.mappable_copyable_flags |= {.Map_Write}
//     }

//     self.is_constant_buffer = .CONSTANT_BUFFER in desc.BindFlags
// }

// d3d11_buffer_storage_get_storage_type :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> D3D11_Buffer_Storage_Type {
//     return self.storage_type
// }

// d3d11_buffer_storage_get_buffer :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> ^d3d11.IBuffer {
//     return self.buffer
// }

// d3d11_buffer_storage_get_revision :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> u64 {
//     return self.revision
// }

// d3d11_buffer_storage_set_revision :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage, revision: u64,
// ) {
//     self.revision = revision
// }

// d3d11_buffer_storage_is_first_revision :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//      return self.revision == 0
// }

// d3d11_buffer_storage_is_constant_buffer :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//      return self.is_constant_buffer
// }

// d3d11_buffer_storage_is_cpu_writable :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//     return .Map_Write in self.mappable_copyable_flags
// }

// d3d11_buffer_storage_is_cpu_readable :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//     return .Map_Read in self.mappable_copyable_flags
// }

// d3d11_buffer_storage_is_dynamic :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//     return self.usage == .DYNAMIC
// }

// d3d11_buffer_storage_supports_copy_dst :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//     return .Copy_Dst in self.mappable_copyable_flags
// }

// d3d11_buffer_storage_is_gpu_writable :: #force_inline proc "contextless" (
//     self: ^D3D11_Buffer_Storage,
// ) -> bool {
//     return self.usage == .DEFAULT
// }

// D3D11_Vertex_Buffer_Tracker :: struct {
//     d3d11_buffers:            [MAX_VERTEX_BUFFERS]^d3d11.IBuffer,
//     strides:                  [MAX_VERTEX_BUFFERS]u32,
//     offsets:                  [MAX_VERTEX_BUFFERS]u32,
//     dirty:                    bit_set[0..<MAX_VERTEX_BUFFERS],
//     last_applied_pipeline:    Render_Pipeline,
//     has_last_applied_pipeline: bool,
// }

// d3d11_vertex_buffer_tracker_reset :: proc(
//     t: ^D3D11_Vertex_Buffer_Tracker,
//     ctx: ^d3d11.IDeviceContext,
// ) {
//     t.d3d11_buffers = {}
//     t.strides       = {}
//     t.offsets       = {}
//     ctx->IASetVertexBuffers(
//         0, MAX_VERTEX_BUFFERS, &t.d3d11_buffers[0], &t.strides[0], &t.offsets[0])
// }

// d3d11_vertex_buffer_tracker_on_set :: proc(
//     t: ^D3D11_Vertex_Buffer_Tracker,
//     slot: u32,
//     buffer: ^d3d11.IBuffer,
//     offset: u32,
// ) {
//     if t.d3d11_buffers[slot] == buffer && t.offsets[slot] == offset {
//         return
//     }
//     t.d3d11_buffers[slot] = buffer
//     t.offsets[slot]       = offset
//     t.dirty              += {int(slot)}
// }

// d3d11_vertex_buffer_tracker_apply :: proc(
//     t: ^D3D11_Vertex_Buffer_Tracker,
//     ctx: ^d3d11.IDeviceContext,
//     pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     pipeline_impl := d3d11_render_pipeline_get_impl(pipeline, loc)

//     if !t.has_last_applied_pipeline || t.last_applied_pipeline != pipeline {
//         t.last_applied_pipeline     = pipeline
//         t.has_last_applied_pipeline = true

//         for &vb, slot in pipeline_impl.vertex_buffers {
//             stride := vb.stride
//             if t.strides[slot] == stride {
//                 continue
//             }
//             t.strides[slot] = stride
//             t.dirty         += {slot}
//         }
//     }

//     for slot in 0 ..< len(pipeline_impl.vertex_buffers) {
//         if slot not_in t.dirty {
//             continue
//         }
//         ctx->IASetVertexBuffers(
//             u32(slot), 1, &t.d3d11_buffers[slot], &t.strides[slot], &t.offsets[slot])
//         t.dirty -= {slot}
//     }
// }

// D3D11_Bind_Group_Tracker :: struct {
//     d3d_context:              ^D3D11_IDeviceContext3,

//     bind_groups:              [MAX_BIND_GROUPS]Bind_Group,
//     dynamic_offsets:          [MAX_BIND_GROUPS][]u32,
//     dirty_groups:             u32, // bitmask over group index

//     last_pipeline_layout:     Pipeline_Layout,

//     cbv_slots:                [Shader_Stage][d3d11.COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT]^d3d11.IBuffer,
//     srv_slots:                [Shader_Stage][d3d11.COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT]^d3d11.IShaderResourceView,
//     sampler_slots:            [Shader_Stage][d3d11.COMMONSHADER_SAMPLER_SLOT_COUNT]^d3d11.ISamplerState,
//     cs_uav_slots:             [d3d11._1_UAV_SLOT_COUNT]^d3d11.IUnorderedAccessView,

//     pixel_local_storage_uavs: []^d3d11.IUnorderedAccessView,
// }

// d3d11_bind_group_tracker_init :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     d3d_context: ^D3D11_IDeviceContext3,
//     pixel_local_storage_uavs: []^d3d11.IUnorderedAccessView = nil,
// ) {
//     tracker.d3d_context = d3d_context
//     tracker.pixel_local_storage_uavs = pixel_local_storage_uavs
// }

// d3d11_bind_group_tracker_on_set_bind_group :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     index: u32,
//     bind_group: Bind_Group,
//     dynamic_offsets: []u32,
// ) {
//     tracker.bind_groups[index] = bind_group
//     tracker.dynamic_offsets[index] = dynamic_offsets
//     tracker.dirty_groups |= 1 << index
// }

// d3d11_bind_group_tracker_on_set_pipeline :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     pipeline_layout: Pipeline_Layout,
// ) {
//     if pipeline_layout != tracker.last_pipeline_layout {
//         for i in 0 ..< MAX_BIND_GROUPS {
//             if tracker.bind_groups[i] != nil {
//                 tracker.dirty_groups |= 1 << u32(i)
//             }
//         }
//         tracker.last_pipeline_layout = pipeline_layout
//     }
// }

// d3d11_bind_group_tracker_set_cbv :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     stage: Shader_Stage,
//     slot: u32,
//     buf: ^d3d11.IBuffer,
//     first_constant: u32,
//     num_constants: u32,
// ) {
//     if tracker.cbv_slots[stage][slot] == buf {
//         return
//     }
//     buf_ptr := buf
//     first_constant := first_constant
//     num_constants := num_constants
//     switch stage {
//     case .Vertex:
//         tracker.d3d_context->VSSetConstantBuffers1(
//             slot, 1, &buf_ptr, &first_constant, &num_constants)
//     case .Fragment:
//         tracker.d3d_context->PSSetConstantBuffers1(
//             slot, 1, &buf_ptr, &first_constant, &num_constants)
//     case .Compute:
//         tracker.d3d_context->CSSetConstantBuffers1(
//             slot, 1, &buf_ptr, &first_constant, &num_constants)
//     }
//     tracker.cbv_slots[stage][slot] = buf
// }

// d3d11_bind_group_tracker_set_srv :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     stage: Shader_Stage,
//     slot: u32,
//     srv: ^d3d11.IShaderResourceView,
// ) {
//     if tracker.srv_slots[stage][slot] == srv {
//         return
//     }
//     srv_ptr := srv
//     switch stage {
//     case .Vertex:
//         tracker.d3d_context->VSSetShaderResources(slot, 1, &srv_ptr)
//     case .Fragment:
//         tracker.d3d_context->PSSetShaderResources(slot, 1, &srv_ptr)
//     case .Compute:
//         tracker.d3d_context->CSSetShaderResources(slot, 1, &srv_ptr)
//     }
//     tracker.srv_slots[stage][slot] = srv
// }

// d3d11_bind_group_tracker_set_sampler :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     stage: Shader_Stage,
//     slot: u32,
//     samp: ^d3d11.ISamplerState,
// ) {
//     if tracker.sampler_slots[stage][slot] == samp {
//         return
//     }
//     samp_ptr := samp
//     switch stage {
//     case .Vertex:
//         tracker.d3d_context->VSSetSamplers(slot, 1, &samp_ptr)
//     case .Fragment:
//         tracker.d3d_context->PSSetSamplers(slot, 1, &samp_ptr)
//     case .Compute:
//         tracker.d3d_context->CSSetSamplers(slot, 1, &samp_ptr)
//     }
//     tracker.sampler_slots[stage][slot] = samp
// }

// d3d11_bind_group_tracker_apply :: proc(
//     tracker: ^D3D11_Bind_Group_Tracker,
//     active_pipeline: Render_Pipeline,
//     loc := #caller_location,
// ) {
//     if tracker.dirty_groups == 0 {
//         return
//     }

//     pipeline_impl := d3d11_render_pipeline_get_impl(active_pipeline, loc)
//     pipeline_layout := d3d11_pipeline_layout_get_impl(pipeline_impl.layout, loc)

//     // Collect all fragment-visible UAVs across every group
//     fragment_uav_count := pipeline_layout.uav_count[.Fragment]
//     pls_count := u32(len(tracker.pixel_local_storage_uavs))

//     if fragment_uav_count > 0 || pls_count > 0 {
//         combined := make(
//             []^d3d11.IUnorderedAccessView,
//             fragment_uav_count + pls_count,
//             context.temp_allocator,
//         )

//         for group_index in 0 ..< MAX_BIND_GROUPS {
//             if pipeline_layout.uav_bind_group_mask & (1 << u32(group_index)) == 0 {
//                 continue
//             }
//             bind_group := tracker.bind_groups[group_index]
//             if bind_group == nil {
//                 continue
//             }
//             bg_impl := d3d11_bind_group_get_impl(bind_group, loc)
//             bgl_impl := d3d11_bind_group_layout_get_impl(bg_impl.layout, loc)

//             for entry, i in bg_impl.entries {
//                 layout_entry := bgl_impl.entries[i]
//                 if !d3d11_is_uav_binding(layout_entry) || .Fragment not_in layout_entry.visibility {
//                     continue
//                 }

//                 slots := pipeline_layout.binding_map[group_index][layout_entry.binding]
//                 pos := slots[.Fragment] - pipeline_layout.uav_start_index_fragment

//                 uav: ^d3d11.IUnorderedAccessView
//                 if layout_entry.buffer.type == .Storage {
//                     buffer_impl := d3d11_buffer_get_impl(entry.buffer, loc)
//                     device_impl := d3d11_device_get_impl(buffer_impl.device, loc)
//                     uav = d3d11_buffer_get_or_create_uav(
//                         buffer_impl,
//                         tracker.d3d_context,
//                         device_impl,
//                         entry.offset,
//                         entry.size,
//                         loc)
//                 } else {
//                     view_impl := d3d11_texture_view_get_impl(entry.texture_view, loc)
//                     uav = d3d11_texture_view_get_or_create_uav(view_impl, loc)
//                 }
//                 combined[pos] = uav
//             }
//         }

//         for uav, i in tracker.pixel_local_storage_uavs {
//             combined[fragment_uav_count + u32(i)] = uav
//         }

//         tracker.d3d_context->OMSetRenderTargetsAndUnorderedAccessViews(
//             d3d11.KEEP_RENDER_TARGETS_AND_DEPTH_STENCIL,
//             nil, nil,
//             pipeline_layout.uav_start_index_fragment,
//             u32(len(combined)),
//             raw_data(combined),
//             nil,
//         )
//     }

//     // CBV / SRV / sampler for dirty groups only
//     for group_index in 0 ..< MAX_BIND_GROUPS {
//         if tracker.dirty_groups & (1 << u32(group_index)) == 0 {
//             continue
//         }
//         bind_group := tracker.bind_groups[group_index]
//         if bind_group == nil {
//             continue
//         }

//         bg_impl := d3d11_bind_group_get_impl(bind_group, loc)
//         bgl_impl := d3d11_bind_group_layout_get_impl(bg_impl.layout, loc)
//         dynamic_offsets := tracker.dynamic_offsets[group_index]

//         for entry, i in bg_impl.entries {
//             layout_entry := bgl_impl.entries[i]
//             if d3d11_is_uav_binding(layout_entry) {
//                 continue // already handled
//             }
//             slots := pipeline_layout.binding_map[group_index][layout_entry.binding]

//             switch {
//             case d3d11_is_uniform_binding(layout_entry):
//                 buffer_impl := d3d11_buffer_get_impl(entry.buffer, loc)
//                 offset := entry.offset
//                 if layout_entry.buffer.has_dynamic_offset {
//                     offset += u64(dynamic_offsets[i])
//                 }
//                 buf := d3d11_buffer_get_constant_buffer(buffer_impl, tracker.d3d_context, loc)
//                 first_constant := u32(offset / 16)
//                 size_in_constants := u32(align_size(entry.size, 16) / 16)
//                 num_constants := u32(align_size(size_in_constants, 16))

//                 if slots[.Vertex] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_cbv(
//                         tracker, .Vertex, slots[.Vertex], buf, first_constant, num_constants)
//                 }
//                 if slots[.Fragment] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_cbv(
//                         tracker, .Fragment, slots[.Fragment], buf, first_constant, num_constants)
//                 }

//             case d3d11_is_sampler_binding(layout_entry):
//                 sampler_impl := d3d11_sampler_get_impl(entry.sampler, loc)
//                 if slots[.Vertex] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_sampler(
//                         tracker, .Vertex, slots[.Vertex], sampler_impl.sampler_state)
//                 }
//                 if slots[.Fragment] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_sampler(
//                         tracker, .Fragment, slots[.Fragment], sampler_impl.sampler_state)
//                 }

//             case: // SRV
//                 view_impl := d3d11_texture_view_get_impl(entry.texture_view, loc)
//                 srv: ^d3d11.IShaderResourceView
//                 if layout_entry.buffer.type == .Read_Only_Storage {
//                     buffer_impl := d3d11_buffer_get_impl(entry.buffer, loc)
//                     offset := entry.offset
//                     if layout_entry.buffer.has_dynamic_offset {
//                         offset += u64(dynamic_offsets[i])
//                     }
//                     srv = d3d11_buffer_get_or_create_srv(
//                         buffer_impl, tracker.d3d_context, offset, entry.size, loc)
//                 } else {
//                     srv = d3d11_texture_view_get_or_create_srv(view_impl, loc)
//                 }
//                 if slots[.Vertex] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_srv(tracker, .Vertex, slots[.Vertex], srv)
//                 }
//                 if slots[.Fragment] != D3D11_INVALID_SLOT {
//                     d3d11_bind_group_tracker_set_srv(tracker, .Fragment, slots[.Fragment], srv)
//                 }
//             }
//         }
//     }

//     tracker.dirty_groups = 0
// }
