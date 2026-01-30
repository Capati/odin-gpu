# wgpu.js

This file is required to use the api on the web.

## Known Issues

We are using the wgpu bindings from vendor that is fine, but the original `wgpu.js` has bugs or
missing functions that need to be addressed. Below are the issues and their fixes in our custom
implementation.

### 1. Incorrect return type in `wgpuTextureGetUsage`

**Problem:** The function returns a JavaScript `number`, but the usage flags are `u64` in Odin.
  WebAssembly expects a `BigInt` for 64-bit integer return values.

**Fix:** Convert the return value to `BigInt`:

```js
/**
 * @param {number} textureIdx
 * @returns {bigint}
 */
wgpuTextureGetUsage: (textureIdx) => {
    const texture = this.textures.get(textureIdx);
    return BigInt(texture.usage);
},
```

### 2. Incorrect memory offset calculation in `RequiredLimitsPtr`

**Problem:** The original implementation adds 8 bytes of padding in `RequiredLimitsPtr`, and the
  `Limits` function adds another 4 bytes. This double-skip causes all values to be shifted
  incorrectly when reading the struct.

**Fix:** Remove the 8-byte offset and let the `Limits` function handle skipping its own
  `nextInChain`:

```js
/**
 * @param {number} ptr
 * @returns {GPUSupportedLimits}
 */
RequiredLimitsPtr(ptr) {
    const start = this.mem.loadPtr(ptr);
    if (start == 0) {
        return undefined;
    }
    return this.Limits(start); // Pass start directly, not start + 8
}
```

### 3. Missing function `wgpuTextureGetDepthOrArrayLayers`

**Fix**: Add the missing function:

```js
/**
 * @param {number} textureIdx
 * @returns {number}
 */
wgpuTextureGetDepthOrArrayLayers: (textureIdx) => {
    const texture = this.textures.get(textureIdx);
    return texture.depthOrArrayLayers;
},
```

## utils.js

Utility functions used by the examples framework, this is not required to use the wegpu api.
