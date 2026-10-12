package gpu

// Supported physical device types.
Device_Type :: enum i32 {
    // Other or Unknown.
    Unknown,
    // Integrated GPU with shared CPU/GPU memory.
    Integrated_Gpu,
    // Discrete GPU with separate CPU/GPU memory.
    Discrete_Gpu,
    // Virtual / Hosted.
    Virtual_Gpu,
    // Cpu / Software Rendering.
    Cpu,
}

// How edges should be handled in texture addressing.
Address_Mode :: enum i32 {
    // Clamp the value to the edge of the texture:
    //
    // -0.25 -> 0.0 1.25 -> 1.0
    Clamp_To_Edge,
    // Repeat the texture in a tiling fashion:
    //
    // -0.25 -> 0.75 1.25 -> 0.25
    Repeat,
    // the texture, mirroring it every repeat:
    //
    // -0.25 -> 0.25 1.25 -> 0.75
    Mirror_Repeat,
    // Clamp the value to the border of the texture. Requires feature
    // `Address_Mode_Clamp_To_Border`.
    //
    // -0.25 -> border 1.25 -> border
    Clamp_To_Border,
}

// Backends supported by the gpu.
Backend_Type :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // Dummy backend, which may be used for testing.
    Null,
    // WebGPU in the browser.
    WebGPU,
    // Direct3D-11 (Windows).
    D3D11,
    // Direct3D-12 (Windows).
    D3D12,
    // Metal API (Apple platforms).
    Metal,
    // Vulkan API (Windows, Linux, Android, MacOS via
    // vulkan-portability/MoltenVK).
    Vulkan,
    // OpenGL 3.3+ (Windows).
    OpenGL,
    // OpenGL ES 3.0+ (Linux, Android, MacOS via Angle), and WebGL2.
    OpenGLES,
}

// Alpha blend factor.
//
// Corresponds to WebGPU GPUBlendFactor. Values using `SRC1` require feature
// `dual_source_blending` and can only be used with the first render target.
//
// For further details on how the blend factors are applied, see the analogous
// functionality in OpenGL:
//
// https://www.khronos.org/opengl/wiki/Blending#Blending_Parameters.
Blend_Factor :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // 0.0.
    Zero,
    // 1.0.
    One,
    // S.component.
    Src,
    // 1.0 - S.component.
    One_Minus_Src,
    // S.alpha.
    Src_Alpha,
    // 1.0 - S.alpha.
    One_Minus_Src_Alpha,
    // D.component.
    Dst,
    // 1.0 - D.component.
    One_Minus_Dst,
    // D.alpha.
    Dst_Alpha,
    // 1.0 - D.alpha.
    One_Minus_Dst_Alpha,
    // min(S.alpha, 1.0 - D.alpha).
    Src_Alpha_Saturated,
    // Constant.
    Constant,
    // 1.0 - Constant.
    One_Minus_Constant,
    // S1.component.
    Src1,
    // 1.0 - S1.component.
    One_Minus_Src1,
    // S1.alpha.
    Src1_Alpha,
    // 1.0 - S1.alpha.
    One_Minus_Src1_Alpha,
}

// Alpha blend operation.
//
// Corresponds to [WebGPU `GPUBlendOperation`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpublendoperation).
//
// For further details on how the blend operations are applied, see the analogous
// functionality in OpenGL:
// <https://www.khronos.org/opengl/wiki/Blending#Blend_Equations>.
Blend_Operation :: enum i32 {
    // Add
    Add,
    // Src - Dst
    Subtract,
    // Dst - Src
    Reverse_Subtract,
    // min(Src, Dst)
    Min,
    // max(Src, Dst)
    Max,
}

// Specific type of a buffer binding.
//
// Corresponds to [WebGPU `GPUBufferBindingType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpubufferbindingtype).
Buffer_Binding_Type :: enum i32 {
    // Indicates that this `Buffer_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // A buffer for uniform values.
    Uniform,
    // A storage buffer.
    Storage,
    // A storage buffer that can only be read in the shader.
    Read_Only_Storage,
}

// Specific state of a buffer.
Buffer_Map_State :: enum i32 {
    // The buffer is not mapped.
    Unmapped,
    // A mapping of the buffer has been requested, but is pending. It may
    // succeed, or fail validation in `buffer_map_async`.
    Pending,
    // The buffer is mapped.
    Mapped,
}

// The callback mode controls how a callback for an asynchronous operation may
// be fired.
Callback_Mode :: enum i32 {
    Wait_Any_Only,
    Allow_Process_Events,
    Allow_Spontaneous,
}

// Comparison function used for depth and stencil operations.
//
// Corresponds to [WebGPU `GPUCompareFunction`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpucomparefunction).
Compare_Function :: enum i32 {
    // Indicates that no value was provided for this argument.
    Undefined,
    // Function never passes.
    Never,
    // Function passes if new value less than existing value.
    Less,
    // Function passes if new value is equal to existing value.
    Equal,
    // Function passes if new value is less than or equal to existing value.
    Less_Equal,
    // Function passes if new value is greater than existing value.
    Greater,
    // Function passes if new value is not equal to existing value.
    Not_Equal,
    // Function passes if new value is greater than or equal to existing value.
    Greater_Equal,
    // Function always passes.
    Always,
}

// Returns true if the comparison depends on the reference value.
compare_function_needs_ref_value :: proc "contextless" (self: Compare_Function) -> bool {
    #partial switch self {
    case .Never, .Always: return false
    }
    return true
}

// Status of an asynchronous request for shader module compilation information
// (the status passed to the `WGPUCompilationInfoCallback`).
Compilation_Info_Request_Status :: enum i32 {
    // The request completed successfully. The `compilation_info` pointer is
    // valid and contains the messages.
    Success,
    // The request was cancelled. This typically happens when the
    // `Shader_Module` is destroyed, the device is lost, or the instance is
    // dropped before the compilation info could be delivered. The
    // `compilation_info` pointer should be ignored.
    Callback_Cancelled,
}

// Severity / kind of a single message produced by the shader compiler (the type
// field of `Compilation_Message`).
Compilation_Message_Type :: enum i32 {
    // A compilation error. Indicates a problem that prevents successful
    // creation/use of the shader module (maps to a shader-creation error in the
    // WebGPU specification).
    Error,
    // A compilation warning. The shader may still be usable, but there is an
    // issue the developer should be aware of (e.g. deprecated syntax, potential
    // performance problems, etc.).
    Warning,
    // An informational message. Purely advisory; does not indicate a problem.
    Info,
}

// Specifies how a single color component (R, G, B, or A) of a texture view is
// sourced when the texture is sampled or loaded in a shader.

// This enum is used by the `WGPUTextureComponentSwizzle` structure (typically
// chained onto a `WGPUTextureViewDescriptor` via the "texture_component_swizzle"
// feature).
Component_Swizzle :: enum i32 {
    // Indicates that no explicit value was provided for this component. The
    // implementation applies the default (identity mapping): R → R, G → G, B →
    // B, A → A.
    Undefined,
    // Force its value to 0.
    Zero,
    // Force its value to 1.
    One,
    // Take its value from the red channel of the texture.
    R,
    // Take its value from the green channel of the texture.
    G,
    // Take its value from the blue channel of the texture.
    B,
    // Take its value from the alpha channel of the texture.
    A,
}

// Specifies how the alpha channel of the textures should be handled during
// compositing.
Composite_Alpha_Mode :: enum i32 {
    // Chooses either **Opaque** or **Inherit** automatically, depending on the
    // `alpha_mode` that the current surface can support.
    Auto,
    // The alpha channel, if it exists, of the textures is ignored in the
    // compositing process. Instead, the textures is treated as if it has a
    // constant alpha of 1.0.
    Opaque,
    // The alpha channel, if it exists, of the textures is respected in the
    // compositing process. The non-alpha channels of the textures are expected
    // to already be multiplied by the alpha channel by the application.
    Premultiplied,
    // The alpha channel, if it exists, of the textures is respected in the
    // compositing process. The non-alpha channels of the textures are not
    // expected to already be multiplied by the alpha channel by the
    // application; instead, the compositor will multiply the non-alpha channels
    // of the texture by the alpha channel during compositing.
    Unpremultiplied,
    // The alpha channel, if it exists, of the textures is unknown for processing
    // during compositing. Instead, the application is responsible for setting
    // the composite alpha blending mode using native WSI command. If not set,
    // then a platform-specific default will be used.
    Inherit,
}

// Status of an asynchronous pipeline creation request (the status passed to the
// `Create_Compute_Pipeline_Async_Callback` or `Create_Render_Pipeline_Async_Callback`).
Create_Pipeline_Async_Status :: enum i32 {
    // Pipeline creation completed successfully. The returned pipeline object is
    // valid and ready to use.
    Success,
    // The asynchronous creation was cancelled. This typically occurs if the
    // device is lost or destroyed while the pipeline is still being compiled.
    // The pipeline pointer should be ignored.
    Callback_Cancelled,
    // A validation error occurred while creating the pipeline (e.g. invalid
    // descriptor, shader incompatibility, unsupported combination of states,
    // etc.). An error message is usually provided.
    Validation_Error,
    // An unexpected internal error occurred inside the implementation during
    // pipeline creation. An error message is usually provided.
    Internal_Error,
}

// Defines which faces of a primitive are discarded (culled) during
// rasterization.
//
// Corresponds to [WebGPU `GPUCullMode`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpucullmode).
Cull_Mode :: enum i32 {
    // No faces are culled. Both front-facing and back-facing primitives are
    // rasterized.
    None,
    // Front-facing primitives are culled (discarded). Only back-facing
    // primitives are rasterized.
    Front,
    // Back-facing primitives are culled (discarded). Only front-facing
    // primitives are rasterized.
    Back,
}

// Indicates why a `Device` was lost. Corresponds to a [`GPUDeviceLostReason`].
//
// [`GPUDeviceLostReason`]:
// https://www.w3.org/TR/webgpu/#enumdef-gpudevicelostreason
Device_Lost_Reason :: enum i32 {
    // The device was lost for an unspecified reason (e.g. driver error, GPU
    // reset, power management, hardware removal, etc.).
    Unknown,
    // The device’s `destroy` method was called explicitly by the application.
    Destroyed,
    // The device-lost callback was cancelled. This can occur if the callback is
    // replaced/unset, the instance is dropped, or the device is cleaned up
    // without a specific error.
    Callback_Cancelled,
    // The device failed to be created (the returned device is already in the
    // lost state).
    Failed_Creation,
}

// Specifies which class of errors an error scope should capture when using
// `device_push_error_scope`.
Error_Filter :: enum i32 {
    // Capture only validation errors. These occur when invalid parameters or
    // states are passed to the API.
    Validation,
    // Capture out-of-memory errors. These occur when a resource allocation
    // fails due to insufficient GPU memory.
    Out_Of_Memory,
    // Capture internal errors. These are unexpected errors originating from the
    // implementation itself.
    Internal,
}

// Errors resulting from usage of GPU APIs.
//
// By default, errors translate into panics. Depending on the backend and
// circumstances, errors may occur synchronously or asynchronously. When errors
// need to be handled, use `device_push_error_scope()` or
// `device_on_uncaptured_error()`.
Error_Type :: enum i32 {
    // No error occurred.
    No_Error,
    // Validation error, signifying an internal bug in code or data.
    Validation,
    // Out of memory.
    Out_Of_Memory,
    // Internal error. Used for signalling any failures not explicitly expected
    // by WebGPU. These could be due to internal implementation or system limits
    // being reached.
    Internal,
    // An unknown error occurred (a catch-all for errors that do not fit the
    // other categories).
    Unknown,
}

// Texel mixing mode when sampling between texels.
//
// Corresponds to [WebGPU `GPUFilterMode`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpufiltermode).
Filter_Mode :: enum i32 {
    // Nearest neighbor sampling.
    //
    // This creates a pixelated effect.
    Nearest,
    // Linear Interpolation
    //
    // This makes textures smooth but blurry.
    Linear,
}

// Vertex winding order which classifies the "front" face of a triangle.
//
// Corresponds to [WebGPU `GPUFrontFace`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpufrontface).
Front_Face :: enum i32 {
    // Triangles with vertices in counter clockwise order are considered the
    // front face.
    //
    // This is the default with right handed coordinate spaces.
    CCW,
    // Triangles with vertices in clockwise order are considered the front face.
    //
    // This is the default with left handed coordinate spaces.
    CW,
}

// Format of indices used with pipeline.
//
// Corresponds to [WebGPU `GPUIndexFormat`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpuindexformat).
Index_Format :: enum i32 {
    // Indicates that no value was provided for this argument.
    Undefined,
    //Indices are 32 bit unsigned integers.
    Uint32,
    // Indices are 16 bit unsigned integers.
    Uint16,
}

// Operation to perform to the output attachment at the start of a render pass.
//
// Corresponds to [WebGPU
// `GPULoadOp`](https://gpuweb.github.io/gpuweb/#enumdef-gpuloadop).
Load_Op :: enum i32 {
    // Indicates that no value was provided for this argument (sentinel value).
    Undefined,
    // Loads the existing contents of the attachment into the render pass.
    Load,
    // Clears the attachment to a specified clear value (`clear_value` /
    // `depth_clear_value` / `stencil_clear_value`) before the render pass
    // begins.
    Clear,
    // The render target has undefined contents at the start of the render pass.
    // This may lead to undefined behavior if you read from the any of the
    // render target pixels without first writing to them.
    //
    // Blending also becomes undefined behavior if the source pixels are
    // undefined.
    //
    // This is the fastest option on all GPUs if you always overwrite all pixels
    // in the render target after this load operation.
    //
    // Backends that don't support `DONT_CARE` internally, will pick a different
    // (unspecified) load op instead.
    //
    // All pixels in the render target must be written to before any read or a
    // `StoreOp.STORE` occurs.
    Dont_Care,
}

// Status code returned by the callback of an asynchronous buffer map operation
// `buffer_map_async`.
Map_Async_Status :: enum i32 {
    // The buffer was successfully mapped. The mapped range is now accessible.
    Success,
    // The callback was cancelled (for example because the last external
    // reference to the instance was dropped, or the operation was explicitly
    // cancelled).
    Callback_Cancelled,
    // An error occurred while trying to map the buffer (validation error,
    // device lost, out-of-memory, etc.).
    Error,
    // The mapping operation was aborted (commonly because the buffer was
    // destroyed or the device was lost before the map completed).
    Aborted,
}

// Texel mixing mode when sampling between texels.
//
// Corresponds to [WebGPU `GPUMipmapFilterMode`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpumipmapfiltermode).
Mipmap_Filter_Mode :: enum i32 {
    // Nearest neighbor sampling.
    //
    // Return the value of the texel nearest to the texture coordinates.
    Nearest,
    // Linear Interpolation
    //
    // Select two texels in each dimension and return a linear interpolation
    // between their values.
    Linear,
}

// Status code delivered to the callback of `device_pop_error_scope()`.
Pop_Error_Scope_Status :: enum i32 {
    // The error scope was successfully popped. If an error was captured, it is
    // provided to the callback; otherwise the error parameter is nil/empty.
    Success,
    // The callback was cancelled (for example because the last external
    // reference to the instance was dropped).
    Callback_Cancelled,
    // An error occurred while trying to pop the error scope (for example the
    // error-scope stack was empty).
    Error,
}

// Power Preference when choosing a physical adapter.
//
// Corresponds to [WebGPU `GPUPowerPreference`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpupowerpreference).
Power_Preference :: enum i32 {
    // Power usage is not considered when choosing an adapter.
    None,
    // Adapter that uses the least possible power. This is often an integrated GPU.
    Low_Power,
    // Adapter that has the highest performance. This is often a discrete GPU.
    High_Performance,
}

// Color spaces supported on the web.
//
// Corresponds to [HTML Canvas `PredefinedColorSpace`](
// https://html.spec.whatwg.org/multipage/canvas.html#predefinedcolorspace).
Predefined_Color_Space :: enum i32 {
    // sRGB color space.
    SRGB,
    // Display-P3 color space.
    DisplayP3,
}

// Timing and queueing with which frames are actually displayed to the user.
//
// Use this as part of a `Surface_Configuration` to control the behavior of
// `surface_present()`.
//
// Some modes are only supported by some backends. You can use one of the
// `Auto*` modes, `Fifo`, or choose one of the supported modes from
// `Surface_Capabilities.present_modes`].
Present_Mode :: enum i32 {
    // Presentation frames are kept in a First-In-First-Out queue approximately
    // 3 frames long. Every vertical blanking period, the presentation engine
    // will pop a frame off the queue to display. If there is no frame to
    // display, it will present the same frame again until the next vblank.
    //
    // When a present command is executed on the GPU, the presented image is
    // added on the queue.
    //
    // Calls to `surface_get_current_texture()` will block until there is a spot
    // in the queue.
    //
    // * **Tearing:** No tearing will be observed.
    // * **Supported on**: All platforms.
    // * **Also known as**: "Vsync On"
    //
    // This is the default value for `Present_Mode`. If you don't know what mode
    // to choose, choose this mode.
    Fifo,
    // Chooses the first supported mode out of:
    //
    // 1. `FifoRelaxed`
    // 2. `Fifo`
    //
    // Because of the fallback behavior, this is supported everywhere.
    Auto_Vsync,
    // Chooses the first supported mode out of:
    //
    // 1. `Immediate`
    // 2. `Mailbox`
    // 3. `Fifo`
    //
    // Because of the fallback behavior, this is supported everywhere.
    Auto_No_Vsync,
    // Presentation frames are kept in a First-In-First-Out queue approximately
    // 3 frames long. Every vertical blanking period, the presentation engine
    // will pop a frame off the queue to display. If there is no frame to
    // display, it will present the same frame until there is a frame in the
    // queue. The moment there is a frame in the queue, it will immediately pop
    // the frame off the queue.
    //
    // When a present command is executed on the GPU, the presented image is
    // added on the queue.
    //
    // Calls to `surface_get_current_texture()` will block until there is a
    // spot in the queue.
    //
    // * **Tearing**: Tearing will be observed if frames last more than one
    //   vblank as the front buffer.
    // * **Supported on**: AMD on Vulkan.
    // * **Also known as**: "Adaptive Vsync"
    Fifo_Relaxed,
    // Presentation frames are not queued at all. The moment a present command
    // is executed on the GPU, the presented image is swapped onto the front
    // buffer immediately.
    //
    // * **Tearing**: Tearing can be observed.
    // * **Supported on**: Most platforms except older DX12 and Wayland.
    // * **Also known as**: "Vsync Off"
    Immediate,
    // Presentation frames are kept in a single-frame queue. Every vertical
    // blanking period, the presentation engine will pop a frame from the queue.
    // If there is no frame to display, it will present the same frame again
    // until the next vblank.
    //
    // When a present command is executed on the GPU, the frame will be put into
    // the queue. If there was already a frame in the queue, the new frame will
    // _replace_ the old frame on the queue.
    //
    // * **Tearing**: No tearing will be observed.
    // * **Supported on**: DX12 on Windows 10, NVidia on Vulkan and Wayland on
    //   Vulkan.
    // * **Also known as**: "Fast Vsync"
    Mailbox,
}

// Primitive type the input mesh is composed of.
//
// Corresponds to [WebGPU `GPUPrimitiveTopology`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpuprimitivetopology).
Primitive_Topology :: enum i32 {
    // Vertex data is a list of triangles. Each set of 3 vertices composes a new triangle.
    //
    // Vertices `0 1 2 3 4 5` create two triangles `0 1 2` and `3 4 5`
    Triangle_List,
    // Vertex data is a list of points. Each vertex is a new point.
    Point_List,
    // Vertex data is a list of lines. Each pair of vertices composes a new line.
    //
    // Vertices `0 1 2 3` create two lines `0 1` and `2 3`
    Line_List,
    // Vertex data is a strip of lines. Each set of two adjacent vertices form a line.
    //
    // Vertices `0 1 2 3` create three lines `0 1`, `1 2`, and `2 3`.
    Line_Strip,
    // Vertex data is a triangle strip. Each set of three adjacent vertices form a triangle.
    //
    // Vertices `0 1 2 3 4 5` create four triangles `0 1 2`, `2 1 3`, `2 3 4`, and `4 3 5`
    Triangle_Strip,
}

// Type of drawing mode for polygons
Polygon_Mode :: enum i32 {
    // Polygons are filled
    Fill,
    // Polygons are drawn as line segments
    Line,
    // Polygons are drawn as points
    Point,
}

// Type of queries contained in a `Query_Set`.
//
// Each query set may contain any number of queries, but they must all be of the same type.
//
// Corresponds to [WebGPU `GPUQueryType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpuquerytype).
Query_Type :: enum i32 {
    // An occlusion query reports whether any of the fragments drawn within the
    // scope of the query passed all per-fragment tests (i.e. were not
    // occluded).
    //
    // Occlusion queries are performed by setting
    // `Render_Pass_Descriptor.occlusion_query_set`, then calling
    // `render_pass_begin_occlusion_query()` and
    // `render_pass_end_occlusion_query()`. The query writes to a single result
    // slot in the query set, whose value will be either 0 or 1 as a boolean.
    Occlusion,
    // A timestamp query records a GPU-timestamp value at which a certain
    // command started or finished executing.
    //
    // Timestamp queries are performed by any one of:
    //
    // * Setting `Compute_Pass_Descriptor.timestamp_writes`
    // * Setting `Render_Pass_Descriptor.timestamp_writes`
    // * Calling `command_encoder_write_timestamp()`]
    // * Calling `render_pass_write_timestamp()`]
    // * Calling `compute_pass_write_timestamp()`]
    //
    // Each timestamp query writes to a single result slot in the query set. The
    // timestamp value must be multiplied by `queue_get_timestamp_period()` to
    // get the time in nanoseconds. Absolute values have no meaning, but
    // timestamps can be subtracted to get the time it takes for a string of
    // operations to complete. Timestamps may overflow and wrap to 0, resulting
    // in occasional spurious negative deltas.
    //
    // Additionally, passes may be executed in parallel or out of the order they
    // were submitted; this does not affect their results but is observable via
    // these timestamps.
    //
    // `Timestamp_Query` feature must be enabled to use this query type.
    Timestamp,
    // A pipeline statistics query records information about the execution of
    // pipelines.
    //
    // Pipeline statistics queries are performed by:
    //
    // `compute_pass_begin_pipeline_statistics_query()`
    // `render_pass_begin_pipeline_statistics_query()`
    //
    // A single query may occupy up to 5 result slots in the query set, based on
    // the flags given here.
    //
    // `Pipeline_Statistics_Query` feature must be enabled to use this query type.
    Pipeline_Statistics,
}

// Status code delivered to the callback of `queue_on_submitted_work_done()`.
Queue_Work_Done_Status :: enum i32 {
    // All previously submitted work on the queue has completed successfully.
    Success,
    // The callback was cancelled (for example because the last external
    // reference to the instance was dropped).
    Callback_Cancelled,
    // An error occurred (most commonly the device was lost before the work finished).
    Error,
}

// Status code delivered to the callback of `instance_request_adapter()`.
Request_Adapter_Status :: enum i32 {
    // An adapter was successfully obtained. The callback receives a valid `Adapter`.
    Success,
    // The callback was cancelled (for example because the last external
    // reference to the instance was dropped).
    Callback_Cancelled,
    // No suitable adapter could be found that matches the requested options
    // (power preference, feature level, backend, etc.).
    Unavailable,
    // An unexpected error occurred while trying to request an adapter.
    Error,
}

// Specific type of a sampler binding.
//
// For use in `Binding_Type.Sampler`.
//
// Corresponds to [WebGPU `GPUSamplerBindingType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpusamplerbindingtype).
Sampler_Binding_Type :: enum i32 {
    // Indicates that this `Sampler_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // The sampling result is produced based on more than a single color sample
    // from a texture, e.g. when bilinear interpolation is enabled.
    Filtering,
    // The sampling result is produced based on a single color sample from a texture.
    Non_Filtering,
    // Use as a comparison sampler instead of a normal sampler. For more info
    // take a look at the analogous functionality in OpenGL:
    //
    // https://www.khronos.org/opengl/wiki/Sampler_Object#Comparison_mode.
    Comparison,
}

// Operation to perform on the stencil value.
//
// Corresponds to [WebGPU `GPUStencilOperation`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpustenciloperation).
Stencil_Operation :: enum i32 {
    // Keep stencil value unchanged.
    Keep,
    // Set stencil value to zero.
    Zero,
    // Replace stencil value with value provided in most recent call to
    // `render_pass_set_stencil_reference`.
    //
    Replace,
    // Bitwise inverts stencil value.
    Invert,
    // Increments stencil value by one, clamping on overflow.
    Increment_Clamp,
    // Decrements stencil value by one, clamping on underflow.
    Decrement_Clamp,
    // Increments stencil value by one, wrapping on overflow.
    Increment_Wrap,
    // Decrements stencil value by one, wrapping on underflow.
    Decrement_Wrap,
}

// Specific type of a sample in a texture binding.
//
// For use in `Binding_Type.Storage_Texture`.
//
// Corresponds to [WebGPU `GPUStorageTextureAccess`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpustoragetextureaccess).
Storage_Texture_Access :: enum i32 {
    // Indicates that this `Storage_Texture_Binding_Layout` member of its
    // parent `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // The texture can only be written in the shader.
    Write_Only,
    // The texture can only be read in the shader.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to
    // use this access mode. This is a native-only extension.
    Read_Only,
    // The texture can be both read and written in the shader.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to use
    // this access mode.  This is a nonstandard, native-only extension.
    Read_Write,
    // The texture can be both read and written in the shader via atomics.
    //
    // `Texture_Adapter_Specific_Format_Features` feature must be enabled to
    // use this access mode.  This is a nonstandard, native-only extension.
    Atomic,
}

// Operation to perform to the output attachment at the end of a render pass.
//
// Corresponds to [WebGPU `GPUStoreOp`](https://gpuweb.github.io/gpuweb/#enumdef-gpustoreop).
Store_Op :: enum i32 {
    // Indicates that no value was provided for this argument (sentinel value).
    Undefined,
    // Stores the resulting value of the render pass for this attachment.
    Store,
    // Discards the resulting value of the render pass for this attachment.
    //
    // The attachment will be treated as uninitialized afterwards.
    // (If only either Depth or Stencil texture-aspects is set to `Discard`,
    // the respective other texture-aspect will be preserved.)
    //
    // This can be significantly faster on tile-based render hardware.
    //
    // Prefer this if the attachment is not read by subsequent passes.
    Discard,
}

// Result of a call to `surface_get_current_texture`.
//
// See variant documentation for how to handle each case.
Surface_Get_Current_Texture_Status :: enum i32 {
    Unknown,
    // Successfully acquired a surface texture with no issues.
    Success,
    // Successfully acquired a surface texture, but texture no longer matches
    // the properties of the underlying surface. It's highly recommended to call
    // `surface_configure` again for optimal performance.
    Suboptimal,
    // A timeout was encountered while trying to acquire the next frame.
    //
    // Applications should skip the current frame and try again later.
    Timeout,
    // The window is occluded (e.g. minimized or behind another window).
    //
    // Applications should skip the current frame and try again once the window
    // is no longer occluded.
    Occluded,
    // The underlying surface has changed, and therefore the surface
    // configuration is outdated.
    //
    // Call `surface_configure()` and try again.
    Outdated,
    // The surface has been lost and needs to be recreated.
    //
    // If the device as a whole is lost, then you need to recreate the device
    // and all resources. Otherwise, call `instance_create_surface()` to
    // recreate the surface, then `surface_configure()`, and try again.
    Lost,
    // A validation error inside `surface_get_current_texture()` was raised and
    // caught by an error scope or `on_uncaptured_error().
    //
    // Applications should attend to the validation error and try again.
    Validation,
}

// Selects a subset of the data a `Texture` holds.
//
// Used in texture views and texture copy operations.
//
// Corresponds to [WebGPU `GPUTextureAspect`](
// https://gpuweb.github.io/gpuweb/#enumdef-gputextureaspect).
Texture_Aspect :: enum i32 {
    // Depth, Stencil, and Color.
    All,
    // Stencil.
    Stencil_Only,
    // Depth.
    Depth_Only,
    // Plane 0.
    Plane0,
    // Plane 1.
    Plane1,
    // Plane 2.
    Plane2,
}

aspect_index :: proc "contextless" (aspect: Texture_Aspect, loc := #caller_location) -> u32 {
    switch aspect {
    case .Plane0: return 0
    case .Plane1: return 1
    case .Plane2: return 2
    case .Depth_Only,
         .Stencil_Only,
         .All:
            return 0
    }
    unreachable()
}

aspect_includes_depth :: proc "contextless" (aspect: Texture_Aspect) -> bool {
    return aspect == .Depth_Only || aspect == .All
}

aspect_includes_stencil :: proc "contextless" (aspect: Texture_Aspect) -> bool {
    return aspect == .Stencil_Only || aspect == .All
}

// Dimensionality of a texture.
//
// Corresponds to [WebGPU `GPUTextureDimension`](
// https://gpuweb.github.io/gpuweb/#enumdef-gputexturedimension).
Texture_Dimension :: enum i32 {
    // Indicates no value is passed for this argument.
    Undefined,
    // 1D texture.
    D1,
    // 2D texture.
    D2,
    // 3D texture.
    D3,
}

// Specific type of a sample in a texture binding.
//
// Corresponds to [WebGPU `GPUTextureSampleType`](
// https://gpuweb.github.io/gpuweb/#enumdef-gputexturesampletype).
Texture_Sample_Type :: enum i32 {
    // Indicates that this `Texture_Binding_Layout` member of its parent
    // `Bind_Group_Layout_Entry` is not used.
    Binding_Not_Used,
    // Indicates no value is passed for this argument.
    Undefined,
    // Sampling returns floating-point values. Compatible with filtering samplers.
    Float,
    // Sampling returns floating-point values, but the texture cannot be sampled
    // with a filtering sampler.
    Unfilterable_Float,
    // Sampling does the depth reference comparison.
    //
    // This is also compatible with a non-filtering sampler.
    Depth,
    // Sampling returns signed integers.
    Sint,
    // Sampling returns unsigned integers.
    Uint,
}

// Dimensions of a particular texture view.
//
// Corresponds to [WebGPU `GPUTextureViewDimension`](
// https://gpuweb.github.io/gpuweb/#enumdef-gputextureviewdimension).
Texture_View_Dimension :: enum i32 {
    // A two dimensional texture.
    D2,
    // A one dimensional texture.
    D1,
    // A two dimensional array texture.
    D2_Array,
    // A cubemap texture.
    Cube,
    // A cubemap array texture.
    Cube_Array,
    // A three dimensional texture.
    D3,
}

// Defines how color values written to a surface/canvas are tone-mapped when
// presented to the display.
Tone_Mapping_Mode :: enum i32 {
    // Restricts content to the Standard Dynamic Range (SDR) of the screen.
    // Color values in the screen’s color space are clamped (or otherwise
    // projected) to the `[0, 1]` interval. This is the default.
    Standard,
    // Unlocks the **full High Dynamic Range (HDR)** of the screen (when
    // available). Behavior matches `Standard` inside the `[0, 1]` range; values
    // outside that range are projected onto the extended dynamic range of the
    // display instead of being clamped to `[0, 1]`.
    Extended,
}

// Vertex attribute data format.
//
// Corresponds to [WebGPU `GPUVertexFormat`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpuvertexformat).
Vertex_Format :: enum i32 {
    // One unsigned 8-bit integer (`u8`).
    Uint8,
    // Two unsigned 8-bit integers (`u8`).
    Uint8x2,
    // Four unsigned 8-bit integers (`u8`).
    Uint8x4,
    // One signed 8-bit integer (`i8`).
    Sint8,
    // Two signed 8-bit integers (`i8`).
    Sint8x2,
    // Four signed 8-bit integers (`i8`).
    Sint8x4,
    // One unsigned 8-bit integer (`u8`). Values in `[0, 255]` are converted to
    // float `[0, 1]` in shaders.
    Unorm8,
    // Two unsigned 8-bit normalized integers.
    Unorm8x2,
    // Four unsigned 8-bit normalized integers.
    Unorm8x4,
    // One signed 8-bit normalized integer. Values in `[-127, 127]` are
    // converted to float `[-1, 1]` in shaders.
    Snorm8,
    // Two signed 8-bit normalized integers.
    Snorm8x2,
    // Four signed 8-bit normalized integers.
    Snorm8x4,
    // One unsigned 16-bit integer (`u16`).
    Uint16,
    // Two unsigned 16-bit integers (`u16`).
    Uint16x2,
    // Four unsigned 16-bit integers (`u16`).
    Uint16x4,
    // One signed 16-bit integer (`i16`).
    Sint16,
    // Two signed 16-bit integers (`i16`).
    Sint16x2,
    // Four signed 16-bit integers (`i16`).
    Sint16x4,
    // One unsigned 16-bit normalized integer. Values in `[0, 65535]` are
    // converted to float `[0, 1]` in shaders.
    Unorm16,
    // Two unsigned 16-bit normalized integers.
    Unorm16x2,
    // Four unsigned 16-bit normalized integers.
    Unorm16x4,
    // One signed 16-bit normalized integer. Values in `[-32767, 32767]` are
    // converted to float `[-1, 1]` in shaders.
    Snorm16,
    // Two signed 16-bit normalized integers.
    Snorm16x2,
    // Four signed 16-bit normalized integers.
    Snorm16x4,
    // One 16-bit floating-point value (`f16`).
    Float16,
    // Two 16-bit floating-point values (`f16`).
    Float16x2,
    // Four 16-bit floating-point values (`f16`).
    Float16x4,
    // One 32-bit floating-point value (`f32`).
    Float32,
    // Two 32-bit floating-point values (`f32`).
    Float32x2,
    // Three 32-bit floating-point values (`f32`).
    Float32x3,
    // Four 32-bit floating-point values (`f32`).
    Float32x4,
    // One unsigned 32-bit integer (`u32`).
    Uint32,
    // Two unsigned 32-bit integers (`u32`).
    Uint32x2,
    // Three unsigned 32-bit integers (`u32`).
    Uint32x3,
    // Four unsigned 32-bit integers (`u32`).
    Uint32x4,
    // One signed 32-bit integer (`i32`).
    Sint32,
    // Two signed 32-bit integers (`i32`).
    Sint32x2,
    // Three signed 32-bit integers (`i32`).
    Sint32x3,
    // Four signed 32-bit integers (`i32`).
    Sint32x4,
    // Four normalized unsigned integers packed into 32 bits (10 + 10 + 10 + 2).
    Unorm10_10_10_2,
    // Four unsigned 8-bit normalized integers in BGRA order.
    Unorm8x4BGRA,
}

// Whether a vertex buffer is indexed by vertex or by instance.
//
// Consider a call to `render_pass_draw` like this:
//
//    render_pass_draw(vertices, instances)
//
// where `vertices` is a `Range(u32)` of vertex indices, and `instances` is a
// `Range(u32)` of instance indices.
//
// This call invokes the vertex shader entry point once for every possible `(v,
// i)` pair, where `v` is drawn from `vertices` and `i` is drawn from
// `instances`. These invocations may happen in any order, and will usually run
// in parallel.
//
// Each vertex buffer has a step mode, established by the `step_mode` field of
// its `Vertex_Buffer_Layout`, given when the pipeline was created. Buffers
// whose step mode is `Vertex` use `v` as the index into their contents,
// whereas buffers whose step mode is [`Instance`] use `i`. The indicated buffer
// element then contributes zero or more attribute values for the `(v, i)`
// vertex shader invocation to use, based on the `Vertex_Buffer_Layout`'s
// `attributes` list.
//
// You can visualize the results from all these vertex shader invocations as a
// matrix with a row for each `i` from `instances`, and with a column for each
// `v` from `vertices`. In one sense, `v` and `i` are symmetrical: both are used
// to index vertex buffers and provide attribute values.  But the key difference
// between `v` and `i` is that line and triangle primitives are built from the
// values of each row, along which `i` is constant and `v` varies, not the
// columns.
//
// An indexed draw call works similarly:
//
//    render_pass_draw_indexed(indices, base_vertex, instances)
//
// The only difference is that `v` values are drawn from the contents of the
// index buffer&mdash;specifically, the subrange of the index buffer given by
// `indices`&mdash;instead of simply being sequential integers, as they are in a
// `draw` call.
//
// A non-instanced call, where `instances` is `0..1`, is simply a matrix with
// only one row.
//
// Corresponds to [WebGPU `GPUVertexStepMode`](
// https://gpuweb.github.io/gpuweb/#enumdef-gpuvertexstepmode).
Vertex_Step_Mode :: enum i32 {
    // Vertex data is advanced every vertex.
    Vertex,
    // Vertex data is advanced every instance.
    Instance,
}

// Status code returned by`instance_wait_any()`.
Wait_Status :: enum i32 {
    // At least one future completed successfully. Completed futures have their
    // callbacks fired (when applicable) and their `completed` flag set.
    Success,
    // The timeout elapsed without any of the waited futures completing.
    Timed_Out,
    // The call was invalid (e.g. timed wait used without the `Timed_Wait_Any`
    // instance feature, too many futures, or mixed-source wait).
    Error,
}

WGSL_Language_Feature_Name :: enum i32 {
    Readonly_And_Readwrite_Storage_Textures,
    Packed4X8_Integer_Dot_Product,
    Unrestricted_Pointer_Parameters,
    Pointer_Composite_Access,
    Uniform_Buffer_Standard_Layout,
    Subgroup_Id,
    Texture_And_Sampler_Let,
    Subgroup_Uniformity,
    Texture_Formats_Tier1,
    Linear_Indexing,
    Immediate_Address_Space,
    Buffer_View,
}

// Different ways that you can use a buffer.
Buffer_Usage :: enum i32 {
    // Allow a buffer to be mapped for reading using `buffer_map_async` +
    // `buffer_get_mapped_range`. This does not include creating a buffer with
    // `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Mappable_Primary_Buffers` feature isn't enabled, the only other usage
    // a buffer may have is `Copy_Dst`.
    Map_Read,
    // Allow a buffer to be mapped for writing using `buffer_map_async` +
    // `buffer_get_mapped_range_mut`. This does not include creating a buffer
    // with `Buffer_Descriptor.mapped_at_creation` set.
    //
    // If `Mappable_Primary_Buffers` feature feature isn't enabled, the only
    // other usage a buffer may have is `Copy_Src`.
    Map_Write,
    // Allow a buffer to be the source buffer for a
    // `command_encoder_copy_buffer_to_buffer` or
    // `command_encoder_copy_buffer_to_texture` / operation.
    Copy_Src,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_copy_buffer_to_buffer`,
    // `command_encoder_copy_texture_to_buffer`, `command_encoder_clear_buffer`
    // or `queue_write_buffer` operation.
    Copy_Dst,
    // Allow a buffer to be the index buffer in a draw operation.
    Index,
    // Allow a buffer to be the vertex buffer in a draw operation.
    Vertex,
    // Allow a buffer to be a `Buffer_Binding_Type.Uniform` inside a bind group.
    Uniform,
    // Allow a buffer to be a `Buffer_Binding_Type.Storage` inside a bind group.
    Storage,
    // Allow a buffer to be the indirect buffer in an indirect draw call.
    Indirect,
    // Allow a buffer to be the destination buffer for a
    // `command_encoder_resolve_query_set` operation.
    Query_Resolve,
    // Allows a buffer to be used as input for a bottom level acceleration
    // structure build
    Blas_Input,
    // Allows a buffer to be used as input for a top level acceleration
    // structure build
    Tlas_Input,
}

// Different ways that you can use a buffer.
//
// The usages determine what kind of memory the buffer is allocated from and
// what actions the buffer can partake in.
//
// Specifying only usages the application will actually perform may increase
// performance. Additionally, on the WebGL backend, there are restrictions on
// `Index`.
//
// Corresponds to [WebGPU `GPUBufferUsageFlags`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpubufferusageflags).
Buffer_Usages :: bit_set[Buffer_Usage;Flags]

// Whether any usages in `other` are also set in `self`.
buffer_usage_intersects :: #force_inline proc "contextless" (self, mask: Buffer_Usages) -> bool {
    return (self & mask) != {}
}

// Whether all usages in `other` are also set in `self`.
buffer_usage_contains :: #force_inline proc "contextless" (self, other: Buffer_Usages) -> bool {
    return (self & other) == other
}

// Color write mask. Disabled color channels will not be written to.
Color_Write :: enum i32 {
    // Enable red channel writes.
    Red,
    // Enable green channel writes.
    Green,
    // Enable blue channel writes.
    Blue,
    // Enable alpha channel writes.
    Alpha,
}

// Color write mask. Disabled color channels will not be written to.
//
// Corresponds to [WebGPU `GPUColorWriteFlags`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpucolorwriteflags).
Color_Writes :: bit_set[Color_Write;Flags]

// No color writes.
COLOR_WRITES_NONE :: Color_Writes{}

// Enable red, green, and blue channel writes
COLOR_WRITES_COLOR :: Color_Writes{.Red, .Green, .Blue}

// Enable writes to all channels.
COLOR_WRITES_ALL :: Color_Writes{.Red, .Green, .Blue, .Alpha}

// Enable writes to all channels.
COLOR_WRITES_DEFAULT :: COLOR_WRITES_ALL

// Type of buffer mapping.
Map_Mode :: enum i32 {
    // Map only for reading.
    Read,
    // Map only for writing.
    Write,
}

// Types of buffer mapping.
Map_Modes :: bit_set[Map_Mode;Flags]

Shader_Stage :: enum i32 {
    // Binding is visible from the vertex shader of a render pipeline.
    Vertex,
    // Binding is visible from the fragment shader of a render pipeline.
    Fragment,
    //  is visible from the compute shader of a compute pipeline.
    Compute,
}

// Describes the shader stages that a binding will be visible from.
//
// These can be combined so something that is visible from both vertex and
// fragment shaders can be defined as:
//
// `{.Vertex, .Fragment}`
//
// Corresponds to [WebGPU `GPUShaderStageFlags`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gpushaderstageflags).
Shader_Stages :: bit_set[Shader_Stage;Flags]

// Binding is visible from the vertex and fragment shaders of a render pipeline.
SHADER_STAGES_FRAGMENT :: Shader_Stages{.Vertex, .Fragment}

// Different ways that you can use a texture.
Texture_Usage :: enum i32 {
    // Allows a texture to be the source in a
    // `command_encoder_copy_texture_to_buffer` or
    // `command_encoder_copy_texture_to_texture` operation.
    Copy_Src,
    // Allows a texture to be the destination in a
    // `command_encoder_copy_buffer_to_texture`,
    // `command_encoder_copy_texture_to_texture`, or `queue_write_texture`
    // operation.
    Copy_Dst,
    // Allows a texture to be a `Binding_Type.Texture` in a bind group.
    Texture_Binding,
    // Allows a texture to be a `Binding_Type.Storage_Texture` in a bind group.
    Storage_Binding,
    // Allows a texture to be an output attachment of a render pass.
    //
    // Consider adding `Transient_Attachment` if the contents are not reused.
    Render_Attachment,
    // Specifies the contents of this texture will not be used in another pass
    // to potentially reduce memory usage and bandwidth.
    //
    // No-op on platforms on platforms that do not benefit from transient
    // textures. Generally mobile and Apple chips care about this.
    //
    // Incompatible with ALL other usages except `Render_Attachment` and
    // requires it.
    //
    // Requires `Load_Op.Clear` or `Load_Op.Dont_Care` (if it is available) and
    // `Store_Op.Discard`.
    Transient_Attachment,
    // Allows a texture to be used with image atomics. Requires
    // `Texture_Atomic` feature.
    Storage_Atomic,
}

// Different ways that you can use a texture.
//
// The usages determine what kind of memory the texture is allocated from and
// what actions the texture can partake in.
//
// Corresponds to [WebGPU `GPUTextureUsageFlags`](
// https://gpuweb.github.io/gpuweb/#typedefdef-gputextureusageflags).
Texture_Usages :: bit_set[Texture_Usage;Flags]

// Flags for which pipeline data should be recorded in a query.
//
// Used in `Query_Type`.
//
// The amount of values written when resolved depends
// on the amount of flags set. For example, if 3 flags are set, 3
// 64-bit values will be written per query.
//
// The order they are written is the order they are declared
// in these bitflags. For example, if you enabled `Clipper_Primitives_Out`
// and `Compute_Shader_Invocations`, it would write 16 bytes,
// the first 8 bytes being the primitive out value, the last 8
// bytes being the compute shader invocation count.
Pipeline_Statistics_Types :: enum i32 {
    // Amount of times the vertex shader is ran. Accounts for
    // the vertex cache when doing indexed rendering.
    Vertex_Shader_Invocations,
    // Amount of times the clipper is invoked. This
    // is also the amount of triangles output by the vertex shader.
    Clipper_Invocations,
    // Amount of primitives that are not culled by the clipper.
    // This is the amount of triangles that are actually on screen
    // and will be rasterized and rendered.
    Clipper_Primitives_Out,
    // Amount of times the fragment shader is ran. Accounts for
    // fragment shaders running in 2x2 blocks in order to get
    // derivatives.
    Fragment_Shader_Invocations,
    // Amount of times a compute shader is invoked. This will
    // be equivalent to the dispatch count times the workgroup size.
    Compute_Shader_Invocations,
}

Submission_Index :: distinct u64

// RGBA double precision color.
//
// This is not to be used as a generic color type, only for specific gpu interfaces.
Color :: [4]f64

COLOR_TRANSPARENT :: Color{0, 0, 0, 0}
COLOR_BLACK       :: Color{0, 0, 0, 1}
COLOR_WHITE       :: Color{1, 1, 1, 1}
COLOR_RED         :: Color{1, 0, 0, 1}
COLOR_GREEN       :: Color{0, 1, 0, 1}
COLOR_BLUE        :: Color{0, 0, 1, 1}

// Generic status code returned by many WebGPU operations.
Status :: enum i32 {
    // The operation completed successfully.
    Success,
    // The operation failed (invalid arguments, unknown enum value,
    // out-of-struct-chain error, or other validation / internal failure).
    Error,
}

// Origin of a copy to/from a texture.
//
// Corresponds to [WebGPU `GPUOrigin3D`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuorigin3ddict).
Origin_3D :: [3]u32

// Extent of a texture related operation.
//
// Corresponds to [WebGPU `GPUExtent3D`](
// https://gpuweb.github.io/gpuweb/#dictdef-gpuextent3ddict).
Extent_3D :: struct {
    // Width of the extent.
    width:                 u32,
    // Height of the extent.
    height:                u32,
    // The depth of the extent or the number of array layers.
    depth_or_array_layers: u32,
}

DEFAULT_EXTENT_3D :: Extent_3D {
    width                 = 0,
    height                = 1,
    depth_or_array_layers = 1,
}

// Load/store operations and clear value for an attachment aspect.
//
// Used for both color attachments and depth/stencil attachments.
Operations :: struct($T: typeid) {
    // How data should be read through this attachment.
    load:        Load_Op,
    // Whether data will be written to through this attachment.
    //
    // Note that resolve textures (if specified) are always written to,
    // regardless of this setting.
    store:       Store_Op,
    // Value used when `load` is `.Clear`. Ignored otherwise.
    clear_value: T,
}
