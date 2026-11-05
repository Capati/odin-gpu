#+build !js
package gpu

// Core
import "core:dynlib"
import "core:log"
import "core:sync"

// Vendor
import vk "vendor:vulkan"

// Process-wide Vulkan loader lifecycle.
//
// The library is opened once and shared by every instance. A caller-supplied
// `vkGetInstanceProcAddr` (from `Vulkan_Backend_Options.get_instance_proc_addr`)
// takes precedence over opening the platform library, which is what embedded
// hosts and MoltenVK need.

VK_Library :: struct {
    proc_addr: vk.ProcGetInstanceProcAddr,
    library:   dynlib.Library,
    ref:       Ref_Count_Type,
    loaded:    bool,
}

VK_Library_State :: enum u8 {
    Init,
    Uninit,
}

// Guards the process-wide loader state and the global Vulkan proc tables that
// every instance shares. Instances may be created in parallel; the loader and
// the function-pointer writes may not.
vk_loader_mutex: sync.Mutex

@(require_results)
@(private)
vk_initialization :: proc(
    state: VK_Library_State,
    proc_addr: vk.ProcGetInstanceProcAddr = nil,
) -> vk.Result {
    @(static) lib: VK_Library

    sync.guard(&vk_loader_mutex)

    switch state {
    case .Uninit:
        if lib.loaded {
            if unload := release_ref(&lib); unload {
                dynlib.unload_library(lib.library)
                lib.loaded = false
            }
        }
        return .SUCCESS
    case .Init:
        if sync.atomic_load(&lib.ref) == 0 {
            init_ref(&lib)
        } else {
            add_ref(&lib)
        }
    }

    if proc_addr != nil {
        lib.proc_addr = proc_addr
    } else if !lib.loaded {
        when ODIN_OS == .Windows {
            lib.library, lib.loaded = dynlib.load_library("vulkan-1.dll")
        } else when ODIN_OS == .Darwin {
            lib.library, lib.loaded = dynlib.load_library("libvulkan.dylib")
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libvulkan.1.dylib")
            }
            // modern versions of macOS don't search /usr/local/lib automatically contrary to
            // what man dlopen says; the Vulkan SDK uses this as the system-wide
            // installation location, so fall back to it if all else fails
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("/usr/local/lib/libvulkan.dylib")
            }
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libMoltenVK.dylib")
            }
            // store rules for iOS strictly enforce no .dylib's. If they aren't
            // found it just falls through
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("vulkan.framework/vulkan")
            }
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("MoltenVK.framework/MoltenVK")
            }
        } else {
            lib.library, lib.loaded = dynlib.load_library("libvulkan.so.1")
            if !lib.loaded {
                lib.library, lib.loaded = dynlib.load_library("libvulkan.so")
            }
        }

        if !lib.loaded {
            log.error("Vulkan: Failed to load the library")
            return .ERROR_INITIALIZATION_FAILED
        }

        INSTANCE_PROC_ADDR_STR :: "vkGetInstanceProcAddr"
        if fp, found := dynlib.symbol_address(lib.library, INSTANCE_PROC_ADDR_STR); found {
            lib.proc_addr = vk.ProcGetInstanceProcAddr(fp)
        } else {
            log.error("Vulkan: Failed to get symbol address " + INSTANCE_PROC_ADDR_STR)
            return .ERROR_INITIALIZATION_FAILED
        }
    }

    // Load the base Vulkan procedures before we can start using them.
    vk.load_proc_addresses_global(auto_cast lib.proc_addr)
    if vk.CreateInstance == nil {
        log.error("Vulkan: Failed to load proc addresses global")
        return .ERROR_INITIALIZATION_FAILED
    }

    return .SUCCESS
}
