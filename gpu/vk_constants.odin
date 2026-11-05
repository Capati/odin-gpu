#+build !js
package gpu

// Vulkan backend-wide constants.
//
// These are the hard limits the backend's structures are sized against. They are
// deliberately independent from the WebGPU-facing constants in `constants.odin`:
// the public limits describe what an application may ask for, these describe what
// the Vulkan implementation can be handed.

// Largest binding size expressible by a signed 32-bit Vulkan binding offset.
VK_MAX_I32_BINDING_SIZE :: (1 << 31) - 1

// Largest target pixel byte cost the backend accepts for a renderable format.
VK_MAX_TARGET_PIXEL_BYTE_COST :: 16

// Descriptor sets bound to a pipeline layout (Vulkan's own maximum).
VK_MAX_BIND_GROUPS :: 8

// Vertex buffers a pipeline can bind.
VK_MAX_VERTEX_BUFFERS :: 16

// Colour attachments per render pass.
VK_MAX_COLOR_ATTACHMENTS :: 8

// Colour + resolve attachments plus one depth/stencil attachment.
VK_MAX_TOTAL_ATTACHMENTS :: VK_MAX_COLOR_ATTACHMENTS * 2 + 1

// Default subgroup bounds reported when the device exposes no subgroup properties.
VK_SUBGROUP_MIN_DEFAULT :: 4
VK_SUBGROUP_MAX_DEFAULT :: 128
