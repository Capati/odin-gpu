// Prints the real js_wasm32 layout of the gpu package structs.
const memInterface = new odin.WasmMemoryInterface();
memInterface.setMemory(new WebAssembly.Memory({initial: 2000, maximum: 65536, shared: false}));
memInterface.setIntSize(4);

odin.runWasm('layout.wasm', document.getElementById('out'), {}, memInterface, 4);
