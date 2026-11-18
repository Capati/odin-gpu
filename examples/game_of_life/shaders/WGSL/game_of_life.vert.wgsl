struct GridParams_std140_0
{
    @align(16) size_0 : vec2<u32>,
    @align(8) resolution_0 : vec2<f32>,
};

@binding(0) @group(0) var<uniform> params_0 : GridParams_std140_0;
@binding(1) @group(0) var<storage, read> grid_0 : array<u32>;

struct VSOut_0
{
    @location(0) color_0 : vec4<f32>,
    @builtin(position) pos_0 : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vid_0 : u32, @builtin(instance_index) iid_0 : u32) -> VSOut_0
{
    var output_0 : VSOut_0;
    var _S1 : bool;
    if(iid_0 >= (params_0.size_0.x * params_0.size_0.y))
    {
        _S1 = true;
    }
    else
    {
        _S1 = grid_0[iid_0] == u32(0);
    }
    if(_S1)
    {
        output_0.pos_0 = vec4<f32>(2.0f, 2.0f, 2.0f, 1.0f);
        output_0.color_0 = vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f);
        return output_0;
    }
    const _S2 : vec2<f32> = vec2<f32>(-1.0f, -1.0f);
    const _S3 : vec2<f32> = vec2<f32>(1.0f, 1.0f);
    var corners_0 : array<vec2<f32>, i32(6)> = array<vec2<f32>, i32(6)>( _S2, vec2<f32>(1.0f, -1.0f), _S3, _S2, vec2<f32>(-1.0f, 1.0f), _S3 );
    var _S4 : u32 = iid_0 % params_0.size_0.x;
    var _S5 : f32 = f32(_S4);
    var _S6 : u32 = iid_0 / params_0.size_0.x;
    var _S7 : f32 = f32(_S6);
    var cell_size_0 : vec2<f32> = params_0.resolution_0 / vec2<f32>(params_0.size_0);
    var _S8 : vec2<f32> = vec2<f32>(0.5f);
    var pixel_0 : vec2<f32> = (vec2<f32>(_S5, _S7) + _S8) * cell_size_0 + corners_0[vid_0] * cell_size_0 * _S8;
    output_0.pos_0 = vec4<f32>(pixel_0.x / params_0.resolution_0.x * 2.0f - 1.0f, 1.0f - pixel_0.y / params_0.resolution_0.y * 2.0f, 0.0f, 1.0f);
    var _S9 : vec3<f32> = vec3<f32>(0.5f);
    output_0.color_0 = vec4<f32>(vec3<f32>(0.34999999403953552f) + vec3<f32>(0.64999997615814209f) * (_S9 + _S9 * cos(vec3<f32>(6.28318023681640625f) * (vec3<f32>(_S5, _S7, _S5 + _S7) / vec3<f32>(24.0f) + vec3<f32>(0.0f, 0.33000001311302185f, 0.67000001668930054f)))), 1.0f);
    return output_0;
}

