"use client";

import { useEffect, useRef, useState } from "react";

const NO_GPU_MSG =
  "WebGPU is not available in this browser. Open this page in Chrome or Edge (desktop) with hardware acceleration enabled.";
const MISSING_WASM_MSG =
  "app.wasm is missing for this example. Build it first: site/tools/build_web_all.[bat|sh] <name>, or wait for the Pages CI deploy.";

function boot(onFirstFrame: () => void) {
  const odin = window.odin;
  if (!odin) {
    throw new Error("odin runtime failed to load");
  }
  // Same boot code as wasm/index.html.
  const stats = new Stats();
  stats.showPanel(0); // 0: fps, 1: ms, 2: mb
  document.body.appendChild(stats.dom);

  const mem = new WebAssembly.Memory({ initial: 2000, maximum: 65536, shared: false });
  const memInterface = new odin.WasmMemoryInterface();
  memInterface.setMemory(mem);
  const wgpuInterface = new odin.WebGPUInterface(memInterface);
  const utilsInterface = new odin.UtilsInterface(memInterface);
  memInterface.setIntSize(4);
  odin.runWasm(
    "app.wasm",
    null,
    {
      webgpu: wgpuInterface.getInterface(),
      js_utils: utilsInterface.getInterface(),
    },
    memInterface,
    4,
  );

  const originalRAF = window.requestAnimationFrame;
  let firstFrame = true;
  window.requestAnimationFrame = function (callback: FrameRequestCallback) {
    return originalRAF.call(window, function (time: number) {
      if (firstFrame) {
        firstFrame = false;
        onFirstFrame();
      }
      stats.begin();
      callback(time);
      stats.end();
    });
  };
}

export default function ExampleBoot() {
  const [notice, setNotice] = useState<string | null>(null);
  const [noGpu, setNoGpu] = useState(false);
  const [loading, setLoading] = useState(true);
  const booted = useRef(false);

  useEffect(() => {
    // Site hosts one shared assets/ folder at the site root, while examples
    // fetch relative "assets/..." paths. Rewrite those to the shared location.
    // The "./assets/..." form is tolerated too (model-file derived paths).
    // Harmless otherwise.
    const origOpen = XMLHttpRequest.prototype.open as unknown as (
      this: XMLHttpRequest,
      ...args: unknown[]
    ) => void;
    XMLHttpRequest.prototype.open = function (
      this: XMLHttpRequest,
      method: string,
      url: string | URL,
      ...rest: unknown[]
    ) {
      let target: string | URL = url;
      if (typeof target === "string") {
        if (target.indexOf("assets/") === 0) {
          target = `../../assets/${target.slice(7)}`;
        } else if (target.indexOf("./assets/") === 0) {
          target = `../../assets/${target.slice(9)}`;
        }
      }
      origOpen.apply(this, [method, target, ...rest]);
    };
    if (booted.current) return;
    booted.current = true;
    // Fallback so the spinner can never stick forever (e.g. RAF throttled
    // in a background tab, where the first frame fires only on focus).
    const fallback = window.setTimeout(() => setLoading(false), 30000);
    const done = () => {
      window.clearTimeout(fallback);
      setLoading(false);
    };
    const fail = (msg: string) => {
      window.clearTimeout(fallback);
      setNotice(msg);
      setLoading(false);
    };
    if (!("gpu" in navigator)) {
      setNoGpu(true);
      fail(NO_GPU_MSG);
      return;
    }
    // Skip booting when the wasm for this example has not been deployed yet
    // (e.g. local preview before running tools/build_web_all).
    fetch("app.wasm", { method: "HEAD" }).then(
      (res) => {
        if (res.ok) {
          try {
            boot(done);
          } catch (e) {
            fail(`Failed to start: ${e instanceof Error ? e.message : String(e)}`);
          }
        } else {
          fail(MISSING_WASM_MSG);
        }
      },
      () => {
        try {
          boot(done);
        } catch (e) {
          fail(`Failed to start: ${e instanceof Error ? e.message : String(e)}`);
        }
      },
    );
    return () => window.clearTimeout(fallback);
  }, []);

  return (
    <>
      {loading && (
        <div
          id="loader"
          className="fixed inset-0 z-10 flex flex-col items-center justify-center gap-3 bg-page/80"
        >
          <span
            aria-hidden="true"
            className="block h-10 w-10 animate-spin rounded-full border-2 border-line border-t-link"
          />
          <span className="text-sm text-dim">Loading demo…</span>
        </div>
      )}
      {notice && (
        <div
          id="notice"
          className="fixed inset-x-0 top-0 z-20 border-b border-line bg-warnbg px-3 py-2 text-[13px] text-warn"
        >
          {notice}
        </div>
      )}
      <div id="wrap" className={noGpu ? "nocanvas" : "h-full"}>
        <canvas id="canvas" className="block h-full w-full" />
      </div>
    </>
  );
}
