#+build !js
package gpu

// Core
import "core:strings"
import hm "core:container/handle_map"

// Vendor
import vk "vendor:vulkan"

VK_Render_Pipeline_Handle :: distinct hm.Handle64

VK_Render_Pipeline_Impl :: struct {
    device:          Device,
    layout:          Pipeline_Layout,
    vk_pipeline:     vk.Pipeline,
    handle:          VK_Render_Pipeline_Handle,
    ref:             Ref_Count_Type,
    is_empty_layout: bool,
}

vk_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    impl := vk_device_get_impl(device, loc)
    adapter_impl := vk_adapter_get_impl(impl.adapter, loc)

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // Shader stages
    vk_shader_stages: [dynamic;5]vk.PipelineShaderStageCreateInfo

    assert(descriptor.vertex.module != {}, "Vertex shader module is required", loc)
    assert(descriptor.vertex.entry_point != "", "Invalid vertex shader entry point", loc)

    vertex_module_impl := vk_shader_module_get_impl(descriptor.vertex.module, loc)

    append(&vk_shader_stages, vk.PipelineShaderStageCreateInfo {
        sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
        stage  = {.VERTEX},
        module = vertex_module_impl.vk_shader_module,
        pName  = strings.clone_to_cstring(descriptor.vertex.entry_point, ta),
    })

    // Vertex input state
    vertex_bindings := make([dynamic]vk.VertexInputBindingDescription,
        0, len(descriptor.vertex.buffers), ta)
    vertex_attributes := make([dynamic]vk.VertexInputAttributeDescription, ta)

    for &buffer, binding in descriptor.vertex.buffers {
        append(&vertex_bindings, vk.VertexInputBindingDescription {
            binding   = u32(binding),
            stride    = u32(buffer.array_stride),
            inputRate = vk_conv_to_vertex_step_mode(buffer.step_mode, loc),
        })

        reserve(&vertex_attributes, len(vertex_attributes) + len(buffer.attributes))
        for &attr in buffer.attributes {
            append(&vertex_attributes, vk.VertexInputAttributeDescription {
                location = attr.shader_location,
                binding  = u32(binding),
                format   = vk_conv_to_vertex_format(attr.format),
                offset   = u32(attr.offset),
            })
        }
    }

    vk_vertex_input_state := vk.PipelineVertexInputStateCreateInfo {
        sType                           = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
        vertexBindingDescriptionCount   = u32(len(vertex_bindings)),
        pVertexBindingDescriptions      = raw_data(vertex_bindings),
        vertexAttributeDescriptionCount = u32(len(vertex_attributes)),
        pVertexAttributeDescriptions    = raw_data(vertex_attributes),
    }

    primitive := descriptor.primitive
    vk_input_assembly := vk.PipelineInputAssemblyStateCreateInfo {
        sType                  = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology               = vk_conv_to_primitive_topology(primitive.topology, loc),
        primitiveRestartEnable = primitive.strip_index_format != .Undefined,
    }

    vk_viewport_state := vk.PipelineViewportStateCreateInfo {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports    = nil,
        scissorCount  = 1,
        pScissors     = nil,
    }

    vk_rasterization_state := vk.PipelineRasterizationStateCreateInfo {
        sType                   = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        flags                   = {},
        depthClampEnable        = b32(primitive.unclipped_depth),
        rasterizerDiscardEnable = false,
        cullMode                = vk_conv_to_cull_mode_flags(primitive.cull_mode, loc),
        frontFace               = vk_conv_to_front_face(primitive.front_face, loc),
        lineWidth               = 1.0,
    }

    multisample := descriptor.multisample
    vk_sample_mask := vk.SampleMask(multisample.mask)
    vk_multisample_state := vk.PipelineMultisampleStateCreateInfo {
        sType                 = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        rasterizationSamples  = vk_conv_to_sample_count_flags(multisample.count, loc),
        sampleShadingEnable   = false,
        minSampleShading      = 0.0,
        pSampleMask           = multisample.mask != max(u32) ? &vk_sample_mask : nil,
        alphaToCoverageEnable = b32(multisample.alpha_to_coverage_enabled),
        alphaToOneEnable      = false,
    }

    // Depth stencil state
    vk_depth_stencil_state: vk.PipelineDepthStencilStateCreateInfo
    has_depth_stencil: bool

    // For the render-pass-key: format/layout of the depth attachment, if any
    rp_key: VK_Render_Pass_Key
    rp_key.sample_count = multisample.count

    if descriptor.depth_stencil != nil {
        ds := descriptor.depth_stencil
        has_depth_stencil = true

        depth_read_only := !ds.depth_write_enabled
        stencil_read_only := stencil_state_is_read_only(ds.stencil, primitive.cull_mode)

        set_stencil_state_ops :: proc(
            self: ^vk.PipelineDepthStencilStateCreateInfo,
            face_mask: vk.StencilFaceFlags,
            state: Stencil_Face_State,
            loc := #caller_location,
        ) {
            fail_op := vk_conv_to_stencil_op(state.fail_op, loc)
            pass_op := vk_conv_to_stencil_op(state.pass_op, loc)
            depth_fail_op := vk_conv_to_stencil_op(state.depth_fail_op, loc)
            compare_op := vk_conv_to_compare_op(state.compare, loc)

            stencil_test_enable :=
                self.stencilTestEnable ||
                fail_op != .KEEP ||
                pass_op != .KEEP ||
                depth_fail_op != .KEEP ||
                compare_op != .ALWAYS
            self.stencilTestEnable = b32(stencil_test_enable)

            if .FRONT in face_mask {
                self.front.failOp = fail_op
                self.front.passOp = pass_op
                self.front.depthFailOp = depth_fail_op
                self.front.compareOp = compare_op
            }
            if .BACK in face_mask {
                self.back.failOp = fail_op
                self.back.passOp = pass_op
                self.back.depthFailOp = depth_fail_op
                self.back.compareOp = compare_op
            }
        }

        vk_depth_stencil_state = {
            sType                 = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
            depthTestEnable       = b32(ds.depth_compare != .Always || ds.depth_write_enabled),
            depthWriteEnable      = b32(ds.depth_write_enabled),
            depthCompareOp        = vk_conv_to_compare_op(ds.depth_compare, loc),
            depthBoundsTestEnable = false,
            stencilTestEnable     = false,
            minDepthBounds        = 0.0,
            maxDepthBounds        = 1.0,
        }

        set_stencil_state_ops(&vk_depth_stencil_state, {.FRONT}, ds.stencil.front, loc)
        set_stencil_state_ops(&vk_depth_stencil_state, {.BACK}, ds.stencil.back, loc)

        vk_depth_stencil_state.front.compareMask = ds.stencil.read_mask
        vk_depth_stencil_state.front.writeMask = ds.stencil.write_mask
        vk_depth_stencil_state.back.compareMask = ds.stencil.read_mask
        vk_depth_stencil_state.back.writeMask = ds.stencil.write_mask
        vk_depth_stencil_state.front.reference = 0
        vk_depth_stencil_state.back.reference = 0

        if ds.bias.constant != 0 || ds.bias.clamp != 0 || ds.bias.slope_scale != 0 {
            vk_rasterization_state.depthBiasEnable = true
            vk_rasterization_state.depthBiasConstantFactor = f32(ds.bias.constant)
            vk_rasterization_state.depthBiasClamp = ds.bias.clamp
            vk_rasterization_state.depthBiasSlopeFactor = ds.bias.slope_scale
        }

        vk_ds_format := vk_conv_to_format(adapter_impl.caps, ds.format)

        ds_layout: vk.ImageLayout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL
        if depth_read_only && stencil_read_only {
            ds_layout = .DEPTH_STENCIL_READ_ONLY_OPTIMAL
        } else if depth_read_only {
            ds_layout = .DEPTH_READ_ONLY_STENCIL_ATTACHMENT_OPTIMAL
        } else if stencil_read_only {
            ds_layout = .DEPTH_ATTACHMENT_STENCIL_READ_ONLY_OPTIMAL
        }

        rp_key.depth_stencil = VK_Depth_Stencil_Attachment_Key{
            format           = vk_ds_format,
            layout           = ds_layout,
            // Compatibility placeholders: pipeline/render-pass compatibility
            // ignores initial and final layouts.
            final_layout     = ds_layout,
            load_op          = .Load,
            store_op         = .Store,
            stencil_load_op  = .Load,
            stencil_store_op = .Store,
        }
        rp_key.depth_read_only   = depth_read_only
        rp_key.stencil_read_only = stencil_read_only
    }

    // Optional fragment stage + color targets
    color_blend_attachment_states:
        [dynamic;MAX_COLOR_ATTACHMENTS]vk.PipelineColorBlendAttachmentState
    color_count := 0

    if descriptor.fragment != nil {
        frag := descriptor.fragment

        assert(frag.module != {}, "Fragment shader module is required", loc)
        assert(frag.entry_point != "", "Invalid fragment shader entry point", loc)

        fragment_module_impl := vk_shader_module_get_impl(frag.module, loc)

        append(&vk_shader_stages, vk.PipelineShaderStageCreateInfo {
            sType  = .PIPELINE_SHADER_STAGE_CREATE_INFO,
            stage  = {.FRAGMENT},
            module = fragment_module_impl.vk_shader_module,
            pName  = strings.clone_to_cstring(frag.entry_point, ta),
        })

        for &target in frag.targets {
            attachment := vk.PipelineColorBlendAttachmentState {
                blendEnable    = false,
                colorWriteMask = {.R, .G, .B, .A},
            }

            if target.blend != nil {
                color := target.blend.color
                alpha := target.blend.alpha
                attachment.blendEnable = true
                attachment.srcColorBlendFactor = vk_conv_to_blend_factor(color.src_factor, loc)
                attachment.dstColorBlendFactor = vk_conv_to_blend_factor(color.dst_factor, loc)
                attachment.colorBlendOp        = vk_conv_to_blend_op(color.operation, loc)
                attachment.srcAlphaBlendFactor = vk_conv_to_blend_factor(alpha.src_factor, loc)
                attachment.dstAlphaBlendFactor = vk_conv_to_blend_factor(alpha.dst_factor, loc)
                attachment.alphaBlendOp        = vk_conv_to_blend_op(alpha.operation, loc)
            }

            attachment.colorWriteMask = vk_conv_to_color_component_flags(target.write_mask, loc)

            attachment_format := vk_conv_to_format(adapter_impl.caps, target.format)

            append(&color_blend_attachment_states, attachment)

            rp_key.colors[color_count] = VK_Color_Attachment_Key{
                format   = attachment_format,
                layout   = .COLOR_ATTACHMENT_OPTIMAL,
                // Compatibility placeholder, as for load/store ops above.
                final_layout = .COLOR_ATTACHMENT_OPTIMAL,
                load_op  = .Load,  // compatibility placeholder
                store_op = .Store, // compatibility placeholder
            }
            color_count += 1
        }
    }

    vk_color_blend_state := vk.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable   = false,
        logicOp         = .COPY,
        attachmentCount = u32(len(color_blend_attachment_states)),
        pAttachments    = raw_data(color_blend_attachment_states[:]),
    }

    // Get-or-create the render pass this pipeline is compatible with.
    vk_render_pass := vk_render_pass_cache_get_or_create(impl, rp_key, loc)

    // Tag all state as dynamic but stencil masks and depth bias.
    vk_dynamic_states := []vk.DynamicState {
        .VIEWPORT,     .SCISSOR,
        .LINE_WIDTH,   .BLEND_CONSTANTS,
        .DEPTH_BOUNDS, .STENCIL_REFERENCE,
    }

    vk_dynamic_state := vk.PipelineDynamicStateCreateInfo {
        sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = u32(len(vk_dynamic_states)),
        pDynamicStates    = raw_data(vk_dynamic_states),
    }

    vk_pipeline_layout: vk.PipelineLayout
    is_empty_layout: bool

    if descriptor.layout != {} {
        vk_pipeline_impl := vk_pipeline_layout_get_impl(descriptor.layout, loc)
        vk_pipeline_layout = vk_pipeline_impl.raw
        vk_pipeline_layout_add_ref(descriptor.layout)
    } else {
        is_empty_layout = true
        vk_pipeline_layout = impl.vk_empty_pipeline_layout
    }

    create_info := vk.GraphicsPipelineCreateInfo {
        sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
        flags               = {},
        stageCount          = u32(len(vk_shader_stages)),
        pStages             = raw_data(vk_shader_stages[:]),
        pVertexInputState   = &vk_vertex_input_state,
        pInputAssemblyState = &vk_input_assembly,
        pTessellationState  = {},
        pViewportState      = &vk_viewport_state,
        pRasterizationState = &vk_rasterization_state,
        pMultisampleState   = &vk_multisample_state,
        pDepthStencilState  = &vk_depth_stencil_state if has_depth_stencil else nil,
        pColorBlendState    = &vk_color_blend_state,
        pDynamicState       = &vk_dynamic_state,
        layout              = vk_pipeline_layout,
        renderPass          = vk_render_pass,
        subpass             = 0,
        basePipelineHandle  = {},
        basePipelineIndex   = {},
    }

    vk_pipeline: vk.Pipeline
    vk_check(vk.CreateGraphicsPipelines(
        impl.vk_device, {}, 1, &create_info, nil, &vk_pipeline), loc = loc)

    _, render_pipeline_handle := add_impl(&impl.render_pipelines, VK_Render_Pipeline_Impl {
        device          = device,
        layout          = descriptor.layout,
        vk_pipeline     = vk_pipeline,
        is_empty_layout = is_empty_layout,
    })

    return new_handle(Render_Pipeline, device, render_pipeline_handle)
}

vk_create_render_pipeline_async :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    callback_info: Create_Render_Pipeline_Async_Callback_Info,
    loc := #caller_location,
) -> Future {
    unimplemented(loc = loc)
}

@(require_results)
vk_render_pipeline_get_impl :: #force_inline proc "contextless" (
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> ^VK_Render_Pipeline_Impl {
    device_impl := vk_device_get_impl(render_pipeline.device, loc)
    return get_handle_impl(&device_impl.render_pipelines, render_pipeline.handle, loc)
}

vk_render_pipeline_get_bind_group_layout :: proc(
    render_pipeline: Render_Pipeline,
    group_index: u32,
    loc := #caller_location,
) -> Bind_Group_Layout {
    unimplemented(loc = loc)
}

vk_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    unimplemented(loc = loc)
}

vk_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := vk_render_pipeline_get_impl(render_pipeline, loc)
    add_ref(impl, loc)
}

vk_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := vk_render_pipeline_get_impl(render_pipeline, loc)
    if release_ref(impl) {
        device_impl := vk_device_get_impl(impl.device, loc)
        if !impl.is_empty_layout {
            vk_pipeline_layout_release(impl.layout)
        }
        vk_deferred_add_resource(&device_impl.deferred, &device_impl.submitter, impl.vk_pipeline)
        remove_handle_impl(&device_impl.render_pipelines, impl.handle)
    }
}
