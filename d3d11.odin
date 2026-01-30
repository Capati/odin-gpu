#+build windows
package gpu

// Core
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:slice"
import "core:strings"
import sa "core:container/small_array"
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/d3d11"
import "vendor:directx/dxgi"
import "vendor:directx/d3d_compiler"

D3D11_LOGIC_OP :: enum i32 {
    CLEAR,
    SET,
    COPY,
    COPY_INVERTED,
    NOOP,
    INVERT,
    AND,
    NAND,
    OR,
    NOR,
    XOR,
    EQUIV,
    AND_REVERSE,
    AND_INVERTED,
    OR_REVERSE,
    OR_INVERTED,
}

D3D11_RENDER_TARGET_BLEND_DESC1 :: struct {
    BlendEnable:           win32.BOOL,
    LogicOpEnable:         win32.BOOL,
    SrcBlend:              d3d11.BLEND,
    DestBlend:             d3d11.BLEND,
    BlendOp:               d3d11.BLEND_OP,
    SrcBlendAlpha:         d3d11.BLEND,
    DestBlendAlpha:        d3d11.BLEND,
    BlendOpAlpha:          d3d11.BLEND_OP,
    LogicOp:               D3D11_LOGIC_OP,
    RenderTargetWriteMask: win32.UINT8,
}

D3D11_BLEND_DESC1 :: struct {
    AlphaToCoverageEnable:  win32.BOOL,
    IndependentBlendEnable: win32.BOOL,
    RenderTarget:           [8]D3D11_RENDER_TARGET_BLEND_DESC1,
}

D3D11_RASTERIZER_DESC1 :: struct {
    FillMode:              d3d11.FILL_MODE,
    CullMode:              d3d11.CULL_MODE,
    FrontCounterClockwise: win32.BOOL,
    DepthBias:             i32,
    DepthBiasClamp:        f32,
    SlopeScaledDepthBias:  f32,
    DepthClipEnable:       win32.BOOL,
    ScissorEnable:         win32.BOOL,
    MultisampleEnable:     win32.BOOL,
    AntialiasedLineEnable: win32.BOOL,
    ForcedSampleCount:     win32.UINT,
}

D3D11_IDeviceContextState_UUID_STRING :: "5c1e0d8a-7c23-48f9-8c59-a92958ceff11"
D3D11_IDeviceContextState_UUID := &win32.IID{
    0x5c1e0d8a, 0x7c23, 0x48f9, {0x8c, 0x59, 0xa9, 0x29, 0x58, 0xce, 0xff, 0x11}}
D3D11_IDeviceContextState :: struct #raw_union {
    #subtype id3d11devicechild: d3d11.IDeviceChild,
    using id3d11devicecontextstate: ^D3D11_IDeviceContextState_VTable,
}
D3D11_IDeviceContextState_VTable :: struct {
    using id3d11devicechild_vtable: d3d11.IDeviceChild_VTable,
}

D3D11_IBlendState1_UUID_STRING :: "cc86fabe-da55-401d-85e7-e3c9de2877e9"
D3D11_IBlendState1_UUID := &win32.IID{
    0xcc86fabe,0xda55 ,0x401d , {0x85, 0xe7, 0xe3, 0xc9, 0xde, 0x28, 0x77, 0xe9}}
D3D11_IBlendState1 :: struct #raw_union {
    #subtype id3d11blendstate: d3d11.IBlendState,
    using id3d11blendstate1_vtable: ^D3D11_IBlendState1_VTable,
}
D3D11_IBlendState1_VTable :: struct {
    using id3d11blendstate_vtable: d3d11.IBlendState_VTable,
    GetDesc1: proc "system" (this: ^D3D11_IBlendState1, pDesc: ^D3D11_BLEND_DESC1),
}

D3D11_IRasterizerState1_UUID_STRING :: "1217d7a6-5039-418c-b042-9cbe256afd6e"
D3D11_IRasterizerState1_UUID := &win32.IID{
    0x1217d7a6, 0x5039, 0x418c, {0xb0, 0x42, 0x9c, 0xbe, 0x25, 0x6a, 0xfd, 0x6e}}
D3D11_IRasterizerState1 :: struct #raw_union {
    #subtype id3d11rasterizerstate: d3d11.IRasterizerState,
    using id3d11rasterizerstate1_vtable: ^D3D11_IRasterizerState1_VTable,
}
D3D11_IRasterizerState1_VTable :: struct {
    using id3d11rasterizerstate_vtable: d3d11.IRasterizerState_VTable,
    GetDesc1: proc "system" (this: ^D3D11_IRasterizerState1, pDesc: ^D3D11_RASTERIZER_DESC1),
}

D3D11_IDevice1_UUID_STRING :: "a04bfb29-08ef-43d6-a49c-a9bdbdcbe686"
D3D11_IDevice1_UUID := &win32.IID{
    0xa04bfb29, 0x08ef, 0x43d6, {0xa4, 0x9c, 0xa9, 0xbd, 0xbd, 0xcb, 0xe6, 0x86}}
D3D11_IDevice1 :: struct #raw_union {
    #subtype id3d11device: d3d11.IDevice,
    using id3d11device1_vtable: ^D3D11_IDevice1_VTable,
}
D3D11_IDevice1_VTable :: struct {
    using id3d11device_vtable: d3d11.IDevice_VTable,
    GetImmediateContext1: proc "system" (
        this: ^D3D11_IDevice1,
        ppImmediateContext: ^^D3D11_IDeviceContext1,
    ),
    CreateDeferredContext1: proc "system" (
        this: ^D3D11_IDevice1,
        ContextFlags: u32,
        ppDeferredContext: ^^D3D11_IDeviceContext1,
    ) -> win32.HRESULT,
    CreateBlendState1: proc "system" (
        this: ^D3D11_IDevice1,
        pBlendStateDesc: ^D3D11_BLEND_DESC1,
        ppBlendState: ^^D3D11_IBlendState1,
    ) -> win32.HRESULT,
    CreateRasterizerState1: proc "system" (
        this: ^D3D11_IDevice1,
        pRasterizerDesc: ^D3D11_RASTERIZER_DESC1,
        ppRasterizerState: ^^D3D11_IRasterizerState1,
    ) -> win32.HRESULT,
    CreateDeviceContextState: proc "system" (
        this: ^D3D11_IDevice1,
        Flags: u32,
        pFeatureLevels: [^]d3d11.FEATURE_LEVEL,
        FeatureLevels: u32,
        SDKVersion: u32,
        EmulatedInterface: ^win32.IID,
        pChosenFeatureLevel: ^d3d11.FEATURE_LEVEL,
        ppContextState: ^^D3D11_IDeviceContextState,
    ) -> win32.HRESULT,
    OpenSharedResource1: proc "system" (
        this: ^D3D11_IDevice1,
        hResource: win32.HANDLE,
        returnedInterface: ^win32.IID,
        ppResource: ^rawptr,
    ) -> win32.HRESULT,
    OpenSharedResourceByName: proc "system" (
        this: ^D3D11_IDevice1,
        lpName: win32.LPCWSTR,
        dwDesiredAccess: win32.DWORD,
        returnedInterface: ^win32.IID,
        ppResource: ^rawptr,
    ) -> win32.HRESULT,
}

D3D11_IDeviceContext1_UUID_STRING :: "bb2c6faa-b5fb-4082-8e6b-388b8cfa90e1"
D3D11_IDeviceContext1_UUID := &win32.IID{
    0xbb2c6faa, 0xb5fb, 0x4082, {0x8e, 0x6b, 0x38, 0x8b, 0x8c, 0xfa, 0x90, 0xe1}}
D3D11_IDeviceContext1 :: struct #raw_union {
    #subtype id3d11devicecontext: d3d11.IDeviceContext,
    using id3d11devicecontext1_vtable: ^D3D11_IDeviceContext1_VTable,
}
D3D11_IDeviceContext1_VTable :: struct {
    using id3d11devicecontext_vtable: d3d11.IDeviceContext_VTable,
    CopySubresourceRegion1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pDstResource: ^d3d11.IResource,
        DstSubresource: u32,
        DstX: u32,
        DstY: u32,
        DstZ: u32,
        pSrcResource: ^d3d11.IResource,
        SrcSubresource: u32,
        pSrcBox: ^d3d11.BOX,
        CopyFlags: u32,
    ),
    UpdateSubresource1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pDstResource: ^d3d11.IResource,
        DstSubresource: u32,
        pDstBox: ^d3d11.BOX,
        pSrcData: rawptr,
        SrcRowPitch: u32,
        SrcDepthPitch: u32,
        CopyFlags: u32,
    ),
    DiscardResource: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pResource: ^d3d11.IResource,
    ),
    DiscardView: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pResourceView: ^d3d11.IView,
    ),
    VSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    HSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    DSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    GSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    PSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    CSSetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    VSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    HSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    DSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    GSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    PSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    CSGetConstantBuffers1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        StartSlot: u32,
        NumBuffers: u32,
        ppConstantBuffers: [^]^d3d11.IBuffer,
        pFirstConstant: ^u32,
        pNumConstants: ^u32,
    ),
    SwapDeviceContextState: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pState: ^D3D11_IDeviceContextState,
        ppPreviousState: ^^D3D11_IDeviceContextState,
    ),
    ClearView: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pView: ^d3d11.IView,
        Color: [4]f32,
        pRect: ^d3d11.RECT,
        NumRects: u32,
    ),
    DiscardView1: proc "system" (
        this: ^D3D11_IDeviceContext1,
        pResourceView: ^d3d11.IView,
        pRects: ^d3d11.RECT,
        NumRects: u32,
    ),
}

d3d11_init :: proc(allocator := context.allocator) {
    // Global procedures
    create_instance_impl                    = d3d11_create_instance

    // Adapter procedures
    adapter_get_info                        = d3d11_adapter_get_info
    adapter_info_free_members               = d3d11_adapter_info_free_members
    adapter_request_device                  = d3d11_adapter_request_device
    adapter_get_features                    = d3d11_adapter_get_features
    adapter_get_label                       = d3d11_adapter_get_label
    adapter_set_label                       = d3d11_adapter_set_label
    adapter_add_ref                         = d3d11_adapter_add_ref
    adapter_release                         = d3d11_adapter_release

    // Bind Group Layout procedures
    bind_group_layout_get_label             = d3d11_bind_group_layout_get_label
    bind_group_layout_set_label             = d3d11_bind_group_layout_set_label
    bind_group_layout_add_ref               = d3d11_bind_group_layout_add_ref
    bind_group_layout_release               = d3d11_bind_group_layout_release

    // Bind Group procedures
    bind_group_get_label                    = d3d11_bind_group_get_label
    bind_group_set_label                    = d3d11_bind_group_set_label
    bind_group_add_ref                      = d3d11_bind_group_add_ref
    bind_group_release                      = d3d11_bind_group_release

    // Buffer procedures
    buffer_unmap                            = d3d11_buffer_unmap
    buffer_get_map_state                    = d3d11_buffer_get_map_state
    buffer_get_size                         = d3d11_buffer_get_size
    buffer_get_usage                        = d3d11_buffer_get_usage
    buffer_get_label                        = d3d11_buffer_get_label
    buffer_set_label                        = d3d11_buffer_set_label
    buffer_add_ref                          = d3d11_buffer_add_ref
    buffer_release                          = d3d11_buffer_release

    // Command Buffer procedures
    command_buffer_get_label                = d3d11_command_buffer_get_label
    command_buffer_set_label                = d3d11_command_buffer_set_label
    command_buffer_add_ref                  = d3d11_command_buffer_add_ref
    command_buffer_release                  = d3d11_command_buffer_release

    // Command Encoder procedures
    command_encoder_begin_render_pass       = d3d11_command_encoder_begin_render_pass
    command_encoder_copy_texture_to_texture = d3d11_command_encoder_copy_texture_to_texture
    command_encoder_finish                  = d3d11_command_encoder_finish
    command_encoder_get_label               = d3d11_command_encoder_get_label
    command_encoder_set_label               = d3d11_command_encoder_set_label
    command_encoder_add_ref                 = d3d11_command_encoder_add_ref
    command_encoder_release                 = d3d11_command_encoder_release

    // Device procedures
    device_create_buffer                    = d3d11_device_create_buffer
    device_create_bind_group_layout         = d3d11_device_create_bind_group_layout
    device_create_bind_group                = d3d11_device_create_bind_group
    device_create_command_encoder           = d3d11_device_create_command_encoder
    device_create_render_pipeline           = d3d11_device_create_render_pipeline
    device_create_pipeline_layout           = d3d11_device_create_pipeline_layout
    device_create_texture                   = d3d11_device_create_texture
    device_create_sampler                   = d3d11_device_create_sampler
    device_create_shader_module             = d3d11_device_create_shader_module
    device_get_features                     = d3d11_device_get_features
    device_get_limits                       = d3d11_device_get_limits
    device_get_queue                        = d3d11_device_get_queue
    device_get_label                        = d3d11_device_get_label
    device_set_label                        = d3d11_device_set_label
    device_add_ref                          = d3d11_device_add_ref
    device_release                          = d3d11_device_release

    // Instance procedures
    instance_create_surface                 = d3d11_instance_create_surface
    instance_request_adapter                = d3d11_instance_request_adapter
    instance_get_label                      = d3d11_instance_get_label
    instance_set_label                      = d3d11_instance_set_label
    instance_add_ref                        = d3d11_instance_add_ref
    instance_release                        = d3d11_instance_release

    // Pipeline Layout procedures
    pipeline_layout_get_label               = d3d11_pipeline_layout_get_label
    pipeline_layout_set_label               = d3d11_pipeline_layout_set_label
    pipeline_layout_add_ref                 = d3d11_pipeline_layout_add_ref
    pipeline_layout_release                 = d3d11_pipeline_layout_release

    // Queue procedures
    queue_submit                            = d3d11_queue_submit
    queue_write_buffer_impl                 = d3d11_queue_write_buffer
    queue_write_texture                     = d3d11_queue_write_texture
    queue_get_label                         = d3d11_queue_get_label
    queue_set_label                         = d3d11_queue_set_label
    queue_add_ref                           = d3d11_queue_add_ref
    queue_release                           = d3d11_queue_release

    // Render Pass procedures
    render_pass_draw                        = d3d11_render_pass_draw
    render_pass_draw_indexed                = d3d11_render_pass_draw_indexed
    render_pass_end                         = d3d11_render_pass_end
    render_pass_set_stencil_reference       = d3d11_render_pass_set_stencil_reference
    render_pass_set_scissor_rect            = d3d11_render_pass_set_scissor_rect
    render_pass_set_viewport                = d3d11_render_pass_set_viewport
    render_pass_set_bind_group              = d3d11_render_pass_set_bind_group
    render_pass_set_pipeline                = d3d11_render_pass_set_pipeline
    render_pass_set_vertex_buffer           = d3d11_render_pass_set_vertex_buffer
    render_pass_set_index_buffer            = d3d11_render_pass_set_index_buffer
    render_pass_get_label                   = d3d11_render_pass_get_label
    render_pass_set_label                   = d3d11_render_pass_set_label
    render_pass_add_ref                     = d3d11_render_pass_add_ref
    render_pass_release                     = d3d11_render_pass_release

    // Render Pipeline procedures
    render_pipeline_get_label               = d3d11_render_pipeline_get_label
    render_pipeline_set_label               = d3d11_render_pipeline_set_label
    render_pipeline_add_ref                 = d3d11_render_pipeline_add_ref
    render_pipeline_release                 = d3d11_render_pipeline_release

    // Sampler procedures
    sampler_get_label                       = d3d11_sampler_get_label
    sampler_set_label                       = d3d11_sampler_set_label
    sampler_add_ref                         = d3d11_sampler_add_ref
    sampler_release                         = d3d11_sampler_release

    // Shader Module procedures
    shader_module_get_label                 = d3d11_shader_module_get_label
    shader_module_set_label                 = d3d11_shader_module_set_label
    shader_module_add_ref                   = d3d11_shader_module_add_ref
    shader_module_release                   = d3d11_shader_module_release

    // Surface procedures
    surface_get_capabilities                = d3d11_surface_get_capabilities
    surface_capabilities_free_members       = d3d11_surface_capabilities_free_members
    surface_configure                       = d3d11_surface_configure
    surface_get_current_texture             = d3d11_surface_get_current_texture
    surface_present                         = d3d11_surface_present
    surface_get_label                       = d3d11_surface_get_label
    surface_set_label                       = d3d11_surface_set_label
    surface_add_ref                         = d3d11_surface_add_ref
    surface_release                         = d3d11_surface_release

    // Texture procedures
    texture_create_view_impl                = d3d11_texture_create_view
    texture_get_descriptor                  = d3d11_texture_get_descriptor
    texture_get_dimension                   = d3d11_texture_get_dimension
    texture_get_format                      = d3d11_texture_get_format
    texture_get_height                      = d3d11_texture_get_height
    texture_get_mip_level_count             = d3d11_texture_get_mip_level_count
    texture_get_sample_count                = d3d11_texture_get_sample_count
    texture_get_size                        = d3d11_texture_get_size
    texture_get_usage                       = d3d11_texture_get_usage
    texture_get_width                       = d3d11_texture_get_width
    texture_get_label                       = d3d11_texture_get_label
    texture_set_label                       = d3d11_texture_set_label
    texture_add_ref                         = d3d11_texture_add_ref
    texture_release                         = d3d11_texture_release

    // Texture View procedures
    texture_view_get_label                  = d3d11_texture_view_get_label
    texture_view_set_label                  = d3d11_texture_view_set_label
    texture_view_add_ref                    = d3d11_texture_view_add_ref
    texture_view_release                    = d3d11_texture_view_release
}

// -----------------------------------------------------------------------------
// Global procedures that are not specific to an object
// -----------------------------------------------------------------------------


@(require_results)
d3d11_create_instance :: proc(
    descriptor: Maybe(Instance_Descriptor) = nil,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    instance: Instance,
) {
    desc := descriptor.? or_else {}

    hr: win32.HRESULT

    // Init DXGI factory
    dxgi_factory: ^dxgi.IFactory2

    hr = dxgi.CreateDXGIFactory2(
        .Debug in desc.flags ? { .DEBUG } : {},
        dxgi.IFactory2_UUID,
        cast(^rawptr)&dxgi_factory,
    )

    // Check if debug layers is the reason for error
    if .Debug in desc.flags && hr == dxgi.ERROR_INVALID_CALL {
        hr_prev := hr
        hr = dxgi.CreateDXGIFactory2({}, dxgi.IFactory2_UUID, cast(^rawptr)&dxgi_factory)
        if hr == win32.S_OK {
            log.warnf("D3D11 debug layers disabled: %0x", u32(hr_prev))
        }
    }
    d3d_check(hr, "dxgi.CreateDXGIFactory2 failed")

    // Create a temp IFactory5 to check for tearing support
    dxgi_factory5: ^dxgi.IFactory5
    hr = dxgi_factory->QueryInterface(dxgi.IFactory5_UUID, cast(^rawptr)&dxgi_factory5)
    tearing_support: bool
    if win32.SUCCEEDED(hr) {
        defer dxgi_factory5->Release()
        allow_tearing: win32.BOOL
        hr = dxgi_factory5->CheckFeatureSupport(
            .PRESENT_ALLOW_TEARING,
            &allow_tearing,
            size_of(win32.BOOL),
        )
        tearing_support = bool(hr == win32.S_OK && allow_tearing)
    }

    // Create instance
    impl := instance_new_impl(D3D11_Instance_Impl, allocator, loc)

    impl.ctx = context
    impl.flags = desc.flags
    impl.backend = .Dx11
    impl.shader_formats = { .Dxbc, .Dxil }
    impl.dxgi_factory = dxgi_factory
    impl.allow_tearing = tearing_support

    return Instance(impl)
}

// -----------------------------------------------------------------------------
// Adapter procedures
// -----------------------------------------------------------------------------


D3D11_Adapter_Impl :: struct {
    // Base
    using base:      Adapter_Base,

    // Backend
    adapter:         ^dxgi.IAdapter1,
    desc:            dxgi.ADAPTER_DESC1,
    device:          ^D3D11_IDevice1,
    d3d_context:     ^D3D11_IDeviceContext1,
    // device:       ^d3d11.IDevice,
    // d3d_context:  ^d3d11.IDeviceContext,
    feature_level:   d3d11.FEATURE_LEVEL,
    is_debug_device: bool,
}

@(private)
d3d11_adapter_get_features_impl :: proc(adapter: ^D3D11_Adapter_Impl) -> Features {
    // Always available features in D3D11
    ret := Features{
        .Depth32_Float_Stencil8,
        .Depth_Clip_Control,
        .Texture_Compression_BC,
        .Texture_Compression_BC_Sliced_3D,
        .Float32_Filterable,
        .Float32_Blendable,
        .Dual_Source_Blending,
        .Clip_Distances,
        .Indirect_First_Instance,
        .Texture_Format_16Bit_Norm,
        .Pipeline_Statistics_Query,
        .Timestamp_Query,
        .Timestamp_Query_Inside_Passes,
        .Texture_Binding_Array,
        .Buffer_Binding_Array,
        .Storage_Resource_Binding_Array,
        .Sampled_Texture_And_Storage_Buffer_Array_Non_Uniform_Indexing,
        .Address_Mode_Clamp_To_Border,
        .Polygon_Mode_Line,
        .Vertex_Writable_Storage,
        .Clear_Texture,
        .Texture_Adapter_Specific_Format_Features,
        .Bgra8_Unorm_Storage,
    }

    assert(adapter.device != nil)
    device := adapter.device

    // Query feature level
    feature_level := adapter.device->GetFeatureLevel()

    // Feature Level specific
    if feature_level >= ._11_1 {
        ret += {
            // .Shader_Float32_Atomic,
            .Multi_Draw_Indirect_Count,
            .Partially_Bound_Binding_Array,
        }
    }

    // Shader Model 5.0+ capabilities
    if feature_level >= ._11_0 {
        ret += { .Shader_Primitive_Index, .Shader_Early_Depth_Test }
    }

    // Query D3D11.2 features
    options2: d3d11.FEATURE_DATA_OPTIONS2
    if win32.SUCCEEDED(device->CheckFeatureSupport(.OPTIONS2, &options2, size_of(options2))) {
        if options2.ConservativeRasterizationTier >= ._1 {
            ret += {.Conservative_Rasterization}
        }
        if options2.ROVsSupported {
            ret += {.Texture_Atomic}
        }
    }

    // Query D3D11.3 features
    options3: d3d11.FEATURE_DATA_OPTIONS3
    if win32.SUCCEEDED(device->CheckFeatureSupport(.OPTIONS3, &options3, size_of(options3))) {
        if options3.VPAndRTArrayIndexFromAnyShaderFeedingRasterizer {
            ret += { .Multiview }
        }
    }

    // Check R11G11B10_FLOAT renderable support
    support: d3d11.FEATURE_DATA_FORMAT_SUPPORT
    support.InFormat = .R11G11B10_FLOAT
    if win32.SUCCEEDED(device->CheckFeatureSupport(.FORMAT_SUPPORT, &support, size_of(support))) {
        if (support.OutFormatSupport & u32(d3d11.FORMAT_SUPPORT.RENDER_TARGET)) != 0 {
            ret += {.Rg11B10_Ufloat_Renderable}
        }
    }

    // Check double precision support
    doubles: d3d11.FEATURE_DATA_DOUBLES
    if win32.SUCCEEDED(device->CheckFeatureSupport(.DOUBLES, &doubles, size_of(doubles))) {
        if doubles.DoublePrecisionFloatShaderOps {
            ret += {.Shader_F64}
        }
    }

    return ret
}

d3d11_adapter_get_features :: proc(adapter: Adapter, loc := #caller_location) -> Features {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    return impl.features
}

@(private)
d3d11_adapter_get_limits_impl :: proc(adapter: ^D3D11_Adapter_Impl) -> Limits {
    assert(adapter.device != nil)
    device := adapter.device
    feature_level := device->GetFeatureLevel()

    // Start with default limits
    limits := LIMITS_DOWNLEVEL

    // Texture dimensions based on D3D11 hardware requirements
    limits.max_texture_dimension_1d = d3d11.REQ_TEXTURE1D_U_DIMENSION
    limits.max_texture_dimension_2d = d3d11.REQ_TEXTURE2D_U_OR_V_DIMENSION
    limits.max_texture_dimension_3d = d3d11.REQ_TEXTURE3D_U_V_OR_W_DIMENSION
    limits.max_texture_array_layers = d3d11.REQ_TEXTURE2D_ARRAY_AXIS_DIMENSION

    // Shader Resource Limits
    limits.max_sampled_textures_per_shader_stage = d3d11.COMMONSHADER_INPUT_RESOURCE_SLOT_COUNT
    limits.max_samplers_per_shader_stage = d3d11.COMMONSHADER_SAMPLER_SLOT_COUNT

    // Constant buffers: Reserve slot 0 for internal use
    limits.max_uniform_buffers_per_shader_stage =
        d3d11.COMMONSHADER_CONSTANT_BUFFER_API_SLOT_COUNT - 1

    // UAVs (Unordered Access Views) for storage buffers/textures
    max_uavs_all_stages: u32
    max_uavs_per_stage: u32

    if feature_level >= ._11_1 {
        // FL 11.1+: 64 UAV slots total, all shader stages
        max_uavs_all_stages = d3d11._1_UAV_SLOT_COUNT  // 64
        max_uavs_per_stage = 32  // Conservative: shared across VS+PS+GS+HS+DS
    } else {
        // FL 11.0: Only PS and CS can use UAVs (8 slots each)
        max_uavs_all_stages = d3d11.PS_CS_UAV_REGISTER_COUNT
        max_uavs_per_stage = 8
    }

    // Split UAVs between storage buffers and storage textures
    limits.max_storage_buffers_per_shader_stage = max_uavs_per_stage / 2
    limits.max_storage_textures_per_shader_stage = max_uavs_per_stage / 2

    // Bind Groups (WebGPU concept, not native to D3D11)
    limits.max_bind_groups = 4
    limits.max_bindings_per_bind_group = 1000

    // Dynamic buffers
    limits.max_dynamic_uniform_buffers_per_pipeline_layout = limits.max_uniform_buffers_per_shader_stage
    limits.max_dynamic_storage_buffers_per_pipeline_layout = limits.max_storage_buffers_per_shader_stage

    // Buffer sizes and alignment
    limits.max_uniform_buffer_binding_size = d3d11.REQ_CONSTANT_BUFFER_ELEMENT_COUNT * 16

    // Storage buffer size: Check for Qualcomm quirk
    vendor_id := u32(adapter.desc.VendorId)
    if vendor_id == 0x5143 {  // Qualcomm
        // Qualcomm has a smaller limit
        limits.max_storage_buffer_binding_size = 1 << d3d11.REQ_BUFFER_RESOURCE_TEXEL_COUNT_2_TO_EXP
    } else {
        // Most GPUs: 2GB limit (D3D11 structured buffer max)
        limits.max_storage_buffer_binding_size = 2 << 30  // ~2GB
    }

    limits.max_buffer_size = u64(limits.max_storage_buffer_binding_size)

    // Alignment requirements
    limits.min_uniform_buffer_offset_alignment = 256
    limits.min_storage_buffer_offset_alignment = 16

    // Vertex Input
    limits.max_vertex_buffers = d3d11.IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT
    limits.max_vertex_attributes = d3d11.IA_VERTEX_INPUT_RESOURCE_SLOT_COUNT - 2
    limits.max_vertex_buffer_array_stride = 2048  // WebGPU default

    // Inter-stage variables and render targets
    limits.max_inter_stage_shader_variables = d3d11.PS_INPUT_REGISTER_COUNT - 2
    limits.max_color_attachments = d3d11.SIMULTANEOUS_RENDER_TARGET_COUNT
    limits.max_color_attachment_bytes_per_sample = 8 * 16

    // Compute shader limits
    limits.max_compute_workgroup_storage_size = d3d11.CS_TGSM_REGISTER_COUNT * 4
    limits.max_compute_invocations_per_workgroup = d3d11.CS_THREAD_GROUP_MAX_THREADS_PER_GROUP
    limits.max_compute_workgroup_size_x = d3d11.CS_THREAD_GROUP_MAX_X
    limits.max_compute_workgroup_size_y = d3d11.CS_THREAD_GROUP_MAX_Y
    limits.max_compute_workgroup_size_z = d3d11.CS_THREAD_GROUP_MAX_Z
    limits.max_compute_workgroups_per_dimension = d3d11.CS_DISPATCH_MAX_THREAD_GROUPS_PER_DIMENSION

    // Subgroup support (not natively supported in D3D11)
    limits.min_subgroup_size = 0
    limits.max_subgroup_size = 0

    // Push constants (not natively supported in D3D11, emulated with CBs)
    limits.max_push_constant_size = 0

    // Mesh/task shaders (not in D3D11)
    limits.max_task_workgroup_total_count = 0
    limits.max_task_workgroups_per_dimension = 0
    limits.max_mesh_output_layers = 0
    limits.max_mesh_multiview_count = 0

    // Ray tracing (not in D3D11)
    limits.max_blas_primitive_count = 0
    limits.max_blas_geometry_count = 0
    limits.max_tlas_instance_count = 0
    limits.max_acceleration_structures_per_shader_stage = 0

    // Combined limits
    limits.max_bind_groups_plus_vertex_buffers = limits.max_bind_groups + limits.max_vertex_buffers

    // Non-sampler bindings: High limit for modern GPUs
    limits.max_non_sampler_bindings = 1_000_000

    return limits
}

d3d11_adapter_get_limits :: proc(adapter: Adapter, loc := #caller_location) -> Limits {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    return impl.limits
}

@(require_results)
d3d11_adapter_get_info :: proc(
    adapter: Adapter,
    allocator := context.allocator,
    loc: runtime.Source_Code_Location,
) -> (
    info: Adapter_Info,
) {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)

    name_buf: [256]u8
    name := win32.wstring_to_utf8_buf(name_buf[:], cstring16(raw_data(impl.desc.Description[:])))

    info.name = strings.clone(name, allocator)
    info.vendor = impl.desc.VendorId
    info.device = impl.desc.DeviceId
    info.device_type = impl.type
    info.backend = .Dx11

    uwd_version: win32.LARGE_INTEGER
    if hr := impl.adapter->CheckInterfaceSupport(
        dxgi.IDevice_UUID, &uwd_version,
    ); hr == win32.S_OK && uwd_version != 0 {
        mask : win32.LARGE_INTEGER = 0xFFFF
        info.driver = fmt.aprintf("%d.%d.%d.%d",
            uwd_version >> 48,
            (uwd_version >> 32) & mask,
            (uwd_version >> 16) & mask,
            uwd_version & mask,
            allocator = allocator)
    }

    return
}

d3d11_adapter_info_free_members :: proc(self: Adapter_Info, allocator := context.allocator) {
    context.allocator = allocator
    if len(self.name) > 0 do delete(self.name)
    if len(self.driver) > 0 do delete(self.driver)
}

d3d11_adapter_request_device :: proc(
    adapter: Adapter,
    callback_info: Request_Device_Callback_Info,
    descriptor: Maybe(Device_Descriptor) = nil,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)

    assert(callback_info.callback != nil, "No callback provided for device request", loc)
    assert(adapter != nil, "Invalid adapter", loc)
    assert(impl.instance != nil, "Invalid instance", loc)

    instance_impl := get_impl(D3D11_Instance_Impl, impl.instance, loc)

    invoke_callback :: proc(
        callback_info: Request_Device_Callback_Info,
        status: Request_Device_Status,
        device: Device,
        message: string,
    ) {
        callback_info.callback(
            status,
            device,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }

    device_impl := adapter_new_handle(D3D11_Device_Impl, adapter, loc)

    queue_impl := device_new_handle(
        D3D11_Queue_Impl,
        Device(device_impl),
        loc)
    device_impl.queue = queue_impl
    device_impl.is_debug_device = impl.is_debug_device
    device_impl.backend = instance_impl.backend
    device_impl.shader_formats = instance_impl.shader_formats
    device_impl.d3d_device = impl.device
    device_impl.d3d_device->AddRef()
    device_impl.d3d_context = impl.d3d_context
    device_impl.d3d_context->AddRef()

    // if .Debug in instance_impl.flags && impl.is_debug_device {
    //     hr := impl.device->QueryInterface(d3d11.IInfoQueue_UUID, (^rawptr)(&device_impl.info_queue))
    //     d3d_check(hr, "device->QueryInterface failed")
    // }

    // Initialize base command allocator
    cmd_impl := device_new_handle(
        D3D11_Command_Encoder_Impl,
        Device(device_impl),
        loc)
    command_allocator_init(&cmd_impl.cmd_allocator, allocator = impl.allocator, loc = loc)
    device_impl.encoder = cmd_impl

    cmdbuf_impl := command_encoder_new_handle(
        D3D11_Command_Buffer_Impl,
        Command_Encoder(cmd_impl),
        loc)
    cmd_impl.cmdbuf = cmdbuf_impl

    invoke_callback(callback_info, .Success, Device(device_impl), "")
}

@(require_results)
d3d11_adapter_get_label :: proc(adapter: Adapter, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_adapter_set_label :: proc(adapter: Adapter, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_adapter_add_ref :: proc(adapter: Adapter, loc := #caller_location) {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_adapter_release :: proc(adapter: Adapter, loc := #caller_location) {
    impl := get_impl(D3D11_Adapter_Impl, adapter, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        impl->adapter->Release()
        impl->d3d_context->Release()
        impl->device->Release()
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Bind Group Layout procedures
// -----------------------------------------------------------------------------


D3D11_Bind_Group_Layout_Impl :: struct {
    using base: Bind_Group_Layout_Base,
    entries:    []D3D11_Bind_Group_Layout_Entry,
}

D3D11_Bind_Group_Layout_Entry :: struct {
    binding:    u32,
    visibility: Shader_Stages,
    type:       D3D11_Binding_Type,
    count:      u32,
}

D3D11_Binding_Type :: union {
    D3D11_Buffer_Binding_Layout,
    D3D11_Sampler_Binding_Layout,
    D3D11_Texture_Binding_Layout,
    D3D11_Storage_Texture_Binding_Layout,
}

D3D11_Buffer_Binding_Layout :: struct {
    type:               Buffer_Binding_Type,
    has_dynamic_offset: bool,
    min_binding_size:   u64,
}

D3D11_Sampler_Binding_Layout :: struct {
    type: Sampler_Binding_Type,
}

D3D11_Texture_Binding_Layout :: struct {
    sample_type:    Texture_Sample_Type,
    view_dimension: Texture_View_Dimension,
    multisampled:   bool,
}

D3D11_Storage_Texture_Binding_Layout :: struct {
    access:         Storage_Texture_Access,
    format:         Texture_Format,
    view_dimension: Texture_View_Dimension,
    dxgi_format:    dxgi.FORMAT, // For UAV creation
}

@(require_results)
d3d11_bind_group_layout_get_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Bind_Group_Layout_Impl, bind_group_layout, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_bind_group_layout_set_label :: proc(
    bind_group_layout: Bind_Group_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Bind_Group_Layout_Impl, bind_group_layout, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_bind_group_layout_add_ref :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Bind_Group_Layout_Impl, bind_group_layout, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_bind_group_layout_release :: proc(
    bind_group_layout: Bind_Group_Layout,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Bind_Group_Layout_Impl, bind_group_layout, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        if len(impl.entries) > 0 {
            delete(impl.entries)
        }
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Bind Group procedures
// -----------------------------------------------------------------------------


D3D11_Bind_Group_Impl :: struct {
    using base: Bind_Group_Base,
    layout:     ^D3D11_Bind_Group_Layout_Impl,
    entries:    []D3D11_Bind_Group_Entry,
}

D3D11_Bind_Group_Entry :: struct {
    binding:  u32,
    resource: D3D11_Bind_Group_Resource,
}

D3D11_Bind_Group_Resource :: union {
    D3D11_Buffer_Binding,
    D3D11_Sampler_Binding,
    D3D11_Texture_View_Binding,
    []D3D11_Buffer_Binding,
    []D3D11_Sampler_Binding,
    []D3D11_Texture_View_Binding,
}

D3D11_Buffer_Binding :: struct {
    buffer: ^D3D11_Buffer_Impl,
    offset: u64,
    size:   u64,
}

D3D11_Sampler_Binding :: struct {
    sampler: ^D3D11_Sampler_Impl,
}

D3D11_Texture_View_Binding :: struct {
    texture_view: ^D3D11_Texture_View_Impl,
}

@(require_results)
d3d11_bind_group_get_label :: proc(bind_group: Bind_Group, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Bind_Group_Impl, bind_group, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_bind_group_set_label :: proc(
    bind_group: Bind_Group,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Bind_Group_Impl, bind_group, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_bind_group_add_ref :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(D3D11_Bind_Group_Impl, bind_group, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_bind_group_release :: proc(bind_group: Bind_Group, loc := #caller_location) {
    impl := get_impl(D3D11_Bind_Group_Impl, bind_group, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        for &entry in impl.entries {
            switch &res in entry.resource {
            case D3D11_Buffer_Binding:
                d3d11_buffer_release(Buffer(res.buffer), loc)
            case D3D11_Sampler_Binding:
                d3d11_sampler_release(Sampler(res.sampler), loc)
            case D3D11_Texture_View_Binding:
                d3d11_texture_view_release(Texture_View(res.texture_view), loc)
            case []D3D11_Buffer_Binding:
                for &buffer_entry in res {
                    d3d11_buffer_release(Buffer(buffer_entry.buffer), loc)
                }
            case []D3D11_Sampler_Binding:
                for &sampler_entry in res {
                    d3d11_sampler_release(Sampler(sampler_entry.sampler), loc)
                }
            case []D3D11_Texture_View_Binding:
                for &view_entry in res {
                    d3d11_texture_view_release(Texture_View(view_entry.texture_view), loc)
                }
            }
        }

        delete(impl.entries)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Buffer procedures
// -----------------------------------------------------------------------------


D3D11_Buffer_Impl :: struct {
    using base:     Buffer_Base,

    // D3D11 resources
    buffer:         ^d3d11.IBuffer,              // Main GPU buffer
    staging_buffer: ^d3d11.IBuffer,              // Staging buffer for CPU access
    srv:            ^d3d11.IShaderResourceView,  // For storage buffer reads
    uav:            ^d3d11.IUnorderedAccessView, // For storage buffer writes
}

d3d11_buffer_unmap :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)

    assert(impl.mapped_ptr != nil, "Attempted to unmap buffer that is not mapped", loc)
    assert(impl.map_state != .Unmapped, "Unmap called in wrong state", loc)
    assert(impl.staging_buffer != nil, "No staging buffer during unmap", loc)

    device_impl := get_impl(D3D11_Device_Impl, impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Unmap the staging buffer
    d3d_context->Unmap(impl.staging_buffer, 0)

    // If we have a separate main GPU buffer, copy data from staging to main
    if impl.buffer != nil && impl.buffer != impl.staging_buffer {
        d3d_context->CopyResource(impl.buffer, impl.staging_buffer)

        // Decide whether to keep the staging buffer for future writes
        keep_staging := (
            .Copy_Dst  in impl.usage ||
            .Map_Write in impl.usage ||
            .Map_Read  in impl.usage
        )

        // This was a one-time upload: release temporary staging buffer
        // Otherwise: keep it for future queue_write_buffer or mapping
        if !keep_staging {
            impl.staging_buffer->Release()
            impl.staging_buffer = nil
        }
    }

    // Clear mapping state
    impl.mapped_ptr = nil
    impl.mapped_range = {}
    impl.map_state = .Unmapped
}

d3d11_buffer_get_map_state :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Map_State {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    return impl.map_state
}

d3d11_buffer_get_size :: proc(buffer: Buffer, loc := #caller_location) -> u64 {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    return impl.size
}

d3d11_buffer_get_usage :: proc(buffer: Buffer, loc := #caller_location) -> Buffer_Usages {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    return impl.usage
}

@(require_results)
d3d11_buffer_get_label :: proc(buffer: Buffer, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_buffer_set_label :: proc(buffer: Buffer, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_buffer_add_ref :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_buffer_release :: proc(buffer: Buffer, loc := #caller_location) {
    impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        // Unmap if mapped
        if impl.mapped_ptr != nil {
            device_impl := get_impl(D3D11_Device_Impl, impl.device, loc)
            resource := impl.staging_buffer != nil \
                ? impl.staging_buffer \
                : impl.buffer
            device_impl.d3d_context->Unmap(resource, 0)
            impl.mapped_ptr = nil
        }

        if impl.uav != nil {
            impl.uav->Release()
            impl.uav = nil
        }

        if impl.srv != nil {
            impl.srv->Release()
            impl.srv = nil
        }

        if impl.staging_buffer != nil {
            impl.staging_buffer->Release()
            impl.staging_buffer = nil
        }

        if impl.buffer != nil {
            impl.buffer->Release()
            impl.buffer = nil
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Command Encoder procedures
// -----------------------------------------------------------------------------


D3D11_Command_Allocator :: struct {
    using base: Command_Allocator,
    in_use:     bool,
}

D3D11_Command_Encoder_Impl :: struct {
    // Base
    using base:                    Command_Encoder_Base,

    // Backend
    cmd_allocator:                 D3D11_Command_Allocator,
    cmdbuf:                        ^D3D11_Command_Buffer_Impl,

    // Render pass tracking
    current_render_pass:           Render_Pass,
    current_render_pass_width:     u32,
    current_render_pass_height:    u32,
    current_begin_render_pass_cmd: ^Command_Begin_Render_Pass,

    // State tracking
    current_blend_color:           [4]f32,
    current_stencil_reference:     u32,
    current_pipeline:              Render_Pipeline,
}

d3d11_command_encoder_begin_render_pass :: proc(
    encoder: Command_Encoder,
    descriptor: Render_Pass_Descriptor,
    loc := #caller_location,
) -> Render_Pass {
    assert(len(descriptor.color_attachments) > 0, "No color attachments", loc)

    impl := get_impl(D3D11_Command_Encoder_Impl, encoder, loc)

    cmd := command_allocator_allocate(&impl.cmd_allocator, Command_Begin_Render_Pass)
    assert(cmd != nil)

    // Copy color attachments
    sa.resize(&cmd.color_attachments, len(descriptor.color_attachments))
    for color_att, i in descriptor.color_attachments {
        sa.set(&cmd.color_attachments, i, color_att)
    }

    // Copy depth stencil attachment if present
    if descriptor.depth_stencil_attachment != nil {
        cmd.depth_stencil_attachment = descriptor.depth_stencil_attachment^
    }

    // Create render pass wrapper
    rpass_impl := command_encoder_new_handle(D3D11_Render_Pass_Impl, encoder, loc)
    rpass_impl.encoding = true

    color0 := sa.get(cmd.color_attachments, 0)
    view_impl := get_impl(D3D11_Texture_View_Impl, color0.view, loc)
    texture_impl := get_impl(D3D11_Texture_Impl, view_impl.texture, loc)
    cmd.width = texture_impl.size.width
    cmd.height = texture_impl.size.height

    return Render_Pass(rpass_impl)
}

d3d11_command_encoder_copy_buffer_to_buffer :: proc(
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

d3d11_command_encoder_copy_buffer_to_texture :: proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Buffer_Info,
    destination: ^Texel_Copy_Texture_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

d3d11_command_encoder_copy_texture_to_buffer :: proc(
    encoder: Command_Encoder,
    source: ^Texel_Copy_Texture_Info,
    destination: ^Texel_Copy_Buffer_Info,
    copy_size: ^Extent_3D,
    loc := #caller_location,
) {
    unimplemented()
}

d3d11_command_encoder_copy_texture_to_texture :: proc(
    encoder: Command_Encoder,
    source: Texel_Copy_Texture_Info,
    destination: Texel_Copy_Texture_Info,
    copy_size: Extent_3D,
    loc := #caller_location,
) {
    impl := get_impl(GL_Command_Encoder_Impl, encoder, loc)
    cmd := command_allocator_allocate(&impl.cmd_allocator, Command_Copy_Texture_To_Texture)
    cmd.source = source
    cmd.destination = destination
    cmd.copy_size = copy_size
}

d3d11_command_encoder_finish :: proc(
    encoder: Command_Encoder,
    loc := #caller_location,
) -> Command_Buffer {
    impl := get_impl(D3D11_Command_Encoder_Impl, encoder, loc)
    impl.encoding = false
    return Command_Buffer(impl.cmdbuf)
}

@(require_results)
d3d11_command_encoder_get_label :: proc(
    command_encoder: Command_Encoder,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Command_Encoder_Impl, command_encoder, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_command_encoder_set_label :: proc(
    command_encoder: Command_Encoder,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Command_Encoder_Impl, command_encoder, loc)
    string_buffer_init(&impl.label, label)
}

@(disabled = true)
d3d11_command_encoder_add_ref :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
}

@(disabled = true)
d3d11_command_encoder_release :: proc(command_encoder: Command_Encoder, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Command Buffer procedures
// -----------------------------------------------------------------------------


D3D11_Command_Buffer_Impl :: struct {
    using base: Command_Buffer_Base,
}

@(require_results)
d3d11_command_buffer_get_label :: proc(
    command_buffer: Command_Buffer,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Command_Buffer_Impl, command_buffer, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_command_buffer_set_label :: proc(
    command_buffer: Command_Buffer,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Command_Buffer_Impl, command_buffer, loc)
    string_buffer_init(&impl.label, label)
}

@(disabled = true)
d3d11_command_buffer_add_ref :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
}

@(disabled = true)
d3d11_command_buffer_release :: proc(command_buffer: Command_Buffer, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Device procedures
// -----------------------------------------------------------------------------


D3D11_Device_Impl :: struct {
    // Base
    using base:      Device_Base,

    // Backend
    queue:           ^D3D11_Queue_Impl,
    d3d_device:      ^D3D11_IDevice1,
    d3d_context:     ^D3D11_IDeviceContext1,
    // d3d_device:   ^d3d11.IDevice,
    // d3d_context:  ^d3d11.IDeviceContext,
    // info_queue:   ^d3d11.IInfoQueue,
    encoder:         ^D3D11_Command_Encoder_Impl,
    is_debug_device: bool,
}

@(require_results)
d3d11_device_create_bind_group_layout :: proc(
    device: Device,
    descriptor: Bind_Group_Layout_Descriptor,
    loc := #caller_location,
) -> Bind_Group_Layout {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    layout := device_new_handle(D3D11_Bind_Group_Layout_Impl, device, loc)

    if len(descriptor.label) > 0 {
        string_buffer_init(&layout.label, descriptor.label)
    }

    // Convert entries
    if len(descriptor.entries) > 0 {
        layout.entries =
            make([]D3D11_Bind_Group_Layout_Entry, len(descriptor.entries), impl.allocator)

        for entry, i in descriptor.entries {
            d3d_entry := &layout.entries[i]
            d3d_entry.binding = entry.binding
            d3d_entry.visibility = entry.visibility
            d3d_entry.count = entry.count

            // Convert binding type
            switch bind_type in entry.type {
            case Buffer_Binding_Layout:
                d3d_entry.type = D3D11_Buffer_Binding_Layout{
                    type               = bind_type.type,
                    has_dynamic_offset = bind_type.has_dynamic_offset,
                    min_binding_size   = bind_type.min_binding_size,
                }

            case Sampler_Binding_Layout:
                d3d_entry.type = D3D11_Sampler_Binding_Layout{
                    type = bind_type.type,
                }

            case Texture_Binding_Layout:
                d3d_entry.type = D3D11_Texture_Binding_Layout{
                    sample_type    = bind_type.sample_type,
                    view_dimension = bind_type.view_dimension,
                    multisampled   = bind_type.multisampled,
                }

            case Storage_Texture_Binding_Layout:
                dxgi_format := d3d_dxgi_texture_format(bind_type.format)

                d3d_entry.type = D3D11_Storage_Texture_Binding_Layout{
                    access         = bind_type.access,
                    format         = bind_type.format,
                    view_dimension = bind_type.view_dimension,
                    dxgi_format    = dxgi_format,
                }

            case Acceleration_Structure_Binding_Layout:
                unimplemented("Ray tracing acceleration structures not supported in D3D11", loc)
            }
        }

        // Sort entries by binding in ascending order
        slice.sort_by(layout.entries, proc(a, b: D3D11_Bind_Group_Layout_Entry) -> bool {
            return a.binding < b.binding
        })
    }

    return Bind_Group_Layout(layout)
}

@(require_results)
d3d11_device_create_bind_group :: proc(
    device: Device,
    descriptor: Bind_Group_Descriptor,
    loc := #caller_location,
) -> Bind_Group {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    assert(descriptor.layout != nil, "Invalid bind group layout", loc)
    layout_impl := get_impl(D3D11_Bind_Group_Layout_Impl, descriptor.layout, loc)

    bind_group := device_new_handle(D3D11_Bind_Group_Impl, device, loc)
    bind_group.layout = layout_impl

    if len(descriptor.label) > 0 {
        string_buffer_init(&bind_group.label, descriptor.label)
    }

    // Convert entries
    if len(descriptor.entries) > 0 {
        bind_group.entries =
            make([]D3D11_Bind_Group_Entry, len(descriptor.entries), impl.allocator)

        for entry, i in descriptor.entries {
            d3d_entry := &bind_group.entries[i]
            d3d_entry.binding = entry.binding

            // Convert resource types
            switch &res in entry.resource {
            case Buffer_Binding:
                buffer := get_impl(D3D11_Buffer_Impl, Buffer(res.buffer), loc)
                size := res.size if res.size != WHOLE_SIZE else buffer.size
                buffer_add_ref(Buffer(buffer), loc)
                d3d_entry.resource = D3D11_Buffer_Binding{
                    buffer = buffer,
                    offset = res.offset,
                    size   = size,
                }

            case Sampler:
                sampler := get_impl(D3D11_Sampler_Impl, Sampler(res), loc)
                sampler_add_ref(Sampler(sampler), loc)
                d3d_entry.resource = D3D11_Sampler_Binding{
                    sampler = sampler,
                }

            case Texture_View:
                texture_view := get_impl(D3D11_Texture_View_Impl, Texture_View(res), loc)
                texture_view_add_ref(Texture_View(texture_view), loc)
                d3d_entry.resource = D3D11_Texture_View_Binding{
                    texture_view = texture_view,
                }

            case []Buffer_Binding:
                d3d_buffers := make([]D3D11_Buffer_Binding, len(res), impl.allocator)
                for &buf, j in res {
                    buffer := get_impl(D3D11_Buffer_Impl, Buffer(buf.buffer), loc)
                    size := buf.size if buf.size != WHOLE_SIZE else buffer.size
                    buffer_add_ref(Buffer(buffer), loc)
                    d3d_buffers[j] = D3D11_Buffer_Binding{
                        buffer = buffer,
                        offset = buf.offset,
                        size   = size,
                    }
                }
                d3d_entry.resource = d3d_buffers

            case []Sampler:
                d3d_samplers := make([]D3D11_Sampler_Binding, len(res), impl.allocator)
                for sampler, j in res {
                    sampler_impl := get_impl(D3D11_Sampler_Impl, Sampler(sampler), loc)
                    sampler_add_ref(Sampler(sampler_impl), loc)
                    d3d_samplers[j] = D3D11_Sampler_Binding{
                        sampler = sampler_impl,
                    }
                }
                d3d_entry.resource = d3d_samplers

            case []Texture_View:
                d3d_texture_views := make([]D3D11_Texture_View_Binding, len(res), impl.allocator)
                for view, j in res {
                    view_impl := get_impl(D3D11_Texture_View_Impl, Texture_View(view), loc)
                    texture_view_add_ref(Texture_View(view_impl), loc)
                    d3d_texture_views[j] = D3D11_Texture_View_Binding{
                        texture_view = view_impl,
                    }
                }
                d3d_entry.resource = d3d_texture_views
            }
        }

        // Sort entries by binding in ascending order
        slice.sort_by(bind_group.entries, proc(a, b: D3D11_Bind_Group_Entry) -> bool {
            return a.binding < b.binding
        })

        when ODIN_DEBUG {
            // Validate against layout
            assert(len(bind_group.entries) == len(layout_impl.entries),
                "Mismatched number of bind group entries", loc)
            for i in 0 ..< len(bind_group.entries) {
                assert(bind_group.entries[i].binding == layout_impl.entries[i].binding,
                    "Mismatched bind group entry binding", loc)
            }
        }
    }

    return Bind_Group(bind_group)
}

@(require_results)
d3d11_device_create_buffer :: proc(
    device: Device,
    descriptor: Buffer_Descriptor,
    loc := #caller_location,
) -> Buffer {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    // Validate descriptor
    assert(descriptor.size > 0, "Buffer size must be greater than 0", loc)
    if descriptor.mapped_at_creation {
        assert(
            descriptor.size % COPY_BUFFER_ALIGNMENT == 0,
            "Mapped at creation buffers must have size aligned to COPY_BUFFER_ALIGNMENT",
            loc,
        )
    }

    buffer_impl := device_new_handle(D3D11_Buffer_Impl, device, loc)

    final_size := u32(max(descriptor.size, 4))
    if .Indirect in descriptor.usage {
        final_size = max(final_size, D3D11_INDIRECT_BUFFER_MIN_SIZE)
    }

    alignment := d3d11_buffer_size_alignment(descriptor.usage)
    final_size = align(final_size, alignment)

    buffer_impl.size = Buffer_Address(final_size)
    buffer_impl.usage = descriptor.usage

    map_read  := .Map_Read  in descriptor.usage
    map_write := .Map_Write in descriptor.usage
    has_gpu_binding := (
        .Vertex   in descriptor.usage ||
        .Index    in descriptor.usage ||
        .Uniform  in descriptor.usage ||
        .Storage  in descriptor.usage ||
        .Indirect in descriptor.usage
    )
    copy_src := .Copy_Src in descriptor.usage
    copy_dst := .Copy_Dst in descriptor.usage

    bind_flags: d3d11.BIND_FLAGS
    if .Vertex   in descriptor.usage { bind_flags += {.VERTEX_BUFFER}   }
    if .Index    in descriptor.usage { bind_flags += {.INDEX_BUFFER}    }
    if .Uniform  in descriptor.usage { bind_flags += {.CONSTANT_BUFFER} }
    if .Storage  in descriptor.usage { bind_flags += {.SHADER_RESOURCE, .UNORDERED_ACCESS} }

    misc_flags: d3d11.RESOURCE_MISC_FLAGS
    if .Storage  in descriptor.usage { misc_flags += {.BUFFER_ALLOW_RAW_VIEWS} }
    if .Indirect in descriptor.usage { misc_flags += {.DRAWINDIRECT_ARGS}    }

    usage: d3d11.USAGE
    cpu_access: d3d11.CPU_ACCESS_FLAGS
    needs_separate_staging := false
    primary_is_gpu_visible := true

    // Determine if we need a staging buffer
    if map_read || map_write {
        if has_gpu_binding && map_write && !map_read &&
           .Storage not_in descriptor.usage &&
           .Indirect not_in descriptor.usage &&
           !copy_src {
            // Best case: DYNAMIC (CPU write-only, GPU read-only, no UAV/indirect/copy_src)
            usage = .DYNAMIC
            cpu_access = {.WRITE}
        } else {
            // Need full CPU access + GPU access → DEFAULT + staging
            usage = .DEFAULT
            needs_separate_staging = true
            primary_is_gpu_visible = true
        }
    } else if !has_gpu_binding && (map_read || map_write || copy_src || copy_dst) {
        // Pure staging (no GPU binding at all)
        usage = .STAGING
        bind_flags = {}
        primary_is_gpu_visible = false
    } else {
        // Pure GPU buffer
        usage = .DEFAULT
    }

    // Even if not mappable, Copy_Dst usage needs a staging buffer for efficient
    // queue_write_buffer operations
    if copy_dst && !needs_separate_staging && usage != .STAGING {
        needs_separate_staging = true
    }

    // CPU access for staging (when needed)
    staging_cpu_access := cpu_access
    if map_read  { staging_cpu_access += {.READ}  }
    if map_write || copy_dst { staging_cpu_access += {.WRITE} }

    main_desc := d3d11.BUFFER_DESC{
        ByteWidth      = final_size,
        Usage          = usage,
        BindFlags      = bind_flags,
        CPUAccessFlags = usage == .DYNAMIC || usage == .STAGING ? staging_cpu_access : {},
        MiscFlags      = misc_flags,
    }

    hr: win32.HRESULT

    if descriptor.mapped_at_creation {
        // Always use a writable staging buffer for initial data
        staging_desc := d3d11.BUFFER_DESC{
            ByteWidth      = final_size,
            Usage          = .STAGING,
            CPUAccessFlags = {.WRITE},
        }

        hr = impl.d3d_device->CreateBuffer(&staging_desc, nil, &buffer_impl.staging_buffer)
        d3d_check(hr, "CreateBuffer (initial staging) failed", loc)

        mapped: d3d11.MAPPED_SUBRESOURCE
        // Note: WRITE_DISCARD map type can be used on DYNAMIC buffers for
        // frequent per-frame updates to avoid GPU stalls via resource renaming.
        // For one-time initial upload, it's unnecessary and invalid on STAGING.
        hr = impl.d3d_context->Map(buffer_impl.staging_buffer, 0, .WRITE, {}, &mapped)
        d3d_check(hr, "Map (initial) failed", loc)

        buffer_impl.mapped_ptr = mapped.pData
        buffer_impl.mapped_range = {0, Buffer_Address(final_size)}
        buffer_impl.map_state = .Mapped

        // Do we need a separate main GPU buffer?
        if has_gpu_binding || copy_dst {
            hr = impl.d3d_device->CreateBuffer(&main_desc, nil, &buffer_impl.buffer)
            d3d_check(hr, "CreateBuffer (main) failed", loc)
            // Data will be copied on first unmap
        } else {
            // Pure upload-only or staging-only, staging becomes the "main" buffer
            buffer_impl.buffer = buffer_impl.staging_buffer
            buffer_impl.staging_buffer = nil
        }
    }  else {
        // Create main buffer
        hr = impl.d3d_device->CreateBuffer(&main_desc, nil, &buffer_impl.buffer)
        d3d_check(hr, "CreateBuffer (main) failed", loc)

        // Create persistent staging if needed for later mapping
        if needs_separate_staging {
            staging_desc := d3d11.BUFFER_DESC{
                ByteWidth      = final_size,
                Usage          = .STAGING,
                CPUAccessFlags = staging_cpu_access,
                BindFlags      = {},
            }
            hr = impl.d3d_device->CreateBuffer(&staging_desc, nil, &buffer_impl.staging_buffer)
            d3d_check(hr, "CreateBuffer (persistent staging) failed", loc)
        }
    }

    gpu_buffer := buffer_impl.buffer
    if gpu_buffer != nil && usage != .STAGING {
        if .Storage in descriptor.usage {
            // Raw SRV
            srv_desc := d3d11.SHADER_RESOURCE_VIEW_DESC{
                Format        = .R32_TYPELESS,
                ViewDimension = .BUFFEREX,
                BufferEx      = {
                    FirstElement = 0,
                    NumElements  = final_size / 4,
                    Flags        = {.RAW},
                },
            }
            hr = impl.d3d_device->CreateShaderResourceView(gpu_buffer, &srv_desc, &buffer_impl.srv)
            d3d_check(hr, "CreateShaderResourceView failed", loc)

            // UAV only on non-DYNAMIC buffers
            if usage != .DYNAMIC {
                uav_desc := d3d11.UNORDERED_ACCESS_VIEW_DESC{
                    Format     = .R32_TYPELESS,
                    ViewDimension = .BUFFER,
                    Buffer     = {
                        FirstElement = 0,
                        NumElements  = final_size / 4,
                        Flags        = {.RAW},
                    },
                }
                hr = impl.d3d_device->CreateUnorderedAccessView(
                    gpu_buffer,
                    &uav_desc,
                    &buffer_impl.uav)
                d3d_check(hr, "CreateUnorderedAccessView failed", loc)
            }
        }
    }

    if len(descriptor.label) > 0 {
        string_buffer_init(&buffer_impl.label, descriptor.label)
    }

    return Buffer(buffer_impl)
}

@(require_results)
d3d11_device_create_command_encoder :: proc(
    device: Device,
    descriptor: Maybe(Command_Encoder_Descriptor) = nil,
    loc := #caller_location,
) -> Command_Encoder {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    impl.encoder.encoding = true
    return Command_Encoder(impl.encoder)
}

@(require_results)
d3d11_device_create_render_pipeline :: proc(
    device: Device,
    descriptor: Render_Pipeline_Descriptor,
    loc := #caller_location,
) -> Render_Pipeline {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    // Basic validation
    assert(descriptor.vertex.module != nil, "Vertex shader module is required", loc)

    // Allocate pipeline handle
    out := device_new_handle(D3D11_Render_Pipeline_Impl, device, loc)

    // Optional debug label
    if len(descriptor.label) > 0 {
        string_buffer_init(&out.label, descriptor.label)
    }

    // Vertex Shader
    vs_impl := get_impl(D3D11_Shader_Module_Impl, descriptor.vertex.module, loc)
    assert(vs_impl.vertex_shader != nil, "Invalid vertex shader", loc)
    out.vertex_shader = vs_impl.vertex_shader
    out.vertex_shader->AddRef()

    // Pixel Shader (optional)
    if descriptor.fragment != nil {
        ps_impl := get_impl(D3D11_Shader_Module_Impl, descriptor.fragment.module, loc)
        assert(ps_impl.pixel_shader != nil, "Invalid pixel shader", loc)
        out.pixel_shader = ps_impl.pixel_shader
        out.pixel_shader->AddRef()
    }

    // Input Layout
    if len(descriptor.vertex.buffers) > 0 {
        // Store vertex buffer info (stride + step mode + attributes copy)
        out.vertex_buffers =
            make([]D3D11_Vertex_Buffer_Info, len(descriptor.vertex.buffers), impl.allocator)
        for &buffer, i in descriptor.vertex.buffers {
            vb := &out.vertex_buffers[i]
            vb.stride = u32(buffer.array_stride)
            vb.step_mode = buffer.step_mode
            vb.attributes = make([]Vertex_Attribute, len(buffer.attributes), impl.allocator)
            copy(vb.attributes, buffer.attributes)
        }

        ta := context.temp_allocator
        runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

        // Reflect vertex shader to get input signature
        vs_ref: ^d3d11.IShaderReflection
        hr := d3d_compiler.Reflect(
            raw_data(vs_impl.bytecode),
            uint(len(vs_impl.bytecode)),
            d3d11.ID3D11ShaderReflection_UUID,
            (^rawptr)(&vs_ref),
        )
        d3d_check(hr, "Failed to reflect vertex shader", loc)
        defer vs_ref->Release()

        // Build map: shader_location -> attribute info
        Attrib_Info :: struct {
            buffer_idx: u32,
            attrib:     ^Vertex_Attribute,
            step_mode:  Vertex_Step_Mode,
        }
        attrib_map := make(map[u32]Attrib_Info, ta)

        for &buffer, buffer_idx in descriptor.vertex.buffers {
            for &attrib in buffer.attributes {
                attrib_map[attrib.shader_location] = {
                    buffer_idx = u32(buffer_idx),
                    attrib = &attrib,
                    step_mode = buffer.step_mode,
                }
            }
        }

        // Build input element array from shader reflection
        input_elements := make([dynamic]d3d11.INPUT_ELEMENT_DESC, 0, 16, ta)

        shader_desc: d3d11.SHADER_DESC
        vs_ref->GetDesc(&shader_desc)

        for i in 0 ..< shader_desc.InputParameters {
            param_desc: d3d11.SIGNATURE_PARAMETER_DESC
            vs_ref->GetInputParameterDesc(i, &param_desc)

            // The shader location is stored in the Register field by the shader compiler
            shader_location := param_desc.Register

            if info, ok := attrib_map[shader_location]; ok {
                append(&input_elements, d3d11.INPUT_ELEMENT_DESC {
                    SemanticName         = param_desc.SemanticName,
                    SemanticIndex        = param_desc.SemanticIndex,
                    Format               = d3d_dxgi_vertex_format(info.attrib.format),
                    InputSlot            = info.buffer_idx,
                    AlignedByteOffset    = u32(info.attrib.offset),
                    InputSlotClass       = info.step_mode == .Vertex ? .VERTEX_DATA : .INSTANCE_DATA,
                    InstanceDataStepRate = info.step_mode == .Instance ? 1 : 0,
                })
            } else {
                log.warnf("No vertex attribute for shader input location %d (%s%d)",
                          shader_location, param_desc.SemanticName, param_desc.SemanticIndex)
            }
        }

        // Create the actual input layout
        hr = impl.d3d_device->CreateInputLayout(
            raw_data(input_elements[:]),
            u32(len(input_elements)),
            raw_data(vs_impl.bytecode),
            uint(len(vs_impl.bytecode)),
            &out.input_layout,
        )
        d3d_check(hr, "Failed to create input layout", loc)
    }

    // Store primitive topology
    out.primitive_topology = d3d11_conv_to_primitive_topology(descriptor.primitive.topology)
    out.strip_index_format = descriptor.primitive.strip_index_format

    front_counter_clockwise: bool
    #partial switch descriptor.primitive.front_face {
    case .Undefined, .Ccw: front_counter_clockwise = true
    }

    // Initialize the rasterizer state
    rasterizer_desc := d3d11.RASTERIZER_DESC {
        FillMode              = .SOLID,
        CullMode              = d3d11_conv_to_cull_mode(descriptor.primitive.cull_mode),
        FrontCounterClockwise = win32.BOOL(front_counter_clockwise),
        DepthClipEnable       = win32.BOOL(descriptor.primitive.unclipped_depth),
        ScissorEnable         = true,
        MultisampleEnable     = descriptor.multisample.count > 1,
        AntialiasedLineEnable = false,
    }

    // Apply depth bias if depth stencil is present
    if descriptor.depth_stencil != nil {
        ds := descriptor.depth_stencil
        rasterizer_desc.DepthBias = ds.bias.constant
        rasterizer_desc.DepthBiasClamp = ds.bias.clamp
        rasterizer_desc.SlopeScaledDepthBias = ds.bias.slope_scale
    }

    hr := impl.d3d_device->CreateRasterizerState(&rasterizer_desc, &out.rasterizer_state)
    d3d_check(hr, "d3d_device->CreateRasterizerState failed", loc)

    // Initialize the blend state
    blend_desc := d3d11.BLEND_DESC {
        AlphaToCoverageEnable  = win32.BOOL(descriptor.multisample.alpha_to_coverage_enabled),
        IndependentBlendEnable = true,
    }

    if descriptor.fragment != nil {
        for &target, i in descriptor.fragment.targets {
            rt := &blend_desc.RenderTarget[i]
            rt.BlendEnable = target.blend != nil
            if rt.BlendEnable {
                rt.SrcBlend = d3d11_conv_to_blend(target.blend.color.src_factor)
                format_components := texture_format_components(target.format)
                if format_components < 4 && rt.SrcBlend == .DEST_ALPHA {
                    // Missing format components default to 0, except A which defaults
                    // to 1. Replacing DEST_ALPHA with ONE can be an optimization, this
                    // avoids reading the destination texture.
                    rt.SrcBlend = .ONE
                }
                rt.DestBlend = d3d11_conv_to_blend(target.blend.color.dst_factor)
                rt.BlendOp = d3d11_conv_to_blend_op(target.blend.color.operation)
                rt.SrcBlendAlpha = d3d11_conv_to_blend_alpha(target.blend.alpha.src_factor)
                rt.DestBlendAlpha = d3d11_conv_to_blend_alpha(target.blend.alpha.dst_factor)
                rt.BlendOpAlpha = d3d11_conv_to_blend_op(target.blend.alpha.operation)
            }
            rt.RenderTargetWriteMask = d3d11_conv_to_color_write_enable(target.write_mask)
        }
    }

    hr = impl.d3d_device->CreateBlendState(&blend_desc, &out.blend_state)
    d3d_check(hr, "d3d_device->CreateBlendState failed", loc)

    // Initialize depth stencil state
    if descriptor.depth_stencil != nil {
        ds := descriptor.depth_stencil

        depth_stencil_desc := d3d11.DEPTH_STENCIL_DESC {
            DepthEnable      = win32.BOOL(ds.depth_compare != .Always || ds.depth_write_enabled),
            DepthWriteMask   = ds.depth_write_enabled  ? .ALL : .ZERO,
            DepthFunc        = d3d11_conv_to_comparison_func(ds.depth_compare),
            StencilEnable    = win32.BOOL(stencil_state_is_enabled(ds.stencil)),
            StencilReadMask  = u8(ds.stencil.read_mask),
            StencilWriteMask = u8(ds.stencil.write_mask),
            FrontFace        = d3d11_conv_to_depth_stencil_op_desc(ds.stencil.front),
            BackFace         = d3d11_conv_to_depth_stencil_op_desc(ds.stencil.back),
        }

        hr = impl.d3d_device->CreateDepthStencilState(&depth_stencil_desc, &out.depth_stencil_state)
        d3d_check(hr, "d3d_device->CreateDepthStencilState failed", loc)
    }

    // Store pipeline layout
    if descriptor.layout != nil {
        out.layout = descriptor.layout
        pipeline_layout_add_ref(descriptor.layout, loc)
    }

    // Multisample mask
    out.sample_mask = descriptor.multisample.mask

    return Render_Pipeline(out)
}

@(require_results)
d3d11_device_create_pipeline_layout :: proc(
    device: Device,
    descriptor: Pipeline_Layout_Descriptor,
    loc := #caller_location,
) -> Pipeline_Layout {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    layout := device_new_handle(D3D11_Pipeline_Layout_Impl, device, loc)

    if len(descriptor.label) > 0 {
        string_buffer_init(&layout.label, descriptor.label)
    }

    // Store bind group layouts
    if len(descriptor.bind_group_layouts) > 0 {
        layout.group_layouts = make(
            []^D3D11_Bind_Group_Layout_Impl,
            len(descriptor.bind_group_layouts),
            impl.allocator,
        )

        for bg_layout, i in descriptor.bind_group_layouts {
            d3d_bg_layout := get_impl(D3D11_Bind_Group_Layout_Impl, bg_layout, loc)
            layout.group_layouts[i] = d3d_bg_layout
            d3d11_bind_group_layout_add_ref(bg_layout, loc)
        }
    }

    // Store push constant ranges
    if len(descriptor.push_constant_ranges) > 0 {
        layout.push_constants = make(
            []Push_Constant_Range,
            len(descriptor.push_constant_ranges),
            impl.allocator,
        )
        copy(layout.push_constants, descriptor.push_constant_ranges)
    }

    return Pipeline_Layout(layout)
}

d3d11_device_create_texture :: proc(
    device: Device,
    descriptor: Texture_Descriptor,
    loc := #caller_location,
) -> Texture {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    texture_descriptor_validade(descriptor, impl.features, loc)

    texture := device_new_handle(D3D11_Texture_Impl, device, loc)

    if len(descriptor.label) > 0 {
        string_buffer_init(&texture.label, descriptor.label)
    }

    // Store texture properties
    texture.dimension = descriptor.dimension
    texture.size = descriptor.size
    texture.format = descriptor.format
    texture.mip_level_count = descriptor.mip_level_count
    texture.sample_count = descriptor.sample_count
    texture.usage = descriptor.usage

    // Determine bind flags from usage
    bind_flags: d3d11.BIND_FLAGS
    if .Texture_Binding in descriptor.usage {
        bind_flags += {.SHADER_RESOURCE}
    }
    if .Storage_Binding in descriptor.usage {
        bind_flags += {.UNORDERED_ACCESS}
    }
    if .Render_Attachment in descriptor.usage {
        if texture_format_is_depth_stencil_format(descriptor.format) {
            bind_flags += {.DEPTH_STENCIL}
        } else {
            bind_flags += {.RENDER_TARGET}
        }
    }

    // Determine CPU access flags and misc flags
    cpu_access_flags: d3d11.CPU_ACCESS_FLAGS
    misc_flags: d3d11.RESOURCE_MISC_FLAGS

    // Check if this is a cubemap (6 layers for basic cubemap)
    is_cubemap := descriptor.dimension == .D2 &&
                  descriptor.size.depth_or_array_layers == 6

    if is_cubemap {
        misc_flags += {.TEXTURECUBE}
    }

    dxgi_format := d3d_dxgi_texture_format(descriptor.format)

    // Create the appropriate texture type based on dimension
    hr: d3d11.HRESULT
    switch descriptor.dimension {
    case .D1:
        assert(descriptor.size.height == 1, "1D textures must have height == 1", loc)
        assert(descriptor.size.depth_or_array_layers == 1,
            "1D textures must have depth_or_array_layers == 1", loc)
        assert(descriptor.sample_count == 1, "1D textures cannot be multisampled", loc)

        desc := d3d11.TEXTURE1D_DESC{
            Width          = descriptor.size.width,
            MipLevels      = descriptor.mip_level_count,
            ArraySize      = descriptor.size.depth_or_array_layers,
            Format         = dxgi_format,
            Usage          = .DEFAULT,
            BindFlags      = bind_flags,
            CPUAccessFlags = cpu_access_flags,
            MiscFlags      = misc_flags,
        }

        hr = impl.d3d_device->CreateTexture1D(&desc, nil, &texture.texture1d)
        d3d_check(hr, "CreateTexture1D failed", loc)

    case .D2:
        if descriptor.sample_count > 1 {
            assert(descriptor.mip_level_count == 1,
                "Multisampled 2D textures must have mip_level_count == 1", loc)
        }

        // Multisample quality
        quality: u32 = 0
        if descriptor.sample_count > 1 {
            hr = impl.d3d_device->CheckMultisampleQualityLevels(
                dxgi_format,
                descriptor.sample_count,
                &quality,
            )
            d3d_check(hr, "d3d_device->CheckMultisampleQualityLevels failed", loc)
            assert(quality > 0, "Requested sample count not supported for this format", loc)
            quality -= 1 // Use highest quality
        }

        desc := d3d11.TEXTURE2D_DESC{
            Width          = descriptor.size.width,
            Height         = descriptor.size.height,
            MipLevels      = descriptor.mip_level_count,
            ArraySize      = descriptor.size.depth_or_array_layers,
            Format         = dxgi_format,
            SampleDesc     = {
                Count   = descriptor.sample_count,
                Quality = quality,
            },
            Usage          = .DEFAULT,
            BindFlags      = bind_flags,
            CPUAccessFlags = cpu_access_flags,
            MiscFlags      = misc_flags,
        }

        hr = impl.d3d_device->CreateTexture2D(&desc, nil, &texture.texture2d)
        d3d_check(hr, "CreateTexture2D failed", loc)

    case .D3:
        assert(descriptor.sample_count == 1, "3D textures cannot be multisampled", loc)
        assert(descriptor.mip_level_count == 1 || !(.Storage_Binding in descriptor.usage),
               "3D storage textures must have mip_level_count == 1", loc)

        desc := d3d11.TEXTURE3D_DESC{
            Width          = descriptor.size.width,
            Height         = descriptor.size.height,
            Depth          = descriptor.size.depth_or_array_layers,
            MipLevels      = descriptor.mip_level_count,
            Format         = dxgi_format,
            Usage          = .DEFAULT,
            BindFlags      = bind_flags,
            CPUAccessFlags = cpu_access_flags,
            MiscFlags      = misc_flags,
        }

        hr = impl.d3d_device->CreateTexture3D(&desc, nil, &texture.texture3d)
        d3d_check(hr, "CreateTexture3D failed", loc)

    case .Undefined:
        unreachable()
    }

    return Texture(texture)
}

@(require_results)
d3d11_device_create_sampler :: proc(
    device: Device,
    descriptor: Sampler_Descriptor,
    loc := #caller_location,
) -> Sampler {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    sampler_desc: d3d11.SAMPLER_DESC

    min_filter := d3d11_conv_to_filter_type(descriptor.min_filter)
    mag_filter := d3d11_conv_to_filter_type(descriptor.mag_filter)
    mipmap_filter := d3d11_conv_to_mipmap_filter_type(descriptor.mipmap_filter)

    // https://docs.microsoft.com/en-us/windows/win32/api/d3d11/ns-d3d11-d3d11_sampler_desc
    sampler_desc.MaxAnisotropy = u32(clamp(descriptor.max_anisotropy, 1, 16))

    // Filter reduction type determines how filter results are combined
    // Defaults to normal filtering (interpolation)
    reduction : d3d11.FILTER_REDUCTION_TYPE =
        descriptor.compare == .Undefined ? .STANDARD : .COMPARISON

    if sampler_desc.MaxAnisotropy > 1 {
        sampler_desc.Filter = d3d11_encode_anisotropic_filter(reduction)
    } else {
        sampler_desc.Filter =
            d3d11_encode_basic_filter(min_filter, mag_filter, mipmap_filter, reduction)
    }

    sampler_desc.AddressU = d3d11_conv_to_texture_address_mode(descriptor.address_mode_u)
    sampler_desc.AddressV = d3d11_conv_to_texture_address_mode(descriptor.address_mode_v)
    sampler_desc.AddressW = d3d11_conv_to_texture_address_mode(descriptor.address_mode_w)
    sampler_desc.MipLODBias = 0.0

    if descriptor.compare != .Undefined {
        sampler_desc.ComparisonFunc = d3d11_conv_to_comparison_func(descriptor.compare)
    } else {
        sampler_desc.ComparisonFunc = .NEVER
    }
    sampler_desc.MinLOD = descriptor.lod_min_clamp
    sampler_desc.MaxLOD = descriptor.lod_max_clamp

    sampler_state: ^d3d11.ISamplerState
    hr := impl.d3d_device->CreateSamplerState(&sampler_desc, &sampler_state)
    d3d_check(hr, "d3d_device->CreateSamplerState failed", loc)

    sampler := device_new_handle(D3D11_Sampler_Impl, device, loc)
    sampler.sampler_state = sampler_state

    return Sampler(sampler)
}

@(require_results)
d3d11_device_create_shader_module :: proc(
    device: Device,
    descriptor: Shader_Module_Descriptor,
    loc := #caller_location,
) -> Shader_Module {
    impl := get_impl(D3D11_Device_Impl, device, loc)

    assert(len(descriptor.code) > 0, "Shader code is empty", loc)
    assert(len(descriptor.code) >= 4, "Shader bytecode too small to be valid", loc)

    shader_impl := device_new_handle(D3D11_Shader_Module_Impl, device, loc)

    // Store shader bytecode
    shader_impl.bytecode = make([]u8, len(descriptor.code), impl.allocator)
    copy(shader_impl.bytecode, descriptor.code)

    #partial switch descriptor.stage {
    case .Vertex:
        hr := impl.d3d_device->CreateVertexShader(
            raw_data(descriptor.code),
            len(descriptor.code),
            nil,
            &shader_impl.vertex_shader,
        )
        d3d_check(hr, "d3d_device->CreateVertexShader failed", loc)

    case .Fragment:
        hr := impl.d3d_device->CreatePixelShader(
            raw_data(descriptor.code),
            len(descriptor.code),
            nil,
            &shader_impl.pixel_shader,
        )
        d3d_check(hr, "d3d_device->CreatePixelShader failed", loc)

    case .Compute:
        hr := impl.d3d_device->CreateComputeShader(
            raw_data(descriptor.code),
            len(descriptor.code),
            nil,
            &shader_impl.compute_shader,
        )
        d3d_check(hr, "d3d_device->CreateComputeShader failed", loc)

    case:
        unreachable()
    }

    return Shader_Module(shader_impl)
}

@(require_results)
d3d11_device_get_features :: proc(device: Device, loc := #caller_location) -> Features {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    return impl.features
}

@(require_results)
d3d11_device_get_limits :: proc(device: Device, loc := #caller_location) -> Limits {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    return impl.limits
}

@(require_results)
d3d11_device_get_queue :: proc(device: Device, loc := #caller_location) -> Queue {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    return Queue(impl.queue)
}

@(require_results)
d3d11_device_get_label :: proc(device: Device, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_device_set_label :: proc(device: Device, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_device_add_ref :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_device_release :: proc(device: Device, loc := #caller_location) {
    impl := get_impl(D3D11_Device_Impl, device, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        // Release default command allocator
        command_allocator_destroy(&impl.encoder.cmd_allocator, loc)
        free(impl.encoder, impl.encoder.allocator)
        free(impl.encoder.cmdbuf, impl.encoder.cmdbuf.allocator)

        free(impl.queue)

        // if impl.info_queue != nil {
        //     impl.info_queue->Release()
        // }

        impl.d3d_context->Release()
        impl.d3d_device->Release()

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Instance procedures
// -----------------------------------------------------------------------------


D3D11_Instance_Devices :: struct {
    device: ^d3d11.IDevice,
    info:   ^d3d11.IInfoQueue,
}

D3D11_Instance_Impl :: struct {
    // Base
    using instance_base: Instance_Base,

    // Backend
    dxgi_factory:        ^dxgi.IFactory2,
    allow_tearing:       bool,
}

@(require_results)
d3d11_instance_create_surface :: proc(
    instance: Instance,
    descriptor: Surface_Descriptor,
    loc := #caller_location,
) -> Surface {
    impl := get_impl(D3D11_Instance_Impl, instance, loc)

    hinstance: win32.HINSTANCE
    hwnd:      win32.HWND

    #partial switch &t in descriptor.target {
    case Surface_Source_Windows_HWND:
        if t.hinstance == nil || t.hwnd == nil {
            log.error("Invalid HWND surface descriptor")
            return nil
        }
        hinstance = win32.HINSTANCE(t.hinstance)
        hwnd = win32.HWND(t.hwnd)
    case:
        log.error("Unsupported surface descriptor type")
        return nil
    }

    surface := instance_new_handle(D3D11_Surface_Impl, instance, loc)

    surface.allocator = impl.allocator
    surface.hinstance = hinstance
    surface.hwnd = hwnd

    return Surface(surface)
}

d3d11_instance_request_adapter :: proc(
    instance: Instance,
    callback_info: Request_Adapter_Callback_Info,
    options: Maybe(Request_Adapter_Options) = nil,
    loc := #caller_location,
) {
    assert(callback_info.callback != nil, "No callback provided", loc)

    impl := get_impl(D3D11_Instance_Impl, instance, loc)
    opts := options.? or_else {}

    invoke_callback :: proc(
        callback_info: Request_Adapter_Callback_Info,
        status: Request_Adapter_Status,
        adapter: Adapter,
        message: string,
    ) {
        callback_info.callback(
            status,
            adapter,
            message,
            callback_info.userdata1,
            callback_info.userdata2,
        )
    }

    score_adapter :: proc(desc: ^dxgi.ADAPTER_DESC1, pref: Power_Preference) -> int {
        if .SOFTWARE in desc.Flags || .REMOTE in desc.Flags {
            return -1
        }

        dedicated_gb := int(desc.DedicatedVideoMemory / (1024 * 1024 * 1024))

        base: int
        switch pref {
        case .High_Performance:
            base = dedicated_gb >= 4 ? 200 : 100  // Favor high-VRAM discrete
            base += dedicated_gb * 5 // Bonus per GB
        case .Low_Power:
            base = desc.DedicatedVideoMemory == 0 ? 150 : 50 // Shared memory = integrated
        case .Undefined:
            base = 100 + dedicated_gb * 3
        }

        return base
    }

    get_device_type :: proc(desc: ^dxgi.ADAPTER_DESC1) -> Device_Type {
        if .SOFTWARE in desc.Flags do return .Cpu
        if .REMOTE in desc.Flags   do return .Virtual_Gpu
        // Assuming any dedicated memory is discrete gpu
        return desc.DedicatedVideoMemory > 0 ? .Discrete_Gpu : .Integrated_Gpu
    }

    feature_levels := [?]d3d11.FEATURE_LEVEL{._11_1, ._11_0}

    best_adapter: ^dxgi.IAdapter1 = nil
    best_score := -1
    best_desc: dxgi.ADAPTER_DESC1
    best_type: Device_Type

    // Enumerate and score adapters
    for adapter_index: u32 = 0; /* */ ; adapter_index += 1 {
        adapter: ^dxgi.IAdapter1
        hr := impl.dxgi_factory->EnumAdapters1(u32(adapter_index), &adapter)
        if hr == dxgi.ERROR_NOT_FOUND {
            break
        }
        if win32.FAILED(hr) {
            continue
        }
        defer adapter->Release()

        desc: dxgi.ADAPTER_DESC1
        adapter->GetDesc1(&desc)

        score := score_adapter(&desc, opts.power_preference)
        if score <= best_score { continue }

        // Quick compatibility check for d3d 11.1
        device: ^d3d11.IDevice
        fl: d3d11.FEATURE_LEVEL
        hr = d3d11.CreateDevice(
            adapter, .UNKNOWN, nil, {},
            &feature_levels[0], len(feature_levels),
            d3d11.SDK_VERSION, &device, &fl, nil,
        )
        if win32.FAILED(hr) || fl < ._11_1 {
            continue  // Skip incompatible
        }
        device->Release()

        // Better adapter found
        if best_adapter != nil {
            best_adapter->Release()
        }
        best_adapter = adapter
        best_adapter->AddRef()  // Transfer ownership
        best_score = score
        best_desc = desc
        best_type = get_device_type(&desc)
    }

    if best_adapter == nil {
        invoke_callback(callback_info, .Unavailable, nil, "No compatible D3D11.1 adapter found")
        return
    }

    // Create final device on best adapter
    device_flags := d3d11.CREATE_DEVICE_FLAGS{.BGRA_SUPPORT}
    if .Debug in impl.flags {
        device_flags += { .DEBUG }
    }

    create_device :: proc(
        adapter: ^dxgi.IAdapter1,
        feature_levels: []d3d11.FEATURE_LEVEL,
        flags: d3d11.CREATE_DEVICE_FLAGS,
    ) -> (
        device: ^d3d11.IDevice,
        d3d_context: ^d3d11.IDeviceContext,
        feature_level: d3d11.FEATURE_LEVEL,
        ok: bool,
    ) {
        ok = win32.SUCCEEDED(d3d11.CreateDevice(
            adapter, .UNKNOWN, nil, flags,
            &feature_levels[0], u32(len(feature_levels)),
            d3d11.SDK_VERSION, &device, &feature_level, &d3d_context,
        ))
        return
    }

    device: ^d3d11.IDevice
    d3d_context: ^d3d11.IDeviceContext
    feature_level: d3d11.FEATURE_LEVEL
    ok: bool

    device, d3d_context, feature_level, ok =
        create_device(best_adapter, feature_levels[:], device_flags)
    if !ok && .Debug in impl.flags {
        log.warn("D3D11 debug layer failed, retrying without it")
        device_flags -= {.DEBUG}
        device, d3d_context, feature_level, ok =
            create_device(best_adapter, feature_levels[:], device_flags)
    }
    if !ok {
        best_adapter->Release()
        invoke_callback(callback_info, .Error, nil, "Failed to create D3D11 device")
        return
    }

    defer {
        device->Release()
        d3d_context->Release()
    }

    // Query D3D11.1 interfaces
    device1: ^D3D11_IDevice1
    hr := device->QueryInterface(D3D11_IDevice1_UUID, (^rawptr)(&device1))
    d3d_check(hr, "Failed to query ID3D11Device1", loc)

    d3d_context1: ^D3D11_IDeviceContext1
    hr = d3d_context->QueryInterface(D3D11_IDeviceContext1_UUID, (^rawptr)(&d3d_context1))
    d3d_check(hr, "Failed to query ID3D11DeviceContext1", loc)

    // Success: create adapter handle
    adapter_impl := instance_new_handle(D3D11_Adapter_Impl, instance, loc)
    adapter_impl.adapter = best_adapter
    adapter_impl.device = device1
    adapter_impl.d3d_context = d3d_context1
    adapter_impl.is_debug_device = .Debug in impl.flags && device_flags & {.DEBUG} != {}
    adapter_impl.type = best_type
    adapter_impl.desc = best_desc
    adapter_impl.feature_level = feature_level
    adapter_impl.features = d3d11_adapter_get_features_impl(adapter_impl)
    adapter_impl.limits = d3d11_adapter_get_limits_impl(adapter_impl)

    invoke_callback(callback_info, .Success, Adapter(adapter_impl), "")
}

@(require_results)
d3d11_instance_get_label :: proc(instance: Instance, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Instance_Impl, instance, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_instance_set_label :: proc(instance: Instance, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Instance_Impl, instance, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_instance_add_ref :: proc(instance: Instance, loc := #caller_location) {
    impl := get_impl(D3D11_Instance_Impl, instance, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_instance_release :: proc(instance: Instance, loc := #caller_location) {
    impl := get_impl(D3D11_Instance_Impl, instance, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        impl.dxgi_factory->Release()
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Pipeline Layout
// -----------------------------------------------------------------------------

D3D11_Pipeline_Layout_Impl :: struct {
    using base:     Pipeline_Layout_Base,
    group_layouts:  []^D3D11_Bind_Group_Layout_Impl,
    push_constants: []Push_Constant_Range,
}

d3d11_pipeline_layout_get_label :: proc(
    pipeline_layout: Pipeline_Layout,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Pipeline_Layout_Impl, pipeline_layout, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_pipeline_layout_set_label :: proc(
    pipeline_layout: Pipeline_Layout,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Pipeline_Layout_Impl, pipeline_layout, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_pipeline_layout_add_ref :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(D3D11_Pipeline_Layout_Impl, pipeline_layout, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_pipeline_layout_release :: proc(pipeline_layout: Pipeline_Layout, loc := #caller_location) {
    impl := get_impl(D3D11_Pipeline_Layout_Impl, pipeline_layout, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        if len(impl.group_layouts) > 0 {
            for &bg_layout in impl.group_layouts {
                d3d11_bind_group_layout_release(Bind_Group_Layout(bg_layout), loc)
            }
            delete(impl.group_layouts)
        }
        if len(impl.push_constants) > 0 {
            delete(impl.push_constants)
        }
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Queue procedures
// -----------------------------------------------------------------------------


D3D11_Queue_Impl :: struct {
    using base: Queue_Base,
}

d3d11_queue_submit :: proc(queue: Queue, commands: []Command_Buffer, loc := #caller_location) {
    // impl := get_impl(D3D11_Queue_Impl, queue, loc)

    // Process each command buffer in order
    for cmdbuf in commands {
        cmdbuf_impl := get_impl(D3D11_Command_Buffer_Impl, cmdbuf, loc)
        encoder_impl := get_impl(D3D11_Command_Encoder_Impl, cmdbuf_impl.encoder, loc)

        // Iterate through all commands in the allocator
        for &cmd in encoder_impl.cmd_allocator.data {
            d3d11_execute_command(encoder_impl, &cmd)
        }

        command_allocator_reset(&encoder_impl.cmd_allocator)
    }
}

d3d11_queue_write_buffer :: proc(
    queue: Queue,
    buffer: Buffer,
    buffer_offset: u64,
    data: rawptr,
    size: uint,
    loc := #caller_location,
) {
    assert(queue != nil, "Invalid queue", loc)
    assert(buffer != nil, "Invalid buffer", loc)
    assert(data != nil, "Invalid data pointer", loc)
    assert(size > 0, "Size must be greater than 0", loc)

    queue_impl := get_impl(D3D11_Queue_Impl, queue, loc)
    buffer_impl := get_impl(D3D11_Buffer_Impl, buffer, loc)
    device_impl := get_impl(D3D11_Device_Impl, queue_impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Validate buffer offset and size
    assert(buffer_offset + u64(size) <= buffer_impl.size,
           "Write would exceed buffer bounds", loc)

    // Check if we have a staging buffer available
    if buffer_impl.staging_buffer != nil {
        // Map the staging buffer
        mapped: d3d11.MAPPED_SUBRESOURCE
        hr := d3d_context->Map(buffer_impl.staging_buffer, 0, .WRITE, {}, &mapped)
        d3d_check(hr, "context->Map failed", loc)

        // Copy data to staging buffer at the specified offset
        dest := ([^]u8)(mapped.pData)[buffer_offset:]
        src := ([^]u8)(data)
        mem.copy(dest, src, int(size))

        // Unmap before copying
        d3d_context->Unmap(buffer_impl.staging_buffer, 0)

        // Copy from staging buffer to main GPU buffer
        src_box := d3d11.BOX {
            left   = u32(buffer_offset),
            top    = 0,
            front  = 0,
            right  = u32(buffer_offset + u64(size)),
            bottom = 1,
            back   = 1,
        }

        d3d_context->CopySubresourceRegion(
            buffer_impl.buffer,          // Destination (GPU buffer)
            0,                           // Dst subresource
            u32(buffer_offset),          // Dst X
            0,                           // Dst Y
            0,                           // Dst Z
            buffer_impl.staging_buffer,  // Source (staging buffer)
            0,                           // Src subresource
            &src_box,                    // Src box (region to copy)
        )

    } else if .Map_Write in buffer_impl.usage {
        // No staging buffer, but buffer is directly mappable (dynamic buffer)
        mapped: d3d11.MAPPED_SUBRESOURCE

        // Use WRITE_DISCARD if writing entire buffer, otherwise WRITE_NO_OVERWRITE
        map_type: d3d11.MAP = buffer_offset == 0 && u64(size) == buffer_impl.size ? \
                              .WRITE_DISCARD : .WRITE_NO_OVERWRITE

        hr := d3d_context->Map(buffer_impl.buffer, 0, map_type, {}, &mapped)
        d3d_check(hr, "context->Map failed", loc)

        // Copy data directly to GPU buffer
        dest := ([^]u8)(mapped.pData)[buffer_offset:]
        src := ([^]u8)(data)
        mem.copy(dest, src, int(size))

        // Unmap after copying
        d3d_context->Unmap(buffer_impl.buffer, 0)

    } else if buffer_offset == 0 && u64(size) == buffer_impl.size {
        // Writing entire buffer to a non-mappable buffer, use UpdateSubresource
        // This is the most efficient path for full buffer updates
        d3d_context->UpdateSubresource(buffer_impl.buffer, 0, nil, data, 0, 0)

    } else {
        // Fallback: create temporary staging buffer for partial write
        // This should rarely happen if buffers are created properly
        log.warnf("Creating temporary staging buffer for partial write - consider using .Copy_Dst usage",
                  location = loc)

        staging_desc := d3d11.BUFFER_DESC{
            ByteWidth      = u32(size),
            Usage          = .STAGING,
            BindFlags      = {},
            CPUAccessFlags = {.WRITE},
            MiscFlags      = {},
        }

        staging_buffer: ^d3d11.IBuffer
        hr := device_impl.d3d_device->CreateBuffer(&staging_desc, nil, &staging_buffer)
        d3d_check(hr, "Failed to create temporary staging buffer", loc)
        defer staging_buffer->Release()

        // Map and write to temporary staging buffer
        mapped: d3d11.MAPPED_SUBRESOURCE
        hr = d3d_context->Map(staging_buffer, 0, .WRITE, {}, &mapped)
        d3d_check(hr, "context->Map failed", loc)

        mem.copy(mapped.pData, data, int(size))

        d3d_context->Unmap(staging_buffer, 0)

        // Copy from staging to destination buffer
        src_box := d3d11.BOX{
            left   = 0,
            top    = 0,
            front  = 0,
            right  = u32(size),
            bottom = 1,
            back   = 1,
        }

        d3d_context->CopySubresourceRegion(
            buffer_impl.buffer,
            0,
            u32(buffer_offset),
            0,
            0,
            staging_buffer,
            0,
            &src_box,
        )
    }
}

d3d11_queue_write_texture :: proc(
    queue: Queue,
    destination: Texel_Copy_Texture_Info,
    data: []byte,
    data_layout: Texel_Copy_Buffer_Layout,
    write_size: Extent_3D,
    loc := #caller_location,
) {
    assert(destination.texture != nil, "Invalid destination texture", loc)

    // Early exit if nothing to write
    if write_size.width == 0 || write_size.height == 0 || write_size.depth_or_array_layers == 0 {
        return
    }

    queue_impl := get_impl(D3D11_Queue_Impl, queue, loc)
    texture_impl := get_impl(D3D11_Texture_Impl, destination.texture, loc)
    device_impl := get_impl(D3D11_Device_Impl, queue_impl.device, loc)
    d3d_context := device_impl.d3d_context

    // Get texture resource based on dimension
    resource: ^d3d11.IResource
    switch texture_impl.dimension {
    case .D1: resource = texture_impl.texture1d
    case .D2: resource = texture_impl.texture2d
    case .D3: resource = texture_impl.texture3d
    case .Undefined: unreachable()
    }

    // Apply data offset
    data_ptr := raw_data(data)
    if data_layout.offset > 0 {
        data_ptr = ([^]u8)(data_ptr)[data_layout.offset:]
    }

    // Calculate pitches
    bytes_per_row := data_layout.bytes_per_row
    rows_per_image := data_layout.rows_per_image

    // Build destination box
    dst_box := d3d11.BOX{
        left   = destination.origin.x,
        top    = destination.origin.y,
        right  = destination.origin.x + write_size.width,
        bottom = destination.origin.y + write_size.height,
    }

    if texture_impl.dimension == .D3 {
        // 3D texture: write entire depth range in one call
        dst_box.front = destination.origin.z
        dst_box.back = destination.origin.z + write_size.depth_or_array_layers

        subresource := destination.mip_level
        depth_pitch := bytes_per_row * rows_per_image

        d3d_context->UpdateSubresource(
            resource,
            subresource,
            &dst_box,
            data_ptr,
            bytes_per_row,
            depth_pitch,
        )
    } else {
        // 1D/2D texture: write each array layer separately
        dst_box.front = 0
        dst_box.back = 1
        box_ptr := &dst_box

        // Calculate bytes per layer
        bytes_per_layer := bytes_per_row * rows_per_image

        // Write each array layer
        for layer in 0 ..< write_size.depth_or_array_layers {
            subresource := d3d11.CalcSubresource(
                destination.mip_level,
                destination.origin.z + layer,
                texture_impl.mip_level_count,
            )

            d3d_context->UpdateSubresource(
                resource,
                subresource,
                box_ptr,
                data_ptr,
                bytes_per_row,
                0,
            )

            // Advance to next layer
            data_ptr = ([^]u8)(data_ptr)[bytes_per_layer:]
        }
    }
}

@(require_results)
d3d11_queue_get_label :: proc(queue: Queue, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Instance_Impl, queue, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_queue_set_label :: proc(queue: Queue, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Instance_Impl, queue, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_queue_add_ref :: proc(queue: Queue, loc := #caller_location) {
    impl := get_impl(D3D11_Instance_Impl, queue, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_queue_release :: proc(queue: Queue, loc := #caller_location) {
}

// -----------------------------------------------------------------------------
// Sampler procedures
// -----------------------------------------------------------------------------


D3D11_Sampler_Impl :: struct {
    using base: Sampler_Base,
    sampler_state: ^d3d11.ISamplerState,
}

@(require_results)
d3d11_sampler_get_label :: proc(sampler: Sampler, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Sampler_Impl, sampler, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_sampler_set_label :: proc(sampler: Sampler, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Sampler_Impl, sampler, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_sampler_add_ref :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(D3D11_Sampler_Impl, sampler, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_sampler_release :: proc(sampler: Sampler, loc := #caller_location) {
    impl := get_impl(D3D11_Sampler_Impl, sampler, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        impl.sampler_state->Release()
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Shader Module procedures
// -----------------------------------------------------------------------------


D3D11_Shader_Module_Impl :: struct {
    using base:     Shader_Module_Base,

    // Shader bytecode
    bytecode:       []u8,
    entry_point:    String_Buffer_Small,

    // D3D11 shader objects (only one will be non-nil based on stage)
    vertex_shader:  ^d3d11.IVertexShader,
    pixel_shader:   ^d3d11.IPixelShader,
    compute_shader: ^d3d11.IComputeShader,
}

@(require_results)
d3d11_shader_module_get_label :: proc(
    shader_module: Shader_Module,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Shader_Module_Impl, shader_module, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_shader_module_set_label :: proc(
    shader_module: Shader_Module,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Shader_Module_Impl, shader_module, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_shader_module_add_ref :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(D3D11_Shader_Module_Impl, shader_module, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_shader_module_release :: proc(shader_module: Shader_Module, loc := #caller_location) {
    impl := get_impl(D3D11_Shader_Module_Impl, shader_module, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.vertex_shader != nil {
            impl.vertex_shader->Release()
            impl.vertex_shader = nil
        }
        if impl.pixel_shader != nil {
            impl.pixel_shader->Release()
            impl.pixel_shader = nil
        }
        if impl.compute_shader != nil {
            impl.compute_shader->Release()
            impl.compute_shader = nil
        }

        delete(impl.bytecode)

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Surface procedures
// -----------------------------------------------------------------------------


D3D11_Surface_Impl :: struct {
    // Base
    using base:            Surface_Base,

    // Backend
    hinstance:             win32.HINSTANCE,
    hwnd:                  win32.HWND,
    dxgi_swapchain_desc:   dxgi.SWAP_CHAIN_DESC1,
    dxgi_swapchain:        ^dxgi.ISwapChain1,
    framebuffer:           ^d3d11.ITexture2D,
    framebuffer_impl:      ^D3D11_Texture_Impl,
    framebuffer_view:      ^d3d11.IRenderTargetView,
    framebuffer_view_impl: ^D3D11_Texture_View_Impl,
}

d3d11_surface_get_capabilities :: proc(
    surface: Surface,
    adapter: Adapter,
    allocator := context.allocator,
    loc := #caller_location,
) -> (
    caps: Surface_Capabilities,
) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    instance_impl := get_impl(D3D11_Instance_Impl, impl.instance, loc)

    formats := make([dynamic]Texture_Format, allocator)
    append(&formats, ..[]Texture_Format{
        .Bgra8_Unorm_Srgb,
        .Bgra8_Unorm,
        .Rgba8_Unorm_Srgb,
        .Rgba8_Unorm,
        .Rgb10a2_Unorm,
        .Rgba16_Float,
    })

    present_modes := make([dynamic]Present_Mode, allocator)
    append(&present_modes, ..[]Present_Mode{.Fifo, .Mailbox})
    if instance_impl.allow_tearing {
        append(&present_modes, Present_Mode.Immediate)
    }

    alpha_modes := make([dynamic]Composite_Alpha_Mode, allocator)
    append(&alpha_modes, ..[]Composite_Alpha_Mode{.Opaque})

    caps.formats = formats[:]
    caps.present_modes = present_modes[:]
    caps.alpha_modes = alpha_modes[:]
    caps.usages = {.Render_Attachment, .Copy_Src, .Copy_Dst}

    return
}

d3d11_surface_capabilities_free_members :: proc(
    caps: Surface_Capabilities,
    allocator := context.allocator,
) {
    context.allocator = allocator
    delete(caps.formats)
    delete(caps.present_modes)
    delete(caps.alpha_modes)
}

d3d11_surface_configure :: proc(
    surface: Surface,
    device: Device,
    config: Surface_Configuration,
    loc := #caller_location,
) {
    assert(config.width != 0, "Surface width must be > 0", loc)
    assert(config.height != 0, "Surface height must be > 0", loc)

    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    device_impl := get_impl(D3D11_Device_Impl, device, loc)
    instance_impl := get_impl(D3D11_Instance_Impl, impl.instance, loc)

    assert(instance_impl.dxgi_factory != nil, loc = loc)

    // Clean up existing resources if reconfiguring
    if impl.framebuffer_view_impl != nil {
        if impl.framebuffer_view_impl.rtv != nil {
            impl.framebuffer_view_impl.rtv->Release()
            impl.framebuffer_view_impl.rtv = nil
        }
        free(impl.framebuffer_view_impl, impl.allocator)
        impl.framebuffer_view_impl = nil
    }

    if impl.framebuffer_impl != nil {
        if impl.framebuffer_impl.texture2d != nil {
            impl.framebuffer_impl.texture2d->Release()
            impl.framebuffer_impl.texture2d = nil
        }
        free(impl.framebuffer_impl, impl.allocator)
        impl.framebuffer_impl = nil
    }

    if impl.dxgi_swapchain != nil {
        impl.dxgi_swapchain->Release()
        impl.dxgi_swapchain = nil
    }

    buffer_count := d3d_present_mode_to_buffer_count(config.present_mode)
    dxgi_format := d3d_dxgi_texture_format(config.format)
    dxgi_usage := d3d_to_dxgi_usage(config.usage)
    swapchain_flags :=  d3d_present_mode_to_swap_chain_flags(config.present_mode)

    swapchain_desc := dxgi.SWAP_CHAIN_DESC1 {
        Width       = config.width,
        Height      = config.height,
        Format      = dxgi_format,
        Stereo      = false,
        SampleDesc  = { Count = 1 },
        BufferUsage = dxgi_usage,
        BufferCount = buffer_count,
        Scaling     = .STRETCH,
        SwapEffect  = .FLIP_DISCARD,
        AlphaMode   = .IGNORE,
        Flags       = swapchain_flags,
    }

    dxgi_factory := instance_impl.dxgi_factory
    hr: win32.HRESULT

    // Query for ISwapChain1
    dxgi_swapchain: ^dxgi.ISwapChain1
    hr = dxgi_factory->CreateSwapChainForHwnd(
        pDevice           = device_impl.d3d_device,
        hWnd              = impl.hwnd,
        pDesc             = &swapchain_desc,
        pFullscreenDesc   = nil,
        pRestrictToOutput = nil,
        ppSwapChain       = &dxgi_swapchain,
    )
    d3d_check(hr, "dxgi_factory.CreateSwapChainForHwnd failed", loc)

    // Disable Alt+Enter fullscreen toggle
    dxgi_factory->MakeWindowAssociation(impl.hwnd, { .NO_ALT_ENTER })

    // Get backbuffer
    framebuffer: ^d3d11.ITexture2D
    // https://learn.microsoft.com/en-us/windows/win32/api/dxgi/ne-dxgi-dxgi_swap_effect
    // According to docs, since our DXGISwapChain uses DXGI_SWAP_EFFECT_FLIP_DISCARD,
    // which means only buffer 0 is accessible for read/write when using D3D11.
    dxgi_swapchain->GetBuffer(0, d3d11.ITexture2D_UUID, (^rawptr)(&framebuffer))
    d3d_check(hr, "dxgi_swapchain.GetBuffer failed", loc)

    // Create texture impl for framebuffer
    texture_impl := new(D3D11_Texture_Impl, impl.allocator)
    assert(texture_impl != nil, "Failed to allocate memory for the framebuffer Texture", loc)

    // Initialize texture
    texture_impl.allocator         = impl.allocator
    texture_impl.device            = device
    texture_impl.surface           = surface
    texture_impl.usage             = config.usage
    texture_impl.format            = config.format
    texture_impl.dimension         = .D2
    texture_impl.size              = {config.width, config.height, 1}
    texture_impl.mip_level_count   = 1
    texture_impl.array_layer_count = 1
    texture_impl.sample_count      = 1
    texture_impl.is_swapchain      = true
    texture_impl.texture2d         = framebuffer
    texture_impl.dxgi_format       = dxgi_format

    // Create render target view
    framebuffer_view: ^d3d11.IRenderTargetView
    device_impl.d3d_device->CreateRenderTargetView(framebuffer, nil, &framebuffer_view)
    d3d_check(hr, "d3d_device->CreateRenderTargetView failed", loc)

    // Create texture view impl for framebuffer
    view_impl := new(D3D11_Texture_View_Impl, impl.allocator)
    assert(view_impl != nil, "Failed to allocate memory for the framebuffer Texture", loc)

    // Initialize texture view
    view_impl.format            = config.format
    view_impl.dimension         = .D2
    view_impl.usage             = config.usage
    view_impl.texture           = Texture(texture_impl)
    view_impl.aspect            = .All
    view_impl.base_mip_level    = 0
    view_impl.mip_level_count   = 1
    view_impl.base_array_layer  = 0
    view_impl.array_layer_count = 1
    view_impl.is_swapchain      = true
    view_impl.rtv               = framebuffer_view

    // Update surface impl
    impl.device                = device
    impl.config                = config
    impl.dxgi_swapchain_desc   = swapchain_desc
    impl.dxgi_swapchain        = dxgi_swapchain
    impl.framebuffer           = framebuffer
    impl.framebuffer_impl      = texture_impl
    impl.framebuffer_view      = framebuffer_view
    impl.framebuffer_view_impl = view_impl
}

@(require_results)
d3d11_surface_get_current_texture :: proc(
    surface: Surface,
    loc := #caller_location,
) -> (
    texture: Surface_Texture,
) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    texture.surface = surface
    texture.texture = Texture(impl.framebuffer_impl)
    texture.status = .Success_Optimal
    return
}

d3d11_surface_present :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    sync_interval := d3d_present_mode_to_swap_interval(impl.config.present_mode)
    hr := impl.dxgi_swapchain->Present(sync_interval, {})
    d3d_check(hr, "Failed to present", loc)
}

@(require_results)
d3d11_surface_get_label :: proc(surface: Surface, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_surface_set_label :: proc(surface: Surface, label: string, loc := #caller_location) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_surface_add_ref :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_surface_release :: proc(surface: Surface, loc := #caller_location) {
    impl := get_impl(D3D11_Surface_Impl, surface, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        if impl.framebuffer_view != nil {
            impl.framebuffer_view->Release()
            free(impl.framebuffer_view_impl)
        }
        if impl.framebuffer != nil {
            impl.framebuffer->Release()
            free(impl.framebuffer_impl)
        }
        if impl.dxgi_swapchain != nil { impl.dxgi_swapchain->Release() }
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Render Pass procedures
// -----------------------------------------------------------------------------


D3D11_Render_Pass_Impl :: struct {
    // Base
    label:     String_Buffer_Small,
    ref:       Ref_Count,
    device:    Device,
    encoder:   Command_Encoder,
    allocator: runtime.Allocator,
    encoding:  bool,

    // Backend
    pipeline:  Render_Pipeline,
}

d3d11_render_pass_draw :: proc(
    render_pass: Render_Pass,
    vertices: Range(u32),
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Draw)
    assert(cmd != nil, loc = loc)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.vertex_count = vertices.end - vertices.start
    cmd.instance_count = instances.end - instances.start
    cmd.first_vertex = vertices.start
    cmd.first_instance = instances.start
}

d3d11_render_pass_draw_indexed :: proc(
    render_pass: Render_Pass,
    indices: Range(u32),
    base_vertex: i32,
    instances: Range(u32) = {start = 0, end = 1},
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Draw_Indexed)
    assert(cmd != nil, loc = loc)

    cmd.render_pass = render_pass
    cmd.index_count = indices.end - indices.start
    cmd.instance_count = instances.end - instances.start
    cmd.first_index = indices.start
    cmd.vertex_offset = base_vertex
    cmd.first_instance = instances.start
}

d3d11_render_pass_end :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    assert(impl.encoding, "Render pass is not currently encoding", loc)

    // Allocate end command
    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(&encoder_impl.cmd_allocator, Command_Render_Pass_End, loc)
    cmd.render_pass = render_pass
    assert(cmd != nil, loc = loc)

    impl.encoding = false // Mark render pass as no longer encoding
}

d3d11_render_pass_set_scissor_rect :: proc(
    render_pass: Render_Pass,
    x: u32,
    y: u32,
    width: u32,
    height: u32,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Scissor_Rect)
    assert(cmd != nil)

    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
}

d3d11_render_pass_set_viewport :: proc(
    render_pass: Render_Pass,
    x: f32,
    y: f32,
    width: f32,
    height: f32,
    min_depth: f32,
    max_depth: f32,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Viewport)
    assert(cmd != nil)

    cmd.x = x
    cmd.y = y
    cmd.width = width
    cmd.height = height
    cmd.min_depth = min_depth
    cmd.max_depth = max_depth
}

d3d11_render_pass_set_stencil_reference :: proc(
    render_pass: Render_Pass,
    reference: u32,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Stencil_Reference)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.reference = reference
}

d3d11_render_pass_set_bind_group :: proc(
    render_pass: Render_Pass,
    group_index: u32,
    group: Bind_Group,
    dynamic_offsets: []u32 = {},
    loc := #caller_location,
) {
    assert(group != nil, "Invalid bind group", loc)
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)

    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Bind_Group)
    cmd.render_pass = render_pass
    cmd.group_index = group_index
    cmd.group = group
    if len(dynamic_offsets) > 0 {
        cmd.dynamic_offsets =
            make([]u32, len(dynamic_offsets), encoder_impl.cmd_allocator.allocator)
        copy(cmd.dynamic_offsets, dynamic_offsets)
    }

    assert(cmd != nil, loc = loc)
}

d3d11_render_pass_set_pipeline :: proc(
    render_pass: Render_Pass,
    pipeline: Render_Pipeline,
    loc := #caller_location,
) {
    assert(pipeline != nil, "Invalid render pipeline", loc)
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)

    impl.pipeline = pipeline

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Render_Pipeline)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.pipeline = pipeline
}

d3d11_render_pass_set_vertex_buffer :: proc(
    render_pass: Render_Pass,
    slot: u32,
    buffer: Buffer,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid vertex buffer", loc)
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    assert(impl.pipeline != nil, "No Render Pipeline is bound", loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Vertex_Buffer)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.pipeline = impl.pipeline
    cmd.slot = slot
    cmd.buffer = buffer
    cmd.offset = offset
    cmd.size = size
}

d3d11_render_pass_set_index_buffer :: proc(
    render_pass: Render_Pass,
    buffer: Buffer,
    format: Index_Format,
    offset: u64,
    size: u64,
    loc := #caller_location,
) {
    assert(buffer != nil, "Invalid index buffer", loc)
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    assert(impl.pipeline != nil, "No Render Pipeline is bound", loc)

    encoder_impl := get_impl(D3D11_Command_Encoder_Impl, impl.encoder, loc)
    cmd := command_allocator_allocate(
        &encoder_impl.cmd_allocator, Command_Render_Pass_Set_Index_Buffer)
    assert(cmd != nil)

    cmd.render_pass = render_pass
    cmd.buffer = buffer
    cmd.format = format
    cmd.offset = offset
    cmd.size = size
}

@(require_results)
d3d11_render_pass_get_label :: proc(render_pass: Render_Pass, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_render_pass_set_label :: proc(
    render_pass: Render_Pass,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_render_pass_add_ref :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_render_pass_release :: proc(render_pass: Render_Pass, loc := #caller_location) {
    impl := get_impl(D3D11_Render_Pass_Impl, render_pass, loc)
    assert(impl.encoding == false, "Render pass encoder still recording", loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator
        d3d11_command_encoder_release(impl.encoder, loc)
        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Render Pipeline procedures
// -----------------------------------------------------------------------------


D3D11_Vertex_Buffer_Info :: struct {
    stride:     u32,
    step_mode:  Vertex_Step_Mode,
    attributes: []Vertex_Attribute,
}

D3D11_Render_Pipeline_Impl :: struct {
    using base:          Render_Pipeline_Base,

    // Shaders
    vertex_shader:        ^d3d11.IVertexShader,
    pixel_shader:         ^d3d11.IPixelShader,

    // Pipeline state
    input_layout:         ^d3d11.IInputLayout,
    rasterizer_state:     ^d3d11.IRasterizerState,
    blend_state:          ^d3d11.IBlendState,
    depth_stencil_state:  ^d3d11.IDepthStencilState,

    // Cached state
    primitive_topology:   d3d11.PRIMITIVE_TOPOLOGY,
    sample_mask:          u32,
    strip_index_format:   Index_Format,

    // Vertex buffer layout (cached from descriptor)
    vertex_buffers:       []D3D11_Vertex_Buffer_Info,

    // Pipeline layout
    layout:               Pipeline_Layout,
}

@(require_results)
d3d11_render_pipeline_get_label :: proc(
    render_pipeline: Render_Pipeline,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Render_Pipeline_Impl, render_pipeline, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_render_pipeline_set_label :: proc(
    render_pipeline: Render_Pipeline,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Render_Pipeline_Impl, render_pipeline, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_render_pipeline_add_ref :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(D3D11_Render_Pipeline_Impl, render_pipeline, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_render_pipeline_release :: proc(render_pipeline: Render_Pipeline, loc := #caller_location) {
    impl := get_impl(D3D11_Render_Pipeline_Impl, render_pipeline, loc)
    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.vertex_buffers != nil {
            for &vb_info in impl.vertex_buffers {
                if vb_info.attributes != nil {
                    delete(vb_info.attributes)
                }
            }
            delete(impl.vertex_buffers)
            impl.vertex_buffers = nil
        }

        if impl.depth_stencil_state != nil {
            impl.depth_stencil_state->Release()
            impl.depth_stencil_state = nil
        }

        if impl.blend_state != nil {
            impl.blend_state->Release()
            impl.blend_state = nil
        }

        if impl.rasterizer_state != nil {
            impl.rasterizer_state->Release()
            impl.rasterizer_state = nil
        }

        if impl.input_layout != nil {
            impl.input_layout->Release()
            impl.input_layout = nil
        }

        if impl.pixel_shader != nil {
            impl.pixel_shader->Release()
            impl.pixel_shader = nil
        }

        if impl.vertex_shader != nil {
            impl.vertex_shader->Release()
            impl.vertex_shader = nil
        }

        if impl.layout != nil {
            pipeline_layout_release(impl.layout, loc)
            impl.layout = nil
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Texture procedures
// -----------------------------------------------------------------------------


D3D11_Texture_Impl :: struct {
    // Base
    using base:      Texture_Base,

    // Backend
    surface:         Surface,
    texture1d:       ^d3d11.ITexture1D,
    texture2d:       ^d3d11.ITexture2D,
    texture3d:       ^d3d11.ITexture3D,
    dxgi_format:     dxgi.FORMAT,

    // For typeless depth textures
    typeless_format: dxgi.FORMAT,
    dsv_format:      dxgi.FORMAT,
    srv_format:      dxgi.FORMAT,
}

@(require_results)
d3d11_texture_create_view :: proc(
    texture: Texture,
    descriptor: Texture_View_Descriptor,
    loc := #caller_location,
) -> Texture_View {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)

    // For swapchain textures, return the existing framebuffer view
    if impl.is_swapchain {
        surface_impl := get_impl(D3D11_Surface_Impl, impl.surface, loc)
        return Texture_View(surface_impl.framebuffer_view_impl)
    }

    view_impl := texture_new_handle(D3D11_Texture_View_Impl, texture, loc)

    view_impl.format = descriptor.format
    view_impl.dimension = descriptor.dimension
    view_impl.usage = descriptor.usage
    view_impl.aspect = descriptor.aspect
    view_impl.base_mip_level = descriptor.base_mip_level
    view_impl.mip_level_count = descriptor.mip_level_count
    view_impl.base_array_layer = descriptor.base_array_layer
    view_impl.array_layer_count = descriptor.array_layer_count

    if len(descriptor.label) > 0 {
        string_buffer_init(&view_impl.label, descriptor.label)
    }

    // Get device for view creation
    device_impl := get_impl(D3D11_Device_Impl, impl.device, loc)

    // Create appropriate D3D11 views based on usage and format
    is_depth_stencil := texture_format_is_depth_stencil_format(view_impl.format)

    if .Render_Attachment in view_impl.usage {
        if is_depth_stencil {
            d3d11_create_depth_stencil_view(device_impl, impl, view_impl)
        } else {
            d3d11_create_render_target_view(device_impl, impl, view_impl)
        }
    }

    if .Texture_Binding in view_impl.usage {
        d3d11_create_shader_resource_view(device_impl, impl, view_impl)
    }

    if .Storage_Binding in view_impl.usage {
        d3d11_create_unordered_access_view(device_impl, impl, view_impl)
    }

    return Texture_View(view_impl)
}

@(require_results)
d3d11_texture_get_descriptor :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Descriptor {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    desc: Texture_Descriptor
    // label
    desc.usage = impl.usage
    desc.dimension = impl.dimension
    desc.size = impl.size
    desc.size = impl.size
    desc.format = impl.format
    desc.mip_level_count = impl.mip_level_count
    desc.sample_count = impl.sample_count
    // view_formats
    return desc
}

@(require_results)
d3d11_texture_get_dimension :: proc(
    texture: Texture,
    loc := #caller_location,
) -> Texture_Dimension {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.dimension
}

@(require_results)
d3d11_texture_get_format :: proc(texture: Texture, loc := #caller_location) -> Texture_Format {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.format
}

@(require_results)
d3d11_texture_get_height :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.size.height
}

@(require_results)
d3d11_texture_get_mip_level_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.mip_level_count
}

@(require_results)
d3d11_texture_get_sample_count :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.sample_count
}

@(require_results)
d3d11_texture_get_size :: proc(texture: Texture, loc := #caller_location) -> Extent_3D {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.size
}

@(require_results)
d3d11_texture_get_usage :: proc(texture: Texture, loc := #caller_location) -> Texture_Usages {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.usage
}

@(require_results)
d3d11_texture_get_width :: proc(texture: Texture, loc := #caller_location) -> u32 {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return impl.size.width
}

@(require_results)
d3d11_texture_get_label :: proc(texture: Texture, loc := #caller_location) -> string {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_texture_set_label :: proc(
    texture: Texture,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_texture_add_ref :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_texture_release :: proc(texture: Texture, loc := #caller_location) {
    impl := get_impl(D3D11_Texture_Impl, texture, loc)

    if impl.is_swapchain {
        return
    }

    if release := ref_count_sub(&impl.ref, loc); release {
        context.allocator = impl.allocator

        if impl.texture1d != nil {
            impl.texture1d->Release()
            impl.texture1d = nil
        }

        if impl.texture2d != nil {
            impl.texture2d->Release()
            impl.texture2d = nil
        }

        if impl.texture3d != nil {
            impl.texture3d->Release()
            impl.texture3d = nil
        }

        free(impl)
    }
}

// -----------------------------------------------------------------------------
// Texture View procedures
// -----------------------------------------------------------------------------


D3D11_Texture_View_Impl :: struct {
    // Base
    using base: Texture_View_Base,

    // Backend
    rtv:        ^d3d11.IRenderTargetView,    // Render target view
    dsv:        ^d3d11.IDepthStencilView,    // Depth stencil view
    srv:        ^d3d11.IShaderResourceView,  // Shader resource view
    uav:        ^d3d11.IUnorderedAccessView, // Unordered access view
}

@(require_results)
d3d11_texture_view_get_label :: proc(
    texture_view: Texture_View,
    loc := #caller_location,
) -> string {
    impl := get_impl(D3D11_Texture_View_Impl, texture_view, loc)
    return string_buffer_get_string(&impl.label)
}

d3d11_texture_view_set_label :: proc(
    texture_view: Texture_View,
    label: string,
    loc := #caller_location,
) {
    impl := get_impl(D3D11_Texture_View_Impl, texture_view, loc)
    string_buffer_init(&impl.label, label)
}

d3d11_texture_view_add_ref :: proc(texture_view: Texture_View, loc := #caller_location) {
    impl := get_impl(D3D11_Texture_View_Impl, texture_view, loc)
    ref_count_add(&impl.ref, loc)
}

d3d11_texture_view_release :: proc(view: Texture_View, loc := #caller_location) {
    impl := get_impl(D3D11_Texture_View_Impl, view, loc)

    // Don't release swapchain views here
    if impl.is_swapchain {
        return
    }

    if release := ref_count_sub(&impl.ref, loc); release {
        if impl.rtv != nil {
            impl.rtv->Release()
            impl.rtv = nil
        }

        if impl.dsv != nil {
            impl.dsv->Release()
            impl.dsv = nil
        }

        if impl.srv != nil {
            impl.srv->Release()
            impl.srv = nil
        }

        if impl.uav != nil {
            impl.uav->Release()
            impl.uav = nil
        }

        if impl.texture != nil {
            d3d11_texture_release(impl.texture, loc)
        }

        free(impl, impl.allocator)
    }
}

d3d11_create_render_target_view :: proc(
    device_impl: ^D3D11_Device_Impl,
    texture_impl: ^D3D11_Texture_Impl,
    view_impl: ^D3D11_Texture_View_Impl,
    loc := #caller_location,
) {
    desc := d3d11.RENDER_TARGET_VIEW_DESC{
        Format = d3d_dxgi_texture_format(view_impl.format),
    }

    // Set view dimension
    #partial switch view_impl.dimension {
    case .D1:
        desc.ViewDimension = .TEXTURE1D
        desc.Texture1D.MipSlice = view_impl.base_mip_level
    case .D2:
        if texture_impl.sample_count > 1 {
            desc.ViewDimension = .TEXTURE2DMS
        } else {
            desc.ViewDimension = .TEXTURE2D
            desc.Texture2D.MipSlice = view_impl.base_mip_level
        }
    case .Cube:
        desc.ViewDimension = .TEXTURE2DARRAY
        desc.Texture2DArray = {
            MipSlice        = view_impl.base_mip_level,
            FirstArraySlice = view_impl.base_array_layer,
            ArraySize       = view_impl.array_layer_count,
        }
    case .D3:
        desc.ViewDimension = .TEXTURE3D
        desc.Texture3D = {
            MipSlice    = view_impl.base_mip_level,
            FirstWSlice = view_impl.base_array_layer,
            WSize       = view_impl.array_layer_count,
        }
    case:
        log.panicf("Invalid texture view dimension", location = loc)
    }

    hr := device_impl.d3d_device->CreateRenderTargetView(
        texture_impl.texture2d,
        &desc,
        &view_impl.rtv,
    )
    d3d_check(hr, "CreateRenderTargetView failed", loc)
}

d3d11_create_depth_stencil_view :: proc(
    device_impl: ^D3D11_Device_Impl,
    texture_impl: ^D3D11_Texture_Impl,
    view_impl: ^D3D11_Texture_View_Impl,
    loc := #caller_location,
) {
    desc := d3d11.DEPTH_STENCIL_VIEW_DESC{
        Format = d3d_dxgi_texture_format(view_impl.format),
    }

    // Set view dimension
    #partial switch view_impl.dimension {
    case .D1:
        desc.ViewDimension = .TEXTURE1D
        desc.Texture1D.MipSlice = view_impl.base_mip_level
    case .D2:
        if texture_impl.sample_count > 1 {
            desc.ViewDimension = .TEXTURE2DMS
        } else {
            desc.ViewDimension = .TEXTURE2D
            desc.Texture2D.MipSlice = view_impl.base_mip_level
        }
    case .Cube:
        desc.ViewDimension = .TEXTURE2DARRAY
        desc.Texture2DArray = {
            MipSlice        = view_impl.base_mip_level,
            FirstArraySlice = view_impl.base_array_layer,
            ArraySize       = view_impl.array_layer_count,
        }
    case .D3:
        log.panicf("3D textures cannot be used as depth stencil views", location = loc)
    case:
        log.panicf("Invalid texture view dimension for depth stencil", location = loc)
    }

    hr := device_impl.d3d_device->CreateDepthStencilView(
        texture_impl.texture2d,
        &desc,
        &view_impl.dsv,
    )
    d3d_check(hr, "CreateDepthStencilView failed", loc)
}

d3d11_create_shader_resource_view :: proc(
    device_impl: ^D3D11_Device_Impl,
    texture_impl: ^D3D11_Texture_Impl,
    view_impl: ^D3D11_Texture_View_Impl,
    loc := #caller_location,
) {
    desc := d3d11.SHADER_RESOURCE_VIEW_DESC{
        Format = d3d_dxgi_texture_format(view_impl.format),
    }

    // Set view dimension
    #partial switch view_impl.dimension {
    case .D1:
        desc.ViewDimension = .TEXTURE1D
        desc.Texture1D = {
            MostDetailedMip = view_impl.base_mip_level,
            MipLevels       = view_impl.mip_level_count,
        }
    case .D2:
        if texture_impl.sample_count > 1 {
            desc.ViewDimension = .TEXTURE2DMS
        } else {
            desc.ViewDimension = .TEXTURE2D
            desc.Texture2D = {
                MostDetailedMip = view_impl.base_mip_level,
                MipLevels       = view_impl.mip_level_count,
            }
        }
    case .Cube:  // Add cubemap support
        desc.ViewDimension = .TEXTURECUBE
        desc.TextureCube = {
            MostDetailedMip = view_impl.base_mip_level,
            MipLevels       = view_impl.mip_level_count,
        }
    case .D3:
        desc.ViewDimension = .TEXTURE3D
        desc.Texture3D = {
            MostDetailedMip = view_impl.base_mip_level,
            MipLevels       = view_impl.mip_level_count,
        }
    case:
        log.panicf("Invalid texture view dimension", location = loc)
    }

    hr := device_impl.d3d_device->CreateShaderResourceView(
        texture_impl.texture2d,
        &desc,
        &view_impl.srv,
    )
    d3d_check(hr, "CreateShaderResourceView failed", loc)
}

d3d11_create_unordered_access_view :: proc(
    device_impl: ^D3D11_Device_Impl,
    texture_impl: ^D3D11_Texture_Impl,
    view_impl: ^D3D11_Texture_View_Impl,
    loc := #caller_location,
) {
    desc := d3d11.UNORDERED_ACCESS_VIEW_DESC{
        Format = d3d_dxgi_texture_format(view_impl.format),
    }

    // Set view dimension
    #partial switch view_impl.dimension {
    case .D1:
        desc.ViewDimension = .TEXTURE1D
        desc.Texture1D.MipSlice = view_impl.base_mip_level
    case .D2:
        desc.ViewDimension = .TEXTURE2D
        desc.Texture2D.MipSlice = view_impl.base_mip_level
    case .Cube:
        desc.ViewDimension = .TEXTURE2DARRAY
        desc.Texture2DArray = {
            MipSlice        = view_impl.base_mip_level,
            FirstArraySlice = view_impl.base_array_layer,
            ArraySize       = view_impl.array_layer_count,
        }
    case .D3:
        desc.ViewDimension = .TEXTURE3D
        desc.Texture3D = {
            MipSlice    = view_impl.base_mip_level,
            FirstWSlice = view_impl.base_array_layer,
            WSize       = view_impl.array_layer_count,
        }
    case:
        log.panicf("Invalid texture view dimension", location = loc)
    }

    hr := device_impl.d3d_device->CreateUnorderedAccessView(
        texture_impl.texture2d,
        &desc,
        &view_impl.uav,
    )
    d3d_check(hr, "CreateUnorderedAccessView failed", loc)
}
