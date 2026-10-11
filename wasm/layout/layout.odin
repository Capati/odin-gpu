#+build js
package layout

import "core:fmt"

import gpu "../../gpu"

sizes :: proc(name: string, size: int, align: int) {
    fmt.printf("%-40s size=%-4v align=%v\n", name, size, align)
}

field :: proc(name: string, off: uintptr) {
    fmt.printf("    %-36s @%-4v\n", name, off)
}

// Shorthand: field(#field, offset_of(T, f))
F :: proc(name: string, off: uintptr) {field(name, off)}

main :: proc() {
    fmt.printf("\n=== scalars ===\n")
    sizes("int", size_of(int), align_of(int))
    sizes("u16", size_of(u16), align_of(u16))
    sizes("u32", size_of(u32), align_of(u32))
    sizes("u64", size_of(u64), align_of(u64))
    sizes("f32", size_of(f32), align_of(f32))
    sizes("f64", size_of(f64), align_of(f64))
    sizes("bool", size_of(bool), align_of(bool))
    sizes("rawptr", size_of(rawptr), align_of(rawptr))
    sizes("string", size_of(string), align_of(string))
    sizes("[]u32", size_of([]u32), align_of([]u32))

    fmt.printf("\n=== enums / bit_sets ===\n")
    sizes("Texture_Format", size_of(gpu.Texture_Format), align_of(gpu.Texture_Format))
    sizes("Texture_Usages", size_of(gpu.Texture_Usages), align_of(gpu.Texture_Usages))
    sizes("Shader_Stages", size_of(gpu.Shader_Stages), align_of(gpu.Shader_Stages))
    sizes("Present_Mode", size_of(gpu.Present_Mode), align_of(gpu.Present_Mode))
    sizes(
        "Composite_Alpha_Mode",
        size_of(gpu.Composite_Alpha_Mode),
        align_of(gpu.Composite_Alpha_Mode),
    )
    sizes(
        "Surface_Color_Space",
        size_of(gpu.Surface_Color_Space),
        align_of(gpu.Surface_Color_Space),
    )
    sizes(
        "Surface_Get_Current_Texture_Status",
        size_of(gpu.Surface_Get_Current_Texture_Status),
        align_of(gpu.Surface_Get_Current_Texture_Status),
    )
    sizes("Feature_Name", size_of(gpu.Feature_Name), align_of(gpu.Feature_Name))
    sizes("Compare_Function", size_of(gpu.Compare_Function), align_of(gpu.Compare_Function))
    sizes("Load_Op", size_of(gpu.Load_Op), align_of(gpu.Load_Op))
    sizes("Store_Op", size_of(gpu.Store_Op), align_of(gpu.Store_Op))
    sizes(
        "Buffer_Binding_Type",
        size_of(gpu.Buffer_Binding_Type),
        align_of(gpu.Buffer_Binding_Type),
    )

    fmt.printf("\n=== handles ===\n")
    sizes("Handle_Packed", size_of(gpu.Handle_Packed), align_of(gpu.Handle_Packed))
    sizes("Handle", size_of(gpu.Handle), align_of(gpu.Handle))
    F("device", offset_of(gpu.Handle, device))
    F("handle", offset_of(gpu.Handle, handle))
    sizes("Device", size_of(gpu.Device), align_of(gpu.Device))
    sizes("Queue", size_of(gpu.Queue), align_of(gpu.Queue))
    sizes("Texture", size_of(gpu.Texture), align_of(gpu.Texture))
    sizes("Texture_View", size_of(gpu.Texture_View), align_of(gpu.Texture_View))
    sizes("Buffer", size_of(gpu.Buffer), align_of(gpu.Buffer))
    sizes("Sampler", size_of(gpu.Sampler), align_of(gpu.Sampler))
    sizes("Bind_Group", size_of(gpu.Bind_Group), align_of(gpu.Bind_Group))
    sizes("Bind_Group_Layout", size_of(gpu.Bind_Group_Layout), align_of(gpu.Bind_Group_Layout))
    sizes("Command_Buffer", size_of(gpu.Command_Buffer), align_of(gpu.Command_Buffer))
    sizes("Query_Set", size_of(gpu.Query_Set), align_of(gpu.Query_Set))
    sizes("Shader_Module", size_of(gpu.Shader_Module), align_of(gpu.Shader_Module))

    fmt.printf("\n=== Limits ===\n")
    sizes("Limits", size_of(gpu.Limits), align_of(gpu.Limits))
    F("max_uniform_buffer_binding_size", offset_of(gpu.Limits, max_uniform_buffer_binding_size))
    F("max_storage_buffer_binding_size", offset_of(gpu.Limits, max_storage_buffer_binding_size))
    F(
        "min_uniform_buffer_offset_alignment",
        offset_of(gpu.Limits, min_uniform_buffer_offset_alignment),
    )
    F("max_vertex_buffers", offset_of(gpu.Limits, max_vertex_buffers))
    F("max_buffer_size", offset_of(gpu.Limits, max_buffer_size))
    F("max_vertex_attributes", offset_of(gpu.Limits, max_vertex_attributes))
    F("max_immediate_size", offset_of(gpu.Limits, max_immediate_size))
    F("max_multiview_view_count", offset_of(gpu.Limits, max_multiview_view_count))

    fmt.printf("\n=== Callback infos / Queue_Descriptor ===\n")
    sizes(
        "Device_Lost_Callback_Info",
        size_of(gpu.Device_Lost_Callback_Info),
        align_of(gpu.Device_Lost_Callback_Info),
    )
    sizes(
        "Uncaptured_Error_Callback_Info",
        size_of(gpu.Uncaptured_Error_Callback_Info),
        align_of(gpu.Uncaptured_Error_Callback_Info),
    )
    sizes("Queue_Descriptor", size_of(gpu.Queue_Descriptor), align_of(gpu.Queue_Descriptor))

    fmt.printf("\n=== Device_Descriptor ===\n")
    sizes("Device_Descriptor", size_of(gpu.Device_Descriptor), align_of(gpu.Device_Descriptor))
    F("label", offset_of(gpu.Device_Descriptor, label))
    F("required_features", offset_of(gpu.Device_Descriptor, required_features))
    F("required_limits", offset_of(gpu.Device_Descriptor, required_limits))
    F("default_queue", offset_of(gpu.Device_Descriptor, default_queue))
    F("lost_callback_info", offset_of(gpu.Device_Descriptor, lost_callback_info))
    F(
        "uncaptured_error_callback_info",
        offset_of(gpu.Device_Descriptor, uncaptured_error_callback_info),
    )

    fmt.printf("\n=== Surface ===\n")
    sizes(
        "Surface_Format_Capabilities",
        size_of(gpu.Surface_Format_Capabilities),
        align_of(gpu.Surface_Format_Capabilities),
    )
    F("format", offset_of(gpu.Surface_Format_Capabilities, format))
    F("color_spaces", offset_of(gpu.Surface_Format_Capabilities, color_spaces))

    sizes(
        "Surface_Capabilities",
        size_of(gpu.Surface_Capabilities),
        align_of(gpu.Surface_Capabilities),
    )
    F("formats", offset_of(gpu.Surface_Capabilities, formats))
    F("format_capabilities", offset_of(gpu.Surface_Capabilities, format_capabilities))
    F("present_modes", offset_of(gpu.Surface_Capabilities, present_modes))
    F("alpha_modes", offset_of(gpu.Surface_Capabilities, alpha_modes))
    F("usages", offset_of(gpu.Surface_Capabilities, usages))

    sizes(
        "Surface_Configuration",
        size_of(gpu.Surface_Configuration),
        align_of(gpu.Surface_Configuration),
    )
    F("device", offset_of(gpu.Surface_Configuration, device))
    F("usage", offset_of(gpu.Surface_Configuration, usage))
    F("format", offset_of(gpu.Surface_Configuration, format))
    F("color_space", offset_of(gpu.Surface_Configuration, color_space))
    F("width", offset_of(gpu.Surface_Configuration, width))
    F("height", offset_of(gpu.Surface_Configuration, height))
    F("present_mode", offset_of(gpu.Surface_Configuration, present_mode))
    F(
        "desired_maximum_frame_latency",
        offset_of(gpu.Surface_Configuration, desired_maximum_frame_latency),
    )
    F("alpha_mode", offset_of(gpu.Surface_Configuration, alpha_mode))
    F("view_formats", offset_of(gpu.Surface_Configuration, view_formats))

    sizes("Surface_Texture", size_of(gpu.Surface_Texture), align_of(gpu.Surface_Texture))
    F("surface", offset_of(gpu.Surface_Texture, surface))
    F("texture", offset_of(gpu.Surface_Texture, texture))
    F("status", offset_of(gpu.Surface_Texture, status))

    fmt.printf("\n=== Render pass ===\n")
    sizes(
        "Render_Pass_Descriptor",
        size_of(gpu.Render_Pass_Descriptor),
        align_of(gpu.Render_Pass_Descriptor),
    )
    F("label", offset_of(gpu.Render_Pass_Descriptor, label))
    F("color_attachments", offset_of(gpu.Render_Pass_Descriptor, color_attachments))
    F("depth_stencil_attachment", offset_of(gpu.Render_Pass_Descriptor, depth_stencil_attachment))
    F("timestamp_writes", offset_of(gpu.Render_Pass_Descriptor, timestamp_writes))
    F("occlusion_query_set", offset_of(gpu.Render_Pass_Descriptor, occlusion_query_set))
    F("multiview_mask", offset_of(gpu.Render_Pass_Descriptor, multiview_mask))

    sizes(
        "Render_Pass_Color_Attachment",
        size_of(gpu.Render_Pass_Color_Attachment),
        align_of(gpu.Render_Pass_Color_Attachment),
    )
    F("view", offset_of(gpu.Render_Pass_Color_Attachment, view))
    F("depth_slice", offset_of(gpu.Render_Pass_Color_Attachment, depth_slice))
    F("resolve_target", offset_of(gpu.Render_Pass_Color_Attachment, resolve_target))
    F("ops", offset_of(gpu.Render_Pass_Color_Attachment, ops))

    sizes(
        "Operations(gpu.Color)",
        size_of(gpu.Operations(gpu.Color)),
        align_of(gpu.Operations(gpu.Color)),
    )
    F("load", offset_of(gpu.Operations(gpu.Color), load))
    F("store", offset_of(gpu.Operations(gpu.Color), store))
    F("clear_value", offset_of(gpu.Operations(gpu.Color), clear_value))
    sizes("Operations(f32)", size_of(gpu.Operations(f32)), align_of(gpu.Operations(f32)))
    sizes("Operations(u32)", size_of(gpu.Operations(u32)), align_of(gpu.Operations(u32)))

    sizes(
        "Render_Pass_Depth_Stencil_Attachment",
        size_of(gpu.Render_Pass_Depth_Stencil_Attachment),
        align_of(gpu.Render_Pass_Depth_Stencil_Attachment),
    )
    F("view", offset_of(gpu.Render_Pass_Depth_Stencil_Attachment, view))
    F("depth_ops", offset_of(gpu.Render_Pass_Depth_Stencil_Attachment, depth_ops))
    F("stencil_ops", offset_of(gpu.Render_Pass_Depth_Stencil_Attachment, stencil_ops))
    F("depth_read_only", offset_of(gpu.Render_Pass_Depth_Stencil_Attachment, depth_read_only))
    F("stencil_read_only", offset_of(gpu.Render_Pass_Depth_Stencil_Attachment, stencil_read_only))

    sizes(
        "Render_Pass_Timestamp_Writes",
        size_of(gpu.Render_Pass_Timestamp_Writes),
        align_of(gpu.Render_Pass_Timestamp_Writes),
    )
    F("query_set", offset_of(gpu.Render_Pass_Timestamp_Writes, query_set))
    F(
        "beginning_of_pass_write_index",
        offset_of(gpu.Render_Pass_Timestamp_Writes, beginning_of_pass_write_index),
    )
    F(
        "end_of_pass_write_index",
        offset_of(gpu.Render_Pass_Timestamp_Writes, end_of_pass_write_index),
    )

    fmt.printf("\n=== Vertex state ===\n")
    sizes("Vertex_State", size_of(gpu.Vertex_State), align_of(gpu.Vertex_State))
    F("module", offset_of(gpu.Vertex_State, module))
    F("entry_point", offset_of(gpu.Vertex_State, entry_point))
    F("compilation_options", offset_of(gpu.Vertex_State, compilation_options))
    F("buffers", offset_of(gpu.Vertex_State, buffers))
    sizes(
        "Pipeline_Compilation_Options",
        size_of(gpu.Pipeline_Compilation_Options),
        align_of(gpu.Pipeline_Compilation_Options),
    )
    F("constants", offset_of(gpu.Pipeline_Compilation_Options, constants))
    F(
        "zero_initialize_workgroup_memory",
        offset_of(gpu.Pipeline_Compilation_Options, zero_initialize_workgroup_memory),
    )
    sizes("Constant_Entry", size_of(gpu.Constant_Entry), align_of(gpu.Constant_Entry))
    sizes(
        "Vertex_Buffer_Layout",
        size_of(gpu.Vertex_Buffer_Layout),
        align_of(gpu.Vertex_Buffer_Layout),
    )
    F("array_stride", offset_of(gpu.Vertex_Buffer_Layout, array_stride))
    F("step_mode", offset_of(gpu.Vertex_Buffer_Layout, step_mode))
    F("attributes", offset_of(gpu.Vertex_Buffer_Layout, attributes))
    sizes("Vertex_Attribute", size_of(gpu.Vertex_Attribute), align_of(gpu.Vertex_Attribute))
    F("format", offset_of(gpu.Vertex_Attribute, format))
    F("offset", offset_of(gpu.Vertex_Attribute, offset))
    F("shader_location", offset_of(gpu.Vertex_Attribute, shader_location))

    fmt.printf("\n=== Texture ===\n")
    sizes("Extent_3D", size_of(gpu.Extent_3D), align_of(gpu.Extent_3D))
    sizes("Origin_3D", size_of(gpu.Origin_3D), align_of(gpu.Origin_3D))
    sizes("Texture_Descriptor", size_of(gpu.Texture_Descriptor), align_of(gpu.Texture_Descriptor))
    F("label", offset_of(gpu.Texture_Descriptor, label))
    F("size", offset_of(gpu.Texture_Descriptor, size))
    F("mip_level_count", offset_of(gpu.Texture_Descriptor, mip_level_count))
    F("sample_count", offset_of(gpu.Texture_Descriptor, sample_count))
    F("dimension", offset_of(gpu.Texture_Descriptor, dimension))
    F("format", offset_of(gpu.Texture_Descriptor, format))
    F("usage", offset_of(gpu.Texture_Descriptor, usage))
    F("view_formats", offset_of(gpu.Texture_Descriptor, view_formats))

    sizes(
        "Texel_Copy_Buffer_Layout",
        size_of(gpu.Texel_Copy_Buffer_Layout),
        align_of(gpu.Texel_Copy_Buffer_Layout),
    )
    F("offset", offset_of(gpu.Texel_Copy_Buffer_Layout, offset))
    F("bytes_per_row", offset_of(gpu.Texel_Copy_Buffer_Layout, bytes_per_row))
    F("rows_per_image", offset_of(gpu.Texel_Copy_Buffer_Layout, rows_per_image))
    sizes(
        "Texel_Copy_Buffer_Info",
        size_of(gpu.Texel_Copy_Buffer_Info),
        align_of(gpu.Texel_Copy_Buffer_Info),
    )
    F("buffer", offset_of(gpu.Texel_Copy_Buffer_Info, buffer))
    F("layout", offset_of(gpu.Texel_Copy_Buffer_Info, layout))
    sizes(
        "Texel_Copy_Texture_Info",
        size_of(gpu.Texel_Copy_Texture_Info),
        align_of(gpu.Texel_Copy_Texture_Info),
    )
    F("texture", offset_of(gpu.Texel_Copy_Texture_Info, texture))
    F("mip_level", offset_of(gpu.Texel_Copy_Texture_Info, mip_level))
    F("origin", offset_of(gpu.Texel_Copy_Texture_Info, origin))
    F("aspect", offset_of(gpu.Texel_Copy_Texture_Info, aspect))

    fmt.printf("\n=== Sampler ===\n")
    sizes("Sampler_Descriptor", size_of(gpu.Sampler_Descriptor), align_of(gpu.Sampler_Descriptor))
    F("label", offset_of(gpu.Sampler_Descriptor, label))
    F("address_mode_u", offset_of(gpu.Sampler_Descriptor, address_mode_u))
    F("mag_filter", offset_of(gpu.Sampler_Descriptor, mag_filter))
    F("mipmap_filter", offset_of(gpu.Sampler_Descriptor, mipmap_filter))
    F("lod_min_clamp", offset_of(gpu.Sampler_Descriptor, lod_min_clamp))
    F("lod_max_clamp", offset_of(gpu.Sampler_Descriptor, lod_max_clamp))
    F("compare", offset_of(gpu.Sampler_Descriptor, compare))
    F("anisotropy_clamp", offset_of(gpu.Sampler_Descriptor, anisotropy_clamp))
    F("border_color", offset_of(gpu.Sampler_Descriptor, border_color))

    fmt.printf("\n=== Bind groups ===\n")
    sizes(
        "Buffer_Binding_Layout",
        size_of(gpu.Buffer_Binding_Layout),
        align_of(gpu.Buffer_Binding_Layout),
    )
    F("type", offset_of(gpu.Buffer_Binding_Layout, type))
    F("has_dynamic_offset", offset_of(gpu.Buffer_Binding_Layout, has_dynamic_offset))
    F("min_binding_size", offset_of(gpu.Buffer_Binding_Layout, min_binding_size))
    sizes(
        "Sampler_Binding_Layout",
        size_of(gpu.Sampler_Binding_Layout),
        align_of(gpu.Sampler_Binding_Layout),
    )
    sizes(
        "Texture_Binding_Layout",
        size_of(gpu.Texture_Binding_Layout),
        align_of(gpu.Texture_Binding_Layout),
    )
    F("sample_type", offset_of(gpu.Texture_Binding_Layout, sample_type))
    F("view_dimension", offset_of(gpu.Texture_Binding_Layout, view_dimension))
    F("multisampled", offset_of(gpu.Texture_Binding_Layout, multisampled))
    sizes(
        "Storage_Texture_Binding_Layout",
        size_of(gpu.Storage_Texture_Binding_Layout),
        align_of(gpu.Storage_Texture_Binding_Layout),
    )
    F("access", offset_of(gpu.Storage_Texture_Binding_Layout, access))
    F("format", offset_of(gpu.Storage_Texture_Binding_Layout, format))
    F("view_dimension", offset_of(gpu.Storage_Texture_Binding_Layout, view_dimension))
    sizes(
        "External_Texture_Binding_Layout",
        size_of(gpu.External_Texture_Binding_Layout),
        align_of(gpu.External_Texture_Binding_Layout),
    )
    sizes("Binding_Type (union)", size_of(gpu.Binding_Type), align_of(gpu.Binding_Type))
    sizes(
        "Bind_Group_Layout_Entry",
        size_of(gpu.Bind_Group_Layout_Entry),
        align_of(gpu.Bind_Group_Layout_Entry),
    )
    F("binding", offset_of(gpu.Bind_Group_Layout_Entry, binding))
    F("visibility", offset_of(gpu.Bind_Group_Layout_Entry, visibility))
    F("type", offset_of(gpu.Bind_Group_Layout_Entry, type))
    F("count", offset_of(gpu.Bind_Group_Layout_Entry, count))
    sizes(
        "Bind_Group_Layout_Descriptor",
        size_of(gpu.Bind_Group_Layout_Descriptor),
        align_of(gpu.Bind_Group_Layout_Descriptor),
    )
    F("label", offset_of(gpu.Bind_Group_Layout_Descriptor, label))
    F("entries", offset_of(gpu.Bind_Group_Layout_Descriptor, entries))

    sizes("Buffer_Binding", size_of(gpu.Buffer_Binding), align_of(gpu.Buffer_Binding))
    F("buffer", offset_of(gpu.Buffer_Binding, buffer))
    F("offset", offset_of(gpu.Buffer_Binding, offset))
    F("size", offset_of(gpu.Buffer_Binding, size))
    sizes(
        "Binding_Resource (union)",
        size_of(gpu.Binding_Resource),
        align_of(gpu.Binding_Resource),
    )
    sizes("Bind_Group_Entry", size_of(gpu.Bind_Group_Entry), align_of(gpu.Bind_Group_Entry))
    F("binding", offset_of(gpu.Bind_Group_Entry, binding))
    F("resource", offset_of(gpu.Bind_Group_Entry, resource))
    sizes(
        "Bind_Group_Descriptor",
        size_of(gpu.Bind_Group_Descriptor),
        align_of(gpu.Bind_Group_Descriptor),
    )
    F("label", offset_of(gpu.Bind_Group_Descriptor, label))
    F("layout", offset_of(gpu.Bind_Group_Descriptor, layout))
    F("entries", offset_of(gpu.Bind_Group_Descriptor, entries))

    sizes(
        "Pipeline_Layout_Descriptor",
        size_of(gpu.Pipeline_Layout_Descriptor),
        align_of(gpu.Pipeline_Layout_Descriptor),
    )
    F("label", offset_of(gpu.Pipeline_Layout_Descriptor, label))
    F("bind_group_layouts", offset_of(gpu.Pipeline_Layout_Descriptor, bind_group_layouts))
    F("immediate_size", offset_of(gpu.Pipeline_Layout_Descriptor, immediate_size))

    fmt.printf("\n=== Features ===\n")
    sizes("Features", size_of(gpu.Features), align_of(gpu.Features))
    fmt.printf("    FEATURE_COUNT = %v\n", gpu.FEATURE_COUNT)

    fmt.printf("\n=== Render pipeline ===\n")
    sizes("Blend_Component", size_of(gpu.Blend_Component), align_of(gpu.Blend_Component))
    sizes("Blend_State", size_of(gpu.Blend_State), align_of(gpu.Blend_State))
    F("color", offset_of(gpu.Blend_State, color))
    F("alpha", offset_of(gpu.Blend_State, alpha))

    sizes("Primitive_State", size_of(gpu.Primitive_State), align_of(gpu.Primitive_State))
    F("topology", offset_of(gpu.Primitive_State, topology))
    F("strip_index_format", offset_of(gpu.Primitive_State, strip_index_format))
    F("front_face", offset_of(gpu.Primitive_State, front_face))
    F("cull_mode", offset_of(gpu.Primitive_State, cull_mode))
    F("unclipped_depth", offset_of(gpu.Primitive_State, unclipped_depth))
    F("polygon_mode", offset_of(gpu.Primitive_State, polygon_mode))
    F("conservative", offset_of(gpu.Primitive_State, conservative))

    sizes("Multisample_State", size_of(gpu.Multisample_State), align_of(gpu.Multisample_State))
    F("count", offset_of(gpu.Multisample_State, count))
    F("mask", offset_of(gpu.Multisample_State, mask))
    F("alpha_to_coverage_enabled", offset_of(gpu.Multisample_State, alpha_to_coverage_enabled))

    sizes("Stencil_Face_State", size_of(gpu.Stencil_Face_State), align_of(gpu.Stencil_Face_State))
    sizes("Stencil_State", size_of(gpu.Stencil_State), align_of(gpu.Stencil_State))
    F("front", offset_of(gpu.Stencil_State, front))
    F("back", offset_of(gpu.Stencil_State, back))
    F("read_mask", offset_of(gpu.Stencil_State, read_mask))
    F("write_mask", offset_of(gpu.Stencil_State, write_mask))
    sizes("Depth_Bias_State", size_of(gpu.Depth_Bias_State), align_of(gpu.Depth_Bias_State))

    sizes(
        "Depth_Stencil_State",
        size_of(gpu.Depth_Stencil_State),
        align_of(gpu.Depth_Stencil_State),
    )
    F("format", offset_of(gpu.Depth_Stencil_State, format))
    F("depth_write_enabled", offset_of(gpu.Depth_Stencil_State, depth_write_enabled))
    F("depth_compare", offset_of(gpu.Depth_Stencil_State, depth_compare))
    F("stencil", offset_of(gpu.Depth_Stencil_State, stencil))
    F("bias", offset_of(gpu.Depth_Stencil_State, bias))

    sizes("Color_Writes", size_of(gpu.Color_Writes), align_of(gpu.Color_Writes))
    sizes("Color_Target_State", size_of(gpu.Color_Target_State), align_of(gpu.Color_Target_State))
    F("format", offset_of(gpu.Color_Target_State, format))
    F("blend", offset_of(gpu.Color_Target_State, blend))
    F("write_mask", offset_of(gpu.Color_Target_State, write_mask))

    sizes("Fragment_State", size_of(gpu.Fragment_State), align_of(gpu.Fragment_State))
    F("module", offset_of(gpu.Fragment_State, module))
    F("entry_point", offset_of(gpu.Fragment_State, entry_point))
    F("compilation_options", offset_of(gpu.Fragment_State, compilation_options))
    F("targets", offset_of(gpu.Fragment_State, targets))

    sizes("Pipeline_Layout", size_of(gpu.Pipeline_Layout), align_of(gpu.Pipeline_Layout))
    sizes("Pipeline_Cache", size_of(gpu.Pipeline_Cache), align_of(gpu.Pipeline_Cache))
    sizes(
        "Render_Pipeline_Descriptor",
        size_of(gpu.Render_Pipeline_Descriptor),
        align_of(gpu.Render_Pipeline_Descriptor),
    )
    F("label", offset_of(gpu.Render_Pipeline_Descriptor, label))
    F("layout", offset_of(gpu.Render_Pipeline_Descriptor, layout))
    F("vertex", offset_of(gpu.Render_Pipeline_Descriptor, vertex))
    F("primitive", offset_of(gpu.Render_Pipeline_Descriptor, primitive))
    F("depth_stencil", offset_of(gpu.Render_Pipeline_Descriptor, depth_stencil))
    F("multisample", offset_of(gpu.Render_Pipeline_Descriptor, multisample))
    F("fragment", offset_of(gpu.Render_Pipeline_Descriptor, fragment))
    F("multiview_mask", offset_of(gpu.Render_Pipeline_Descriptor, multiview_mask))
    F("cache", offset_of(gpu.Render_Pipeline_Descriptor, cache))

    fmt.printf("\n=== Device_Descriptor tail ===\n")
    F("trace_path", offset_of(gpu.Device_Descriptor, trace_path))
    F("memory_hints", offset_of(gpu.Device_Descriptor, memory_hints))
    F(
        "suballocated_device_memory_block_size",
        offset_of(gpu.Device_Descriptor, suballocated_device_memory_block_size),
    )
    sizes("Range(u64)", size_of(gpu.Range(u64)), align_of(gpu.Range(u64)))

    fmt.printf("\n=== done ===\n")
}
