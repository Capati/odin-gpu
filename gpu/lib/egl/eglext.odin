package egl

CL_EVENT_HANDLE_KHR        :: 0x309C
SYNC_CL_EVENT_KHR          :: 0x30FE
SYNC_CL_EVENT_COMPLETE_KHR :: 0x30FF

SyncKHR :: distinct rawptr
AttribKHR :: distinct int

PFNEGLCREATESYNC64KHRPROC :: #type proc "c" (
    dpy: Display,
    type: u32,
    attrib_list: ^AttribKHR) -> SyncKHR

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    CreateSync64KHR :: proc (dpy: Display, type: u32, attrib_list: ^AttribKHR) -> SyncKHR ---
}

CONFORMANT_KHR               :: 0x3042
VG_COLORSPACE_LINEAR_BIT_KHR :: 0x0020
VG_ALPHA_FORMAT_PRE_BIT_KHR  :: 0x0040

CONTEXT_RELEASE_BEHAVIOR_NONE_KHR  :: 0
CONTEXT_RELEASE_BEHAVIOR_KHR       :: 0x2097
CONTEXT_RELEASE_BEHAVIOR_FLUSH_KHR :: 0x2098

CONTEXT_MAJOR_VERSION_KHR                      :: 0x3098
CONTEXT_MINOR_VERSION_KHR                      :: 0x30FB
CONTEXT_FLAGS_KHR                              :: 0x30FC
CONTEXT_OPENGL_PROFILE_MASK_KHR                :: 0x30FD
CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY_KHR :: 0x31BD
NO_RESET_NOTIFICATION_KHR                      :: 0x31BE
LOSE_CONTEXT_ON_RESET_KHR                      :: 0x31BF
CONTEXT_OPENGL_DEBUG_BIT_KHR                   :: 0x00000001
CONTEXT_OPENGL_FORWARD_COMPATIBLE_BIT_KHR      :: 0x00000002
CONTEXT_OPENGL_ROBUST_ACCESS_BIT_KHR           :: 0x00000004
CONTEXT_OPENGL_CORE_PROFILE_BIT_KHR            :: 0x00000001
CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT_KHR   :: 0x00000002
OPENGL_ES3_BIT_KHR                             :: 0x00000040

CONTEXT_OPENGL_NO_ERROR_KHR :: 0x31B3

LabelKHR :: distinct rawptr
ObjectKHR :: distinct rawptr

DebugProcKHR :: #type proc "c" (
    error: u32,
    command: cstring,
    messageType: i32,
    threadLabel: LabelKHR,
    objectLabel: LabelKHR,
    message: cstring)

OBJECT_THREAD_KHR      :: 0x33B0
OBJECT_DISPLAY_KHR     :: 0x33B1
OBJECT_CONTEXT_KHR     :: 0x33B2
OBJECT_SURFACE_KHR     :: 0x33B3
OBJECT_IMAGE_KHR       :: 0x33B4
OBJECT_SYNC_KHR        :: 0x33B5
OBJECT_STREAM_KHR      :: 0x33B6
DEBUG_MSG_CRITICAL_KHR :: 0x33B9
DEBUG_MSG_ERROR_KHR    :: 0x33BA
DEBUG_MSG_WARN_KHR     :: 0x33BB
DEBUG_MSG_INFO_KHR     :: 0x33BC
DEBUG_CALLBACK_KHR     :: 0x33B8

DebugMessageControlKHRType :: #type proc "c" (
    callback: DebugProcKHR,
    attrib_list: ^Attrib) -> i32

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    DebugMessageControlKHR :: proc (
        callback: DebugProcKHR,
        attrib_list: ^Attrib) -> i32 ---

    // EGLAPI EGLBoolean EGLAPIENTRY eglQueryDebugKHR (i32 attribute, EGLAttrib *value);
    // EGLAPI i32 EGLAPIENTRY eglLabelObjectKHR (Display display, EGLenum objectType, ObjectKHR object, LabelKHR label);
}

// TRACK_REFERENCES_KHR          0x3352
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDISPLAYATTRIBKHRPROC) (dpy: Display, i32 name, EGLAttrib *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDisplayAttribKHR (dpy: Display, i32 name, EGLAttrib *value);

// typedef khronos_utime_nanoseconds_t EGLTimeKHR;
// #ifdef KHRONOS_SUPPORT_INT64
// SYNC_PRIOR_COMMANDS_COMPLETE_KHR 0x30F0
// SYNC_CONDITION_KHR            0x30F8
// SYNC_FENCE_KHR                0x30F9
// typedef SyncKHR (EGLAPIENTRYP PFNEGLCREATESYNCKHRPROC) (dpy: Display, EGLenum type, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLDESTROYSYNCKHRPROC) (dpy: Display, SyncKHR sync);
// typedef i32 (EGLAPIENTRYP PFNEGLCLIENTWAITSYNCKHRPROC) (dpy: Display, SyncKHR sync, i32 flags, EGLTimeKHR timeout);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETSYNCATTRIBKHRPROC) (dpy: Display, SyncKHR sync, i32 attribute, i32 *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI SyncKHR EGLAPIENTRY eglCreateSyncKHR (dpy: Display, EGLenum type, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglDestroySyncKHR (dpy: Display, SyncKHR sync);
// EGLAPI i32 EGLAPIENTRY eglClientWaitSyncKHR (dpy: Display, SyncKHR sync, i32 flags, EGLTimeKHR timeout);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncAttribKHR (dpy: Display, SyncKHR sync, i32 attribute, i32 *value);

GL_COLORSPACE_KHR        :: 0x309D
GL_COLORSPACE_SRGB_KHR   :: 0x3089
GL_COLORSPACE_LINEAR_KHR :: 0x308A

GL_RENDERBUFFER_KHR      :: 0x30B9

GL_TEXTURE_2D_KHR        :: 0x30B1
GL_TEXTURE_LEVEL_KHR     :: 0x30BC

GL_TEXTURE_3D_KHR      :: 0x30B2
GL_TEXTURE_ZOFFSET_KHR :: 0x30BD

GL_TEXTURE_CUBE_MAP_POSITIVE_X_KHR :: 0x30B3
GL_TEXTURE_CUBE_MAP_NEGATIVE_X_KHR :: 0x30B4
GL_TEXTURE_CUBE_MAP_POSITIVE_Y_KHR :: 0x30B5
GL_TEXTURE_CUBE_MAP_NEGATIVE_Y_KHR :: 0x30B6
GL_TEXTURE_CUBE_MAP_POSITIVE_Z_KHR :: 0x30B7
GL_TEXTURE_CUBE_MAP_NEGATIVE_Z_KHR :: 0x30B8

// typedef void *EGLImageKHR;
// NATIVE_PIXMAP_KHR             0x30B0
// NO_IMAGE_KHR                  EGL_CAST(EGLImageKHR,0)
// typedef EGLImageKHR (EGLAPIENTRYP PFNEGLCREATEIMAGEKHRPROC) (dpy: Display, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLDESTROYIMAGEKHRPROC) (dpy: Display, EGLImageKHR image);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLImageKHR EGLAPIENTRY eglCreateImageKHR (dpy: Display, EGLContext ctx, EGLenum target, EGLClientBuffer buffer, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglDestroyImageKHR (dpy: Display, EGLImageKHR image);

// IMAGE_PRESERVED_KHR           0x30D2

READ_SURFACE_BIT_KHR              :: 0x0001
WRITE_SURFACE_BIT_KHR             :: 0x0002
LOCK_SURFACE_BIT_KHR              :: 0x0080
OPTIMAL_FORMAT_BIT_KHR            :: 0x0100
MATCH_FORMAT_KHR                  :: 0x3043
FORMAT_RGB_565_EXACT_KHR          :: 0x30C0
FORMAT_RGB_565_KHR                :: 0x30C1
FORMAT_RGBA_8888_EXACT_KHR        :: 0x30C2
FORMAT_RGBA_8888_KHR              :: 0x30C3
MAP_PRESERVE_PIXELS_KHR           :: 0x30C4
LOCK_USAGE_HINT_KHR               :: 0x30C5
BITMAP_POINTER_KHR                :: 0x30C6
BITMAP_PITCH_KHR                  :: 0x30C7
BITMAP_ORIGIN_KHR                 :: 0x30C8
BITMAP_PIXEL_RED_OFFSET_KHR       :: 0x30C9
BITMAP_PIXEL_GREEN_OFFSET_KHR     :: 0x30CA
BITMAP_PIXEL_BLUE_OFFSET_KHR      :: 0x30CB
BITMAP_PIXEL_ALPHA_OFFSET_KHR     :: 0x30CC
BITMAP_PIXEL_LUMINANCE_OFFSET_KHR :: 0x30CD
LOWER_LEFT_KHR                    :: 0x30CE
UPPER_LEFT_KHR                    :: 0x30CF
//
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLLOCKSURFACEKHRPROC) (dpy: Display, EGLSurface surface, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLUNLOCKSURFACEKHRPROC) (dpy: Display, EGLSurface surface);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglLockSurfaceKHR (dpy: Display, EGLSurface surface, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglUnlockSurfaceKHR (dpy: Display, EGLSurface surface);

// #ifndef EGL_KHR_lock_surface2
// KHR_lock_surface2 1
// BITMAP_PIXEL_SIZE_KHR         0x3110
// #endif /* EGL_KHR_lock_surface2 */

// #ifndef EGL_KHR_lock_surface3
// KHR_lock_surface3 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSURFACE64KHRPROC) (dpy: Display, EGLSurface surface, i32 attribute, AttribKHR *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQuerySurface64KHR (dpy: Display, EGLSurface surface, i32 attribute, AttribKHR *value);
// #endif
// #endif /* EGL_KHR_lock_surface3 */

// #ifndef EGL_KHR_mutable_render_buffer
// KHR_mutable_render_buffer 1
// MUTABLE_RENDER_BUFFER_BIT_KHR 0x1000
// #endif /* EGL_KHR_mutable_render_buffer */

// #ifndef EGL_KHR_no_config_context
// KHR_no_config_context 1
// NO_CONFIG_KHR                 EGL_CAST(EGLConfig,0)
// #endif /* EGL_KHR_no_config_context */

// #ifndef EGL_KHR_partial_update
// KHR_partial_update 1
// BUFFER_AGE_KHR                0x313D
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSETDAMAGEREGIONKHRPROC) (dpy: Display, EGLSurface surface, i32 *rects, i32 n_rects);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSetDamageRegionKHR (dpy: Display, EGLSurface surface, i32 *rects, i32 n_rects);
// #endif
// #endif /* EGL_KHR_partial_update */

// #ifndef EGL_KHR_platform_android
// KHR_platform_android 1
// PLATFORM_ANDROID_KHR          0x3141
// #endif /* EGL_KHR_platform_android */

// #ifndef EGL_KHR_platform_gbm
// KHR_platform_gbm 1
// PLATFORM_GBM_KHR              0x31D7
// #endif /* EGL_KHR_platform_gbm */

PLATFORM_WAYLAND_KHR :: 0x31D8

PLATFORM_X11_KHR        :: 0x31D5
PLATFORM_X11_SCREEN_KHR :: 0x31D6

// #ifndef EGL_KHR_reusable_sync
// KHR_reusable_sync 1
// #ifdef KHRONOS_SUPPORT_INT64
// SYNC_STATUS_KHR               0x30F1
// SIGNALED_KHR                  0x30F2
// UNSIGNALED_KHR                0x30F3
// TIMEOUT_EXPIRED_KHR           0x30F5
// CONDITION_SATISFIED_KHR       0x30F6
// SYNC_TYPE_KHR                 0x30F7
// SYNC_REUSABLE_KHR             0x30FA
// SYNC_FLUSH_COMMANDS_BIT_KHR   0x0001
// FOREVER_KHR                   0xFFFFFFFFFFFFFFFFull
// NO_SYNC_KHR                   EGL_CAST(SyncKHR,0)
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSIGNALSYNCKHRPROC) (dpy: Display, SyncKHR sync, EGLenum mode);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSignalSyncKHR (dpy: Display, SyncKHR sync, EGLenum mode);
// #endif
// #endif /* KHRONOS_SUPPORT_INT64 */
// #endif /* EGL_KHR_reusable_sync */

// #ifndef EGL_KHR_stream
// KHR_stream 1
// typedef void *EGLStreamKHR;
// typedef khronos_uint64_t EGLuint64KHR;
// #ifdef KHRONOS_SUPPORT_INT64
// NO_STREAM_KHR                 EGL_CAST(EGLStreamKHR,0)
// CONSUMER_LATENCY_USEC_KHR     0x3210
// PRODUCER_FRAME_KHR            0x3212
// CONSUMER_FRAME_KHR            0x3213
// STREAM_STATE_KHR              0x3214
// STREAM_STATE_CREATED_KHR      0x3215
// STREAM_STATE_CONNECTING_KHR   0x3216
// STREAM_STATE_EMPTY_KHR        0x3217
// STREAM_STATE_NEW_FRAME_AVAILABLE_KHR 0x3218
// STREAM_STATE_OLD_FRAME_AVAILABLE_KHR 0x3219
// STREAM_STATE_DISCONNECTED_KHR 0x321A
// BAD_STREAM_KHR                0x321B
// BAD_STATE_KHR                 0x321C
// typedef EGLStreamKHR (EGLAPIENTRYP PFNEGLCREATESTREAMKHRPROC) (dpy: Display, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLDESTROYSTREAMKHRPROC) (dpy: Display, EGLStreamKHR stream);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMATTRIBKHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, i32 value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSTREAMKHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, i32 *value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSTREAMU64KHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLuint64KHR *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLStreamKHR EGLAPIENTRY eglCreateStreamKHR (dpy: Display, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglDestroyStreamKHR (dpy: Display, EGLStreamKHR stream);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamAttribKHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, i32 value);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryStreamKHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, i32 *value);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryStreamu64KHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLuint64KHR *value);
// #endif
// #endif /* KHRONOS_SUPPORT_INT64 */
// #endif /* EGL_KHR_stream */

// #ifndef EGL_KHR_stream_attrib
// KHR_stream_attrib 1
// #ifdef KHRONOS_SUPPORT_INT64
// typedef EGLStreamKHR (EGLAPIENTRYP PFNEGLCREATESTREAMATTRIBKHRPROC) (dpy: Display, const EGLAttrib *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSETSTREAMATTRIBKHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLAttrib value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSTREAMATTRIBKHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLAttrib *value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERACQUIREATTRIBKHRPROC) (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERRELEASEATTRIBKHRPROC) (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLStreamKHR EGLAPIENTRY eglCreateStreamAttribKHR (dpy: Display, const EGLAttrib *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglSetStreamAttribKHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLAttrib value);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryStreamAttribKHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLAttrib *value);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerAcquireAttribKHR (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerReleaseAttribKHR (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// #endif
// #endif /* KHRONOS_SUPPORT_INT64 */
// #endif /* EGL_KHR_stream_attrib */

// #ifndef EGL_KHR_stream_consumer_gltexture
// KHR_stream_consumer_gltexture 1
// #ifdef EGL_KHR_stream
// CONSUMER_ACQUIRE_TIMEOUT_USEC_KHR 0x321E
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERGLTEXTUREEXTERNALKHRPROC) (dpy: Display, EGLStreamKHR stream);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERACQUIREKHRPROC) (dpy: Display, EGLStreamKHR stream);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERRELEASEKHRPROC) (dpy: Display, EGLStreamKHR stream);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerGLTextureExternalKHR (dpy: Display, EGLStreamKHR stream);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerAcquireKHR (dpy: Display, EGLStreamKHR stream);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerReleaseKHR (dpy: Display, EGLStreamKHR stream);
// #endif
// #endif /* EGL_KHR_stream */
// #endif /* EGL_KHR_stream_consumer_gltexture */

// #ifndef EGL_KHR_stream_cross_process_fd
// KHR_stream_cross_process_fd 1
// typedef int EGLNativeFileDescriptorKHR;
// #ifdef EGL_KHR_stream
// NO_FILE_DESCRIPTOR_KHR        EGL_CAST(EGLNativeFileDescriptorKHR,-1)
// typedef EGLNativeFileDescriptorKHR (EGLAPIENTRYP PFNEGLGETSTREAMFILEDESCRIPTORKHRPROC) (dpy: Display, EGLStreamKHR stream);
// typedef EGLStreamKHR (EGLAPIENTRYP PFNEGLCREATESTREAMFROMFILEDESCRIPTORKHRPROC) (dpy: Display, EGLNativeFileDescriptorKHR file_descriptor);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLNativeFileDescriptorKHR EGLAPIENTRY eglGetStreamFileDescriptorKHR (dpy: Display, EGLStreamKHR stream);
// EGLAPI EGLStreamKHR EGLAPIENTRY eglCreateStreamFromFileDescriptorKHR (dpy: Display, EGLNativeFileDescriptorKHR file_descriptor);
// #endif
// #endif /* EGL_KHR_stream */
// #endif /* EGL_KHR_stream_cross_process_fd */

// #ifndef EGL_KHR_stream_fifo
// KHR_stream_fifo 1
// #ifdef EGL_KHR_stream
// STREAM_FIFO_LENGTH_KHR        0x31FC
// STREAM_TIME_NOW_KHR           0x31FD
// STREAM_TIME_CONSUMER_KHR      0x31FE
// STREAM_TIME_PRODUCER_KHR      0x31FF
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSTREAMTIMEKHRPROC) (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLTimeKHR *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryStreamTimeKHR (dpy: Display, EGLStreamKHR stream, EGLenum attribute, EGLTimeKHR *value);
// #endif
// #endif /* EGL_KHR_stream */
// #endif /* EGL_KHR_stream_fifo */

// #ifndef EGL_KHR_stream_producer_aldatalocator
// KHR_stream_producer_aldatalocator 1
// #ifdef EGL_KHR_stream
// #endif /* EGL_KHR_stream */
// #endif /* EGL_KHR_stream_producer_aldatalocator */

// #ifndef EGL_KHR_stream_producer_eglsurface
// KHR_stream_producer_eglsurface 1
// #ifdef EGL_KHR_stream
// STREAM_BIT_KHR                0x0800
// typedef EGLSurface (EGLAPIENTRYP PFNEGLCREATESTREAMPRODUCERSURFACEKHRPROC) (dpy: Display, EGLConfig config, EGLStreamKHR stream, const i32 *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLSurface EGLAPIENTRY eglCreateStreamProducerSurfaceKHR (dpy: Display, EGLConfig config, EGLStreamKHR stream, const i32 *attrib_list);
// #endif
// #endif /* EGL_KHR_stream */
// #endif /* EGL_KHR_stream_producer_eglsurface */

// #ifndef EGL_KHR_surfaceless_context
// KHR_surfaceless_context 1
// #endif /* EGL_KHR_surfaceless_context */

// #ifndef EGL_KHR_swap_buffers_with_damage
// KHR_swap_buffers_with_damage 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSWAPBUFFERSWITHDAMAGEKHRPROC) (dpy: Display, EGLSurface surface, const i32 *rects, i32 n_rects);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffersWithDamageKHR (dpy: Display, EGLSurface surface, const i32 *rects, i32 n_rects);
// #endif
// #endif /* EGL_KHR_swap_buffers_with_damage */

// #ifndef EGL_KHR_vg_parent_image
// KHR_vg_parent_image 1
// VG_PARENT_IMAGE_KHR           0x30BA
// #endif /* EGL_KHR_vg_parent_image */

// #ifndef EGL_KHR_wait_sync
// KHR_wait_sync 1
// typedef i32 (EGLAPIENTRYP PFNEGLWAITSYNCKHRPROC) (dpy: Display, SyncKHR sync, i32 flags);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI i32 EGLAPIENTRY eglWaitSyncKHR (dpy: Display, SyncKHR sync, i32 flags);
// #endif
// #endif /* EGL_KHR_wait_sync */

// #ifndef EGL_ANDROID_GLES_layers
// ANDROID_GLES_layers 1
// #endif /* EGL_ANDROID_GLES_layers */

// #ifndef EGL_ANDROID_blob_cache
// ANDROID_blob_cache 1
// typedef khronos_ssize_t EGLsizeiANDROID;
// typedef void (*EGLSetBlobFuncANDROID) (const void *key, EGLsizeiANDROID keySize, const void *value, EGLsizeiANDROID valueSize);
// typedef EGLsizeiANDROID (*EGLGetBlobFuncANDROID) (const void *key, EGLsizeiANDROID keySize, void *value, EGLsizeiANDROID valueSize);
// typedef void (EGLAPIENTRYP PFNEGLSETBLOBCACHEFUNCSANDROIDPROC) (dpy: Display, EGLSetBlobFuncANDROID set, EGLGetBlobFuncANDROID get);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI void EGLAPIENTRY eglSetBlobCacheFuncsANDROID (dpy: Display, EGLSetBlobFuncANDROID set, EGLGetBlobFuncANDROID get);
// #endif
// #endif /* EGL_ANDROID_blob_cache */

// #ifndef EGL_ANDROID_create_native_client_buffer
// ANDROID_create_native_client_buffer 1
// NATIVE_BUFFER_USAGE_ANDROID   0x3143
// NATIVE_BUFFER_USAGE_PROTECTED_BIT_ANDROID 0x00000001
// NATIVE_BUFFER_USAGE_RENDERBUFFER_BIT_ANDROID 0x00000002
// NATIVE_BUFFER_USAGE_TEXTURE_BIT_ANDROID 0x00000004
// typedef EGLClientBuffer (EGLAPIENTRYP PFNEGLCREATENATIVECLIENTBUFFERANDROIDPROC) (const i32 *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLClientBuffer EGLAPIENTRY eglCreateNativeClientBufferANDROID (const i32 *attrib_list);
// #endif
// #endif /* EGL_ANDROID_create_native_client_buffer */

// #ifndef EGL_ANDROID_framebuffer_target
// ANDROID_framebuffer_target 1
// FRAMEBUFFER_TARGET_ANDROID    0x3147
// #endif /* EGL_ANDROID_framebuffer_target */

// #ifndef EGL_ANDROID_front_buffer_auto_refresh
// ANDROID_front_buffer_auto_refresh 1
// FRONT_BUFFER_AUTO_REFRESH_ANDROID 0x314C
// #endif /* EGL_ANDROID_front_buffer_auto_refresh */

// #ifndef EGL_ANDROID_get_frame_timestamps
// ANDROID_get_frame_timestamps 1
// typedef khronos_stime_nanoseconds_t EGLnsecsANDROID;
// TIMESTAMP_PENDING_ANDROID     EGL_CAST(EGLnsecsANDROID,-2)
// TIMESTAMP_INVALID_ANDROID     EGL_CAST(EGLnsecsANDROID,-1)
// TIMESTAMPS_ANDROID            0x3430
// COMPOSITE_DEADLINE_ANDROID    0x3431
// COMPOSITE_INTERVAL_ANDROID    0x3432
// COMPOSITE_TO_PRESENT_LATENCY_ANDROID 0x3433
// REQUESTED_PRESENT_TIME_ANDROID 0x3434
// RENDERING_COMPLETE_TIME_ANDROID 0x3435
// COMPOSITION_LATCH_TIME_ANDROID 0x3436
// FIRST_COMPOSITION_START_TIME_ANDROID 0x3437
// LAST_COMPOSITION_START_TIME_ANDROID 0x3438
// FIRST_COMPOSITION_GPU_FINISHED_TIME_ANDROID 0x3439
// DISPLAY_PRESENT_TIME_ANDROID  0x343A
// DEQUEUE_READY_TIME_ANDROID    0x343B
// READS_DONE_TIME_ANDROID       0x343C
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETCOMPOSITORTIMINGSUPPORTEDANDROIDPROC) (dpy: Display, EGLSurface surface, i32 name);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETCOMPOSITORTIMINGANDROIDPROC) (dpy: Display, EGLSurface surface, i32 numTimestamps,  const i32 *names, EGLnsecsANDROID *values);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETNEXTFRAMEIDANDROIDPROC) (dpy: Display, EGLSurface surface, EGLuint64KHR *frameId);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETFRAMETIMESTAMPSUPPORTEDANDROIDPROC) (dpy: Display, EGLSurface surface, i32 timestamp);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETFRAMETIMESTAMPSANDROIDPROC) (dpy: Display, EGLSurface surface, EGLuint64KHR frameId, i32 numTimestamps,  const i32 *timestamps, EGLnsecsANDROID *values);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglGetCompositorTimingSupportedANDROID (dpy: Display, EGLSurface surface, i32 name);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetCompositorTimingANDROID (dpy: Display, EGLSurface surface, i32 numTimestamps,  const i32 *names, EGLnsecsANDROID *values);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetNextFrameIdANDROID (dpy: Display, EGLSurface surface, EGLuint64KHR *frameId);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetFrameTimestampSupportedANDROID (dpy: Display, EGLSurface surface, i32 timestamp);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetFrameTimestampsANDROID (dpy: Display, EGLSurface surface, EGLuint64KHR frameId, i32 numTimestamps,  const i32 *timestamps, EGLnsecsANDROID *values);
// #endif
// #endif /* EGL_ANDROID_get_frame_timestamps */

// #ifndef EGL_ANDROID_get_native_client_buffer
// ANDROID_get_native_client_buffer 1
// struct AHardwareBuffer;
// typedef EGLClientBuffer (EGLAPIENTRYP PFNEGLGETNATIVECLIENTBUFFERANDROIDPROC) (const struct AHardwareBuffer *buffer);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLClientBuffer EGLAPIENTRY eglGetNativeClientBufferANDROID (const struct AHardwareBuffer *buffer);
// #endif
// #endif /* EGL_ANDROID_get_native_client_buffer */

// #ifndef EGL_ANDROID_image_native_buffer
// ANDROID_image_native_buffer 1
// NATIVE_BUFFER_ANDROID         0x3140
// #endif /* EGL_ANDROID_image_native_buffer */

// #ifndef EGL_ANDROID_native_fence_sync
// ANDROID_native_fence_sync 1
// SYNC_NATIVE_FENCE_ANDROID     0x3144
// SYNC_NATIVE_FENCE_FD_ANDROID  0x3145
// SYNC_NATIVE_FENCE_SIGNALED_ANDROID 0x3146
// NO_NATIVE_FENCE_FD_ANDROID    -1
// typedef i32 (EGLAPIENTRYP PFNEGLDUPNATIVEFENCEFDANDROIDPROC) (dpy: Display, SyncKHR sync);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI i32 EGLAPIENTRY eglDupNativeFenceFDANDROID (dpy: Display, SyncKHR sync);
// #endif
// #endif /* EGL_ANDROID_native_fence_sync */

// #ifndef EGL_ANDROID_presentation_time
// ANDROID_presentation_time 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLPRESENTATIONTIMEANDROIDPROC) (dpy: Display, EGLSurface surface, EGLnsecsANDROID time);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglPresentationTimeANDROID (dpy: Display, EGLSurface surface, EGLnsecsANDROID time);
// #endif
// #endif /* EGL_ANDROID_presentation_time */

// #ifndef EGL_ANDROID_recordable
// ANDROID_recordable 1
// RECORDABLE_ANDROID            0x3142
// #endif /* EGL_ANDROID_recordable */

// #ifndef EGL_ANGLE_d3d_share_handle_client_buffer
// ANGLE_d3d_share_handle_client_buffer 1
// D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE 0x3200
// #endif /* EGL_ANGLE_d3d_share_handle_client_buffer */

// #ifndef EGL_ANGLE_device_d3d
// ANGLE_device_d3d 1
// D3D9_DEVICE_ANGLE             0x33A0
// D3D11_DEVICE_ANGLE            0x33A1
// #endif /* EGL_ANGLE_device_d3d */

// #ifndef EGL_ANGLE_query_surface_pointer
// ANGLE_query_surface_pointer 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSURFACEPOINTERANGLEPROC) (dpy: Display, EGLSurface surface, i32 attribute, void **value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQuerySurfacePointerANGLE (dpy: Display, EGLSurface surface, i32 attribute, void **value);
// #endif
// #endif /* EGL_ANGLE_query_surface_pointer */

// #ifndef EGL_ANGLE_surface_d3d_texture_2d_share_handle
// ANGLE_surface_d3d_texture_2d_share_handle 1
// #endif /* EGL_ANGLE_surface_d3d_texture_2d_share_handle */

// #ifndef EGL_ANGLE_sync_control_rate
// ANGLE_sync_control_rate 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETMSCRATEANGLEPROC) (dpy: Display, EGLSurface surface, i32 *numerator, i32 *denominator);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglGetMscRateANGLE (dpy: Display, EGLSurface surface, i32 *numerator, i32 *denominator);
// #endif
// #endif /* EGL_ANGLE_sync_control_rate */

// #ifndef EGL_ANGLE_window_fixed_size
// ANGLE_window_fixed_size 1
// FIXED_SIZE_ANGLE              0x3201
// #endif /* EGL_ANGLE_window_fixed_size */

// #ifndef EGL_ARM_image_format
// ARM_image_format 1
// COLOR_COMPONENT_TYPE_UNSIGNED_INTEGER_ARM 0x3287
// COLOR_COMPONENT_TYPE_INTEGER_ARM 0x3288
// #endif /* EGL_ARM_image_format */

// #ifndef EGL_ARM_implicit_external_sync
// ARM_implicit_external_sync 1
// SYNC_PRIOR_COMMANDS_IMPLICIT_EXTERNAL_ARM 0x328A
// #endif /* EGL_ARM_implicit_external_sync */

// #ifndef EGL_ARM_pixmap_multisample_discard
// ARM_pixmap_multisample_discard 1
// DISCARD_SAMPLES_ARM           0x3286
// #endif /* EGL_ARM_pixmap_multisample_discard */

// #ifndef EGL_EXT_bind_to_front
// EXT_bind_to_front 1
// FRONT_BUFFER_EXT              0x3464
// #endif /* EGL_EXT_bind_to_front */

// #ifndef EGL_EXT_buffer_age
// EXT_buffer_age 1
// BUFFER_AGE_EXT                0x313D
// #endif /* EGL_EXT_buffer_age */

// #ifndef EGL_EXT_client_extensions
// EXT_client_extensions 1
// #endif /* EGL_EXT_client_extensions */

// #ifndef EGL_EXT_client_sync
// EXT_client_sync 1
// SYNC_CLIENT_EXT               0x3364
// SYNC_CLIENT_SIGNAL_EXT        0x3365
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCLIENTSIGNALSYNCEXTPROC) (dpy: Display, EGLSync sync, const EGLAttrib *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglClientSignalSyncEXT (dpy: Display, EGLSync sync, const EGLAttrib *attrib_list);
// #endif
// #endif /* EGL_EXT_client_sync */

// #ifndef EGL_EXT_compositor
// EXT_compositor 1
// PRIMARY_COMPOSITOR_CONTEXT_EXT 0x3460
// EXTERNAL_REF_ID_EXT           0x3461
// COMPOSITOR_DROP_NEWEST_FRAME_EXT 0x3462
// COMPOSITOR_KEEP_NEWEST_FRAME_EXT 0x3463
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSETCONTEXTLISTEXTPROC) (const i32 *external_ref_ids, i32 num_entries);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSETCONTEXTATTRIBUTESEXTPROC) (i32 external_ref_id, const i32 *context_attributes, i32 num_entries);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSETWINDOWLISTEXTPROC) (i32 external_ref_id, const i32 *external_win_ids, i32 num_entries);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSETWINDOWATTRIBUTESEXTPROC) (i32 external_win_id, const i32 *window_attributes, i32 num_entries);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORBINDTEXWINDOWEXTPROC) (i32 external_win_id);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSETSIZEEXTPROC) (i32 external_win_id, i32 width, i32 height);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLCOMPOSITORSWAPPOLICYEXTPROC) (i32 external_win_id, i32 policy);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSetContextListEXT (const i32 *external_ref_ids, i32 num_entries);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSetContextAttributesEXT (i32 external_ref_id, const i32 *context_attributes, i32 num_entries);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSetWindowListEXT (i32 external_ref_id, const i32 *external_win_ids, i32 num_entries);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSetWindowAttributesEXT (i32 external_win_id, const i32 *window_attributes, i32 num_entries);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorBindTexWindowEXT (i32 external_win_id);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSetSizeEXT (i32 external_win_id, i32 width, i32 height);
// EGLAPI EGLBoolean EGLAPIENTRY eglCompositorSwapPolicyEXT (i32 external_win_id, i32 policy);
// #endif
// #endif /* EGL_EXT_compositor */

// #ifndef EGL_EXT_config_select_group
// EXT_config_select_group 1
// CONFIG_SELECT_GROUP_EXT       0x34C0
// #endif /* EGL_EXT_config_select_group */

CONTEXT_OPENGL_ROBUST_ACCESS_EXT               :: 0x30BF
CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY_EXT :: 0x3138
NO_RESET_NOTIFICATION_EXT                      :: 0x31BE
LOSE_CONTEXT_ON_RESET_EXT                      :: 0x31BF

// #ifndef EGL_EXT_device_base
// EXT_device_base 1
// typedef void *EGLDeviceEXT;
// NO_DEVICE_EXT                 EGL_CAST(EGLDeviceEXT,0)
// BAD_DEVICE_EXT                0x322B
// DEVICE_EXT                    0x322C
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDEVICEATTRIBEXTPROC) (EGLDeviceEXT device, i32 attribute, EGLAttrib *value);
// typedef const char *(EGLAPIENTRYP PFNEGLQUERYDEVICESTRINGEXTPROC) (EGLDeviceEXT device, i32 name);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDEVICESEXTPROC) (i32 max_devices, EGLDeviceEXT *devices, i32 *num_devices);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDISPLAYATTRIBEXTPROC) (dpy: Display, i32 attribute, EGLAttrib *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDeviceAttribEXT (EGLDeviceEXT device, i32 attribute, EGLAttrib *value);
// EGLAPI const char *EGLAPIENTRY eglQueryDeviceStringEXT (EGLDeviceEXT device, i32 name);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDevicesEXT (i32 max_devices, EGLDeviceEXT *devices, i32 *num_devices);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDisplayAttribEXT (dpy: Display, i32 attribute, EGLAttrib *value);
// #endif
// #endif /* EGL_EXT_device_base */

// #ifndef EGL_EXT_device_drm
// EXT_device_drm 1
// DRM_DEVICE_FILE_EXT           0x3233
// DRM_MASTER_FD_EXT             0x333C
// #endif /* EGL_EXT_device_drm */

// #ifndef EGL_EXT_device_drm_render_node
// EXT_device_drm_render_node 1
// DRM_RENDER_NODE_FILE_EXT      0x3377
// #endif /* EGL_EXT_device_drm_render_node */

// #ifndef EGL_EXT_device_enumeration
// EXT_device_enumeration 1
// #endif /* EGL_EXT_device_enumeration */

// #ifndef EGL_EXT_device_openwf
// EXT_device_openwf 1
// OPENWF_DEVICE_ID_EXT          0x3237
// OPENWF_DEVICE_EXT             0x333D
// #endif /* EGL_EXT_device_openwf */

// #ifndef EGL_EXT_device_persistent_id
// EXT_device_persistent_id 1
// DEVICE_UUID_EXT               0x335C
// DRIVER_UUID_EXT               0x335D
// DRIVER_NAME_EXT               0x335E
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDEVICEBINARYEXTPROC) (EGLDeviceEXT device, i32 name, i32 max_size, void *value, i32 *size);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDeviceBinaryEXT (EGLDeviceEXT device, i32 name, i32 max_size, void *value, i32 *size);
// #endif
// #endif /* EGL_EXT_device_persistent_id */

// #ifndef EGL_EXT_device_query
// EXT_device_query 1
// #endif /* EGL_EXT_device_query */

// #ifndef EGL_EXT_device_query_name
// EXT_device_query_name 1
// RENDERER_EXT                  0x335F
// #endif /* EGL_EXT_device_query_name */

// #ifndef EGL_EXT_explicit_device
// EXT_explicit_device 1
// #endif /* EGL_EXT_explicit_device */

// #ifndef EGL_EXT_gl_colorspace_bt2020_hlg
// EXT_gl_colorspace_bt2020_hlg 1
// GL_COLORSPACE_BT2020_HLG_EXT  0x3540
// #endif /* EGL_EXT_gl_colorspace_bt2020_hlg */

// #ifndef EGL_EXT_gl_colorspace_bt2020_linear
// EXT_gl_colorspace_bt2020_linear 1
// GL_COLORSPACE_BT2020_LINEAR_EXT 0x333F
// #endif /* EGL_EXT_gl_colorspace_bt2020_linear */

// #ifndef EGL_EXT_gl_colorspace_bt2020_pq
// EXT_gl_colorspace_bt2020_pq 1
// GL_COLORSPACE_BT2020_PQ_EXT   0x3340
// #endif /* EGL_EXT_gl_colorspace_bt2020_pq */

// #ifndef EGL_EXT_gl_colorspace_display_p3
// EXT_gl_colorspace_display_p3 1
// GL_COLORSPACE_DISPLAY_P3_EXT  0x3363
// #endif /* EGL_EXT_gl_colorspace_display_p3 */

// #ifndef EGL_EXT_gl_colorspace_display_p3_linear
// EXT_gl_colorspace_display_p3_linear 1
// GL_COLORSPACE_DISPLAY_P3_LINEAR_EXT 0x3362
// #endif /* EGL_EXT_gl_colorspace_display_p3_linear */

// #ifndef EGL_EXT_gl_colorspace_display_p3_passthrough
// EXT_gl_colorspace_display_p3_passthrough 1
// GL_COLORSPACE_DISPLAY_P3_PASSTHROUGH_EXT 0x3490
// #endif /* EGL_EXT_gl_colorspace_display_p3_passthrough */

// #ifndef EGL_EXT_gl_colorspace_scrgb
// EXT_gl_colorspace_scrgb 1
// GL_COLORSPACE_SCRGB_EXT       0x3351
// #endif /* EGL_EXT_gl_colorspace_scrgb */

// #ifndef EGL_EXT_gl_colorspace_scrgb_linear
// EXT_gl_colorspace_scrgb_linear 1
// GL_COLORSPACE_SCRGB_LINEAR_EXT 0x3350
// #endif /* EGL_EXT_gl_colorspace_scrgb_linear */

// #ifndef EGL_EXT_image_dma_buf_import
// EXT_image_dma_buf_import 1
// LINUX_DMA_BUF_EXT             0x3270
// LINUX_DRM_FOURCC_EXT          0x3271
// DMA_BUF_PLANE0_FD_EXT         0x3272
// DMA_BUF_PLANE0_OFFSET_EXT     0x3273
// DMA_BUF_PLANE0_PITCH_EXT      0x3274
// DMA_BUF_PLANE1_FD_EXT         0x3275
// DMA_BUF_PLANE1_OFFSET_EXT     0x3276
// DMA_BUF_PLANE1_PITCH_EXT      0x3277
// DMA_BUF_PLANE2_FD_EXT         0x3278
// DMA_BUF_PLANE2_OFFSET_EXT     0x3279
// DMA_BUF_PLANE2_PITCH_EXT      0x327A
// YUV_COLOR_SPACE_HINT_EXT      0x327B
// SAMPLE_RANGE_HINT_EXT         0x327C
// YUV_CHROMA_HORIZONTAL_SITING_HINT_EXT 0x327D
// YUV_CHROMA_VERTICAL_SITING_HINT_EXT 0x327E
// ITU_REC601_EXT                0x327F
// ITU_REC709_EXT                0x3280
// ITU_REC2020_EXT               0x3281
// YUV_FULL_RANGE_EXT            0x3282
// YUV_NARROW_RANGE_EXT          0x3283
// YUV_CHROMA_SITING_0_EXT       0x3284
// YUV_CHROMA_SITING_0_5_EXT     0x3285
// #endif /* EGL_EXT_image_dma_buf_import */

// #ifndef EGL_EXT_image_dma_buf_import_modifiers
// EXT_image_dma_buf_import_modifiers 1
// DMA_BUF_PLANE3_FD_EXT         0x3440
// DMA_BUF_PLANE3_OFFSET_EXT     0x3441
// DMA_BUF_PLANE3_PITCH_EXT      0x3442
// DMA_BUF_PLANE0_MODIFIER_LO_EXT 0x3443
// DMA_BUF_PLANE0_MODIFIER_HI_EXT 0x3444
// DMA_BUF_PLANE1_MODIFIER_LO_EXT 0x3445
// DMA_BUF_PLANE1_MODIFIER_HI_EXT 0x3446
// DMA_BUF_PLANE2_MODIFIER_LO_EXT 0x3447
// DMA_BUF_PLANE2_MODIFIER_HI_EXT 0x3448
// DMA_BUF_PLANE3_MODIFIER_LO_EXT 0x3449
// DMA_BUF_PLANE3_MODIFIER_HI_EXT 0x344A
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDMABUFFORMATSEXTPROC) (dpy: Display, i32 max_formats, i32 *formats, i32 *num_formats);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDMABUFMODIFIERSEXTPROC) (dpy: Display, i32 format, i32 max_modifiers, EGLuint64KHR *modifiers, EGLBoolean *external_only, i32 *num_modifiers);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDmaBufFormatsEXT (dpy: Display, i32 max_formats, i32 *formats, i32 *num_formats);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDmaBufModifiersEXT (dpy: Display, i32 format, i32 max_modifiers, EGLuint64KHR *modifiers, EGLBoolean *external_only, i32 *num_modifiers);
// #endif
// #endif /* EGL_EXT_image_dma_buf_import_modifiers */

// #ifndef EGL_EXT_image_gl_colorspace
// EXT_image_gl_colorspace 1
// GL_COLORSPACE_DEFAULT_EXT     0x314D
// #endif /* EGL_EXT_image_gl_colorspace */

// #ifndef EGL_EXT_image_implicit_sync_control
// EXT_image_implicit_sync_control 1
// IMPORT_SYNC_TYPE_EXT          0x3470
// IMPORT_IMPLICIT_SYNC_EXT      0x3471
// IMPORT_EXPLICIT_SYNC_EXT      0x3472
// #endif /* EGL_EXT_image_implicit_sync_control */

// #ifndef EGL_EXT_multiview_window
// EXT_multiview_window 1
// MULTIVIEW_VIEW_COUNT_EXT      0x3134
// #endif /* EGL_EXT_multiview_window */

// #ifndef EGL_EXT_output_base
// EXT_output_base 1
// typedef void *EGLOutputLayerEXT;
// typedef void *EGLOutputPortEXT;
// NO_OUTPUT_LAYER_EXT           EGL_CAST(EGLOutputLayerEXT,0)
// NO_OUTPUT_PORT_EXT            EGL_CAST(EGLOutputPortEXT,0)
// BAD_OUTPUT_LAYER_EXT          0x322D
// BAD_OUTPUT_PORT_EXT           0x322E
// SWAP_INTERVAL_EXT             0x322F
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETOUTPUTLAYERSEXTPROC) (dpy: Display, const EGLAttrib *attrib_list, EGLOutputLayerEXT *layers, i32 max_layers, i32 *num_layers);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETOUTPUTPORTSEXTPROC) (dpy: Display, const EGLAttrib *attrib_list, EGLOutputPortEXT *ports, i32 max_ports, i32 *num_ports);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLOUTPUTLAYERATTRIBEXTPROC) (dpy: Display, EGLOutputLayerEXT layer, i32 attribute, EGLAttrib value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYOUTPUTLAYERATTRIBEXTPROC) (dpy: Display, EGLOutputLayerEXT layer, i32 attribute, EGLAttrib *value);
// typedef const char *(EGLAPIENTRYP PFNEGLQUERYOUTPUTLAYERSTRINGEXTPROC) (dpy: Display, EGLOutputLayerEXT layer, i32 name);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLOUTPUTPORTATTRIBEXTPROC) (dpy: Display, EGLOutputPortEXT port, i32 attribute, EGLAttrib value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYOUTPUTPORTATTRIBEXTPROC) (dpy: Display, EGLOutputPortEXT port, i32 attribute, EGLAttrib *value);
// typedef const char *(EGLAPIENTRYP PFNEGLQUERYOUTPUTPORTSTRINGEXTPROC) (dpy: Display, EGLOutputPortEXT port, i32 name);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglGetOutputLayersEXT (dpy: Display, const EGLAttrib *attrib_list, EGLOutputLayerEXT *layers, i32 max_layers, i32 *num_layers);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetOutputPortsEXT (dpy: Display, const EGLAttrib *attrib_list, EGLOutputPortEXT *ports, i32 max_ports, i32 *num_ports);
// EGLAPI EGLBoolean EGLAPIENTRY eglOutputLayerAttribEXT (dpy: Display, EGLOutputLayerEXT layer, i32 attribute, EGLAttrib value);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryOutputLayerAttribEXT (dpy: Display, EGLOutputLayerEXT layer, i32 attribute, EGLAttrib *value);
// EGLAPI const char *EGLAPIENTRY eglQueryOutputLayerStringEXT (dpy: Display, EGLOutputLayerEXT layer, i32 name);
// EGLAPI EGLBoolean EGLAPIENTRY eglOutputPortAttribEXT (dpy: Display, EGLOutputPortEXT port, i32 attribute, EGLAttrib value);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryOutputPortAttribEXT (dpy: Display, EGLOutputPortEXT port, i32 attribute, EGLAttrib *value);
// EGLAPI const char *EGLAPIENTRY eglQueryOutputPortStringEXT (dpy: Display, EGLOutputPortEXT port, i32 name);
// #endif
// #endif /* EGL_EXT_output_base */

// #ifndef EGL_EXT_output_drm
// EXT_output_drm 1
// DRM_CRTC_EXT                  0x3234
// DRM_PLANE_EXT                 0x3235
// DRM_CONNECTOR_EXT             0x3236
// #endif /* EGL_EXT_output_drm */

// #ifndef EGL_EXT_output_openwf
// EXT_output_openwf 1
// OPENWF_PIPELINE_ID_EXT        0x3238
// OPENWF_PORT_ID_EXT            0x3239
// #endif /* EGL_EXT_output_openwf */

// #ifndef EGL_EXT_pixel_format_float
// EXT_pixel_format_float 1
// COLOR_COMPONENT_TYPE_EXT      0x3339
// COLOR_COMPONENT_TYPE_FIXED_EXT 0x333A
// COLOR_COMPONENT_TYPE_FLOAT_EXT 0x333B
// #endif /* EGL_EXT_pixel_format_float */

// typedef Display (EGLAPIENTRYP PFNEGLGETPLATFORMDISPLAYEXTPROC) (EGLenum platform, void *native_display, const i32 *attrib_list);
// typedef EGLSurface (EGLAPIENTRYP PFNEGLCREATEPLATFORMWINDOWSURFACEEXTPROC) (dpy: Display, EGLConfig config, void *native_window, const i32 *attrib_list);
// typedef EGLSurface (EGLAPIENTRYP PFNEGLCREATEPLATFORMPIXMAPSURFACEEXTPROC) (dpy: Display, EGLConfig config, void *native_pixmap, const i32 *attrib_list);

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    GetPlatformDisplayEXT :: proc (
        platform: u32,
        native_display: rawptr,
        attrib_list: ^Attrib) -> Display ---
}

// EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformWindowSurfaceEXT (dpy: Display, EGLConfig config, void *native_window, const i32 *attrib_list);
// EGLAPI EGLSurface EGLAPIENTRY eglCreatePlatformPixmapSurfaceEXT (dpy: Display, EGLConfig config, void *native_pixmap, const i32 *attrib_list);

// #ifndef EGL_EXT_platform_device
// EXT_platform_device 1
// PLATFORM_DEVICE_EXT           0x313F
// #endif /* EGL_EXT_platform_device */

// #ifndef EGL_EXT_platform_wayland
// EXT_platform_wayland 1
// PLATFORM_WAYLAND_EXT          0x31D8
// #endif /* EGL_EXT_platform_wayland */

// #ifndef EGL_EXT_platform_x11
// EXT_platform_x11 1
// PLATFORM_X11_EXT              0x31D5
// PLATFORM_X11_SCREEN_EXT       0x31D6
// #endif /* EGL_EXT_platform_x11 */

PLATFORM_XCB_EXT        :: 0x31DC
PLATFORM_XCB_SCREEN_EXT :: 0x31DE

// #ifndef EGL_EXT_present_opaque
// EXT_present_opaque 1
// PRESENT_OPAQUE_EXT            0x31DF
// #endif /* EGL_EXT_present_opaque */

// #ifndef EGL_EXT_protected_content
// EXT_protected_content 1
// PROTECTED_CONTENT_EXT         0x32C0
// #endif /* EGL_EXT_protected_content */

// #ifndef EGL_EXT_protected_surface
// EXT_protected_surface 1
// #endif /* EGL_EXT_protected_surface */

// #ifndef EGL_EXT_stream_consumer_egloutput
// EXT_stream_consumer_egloutput 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMEROUTPUTEXTPROC) (dpy: Display, EGLStreamKHR stream, EGLOutputLayerEXT layer);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerOutputEXT (dpy: Display, EGLStreamKHR stream, EGLOutputLayerEXT layer);
// #endif
// #endif /* EGL_EXT_stream_consumer_egloutput */

// #ifndef EGL_EXT_surface_CTA861_3_metadata
// EXT_surface_CTA861_3_metadata 1
// CTA861_3_MAX_CONTENT_LIGHT_LEVEL_EXT 0x3360
// CTA861_3_MAX_FRAME_AVERAGE_LEVEL_EXT 0x3361
// #endif /* EGL_EXT_surface_CTA861_3_metadata */

// #ifndef EGL_EXT_surface_SMPTE2086_metadata
// EXT_surface_SMPTE2086_metadata 1
// SMPTE2086_DISPLAY_PRIMARY_RX_EXT 0x3341
// SMPTE2086_DISPLAY_PRIMARY_RY_EXT 0x3342
// SMPTE2086_DISPLAY_PRIMARY_GX_EXT 0x3343
// SMPTE2086_DISPLAY_PRIMARY_GY_EXT 0x3344
// SMPTE2086_DISPLAY_PRIMARY_BX_EXT 0x3345
// SMPTE2086_DISPLAY_PRIMARY_BY_EXT 0x3346
// SMPTE2086_WHITE_POINT_X_EXT   0x3347
// SMPTE2086_WHITE_POINT_Y_EXT   0x3348
// SMPTE2086_MAX_LUMINANCE_EXT   0x3349
// SMPTE2086_MIN_LUMINANCE_EXT   0x334A
// METADATA_SCALING_EXT          50000
// #endif /* EGL_EXT_surface_SMPTE2086_metadata */

// #ifndef EGL_EXT_surface_compression
// EXT_surface_compression 1
// SURFACE_COMPRESSION_EXT       0x34B0
// SURFACE_COMPRESSION_PLANE1_EXT 0x328E
// SURFACE_COMPRESSION_PLANE2_EXT 0x328F
// SURFACE_COMPRESSION_FIXED_RATE_NONE_EXT 0x34B1
// SURFACE_COMPRESSION_FIXED_RATE_DEFAULT_EXT 0x34B2
// SURFACE_COMPRESSION_FIXED_RATE_1BPC_EXT 0x34B4
// SURFACE_COMPRESSION_FIXED_RATE_2BPC_EXT 0x34B5
// SURFACE_COMPRESSION_FIXED_RATE_3BPC_EXT 0x34B6
// SURFACE_COMPRESSION_FIXED_RATE_4BPC_EXT 0x34B7
// SURFACE_COMPRESSION_FIXED_RATE_5BPC_EXT 0x34B8
// SURFACE_COMPRESSION_FIXED_RATE_6BPC_EXT 0x34B9
// SURFACE_COMPRESSION_FIXED_RATE_7BPC_EXT 0x34BA
// SURFACE_COMPRESSION_FIXED_RATE_8BPC_EXT 0x34BB
// SURFACE_COMPRESSION_FIXED_RATE_9BPC_EXT 0x34BC
// SURFACE_COMPRESSION_FIXED_RATE_10BPC_EXT 0x34BD
// SURFACE_COMPRESSION_FIXED_RATE_11BPC_EXT 0x34BE
// SURFACE_COMPRESSION_FIXED_RATE_12BPC_EXT 0x34BF
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSUPPORTEDCOMPRESSIONRATESEXTPROC) (dpy: Display, EGLConfig config, const EGLAttrib *attrib_list, i32 *rates, i32 rate_size, i32 *num_rates);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQuerySupportedCompressionRatesEXT (dpy: Display, EGLConfig config, const EGLAttrib *attrib_list, i32 *rates, i32 rate_size, i32 *num_rates);
// #endif
// #endif /* EGL_EXT_surface_compression */

// #ifndef EGL_EXT_swap_buffers_with_damage
// EXT_swap_buffers_with_damage 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSWAPBUFFERSWITHDAMAGEEXTPROC) (dpy: Display, EGLSurface surface, const i32 *rects, i32 n_rects);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffersWithDamageEXT (dpy: Display, EGLSurface surface, const i32 *rects, i32 n_rects);
// #endif
// #endif /* EGL_EXT_swap_buffers_with_damage */

// #ifndef EGL_EXT_sync_reuse
// EXT_sync_reuse 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLUNSIGNALSYNCEXTPROC) (dpy: Display, EGLSync sync, const EGLAttrib *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglUnsignalSyncEXT (dpy: Display, EGLSync sync, const EGLAttrib *attrib_list);
// #endif
// #endif /* EGL_EXT_sync_reuse */

// #ifndef EGL_EXT_yuv_surface
// EXT_yuv_surface 1
// YUV_ORDER_EXT                 0x3301
// YUV_NUMBER_OF_PLANES_EXT      0x3311
// YUV_SUBSAMPLE_EXT             0x3312
// YUV_DEPTH_RANGE_EXT           0x3317
// YUV_CSC_STANDARD_EXT          0x330A
// YUV_PLANE_BPP_EXT             0x331A
// YUV_BUFFER_EXT                0x3300
// YUV_ORDER_YUV_EXT             0x3302
// YUV_ORDER_YVU_EXT             0x3303
// YUV_ORDER_YUYV_EXT            0x3304
// YUV_ORDER_UYVY_EXT            0x3305
// YUV_ORDER_YVYU_EXT            0x3306
// YUV_ORDER_VYUY_EXT            0x3307
// YUV_ORDER_AYUV_EXT            0x3308
// YUV_SUBSAMPLE_4_2_0_EXT       0x3313
// YUV_SUBSAMPLE_4_2_2_EXT       0x3314
// YUV_SUBSAMPLE_4_4_4_EXT       0x3315
// YUV_DEPTH_RANGE_LIMITED_EXT   0x3318
// YUV_DEPTH_RANGE_FULL_EXT      0x3319
// YUV_CSC_STANDARD_601_EXT      0x330B
// YUV_CSC_STANDARD_709_EXT      0x330C
// YUV_CSC_STANDARD_2020_EXT     0x330D
// YUV_PLANE_BPP_0_EXT           0x331B
// YUV_PLANE_BPP_8_EXT           0x331C
// YUV_PLANE_BPP_10_EXT          0x331D
// #endif /* EGL_EXT_yuv_surface */

// #ifndef EGL_HI_clientpixmap
// HI_clientpixmap 1
// struct EGLClientPixmapHI {
//     void  *pData;
//     i32 iWidth;
//     i32 iHeight;
//     i32 iStride;
// };
// CLIENT_PIXMAP_POINTER_HI      0x8F74
// typedef EGLSurface (EGLAPIENTRYP PFNEGLCREATEPIXMAPSURFACEHIPROC) (dpy: Display, EGLConfig config, struct EGLClientPixmapHI *pixmap);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLSurface EGLAPIENTRY eglCreatePixmapSurfaceHI (dpy: Display, EGLConfig config, struct EGLClientPixmapHI *pixmap);
// #endif
// #endif /* EGL_HI_clientpixmap */

// #ifndef EGL_HI_colorformats
// HI_colorformats 1
// COLOR_FORMAT_HI               0x8F70
// COLOR_RGB_HI                  0x8F71
// COLOR_RGBA_HI                 0x8F72
// COLOR_ARGB_HI                 0x8F73
// #endif /* EGL_HI_colorformats */

// #ifndef EGL_IMG_context_priority
// IMG_context_priority 1
// CONTEXT_PRIORITY_LEVEL_IMG    0x3100
// CONTEXT_PRIORITY_HIGH_IMG     0x3101
// CONTEXT_PRIORITY_MEDIUM_IMG   0x3102
// CONTEXT_PRIORITY_LOW_IMG      0x3103
// #endif /* EGL_IMG_context_priority */

// #ifndef EGL_IMG_image_plane_attribs
// IMG_image_plane_attribs 1
// NATIVE_BUFFER_MULTIPLANE_SEPARATE_IMG 0x3105
// NATIVE_BUFFER_PLANE_OFFSET_IMG 0x3106
// #endif /* EGL_IMG_image_plane_attribs */

// #ifndef EGL_MESA_drm_image
// MESA_drm_image 1
// DRM_BUFFER_FORMAT_MESA        0x31D0
// DRM_BUFFER_USE_MESA           0x31D1
// DRM_BUFFER_FORMAT_ARGB32_MESA 0x31D2
// DRM_BUFFER_MESA               0x31D3
// DRM_BUFFER_STRIDE_MESA        0x31D4
// DRM_BUFFER_USE_SCANOUT_MESA   0x00000001
// DRM_BUFFER_USE_SHARE_MESA     0x00000002
// DRM_BUFFER_USE_CURSOR_MESA    0x00000004
// typedef EGLImageKHR (EGLAPIENTRYP PFNEGLCREATEDRMIMAGEMESAPROC) (dpy: Display, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLEXPORTDRMIMAGEMESAPROC) (dpy: Display, EGLImageKHR image, i32 *name, i32 *handle, i32 *stride);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLImageKHR EGLAPIENTRY eglCreateDRMImageMESA (dpy: Display, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglExportDRMImageMESA (dpy: Display, EGLImageKHR image, i32 *name, i32 *handle, i32 *stride);
// #endif
// #endif /* EGL_MESA_drm_image */

// #ifndef EGL_MESA_image_dma_buf_export
// MESA_image_dma_buf_export 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLEXPORTDMABUFIMAGEQUERYMESAPROC) (dpy: Display, EGLImageKHR image, int *fourcc, int *num_planes, EGLuint64KHR *modifiers);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLEXPORTDMABUFIMAGEMESAPROC) (dpy: Display, EGLImageKHR image, int *fds, i32 *strides, i32 *offsets);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglExportDMABUFImageQueryMESA (dpy: Display, EGLImageKHR image, int *fourcc, int *num_planes, EGLuint64KHR *modifiers);
// EGLAPI EGLBoolean EGLAPIENTRY eglExportDMABUFImageMESA (dpy: Display, EGLImageKHR image, int *fds, i32 *strides, i32 *offsets);
// #endif
// #endif /* EGL_MESA_image_dma_buf_export */

// #ifndef EGL_MESA_platform_gbm
// MESA_platform_gbm 1
// PLATFORM_GBM_MESA             0x31D7
// #endif /* EGL_MESA_platform_gbm */

PLATFORM_SURFACELESS_MESA :: 0x31DD

// #ifndef EGL_MESA_query_driver
// MESA_query_driver 1
// typedef char *(EGLAPIENTRYP PFNEGLGETDISPLAYDRIVERCONFIGPROC) (dpy: Display);
// typedef const char *(EGLAPIENTRYP PFNEGLGETDISPLAYDRIVERNAMEPROC) (dpy: Display);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI char *EGLAPIENTRY eglGetDisplayDriverConfig (dpy: Display);
// EGLAPI const char *EGLAPIENTRY eglGetDisplayDriverName (dpy: Display);
// #endif
// #endif /* EGL_MESA_query_driver */

// #ifndef EGL_NOK_swap_region
// NOK_swap_region 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSWAPBUFFERSREGIONNOKPROC) (dpy: Display, EGLSurface surface, i32 numRects, const i32 *rects);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffersRegionNOK (dpy: Display, EGLSurface surface, i32 numRects, const i32 *rects);
// #endif
// #endif /* EGL_NOK_swap_region */

// #ifndef EGL_NOK_swap_region2
// NOK_swap_region2 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSWAPBUFFERSREGION2NOKPROC) (dpy: Display, EGLSurface surface, i32 numRects, const i32 *rects);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglSwapBuffersRegion2NOK (dpy: Display, EGLSurface surface, i32 numRects, const i32 *rects);
// #endif
// #endif /* EGL_NOK_swap_region2 */

// #ifndef EGL_NOK_texture_from_pixmap
// NOK_texture_from_pixmap 1
// Y_INVERTED_NOK                0x307F
// #endif /* EGL_NOK_texture_from_pixmap */

// #ifndef EGL_NV_3dvision_surface
// NV_3dvision_surface 1
// AUTO_STEREO_NV                0x3136
// #endif /* EGL_NV_3dvision_surface */

// #ifndef EGL_NV_context_priority_realtime
// NV_context_priority_realtime 1
// CONTEXT_PRIORITY_REALTIME_NV  0x3357
// #endif /* EGL_NV_context_priority_realtime */

// #ifndef EGL_NV_coverage_sample
// NV_coverage_sample 1
// COVERAGE_BUFFERS_NV           0x30E0
// COVERAGE_SAMPLES_NV           0x30E1
// #endif /* EGL_NV_coverage_sample */

// #ifndef EGL_NV_coverage_sample_resolve
// NV_coverage_sample_resolve 1
// COVERAGE_SAMPLE_RESOLVE_NV    0x3131
// COVERAGE_SAMPLE_RESOLVE_DEFAULT_NV 0x3132
// COVERAGE_SAMPLE_RESOLVE_NONE_NV 0x3133
// #endif /* EGL_NV_coverage_sample_resolve */

// #ifndef EGL_NV_cuda_event
// NV_cuda_event 1
// CUDA_EVENT_HANDLE_NV          0x323B
// SYNC_CUDA_EVENT_NV            0x323C
// SYNC_CUDA_EVENT_COMPLETE_NV   0x323D
// #endif /* EGL_NV_cuda_event */

// #ifndef EGL_NV_depth_nonlinear
// NV_depth_nonlinear 1
// DEPTH_ENCODING_NV             0x30E2
// DEPTH_ENCODING_NONE_NV        0
// DEPTH_ENCODING_NONLINEAR_NV   0x30E3
// #endif /* EGL_NV_depth_nonlinear */

// #ifndef EGL_NV_device_cuda
// NV_device_cuda 1
// CUDA_DEVICE_NV                0x323A
// #endif /* EGL_NV_device_cuda */

// #ifndef EGL_NV_native_query
// NV_native_query 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYNATIVEDISPLAYNVPROC) (dpy: Display, EGLNativeDisplayType *display_id);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYNATIVEWINDOWNVPROC) (dpy: Display, EGLSurface surf, EGLNativeWindowType *window);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYNATIVEPIXMAPNVPROC) (dpy: Display, EGLSurface surf, EGLNativePixmapType *pixmap);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryNativeDisplayNV (dpy: Display, EGLNativeDisplayType *display_id);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryNativeWindowNV (dpy: Display, EGLSurface surf, EGLNativeWindowType *window);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryNativePixmapNV (dpy: Display, EGLSurface surf, EGLNativePixmapType *pixmap);
// #endif
// #endif /* EGL_NV_native_query */

// #ifndef EGL_NV_post_convert_rounding
// NV_post_convert_rounding 1
// #endif /* EGL_NV_post_convert_rounding */

// #ifndef EGL_NV_post_sub_buffer
// NV_post_sub_buffer 1
// POST_SUB_BUFFER_SUPPORTED_NV  0x30BE
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLPOSTSUBBUFFERNVPROC) (dpy: Display, EGLSurface surface, i32 x, i32 y, i32 width, i32 height);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglPostSubBufferNV (dpy: Display, EGLSurface surface, i32 x, i32 y, i32 width, i32 height);
// #endif
// #endif /* EGL_NV_post_sub_buffer */

// #ifndef EGL_NV_quadruple_buffer
// NV_quadruple_buffer 1
// QUADRUPLE_BUFFER_NV           0x3231
// #endif /* EGL_NV_quadruple_buffer */

// #ifndef EGL_NV_robustness_video_memory_purge
// NV_robustness_video_memory_purge 1
// GENERATE_RESET_ON_VIDEO_MEMORY_PURGE_NV 0x334C
// #endif /* EGL_NV_robustness_video_memory_purge */

// #ifndef EGL_NV_stream_consumer_eglimage
// NV_stream_consumer_eglimage 1
// STREAM_CONSUMER_IMAGE_NV      0x3373
// STREAM_IMAGE_ADD_NV           0x3374
// STREAM_IMAGE_REMOVE_NV        0x3375
// STREAM_IMAGE_AVAILABLE_NV     0x3376
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMIMAGECONSUMERCONNECTNVPROC) (dpy: Display, EGLStreamKHR stream, i32 num_modifiers, const EGLuint64KHR *modifiers, const EGLAttrib *attrib_list);
// typedef i32 (EGLAPIENTRYP PFNEGLQUERYSTREAMCONSUMEREVENTNVPROC) (dpy: Display, EGLStreamKHR stream, EGLTime timeout, EGLenum *event, EGLAttrib *aux);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMACQUIREIMAGENVPROC) (dpy: Display, EGLStreamKHR stream, EGLImage *pImage, EGLSync sync);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMRELEASEIMAGENVPROC) (dpy: Display, EGLStreamKHR stream, EGLImage image, EGLSync sync);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamImageConsumerConnectNV (dpy: Display, EGLStreamKHR stream, i32 num_modifiers, const EGLuint64KHR *modifiers, const EGLAttrib *attrib_list);
// EGLAPI i32 EGLAPIENTRY eglQueryStreamConsumerEventNV (dpy: Display, EGLStreamKHR stream, EGLTime timeout, EGLenum *event, EGLAttrib *aux);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamAcquireImageNV (dpy: Display, EGLStreamKHR stream, EGLImage *pImage, EGLSync sync);
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamReleaseImageNV (dpy: Display, EGLStreamKHR stream, EGLImage image, EGLSync sync);
// #endif
// #endif /* EGL_NV_stream_consumer_eglimage */

// #ifndef EGL_NV_stream_consumer_eglimage_use_scanout_attrib
// NV_stream_consumer_eglimage_use_scanout_attrib 1
// STREAM_CONSUMER_IMAGE_USE_SCANOUT_NV 0x3378
// #endif /* EGL_NV_stream_consumer_eglimage_use_scanout_attrib */

// #ifndef EGL_NV_stream_consumer_gltexture_yuv
// NV_stream_consumer_gltexture_yuv 1
// YUV_PLANE0_TEXTURE_UNIT_NV    0x332C
// YUV_PLANE1_TEXTURE_UNIT_NV    0x332D
// YUV_PLANE2_TEXTURE_UNIT_NV    0x332E
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMCONSUMERGLTEXTUREEXTERNALATTRIBSNVPROC) (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamConsumerGLTextureExternalAttribsNV (dpy: Display, EGLStreamKHR stream, const EGLAttrib *attrib_list);
// #endif
// #endif /* EGL_NV_stream_consumer_gltexture_yuv */

// #ifndef EGL_NV_stream_cross_display
// NV_stream_cross_display 1
// STREAM_CROSS_DISPLAY_NV       0x334E
// #endif /* EGL_NV_stream_cross_display */

// #ifndef EGL_NV_stream_cross_object
// NV_stream_cross_object 1
// STREAM_CROSS_OBJECT_NV        0x334D
// #endif /* EGL_NV_stream_cross_object */

// #ifndef EGL_NV_stream_cross_partition
// NV_stream_cross_partition 1
// STREAM_CROSS_PARTITION_NV     0x323F
// #endif /* EGL_NV_stream_cross_partition */

// #ifndef EGL_NV_stream_cross_process
// NV_stream_cross_process 1
// STREAM_CROSS_PROCESS_NV       0x3245
// #endif /* EGL_NV_stream_cross_process */

// #ifndef EGL_NV_stream_cross_system
// NV_stream_cross_system 1
// STREAM_CROSS_SYSTEM_NV        0x334F
// #endif /* EGL_NV_stream_cross_system */

// #ifndef EGL_NV_stream_dma
// NV_stream_dma 1
// STREAM_DMA_NV                 0x3371
// STREAM_DMA_SERVER_NV          0x3372
// #endif /* EGL_NV_stream_dma */

// #ifndef EGL_NV_stream_fifo_next
// NV_stream_fifo_next 1
// PENDING_FRAME_NV              0x3329
// STREAM_TIME_PENDING_NV        0x332A
// #endif /* EGL_NV_stream_fifo_next */

// #ifndef EGL_NV_stream_fifo_synchronous
// NV_stream_fifo_synchronous 1
// STREAM_FIFO_SYNCHRONOUS_NV    0x3336
// #endif /* EGL_NV_stream_fifo_synchronous */

// #ifndef EGL_NV_stream_flush
// NV_stream_flush 1
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSTREAMFLUSHNVPROC) (dpy: Display, EGLStreamKHR stream);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglStreamFlushNV (dpy: Display, EGLStreamKHR stream);
// #endif
// #endif /* EGL_NV_stream_flush */

// #ifndef EGL_NV_stream_frame_limits
// NV_stream_frame_limits 1
// PRODUCER_MAX_FRAME_HINT_NV    0x3337
// CONSUMER_MAX_FRAME_HINT_NV    0x3338
// #endif /* EGL_NV_stream_frame_limits */

// #ifndef EGL_NV_stream_metadata
// NV_stream_metadata 1
// MAX_STREAM_METADATA_BLOCKS_NV 0x3250
// MAX_STREAM_METADATA_BLOCK_SIZE_NV 0x3251
// MAX_STREAM_METADATA_TOTAL_SIZE_NV 0x3252
// PRODUCER_METADATA_NV          0x3253
// CONSUMER_METADATA_NV          0x3254
// PENDING_METADATA_NV           0x3328
// METADATA0_SIZE_NV             0x3255
// METADATA1_SIZE_NV             0x3256
// METADATA2_SIZE_NV             0x3257
// METADATA3_SIZE_NV             0x3258
// METADATA0_TYPE_NV             0x3259
// METADATA1_TYPE_NV             0x325A
// METADATA2_TYPE_NV             0x325B
// METADATA3_TYPE_NV             0x325C
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYDISPLAYATTRIBNVPROC) (dpy: Display, i32 attribute, EGLAttrib *value);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSETSTREAMMETADATANVPROC) (dpy: Display, EGLStreamKHR stream, i32 n, i32 offset, i32 size, const void *data);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYSTREAMMETADATANVPROC) (dpy: Display, EGLStreamKHR stream, EGLenum name, i32 n, i32 offset, i32 size, void *data);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryDisplayAttribNV (dpy: Display, i32 attribute, EGLAttrib *value);
// EGLAPI EGLBoolean EGLAPIENTRY eglSetStreamMetadataNV (dpy: Display, EGLStreamKHR stream, i32 n, i32 offset, i32 size, const void *data);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryStreamMetadataNV (dpy: Display, EGLStreamKHR stream, EGLenum name, i32 n, i32 offset, i32 size, void *data);
// #endif
// #endif /* EGL_NV_stream_metadata */

// #ifndef EGL_NV_stream_origin
// NV_stream_origin 1
// STREAM_FRAME_ORIGIN_X_NV      0x3366
// STREAM_FRAME_ORIGIN_Y_NV      0x3367
// STREAM_FRAME_MAJOR_AXIS_NV    0x3368
// CONSUMER_AUTO_ORIENTATION_NV  0x3369
// PRODUCER_AUTO_ORIENTATION_NV  0x336A
// LEFT_NV                       0x336B
// RIGHT_NV                      0x336C
// TOP_NV                        0x336D
// BOTTOM_NV                     0x336E
// X_AXIS_NV                     0x336F
// Y_AXIS_NV                     0x3370
// #endif /* EGL_NV_stream_origin */

// #ifndef EGL_NV_stream_remote
// NV_stream_remote 1
// STREAM_STATE_INITIALIZING_NV  0x3240
// STREAM_TYPE_NV                0x3241
// STREAM_PROTOCOL_NV            0x3242
// STREAM_ENDPOINT_NV            0x3243
// STREAM_LOCAL_NV               0x3244
// STREAM_PRODUCER_NV            0x3247
// STREAM_CONSUMER_NV            0x3248
// STREAM_PROTOCOL_FD_NV         0x3246
// #endif /* EGL_NV_stream_remote */

// #ifndef EGL_NV_stream_reset
// NV_stream_reset 1
// SUPPORT_RESET_NV              0x3334
// SUPPORT_REUSE_NV              0x3335
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLRESETSTREAMNVPROC) (dpy: Display, EGLStreamKHR stream);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglResetStreamNV (dpy: Display, EGLStreamKHR stream);
// #endif
// #endif /* EGL_NV_stream_reset */

// #ifndef EGL_NV_stream_socket
// NV_stream_socket 1
// STREAM_PROTOCOL_SOCKET_NV     0x324B
// SOCKET_HANDLE_NV              0x324C
// SOCKET_TYPE_NV                0x324D
// #endif /* EGL_NV_stream_socket */

// #ifndef EGL_NV_stream_socket_inet
// NV_stream_socket_inet 1
// SOCKET_TYPE_INET_NV           0x324F
// #endif /* EGL_NV_stream_socket_inet */

// #ifndef EGL_NV_stream_socket_unix
// NV_stream_socket_unix 1
// SOCKET_TYPE_UNIX_NV           0x324E
// #endif /* EGL_NV_stream_socket_unix */

// #ifndef EGL_NV_stream_sync
// NV_stream_sync 1
// SYNC_NEW_FRAME_NV             0x321F
// typedef SyncKHR (EGLAPIENTRYP PFNEGLCREATESTREAMSYNCNVPROC) (dpy: Display, EGLStreamKHR stream, EGLenum type, const i32 *attrib_list);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI SyncKHR EGLAPIENTRY eglCreateStreamSyncNV (dpy: Display, EGLStreamKHR stream, EGLenum type, const i32 *attrib_list);
// #endif
// #endif /* EGL_NV_stream_sync */

// #ifndef EGL_NV_sync
// NV_sync 1
// typedef void *EGLSyncNV;
// typedef khronos_utime_nanoseconds_t EGLTimeNV;
// #ifdef KHRONOS_SUPPORT_INT64
// SYNC_PRIOR_COMMANDS_COMPLETE_NV 0x30E6
// SYNC_STATUS_NV                0x30E7
// SIGNALED_NV                   0x30E8
// UNSIGNALED_NV                 0x30E9
// SYNC_FLUSH_COMMANDS_BIT_NV    0x0001
// FOREVER_NV                    0xFFFFFFFFFFFFFFFFull
// ALREADY_SIGNALED_NV           0x30EA
// TIMEOUT_EXPIRED_NV            0x30EB
// CONDITION_SATISFIED_NV        0x30EC
// SYNC_TYPE_NV                  0x30ED
// SYNC_CONDITION_NV             0x30EE
// SYNC_FENCE_NV                 0x30EF
// NO_SYNC_NV                    EGL_CAST(EGLSyncNV,0)
// typedef EGLSyncNV (EGLAPIENTRYP PFNEGLCREATEFENCESYNCNVPROC) (dpy: Display, EGLenum condition, const i32 *attrib_list);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLDESTROYSYNCNVPROC) (EGLSyncNV sync);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLFENCENVPROC) (EGLSyncNV sync);
// typedef i32 (EGLAPIENTRYP PFNEGLCLIENTWAITSYNCNVPROC) (EGLSyncNV sync, i32 flags, EGLTimeNV timeout);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLSIGNALSYNCNVPROC) (EGLSyncNV sync, EGLenum mode);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLGETSYNCATTRIBNVPROC) (EGLSyncNV sync, i32 attribute, i32 *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLSyncNV EGLAPIENTRY eglCreateFenceSyncNV (dpy: Display, EGLenum condition, const i32 *attrib_list);
// EGLAPI EGLBoolean EGLAPIENTRY eglDestroySyncNV (EGLSyncNV sync);
// EGLAPI EGLBoolean EGLAPIENTRY eglFenceNV (EGLSyncNV sync);
// EGLAPI i32 EGLAPIENTRY eglClientWaitSyncNV (EGLSyncNV sync, i32 flags, EGLTimeNV timeout);
// EGLAPI EGLBoolean EGLAPIENTRY eglSignalSyncNV (EGLSyncNV sync, EGLenum mode);
// EGLAPI EGLBoolean EGLAPIENTRY eglGetSyncAttribNV (EGLSyncNV sync, i32 attribute, i32 *value);
// #endif
// #endif /* KHRONOS_SUPPORT_INT64 */
// #endif /* EGL_NV_sync */

// #ifndef EGL_NV_system_time
// NV_system_time 1
// typedef khronos_utime_nanoseconds_t EGLuint64NV;
// #ifdef KHRONOS_SUPPORT_INT64
// typedef EGLuint64NV (EGLAPIENTRYP PFNEGLGETSYSTEMTIMEFREQUENCYNVPROC) (void);
// typedef EGLuint64NV (EGLAPIENTRYP PFNEGLGETSYSTEMTIMENVPROC) (void);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLuint64NV EGLAPIENTRY eglGetSystemTimeFrequencyNV (void);
// EGLAPI EGLuint64NV EGLAPIENTRY eglGetSystemTimeNV (void);
// #endif
// #endif /* KHRONOS_SUPPORT_INT64 */
// #endif /* EGL_NV_system_time */

// #ifndef EGL_NV_triple_buffer
// NV_triple_buffer 1
// TRIPLE_BUFFER_NV              0x3230
// #endif /* EGL_NV_triple_buffer */

// #ifndef EGL_QNX_image_native_buffer
// QNX_image_native_buffer 1
// NATIVE_BUFFER_QNX             0x3551
// #endif /* EGL_QNX_image_native_buffer */

// #ifndef EGL_QNX_platform_screen
// QNX_platform_screen 1
// PLATFORM_SCREEN_QNX           0x3550
// #endif /* EGL_QNX_platform_screen */

// #ifndef EGL_TIZEN_image_native_buffer
// TIZEN_image_native_buffer 1
// NATIVE_BUFFER_TIZEN           0x32A0
// #endif /* EGL_TIZEN_image_native_buffer */

// #ifndef EGL_TIZEN_image_native_surface
// TIZEN_image_native_surface 1
// NATIVE_SURFACE_TIZEN          0x32A1
// #endif /* EGL_TIZEN_image_native_surface */

// #ifndef EGL_WL_bind_wayland_display
// WL_bind_wayland_display 1
// #define PFNEGLBINDWAYLANDDISPLAYWL PFNEGLBINDWAYLANDDISPLAYWLPROC
// #define PFNEGLUNBINDWAYLANDDISPLAYWL PFNEGLUNBINDWAYLANDDISPLAYWLPROC
// #define PFNEGLQUERYWAYLANDBUFFERWL PFNEGLQUERYWAYLANDBUFFERWLPROC
// struct wl_display;
// struct wl_resource;
// WAYLAND_BUFFER_WL             0x31D5
// WAYLAND_PLANE_WL              0x31D6
// TEXTURE_Y_U_V_WL              0x31D7
// TEXTURE_Y_UV_WL               0x31D8
// TEXTURE_Y_XUXV_WL             0x31D9
// TEXTURE_EXTERNAL_WL           0x31DA
// WAYLAND_Y_INVERTED_WL         0x31DB
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLBINDWAYLANDDISPLAYWLPROC) (dpy: Display, struct wl_display *display);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLUNBINDWAYLANDDISPLAYWLPROC) (dpy: Display, struct wl_display *display);
// typedef EGLBoolean (EGLAPIENTRYP PFNEGLQUERYWAYLANDBUFFERWLPROC) (dpy: Display, struct wl_resource *buffer, i32 attribute, i32 *value);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI EGLBoolean EGLAPIENTRY eglBindWaylandDisplayWL (dpy: Display, struct wl_display *display);
// EGLAPI EGLBoolean EGLAPIENTRY eglUnbindWaylandDisplayWL (dpy: Display, struct wl_display *display);
// EGLAPI EGLBoolean EGLAPIENTRY eglQueryWaylandBufferWL (dpy: Display, struct wl_resource *buffer, i32 attribute, i32 *value);
// #endif
// #endif /* EGL_WL_bind_wayland_display */

// #ifndef EGL_WL_create_wayland_buffer_from_image
// WL_create_wayland_buffer_from_image 1
// #define PFNEGLCREATEWAYLANDBUFFERFROMIMAGEWL PFNEGLCREATEWAYLANDBUFFERFROMIMAGEWLPROC
// struct wl_buffer;
// typedef struct wl_buffer *(EGLAPIENTRYP PFNEGLCREATEWAYLANDBUFFERFROMIMAGEWLPROC) (dpy: Display, EGLImageKHR image);
// #ifdef EGL_EGLEXT_PROTOTYPES
// EGLAPI struct wl_buffer *EGLAPIENTRY eglCreateWaylandBufferFromImageWL (dpy: Display, EGLImageKHR image);
// #endif
// #endif /* EGL_WL_create_wayland_buffer_from_image */

// /* ANGLE EGL extensions */
// #include "eglext_angle.h"

// #ifdef __cplusplus
// }
// #endif

// #endif

