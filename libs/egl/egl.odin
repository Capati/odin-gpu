#+build linux
package egl

foreign import egl "system:EGL"

NativeDisplayType :: distinct rawptr
NativePixmapType  :: distinct rawptr
NativeWindowType  :: distinct rawptr

Display :: distinct rawptr
Config  :: distinct rawptr
Surface :: distinct rawptr
Context :: distinct rawptr

ALPHA_SIZE              :: 0x3021
BAD_ACCESS              :: 0x3002
BAD_ALLOC               :: 0x3003
BAD_ATTRIBUTE           :: 0x3004
BAD_CONFIG              :: 0x3005
BAD_CONTEXT             :: 0x3006
BAD_CURRENT_SURFACE     :: 0x3007
BAD_DISPLAY             :: 0x3008
BAD_MATCH               :: 0x3009
BAD_NATIVE_PIXMAP       :: 0x300A
BAD_NATIVE_WINDOW       :: 0x300B
BAD_PARAMETER           :: 0x300C
BAD_SURFACE             :: 0x300D
BLUE_SIZE               :: 0x3022
BUFFER_SIZE             :: 0x3020
CONFIG_CAVEAT           :: 0x3027
CONFIG_ID               :: 0x3028
CORE_NATIVE_ENGINE      :: 0x305B
DEPTH_SIZE              :: 0x3025
DONT_CARE               :: -1
DRAW                    :: 0x3059
EXTENSIONS              :: 0x3055
FALSE                   :: 0
GREEN_SIZE              :: 0x3023
HEIGHT                  :: 0x3056
LARGEST_PBUFFER         :: 0x3058
LEVEL                   :: 0x3029
MAX_PBUFFER_HEIGHT      :: 0x302A
MAX_PBUFFER_PIXELS      :: 0x302B
MAX_PBUFFER_WIDTH       :: 0x302C
NATIVE_RENDERABLE       :: 0x302D
NATIVE_VISUAL_ID        :: 0x302E
NATIVE_VISUAL_TYPE      :: 0x302F
NONE                    :: 0x3038
NON_CONFORMANT_CONFIG   :: 0x3051
NOT_INITIALIZED         :: 0x3001
NO_CONTEXT              :: Context(uintptr(0))
NO_DISPLAY              :: Display(uintptr(0))
NO_SURFACE              :: Surface(uintptr(0))
NO_CONFIG               :: Config(uintptr(0))
PBUFFER_BIT             :: 0x0001
PIXMAP_BIT              :: 0x0002
READ                    :: 0x305A
RED_SIZE                :: 0x3024
SAMPLES                 :: 0x3031
SAMPLE_BUFFERS          :: 0x3032
SLOW_CONFIG             :: 0x3050
STENCIL_SIZE            :: 0x3026
SUCCESS                 :: 0x3000
SURFACE_TYPE            :: 0x3033
TRANSPARENT_BLUE_VALUE  :: 0x3035
TRANSPARENT_GREEN_VALUE :: 0x3036
TRANSPARENT_RED_VALUE   :: 0x3037
TRANSPARENT_RGB         :: 0x3052
TRANSPARENT_TYPE        :: 0x3034
TRUE                    :: 1
VENDOR                  :: 0x3053
VERSION                 :: 0x3054
WIDTH                   :: 0x3057
WINDOW_BIT              :: 0x0004

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    ChooseConfig :: proc(
        dpy: Display,
        attrib_list: ^i32,
        configs: [^]Config,
        config_size: i32,
        num_config: ^i32,
    ) -> b32 ---
    CopyBuffers :: proc(dpy: Display, surface: Surface, target: NativePixmapType) -> b32 ---
    CreateContext :: proc(
        dpy: Display,
        config: Config,
        share_context: Context,
        attrib_list: ^i32,
    ) -> Context ---
    CreatePbufferSurface :: proc(dpy: Display, config: Config, attrib_list: ^i32) -> Surface ---
    CreatePixmapSurface :: proc(
        dpy: Display,
        config: Config,
        pixmap: NativePixmapType,
        attrib_list: ^i32,
    ) -> Surface ---
    CreateWindowSurface :: proc(
        dpy: Display,
        config: Config,
        win: NativeWindowType,
        attrib_list: ^i32,
    ) -> Surface ---
    DestroyContext :: proc(dpy: Display, ctx: Context) -> b32 ---
    DestroySurface :: proc(dpy: Display, surface: Surface) -> b32 ---
    GetConfigAttrib :: proc(
        dpy: Display,
        config: Config,
        attribute: i32,
        value: ^i32,
    ) -> b32 ---
    GetConfigs :: proc(
        dpy: Display,
        configs: [^]Config,
        config_size: i32,
        num_config: ^i32,
    ) -> b32 ---
    GetCurrentDisplay :: proc() -> Display ---
    GetCurrentSurface :: proc(readdraw: i32) -> Surface ---
    GetDisplay :: proc(display_id: NativeDisplayType) -> Display ---
    GetError :: proc() -> i32 ---
    GetProcAddress :: proc(procname: cstring) -> rawptr ---
    Initialize :: proc(dpy: Display, major, minor: ^i32) -> b32 ---
    MakeCurrent :: proc(dpy: Display, draw: Surface, read: Surface, ctx: Context) -> b32 ---
    QueryContext :: proc(dpy: Display, ctx: Context, attribute: i32, value: ^i32) -> b32 ---
    QueryString :: proc(dpy: Display, name: i32) -> cstring ---
    QuerySurface :: proc(dpy: Display, surface: Surface, attribute: i32, value: ^i32) -> b32 ---
    SwapBuffers :: proc(dpy: Display, surface: Surface) -> b32 ---
    Terminate :: proc(dpy: Display) -> b32 ---
    WaitGL :: proc() -> b32 ---
    WaitNative :: proc(engine: i32) -> b32 ---
}

BACK_BUFFER          :: 0x3084
BIND_TO_TEXTURE_RGB  :: 0x3039
BIND_TO_TEXTURE_RGBA :: 0x303A
CONTEXT_LOST         :: 0x300E
MIN_SWAP_INTERVAL    :: 0x303B
MAX_SWAP_INTERVAL    :: 0x303C
MIPMAP_TEXTURE       :: 0x3082
MIPMAP_LEVEL         :: 0x3083
NO_TEXTURE           :: 0x305C
TEXTURE_2D           :: 0x305F
TEXTURE_FORMAT       :: 0x3080
TEXTURE_RGB          :: 0x305D
TEXTURE_RGBA         :: 0x305E
TEXTURE_TARGET       :: 0x3081

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    BindTexImage :: proc(dpy: Display, surface: Surface, buffer: i32) -> b32 ---
    ReleaseTexImage :: proc(dpy: Display, surface: Surface, buffer: i32) -> b32 ---
    SurfaceAttrib :: proc(dpy: Display, surface: Surface, attribute: i32, value: i32) -> b32 ---
    SwapInterval :: proc(dpy: Display, interval: i32) -> b32 ---
}

ClientBuffer :: distinct rawptr

ALPHA_FORMAT          :: 0x3088
ALPHA_FORMAT_NONPRE   :: 0x308B
ALPHA_FORMAT_PRE      :: 0x308C
ALPHA_MASK_SIZE       :: 0x303E
BUFFER_PRESERVED      :: 0x3094
BUFFER_DESTROYED      :: 0x3095
CLIENT_APIS           :: 0x308D
COLORSPACE            :: 0x3087
COLORSPACE_sRGB       :: 0x3089
COLORSPACE_LINEAR     :: 0x308A
COLOR_BUFFER_TYPE     :: 0x303F
CONTEXT_CLIENT_TYPE   :: 0x3097
DISPLAY_SCALING       :: 10000
HORIZONTAL_RESOLUTION :: 0x3090
LUMINANCE_BUFFER      :: 0x308F
LUMINANCE_SIZE        :: 0x303D
OPENGL_ES_BIT         :: 0x0001
OPENVG_BIT            :: 0x0002
OPENGL_ES_API         :: 0x30A0
OPENVG_API            :: 0x30A1
OPENVG_IMAGE          :: 0x3096
PIXEL_ASPECT_RATIO    :: 0x3092
RENDERABLE_TYPE       :: 0x3040
RENDER_BUFFER         :: 0x3086
RGB_BUFFER            :: 0x308E
SINGLE_BUFFER         :: 0x3085
SWAP_BEHAVIOR         :: 0x3093
UNKNOWN               :: -1
VERTICAL_RESOLUTION   :: 0x3091

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    BindAPI :: proc(api: u32) -> b32 ---
    QueryAPI :: proc() -> u32 ---
    CreatePbufferFromClientBuffer :: proc(
        dpy: Display,
        buftype: u32,
        buffer: ClientBuffer,
        config: Config,
        attrib_list: ^i32,
    ) -> Surface ---
    ReleaseThread :: proc() -> b32 ---
    WaitClient :: proc() -> b32 ---
}

CONFORMANT               :: 0x3042
CONTEXT_CLIENT_VERSION   :: 0x3098
MATCH_NATIVE_PIXMAP      :: 0x3041
OPENGL_ES2_BIT           :: 0x0004
VG_ALPHA_FORMAT          :: 0x3088
VG_ALPHA_FORMAT_NONPRE   :: 0x308B
VG_ALPHA_FORMAT_PRE      :: 0x308C
VG_ALPHA_FORMAT_PRE_BIT  :: 0x0040
VG_COLORSPACE            :: 0x3087
VG_COLORSPACE_sRGB       :: 0x3089
VG_COLORSPACE_LINEAR     :: 0x308A
VG_COLORSPACE_LINEAR_BIT :: 0x0020

DEFAULT_DISPLAY :: NativeDisplayType(uintptr(0))

MULTISAMPLE_RESOLVE_BOX_BIT :: 0x0200
MULTISAMPLE_RESOLVE         :: 0x3099
MULTISAMPLE_RESOLVE_DEFAULT :: 0x309A
MULTISAMPLE_RESOLVE_BOX     :: 0x309B
OPENGL_API                  :: 0x30A2
OPENGL_BIT                  :: 0x0008
SWAP_BEHAVIOR_PRESERVED_BIT :: 0x0400

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    GetCurrentContext :: proc() -> Context ---
}

Sync :: distinct rawptr
Image :: distinct rawptr

CONTEXT_MAJOR_VERSION                      :: 0x3098
CONTEXT_MINOR_VERSION                      :: 0x30FB
CONTEXT_OPENGL_PROFILE_MASK                :: 0x30FD
CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY :: 0x31BD
NO_RESET_NOTIFICATION                      :: 0x31BE
LOSE_CONTEXT_ON_RESET                      :: 0x31BF
CONTEXT_OPENGL_CORE_PROFILE_BIT            :: 0x00000001
CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT   :: 0x00000002
CONTEXT_OPENGL_DEBUG                       :: 0x31B0
CONTEXT_OPENGL_FORWARD_COMPATIBLE          :: 0x31B1
CONTEXT_OPENGL_ROBUST_ACCESS               :: 0x31B2
OPENGL_ES3_BIT                             :: 0x00000040
CL_EVENT_HANDLE                            :: 0x309C
SYNC_CL_EVENT                              :: 0x30FE
SYNC_CL_EVENT_COMPLETE                     :: 0x30FF
SYNC_PRIOR_COMMANDS_COMPLETE               :: 0x30F0
SYNC_TYPE                                  :: 0x30F7
SYNC_STATUS                                :: 0x30F1
SYNC_CONDITION                             :: 0x30F8
SIGNALED                                   :: 0x30F2
UNSIGNALED                                 :: 0x30F3
SYNC_FLUSH_COMMANDS_BIT                    :: 0x0001
FOREVER                                    :: max(u64)
TIMEOUT_EXPIRED                            :: 0x30F5
CONDITION_SATISFIED                        :: 0x30F6
NO_SYNC                                    :: Sync(uintptr(0))
SYNC_FENCE                                 :: 0x30F9
GL_COLORSPACE                              :: 0x309D
GL_COLORSPACE_SRGB                         :: 0x3089
GL_COLORSPACE_LINEAR                       :: 0x308A
GL_RENDERBUFFER                            :: 0x30B9
GL_TEXTURE_2D                              :: 0x30B1
GL_TEXTURE_LEVEL                           :: 0x30BC
GL_TEXTURE_3D                              :: 0x30B2
GL_TEXTURE_ZOFFSET                         :: 0x30BD
GL_TEXTURE_CUBE_MAP_POSITIVE_X             :: 0x30B3
GL_TEXTURE_CUBE_MAP_NEGATIVE_X             :: 0x30B4
GL_TEXTURE_CUBE_MAP_POSITIVE_Y             :: 0x30B5
GL_TEXTURE_CUBE_MAP_NEGATIVE_Y             :: 0x30B6
GL_TEXTURE_CUBE_MAP_POSITIVE_Z             :: 0x30B7
GL_TEXTURE_CUBE_MAP_NEGATIVE_Z             :: 0x30B8
IMAGE_PRESERVED                            :: 0x30D2
NO_IMAGE                                   :: Image(uintptr(0))

@(default_calling_convention="c", link_prefix="egl")
foreign egl {
    CreateSync :: proc(dpy: Display, type: u32, attrib_list: ^int) -> Sync ---
    DestroySync :: proc(dpy: Display, sync: Sync) -> b32 ---
    ClientWaitSync :: proc(dpy: Display, sync: Sync, flags: i32, timeout: u64) -> i32 ---
    GetSyncAttrib :: proc(dpy: Display, sync: Sync, attribute: i32, value: ^int) -> b32 ---
    CreateImage :: proc(
        dpy: Display,
        ctx: Context,
        target: u32,
        buffer: ClientBuffer,
        attrib_list: ^int,
    ) -> Image ---
    DestroyImage :: proc(dpy: Display, image: Image) -> b32 ---
    GetPlatformDisplay :: proc(platform: u32, native_display: rawptr, attrib_list: ^int) -> Display ---
    CreatePlatformWindowSurface :: proc(
        dpy: Display,
        config: Config,
        native_window: rawptr,
        attrib_list: ^int,
    ) -> Surface ---
    CreatePlatformPixmapSurface :: proc(
        dpy: Display,
        config: Config,
        native_pixmap: rawptr,
        attrib_list: ^int,
    ) -> Surface ---
    WaitSync :: proc(dpy: Display, sync: Sync, flags: i32) -> b32 ---
}

gl_set_proc_address :: proc(p: rawptr, name: cstring) {
    (^rawptr)(p)^ = GetProcAddress(name)
}
