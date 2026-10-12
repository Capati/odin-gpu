// Globals provided by plain <script> tags (wasm/third-party runtime), not modules.
declare class Stats {
  showPanel(n: number): void;
  dom: HTMLElement;
  begin(): void;
  end(): void;
}

interface OdinMemoryInterface {
  setMemory(mem: WebAssembly.Memory): void;
  setIntSize(size: number): void;
}

interface OdinWasmModule {
  WasmMemoryInterface: new () => OdinMemoryInterface;
  WebGPUInterface: new (mem: OdinMemoryInterface) => { getInterface(): unknown };
  UtilsInterface: new (mem: OdinMemoryInterface) => { getInterface(): unknown };
  runWasm(
    path: string,
    canvas: null,
    imports: { webgpu: unknown; js_utils: unknown },
    memInterface: OdinMemoryInterface,
    intSize: number,
  ): unknown;
}

interface Window {
  odin?: OdinWasmModule;
}
