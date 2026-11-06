#+build !js
package gpu

// Core
import "base:runtime"
import "core:log"
import "core:sync"

// Vendor
import gpua "allocator"
import "lib/vma"
import vk "vendor:vulkan"

// Deferred release engine.
//
// Resources whose last reference was dropped are parked against the submission
// they were last used in and destroyed when that submission retires.

// -----------------------------------------------------------------------------
// Deferred deletion
// -----------------------------------------------------------------------------

VK_Deferred_Buffer :: struct {
    buffer:         vk.Buffer,
    tracker_index:  Tracker_Index,
    vma_allocation: vma.Allocation,
    gpu_allocation: gpua.VK_Allocation,
    init:           Buffer_Init_Tracker,
}

VK_Deferred_Image :: struct {
    image:         vk.Image,
    tracker_index: Tracker_Index,
    allocation:    VK_Texture_Memory_Allocation,
    init:          Texture_Init_Tracker,
}

VK_Deferred_Descriptor_Set :: struct {
    descriptor:     ^VK_Descriptor_Allocator,
    descriptor_set: VK_Descriptor_Set,
}

VK_Deferred_Sampler :: struct {
    cache:       ^VK_Sampler_Cache,
    create_info: vk.SamplerCreateInfo,
    sampler:     vk.Sampler,
}

VK_Deferred_Query_Set :: struct {
    pool: vk.QueryPool,
}

VK_Deferred_Bind_Group_Layout :: struct {
    allocator: ^VK_Descriptor_Allocator,
    layout:    VK_Descriptor_Layout_Info,
}

VK_Deferred_Shader_Module :: struct {
    module: vk.ShaderModule,
}

VK_Deferred_Resource :: union {
    VK_Deferred_Buffer,
    VK_Deferred_Image,
    VK_Deferred_Descriptor_Set,
    VK_Deferred_Sampler,
    VK_Deferred_Query_Set,
    VK_Deferred_Bind_Group_Layout,
    VK_Deferred_Shader_Module,
    vk.ImageView,
    vk.Pipeline,
    vk.Sampler,
    vk.Framebuffer,
    vk.RenderPass,
    vk.DescriptorSetLayout,
    vk.PipelineLayout,
}

// Destruction kinds, in dependency order: framebuffers and views before the
// images they name, buffers before the memory they used, pipelines before the
// layouts they borrow.
VK_Release_Kind :: enum u8 {
    Framebuffer,
    View,
    Buffer,
    Shader_Module,
    Bind_Group,
    Render_Pipeline,
    Compute_Pipeline,
    Pipeline_Layout,
    Bind_Group_Layout,
    Sampler,
    Query_Set,
    Texture,
    Kind_Count,
}

// Derived from the enum so a new kind cannot leave this behind.
VK_RELEASE_KIND_COUNT :: int(VK_Release_Kind.Kind_Count)

VK_Deferred_Deletion :: struct {
    wait_on:  VK_Submit_Handle,
    kind:     VK_Release_Kind,
    resource: VK_Deferred_Resource,
}

// Which queue a record belongs to. The union variant is enough: everything that
// builds a record already knows its type, and `vk.Pipeline` cannot distinguish a
// render from a compute pipeline, which share a destruction path anyway.
@(private = "file")
vk_release_kind_for :: proc(resource: VK_Deferred_Resource) -> VK_Release_Kind {
    #partial switch res in resource {
    case VK_Deferred_Buffer:
        return .Buffer
    case VK_Deferred_Image:
        return .Texture
    case VK_Deferred_Descriptor_Set:
        return .Bind_Group
    case VK_Deferred_Sampler:
        return .Sampler
    case VK_Deferred_Query_Set:
        return .Query_Set
    case VK_Deferred_Bind_Group_Layout:
        return .Bind_Group_Layout
    case VK_Deferred_Shader_Module:
        return .Shader_Module
    case vk.ImageView:
        return .View
    case vk.Pipeline:
        return .Render_Pipeline
    case vk.Sampler:
        return .Sampler
    case vk.Framebuffer:
        return .Framebuffer
    case vk.RenderPass:
        return .Framebuffer
    case vk.DescriptorSetLayout:
        return .Bind_Group_Layout
    case vk.PipelineLayout:
        return .Pipeline_Layout
    }
    // A new `VK_Deferred_Resource` variant must be given a destruction queue here.
    // Trapping is deliberate: the previous `.Framebuffer` fallback would silently
    // misroute the release instead of pointing at the missing case.
    unreachable()
}

// Resources whose last reference was dropped, held back until the submission they
// were last used in has completed.
//
// One queue per release kind, drained in kind order; each queue preserves record
// order within a kind. `mtx` guards every enqueue and drain. Destruction runs
// under it and may take the descriptor, sampler, tracker and tracker-index locks,
// so those rank below the deletor; nothing takes the deletor while holding them.
VK_Deferred_Deletor :: struct {
    device:        Device,
    queues:        [VK_RELEASE_KIND_COUNT][dynamic]VK_Deferred_Deletion,
    allocator:     runtime.Allocator,
    vma_allocator: vma.Allocator,
    gpu_allocator: ^gpua.VK_Allocator,
    mtx:           sync.Mutex,
}

@(private)
vk_deferred_init :: proc(
    self: ^VK_Deferred_Deletor,
    device: Device,
    vma_allocator: vma.Allocator,
    gpu_allocator: ^gpua.VK_Allocator,
    allocator: runtime.Allocator,
) {
    self.device = device
    self.vma_allocator = vma_allocator
    self.allocator = allocator
    self.gpu_allocator = gpu_allocator
    for &queue in self.queues {
        queue.allocator = allocator
    }
}

@(private)
vk_deferred_uninit :: proc(self: ^VK_Deferred_Deletor) {
    for &queue in self.queues {
        delete(queue)
    }
}

@(private)
vk_deferred_add_resource :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    resource: VK_Deferred_Resource,
    loc := #caller_location,
) {
    sync.lock(&self.mtx)
    wait_on := vk_submit_context_get_next_submit_handle(submitter)
    vk_deferred_add_resource_locked(self, resource, wait_on, loc)
}

// Releases a resource that was used by the submission named by `wait_on`. The
// next-submit heuristic above would pin a slot that may not have been submitted
// yet; the caller here knows the exact submission.
@(private)
vk_deferred_add_resource_after :: proc(
    self: ^VK_Deferred_Deletor,
    resource: VK_Deferred_Resource,
    wait_on: VK_Submit_Handle,
    loc := #caller_location,
) {
    ensure(wait_on != {}, "an explicit wait-on submission is required", loc)
    sync.lock(&self.mtx)
    vk_deferred_add_resource_locked(self, resource, wait_on, loc)
}

// Exclusive-lock body of both entry points.
@(private = "file")
vk_deferred_add_resource_locked :: proc(
    self: ^VK_Deferred_Deletor,
    resource: VK_Deferred_Resource,
    wait_on: VK_Submit_Handle,
    loc := #caller_location,
) {
    // Nothing has ever been submitted, so no queue work can reference the
    // resource: destroy it now instead of queueing a wait that can never run.
    if wait_on == {} {
        sync.unlock(&self.mtx)
        pending := VK_Deferred_Deletion {
            resource = resource,
        }
        vk_deferred_destroy_resource(self, &pending, loc)
        return
    }

    kind := vk_release_kind_for(resource)
    queue := &self.queues[int(kind)]
    append(queue, VK_Deferred_Deletion {
        wait_on  = wait_on,
        kind     = kind,
        resource = resource,
    })
    sync.unlock(&self.mtx)
}

@(private)
vk_deferred_destroy_buffer :: proc(
    self: ^VK_Deferred_Deletor,
    res: ^VK_Deferred_Buffer,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    buffer_init_tracker_free(&res.init)

    {
        sync.guard(&device_impl.trackers_mtx)
        device_buffer_tracker_forget(&device_impl.trackers.buffers, res.tracker_index)
    }
    shared_tracker_index_allocator_free(&device_impl.tracker_indices.buffers, res.tracker_index)

    when USE_VMA {
        vma.DestroyBuffer(self.vma_allocator, res.buffer, res.vma_allocation)
    } else {
        device_impl.fp.DestroyBuffer(device_impl.vk_device, res.buffer, nil)
        free_err := gpua.vk_allocator_free(self.gpu_allocator, &res.gpu_allocation)
        if free_err != .None {
            log.errorf("VULKAN: failed to free buffer allocation: %v", free_err, location = loc)
        }
    }
}

@(private = "file")
vk_deferred_destroy_image :: proc(
    self: ^VK_Deferred_Deletor,
    res: ^VK_Deferred_Image,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    texture_init_tracker_free(&res.init)

    {
        sync.guard(&device_impl.trackers_mtx)
        device_texture_tracker_forget(&device_impl.trackers.textures, res.tracker_index)
    }
    shared_tracker_index_allocator_free(&device_impl.tracker_indices.textures, res.tracker_index)

    when USE_VMA {
        #partial switch &allocation in res.allocation {
        case vma.Allocation:
            vma.DestroyImage(self.vma_allocator, res.image, allocation)
        case:
            unreachable()
        }
    } else {
        device_impl.fp.DestroyImage(device_impl.vk_device, res.image, nil)
        #partial switch &allocation in res.allocation {
        case gpua.VK_Allocation:
            free_err := gpua.vk_allocator_free(self.gpu_allocator, &allocation)
            if free_err != .None {
                log.errorf("VULKAN: failed to free image allocation: %v", free_err, location = loc)
            }
        case:
            unreachable()
        }
    }
}

@(private = "file")
vk_deferred_destroy_resource :: proc(
    self: ^VK_Deferred_Deletor,
    pending: ^VK_Deferred_Deletion,
    loc := #caller_location,
) {
    device_impl := vk_device_get_impl(self.device, loc)

    switch &res in pending.resource {
    case VK_Deferred_Buffer:
        vk_deferred_destroy_buffer(self, &res, loc)

    case VK_Deferred_Image:
        vk_deferred_destroy_image(self, &res, loc)

    case VK_Deferred_Descriptor_Set:
        vk_descriptor_allocator_free(res.descriptor, res.descriptor_set)

    case VK_Deferred_Sampler:
        vk_sampler_cache_destroy_sampler(res.cache, &res.create_info, res.sampler)

    case VK_Deferred_Query_Set:
        device_impl.fp.DestroyQueryPool(device_impl.vk_device, res.pool, nil)

    case VK_Deferred_Bind_Group_Layout:
        vk_descriptor_allocator_unregister_layout(res.allocator, res.layout, loc)
        device_impl.fp.DestroyDescriptorSetLayout(device_impl.vk_device, res.layout.raw, nil)

    case vk.ImageView:
        device_impl.fp.DestroyImageView(device_impl.vk_device, res, nil)

    case vk.Pipeline:
        device_impl.fp.DestroyPipeline(device_impl.vk_device, res, nil)

    case vk.Sampler:
        device_impl.fp.DestroySampler(device_impl.vk_device, res, nil)

    case vk.Framebuffer:
        device_impl.fp.DestroyFramebuffer(device_impl.vk_device, res, nil)

    case vk.RenderPass:
        device_impl.fp.DestroyRenderPass(device_impl.vk_device, res, nil)

    case vk.DescriptorSetLayout:
        device_impl.fp.DestroyDescriptorSetLayout(device_impl.vk_device, res, nil)

    case vk.PipelineLayout:
        device_impl.fp.DestroyPipelineLayout(device_impl.vk_device, res, nil)

    case VK_Deferred_Shader_Module:
        device_impl.fp.DestroyShaderModule(device_impl.vk_device, res.module, nil)
    }
}

VK_Deferred_Slot_State :: enum u8 {
    Unknown,
    Not_Ready,
    Ready,
}

@(optimization_mode = "favor_size")
@(private)
vk_deferred_process :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    loc := #caller_location,
) #no_bounds_check {
    sync.guard(&self.mtx)

    slot_state: [MAX_COMMAND_BUFFERS]VK_Deferred_Slot_State

    for &queue in self.queues {
        write_index := 0
        for read_index := 0; read_index < len(queue); read_index += 1 {
            pending := &queue[read_index]
            idx := pending.wait_on.buffer_index

            // Cheap path first: stale handle (slot already recycled onto a
            // newer submit_id) resolves without touching Vulkan at all.
            ready := vk_submit_context_is_ready(
                submitter,
                pending.wait_on,
                fast_check_no_vulkan = true,
                loc = loc,
            )
            if !ready {
                if slot_state[idx] == .Unknown {
                    slot_state[idx] =
                        (vk_submit_context_is_ready(submitter, pending.wait_on, loc = loc) ? .Ready : .Not_Ready)
                }
                ready = slot_state[idx] == .Ready
            }

            if ready {
                vk_deferred_destroy_resource(self, pending, loc)
                continue
            }

            if write_index != read_index {
                queue[write_index] = queue[read_index]
            }
            write_index += 1
        }

        resize(&queue, write_index)
    }
}

@(private)
vk_deferred_wait_and_process_all :: proc(
    self: ^VK_Deferred_Deletor,
    submitter: ^VK_Submit_Context,
    loc := #caller_location,
) {
    sync.guard(&self.mtx)

    for &queue in self.queues {
        for &pending in queue {
            vk_submit_context_wait(submitter, pending.wait_on, loc = loc)
            vk_deferred_destroy_resource(self, &pending, loc)
        }
        clear(&queue)
    }
}
