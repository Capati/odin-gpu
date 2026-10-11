#+build windows
#+private
package gpu

// Core
import win32 "core:sys/windows"

// Vendor
import "vendor:directx/dxgi"
import "vendor:directx/d3d11"

D3D11_CONTEXT_TYPE :: enum i32 {
    ALL     = 0,
    D3      = 1,
    COMPUTE = 2,
    COPY    = 3,
    VIDEO   = 4,
}

D3D11_TEXTURE_LAYOUT :: enum i32 {
    UNDEFINED             = 0,
    ROW_MAJOR             = 1,
    _64K_STANDARD_SWIZZLE = 2,
}

D3D11_TEXTURE2D_DESC1 :: struct {
    Width:          win32.UINT,
    Height:         win32.UINT,
    MipLevels:      win32.UINT,
    ArraySize:      win32.UINT,
    Format:         dxgi.FORMAT,
    SampleDesc:     dxgi.SAMPLE_DESC,
    Usage:          d3d11.USAGE,
    BindFlags:      d3d11.BIND_FLAGS,
    CPUAccessFlags: d3d11.CPU_ACCESS_FLAGS,
    MiscFlags:      d3d11.RESOURCE_MISC_FLAGS,
    TextureLayout:  D3D11_TEXTURE_LAYOUT,
}

D3D11_TEXTURE2D_DESC1_INIT :: D3D11_TEXTURE2D_DESC1 {
    Width          = 0,
    Height         = 0,
    MipLevels      = 0,
    ArraySize      = 1,
    Format         = .UNKNOWN,
    SampleDesc     = {1, 0},
    Usage          = .DEFAULT,
    BindFlags      = {.SHADER_RESOURCE},
    CPUAccessFlags = {},
    MiscFlags      = {},
    TextureLayout  = .UNDEFINED,
}

D3D11_ITexture2D1_UUID_STRING :: "51218251-1E33-4617-9CCB-4D3A4367E7BB"
D3D11_ITexture2D1_UUID :=
    &win32.IID{0x51218251,0x1E33,0x4617,{0x9C,0xCB,0x4D,0x3A,0x43,0x67,0xE7,0xBB}}
D3D11_ITexture2D1 :: struct #raw_union {
    #subtype itexture2d: d3d11.ITexture2D,
    using itexture2d1_vtable: ^D3D11_ITexture2D1_VTable,
}
D3D11_ITexture2D1_VTable :: struct {
    using itexture2d_vtable: d3d11.ITexture2D_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_ITexture2D1,
        pDesc: ^D3D11_TEXTURE2D_DESC1),
}

D3D11_TEXTURE3D_DESC1 :: struct {
    Width:          win32.UINT,
    Height:         win32.UINT,
    Depth:          win32.UINT,
    MipLevels:      win32.UINT,
    Format:         dxgi.FORMAT,
    Usage:          d3d11.USAGE,
    BindFlags:      d3d11.BIND_FLAGS,
    CPUAccessFlags: d3d11.CPU_ACCESS_FLAGS,
    MiscFlags:      d3d11.RESOURCE_MISC_FLAGS,
    TextureLayout:  D3D11_TEXTURE_LAYOUT,
}

D3D11_TEXTURE3D_DESC1_INIT :: D3D11_TEXTURE3D_DESC1 {
    Width          = 0,
    Height         = 0,
    Depth          = 0,
    MipLevels      = 0,
    Format         = .UNKNOWN,
    Usage          = .DEFAULT,
    BindFlags      = {.SHADER_RESOURCE},
    CPUAccessFlags = {},
    MiscFlags      = {},
    TextureLayout  = .UNDEFINED,
}

D3D11_ITexture3D1_UUID_STRING :: "0C711683-2853-4846-9BB0-F3E60639E46A"
D3D11_ITexture3D1_UUID :=
    &win32.IID{0x0C711683,0x2853,0x4846,{0x9B,0xB0,0xF3,0xE6,0x06,0x39,0xE4,0x6A}}
D3D11_ITexture3D1 :: struct #raw_union {
    #subtype itexture3d: d3d11.ITexture3D,
    using itexture3d1_vtable: ^D3D11_ITexture3D1_VTable,
}
D3D11_ITexture3D1_VTable :: struct {
    using ITexture3D_vtable: d3d11.ITexture3D_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_ITexture3D1,
        pDesc: ^D3D11_TEXTURE3D_DESC1),
}

D3D11_CONSERVATIVE_RASTERIZATION_MODE :: enum i32 {
    OFF = 0,
    ON  = 1,
}

D3D11_RASTERIZER_DESC2 :: struct {
    FillMode:              d3d11.FILL_MODE,
    CullMode:              d3d11.CULL_MODE,
    FrontCounterClockwise: win32.BOOL,
    DepthBias:             win32.INT,
    DepthBiasClamp:        f32,
    SlopeScaledDepthBias:  f32,
    DepthClipEnable:       win32.BOOL,
    ScissorEnable:         win32.BOOL,
    MultisampleEnable:     win32.BOOL,
    AntialiasedLineEnable: win32.BOOL,
    ForcedSampleCount:     win32.UINT,
    ConservativeRaster:    D3D11_CONSERVATIVE_RASTERIZATION_MODE,
}

D3D11_RASTERIZER_DESC2_INIT :: D3D11_RASTERIZER_DESC2 {
    FillMode              = .SOLID,
    CullMode              = .BACK,
    FrontCounterClockwise = false,
    DepthBias             = d3d11.DEFAULT_DEPTH_BIAS,
    DepthBiasClamp        = d3d11.DEFAULT_DEPTH_BIAS_CLAMP,
    SlopeScaledDepthBias  = d3d11.DEFAULT_SLOPE_SCALED_DEPTH_BIAS,
    DepthClipEnable       = true,
    ScissorEnable         = false,
    MultisampleEnable     = false,
    AntialiasedLineEnable = false,
    ForcedSampleCount     = 0,
    ConservativeRaster    = .OFF,
}

D3D11_IRasterizerState2_UUID_STRING :: "6fbd02fb-209f-46c4-b059-2ed15586a6ac"
D3D11_IRasterizerState2_UUID :=
    &win32.IID{0x6fbd02fb,0x209f,0x46c4,{0xb0,0x59,0x2e,0xd1,0x55,0x86,0xa6,0xac}}
D3D11_IRasterizerState2 :: struct #raw_union {
    #subtype irasterizerstate1: D3D11_IRasterizerState1,
    using irasterizerstate2_vtable: ^D3D11_IRasterizerState2_VTable,
}
D3D11_IRasterizerState2_VTable :: struct {
    using IRasterizerState1_vtable: D3D11_IRasterizerState1_VTable,
    GetDesc2: proc "system" (
        This: ^D3D11_IRasterizerState2,
        pDesc: ^D3D11_RASTERIZER_DESC2),
}

D3D11_TEX2D_SRV1 :: struct {
    MostDetailedMip: win32.UINT,
    MipLevels:       win32.UINT,
    PlaneSlice:      win32.UINT,
}

D3D11_TEX2D_ARRAY_SRV1 :: struct {
    MostDetailedMip: win32.UINT,
    MipLevels:       win32.UINT,
    FirstArraySlice: win32.UINT,
    ArraySize:       win32.UINT,
    PlaneSlice:      win32.UINT,
}

D3D11_SHADER_RESOURCE_VIEW_DESC1 :: struct {
    Format: dxgi.FORMAT,
    ViewDimension: d3d11.SRV_DIMENSION,
    using _: struct #raw_union {
        Buffer:           d3d11.BUFFER_SRV,
        Texture1D:        d3d11.TEX1D_SRV,
        Texture1DArray:   d3d11.TEX1D_ARRAY_SRV,
        Texture2D:        D3D11_TEX2D_SRV1,
        Texture2DArray:   D3D11_TEX2D_ARRAY_SRV1,
        Texture2DMS:      d3d11.TEX2DMS_SRV,
        Texture2DMSArray: d3d11.TEX2DMS_ARRAY_SRV,
        Texture3D:        d3d11.TEX3D_SRV,
        TextureCube:      d3d11.TEXCUBE_SRV,
        TextureCubeArray: d3d11.TEXCUBE_ARRAY_SRV,
        BufferEx:         d3d11.BUFFEREX_SRV,
    },
}

d3d11_srv_desc1_init :: proc(
    view_dimension: d3d11.SRV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    most_detailed_mip: u32 = 0,
    mip_levels: u32 = 0xFFFFFFFF,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    flags: d3d11.BUFFEREX_SRV_FLAGS = {},
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_SHADER_RESOURCE_VIEW_DESC1 {
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)

    desc := D3D11_SHADER_RESOURCE_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .BUFFER:
        desc.Buffer.FirstElement = most_detailed_mip
        desc.Buffer.NumElements = mip_levels
    case .TEXTURE1D:
        desc.Texture1D.MostDetailedMip = most_detailed_mip
        desc.Texture1D.MipLevels = mip_levels
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MostDetailedMip = most_detailed_mip
        desc.Texture1DArray.MipLevels = mip_levels
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    case .TEXTURE2D:
        desc.Texture2D.MostDetailedMip = most_detailed_mip
        desc.Texture2D.MipLevels = mip_levels
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MostDetailedMip = most_detailed_mip
        desc.Texture2DArray.MipLevels = mip_levels
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    case .TEXTURE2DMS:
        // no fields
    case .TEXTURE2DMSARRAY:
        desc.Texture2DMSArray.FirstArraySlice = first_array_slice
        desc.Texture2DMSArray.ArraySize = array_size
    case .TEXTURE3D:
        desc.Texture3D.MostDetailedMip = most_detailed_mip
        desc.Texture3D.MipLevels = mip_levels
    case .TEXTURECUBE:
        desc.TextureCube.MostDetailedMip = most_detailed_mip
        desc.TextureCube.MipLevels = mip_levels
    case .TEXTURECUBEARRAY:
        desc.TextureCubeArray.MostDetailedMip = most_detailed_mip
        desc.TextureCubeArray.MipLevels = mip_levels
        desc.TextureCubeArray.First2DArrayFace = first_array_slice
        desc.TextureCubeArray.NumCubes = array_size
    case .BUFFEREX:
        desc.BufferEx.FirstElement = most_detailed_mip
        desc.BufferEx.NumElements = mip_levels
        desc.BufferEx.Flags = flags
    case:
        unreachable()
    }

    return desc
}

d3d11_srv_desc1_init_bufferex :: proc(
    format: dxgi.FORMAT,
    first_element: u32,
    num_elements: u32,
    flags: d3d11.BUFFEREX_SRV_FLAGS = {},
    loc := #caller_location,
) -> D3D11_SHADER_RESOURCE_VIEW_DESC1 {
    assert(format != .UNKNOWN, "Invalid format", loc)
    return {
        Format = format,
        ViewDimension = .BUFFEREX,
        BufferEx = {
            FirstElement = first_element,
            NumElements = num_elements,
            Flags = flags,
        },
    }
}

d3d11_srv_desc1_init_tex1d :: proc(
    tex1d: ^d3d11.ITexture1D,
    view_dimension: d3d11.SRV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    most_detailed_mip: u32 = 0,
    mip_levels: u32 = 0xFFFFFFFF,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_SHADER_RESOURCE_VIEW_DESC1 {
    assert(tex1d != nil, "Invalid d3d11.ITexture1D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    mip_levels := mip_levels
    array_size := array_size

    if format == .UNKNOWN || mip_levels == 0xFFFFFFFF ||
       (array_size == 0xFFFFFFFF && view_dimension == .TEXTURE1DARRAY) {
        tex_desc: d3d11.TEXTURE1D_DESC
        tex1d->GetDesc(&tex_desc)
        if format == .UNKNOWN { format = tex_desc.Format }
        if mip_levels == 0xFFFFFFFF { mip_levels = tex_desc.MipLevels - most_detailed_mip }
        if array_size == 0xFFFFFFFF { array_size = tex_desc.ArraySize - first_array_slice }
    }

    desc := D3D11_SHADER_RESOURCE_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE1D:
        desc.Texture1D.MostDetailedMip = most_detailed_mip
        desc.Texture1D.MipLevels = mip_levels
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MostDetailedMip = most_detailed_mip
        desc.Texture1DArray.MipLevels = mip_levels
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    }

    return desc
}

d3d11_srv_desc1_init_tex2d :: proc(
    tex2d: ^d3d11.ITexture2D,
    view_dimension: d3d11.SRV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    most_detailed_mip: u32 = 0,
    mip_levels: u32 = 0xFFFFFFFF,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_SHADER_RESOURCE_VIEW_DESC1 {
    assert(tex2d != nil, "Invalid d3d11.ITexture2D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    mip_levels := mip_levels
    array_size := array_size

    needs_query :=
        format == .UNKNOWN ||
        (mip_levels == 0xFFFFFFFF &&
                view_dimension != .TEXTURE2DMS &&
                view_dimension != .TEXTURE2DMSARRAY) ||
        (array_size == 0xFFFFFFFF &&
                (view_dimension == .TEXTURE2DARRAY ||
                        view_dimension == .TEXTURE2DMSARRAY ||
                        view_dimension == .TEXTURECUBEARRAY))

    if needs_query {
        tex_desc: d3d11.TEXTURE2D_DESC
        tex2d->GetDesc(&tex_desc)
        if format == .UNKNOWN { format = tex_desc.Format }
        if mip_levels == 0xFFFFFFFF { mip_levels = tex_desc.MipLevels - most_detailed_mip }
        if array_size == 0xFFFFFFFF {
            array_size = tex_desc.ArraySize - first_array_slice
            if view_dimension == .TEXTURECUBEARRAY { array_size /= 6 }
        }
    }

    desc := D3D11_SHADER_RESOURCE_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE2D:
        desc.Texture2D.MostDetailedMip = most_detailed_mip
        desc.Texture2D.MipLevels = mip_levels
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MostDetailedMip = most_detailed_mip
        desc.Texture2DArray.MipLevels = mip_levels
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    case .TEXTURE2DMS:
    case .TEXTURE2DMSARRAY:
        desc.Texture2DMSArray.FirstArraySlice = first_array_slice
        desc.Texture2DMSArray.ArraySize = array_size
    case .TEXTURECUBE:
        desc.TextureCube.MostDetailedMip = most_detailed_mip
        desc.TextureCube.MipLevels = mip_levels
    case .TEXTURECUBEARRAY:
        desc.TextureCubeArray.MostDetailedMip = most_detailed_mip
        desc.TextureCubeArray.MipLevels = mip_levels
        desc.TextureCubeArray.First2DArrayFace = first_array_slice
        desc.TextureCubeArray.NumCubes = array_size
    }

    return desc
}

d3d11_srv_desc1_init_tex3d :: proc(
    tex3d: ^d3d11.ITexture3D,
    format: dxgi.FORMAT = .UNKNOWN,
    most_detailed_mip: u32 = 0,
    mip_levels: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_SHADER_RESOURCE_VIEW_DESC1 {
    assert(tex3d != nil, "Invalid d3d11.ITexture3D", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    mip_levels := mip_levels

    if format == .UNKNOWN || mip_levels == 0xFFFFFFFF {
        tex_desc: d3d11.TEXTURE3D_DESC
        tex3d->GetDesc(&tex_desc)
        if format == .UNKNOWN { format = tex_desc.Format }
        if mip_levels == 0xFFFFFFFF { mip_levels = tex_desc.MipLevels - most_detailed_mip }
    }

    return {
        Format = format,
        ViewDimension = .TEXTURE3D,
        Texture3D = {
            MostDetailedMip = most_detailed_mip,
            MipLevels = mip_levels,
        },
    }
}

D3D11_IShaderResourceView1_UUID_STRING :: "91308b87-9040-411d-8c67-c39253ce3802"
D3D11_IShaderResourceView1_UUID :=
    &win32.IID{0x91308b87,0x9040,0x411d,{0x8c,0x67,0xc3,0x92,0x53,0xce,0x38,0x02}}
D3D11_IShaderResourceView1 :: struct #raw_union {
    #subtype ishaderresourceview: d3d11.IShaderResourceView,
    using ishaderresourceview1_vtable: ^D3D11_IShaderResourceView1_VTable,
}
D3D11_IShaderResourceView1_VTable :: struct {
    using ishaderresourceview_vtable: d3d11.IShaderResourceView_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_IShaderResourceView1,
        pDesc1: ^D3D11_SHADER_RESOURCE_VIEW_DESC1),
}

D3D11_TEX2D_RTV1 :: struct {
    MipSlice:   win32.UINT,
    PlaneSlice: win32.UINT,
}

D3D11_TEX2D_ARRAY_RTV1 :: struct {
    MipSlice:        win32.UINT,
    FirstArraySlice: win32.UINT,
    ArraySize:       win32.UINT,
    PlaneSlice:      win32.UINT,
}

D3D11_RENDER_TARGET_VIEW_DESC1 :: struct {
    Format: dxgi.FORMAT,
    ViewDimension: d3d11.RTV_DIMENSION,
    using _: struct #raw_union {
        Buffer:           d3d11.BUFFER_RTV,
        Texture1D:        d3d11.TEX1D_RTV,
        Texture1DArray:   d3d11.TEX1D_ARRAY_RTV,
        Texture2D:        D3D11_TEX2D_RTV1,
        Texture2DArray:   D3D11_TEX2D_ARRAY_RTV1,
        Texture2DMS:      d3d11.TEX2DMS_RTV,
        Texture2DMSArray: d3d11.TEX2DMS_ARRAY_RTV,
        Texture3D:        d3d11.TEX3D_RTV,
    },
}

d3d11_rtv_desc1_init :: proc(
    view_dimension: d3d11.RTV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_RENDER_TARGET_VIEW_DESC1 {
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    desc := D3D11_RENDER_TARGET_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .BUFFER:
        desc.Buffer.FirstElement = mip_slice
        desc.Buffer.NumElements = first_array_slice
    case .TEXTURE1D:
        desc.Texture1D.MipSlice = mip_slice
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MipSlice = mip_slice
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    case .TEXTURE2D:
        desc.Texture2D.MipSlice = mip_slice
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MipSlice = mip_slice
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    case .TEXTURE2DMS:
        // no fields
    case .TEXTURE2DMSARRAY:
        desc.Texture2DMSArray.FirstArraySlice = first_array_slice
        desc.Texture2DMSArray.ArraySize = array_size
    case .TEXTURE3D:
        desc.Texture3D.MipSlice = mip_slice
        desc.Texture3D.FirstWSlice = first_array_slice
        desc.Texture3D.WSize = array_size
    case:
        unreachable()
    }

    return desc
}

d3d11_rtv_desc1_init_buffer :: proc(
    format: dxgi.FORMAT,
    first_element: u32,
    num_elements: u32,
    loc := #caller_location,
) -> D3D11_RENDER_TARGET_VIEW_DESC1 {
    assert(format != .UNKNOWN, "Invalid format", loc)

    return {
        Format = format,
        ViewDimension = .BUFFER,
        Buffer = {
            FirstElement = first_element,
            NumElements = num_elements,
        },
    }
}

d3d11_rtv_desc1_init_tex1d :: proc(
    tex1d: ^d3d11.ITexture1D,
    view_dimension: d3d11.RTV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_RENDER_TARGET_VIEW_DESC1 {
    assert(tex1d != nil, "Invalid d3d11.ITexture1D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    array_size := array_size

    if format == .UNKNOWN || (array_size == 0xFFFFFFFF && view_dimension == .TEXTURE1DARRAY) {
        tex_desc: d3d11.TEXTURE1D_DESC
        tex1d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if array_size == 0xFFFFFFFF do array_size = tex_desc.ArraySize - first_array_slice
    }

    desc := D3D11_RENDER_TARGET_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE1D:
        desc.Texture1D.MipSlice = mip_slice
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MipSlice = mip_slice
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    }

    return desc
}

d3d11_rtv_desc1_init_tex2d :: proc(
    tex2d: ^d3d11.ITexture2D,
    view_dimension: d3d11.RTV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_RENDER_TARGET_VIEW_DESC1 {
    assert(tex2d != nil, "Invalid d3d11.ITexture2D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    array_size := array_size

    needs_query :=
        format == .UNKNOWN ||
        (array_size == 0xFFFFFFFF &&
                (view_dimension == .TEXTURE2DARRAY || view_dimension == .TEXTURE2DMSARRAY))

    if needs_query {
        tex_desc: d3d11.TEXTURE2D_DESC
        tex2d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if array_size == 0xFFFFFFFF do array_size = tex_desc.ArraySize - first_array_slice
    }

    desc := D3D11_RENDER_TARGET_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE2D:
        desc.Texture2D.MipSlice = mip_slice
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MipSlice = mip_slice
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    case .TEXTURE2DMS:
    case .TEXTURE2DMSARRAY:
        desc.Texture2DMSArray.FirstArraySlice = first_array_slice
        desc.Texture2DMSArray.ArraySize = array_size
    }

    return desc
}

d3d11_rtv_desc1_init_tex3d :: proc(
    tex3d: ^d3d11.ITexture3D,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_w_slice: u32 = 0,
    w_size: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_RENDER_TARGET_VIEW_DESC1 {
    assert(tex3d != nil, "Invalid d3d11.ITexture3D", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    w_size := w_size

    if format == .UNKNOWN || w_size == 0xFFFFFFFF {
        tex_desc: d3d11.TEXTURE3D_DESC
        tex3d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if w_size == 0xFFFFFFFF do w_size = tex_desc.Depth - first_w_slice
    }

    return {
        Format = format,
        ViewDimension = .TEXTURE3D,
        Texture3D = {
            MipSlice = mip_slice,
            FirstWSlice = first_w_slice,
            WSize = w_size,
        },
    }
}

D3D11_IRenderTargetView1_UUID_STRING :: "ffbe2e23-f011-418a-ac56-5ceed7c5b94b"
D3D11_IRenderTargetView1_UUID :=
    &win32.IID{0xffbe2e23,0xf011,0x418a,{0xac,0x56,0x5c,0xee,0xd7,0xc5,0xb9,0x4b}}
D3D11_IRenderTargetView1 :: struct #raw_union {
    #subtype irendertargetview: d3d11.IRenderTargetView,
    using irendertargetview1_vtable: ^D3D11_IRenderTargetView1_VTable,
}
D3D11_IRenderTargetView1_VTable :: struct {
    using irendertargetview_vtable: d3d11.IRenderTargetView_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_IRenderTargetView1,
        pDesc1: ^D3D11_RENDER_TARGET_VIEW_DESC1),
}

D3D11_TEX2D_UAV1 :: struct {
    MipSlice:   win32.UINT,
    PlaneSlice: win32.UINT,
}

D3D11_TEX2D_ARRAY_UAV1 :: struct {
    MipSlice:        win32.UINT,
    FirstArraySlice: win32.UINT,
    ArraySize:       win32.UINT,
    PlaneSlice:      win32.UINT,
}

D3D11_UNORDERED_ACCESS_VIEW_DESC1 :: struct {
    Format: dxgi.FORMAT,
    ViewDimension: d3d11.UAV_DIMENSION,
    using _: struct #raw_union {
        Buffer:         d3d11.BUFFER_UAV,
        Texture1D:      d3d11.TEX1D_UAV,
        Texture1DArray: d3d11.TEX1D_ARRAY_UAV,
        Texture2D:      D3D11_TEX2D_UAV1,
        Texture2DArray: D3D11_TEX2D_ARRAY_UAV1,
        Texture3D:      d3d11.TEX3D_UAV,
    },
}

d3d11_uav_desc1_init :: proc(
    view_dimension: d3d11.UAV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    flags: d3d11.BUFFER_UAV_FLAGS = {},
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    desc := D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .BUFFER:
        desc.Buffer.FirstElement = mip_slice
        desc.Buffer.NumElements = first_array_slice
        desc.Buffer.Flags = flags
    case .TEXTURE1D:
        desc.Texture1D.MipSlice = mip_slice
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MipSlice = mip_slice
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    case .TEXTURE2D:
        desc.Texture2D.MipSlice = mip_slice
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MipSlice = mip_slice
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    case .TEXTURE3D:
        desc.Texture3D.MipSlice = mip_slice
        desc.Texture3D.FirstWSlice = first_array_slice
        desc.Texture3D.WSize = array_size
    case:
        unreachable()
    }

    return desc
}

d3d11_uav_desc1_init_buffer :: proc(
    format: dxgi.FORMAT,
    first_element: u32,
    num_elements: u32,
    flags: d3d11.BUFFER_UAV_FLAGS = {},
    loc := #caller_location,
) -> D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
    assert(format != .UNKNOWN, "Invalid format", loc)
    return {
        Format = format,
        ViewDimension = .BUFFER,
        Buffer = {
            FirstElement = first_element,
            NumElements = num_elements,
            Flags = flags,
        },
    }
}

d3d11_uav_desc1_init_tex1d :: proc(
    tex1d: ^d3d11.ITexture1D,
    view_dimension: d3d11.UAV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
    assert(tex1d != nil, "Invalid d3d11.ITexture1D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    array_size := array_size

    if format == .UNKNOWN || (array_size == 0xFFFFFFFF && view_dimension == .TEXTURE1DARRAY) {
        tex_desc: d3d11.TEXTURE1D_DESC
        tex1d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if array_size == 0xFFFFFFFF do array_size = tex_desc.ArraySize - first_array_slice
    }

    desc := D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE1D:
        desc.Texture1D.MipSlice = mip_slice
    case .TEXTURE1DARRAY:
        desc.Texture1DArray.MipSlice = mip_slice
        desc.Texture1DArray.FirstArraySlice = first_array_slice
        desc.Texture1DArray.ArraySize = array_size
    }

    return desc
}

d3d11_uav_desc1_init_tex2d :: proc(
    tex2d: ^d3d11.ITexture2D,
    view_dimension: d3d11.UAV_DIMENSION,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_array_slice: u32 = 0,
    array_size: u32 = 0xFFFFFFFF,
    plane_slice: u32 = 0,
    loc := #caller_location,
) -> D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
    assert(tex2d != nil, "Invalid d3d11.ITexture2D", loc)
    assert(view_dimension != .UNKNOWN, "Invalid view dimension", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    array_size := array_size

    if format == .UNKNOWN || (array_size == 0xFFFFFFFF && view_dimension == .TEXTURE2DARRAY) {
        tex_desc: d3d11.TEXTURE2D_DESC
        tex2d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if array_size == 0xFFFFFFFF do array_size = tex_desc.ArraySize - first_array_slice
    }

    desc := D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
        Format        = format,
        ViewDimension = view_dimension,
    }

    #partial switch view_dimension {
    case .TEXTURE2D:
        desc.Texture2D.MipSlice = mip_slice
        desc.Texture2D.PlaneSlice = plane_slice
    case .TEXTURE2DARRAY:
        desc.Texture2DArray.MipSlice = mip_slice
        desc.Texture2DArray.FirstArraySlice = first_array_slice
        desc.Texture2DArray.ArraySize = array_size
        desc.Texture2DArray.PlaneSlice = plane_slice
    }

    return desc
}

d3d11_uav_desc1_init_tex3d :: proc(
    tex3d: ^d3d11.ITexture3D,
    format: dxgi.FORMAT = .UNKNOWN,
    mip_slice: u32 = 0,
    first_w_slice: u32 = 0,
    w_size: u32 = 0xFFFFFFFF,
    loc := #caller_location,
) -> D3D11_UNORDERED_ACCESS_VIEW_DESC1 {
    assert(tex3d != nil, "Invalid d3d11.ITexture3D", loc)
    assert(format != .UNKNOWN, "Invalid format", loc)

    format := format
    w_size := w_size

    if format == .UNKNOWN || w_size == 0xFFFFFFFF {
        tex_desc: d3d11.TEXTURE3D_DESC
        tex3d->GetDesc(&tex_desc)
        if format == .UNKNOWN do format = tex_desc.Format
        if w_size == 0xFFFFFFFF do w_size = tex_desc.Depth - first_w_slice
    }

    return {
        Format = format,
        ViewDimension = .TEXTURE3D,
        Texture3D = {
            MipSlice = mip_slice,
            FirstWSlice = first_w_slice,
            WSize = w_size,
        },
    }
}

D3D11_IUnorderedAccessView1_UUID_STRING :: "7b3b6153-a886-4544-ab37-6537c8500403"
D3D11_IUnorderedAccessView1_UUID :=
    &win32.IID{0x7b3b6153,0xa886,0x4544,{0xab,0x37,0x65,0x37,0xc8,0x50,0x04,0x03}}
D3D11_IUnorderedAccessView1 :: struct #raw_union {
    #subtype iunorderedaccessview: d3d11.IUnorderedAccessView,
    using iunorderedaccessview1_vtable: ^D3D11_IUnorderedAccessView1_VTable,
}
D3D11_IUnorderedAccessView1_VTable :: struct {
    using iunorderedaccessview_vtable: d3d11.IUnorderedAccessView_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_IUnorderedAccessView1,
        pDesc1: ^D3D11_UNORDERED_ACCESS_VIEW_DESC1),
}

D3D11_QUERY_DESC1 :: struct {
    Query:       d3d11.QUERY,
    MiscFlags:   d3d11.QUERY_MISC_FLAGS,
    ContextType: D3D11_CONTEXT_TYPE,
}

d3d11_query_desc1_init :: proc(
    query: d3d11.QUERY,
    misc_flags: d3d11.QUERY_MISC_FLAGS = {},
    context_type: D3D11_CONTEXT_TYPE = .ALL,
) -> D3D11_QUERY_DESC1 {
    return {
        Query = query,
        MiscFlags = misc_flags,
        ContextType = context_type,
    }
}

D3D11_IQuery1_UUID_STRING :: "631b4766-36dc-461d-8db6-c47e13e60916"
D3D11_IQuery1_UUID :=
    &win32.IID{0x631b4766,0x36dc,0x461d,{0x8d,0xb6,0xc4,0x7e,0x13,0xe6,0x09,0x16}}
D3D11_IQuery1 :: struct #raw_union {
    #subtype iquery: d3d11.IQuery,
    using iquery1_vtable: ^D3D11_IQuery1_VTable,
}
D3D11_IQuery1_VTable :: struct {
    using iquery_vtable: d3d11.IQuery_VTable,
    GetDesc1: proc "system" (
        This: ^D3D11_IQuery1,
        pDesc1: ^D3D11_QUERY_DESC1),
}

D3D11_FENCE_FLAGS :: distinct bit_set[D3D11_FENCE_FLAG; u32]
D3D11_FENCE_FLAG :: enum i32 {
    SHARED               = 1,
    SHARED_CROSS_ADAPTER = 2,
    NON_MONITORED        = 3,
}

D3D11_FENCE_FLAGS_NONE :: D3D11_FENCE_FLAGS{}

D3D11_IDeviceContext3_UUID_STIRNG :: "b4e3c01d-e79e-4637-91b2-510e9f4c9b8f"
D3D11_IDeviceContext3_UUID :=
    &win32.IID{0xb4e3c01d,0xe79e,0x4637,{0x91,0xb2,0x51,0x0e,0x9f,0x4c,0x9b,0x8f}}
D3D11_IDeviceContext3 :: struct #raw_union {
    #subtype idevicecontext2: D3D11_IDeviceContext2,
    using idevicecontext3_vtable: ^D3D11_IDeviceContext3_VTable,
}
D3D11_IDeviceContext3_VTable :: struct {
    using idevicecontext2_vtable: D3D11_IDeviceContext2_VTable,
    Flush1: proc "system" (
        This: ^D3D11_IDeviceContext3,
        ContextType: D3D11_CONTEXT_TYPE,
        hEvent: win32.HANDLE),
    SetHardwareProtectionState: proc "system" (
        This: ^D3D11_IDeviceContext3,
        HwProtectionEnable: win32.BOOL),
    GetHardwareProtectionState: proc "system" (
        This: ^D3D11_IDeviceContext3,
        pHwProtectionEnable: ^win32.BOOL),
}

D3D11_IFence_UUID_STRING :: "affde9d1-1df7-4bb7-8a34-0f46251dab80"
D3D11_IFence_UUID :=
    &win32.IID{0xaffde9d1,0x1df7,0x4bb7,{0x8a,0x34,0x0f,0x46,0x25,0x1d,0xab,0x80}}
D3D11_IFence :: struct #raw_union {
    #subtype idevicechild: d3d11.IDeviceChild,
    using ifence_vtable: ^D3D11_IFence_VTable,
}
D3D11_IFence_VTable :: struct {
    using idevicechild_vtable: d3d11.IDeviceChild_VTable,
    CreateSharedHandle: proc "system" (
        This: ^D3D11_IFence,
        pAttributes: ^win32.SECURITY_ATTRIBUTES,
        dwAccess: win32.DWORD,
        lpName: win32.LPCWSTR,
        pHandle: ^win32.HANDLE) -> win32.HRESULT,
    GetCompletedValue: proc "system" (This: ^D3D11_IFence) -> win32.UINT64,
    SetEventOnCompletion: proc "system" (
        This: ^D3D11_IFence,
        Value: win32.UINT64,
        hEvent: win32.HANDLE) -> win32.HRESULT,
}

D3D11_IDeviceContext4_UUID_STRING :: "917600da-f58c-4c33-98d8-3e15b390fa24"
D3D11_IDeviceContext4_UUID :=
    &win32.IID{0x917600da,0xf58c,0x4c33,{0x98,0xd8,0x3e,0x15,0xb3,0x90,0xfa,0x24}}
D3D11_IDeviceContext4 :: struct #raw_union {
    #subtype idevicecontext3: D3D11_IDeviceContext3,
    using idevicecontext4_vtable: ^D3D11_IDeviceContext4_VTable,
}
D3D11_IDeviceContext4_VTable :: struct {
    using idevicecontext3_vtable: D3D11_IDeviceContext3_VTable,
    Signal: proc "system" (
        This: ^D3D11_IDeviceContext4,
        pFence: ^D3D11_IFence,
        Value: win32.UINT64) -> win32.HRESULT,
    Wait: proc "system" (
        This: ^D3D11_IDeviceContext4,
        pFence: ^D3D11_IFence,
        Value: win32.UINT64) -> win32.HRESULT,
}

D3D11_IDevice3_UUID_STRING :: "A05C8C37-D2C6-4732-B3A0-9CE0B0DC9AE6"
D3D11_IDevice3_UUID :=
    &win32.IID{0xA05C8C37,0xD2C6,0x4732,{0xB3,0xA0,0x9C,0xE0,0xB0,0xDC,0x9A,0xE6}}
D3D11_IDevice3 :: struct #raw_union {
    #subtype idevice2: D3D11_IDevice2,
    using idevice3_vtable: ^D3D11_IDevice3_VTable,
}
D3D11_IDevice3_VTable :: struct {
    using idevice2_vtable: D3D11_IDevice2_VTable,
    CreateTexture2D1: proc "system" (
        This: ^D3D11_IDevice3,
        pDesc1: ^D3D11_TEXTURE2D_DESC1,
        pInitialData: ^d3d11.SUBRESOURCE_DATA,
        ppTexture2D: ^^D3D11_ITexture2D1) -> win32.HRESULT,
    CreateTexture3D1: proc "system" (
        This: ^D3D11_IDevice3,
        pDesc1: ^D3D11_TEXTURE3D_DESC1,
        pInitialData: ^d3d11.SUBRESOURCE_DATA,
        ppTexture3D: ^^D3D11_ITexture3D1) -> win32.HRESULT,
    CreateRasterizerState2: proc "system" (
        This: ^D3D11_IDevice3,
        pRasterizerDesc: ^D3D11_RASTERIZER_DESC2,
        ppRasterizerState: ^^D3D11_IRasterizerState2) -> win32.HRESULT,
    CreateShaderResourceView1: proc "system" (
        This: ^D3D11_IDevice3,
        pResource: ^d3d11.IResource,
        pDesc1: ^D3D11_SHADER_RESOURCE_VIEW_DESC1,
        ppSRView1: ^^D3D11_IShaderResourceView1) -> win32.HRESULT,
    CreateUnorderedAccessView1: proc "system" (
        This: ^D3D11_IDevice3,
        pResource: ^d3d11.IResource,
        pDesc1: ^D3D11_UNORDERED_ACCESS_VIEW_DESC1,
        ppUAView1: ^^D3D11_IUnorderedAccessView1) -> win32.HRESULT,
    CreateRenderTargetView1: proc "system" (
        This: ^D3D11_IDevice3,
        pResource: ^d3d11.IResource,
        pDesc1: ^D3D11_RENDER_TARGET_VIEW_DESC1,
        ppRTView1: ^^D3D11_IRenderTargetView1) -> win32.HRESULT,
    CreateQuery1: proc "system" (
        This: ^D3D11_IDevice3,
        pQueryDesc1: ^D3D11_QUERY_DESC1,
        ppQuery1: ^^D3D11_IQuery1) -> win32.HRESULT,
    GetImmediateContext3: proc "system" (
        This: ^D3D11_IDevice3,
        ppImmediateContext: ^^D3D11_IDeviceContext3),
    CreateDeferredContext3: proc "system" (
        This: ^D3D11_IDevice3,
        ContextFlags: win32.UINT,
        ppDeferredContext: ^^D3D11_IDeviceContext3) -> win32.HRESULT,
    WriteToSubresource: proc "system" (
        This: ^D3D11_IDevice3,
        pDstResource: ^d3d11.IResource,
        DstSubresource: win32.UINT,
        pDstBox: ^d3d11.BOX,
        pSrcData: rawptr,
        SrcRowPitch: win32.UINT,
        SrcDepthPitch: win32.UINT),
    ReadFromSubresource: proc "system" (
        This: ^D3D11_IDevice3,
        pDstData: rawptr,
        DstRowPitch: win32.UINT,
        DstDepthPitch: win32.UINT,
        pSrcResource: ^d3d11.IResource,
        SrcSubresource: win32.UINT,
        pSrcBox: ^d3d11.BOX),
}
