struct GridParams_std140_0
{
    @align(16) size_0 : vec2<u32>,
    @align(8) resolution_0 : vec2<f32>,
};

@binding(0) @group(0) var<uniform> params_0 : GridParams_std140_0;
@binding(1) @group(0) var<storage, read> src_0 : array<u32>;

@binding(2) @group(0) var<storage, read_write> dst_0 : array<u32>;

@compute
@workgroup_size(16, 16, 1)
fn cs_main(@builtin(global_invocation_id) tid_0 : vec3<u32>)
{
    var cell_0 : vec2<u32> = tid_0.xy;
    var alive_0 : bool;
    if((cell_0.x) >= (params_0.size_0.x))
    {
        alive_0 = true;
    }
    else
    {
        alive_0 = (cell_0.y) >= (params_0.size_0.y);
    }
    if(alive_0)
    {
        return;
    }
    var _S1 : vec2<i32> = vec2<i32>(params_0.size_0);
    var _S2 : vec2<i32> = vec2<i32>(cell_0);
    var dy_0 : i32 = i32(-1);
    var neighbours_0 : u32 = u32(0);
    for(;;)
    {
        if(dy_0 <= i32(1))
        {
        }
        else
        {
            break;
        }
        var dx_0 : i32 = i32(-1);
        var neighbours_1 : u32 = neighbours_0;
        for(;;)
        {
            if(dx_0 <= i32(1))
            {
            }
            else
            {
                break;
            }
            if(dx_0 == i32(0))
            {
                alive_0 = dy_0 == i32(0);
            }
            else
            {
                alive_0 = false;
            }
            if(alive_0)
            {
                dx_0 = dx_0 + i32(1);
                continue;
            }
            var n_0 : vec2<i32> = (_S2 + vec2<i32>(dx_0, dy_0) + _S1) % _S1;
            neighbours_1 = neighbours_1 + src_0[n_0.y * _S1.x + n_0.x];
            dx_0 = dx_0 + i32(1);
        }
        dy_0 = dy_0 + i32(1);
        neighbours_0 = neighbours_1;
    }
    var _S3 : i32 = _S2.y * _S1.x + _S2.x;
    var self_0 : u32 = src_0[_S3];
    if(neighbours_0 == u32(3))
    {
        alive_0 = true;
    }
    else
    {
        if(self_0 != u32(0))
        {
            alive_0 = neighbours_0 == u32(2);
        }
        else
        {
            alive_0 = false;
        }
    }
    if(alive_0)
    {
        dy_0 = i32(1);
    }
    else
    {
        dy_0 = i32(0);
    }
    dst_0[_S3] = u32(dy_0);
    return;
}

