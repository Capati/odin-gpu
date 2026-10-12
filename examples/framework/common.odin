package application

// Vendor
import "../../gpu"

create_blend_state :: proc(enable_blend := true) -> (blend_state: gpu.Blend_State) {
    blend_component := gpu.Blend_Component {
        operation = .Add,
    }

    if enable_blend {
        blend_component.src_factor = .Src_Alpha
        blend_component.dst_factor = .One_Minus_Src_Alpha
    } else {
        blend_component.src_factor = .One
        blend_component.dst_factor = .Zero
    }

    blend_state.color = blend_component
    blend_state.alpha = blend_component

    return
}

Depth_Stencil_State_Descriptor :: struct {
    format:              gpu.Texture_Format,
    depth_write_enabled: bool,
    depth_compare:       Maybe(gpu.Compare_Function),
}

create_depth_stencil_state :: proc "contextless" (
    desc: Depth_Stencil_State_Descriptor,
) -> gpu.Depth_Stencil_State {
    stencil_state_face_desc := gpu.Stencil_Face_State {
        compare       = .Always,
        fail_op       = .Keep,
        depth_fail_op = .Keep,
        pass_op       = .Keep,
    }

    return {
        format = desc.format,
        depth_write_enabled = desc.depth_write_enabled,
        depth_compare = desc.depth_compare.? or_else .Less_Equal,
        stencil = {
            front = stencil_state_face_desc,
            back = stencil_state_face_desc,
            read_mask = max(u32),
            write_mask = max(u32),
        },
        bias = {
            constant = 0,
            slope_scale = 0.0,
            clamp = 0.0,
        },
    }
}
