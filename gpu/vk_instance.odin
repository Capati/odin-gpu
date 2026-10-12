#+build !js
package gpu

// Core
import "base:runtime"
import "core:dynlib"
import "core:log"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

vk_set_procedures :: proc() {
    // Global procedures
    get_instance_features = vk_get_instance_features
    get_instance_limits   = vk_get_instance_limits
    has_instance_feature  = vk_has_instance_feature

    // Procedures of Adapter
    adapter_get_features  = vk_adapter_get_features
    adapter_get_info      = vk_adapter_get_info
    adapter_create_device = vk_adapter_create_device
    adapter_add_ref       = vk_adapter_add_ref
    adapter_release       = vk_adapter_release

    // Private procedures of Adapter
    adapter_get_public_impl             = vk_adapter_get_public_impl
    adapter_texture_format_capabilities = vk_adapter_texture_format_capabilities

    // Procedures of Bind_Group
    bind_group_get_public_impl = vk_bind_group_get_public_impl
    bind_group_set_label       = vk_bind_group_set_label
    bind_group_add_ref         = vk_bind_group_add_ref
    bind_group_release         = vk_bind_group_release

    // Procedures of Bind_Group_Layout
    bind_group_layout_get_public_impl = vk_bind_group_layout_get_public_impl
    bind_group_layout_set_label       = vk_bind_group_layout_set_label
    bind_group_layout_add_ref         = vk_bind_group_layout_add_ref
    bind_group_layout_release         = vk_bind_group_layout_release

    // Procedures of Buffer
    buffer_get_public_impl        = vk_buffer_get_public_impl
    buffer_destroy                = vk_buffer_destroy
    buffer_flush_mapped_ranges    = vk_buffer_flush_mapped_ranges
    buffer_get_const_mapped_range = vk_buffer_get_const_mapped_range
    buffer_get_map_state          = vk_buffer_get_map_state
    buffer_get_mapped_range       = vk_buffer_get_mapped_range
    buffer_get_size               = vk_buffer_get_size
    buffer_get_usage              = vk_buffer_get_usage
    buffer_is_coherent            = vk_buffer_is_coherent
    buffer_map_async              = vk_buffer_map_async
    buffer_map_sync               = vk_buffer_map_sync
    buffer_read_mapped_range      = vk_buffer_read_mapped_range
    buffer_set_label              = vk_buffer_set_label
    buffer_unmap                  = vk_buffer_unmap
    buffer_write_mapped_range     = vk_buffer_write_mapped_range
    buffer_add_ref                = vk_buffer_add_ref
    buffer_release                = vk_buffer_release

    // Reference-counting hooks used by the trackers to keep the resources they
    // hold alive. The tracker does not call `buffer_add_ref`/`buffer_release`
    // directly so it stays backend-agnostic and testable without a device.
    tracker_retain_buffer         = vk_buffer_add_ref
    tracker_release_buffer        = vk_buffer_release

    // Procedures of Command_Buffer
    command_buffer_set_label       = vk_command_buffer_set_label
    command_buffer_add_ref         = vk_command_buffer_add_ref
    command_buffer_release         = vk_command_buffer_release

    // @private procedures of Command_Buffer
    command_buffer_get_public_impl = vk_command_buffer_get_public_impl
    command_buffer_arena_allocator = vk_command_buffer_arena_allocator

    // Procedures of Command_Encoder
    command_encoder_begin_compute_pass      = vk_command_encoder_begin_compute_pass
    command_encoder_begin_render_pass       = vk_command_encoder_begin_render_pass
    command_encoder_clear_buffer            = vk_command_encoder_clear_buffer
    command_encoder_copy_buffer_to_buffer   = vk_command_encoder_copy_buffer_to_buffer
    command_encoder_copy_buffer_to_texture  = vk_command_encoder_copy_buffer_to_texture
    command_encoder_copy_texture_to_buffer  = vk_command_encoder_copy_texture_to_buffer
    command_encoder_copy_texture_to_texture = vk_command_encoder_copy_texture_to_texture
    command_encoder_finish                  = vk_command_encoder_finish
    command_encoder_insert_debug_marker     = vk_command_encoder_insert_debug_marker
    command_encoder_pop_debug_group         = vk_command_encoder_pop_debug_group
    command_encoder_push_debug_group        = vk_command_encoder_push_debug_group
    command_encoder_resolve_query_set       = vk_command_encoder_resolve_query_set
    command_encoder_set_label               = vk_command_encoder_set_label
    command_encoder_write_timestamp         = vk_command_encoder_write_timestamp
    command_encoder_add_ref                 = vk_command_encoder_add_ref
    command_encoder_release                 = vk_command_encoder_release

    // @private procedures of Command_Encoder
    command_encoder_get_public_impl = vk_command_encoder_get_public_impl

    // @private procedures of Command_Encoder
    command_encoder_arena_allocator         = vk_command_encoder_arena_allocator
    command_encoder_transition_buffers      = vk_command_encoder_transition_buffers

    // Procedures of Compute_Pass_Encoder
    compute_pass_dispatch_workgroups          = vk_compute_pass_dispatch_workgroups
    compute_pass_dispatch_workgroups_indirect = vk_compute_pass_dispatch_workgroups_indirect
    compute_pass_end                          = vk_compute_pass_end
    compute_pass_insert_debug_marker          = vk_compute_pass_insert_debug_marker
    compute_pass_pop_debug_group              = vk_compute_pass_pop_debug_group
    compute_pass_push_debug_group             = vk_compute_pass_push_debug_group
    compute_pass_set_bind_group               = vk_compute_pass_set_bind_group
    compute_pass_set_immediates               = vk_compute_pass_set_immediates
    compute_pass_set_label                    = vk_compute_pass_set_label
    compute_pass_set_pipeline                 = vk_compute_pass_set_pipeline
    compute_pass_add_ref                      = vk_compute_pass_add_ref
    compute_pass_release                      = vk_compute_pass_release

    // Procedures of Compute_Pipeline
    compute_pipeline_get_bind_group_layout = vk_compute_pipeline_get_bind_group_layout
    compute_pipeline_set_label             = vk_compute_pipeline_set_label
    compute_pipeline_add_ref               = vk_compute_pipeline_add_ref
    compute_pipeline_release               = vk_compute_pipeline_release

    // Procedures of Device
    device_get_public_impl               = vk_device_get_public_impl
    device_create_bind_group        = vk_device_create_bind_group
    device_create_bind_group_layout      = vk_device_create_bind_group_layout
    device_create_buffer            = vk_device_create_buffer
    device_create_command_encoder        = vk_device_create_command_encoder
    device_create_compute_pipeline       = vk_device_create_compute_pipeline
    device_create_compute_pipeline_async = vk_device_create_compute_pipeline_async
    device_create_pipeline_layout        = vk_device_create_pipeline_layout
    device_create_query_set              = vk_device_create_query_set
    device_create_render_bundle_encoder  = vk_device_create_render_bundle_encoder
    device_create_render_pipeline        = vk_device_create_render_pipeline
    device_create_render_pipeline_async  = vk_device_create_render_pipeline_async
    device_create_sampler                = vk_device_create_sampler
    device_create_shader_module          = vk_device_create_shader_module
    device_create_texture                = vk_device_create_texture
    device_destroy                       = vk_device_destroy
    device_get_adapter_info              = vk_device_get_adapter_info
    device_get_lost_future               = vk_device_get_lost_future
    device_get_queue                     = vk_device_get_queue
    device_pop_error_scope               = vk_device_pop_error_scope
    device_push_error_scope              = vk_device_push_error_scope
    device_backend = vk_device_backend
    device_is_embedded = vk_device_is_embedded
    device_set_label                     = vk_device_set_label
    device_add_ref                       = vk_device_add_ref
    device_release                       = vk_device_release

    // Procedures of External_Texture
    external_texture_set_label = vk_external_texture_set_label
    external_texture_add_ref   = vk_external_texture_add_ref
    external_texture_release   = vk_external_texture_release

    // Procedures of Instance
    instance_create_surface             = vk_instance_create_surface
    instance_get_wgsl_language_features = vk_instance_get_wgsl_language_features
    instance_has_wgsl_language_feature  = vk_instance_has_wgsl_language_feature
    instance_process_events             = vk_instance_process_events
    instance_create_adapter             = vk_instance_create_adapter
    instance_wait_any                   = vk_instance_wait_any
    instance_add_ref                    = vk_instance_add_ref
    instance_release                    = vk_instance_release

    // @private procedures of Instance
    instance_get_public_impl = vk_instance_get_public_impl

    // Procedures of Pipeline_Layout
    pipeline_layout_set_label = vk_pipeline_layout_set_label
    pipeline_layout_add_ref   = vk_pipeline_layout_add_ref
    pipeline_layout_release   = vk_pipeline_layout_release

    // Procedures of Query_Set
    query_set_destroy   = vk_query_set_destroy
    query_set_get_count = vk_query_set_get_count
    query_set_get_type  = vk_query_set_get_type
    query_set_set_label = vk_query_set_set_label
    query_set_add_ref   = vk_query_set_add_ref
    query_set_release   = vk_query_set_release

    // Procedures of Queue
    queue_on_submitted_work_done = vk_queue_on_submitted_work_done
    queue_set_label              = vk_queue_set_label
    queue_submit                 = vk_queue_submit
    queue_write_buffer_raw       = resolve_queue_write_buffer
    queue_write_texture          = vk_queue_write_texture
    queue_add_ref                = vk_queue_add_ref
    queue_release                = vk_queue_release

    // @private procedures of Queue
    queue_get_public_impl = vk_queue_get_public_impl

    // Procedures of Render_Bundle
    render_bundle_set_label = vk_render_bundle_set_label
    render_bundle_add_ref   = vk_render_bundle_add_ref
    render_bundle_release   = vk_render_bundle_release

    // Procedures of Render_Bundle_Encoder
    render_bundle_encoder_draw                  = vk_render_bundle_encoder_draw
    render_bundle_encoder_draw_indexed          = vk_render_bundle_encoder_draw_indexed
    render_bundle_encoder_draw_indexed_indirect = vk_render_bundle_encoder_draw_indexed_indirect
    render_bundle_encoder_draw_indirect         = vk_render_bundle_encoder_draw_indirect
    render_bundle_encoder_finish                = vk_render_bundle_encoder_finish
    render_bundle_encoder_insert_debug_marker   = vk_render_bundle_encoder_insert_debug_marker
    render_bundle_encoder_pop_debug_group       = vk_render_bundle_encoder_pop_debug_group
    render_bundle_encoder_push_debug_group      = vk_render_bundle_encoder_push_debug_group
    render_bundle_encoder_set_bind_group        = vk_render_bundle_encoder_set_bind_group
    render_bundle_encoder_set_immediates        = vk_render_bundle_encoder_set_immediates
    render_bundle_encoder_set_index_buffer      = vk_render_bundle_encoder_set_index_buffer
    render_bundle_encoder_set_label             = vk_render_bundle_encoder_set_label
    render_bundle_encoder_set_pipeline          = vk_render_bundle_encoder_set_pipeline
    render_bundle_encoder_set_vertex_buffer     = vk_render_bundle_encoder_set_vertex_buffer
    render_bundle_encoder_add_ref               = vk_render_bundle_encoder_add_ref
    render_bundle_encoder_release               = vk_render_bundle_encoder_release

    // Procedures of Render_Pass_Encoder
    render_pass_begin_occlusion_query = vk_render_pass_begin_occlusion_query
    render_pass_draw                  = vk_render_pass_draw
    render_pass_draw_indexed          = vk_render_pass_draw_indexed
    render_pass_draw_indexed_indirect = vk_render_pass_draw_indexed_indirect
    render_pass_draw_indirect         = vk_render_pass_draw_indirect
    render_pass_end                   = vk_render_pass_end
    render_pass_end_occlusion_query   = vk_render_pass_end_occlusion_query
    render_pass_execute_bundles       = vk_render_pass_execute_bundles
    render_pass_insert_debug_marker   = vk_render_pass_insert_debug_marker
    render_pass_pop_debug_group       = vk_render_pass_pop_debug_group
    render_pass_push_debug_group      = vk_render_pass_push_debug_group
    render_pass_set_bind_group        = vk_render_pass_set_bind_group
    render_pass_set_blend_constant    = vk_render_pass_set_blend_constant
    render_pass_set_immediates        = vk_render_pass_set_immediates
    render_pass_set_index_buffer      = vk_render_pass_set_index_buffer
    render_pass_set_label             = vk_render_pass_set_label
    render_pass_set_pipeline          = vk_render_pass_set_pipeline
    render_pass_set_scissor_rect      = vk_render_pass_set_scissor_rect
    render_pass_set_stencil_reference = vk_render_pass_set_stencil_reference
    render_pass_set_vertex_buffer     = vk_render_pass_set_vertex_buffer
    render_pass_set_viewport          = vk_render_pass_set_viewport
    render_pass_add_ref               = vk_render_pass_add_ref
    render_pass_release               = vk_render_pass_release

    // @private procedures of Render_Pass
    render_pass_get_public_impl = vk_render_pass_get_public_impl

    // Procedures of Render_Pipeline
    render_pipeline_get_bind_group_layout = vk_render_pipeline_get_bind_group_layout
    render_pipeline_set_label             = vk_render_pipeline_set_label
    render_pipeline_add_ref               = vk_render_pipeline_add_ref
    render_pipeline_release               = vk_render_pipeline_release

    // Procedures of Sampler
    sampler_set_label = vk_sampler_set_label
    sampler_add_ref   = vk_sampler_add_ref
    sampler_release   = vk_sampler_release

    // Procedures of Shader_Module
    shader_module_get_compilation_info = vk_shader_module_get_compilation_info
    shader_module_set_label            = vk_shader_module_set_label
    shader_module_add_ref              = vk_shader_module_add_ref
    shader_module_release              = vk_shader_module_release

    // Procedures of Supported_Features
    supported_features_free_members = vk_supported_features_free_members

    // Procedures of Supported_Instance_Features
    supported_instance_features_free_members = vk_supported_instance_features_free_members

    // Procedures of Supported_WGSL_Language_Features
    supported_wgsl_language_features_free_members =
        vk_supported_wgsl_language_features_free_members

    // Procedures of Surface
    surface_configure                 = vk_surface_configure
    surface_get_capabilities          = vk_surface_get_capabilities
    surface_capabilities_free_members = vk_surface_capabilities_free_members
    surface_get_current_texture       = vk_surface_get_current_texture
    surface_present                   = vk_surface_present
    surface_set_label                 = vk_surface_set_label
    surface_unconfigure               = vk_surface_unconfigure
    surface_add_ref                   = vk_surface_add_ref
    surface_release                   = vk_surface_release

    // Procedures of Surface_Texture
    surface_texture_present = vk_surface_texture_present

    // Procedures of Texture
    texture_create_view               = vk_texture_create_view
    texture_destroy                   = vk_texture_destroy
    texture_get_depth_or_array_layers = vk_texture_get_depth_or_array_layers
    texture_get_descriptor            = vk_texture_get_descriptor
    texture_get_dimension             = vk_texture_get_dimension
    texture_get_format                = vk_texture_get_format
    texture_get_height                = vk_texture_get_height
    texture_get_mip_level_count       = vk_texture_get_mip_level_count
    texture_get_sample_count          = vk_texture_get_sample_count
    texture_get_size                  = vk_texture_get_size
    texture_get_usage                 = vk_texture_get_usage
    texture_get_width                 = vk_texture_get_width
    texture_set_label                 = vk_texture_set_label
    texture_add_ref                   = vk_texture_add_ref
    texture_release                   = vk_texture_release

    // @private procedures of Texture
    texture_get_public_impl = vk_texture_get_public_impl

    // Procedures of Texture_View
    texture_view_set_label       = vk_texture_view_set_label
    texture_view_add_ref         = vk_texture_view_add_ref
    texture_view_release         = vk_texture_view_release

    // Tracker hooks, see `tracker_retain_buffer` in gpu/tracker.odin.
    tracker_retain_texture       = vk_tracker_texture_add_ref
    tracker_release_texture      = vk_tracker_texture_release
    tracker_retain_texture_view  = vk_tracker_texture_view_add_ref
    tracker_release_texture_view = vk_tracker_texture_view_release

    // @private procedures of Texture_View
    texture_view_get_public_impl = vk_texture_view_get_public_impl
}

// Default validations
VK_VALIDATION_LAYER_NAME :: "VK_LAYER_KHRONOS_validation"

VK_Library :: struct {
    proc_addr: vk.ProcGetInstanceProcAddr,
    library:   dynlib.Library,
    ref:       Ref_Count_Type,
    loaded:    bool,
}

VK_Library_State :: enum u8 {
    Init,
    Uninit,
}

vk_initialization :: proc(
    state: VK_Library_State,
    proc_addr: vk.ProcGetInstanceProcAddr = nil,
) -> vk.Result {
    @(static) lib: VK_Library

    switch state {
    case .Uninit:
        if lib.loaded {
            if unload := release_ref(&lib); unload {
                dynlib.unload_library(lib.library)
                lib.loaded = false
            }
        }
        return .SUCCESS
    case .Init:
        init_ref(&lib)
    // falls through to load logic below
    }

    if proc_addr != nil {
        lib.proc_addr = proc_addr
    } else if !lib.loaded {
        when ODIN_OS == .Windows {
            lib.library, lib.loaded = dynlib.load_library("vulkan-1.dll")
        } else when ODIN_OS == .Darwin {
            lib.library, lib.loaded = dynlib.load_library("libvulkan.dylib")
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libvulkan.1.dylib")
            }
            // modern versions of macOS don't search /usr/local/lib automatically contrary to
            // what man dlopen says Vulkan SDK uses this as the system-wide installation
            // location, so we're going to fallback to this if all else fails
            if !lib.loaded {
                _, found_lib_path := os.lookup_env(
                    "DYLD_FALLBACK_LIBRARY_PATH",
                    context.temp_allocator,
                )
                if !found_lib_path {
                    lib.library, lib.loaded = dynlib.load_library("/usr/local/lib/libvulkan.dylib")
                }
            }
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libMoltenVK.dylib")
            }
            // store rules for iOS strictly enforce no .dylib's. If they aren't
            // found it just falls through
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("vulkan.framework/vulkan")
            }
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("MoltenVK.framework/MoltenVK")
            }
        } else {
            lib.library, lib.loaded = dynlib.load_library("libvulkan.so.1")
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libvulkan.so")
            }
        }

        if !lib.loaded {
            log.error("Vulkan: Failed to load the library")
            return .ERROR_INITIALIZATION_FAILED
        }

        INSTANCE_PROC_ADDR_STR :: "vkGetInstanceProcAddr"
        if fp, found := dynlib.symbol_address(lib.library, INSTANCE_PROC_ADDR_STR); found {
            lib.proc_addr = vk.ProcGetInstanceProcAddr(fp)
        } else {
            log.error("Vulkan: Failed to get symbol address " + INSTANCE_PROC_ADDR_STR)
            return .ERROR_INITIALIZATION_FAILED
        }
    }

    // Load the base Vulkan procedures before we can start using them
    vk.load_proc_addresses_global(auto_cast lib.proc_addr)
    if vk.CreateInstance == nil {
        log.error("Vulkan: Failed to load proc addresses global")
        return .ERROR_INITIALIZATION_FAILED
    }

    return .SUCCESS
}

vk_create_instance :: proc(
    allocator: runtime.Allocator,
    descriptor: Instance_Descriptor = {},
    loc := #caller_location,
) -> (
    out: Instance,
) {
    // Alias to the temporary allocator
    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    // Vulkan backend options
    options := descriptor.backend_options.vulkan

    // Get the vkGetInstanceProcAddr or null
    get_instance_proc_addr: vk.ProcGetInstanceProcAddr
    if options.get_instance_proc_addr != nil {
        get_instance_proc_addr = auto_cast options.get_instance_proc_addr
    }

    // Init the Vulkan library using the instance options
    if vk_initialization(.Init, get_instance_proc_addr) != .SUCCESS {
        return nil
    }

    impl := new_clone(VK_Instance_Impl{
        ctx               = context,
        allocator         = context.allocator,
        flags             = descriptor.flags,
        current_future_id = 1,
        backend           = .Vulkan,
        is_embedded       = false,
    }, allocator)
    init_ref(impl)
    defer if out == nil { free(impl, allocator) }

    impl.pending_futures.allocator = impl.allocator

    // Query the highest Vulkan instance version supported by the
    // implementation. Vulkan 1.0 implementations may not expose
    // vk.EnumerateInstanceVersion.
    impl.instance_version = vk.API_VERSION_1_0

    if vk.EnumerateInstanceVersion != nil {
        if vk.EnumerateInstanceVersion(&impl.instance_version) != .SUCCESS {
            impl.instance_version = vk.API_VERSION_1_0
        }
    }

    // We only require Vulkan 1.0, but prefer Vulkan 1.3 when available
    impl.instance_version = min(impl.instance_version, vk.API_VERSION_1_3)

    // Query instance layers
    layer_count: u32
    vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, nil))
    layer_properties := make([dynamic]vk.LayerProperties, layer_count, ta)
    vk_check(vk.EnumerateInstanceLayerProperties(&layer_count, raw_data(layer_properties)))

    // Check if validation layer is enabled
    validation_layer_available :=
        vk_has_layer_property(layer_properties[:], VK_VALIDATION_LAYER_NAME)

    // Query instance extensions
    extension_count: u32
    vk_check(vk.EnumerateInstanceExtensionProperties(nil, &extension_count, nil))
    instance_extensions := make([dynamic]vk.ExtensionProperties, extension_count, ta)
    vk_check(vk.EnumerateInstanceExtensionProperties(
        nil, &extension_count, raw_data(instance_extensions)))

    // Determine if VK_EXT_validation_features is available, so we can enable
    // GPU assisted validation and synchronization validation.
    validation_features_available: bool

    // Get all the instance extension properties from the validation layer
    if validation_layer_available {
        property_count: u32
        vk_check(vk.EnumerateInstanceExtensionProperties(
            VK_VALIDATION_LAYER_NAME, &property_count, nil))
        if property_count > 0 {
            exts := make([]vk.ExtensionProperties, property_count, ta)
            vk_check(vk.EnumerateInstanceExtensionProperties(
                VK_VALIDATION_LAYER_NAME, &property_count, raw_data(exts)))
            for &layer_ext in exts {
                // Check for duplicates before the append
                ext_name := byte_arr_str(&layer_ext.extensionName)
                if vk_has_extension(instance_extensions, ext_name) {
                    continue
                }
                append(&instance_extensions, layer_ext)
            }
        }

        validation_features_available = vk_has_extension(
            instance_extensions, vk.EXT_VALIDATION_FEATURES_EXTENSION_NAME)
    }

    // Required instance extensions to enable
    extensions := make([dynamic]cstring, ta)

    // VK_KHR_surface
    if vk_has_extension(instance_extensions, vk.KHR_SURFACE_EXTENSION_NAME) {
        append(&extensions, vk.KHR_SURFACE_EXTENSION_NAME)
    }

    has_portability_enumeration: bool

    // Platform-specific WSI extensions
    when ODIN_OS == .Linux {
        // VK_KHR_xlib_surface
        if vk_has_extension(instance_extensions, vk.KHR_XLIB_SURFACE_EXTENSION_NAME) {
            append(&extensions, vk.KHR_XLIB_SURFACE_EXTENSION_NAME)
        }
        // VK_KHR_xcb_surface
        if vk_has_extension(instance_extensions, vk.KHR_XCB_SURFACE_EXTENSION_NAME) {
            append(&extensions, vk.KHR_XCB_SURFACE_EXTENSION_NAME)
        }
        // VK_KHR_wayland_surface
        if vk_has_extension(instance_extensions, vk.KHR_WAYLAND_SURFACE_EXTENSION_NAME) {
            append(&extensions, vk.KHR_WAYLAND_SURFACE_EXTENSION_NAME)
        }
    } else when ODIN_OS == .Windows {
        // VK_KHR_win32_surface
        if vk_has_extension(instance_extensions, vk.KHR_WIN32_SURFACE_EXTENSION_NAME) {
            append(&extensions, vk.KHR_WIN32_SURFACE_EXTENSION_NAME)
        }
    } else when ODIN_OS == .Darwin {
        // VK_EXT_metal_surface
        if vk_has_extension(instance_extensions, vk.EXT_METAL_SURFACE_EXTENSION_NAME) {
            append(&extensions, vk.EXT_METAL_SURFACE_EXTENSION_NAME)
        }
        // VK_KHR_portability_enumeration
        if vk_has_extension(instance_extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) {
            has_portability_enumeration = true
            append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
        }
    }

    debug_utils_enabled := .Debug in descriptor.flags && vk_has_extension(
        instance_extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

    // VK_EXT_debug_utils
    if debug_utils_enabled {
        append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)
    }

    // VK_EXT_swapchain_colorspace for wide color gamut
    if vk_has_extension(instance_extensions, vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME) {
        append(&extensions, vk.EXT_SWAPCHAIN_COLOR_SPACE_EXTENSION_NAME)
    }

    // VK_KHR_get_physical_device_properties2
    if vk_has_extension(instance_extensions,
            vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME) {
        append(&extensions, vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME)
    }

    // Required instance layers to enable
    layers := make([dynamic]cstring, ta)

    // Request validation layer if asked.
    if .Validation in descriptor.flags {
        if validation_layer_available {
            append(&layers, VK_VALIDATION_LAYER_NAME)
        } else {
            log.warn("VULKAN: validation layer [%s] requested but not available on this system",
                VK_VALIDATION_LAYER_NAME)
            log.warn("VULKAN: install the Vulkan SDK to enable validation:\n\t" +
                "https://vulkan.lunarg.com/sdk/home")
            log.warn("VULKAN: ignoring validation layers...")
        }
    }

    flags: vk.InstanceCreateFlags

    // Only ask the instance to enumerate incomplete Vulkan implementations
    // (which we need on Mac) if we managed to find the extension that provides
    // the flag.
    if has_portability_enumeration {
        flags |= {.ENUMERATE_PORTABILITY_KHR}
    }

    app_info := vk.ApplicationInfo {
        sType              = .APPLICATION_INFO,
        pApplicationName   = "Odin/Vulkan",
        applicationVersion = vk.MAKE_VERSION(1, 0, 0),
        pEngineName        = "Odin/Vulkan",
        engineVersion      = vk.MAKE_VERSION(1, 0, 0),
        apiVersion         = impl.instance_version,
    }

    create_info := vk.InstanceCreateInfo {
        sType                   = .INSTANCE_CREATE_INFO,
        flags                   = flags,
        pApplicationInfo        = &app_info,
        enabledLayerCount       = u32(len(layers)),
        ppEnabledLayerNames     = raw_data(layers),
        enabledExtensionCount   = u32(len(extensions)),
        ppEnabledExtensionNames = raw_data(extensions),
    }

    pnext_chain := make([dynamic]^vk.BaseOutStructure, ta)

    dbg_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
        sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
    }
    if debug_utils_enabled {
        severity : vk.DebugUtilsMessageSeverityFlagsEXT = {.ERROR}

        // `log.Level` is ordered least-verbose-first (.Debug is the lowest
        // value), so a more verbose logger must compare `<=`, not `>=`.
        log_priority := context.logger.lowest_level

        if log_priority <= .Debug { severity |= {.VERBOSE} }
        if log_priority <= .Info { severity |= {.INFO} }
        if log_priority <= .Warning { severity |= {.WARNING} }

        dbg_create_info.messageSeverity = severity
        dbg_create_info.messageType = {.GENERAL, .VALIDATION, .PERFORMANCE}
        dbg_create_info.pfnUserCallback = vk_debug_callback
        dbg_create_info.pUserData = impl

        append(&pnext_chain, cast(^vk.BaseOutStructure)&dbg_create_info)
    }

    validation_features_list: [dynamic; 3]vk.ValidationFeatureEnableEXT

    validation_features := vk.ValidationFeaturesEXT {
        sType = .VALIDATION_FEATURES_EXT,
    }
    if validation_features_available {
        // Always enable synchronization validation
        append(&validation_features_list,
            vk.ValidationFeatureEnableEXT.SYNCHRONIZATION_VALIDATION)

        // Only enable GPU assisted validation if requested
        if .GPU_Based_Validation in descriptor.flags {
            append(&validation_features_list,
                vk.ValidationFeatureEnableEXT.GPU_ASSISTED)
            append(&validation_features_list,
                vk.ValidationFeatureEnableEXT.GPU_ASSISTED_RESERVE_BINDING_SLOT)
        }

        validation_features.enabledValidationFeatureCount = u32(len(validation_features_list))
        validation_features.pEnabledValidationFeatures = raw_data(validation_features_list[:])

        append(&pnext_chain, cast(^vk.BaseOutStructure)&validation_features)
    }

    vk_setup_pnext_chain(&create_info, pnext_chain[:])

    // Create the Vulkan Instance
    if res := vk.CreateInstance(&create_info, nil, &impl.vk_instance); res != .SUCCESS {
        log.errorf("Vulkan: vk.CreateInstance failed: %v", res)
        return nil
    }

    // Load instance-level functions
    vk.load_proc_addresses_instance(impl.vk_instance)

    if debug_utils_enabled {
        vk_check(vk.CreateDebugUtilsMessengerEXT(
            impl.vk_instance, &dbg_create_info, nil, &impl.vk_debug_messenger))
    }

    // Set backend procedures
    vk_set_procedures()

    out = Instance(impl)

    return
}

vk_get_instance_features :: proc(loc := #caller_location) -> Instance_Features {
    // supports all instance features
    return {.Timed_Wait_Any, .Shader_Source_SPIRV, .Multiple_Devices_Per_Adapter}
}

vk_get_instance_limits :: proc(loc := #caller_location) -> (limits: Instance_Limits) {
    limits.timed_wait_any_max_count = max(uint) // unlimited
    return
}

vk_has_instance_feature :: proc(feature: Instance_Feature_Name, loc := #caller_location) -> bool {
    return true // supports all instance features
}

vk_get_version :: proc(loc := #caller_location) -> u32 {
    unimplemented(loc = loc)
}

VK_Instance_Impl :: struct {
    // base #subtype
    using base:                   Instance_Impl,

    // Backend
    pending_futures:              map[u64]Future_Impl,
    future_mtx:                   sync.Mutex,
    vk_instance:                  vk.Instance,
    vk_debug_messenger:           vk.DebugUtilsMessengerEXT,
    current_future_id:            u64,
    instance_version:             u32,
    khr_validation_version:       u32,
    has_mvk_macos_surface:        bool,
    validation_layers_available:  bool,
    debug_utils_available:        bool,
    has_ext_swapchain_colorspace: bool,
}

@(require_results)
vk_instance_get_public_impl :: #force_inline proc "contextless" (
    instance: Instance,
    loc := #caller_location,
) -> ^Instance_Impl {
    return vk_instance_get_impl(instance, loc)
}

@(require_results)
vk_instance_get_impl :: #force_inline proc "contextless" (
    instance: Instance,
    loc := #caller_location,
) -> ^VK_Instance_Impl {
    assert_contextless(instance != nil, "invalid instance", loc)
    return cast(^VK_Instance_Impl)instance
}

vk_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    impl := vk_instance_get_impl(instance, loc)

    vk_surface: vk.SurfaceKHR

    when ODIN_OS == .Linux {
        #partial switch source in descriptor.source {
        case Surface_Source_Wayland_Surface:
            assert(source.surface != nil, "VULKAN: Invalid Wayland surface", loc)
            assert(source.display != nil, "VULKAN: Invalid Wayland display", loc)
            ci := vk.WaylandSurfaceCreateInfoKHR {
                sType = .WAYLAND_SURFACE_CREATE_INFO_KHR,
                surface = auto_cast source.surface,
                display = auto_cast source.display,
            }
            vk_check(vk.CreateWaylandSurfaceKHR(impl.vk_instance, &ci, nil, &vk_surface))
        case Surface_Source_XCB_Window:
            assert(source.connection != nil, "VULKAN: Invalid XCB connection", loc)
            assert(source.window != 0, "VULKAN: Invalid XCB window", loc)
            ci := vk.XcbSurfaceCreateInfoKHR {
                sType = .XCB_SURFACE_CREATE_INFO_KHR,
                connection = auto_cast source.connection,
                window = auto_cast source.window,
            }
            vk_check(vk.CreateXcbSurfaceKHR(impl.vk_instance, &ci, nil, &vk_surface))
        case Surface_Source_Xlib_Window:
            assert(source.display != nil, "VULKAN: Invalid Xlib display", loc)
            assert(source.window != 0, "VULKAN: Invalid Xlib window", loc)
            ci := vk.XlibSurfaceCreateInfoKHR {
                sType = .XLIB_SURFACE_CREATE_INFO_KHR,
                dpy = auto_cast source.display,
                window = auto_cast source.window,
            }
            vk_check(vk.CreateXlibSurfaceKHR(impl.vk_instance, &ci, nil, &vk_surface))
        case:
            panic("VULKAN: Invalid surface source for Linux", loc)
        }
    } else when ODIN_OS == .Windows {
        #partial switch source in descriptor.source {
        case Surface_Source_Windows_HWND:
            assert(source.hwnd != nil, "VULKAN: Invalid Windows HWND", loc)
            ci := vk.Win32SurfaceCreateInfoKHR {
                sType = .WIN32_SURFACE_CREATE_INFO_KHR,
                hinstance = auto_cast source.hinstance,
                hwnd = auto_cast source.hwnd,
            }
            vk_check(vk.CreateWin32SurfaceKHR(impl.vk_instance, &ci, nil, &vk_surface))
        case:
            panic("VULKAN: Invalid surface source for Windows", loc)
        }
    } else when ODIN_OS == .Darwin {
        #partial switch source in descriptor.source {
        case Surface_Source_Metal_Layer:
            assert(source.layer != nil, "VULKAN: Invalid Darwin metal layer", loc)
            ci := vk.MetalSurfaceCreateInfoEXT {
                sType = .METAL_SURFACE_CREATE_INFO_EXT,
                pLayer = auto_cast source.layer,
            }
            vk_check(vk.CreateMetalSurfaceEXT(impl.vk_instance, &ci, nil, &vk_surface))
        case:
            panic("VULKAN: Invalid surface source for Darwin", loc)
        }
    } else {
        #panic("VULKAN: Unsupported platform")
    }

    assert(vk_surface != {}, "VULKAN: Failed to create vk.SurfaceKHR", loc)

    surface_impl := new_clone(VK_Surface_Impl{
        instance   = instance,
        allocator  = impl.allocator,
        vk_surface = vk_surface,
        get_next_image = true,
    }, impl.allocator)
    init_ref(surface_impl)
    vk_instance_add_ref(instance, loc)

    return Surface(surface_impl)
}

vk_instance_get_wgsl_language_features :: proc(
    instance: Instance,
    loc := #caller_location,
) -> Supported_WGSL_Language_Features {
    unimplemented(loc = loc)
}

vk_instance_has_wgsl_language_feature :: proc(
    instance: Instance,
    feature: WGSL_Language_Feature_Name,
    loc := #caller_location,
) -> bool {
    unimplemented(loc = loc)
}

vk_instance_process_events :: proc(instance: Instance, loc := #caller_location) {
    unimplemented(loc = loc)
}

VK_Request_Adapter_Info :: struct {
    instance:      ^VK_Instance_Impl,
    options:       Request_Adapter_Options,
    callback_info: Request_Adapter_Callback_Info,
}

vk_instance_create_adapter :: proc(
    instance: Instance,
    options: Request_Adapter_Options = {},
    loc := #caller_location,
) -> Adapter {
    impl := vk_instance_get_impl(instance, loc)

    rate_physical_device :: proc(pd: vk.PhysicalDevice, options: Request_Adapter_Options) -> u32 {
        properties: vk.PhysicalDeviceProperties
        vk.GetPhysicalDeviceProperties(pd, &properties)

        score: u32 = 1

        // Rate the preferred device type
        if options.force_fallback_adapter {
            // Force software/CPU renderer: lowest priority device type
            if properties.deviceType != .CPU {
                return 0
            }
        } else {
            #partial switch options.power_preference {
            case .High_Performance:
                #partial switch properties.deviceType {
                case .DISCRETE_GPU:   score += 1000
                case .INTEGRATED_GPU: score += 100
                case .VIRTUAL_GPU:    score += 50
                case .CPU:            score += 10
                case:                 score += 1
                }
            case .Low_Power:
                switch properties.deviceType {
                case .INTEGRATED_GPU: score += 1000
                case .VIRTUAL_GPU:    score += 100
                case .CPU:            score += 50
                case .DISCRETE_GPU:   score += 10
                case .OTHER:          score += 1
                }
            case:
                // No preference, just pick discrete over integrated, no strong bias
                if properties.deviceType == .DISCRETE_GPU {score += 100}
                if properties.deviceType == .INTEGRATED_GPU {score += 50}
            }
        }

        score += properties.limits.maxImageDimension2D

        return score
    }

    ta := default_temp_allocator()
    DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

    device_count: u32
    res := vk.EnumeratePhysicalDevices(impl.vk_instance, &device_count, nil)
    if res != .SUCCESS {
        log.errorf("vk.EnumeratePhysicalDevices failed: %v", res)
        return {}
    }
    physical_devices := make([]vk.PhysicalDevice, device_count, ta)
    res = vk.EnumeratePhysicalDevices(impl.vk_instance, &device_count, raw_data(physical_devices))
    if res != .SUCCESS {
        log.errorf("vk.EnumeratePhysicalDevices failed: %v", res)
        return {}
    }

    suitable_device: VK_Adapter_Impl
    has_suitable_device := false
    best_score: u32

    for pd in physical_devices {
        adapter, adapter_ok := vk_create_adapter(pd, instance, options.compatible_surface)
        if !adapter_ok {
            continue
        }

        score := rate_physical_device(pd, options)
        if score > best_score || !has_suitable_device {
            if has_suitable_device {
                vk_adapter_release_internal(&suitable_device) // free the previous best
            }
            best_score = score
            suitable_device = adapter
            has_suitable_device = true
        } else {
            vk_adapter_release_internal(&adapter) // free this losing candidate immediately
        }
    }

    if !has_suitable_device {
        log.error("No suitable adapter found")
        return {}
    }

    adapter_impl := new_clone(suitable_device, impl.allocator)
    init_ref(adapter_impl)
    vk_instance_add_ref(instance, loc)

    // Success
    return Adapter(adapter_impl)
}

vk_instance_wait_any :: proc(
    instance: Instance,
    futures: []^Future_Wait_Info,
    timeout_ns: u64 = max(u64),
    loc := #caller_location,
) -> Wait_Status {
    impl := vk_instance_get_impl(instance, loc)

    sync.guard(&impl.future_mtx)

    for f in futures {
        assert(f != {}, "Invalid future", loc)
        if f.completed {continue}
        id := f.future.id
        if pending, ok := impl.pending_futures[id]; ok {
            if pending.resolve != nil {
                pending.resolve(pending.userdata)
            }
            delete_key(&impl.pending_futures, id)
        }
        f.completed = true
    }

    return .Success
}

vk_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    impl := vk_instance_get_impl(instance, loc)
    add_ref(impl, loc)
}

vk_instance_release :: proc(instance: Instance, loc := #caller_location) {
    impl := vk_instance_get_impl(instance, loc)
    if release_ref(impl, loc) {
        context.allocator = impl.allocator

        if len(impl.pending_futures) > 0 {
            log.warnf("Leaked [%d] pending futures", len(impl.pending_futures))
        }
        delete(impl.pending_futures)

        if impl.vk_debug_messenger != {} {
            vk.DestroyDebugUtilsMessengerEXT(impl.vk_instance, impl.vk_debug_messenger, nil)
        }
        vk.DestroyInstance(impl.vk_instance, nil)

        vk_initialization(.Uninit)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Procedures of Supported_Instance_Features
// -----------------------------------------------------------------------------

vk_supported_instance_features_free_members :: proc(
    features: []Instance_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    delete(features, allocator)
}

// -----------------------------------------------------------------------------
// Procedures of Supported_WGSL_Language_Features
// -----------------------------------------------------------------------------

vk_supported_wgsl_language_features_free_members :: proc(
    features: []WGSL_Language_Feature_Name,
    allocator := context.allocator,
    loc := #caller_location,
) {
    delete(features, allocator)
}
