struct TimeParams_std140_0
{
    @align(16) time_0 : f32,
    @align(4) pad0_0 : f32,
    @align(8) pad1_0 : f32,
    @align(4) pad2_0 : f32,
};

@binding(0) @group(0) var<uniform> params_0 : TimeParams_std140_0;
struct pixelOutput_0
{
    @location(0) output_0 : vec4<f32>,
};

struct pixelInput_0
{
    @location(0) uv_0 : vec2<f32>,
};

@fragment
fn fs_main( _S1 : pixelInput_0) -> pixelOutput_0
{
    var c_0 : vec2<f32> = (_S1.uv_0 - vec2<f32>(0.5f)) * vec2<f32>(3.0f);
    var z_0 : vec2<f32> = c_0;
    var i_0 : i32 = i32(0);
    var t_0 : f32 = 0.0f;
    for(;;)
    {
        if(i_0 < i32(64))
        {
        }
        else
        {
            break;
        }
        var _S2 : f32 = z_0.x;
        var _S3 : f32 = z_0.y;
        var z_1 : vec2<f32> = vec2<f32>(_S2 * _S2 - _S3 * _S3, 2.0f * _S2 * _S3) + c_0;
        var t_1 : f32 = t_0 + exp(-8.0f * length(z_1));
        var _S4 : i32 = i_0 + i32(1);
        z_0 = z_1;
        i_0 = _S4;
        t_0 = t_1;
    }
    var _S5 : vec3<f32> = vec3<f32>(0.5f);
    var _S6 : pixelOutput_0 = pixelOutput_0( vec4<f32>((_S5 + _S5 * cos(vec3<f32>(6.28318023681640625f) * (vec3<f32>((t_0 * 0.15000000596046448f + params_0.time_0)) + vec3<f32>(0.0f, 0.33000001311302185f, 0.67000001668930054f)))) * vec3<f32>(0.80000001192092896f), 1.0f) );
    return _S6;
}

