package egl

// //
// // Copyright 2017 The ANGLE Project Authors. All rights reserved.
// // Use of this source code is governed by a BSD-style license that can be
// // found in the LICENSE file.
// //
// // eglext_angle.h: ANGLE modifications to the eglext.h header file.
// //   Currently we don't include this file directly, we patch eglext.h
// //   to include it implicitly so it is visible throughout our code.

// #ifndef INCLUDE_EGL_EGLEXT_ANGLE_
// #define INCLUDE_EGL_EGLEXT_ANGLE_

// // clang-format off

// #ifndef EGL_ANGLE_robust_resource_initialization
// ANGLE_robust_resource_initialization 1
// ROBUST_RESOURCE_INITIALIZATION_ANGLE 0x3453
// #endif /* EGL_ANGLE_robust_resource_initialization */

// #ifndef EGL_ANGLE_keyed_mutex
// ANGLE_keyed_mutex 1
// DXGI_KEYED_MUTEX_ANGLE        0x33A2
// #endif /* EGL_ANGLE_keyed_mutex */

// #ifndef EGL_ANGLE_d3d_texture_client_buffer
// ANGLE_d3d_texture_client_buffer 1
// D3D_TEXTURE_ANGLE 0x33A3
// TEXTURE_OFFSET_X_ANGLE 0x3490
// TEXTURE_OFFSET_Y_ANGLE 0x3491
// D3D11_TEXTURE_PLANE_ANGLE 0x3492
// D3D11_TEXTURE_ARRAY_SLICE_ANGLE 0x3493
// #endif /* EGL_ANGLE_d3d_texture_client_buffer */

// #ifndef EGL_ANGLE_software_display
// ANGLE_software_display 1
// SOFTWARE_DISPLAY_ANGLE ((EGLNativeDisplayType)-1)
// #endif /* EGL_ANGLE_software_display */

// #ifndef EGL_ANGLE_direct3d_display
// ANGLE_direct3d_display 1
// D3D11_ELSE_D3D9_DISPLAY_ANGLE ((EGLNativeDisplayType)-2)
// D3D11_ONLY_DISPLAY_ANGLE ((EGLNativeDisplayType)-3)
// #endif /* EGL_ANGLE_direct3d_display */

// #ifndef EGL_ANGLE_direct_composition
// ANGLE_direct_composition 1
// DIRECT_COMPOSITION_ANGLE 0x33A5
// #endif /* EGL_ANGLE_direct_composition */

PLATFORM_ANGLE_ANGLE                      :: 0x3202
PLATFORM_ANGLE_TYPE_ANGLE                 :: 0x3203
PLATFORM_ANGLE_MAX_VERSION_MAJOR_ANGLE    :: 0x3204
PLATFORM_ANGLE_MAX_VERSION_MINOR_ANGLE    :: 0x3205
PLATFORM_ANGLE_TYPE_DEFAULT_ANGLE         :: 0x3206
PLATFORM_ANGLE_DEBUG_LAYERS_ENABLED_ANGLE :: 0x3451
PLATFORM_ANGLE_DEVICE_TYPE_ANGLE          :: 0x3209
PLATFORM_ANGLE_DEVICE_TYPE_HARDWARE_ANGLE :: 0x320A
PLATFORM_ANGLE_DEVICE_TYPE_NULL_ANGLE     :: 0x345E
PLATFORM_ANGLE_NATIVE_PLATFORM_TYPE_ANGLE :: 0x348F

// #ifndef EGL_ANGLE_platform_angle_d3d
// ANGLE_platform_angle_d3d 1
// PLATFORM_ANGLE_TYPE_D3D9_ANGLE 0x3207
// PLATFORM_ANGLE_TYPE_D3D11_ANGLE 0x3208
// PLATFORM_ANGLE_DEVICE_TYPE_D3D_WARP_ANGLE 0x320B
// PLATFORM_ANGLE_DEVICE_TYPE_D3D_REFERENCE_ANGLE 0x320C
// PLATFORM_ANGLE_ENABLE_AUTOMATIC_TRIM_ANGLE 0x320F
// #endif /* EGL_ANGLE_platform_angle_d3d */

// #ifndef EGL_ANGLE_platform_angle_d3d_luid
// ANGLE_platform_angle_d3d_luid 1
// PLATFORM_ANGLE_D3D_LUID_HIGH_ANGLE 0x34A0
// PLATFORM_ANGLE_D3D_LUID_LOW_ANGLE 0x34A1
// #endif /* EGL_ANGLE_platform_angle_d3d_luid */

// #ifndef EGL_ANGLE_platform_angle_d3d11on12
// ANGLE_platform_angle_d3d11on12 1
// PLATFORM_ANGLE_D3D11ON12_ANGLE 0x3488
// #endif /* EGL_ANGLE_platform_angle_d3d11on12 */

// #ifndef EGL_ANGLE_platform_angle_opengl
// ANGLE_platform_angle_opengl 1
// PLATFORM_ANGLE_TYPE_OPENGL_ANGLE 0x320D
// PLATFORM_ANGLE_TYPE_OPENGLES_ANGLE 0x320E
// PLATFORM_ANGLE_EGL_HANDLE_ANGLE 0x3480
// #endif /* EGL_ANGLE_platform_angle_opengl */

// #ifndef EGL_ANGLE_platform_angle_null
// ANGLE_platform_angle_null 1
// PLATFORM_ANGLE_TYPE_NULL_ANGLE 0x33AE
// #endif /* EGL_ANGLE_platform_angle_null */

// #ifndef EGL_ANGLE_platform_angle_webgpu
// ANGLE_platform_angle_webgpu 1
// PLATFORM_ANGLE_TYPE_WEBGPU_ANGLE 0x34DD
// PLATFORM_ANGLE_DAWN_PROC_TABLE_ANGLE 0x3468
// PLATFORM_ANGLE_WEBGPU_INSTANCE_ANGLE 0x34F7
// PLATFORM_ANGLE_WEBGPU_DEVICE_ANGLE 0x34F6
// #endif /* EGL_ANGLE_platform_angle_webgpu */

// #ifndef EGL_ANGLE_platform_angle_vulkan
// ANGLE_platform_angle_vulkan 1
// PLATFORM_ANGLE_TYPE_VULKAN_ANGLE 0x3450
// PLATFORM_VULKAN_DISPLAY_MODE_SIMPLE_ANGLE 0x34A4
// PLATFORM_VULKAN_DISPLAY_MODE_HEADLESS_ANGLE 0x34A5
// #endif /* EGL_ANGLE_platform_angle_vulkan */

// #ifndef EGL_ANGLE_platform_angle_vulkan_device_uuid
// ANGLE_platform_angle_vulkan_device_uuid 1
// PLATFORM_ANGLE_VULKAN_DEVICE_UUID_ANGLE 0x34F0
// PLATFORM_ANGLE_VULKAN_DRIVER_UUID_ANGLE 0x34F1
// PLATFORM_ANGLE_VULKAN_DRIVER_ID_ANGLE 0x34F2
// #endif /* EGL_ANGLE_platform_angle_vulkan_device_uuid */

// #ifndef EGL_ANGLE_platform_angle_metal
// ANGLE_platform_angle_metal 1
// PLATFORM_ANGLE_TYPE_METAL_ANGLE 0x3489
// #endif /* EGL_ANGLE_platform_angle_metal  */

// #ifndef EGL_ANGLE_platform_angle_device_type_swiftshader
// ANGLE_platform_angle_device_type_swiftshader
// PLATFORM_ANGLE_DEVICE_TYPE_SWIFTSHADER_ANGLE 0x3487
// #endif /* EGL_ANGLE_platform_angle_device_type_swiftshader */

// #ifndef EGL_ANGLE_platform_angle_device_type_egl_angle
// ANGLE_platform_angle_device_type_egl_angle
// PLATFORM_ANGLE_DEVICE_TYPE_EGL_ANGLE 0x348E
// #endif /* EGL_ANGLE_platform_angle_device_type_egl_angle */

// #ifndef EGL_ANGLE_context_virtualization
// ANGLE_context_virtualization 1
// CONTEXT_VIRTUALIZATION_GROUP_ANGLE 0x3481
// #endif /* EGL_ANGLE_context_virtualization */

// #ifndef EGL_ANGLE_platform_angle_device_context_volatile_eagl
// ANGLE_platform_angle_device_context_volatile_eagl 1
// PLATFORM_ANGLE_DEVICE_CONTEXT_VOLATILE_EAGL_ANGLE 0x34A2
// #endif /* EGL_ANGLE_platform_angle_device_context_volatile_eagl */

// #ifndef EGL_ANGLE_platform_angle_device_context_volatile_cgl
// ANGLE_platform_angle_device_context_volatile_cgl 1
// PLATFORM_ANGLE_DEVICE_CONTEXT_VOLATILE_CGL_ANGLE 0x34A3
// #endif /* EGL_ANGLE_platform_angle_device_context_volatile_cgl */

// #ifndef EGL_ANGLE_platform_angle_device_id
// ANGLE_platform_angle_device_id
// PLATFORM_ANGLE_DEVICE_ID_HIGH_ANGLE 0x34D6
// PLATFORM_ANGLE_DEVICE_ID_LOW_ANGLE 0x34D7
// PLATFORM_ANGLE_DISPLAY_KEY_ANGLE 0x34DC
// #endif /* EGL_ANGLE_platform_angle_device_id */

// #ifndef EGL_ANGLE_x11_visual
// ANGLE_x11_visual
// X11_VISUAL_ID_ANGLE 0x33A3
// #endif /* EGL_ANGLE_x11_visual */

// #ifndef EGL_ANGLE_surface_orientation
// ANGLE_surface_orientation
// OPTIMAL_SURFACE_ORIENTATION_ANGLE 0x33A7
// SURFACE_ORIENTATION_ANGLE 0x33A8
// SURFACE_ORIENTATION_INVERT_X_ANGLE 0x0001
// SURFACE_ORIENTATION_INVERT_Y_ANGLE 0x0002
// #endif /* EGL_ANGLE_surface_orientation */

// #ifndef EGL_ANGLE_experimental_present_path
// ANGLE_experimental_present_path
// EXPERIMENTAL_PRESENT_PATH_ANGLE 0x33A4
// EXPERIMENTAL_PRESENT_PATH_FAST_ANGLE 0x33A9
// EXPERIMENTAL_PRESENT_PATH_COPY_ANGLE 0x33AA
// #endif /* EGL_ANGLE_experimental_present_path */

// #ifndef EGL_ANGLE_stream_producer_d3d_texture
// ANGLE_stream_producer_d3d_texture
// D3D_TEXTURE_SUBRESOURCE_ID_ANGLE 0x33AB
// typedef EGLBoolean(EGLAPIENTRYP PFNEGLCREATESTREAMPRODUCERD3DTEXTUREANGLEPROC)(EGLDisplay dpy, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// typedef EGLBoolean(EGLAPIENTRYP PFNEGLSTREAMPOSTD3DTEXTUREANGLEPROC)(EGLDisplay dpy, EGLStreamKHR stream, void *texture, const EGLAttrib *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglCreateStreamProducerD3DTextureANGLE(EGLDisplay dpy, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamPostD3DTextureANGLE(EGLDisplay dpy, EGLStreamKHR stream, void *texture, const EGLAttrib *attrib_list);
// #endif
// #endif /* EGL_ANGLE_stream_producer_d3d_texture */

// #ifndef EGL_ANGLE_create_context_webgl_compatibility
// ANGLE_create_context_webgl_compatibility 1
// CONTEXT_WEBGL_COMPATIBILITY_ANGLE 0x33AC
// CONTEXT_HARDENED_ANGLE 0x34F8
// #endif /* EGL_ANGLE_create_context_webgl_compatibility */

// #ifndef EGL_ANGLE_display_texture_share_group
// ANGLE_display_texture_share_group 1
// DISPLAY_TEXTURE_SHARE_GROUP_ANGLE 0x33AF
// #endif /* EGL_ANGLE_display_texture_share_group */

// #ifndef EGL_CHROMIUM_create_context_bind_generates_resource
// CHROMIUM_create_context_bind_generates_resource 1
// CONTEXT_BIND_GENERATES_RESOURCE_CHROMIUM 0x33AD
// #endif /* EGL_CHROMIUM_create_context_bind_generates_resource */

// #ifndef EGL_ANGLE_metal_create_context_ownership_identity
// ANGLE_metal_create_context_ownership_identity 1
// CONTEXT_METAL_OWNERSHIP_IDENTITY_ANGLE 0x34D2
// #endif /* EGL_ANGLE_metal_create_context_ownership_identity */

// #ifndef EGL_ANGLE_create_context_client_arrays
// ANGLE_create_context_client_arrays 1
// CONTEXT_CLIENT_ARRAYS_ENABLED_ANGLE 0x3452
// #endif /* EGL_ANGLE_create_context_client_arrays */

// #ifndef EGL_ANGLE_device_creation
// ANGLE_device_creation 1
// typedef EGLDeviceEXT(EGLAPIENTRYP PFNEGLCREATEDEVICEANGLEPROC) (EGLint device_type, void *native_device, const EGLAttrib *attrib_list);
// typedef EGLBoolean(EGLAPIENTRYP PFNEGLRELEASEDEVICEANGLEPROC) (EGLDeviceEXT device);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLDeviceEXT EGLAPIENTRY eglCreateDeviceANGLE(EGLint device_type, void *native_device, const EGLAttrib *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglReleaseDeviceANGLE(EGLDeviceEXT device);
// #endif
// #endif /* EGL_ANGLE_device_creation */

// #ifndef EGL_ANGLE_program_cache_control
// ANGLE_program_cache_control 1
// PROGRAM_CACHE_SIZE_ANGLE 0x3455
// PROGRAM_CACHE_KEY_LENGTH_ANGLE 0x3456
// PROGRAM_CACHE_RESIZE_ANGLE 0x3457
// PROGRAM_CACHE_TRIM_ANGLE 0x3458
// CONTEXT_PROGRAM_BINARY_CACHE_ENABLED_ANGLE 0x3459
// typedef EGLint (EGLAPIENTRYP PFNEGLPROGRAMCACHEGETATTRIBANGLEPROC) (EGLDisplay dpy, EGLenum attrib);
// typedef void (EGLAPIENTRYP PFNEGLPROGRAMCACHEQUERYANGLEPROC) (EGLDisplay dpy, EGLint index, void *key, EGLint *keysize, void *binary, EGLint *binarysize);
// typedef void (EGLAPIENTRYP PFNEGLPROGRAMCACHEPOPULATEANGLEPROC) (EGLDisplay dpy, const void *key, EGLint keysize, const void *binary, EGLint binarysize);
// typedef EGLint (EGLAPIENTRYP PFNEGLPROGRAMCACHERESIZEANGLEPROC) (EGLDisplay dpy, EGLint limit, EGLint mode);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLint EGLAPIENTRY eglProgramCacheGetAttribANGLE(EGLDisplay dpy, EGLenum attrib);
// EGLAPI void EGLAPIENTRY eglProgramCacheQueryANGLE(EGLDisplay dpy, EGLint index, void *key, EGLint *keysize, void *binary, EGLint *binarysize);
// EGLAPI void EGLAPIENTRY eglProgramCachePopulateANGLE(EGLDisplay dpy, const void *key, EGLint keysize, const void *binary, EGLint binarysize);
// EGLAPI EGLint EGLAPIENTRY eglProgramCacheResizeANGLE(EGLDisplay dpy, EGLint limit, EGLint mode);
// #endif
// #endif /* EGL_ANGLE_program_cache_control */

// #ifndef EGL_ANGLE_iosurface_client_buffer
// ANGLE_iosurface_client_buffer 1
// IOSURFACE_ANGLE 0x3454
// IOSURFACE_PLANE_ANGLE 0x345A
// TEXTURE_RECTANGLE_ANGLE 0x345B
// TEXTURE_TYPE_ANGLE 0x345C
// TEXTURE_INTERNAL_FORMAT_ANGLE 0x345D
// IOSURFACE_USAGE_HINT_ANGLE 0x348A
// IOSURFACE_READ_HINT_ANGLE 0x0001
// IOSURFACE_WRITE_HINT_ANGLE 0x0002
// BIND_TO_TEXTURE_TARGET_ANGLE 0x348D
// #endif /* EGL_ANGLE_iosurface_client_buffer */

// #ifndef ANGLE_metal_texture_client_buffer
// #define ANGLE_metal_texture_client_buffer 1
// METAL_TEXTURE_ANGLE 0x34A7
// METAL_TEXTURE_ARRAY_SLICE_ANGLE 0x34DD
// #endif /* ANGLE_metal_texture_client_buffer */

// #ifndef EGL_ANGLE_create_context_extensions_enabled
// ANGLE_create_context_extensions_enabled 1
// EXTENSIONS_ENABLED_ANGLE 0x345F
// #endif /* EGL_ANGLE_create_context_extensions_enabled */

// #ifndef EGL_CHROMIUM_sync_control
// CHROMIUM_sync_control 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETSYNCVALUESCHROMIUMPROC) (EGLDisplay dpy,
//                                                              EGLSurface surface,
//                                                              EGLuint64KHR *ust,
//                                                              EGLuint64KHR *msc,
//                                                              EGLuint64KHR *sbc);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncValuesCHROMIUM(EGLDisplay dpy,
//                                                              EGLSurface surface,
//                                                              EGLuint64KHR *ust,
//                                                              EGLuint64KHR *msc,
//                                                              EGLuint64KHR *sbc);
// #endif
// #endif /* EGL_CHROMIUM_sync_control */

// #ifndef EGL_ANGLE_sync_control_rate
// ANGLE_sync_control_rate 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETMSCRATEANGLEPROC) (EGLDisplay dpy,
//                                                              EGLSurface surface,
//                                                              EGLint *numerator,
//                                                              EGLint *denominator);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglGetMscRateANGLE(EGLDisplay dpy,
//                                                              EGLSurface surface,
//                                                              EGLint *numerator,
//                                                              EGLint *denominator);
// #endif
// #endif /* EGL_ANGLE_sync_control_rate */

// #ifndef EGL_ANGLE_power_preference
// ANGLE_power_preference 1
// POWER_PREFERENCE_ANGLE 0x3482
// LOW_POWER_ANGLE 0x0001
// HIGH_POWER_ANGLE 0x0002
// typedef void(EGLAPIENTRYP PFNEGLRELEASEHIGHPOWERGPUANGLEPROC) (EGLDisplay dpy, EGLContext ctx);
// typedef void(EGLAPIENTRYP PFNEGLREACQUIREHIGHPOWERGPUANGLEPROC) (EGLDisplay dpy, EGLContext ctx);
// typedef void(EGLAPIENTRYP PFNEGLHANDLEGPUSWITCHANGLEPROC) (EGLDisplay dpy);
// typedef void(EGLAPIENTRYP PFNEGLFORCEGPUSWITCHANGLEPROC) (EGLDisplay dpy, EGLint gpuIDHigh, EGLint gpuIDLow);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglReleaseHighPowerGPUANGLE(EGLDisplay dpy, EGLContext ctx);
// EGLAPI void EGLAPIENTRY eglReacquireHighPowerGPUANGLE(EGLDisplay dpy, EGLContext ctx);
// EGLAPI void EGLAPIENTRY eglHandleGPUSwitchANGLE(EGLDisplay dpy);
// EGLAPI void EGLAPIENTRY eglForceGPUSwitchANGLE(EGLDisplay dpy, EGLint gpuIDHigh, EGLint gpuIDLow);
// #endif
// #endif /* EGL_ANGLE_power_preference */

// #ifndef EGL_ANGLE_wait_until_work_scheduled
// ANGLE_wait_until_work_scheduled 1
// typedef void(EGLAPIENTRYP PFNEGLWAITUNTILWORKSCHEDULEDANGLEPROC) (EGLDisplay dpy);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglWaitUntilWorkScheduledANGLE(EGLDisplay dpy);
// #endif
// #endif /* EGL_ANGLE_wait_until_work_scheduled */

// #ifndef EGL_ANGLE_feature_control
// ANGLE_feature_control 1
// FEATURE_NAME_ANGLE 0x3460
// FEATURE_CATEGORY_ANGLE 0x3461
// FEATURE_STATUS_ANGLE 0x3464
// FEATURE_COUNT_ANGLE 0x3465
// FEATURE_OVERRIDES_ENABLED_ANGLE 0x3466
// FEATURE_OVERRIDES_DISABLED_ANGLE 0x3467
// FEATURE_ALL_DISABLED_ANGLE 0x3469
// typedef const char *(EGLAPIENTRYP PFNEGLQUERYSTRINGIANGLEPROC) (EGLDisplay dpy, EGLint name, EGLint index);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDISPLAYATTRIBANGLEPROC) (EGLDisplay dpy, EGLint attribute, EGLAttrib *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI const char *EGLAPIENTRY eglQueryStringiANGLE(EGLDisplay dpy, EGLint name, EGLint index);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDisplayAttribANGLE(EGLDisplay dpy, EGLint attribute, EGLAttrib *value);
// #endif
// #endif /* EGL_ANGLE_feature_control */

// #ifndef EGL_ANGLE_image_d3d11_texture
// D3D11_TEXTURE_ANGLE 0x3484
// TEXTURE_INTERNAL_FORMAT_ANGLE 0x345D
// #endif /* EGL_ANGLE_image_d3d11_texture */

// #ifndef EGL_ANGLE_create_context_backwards_compatible
// ANGLE_create_context_backwards_compatible 1
// CONTEXT_OPENGL_BACKWARDS_COMPATIBLE_ANGLE 0x3483
// #endif /* EGL_ANGLE_create_context_backwards_compatible */

// #ifndef EGL_ANGLE_device_cgl
// ANGLE_device_cgl 1
// CGL_CONTEXT_ANGLE 0x3485
// CGL_PIXEL_FORMAT_ANGLE 0x3486
// #endif

// #ifndef EGL_ANGLE_prepare_swap_buffers
// ANGLE_prepare_swap_buffers 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLPREPARESWAPBUFFERSANGLEPROC)(EGLDisplay dpy, EGLSurface surface);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglPrepareSwapBuffersANGLE(EGLDisplay dpy, EGLSurface surface);
// #endif
// #endif /* EGL_ANGLE_prepare_swap_buffers */

// #ifndef EGL_ANGLE_device_eagl
// ANGLE_device_eagl 1
// EAGL_CONTEXT_ANGLE 0x348C
// #endif

// #ifndef EGL_ANGLE_device_metal
// ANGLE_device_metal 1
// METAL_DEVICE_ANGLE 0x34A6
// #endif /* EGL_ANGLE_device_metal */

// #ifndef EGL_ANGLE_display_semaphore_share_group
// ANGLE_display_semaphore_share_group 1
// DISPLAY_SEMAPHORE_SHARE_GROUP_ANGLE 0x348D
// #endif /* EGL_ANGLE_display_semaphore_share_group */

// #ifndef EGL_ANGLE_external_context_and_surface
// ANGLE_external_context_and_surface 1
// EXTERNAL_CONTEXT_ANGLE 0x348E
// EXTERNAL_SURFACE_ANGLE 0x348F
// typedef void (EGLAPIENTRYP PFNEGLACQUIREEXTERNALCONTEXTANGLEPROC) (EGLDisplay dpy, EGLSurface readAndDraw);
// typedef void (EGLAPIENTRYP PFNEGLRELEASEEXTERNALCONTEXTANGLEPROC) (EGLDisplay dpy);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglAcquireExternalContextANGLE(EGLDisplay dpy, EGLSurface drawAndRead);
// EGLAPI void EGLAPIENTRY eglReleaseExternalContextANGLE(EGLDisplay dpy);
// #endif
// #endif /* EGL_ANGLE_external_context_and_surface */

// #ifndef EGL_ANGLE_create_surface_swap_interval
// ANGLE_create_surface_swap_interval 1
// SWAP_INTERVAL_ANGLE 0x322F
// #endif /* EGL_ANGLE_create_surface_swap_interval */

// #ifndef EGL_ANGLE_device_vulkan
// ANGLE_device_vulkan 1
// VULKAN_VERSION_ANGLE 0x34A8
// VULKAN_INSTANCE_ANGLE 0x34A9
// VULKAN_INSTANCE_EXTENSIONS_ANGLE 0x34AA
// VULKAN_PHYSICAL_DEVICE_ANGLE 0x34AB
// VULKAN_DEVICE_ANGLE 0x34AC
// VULKAN_DEVICE_EXTENSIONS_ANGLE 0x34AD
// VULKAN_FEATURES_ANGLE 0x34AE
// VULKAN_QUEUE_ANGLE 0x34AF
// VULKAN_QUEUE_FAMILIY_INDEX_ANGLE 0x34D0
// VULKAN_GET_INSTANCE_PROC_ADDR 0x34D1
// typedef void (EGLAPIENTRYP PFNEGLLOCKVULKANQUEUEANGLEPROC)(EGLDisplay dpy);
// typedef void (EGLAPIENTRYP PFNEGLUNLOCKVULKANQUEUEANGLEPROC)(EGLDisplay dpy);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglLockVulkanQueueANGLE(EGLDisplay dpy);
// EGLAPI void EGLAPIENTRY eglUnlockVulkanQueueANGLE(EGLDisplay dpy);
// #endif
// #endif /* EGL_ANGLE_device_vulkan */

// #ifndef EGL_ANGLE_vulkan_image
// ANGLE_vulkan_image
// VULKAN_IMAGE_ANGLE 0x34D3
// VULKAN_IMAGE_CREATE_INFO_HI_ANGLE 0x34D4
// VULKAN_IMAGE_CREATE_INFO_LO_ANGLE 0x34D5
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLEXPORTVKIMAGEANGLEPROC)(EGLDisplay dpy, EGLImage image, void* vk_image, void* vk_image_create_info);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglExportVkImageANGLE(EGLDisplay dpy, EGLImage image, void* vk_image, void* vk_image_create_info);
// #endif
// #endif /* EGL_ANGLE_vulkan_image */

// #ifndef EGL_ANGLE_metal_shared_event_sync
// ANGLE_metal_hared_event_sync 1
// SYNC_METAL_SHARED_EVENT_ANGLE 0x34D8
// SYNC_METAL_SHARED_EVENT_OBJECT_ANGLE 0x34D9
// SYNC_METAL_SHARED_EVENT_SIGNAL_VALUE_LO_ANGLE 0x34DA
// SYNC_METAL_SHARED_EVENT_SIGNAL_VALUE_HI_ANGLE 0x34DB
// SYNC_METAL_SHARED_EVENT_SIGNALED_ANGLE 0x34DC
// typedef void* (EGLAPIENTRYP PFNEGLCOPYMETALSHAREDEVENTANGLEPROC)(EGLDisplay dpy, EGLSync sync);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void *EGLAPIENTRY eglCopyMetalSharedEventANGLE(EGLDisplay dpy, EGLSync sync);
// #endif
// #endif /* EGL_ANGLE_metal_shared_event_sync */

// #ifndef EGL_ANGLE_metal_commands_scheduled_sync
// ANGLE_metal_commands_scheduled_sync 1
// SYNC_METAL_COMMANDS_SCHEDULED_ANGLE 0x34E0
// #endif /* EGL_ANGLE_metal_commands_scheduled_sync */

// #ifndef EGL_ANGLE_global_fence_sync
// ANGLE_global_fence_sync 1
// SYNC_GLOBAL_FENCE_ANGLE 0x34DE
// #endif /* EGL_ANGLE_global_fence_sync */

// #ifndef EGL_ANGLE_no_error
// ANGLE_no_error 1
// typedef void (EGLAPIENTRYP PFNEGLSETVALIDATIONENABLEDANGLEPROC)(EGLBoolean validationState);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglSetValidationEnabledANGLE(EGLBoolean validationState);
// #endif
// #endif /* EGL_ANGLE_no_error */

// #ifndef EGL_ANGLE_memory_usage_report
// ANGLE_memory_usage_report 1
// CONTEXT_MEMORY_USAGE_ANGLE 0x3462
// #endif /* EGL_ANGLE_memory_usage_report */

// #ifndef EGL_ANGLE_device_webgpu
// ANGLE_device_webgpu 1
// WEBGPU_DEVICE_ANGLE 0x34F3
// WEBGPU_ADAPTER_ANGLE 0x34F4
// #endif /* EGL_ANGLE_device_webgpu */

// #ifndef ANGLE_webgpu_texture_client_buffer
// #define ANGLE_webgpu_texture_client_buffer 1
// WEBGPU_TEXTURE_ANGLE 0x34F5
// TEXTURE_TYPE_ANGLE 0x345C
// TEXTURE_INTERNAL_FORMAT_ANGLE 0x345D
// #endif /* ANGLE_webgpu_texture_client_buffer */

// #ifndef EGL_ANGLE_create_context_passthrough_shaders
// ANGLE_create_context_passthrough_shaders 1
// CONTEXT_PASSTHROUGH_SHADERS_ANGLE 0x3463
// #endif /* EGL_ANGLE_create_context_passthrough_shaders */

// // clang-format on

// #endif  // INCLUDE_EGL_EGLEXT_ANGLE_

