#+build windows
package gpu

// // Core
// import "core:log"
// import win32 "core:sys/windows"

// // Vendor
// import "vendor:directx/dxgi"

// d3d_check :: #force_inline proc(
//     res: win32.HRESULT,
//     message := #caller_expression(res),
//     loc := #caller_location,
// ) {
//     if win32.SUCCEEDED(res) {
//         return
//     }

//     log.panicf("D3D: [%0x] - %v", u32(res), message, location = loc)
// }

// d3d_check_ok :: #force_inline proc(
//     res: win32.HRESULT,
//     message := #caller_expression(res),
//     loc := #caller_location,
// ) -> bool {
//     if win32.SUCCEEDED(res) {
//         return true
//     }

//     log.errorf("D3D: [%0x] - %v", u32(res), message, location = loc)

//     return false
// }

// d3d_create_factory :: proc(debug := ODIN_DEBUG, loc := #caller_location) -> ^dxgi.IFactory4 {
//     dxgi_factory: ^dxgi.IFactory4

//     // Enable DXGI debug layer if configured
//     dxgi_factory_flags: dxgi.CREATE_FACTORY
//     if debug {
//         dxgi_factory_flags |= {.DEBUG}
//     }

//     hr := dxgi.CreateDXGIFactory2(
//         dxgi_factory_flags, dxgi.IFactory4_UUID, cast(^rawptr)&dxgi_factory)

//     // Check if debug layers is the reason for an error
//     if hr == dxgi.ERROR_INVALID_CALL && .DEBUG in dxgi_factory_flags {
//         hr_prev := hr
//         hr = dxgi.CreateDXGIFactory2({}, dxgi.IFactory4_UUID, cast(^rawptr)&dxgi_factory)
//         if hr == win32.S_OK {
//             log.warnf("D3D: debug layers disabled: %0x", u32(hr_prev))
//         }
//     }
//     d3d_check(hr, "D3D: dxgi.CreateDXGIFactory2 failed", loc)

//     return dxgi_factory
// }

// d3d_discover_adapters :: proc(
//     factory: ^dxgi.IFactory4,
//     options: Request_Adapter_Options,
//     allocator := context.allocator,
//     loc := #caller_location,
// ) -> []^dxgi.IAdapter1 {
//     list := make([dynamic]^dxgi.IAdapter1, allocator)

//     if options.force_fallback_adapter {
//         warp1: ^dxgi.IAdapter1
//         hr := factory->EnumWarpAdapter(dxgi.IAdapter1_UUID, cast(^rawptr)&warp1)
//         if hr == win32.S_OK {
//             append(&list, warp1)
//             return list[:]
//         }
//     }

//     gpu_preference := d3d_conv_to_gpu_preference(options.power_preference)

//     // IFactory6 isn't available on all Windows 10 versions. If present, use
//     // it to enumerate adapters ordered by power preference; otherwise fall
//     // back to plain IFactory1::EnumAdapters1 (insertion order, no preference).
//     dxgi_factory6: ^dxgi.IFactory6
//     use_factory6 := win32.SUCCEEDED(
//         factory->QueryInterface(dxgi.IFactory6_UUID, cast(^rawptr)&dxgi_factory6))
//     defer if use_factory6 { dxgi_factory6->Release() }

//     // Enumerate and discover all available physical devices.
//     for i: u32 = 0; ; i += 1 {
//         dxgi_adapter: ^dxgi.IAdapter1
//         hr: win32.HRESULT
//         if use_factory6 {
//             hr = dxgi_factory6->EnumAdapterByGpuPreference(
//                 i, gpu_preference, dxgi.IAdapter1_UUID, cast(^rawptr)&dxgi_adapter)
//         } else {
//             hr = factory->EnumAdapters1(i, &dxgi_adapter)
//         }

//         if hr == dxgi.ERROR_NOT_FOUND {
//             break // No more adapters to enumerate.
//         }
//         if !win32.SUCCEEDED(hr) {
//             continue
//         }

//         append(&list, dxgi_adapter)
//     }

//     return list[:]
// }

// d3d_tearing_support :: proc(factory: ^dxgi.IFactory4) -> (tearing_support: bool) {
//     // Create a temp IFactory5 to check for tearing support
//     dxgi_factory5: ^dxgi.IFactory5
//     factory->QueryInterface(dxgi.IFactory5_UUID, cast(^rawptr)&dxgi_factory5)
//     defer if dxgi_factory5 != nil {
//         dxgi_factory5->Release()
//     }
//     if dxgi_factory5 != nil {
//         allow_tearing: win32.BOOL
//         hr := dxgi_factory5->CheckFeatureSupport(
//             .PRESENT_ALLOW_TEARING, &allow_tearing, size_of(win32.BOOL))
//         tearing_support = bool(hr == win32.S_OK && allow_tearing)
//     }
//     return
// }

// // D3D_SwapChain :: struct {
// //     dxgi_swap_chain:  ^dxgi.ISwapChain3,
// //     buffer_count:     u32,
// //     swap_chain_flags: dxgi.SWAP_CHAIN,
// //     dxgi_format:      dxgi.FORMAT,
// //     dxgi_usage:       dxgi.USAGE,
// // }

// // d3d_swap_chain_init :: proc(
// //     self: ^D3D_SwapChain,
// //     previous_swap_chain: ^D3D_SwapChain,
// //     config: Surface_Configuration,
// //     loc := #caller_location,
// // ) {
// //     // Flip-model swapchains only accept the non-sRGB
// //     format := texture_format_remove_srgb_suffix(config.format, loc)

// //     // Compute DXGI swapchain params from config
// //     self.buffer_count = d3d_conv_to_buffer_count(config.present_mode)
// //     self.dxgi_format = d3d_conv_to_dxgi_format(format)
// //     self.swap_chain_flags = d3d_conv_to_swap_chain_flags(config.present_mode)
// //     self.dxgi_usage = d3d_conv_to_dxgi_usage(config.usage, format)
// // }
