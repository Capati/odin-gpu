#+build !js
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:mem"
import sa "core:container/small_array"

// Vendor
import vk "vendor:vulkan"

vk_check :: #force_inline proc(
    res: vk.Result,
    message := #caller_expression(res),
    loc := #caller_location,
) {
    assert(res == .SUCCESS, message, loc)
}

vk_default_debug_callback :: proc "system" (
    messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
    messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
    pUserData: rawptr,
) -> b32 {
    // Ignore verbose/info
    if messageSeverity < { .INFO } {
        return false
    }

    impl := cast(^Vulkan_Instance_Impl)pUserData
    context = impl.ctx

    is_error := .ERROR in messageSeverity
    is_warning := .WARNING in messageSeverity

    if !is_error && !is_warning {
        return false
    }

    if is_error {
        log.errorf("[%v]: %s", messageTypes, pCallbackData.pMessage)
        runtime.trap() // Immediate crash on validation error
    }

    log.warnf("[%v]: %s", messageTypes, pCallbackData.pMessage)
    return false
}

vk_setup_pnext_chain :: proc(
    structure: ^$T,
    structs: []^vk.BaseOutStructure,
    loc := #caller_location,
) {
    structure.pNext = nil
    if len(structs) == 0 {
        return
    }

    for i := 0; i < len(structs) - 1; i += 1 {
        out_structure: vk.BaseOutStructure
        mem.copy(&out_structure, structs[i], size_of(vk.BaseOutStructure))

        when ODIN_DEBUG {
            assert(out_structure.sType != .APPLICATION_INFO, loc = loc)
        }

        out_structure.pNext = cast(^vk.BaseOutStructure)structs[i + 1]
        mem.copy(structs[i], &out_structure, size_of(vk.BaseOutStructure))
    }

    out_structure: vk.BaseOutStructure
    mem.copy(&out_structure, structs[len(structs) - 1], size_of(vk.BaseOutStructure))
    out_structure.pNext = nil

    when ODIN_DEBUG {
        assert(out_structure.sType != .APPLICATION_INFO, loc = loc)
    }

    mem.copy(structs[len(structs) - 1], &out_structure, size_of(vk.BaseOutStructure))
    structure.pNext = structs[0]
}

@(disabled = !ODIN_DEBUG)
vk_set_debug_object_name :: proc(
    device: vk.Device,
    type: vk.ObjectType,
    #any_int handle: vk.NonDispatchableHandle,
    name: string,
    loc := #caller_location,
) {
    if len(name) == 0 || vk.SetDebugUtilsObjectNameEXT == nil {
        return
    }

    name_buf: String_Buffer_Small
    string_buffer_init(&name_buf, name)

    ni := vk.DebugUtilsObjectNameInfoEXT {
        sType        = .DEBUG_UTILS_OBJECT_NAME_INFO_EXT,
        objectType   = type,
        objectHandle = u64(handle),
        pObjectName  = string_buffer_get_cstring(&name_buf),
    }

    vk_check(vk.SetDebugUtilsObjectNameEXT(device, &ni), loc = loc)
}

vk_create_semaphore :: proc(
    device: vk.Device,
    debug_name: string,
    loc := #caller_location,
) -> (
    semaphore: vk.Semaphore,
) {
    ci := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
    }

    vk_check(vk.CreateSemaphore(device, &ci, nil, &semaphore), loc = loc)
    vk_set_debug_object_name(device, .SEMAPHORE, semaphore, debug_name)

    return
}

vk_create_semaphore_timeline :: proc(
    device: vk.Device,
    initial_value: u64,
    debug_name: string,
    loc := #caller_location,
) -> (
    semaphore: vk.Semaphore,
) {
    semaphore_type_create_info := vk.SemaphoreTypeCreateInfo {
        sType = .SEMAPHORE_TYPE_CREATE_INFO,
        semaphoreType = .TIMELINE,
        initialValue = initial_value,
    }

    ci := vk.SemaphoreCreateInfo {
        sType = .SEMAPHORE_CREATE_INFO,
        pNext = &semaphore_type_create_info,
    }

    vk_check(vk.CreateSemaphore(device, &ci, nil, &semaphore))
    vk_set_debug_object_name(device, .SEMAPHORE, semaphore, debug_name)

    return
}

vk_create_fence :: proc(
    device: vk.Device,
    debug_name: string,
    signaled := false,
    loc := #caller_location,
) -> (
    fence: vk.Fence,
) {
    ci := vk.FenceCreateInfo {
        sType = .FENCE_CREATE_INFO,
        flags = signaled ? { .SIGNALED } : {},
    }

    vk_check(vk.CreateFence(device, &ci, nil, &fence), loc = loc)
    vk_set_debug_object_name(device, .FENCE, fence, debug_name)

    return
}

vk_command_encoder_wait_all :: proc(self: ^Vulkan_Command_Encoder_Impl, loc := #caller_location) {
    fences: [VK_MAX_COMMAND_BUFFERS]vk.Fence

    num_fences: int
    for &buf in self.buffers {
        if buf.vk_cmd_buf != nil && !buf.is_encoding {
            fences[num_fences] = buf.vk_fence
            num_fences += 1
        }
    }

    if num_fences > 0 {
        vk_check(vk.WaitForFences(
            self.vk_device, u32(num_fences), raw_data(fences[:]), true, max(u64)))
    }

    vk_command_encoder_purge(self, loc)
}

vk_command_encoder_purge :: proc(self: ^Vulkan_Command_Encoder_Impl, loc := #caller_location) {
    num_buffers := u32(len(self.buffers))

    // for i in 0 ..< num_buffers {
    for i : u32 = 0; i != num_buffers; i += 1 {
        // Always start checking with the oldest submitted buffer, then wrap around
        idx := (i + self.last_submit_handle.buffer_index + 1) % num_buffers
        buf := &self.buffers[idx]

        if buf.vk_cmd_buf == nil || buf.is_encoding {
            continue
        }

        result := vk.WaitForFences(self.vk_device, 1, &buf.vk_fence, true, 0)

        if result == .SUCCESS {
            vk_deletion_queue_flush(&buf.resources, loc)
            command_allocator_reset(&buf.cmd_allocator)
            vk_check(vk.ResetCommandBuffer(buf.vk_cmd_buf, {}))
            vk_check(vk.ResetFences(self.vk_device, 1, &buf.vk_fence))
            buf.vk_cmd_buf = nil
            buf.current_pipeline_graphics = nil
            self.available_command_buffers += 1
        } else {
            if result != .TIMEOUT {
                vk_check(result, "WaitForFences failed", loc)
            }
        }
    }
}

vk_texture_create_image_view :: proc(
    texture: ^Vulkan_Texture_Impl,
    device: vk.Device,
    type: vk.ImageViewType,
    format: vk.Format,
    aspect_mask: vk.ImageAspectFlags,
    base_level: u32,
    num_levels: u32 = vk.REMAINING_MIP_LEVELS,
    base_layer: u32 = 0,
    num_layers: u32 = 1,
    components: vk.ComponentMapping = {}, // .IDENTITY
    ycbcr: ^vk.SamplerYcbcrConversionInfo = nil,
    debug_name: string = "",
) -> (
    vk_image_view: vk.ImageView,
) {
    ci := vk.ImageViewCreateInfo {
        sType = .IMAGE_VIEW_CREATE_INFO,
        pNext = ycbcr,
        image = texture.vk_image,
        viewType = type,
        format = format,
        components = components,
        subresourceRange = {
            aspectMask     = aspect_mask,
            baseMipLevel   = base_level,
            levelCount     = num_levels > 0 ? num_levels : texture.num_levels,
            baseArrayLayer = base_layer,
            layerCount     = num_layers,
        },
    }

    vk_check(vk.CreateImageView(device, &ci, nil, &vk_image_view))
    vk_set_debug_object_name(device, .IMAGE_VIEW, vk_image_view, debug_name)

    return
}

vk_image_usage_is_sampled :: #force_inline proc(usages: vk.ImageUsageFlags) -> bool {
    return .SAMPLED in usages
}

vk_image_usage_is_storage :: #force_inline proc(usages: vk.ImageUsageFlags) -> bool {
    return .STORAGE in usages
}

vk_image_usage_is_color_attachment :: #force_inline proc(usages: vk.ImageUsageFlags) -> bool {
    return .COLOR_ATTACHMENT in usages
}

vk_image_usage_is_depth_attachment :: #force_inline proc(usages: vk.ImageUsageFlags) -> bool {
    return .DEPTH_STENCIL_ATTACHMENT in usages
}

vk_image_usage_is_attachment :: #force_inline proc(usages: vk.ImageUsageFlags) -> bool {
    return .COLOR_ATTACHMENT in usages ||
           .DEPTH_STENCIL_ATTACHMENT in usages
}

vk_transition_to_color_attachment :: proc(
    cmd: ^Vulkan_Command_Buffer_Impl,
    texture: ^Vulkan_Texture_Impl,
    loc := #caller_location,
) {
    assert(texture.is_depth_format == false,
        "Color attachments cannot have depth format", loc)
    assert(texture.is_stencil_format == false,
        "Color attachments cannot have stencil format", loc)
    assert(texture.vk_image_format != .UNDEFINED, "Invalid color attachment format", loc)

    subresource_range := vk.ImageSubresourceRange {
        aspectMask     = { .COLOR },
        baseMipLevel   = 0,
        levelCount     = vk.REMAINING_MIP_LEVELS,
        baseArrayLayer = 0,
        layerCount     = vk.REMAINING_ARRAY_LAYERS,
    }

    vk_texture_transition_layout(
        texture, cmd.vk_cmd_buf, .COLOR_ATTACHMENT_OPTIMAL, subresource_range, loc)
}

vk_texture_transition_layout :: proc(
    texture: ^Vulkan_Texture_Impl,
    command_buffer: vk.CommandBuffer,
    new_image_layout: vk.ImageLayout,
    subresource_range: vk.ImageSubresourceRange,
    loc := #caller_location,
) {
    // Calculate actual layer count from sentinel value, with bounds checking
    actual_layer_count := subresource_range.layerCount
    if actual_layer_count == vk.REMAINING_ARRAY_LAYERS {
        assert(subresource_range.baseArrayLayer < texture.num_layers,
            "Base array layer out of bounds", loc)
        actual_layer_count = texture.num_layers - subresource_range.baseArrayLayer
    }

    assert(actual_layer_count > 0, "Invalid layer count in subresource range", loc)
    assert(subresource_range.baseArrayLayer + actual_layer_count <= texture.num_layers,
        "Subresource range exceeds texture layers", loc)

    // Calculate actual mip level count from sentinel value, with bounds checking
    actual_level_count := subresource_range.levelCount
    if actual_level_count == vk.REMAINING_MIP_LEVELS {
        assert(subresource_range.baseMipLevel < texture.num_levels, "Base mip level out of bounds", loc)
        actual_level_count = texture.num_levels - subresource_range.baseMipLevel
    }

    assert(actual_level_count > 0, "Invalid mip level count in subresource range", loc)
    assert(subresource_range.baseMipLevel + actual_level_count <= texture.num_levels,
        "Subresource range exceeds texture mip levels", loc)

    // Cache depth attachment check for efficiency
    is_depth_attachment := vk_image_usage_is_depth_attachment(texture.vk_usage_flags)

    // Get old layout for the first layer in the range
    old_image_layout := texture.vk_layer_layouts[subresource_range.baseArrayLayer]
    if old_image_layout == .ATTACHMENT_OPTIMAL {
        old_image_layout =
            is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
    }

    // Resolve new layout
    resolved_new_layout := new_image_layout
    if resolved_new_layout == .ATTACHMENT_OPTIMAL {
        resolved_new_layout =
            is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
    }

    end_layer := subresource_range.baseArrayLayer + actual_layer_count

    when ODIN_DEBUG {
        // Verify all layers in the range have the same old layout (safety check)
        for layer in subresource_range.baseArrayLayer + 1 ..< end_layer {
            layer_old_layout := texture.vk_layer_layouts[layer]
            if layer_old_layout == .ATTACHMENT_OPTIMAL {
                layer_old_layout =
                    is_depth_attachment ? .DEPTH_STENCIL_ATTACHMENT_OPTIMAL : .COLOR_ATTACHMENT_OPTIMAL
            }
            assert(layer_old_layout == old_image_layout,
                "Layers in subresource range have inconsistent old layouts; split the transition", loc)
        }
    }

    // Get source and destination pipeline stages/accesses
    src := vk_get_pipeline_stage_access(old_image_layout)
    dst := vk_get_pipeline_stage_access(resolved_new_layout)

    // Adjust for resolve attachments if applicable
    if is_depth_attachment && texture.is_resolve_attachment {
        src.stage += { .COLOR_ATTACHMENT_OUTPUT }
        dst.stage += { .COLOR_ATTACHMENT_OUTPUT }
        src.access += { .COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE }
        dst.access += { .COLOR_ATTACHMENT_READ, .COLOR_ATTACHMENT_WRITE }
    }

    // Set up the image memory barrier
    barrier := vk.ImageMemoryBarrier2 {
        sType               = .IMAGE_MEMORY_BARRIER_2,
        srcStageMask        = src.stage,
        srcAccessMask       = src.access,
        dstStageMask        = dst.stage,
        dstAccessMask       = dst.access,
        oldLayout           = old_image_layout,
        newLayout           = resolved_new_layout,
        srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        image               = texture.vk_image,
        subresourceRange    = subresource_range,
    }

    // Dependency info for the barrier
    dep_info := vk.DependencyInfo {
        sType                   = .DEPENDENCY_INFO,
        imageMemoryBarrierCount = 1,
        pImageMemoryBarriers    = &barrier,
    }

    // Record the pipeline barrier
    vk.CmdPipelineBarrier2(command_buffer, &dep_info)

    // Update layouts for all affected layers.
    //
    // Note: We track per-layer layouts only, assuming all mip levels per layer
    // share the same layout
    for layer in subresource_range.baseArrayLayer ..< end_layer {
        texture.vk_layer_layouts[layer] = resolved_new_layout
    }

    // Update the global layout tracker only if the entire image (all layers) is transitioned
    if subresource_range.baseArrayLayer == 0 && actual_layer_count == texture.num_layers {
        texture.vk_image_layout = resolved_new_layout
    }
}

VK_MAX_DYNAMIC_STATES :: 128

Vulkan_Pipeline_Builder :: struct {
    dynamic_states:                sa.Small_Array(VK_MAX_DYNAMIC_STATES, vk.DynamicState),
    shader_stages:                 sa.Small_Array(5, vk.PipelineShaderStageCreateInfo),
    vertex_input_state:            vk.PipelineVertexInputStateCreateInfo,
    input_assembly:                vk.PipelineInputAssemblyStateCreateInfo,
    rasterization_state:           vk.PipelineRasterizationStateCreateInfo,
    multisample_state:             vk.PipelineMultisampleStateCreateInfo,
    depth_stencil_state:           vk.PipelineDepthStencilStateCreateInfo,
    tessellation_state:            vk.PipelineTessellationStateCreateInfo,
    view_mask:                     u32,
    color_blend_attachment_states: sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.PipelineColorBlendAttachmentState),
    color_attachment_formats:      sa.Small_Array(MAX_COLOR_ATTACHMENTS, vk.Format),
    depth_attachment_format:       vk.Format,
    stencil_attachment_format:     vk.Format,
    num_pipelines_created:         u32,
}

VULKAN_PIPELINE_BUILDER_DEFAULT :: Vulkan_Pipeline_Builder {
    vertex_input_state = {
        sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    },
    input_assembly = {
        sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        topology = .TRIANGLE_LIST,
    },
    rasterization_state = {
        sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        polygonMode = .FILL,
        cullMode = vk.CullModeFlags_NONE,
        frontFace = .COUNTER_CLOCKWISE,
        lineWidth = 1.0,
    },
    multisample_state = {
        sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        rasterizationSamples = { ._1 },
    },
    depth_stencil_state = {
        sType = .PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO,
        depthCompareOp = .LESS,
        front = {
            failOp = .KEEP,
            passOp = .KEEP,
            depthFailOp = .KEEP,
            compareOp = .NEVER,
        },
        back = {
            failOp = .KEEP,
            passOp = .KEEP,
            depthFailOp = .KEEP,
            compareOp = .NEVER,
        },
        maxDepthBounds = 1.0,
    },
    tessellation_state = {
        sType = .PIPELINE_TESSELLATION_STATE_CREATE_INFO,
    },
}

vk_pipeline_builder_add_dynamic_state :: proc(
    self: ^Vulkan_Pipeline_Builder,
    state: vk.DynamicState,
    loc := #caller_location,
) {
    assert(sa.len(self.dynamic_states) < VK_MAX_DYNAMIC_STATES, loc = loc)
    sa.push_back(&self.dynamic_states, state)
}

vk_pipeline_builder_add_dynamic_states :: proc(
    self: ^Vulkan_Pipeline_Builder,
    states: []vk.DynamicState,
    loc := #caller_location,
) {
    assert(sa.len(self.dynamic_states) + len(states) < VK_MAX_DYNAMIC_STATES, loc = loc)
    sa.push_back_elems(&self.dynamic_states, ..states)
}

vk_pipeline_builder_set_primitive_topology :: proc(self: ^Vulkan_Pipeline_Builder, topology: vk.PrimitiveTopology) {
    self.input_assembly.topology = topology
}

vk_pipeline_builder_set_rasterization_samples :: proc(
    self: ^Vulkan_Pipeline_Builder,
    samples: vk.SampleCountFlags,
    min_sample_shading: f32,
) {
    self.multisample_state.rasterizationSamples = samples
    self.multisample_state.sampleShadingEnable = min_sample_shading > 0
    self.multisample_state.minSampleShading = min_sample_shading
}

vk_pipeline_builder_set_cull_mode :: proc(self: ^Vulkan_Pipeline_Builder, mode: vk.CullModeFlags) {
    self.rasterization_state.cullMode = mode
}

vk_pipeline_builder_set_front_face :: proc(self: ^Vulkan_Pipeline_Builder, mode: vk.FrontFace) {
    self.rasterization_state.frontFace = mode
}

vk_pipeline_builder_set_polygon_mode :: proc(self: ^Vulkan_Pipeline_Builder, mode: vk.PolygonMode) {
    self.rasterization_state.polygonMode = mode
}

vk_pipeline_builder_set_vertex_input_state :: proc(
    self: ^Vulkan_Pipeline_Builder,
    state: vk.PipelineVertexInputStateCreateInfo,
) {
    self.vertex_input_state = state
}

vk_pipeline_builder_set_view_mask :: proc(self: ^Vulkan_Pipeline_Builder, mask: u32) {
    self.view_mask = mask
}

vk_pipeline_builder_add_color_attachments :: proc(
    self: ^Vulkan_Pipeline_Builder,
    states: []vk.PipelineColorBlendAttachmentState,
    formats: []vk.Format,
    loc := #caller_location,
) {
    assert(states != nil, "Invalid states", loc)
    assert(formats != nil, "Invalid formats", loc)
    assert(len(states) == len(formats), "Mismatch number of states and formats", loc)
    num_color_attachments := len(states)
    assert(sa.len(self.color_blend_attachment_states) + num_color_attachments <= MAX_COLOR_ATTACHMENTS, loc = loc)
    assert(sa.len(self.color_attachment_formats) + num_color_attachments <= MAX_COLOR_ATTACHMENTS, loc = loc)
    sa.push_back_elems(&self.color_blend_attachment_states, ..states)
    sa.push_back_elems(&self.color_attachment_formats, ..formats)
}

vk_pipeline_builder_set_depth_attachment_format :: proc(self: ^Vulkan_Pipeline_Builder, format: vk.Format) {
    self.depth_attachment_format = format
}

vk_pipeline_builder_set_stencil_attachment_format :: proc(self: ^Vulkan_Pipeline_Builder, format: vk.Format) {
    self.stencil_attachment_format = format
}

vk_pipeline_builder_set_patch_control_points :: proc(self: ^Vulkan_Pipeline_Builder, num_points: u32) {
    self.tessellation_state.patchControlPoints = num_points
}

vk_pipeline_builder_add_shader_stage :: proc(self: ^Vulkan_Pipeline_Builder, stage: vk.PipelineShaderStageCreateInfo) {
    sa.push_back(&self.shader_stages, stage)
}

vk_pipeline_builder_set_stencil_state_ops :: proc(
    self: ^Vulkan_Pipeline_Builder,
    face_mask: vk.StencilFaceFlags,
    fail_op: vk.StencilOp,
    pass_op: vk.StencilOp,
    depth_fail_op: vk.StencilOp,
    compare_op: vk.CompareOp,
) {
  self.depth_stencil_state.stencilTestEnable = self.depth_stencil_state.stencilTestEnable || fail_op != .KEEP ||
                                                 pass_op != .KEEP || depth_fail_op != .KEEP ||
                                                 compare_op != .ALWAYS

    if .FRONT in face_mask {
        s := self.depth_stencil_state.front
        s.failOp = fail_op
        s.passOp = pass_op
        s.depthFailOp = depth_fail_op
        s.compareOp = compare_op
    }

    if .BACK in face_mask {
        s := self.depth_stencil_state.back
        s.failOp = fail_op
        s.passOp = pass_op
        s.depthFailOp = depth_fail_op
        s.compareOp = compare_op
    }
}

vk_pipeline_builder_set_stencil_masks :: proc(
    self: ^Vulkan_Pipeline_Builder,
    face_mask: vk.StencilFaceFlags,
    compare_mask: u32,
    write_mask: u32,
    reference: u32,
) {
    if .FRONT in face_mask {
        s := self.depth_stencil_state.front
        s.compareMask = compare_mask
        s.writeMask = write_mask
        s.reference = reference
    }

    if .BACK in face_mask {
        s := self.depth_stencil_state.back
        s.compareMask = compare_mask
        s.writeMask = write_mask
        s.reference = reference
    }
}

vk_pipeline_builder_build :: proc(
    self: ^Vulkan_Pipeline_Builder,
    device: vk.Device,
    pipeline_cache: vk.PipelineCache,
    pipeline_layout: vk.PipelineLayout,
    debug_name: string,
    loc := #caller_location,
) -> (
    vk_pipeline: vk.Pipeline,
) {
    dynamic_state := vk.PipelineDynamicStateCreateInfo {
        sType             = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        dynamicStateCount = u32(sa.len(self.dynamic_states)),
        pDynamicStates    = raw_data(sa.slice(&self.dynamic_states)),
    }

    // viewport and scissor can be NULL if the viewport state is dynamic
    // https://www.khronos.org/registry/vulkan/specs/1.3-extensions/man/html/VkPipelineViewportStateCreateInfo.html
    viewport_state := vk.PipelineViewportStateCreateInfo {
        sType         = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        viewportCount = 1,
        pViewports    = nil,
        scissorCount  = 1,
        pScissors     = nil,
    }

    color_blend_state := vk.PipelineColorBlendStateCreateInfo {
        sType           = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        logicOpEnable   = false,
        logicOp         = .COPY,
        attachmentCount = u32(sa.len(self.color_blend_attachment_states)),
        pAttachments    = raw_data(sa.slice(&self.color_blend_attachment_states)),
    }

    rendering_info := vk.PipelineRenderingCreateInfo {
        sType                   = .PIPELINE_RENDERING_CREATE_INFO_KHR,
        pNext                   = nil,
        viewMask                = self.view_mask,
        colorAttachmentCount    = u32(sa.len(self.color_attachment_formats)),
        pColorAttachmentFormats = raw_data(sa.slice(&self.color_attachment_formats)),
        depthAttachmentFormat   = self.depth_attachment_format,
        stencilAttachmentFormat = self.stencil_attachment_format,
    }

    ci := vk.GraphicsPipelineCreateInfo {
        sType               = .GRAPHICS_PIPELINE_CREATE_INFO,
        pNext               = &rendering_info,
        flags               = {},
        stageCount          = u32(sa.len(self.shader_stages)),
        pStages             = raw_data(sa.slice(&self.shader_stages)),
        pVertexInputState   = &self.vertex_input_state,
        pInputAssemblyState = &self.input_assembly,
        pTessellationState  = &self.tessellation_state,
        pViewportState      = &viewport_state,
        pRasterizationState = &self.rasterization_state,
        pMultisampleState   = &self.multisample_state,
        pDepthStencilState  = &self.depth_stencil_state,
        pColorBlendState    = &color_blend_state,
        pDynamicState       = &dynamic_state,
        layout              = pipeline_layout,
        renderPass          = {},
        subpass             = 0,
        basePipelineHandle  = {},
        basePipelineIndex   = -1,
    }

    vk_check(vk.CreateGraphicsPipelines(device, pipeline_cache, 1, &ci, nil, &vk_pipeline), loc = loc)

    if len(debug_name) > 0 {
        vk_set_debug_object_name(device, .PIPELINE, vk_pipeline, debug_name, loc)
    }

    return
}

Vulkan_Resource :: union {
    ^Vulkan_Bind_Group_Impl,
    ^Vulkan_Buffer_Impl,
    ^Vulkan_Render_Pipeline_Impl,
    ^Vulkan_Texture_Impl,
}

Vulkan_Deletion_Queue :: struct {
    device:    vk.Device,
    resources: [dynamic]Vulkan_Resource,
    allocator: mem.Allocator,
}

vk_deletion_queue_init :: proc(
    self: ^Vulkan_Deletion_Queue,
    device: vk.Device,
    allocator := context.allocator,
) {
    assert(self != nil, "Invalid 'Deletion_Queue'")
    assert(device != nil, "Invalid 'Device'")

    self.allocator = allocator
    self.device = device
    self.resources = make([dynamic]Vulkan_Resource, self.allocator)
}

vk_deletion_queue_destroy :: proc(self: ^Vulkan_Deletion_Queue) {
    assert(self != nil)
    context.allocator = self.allocator
    vk_deletion_queue_flush(self)
    delete(self.resources)
}

vk_deletion_queue_push :: proc(self: ^Vulkan_Deletion_Queue, resource: Vulkan_Resource, loc := #caller_location) {
    switch &res in resource {
    case ^Vulkan_Bind_Group_Impl:
        vk_bind_group_add_ref(Bind_Group(res), loc)
    case ^Vulkan_Buffer_Impl:
        vk_buffer_add_ref(Buffer(res), loc)
    case ^Vulkan_Render_Pipeline_Impl:
        vk_render_pipeline_add_ref(Render_Pipeline(res), loc)
    case ^Vulkan_Texture_Impl:
        if !res.is_swapchain_image {
            vk_texture_add_ref(Texture(res), loc)
        }
    }
    append(&self.resources, resource)
}

// LIFO (Last-In, First-Out) deletion.
vk_deletion_queue_flush :: proc(self: ^Vulkan_Deletion_Queue, loc := #caller_location) {
    assert(self != nil, loc = loc)

    if len(self.resources) == 0 {
        return
    }

    // Process resources in reverse order (LIFO)
    #reverse for &resource in self.resources {
        switch &res in resource {
        case ^Vulkan_Bind_Group_Impl:
            vk_bind_group_release(Bind_Group(res), loc)
        case ^Vulkan_Buffer_Impl:
            vk_buffer_release(Buffer(res), loc)
        case ^Vulkan_Render_Pipeline_Impl:
            vk_render_pipeline_release(Render_Pipeline(res), loc)
        case ^Vulkan_Texture_Impl:
            vk_texture_release(Texture(res), loc)
        }
    }

    // Clear the array after processing all resources
    clear(&self.resources)
}

Vulkan_Pool_Size_Ratio :: struct {
    type:  vk.DescriptorType,
    ratio: f32,
}

Vulkan_Descriptor_Pool_State :: struct {
    pool:           vk.DescriptorPool,
    allocated_sets: u32,
    max_sets:       u32,
}

Vulkan_Descriptor_Allocator :: struct {
    device:         ^Vulkan_Device_Impl,
    pool_ratios:    []Vulkan_Pool_Size_Ratio,
    sets_per_pool:  u32,
    active_pools:   [dynamic]Vulkan_Descriptor_Pool_State,
    full_pools:     [dynamic]vk.DescriptorPool,
    allocator:      runtime.Allocator,
}

vk_descriptor_allocator_init :: proc(
    alloc: ^Vulkan_Descriptor_Allocator,
    device: ^Vulkan_Device_Impl,
    initial_sets_per_pool: u32,
    pool_ratios: []Vulkan_Pool_Size_Ratio,
    allocator := context.allocator,
) {
    alloc.device = device
    alloc.sets_per_pool = initial_sets_per_pool
    alloc.allocator = allocator

    // Copy pool ratios
    alloc.pool_ratios = make([]Vulkan_Pool_Size_Ratio, len(pool_ratios), allocator)
    copy(alloc.pool_ratios, pool_ratios)

    alloc.active_pools = make([dynamic]Vulkan_Descriptor_Pool_State, 0, 8, allocator)
    alloc.full_pools = make([dynamic]vk.DescriptorPool, 0, 8, allocator)

    // Create initial pool
    pool, max_sets := vk_descriptor_allocator_create_pool(alloc, initial_sets_per_pool)
    append(&alloc.active_pools, Vulkan_Descriptor_Pool_State{
        pool = pool,
        allocated_sets = 0,
        max_sets = max_sets,
    })
}

vk_descriptor_allocator_destroy :: proc(alloc: ^Vulkan_Descriptor_Allocator) {
    for pool_state in alloc.active_pools {
        vk.DestroyDescriptorPool(alloc.device.vk_device, pool_state.pool, nil)
    }

    for pool in alloc.full_pools {
        vk.DestroyDescriptorPool(alloc.device.vk_device, pool, nil)
    }

    delete(alloc.pool_ratios, alloc.allocator)
    delete(alloc.active_pools)
    delete(alloc.full_pools)
}

vk_descriptor_allocator_reset :: proc(alloc: ^Vulkan_Descriptor_Allocator) {
    // Reset all active pools
    for &pool_state in alloc.active_pools {
        vk.ResetDescriptorPool(alloc.device.vk_device, pool_state.pool, {})
        pool_state.allocated_sets = 0
    }

    // Move full pools back to active and reset them
    for pool in alloc.full_pools {
        vk.ResetDescriptorPool(alloc.device.vk_device, pool, {})
        append(&alloc.active_pools, Vulkan_Descriptor_Pool_State{
            pool = pool,
            allocated_sets = 0,
            max_sets = alloc.sets_per_pool,
        })
    }

    clear(&alloc.full_pools)
}

@(require_results)
vk_descriptor_allocator_create_pool :: proc(
    alloc: ^Vulkan_Descriptor_Allocator,
    set_count: u32,
    loc := #caller_location,
) -> (
    pool: vk.DescriptorPool,
    max_sets: u32,
) {
    ta := context.temp_allocator

    pool_sizes := make([dynamic]vk.DescriptorPoolSize, 0, len(alloc.pool_ratios), ta)

    for ratio in alloc.pool_ratios {
        count := u32(ratio.ratio * f32(set_count))
        if count > 0 {
            append(&pool_sizes, vk.DescriptorPoolSize{
                type = ratio.type,
                descriptorCount = count,
            })
        }
    }

    pool_info := vk.DescriptorPoolCreateInfo{
        sType         = .DESCRIPTOR_POOL_CREATE_INFO,
        flags         = {},
        maxSets       = set_count,
        poolSizeCount = u32(len(pool_sizes)),
        pPoolSizes    = raw_data(pool_sizes),
    }

    vk_check(vk.CreateDescriptorPool(alloc.device.vk_device, &pool_info, nil, &pool), loc = loc)

    return pool, set_count
}

@(require_results)
vk_descriptor_allocator_allocate :: proc(
    alloc: ^Vulkan_Descriptor_Allocator,
    layout: ^vk.DescriptorSetLayout,
    loc := #caller_location,
) -> (
    set: vk.DescriptorSet,
    pool: vk.DescriptorPool,
) {
    // Try to allocate from active pools
    for &pool_state in alloc.active_pools {
        if pool_state.allocated_sets >= pool_state.max_sets {
            continue
        }

        alloc_info := vk.DescriptorSetAllocateInfo{
            sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
            descriptorPool     = pool_state.pool,
            descriptorSetCount = 1,
            pSetLayouts        = layout,
        }

        result := vk.AllocateDescriptorSets(alloc.device.vk_device, &alloc_info, &set)

        if result == .SUCCESS {
            pool_state.allocated_sets += 1
            return set, pool_state.pool
        }

        // Pool is full or fragmented, mark it
        if result == .ERROR_OUT_OF_POOL_MEMORY || result == .ERROR_FRAGMENTED_POOL {
            append(&alloc.full_pools, pool_state.pool)
            unordered_remove(&alloc.active_pools, pool_state.pool)
            continue
        }

        // Other error
        panic("Failed to allocate descriptor set", loc)
    }

    // No active pools available, create new one
    // Grow pool size by 50% with upper limit of 4092
    new_pool_size := min(u32(f32(alloc.sets_per_pool) * 1.5), 4092)
    alloc.sets_per_pool = new_pool_size

    new_pool, max_sets := vk_descriptor_allocator_create_pool(alloc, new_pool_size, loc = loc)

    alloc_info := vk.DescriptorSetAllocateInfo{
        sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
        descriptorPool     = new_pool,
        descriptorSetCount = 1,
        pSetLayouts        = layout,
    }

    vk_check(vk.AllocateDescriptorSets(alloc.device.vk_device, &alloc_info, &set), loc = loc)

    append(&alloc.active_pools, Vulkan_Descriptor_Pool_State{
        pool = new_pool,
        allocated_sets = 1,
        max_sets = max_sets,
    })

    return set, new_pool
}

vk_compute_texture_copy_extent :: proc(
    texture_copy: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) -> Extent_3D {
    valid_texture_copy_extent := copy_size

    texture := get_impl(Vulkan_Texture_Impl, texture_copy.texture, loc)

    virtual_size_at_level :=
        texture_get_virtual_mip_size(texture, texture_copy.mip_level, texture_copy.aspect)

    assert(texture_copy.origin.x <= virtual_size_at_level.width)
    assert(texture_copy.origin.y <= virtual_size_at_level.height)

    if copy_size.width > virtual_size_at_level.width - texture_copy.origin.x {
        assert(texture_format_is_compressed(texture.format), loc = loc)
        valid_texture_copy_extent.width = virtual_size_at_level.width - texture_copy.origin.x
    }

    if copy_size.height > virtual_size_at_level.height - texture_copy.origin.y {
        assert(texture_format_is_compressed(texture.format), loc = loc)
        valid_texture_copy_extent.height = virtual_size_at_level.height - texture_copy.origin.y
    }

    return valid_texture_copy_extent
}

vk_compute_buffer_image_copy_region :: proc(
    data_layout: Texel_Copy_Buffer_Layout,
    texture_copy: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) -> (
    region: vk.BufferImageCopy,
) {
    texture := get_impl(Vulkan_Texture_Impl, texture_copy.texture, loc)

    region.bufferOffset = vk.DeviceSize(data_layout.offset)

    region.bufferRowLength = data_layout.bytes_per_row / texture_format_block_copy_size(texture.format)
    region.bufferImageHeight = data_layout.rows_per_image

    region.imageSubresource.aspectMask =
        vk_conv_to_image_aspect_flags(texture_copy.aspect, texture.format)
    region.imageSubresource.mipLevel = texture_copy.mip_level

    switch texture.dimension {
    case .Undefined:
        unreachable()

    case .D1:
        assert(texture_copy.origin.z == 0 && copy_size.depth_or_array_layers == 1, loc = loc)
        region.imageOffset.x = i32(texture_copy.origin.x)
        region.imageOffset.y = 0
        region.imageOffset.z = 0
        region.imageSubresource.baseArrayLayer = 0
        region.imageSubresource.layerCount = 1

        assert(!texture_format_is_compressed(texture.format), loc = loc)
        region.imageExtent.width = copy_size.width
        region.imageExtent.height = 1
        region.imageExtent.depth = 1

    case .D2:
        region.imageOffset.x = i32(texture_copy.origin.x)
        region.imageOffset.y = i32(texture_copy.origin.y)
        region.imageOffset.z = 0
        region.imageSubresource.baseArrayLayer = texture_copy.origin.z
        region.imageSubresource.layerCount = copy_size.depth_or_array_layers

        image_extent := vk_compute_texture_copy_extent(texture_copy, copy_size)
        region.imageExtent.width = image_extent.width
        region.imageExtent.height = image_extent.height
        region.imageExtent.depth = 1

    case .D3:
        region.imageOffset.x = i32((texture_copy.origin.x))
        region.imageOffset.y = i32((texture_copy.origin.y))
        region.imageOffset.z = i32((texture_copy.origin.z))
        region.imageSubresource.baseArrayLayer = 0
        region.imageSubresource.layerCount = 1

        image_extent := vk_compute_texture_copy_extent(texture_copy, copy_size)
        region.imageExtent.width = image_extent.width
        region.imageExtent.height = image_extent.height
        region.imageExtent.depth = copy_size.depth_or_array_layers
    }

    return
}
