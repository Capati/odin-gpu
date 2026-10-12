package application

// Vendor
import "../../gpu"

Mipmap_View_Dimension :: enum {
    Undefined,
    D2,
    D2_Array,
    D3,
    Cube,
    Cube_Array,
}

Texture_Descriptor :: struct {
    // Base
    using base:            gpu.Texture_Descriptor,

    // Custom fields
    address_mode:          Maybe(gpu.Address_Mode),
    pixels:                []u8,
    is_dirty:              bool,
    generate_mipmaps:      bool,
    mipmap_view_dimension: Mipmap_View_Dimension,
}

Texture :: struct {
    desc:    Texture_Descriptor,
    handle:  gpu.Texture,
    view:    gpu.Texture_View,
    sampler: gpu.Sampler,
}

texture_init :: proc(texture: ^Texture, desc: Texture_Descriptor, loc := #caller_location) {
    assert(texture != nil, loc = loc)

    texture.desc = desc

    width := value_or(desc.size.width, 16)
    height := value_or(desc.size.height, 16)
    depth_or_array_layers := max(1, value_or(desc.size.depth_or_array_layers, 1))
    format := value_or(desc.format, gpu.Texture_Format.RGBA8_Unorm)

    // Calculate mip level count: auto-compute if generate_mipmaps is set and
    // mip_level_count is 0 or 1
    mip_level_count: u32
    if desc.generate_mipmaps && desc.mip_level_count <= 1 {
        mip_level_count = gpu.max_mip_levels(width, height)
    } else {
        mip_level_count = max(1, value_or(desc.mip_level_count, 1))
    }

    // Store computed mip level count back
    texture.desc.mip_level_count = mip_level_count

    // Texture
    {
        usage := desc.usage != {} ? desc.usage : {.Texture_Binding, .Copy_Dst}

        // Mipmap generation requires Render_Attachment usage for the destination
        // views and Texture_Binding for the source views
        if desc.generate_mipmaps && mip_level_count > 1 {
            usage |= {.Render_Attachment, .Texture_Binding}
        }

        tex_dim := gpu.Texture_Dimension.D2
        if desc.dimension == .D3 {
            tex_dim = .D3
        } else if desc.dimension == .D1 {
            tex_dim = .D1
        }

        tdesc := gpu.Texture_Descriptor {
            usage           = usage,
            dimension       = tex_dim,
            size            = {width, height, depth_or_array_layers},
            format          = format,
            mip_level_count = mip_level_count,
            sample_count    = 1,
        }

        texture.handle = gpu.device_create_texture(g_ctx.device, tdesc, loc)
    }

    // Texture data
    {
        if len(desc.pixels) > 0 {
            bytes_per_row := width * gpu.texture_format_block_copy_size(format)
            gpu.queue_write_texture(
                queue       = g_ctx.queue,
                destination = { texture = texture.handle, aspect = .All },
                data_layout = { 0, bytes_per_row, height },
                write_size  = { width, height, depth_or_array_layers },
                data        = desc.pixels,
                loc         = loc,
            )
        }
    }

    // Generate mipmaps if requested
    if desc.generate_mipmaps && mip_level_count > 1 && len(desc.pixels) > 0 {
        // generate_mipmaps(texture.handle, desc.mipmap_view_dimension, loc)
    }

    // Texture view
    {
        usage := desc.usage != {} ? desc.usage : {.Texture_Binding, .Copy_Dst}

        // Determine the view dimension for the final texture view
        view_dim := gpu.Texture_View_Dimension.D2

        if desc.dimension == .D3 {
            view_dim = .D3
        } else if desc.mipmap_view_dimension != .Undefined {
              view_dim = mipmap_view_to_gpu(desc.mipmap_view_dimension)
        } else if depth_or_array_layers == 6 {
            view_dim = .Cube
        } else if depth_or_array_layers > 1 {
            view_dim = .D2_Array
        }

        // For 3D textures, arrayLayerCount must be 1
        array_layer_count := view_dim == .D3 ? 1 : depth_or_array_layers

        view_desc := gpu.Texture_View_Descriptor {
            format            = format,
            dimension         = view_dim,
            usage             = usage,
            base_mip_level    = 0,
            mip_level_count   = mip_level_count,
            base_array_layer  = 0,
            array_layer_count = array_layer_count,
            aspect            = .All,
        }

        texture.view = gpu.texture_create_view(texture.handle, view_desc, loc)
    }

    // Texture sampler
    {
        // Use specified address mode, default to Repeat (0 maps to Repeat)
        addr_mode: gpu.Address_Mode = .Repeat
        if curr_addr_mode, ok := desc.address_mode.?; ok {
            addr_mode = curr_addr_mode
        }
        sampler_desc := gpu.Sampler_Descriptor {
            address_mode_u   = addr_mode,
            address_mode_v   = addr_mode,
            address_mode_w   = addr_mode,
            mag_filter       = .Linear,
            min_filter       = mip_level_count > 1 ? .Linear : .Nearest,
            mipmap_filter    = .Linear,
            lod_min_clamp    = 0.0,
            lod_max_clamp    = f32(mip_level_count),
            compare          = .Undefined,
            anisotropy_clamp = 1,
        }

        texture.sampler = gpu.device_create_sampler(g_ctx.device, sampler_desc, loc)
    }
}

texture_recreate :: proc(texture: ^Texture) {
    texture_uninit(texture)
}

texture_uninit :: proc(texture: ^Texture) {
    if texture.sampler != {} {
        gpu.sampler_release(texture.sampler)
    }
    if texture.view != {} {
        gpu.texture_view_release(texture.view)
    }
    if texture.handle != {} {
        gpu.texture_release(texture.handle)
    }
}

mipmap_view_to_gpu :: proc(dim: Mipmap_View_Dimension) -> gpu.Texture_View_Dimension {
    #partial switch dim {
    case .D2: return .D2
    case .D2_Array: return .D2_Array
    case .D3: return .D3
    case .Cube: return .Cube
    case .Cube_Array: return .Cube_Array
    case:
        return .D2
    }
}

Depth_Stencil_Texture_Creation_Options :: struct {
    format:        gpu.Texture_Format,
    width, height: u32,
    sample_count:  u32,
}

Depth_Stencil_Texture :: struct {
    format:     gpu.Texture_Format,
    texture:    gpu.Texture,
    view:       gpu.Texture_View,
    descriptor: gpu.Render_Pass_Depth_Stencil_Attachment,
}

DEFAULT_DEPTH_FORMAT :: gpu.Texture_Format.Depth24Plus

depth_stencil_texture_init :: proc(
    self: ^Depth_Stencil_Texture,
    device: gpu.Device,
    options: Depth_Stencil_Texture_Creation_Options,
    loc := #caller_location,
) {
    assert(self != nil, "invalid depth stencil texture", loc)
    assert(self.texture == {}, "depth stencil texture already initialized", loc)

    self^ = {} // reset memory

    self.format = options.format if options.format != .Undefined else DEFAULT_DEPTH_FORMAT

    sample_count := max(1, options.sample_count)

    self.texture = gpu.device_create_texture(device, {
        usage = {.Render_Attachment, .Copy_Dst},
        format = self.format,
        dimension = .D2,
        mip_level_count = 1,
        sample_count = sample_count,
        size = {
            width = options.width,
            height = options.height,
            depth_or_array_layers = 1,
        },
    })

    self.view = gpu.texture_create_view(self.texture, {
        format            = self.format,
        dimension         = .D2,
        base_mip_level    = 0,
        mip_level_count   = 1,
        base_array_layer  = 0,
        array_layer_count = 1,
        aspect            = .All,
    })

    self.descriptor = {
        view = self.view,
        depth_ops = {
            load = .Clear,
            store = .Store,
            clear_value = 1.0,
        },
        stencil_ops = {
            load = .Clear,
            store = .Store,
            clear_value = 0.0,
        },
    }
}

depth_stencil_texture_uninit :: proc(self: ^Depth_Stencil_Texture, loc := #caller_location) {
    assert(self != nil, "invalid depth stencil texture", loc)
    if self.texture != {} {
        gpu.texture_release(self.texture)
    }
    if self.view != {} {
        gpu.texture_view_release(self.view)
    }
    self^ = {}
}
