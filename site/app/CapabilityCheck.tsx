"use client";

import { useEffect, useState } from "react";

type Status = "checking" | "ok" | "fail";

const DOT: Record<Status, string> = {
  checking: "animate-pulse bg-[#d29922]",
  ok: "bg-[#3fb950]",
  fail: "bg-[#f85149]",
};

function checkWasm(): boolean {
  try {
    if (
      typeof WebAssembly !== "object" ||
      typeof WebAssembly.validate !== "function"
    ) {
      return false;
    }
    // Smallest valid module: magic + version, no sections.
    return WebAssembly.validate(new Uint8Array([0, 97, 115, 109, 1, 0, 0, 0]));
  } catch {
    return false;
  }
}

function checkJspi(): boolean {
  try {
    if (typeof WebAssembly !== "object") return false;
    const wasm = WebAssembly as unknown as { Suspending?: unknown };
    return typeof wasm.Suspending === "function";
  } catch {
    return false;
  }
}

async function checkWebGpu(): Promise<boolean> {
  try {
    const nav = navigator as Navigator & {
      gpu?: { requestAdapter: () => Promise<unknown> };
    };
    if (!nav.gpu) return false;
    return (await nav.gpu.requestAdapter()) != null;
  } catch {
    return false;
  }
}

interface Row {
  key: string;
  label: string;
  status: Status;
  detail: string;
}

export default function CapabilityCheck() {
  const [gpu, setGpu] = useState<Status>("checking");
//   const [wasm, setWasm] = useState<Status>("checking");
  const [jspi, setJspi] = useState<Status>("checking");

  useEffect(() => {
    // setWasm(checkWasm() ? "ok" : "fail");
    setJspi(checkJspi() ? "ok" : "fail");
    checkWebGpu().then((ok) => setGpu(ok ? "ok" : "fail"));
  }, []);

  const rows: Row[] = [
    {
      key: "webgpu",
      label: "WebGPU",
      status: gpu,
      detail:
        gpu === "ok"
          ? "Available — demos can use your GPU."
          : gpu === "fail"
            ? "Unavailable — use Chrome or Edge on desktop with hardware acceleration enabled, over HTTPS or localhost."
            : "Checking for a GPU adapter…",
    },
    // {
    //   key: "wasm",
    //   label: "WebAssembly",
    //   status: wasm,
    //   detail:
    //     wasm === "ok"
    //       ? "Supported — demo binaries can run."
    //       : wasm === "fail"
    //         ? "Not supported by this browser — the demos cannot run here."
    //         : "Checking…",
    // },
    {
      key: "jspi",
      label: "JSPI",
      status: jspi,
      detail:
        jspi === "ok"
          ? "Available — WASM can call async browser APIs (used for adapter/device setup)."
          : jspi === "fail"
            ? "Unavailable — update Chrome/Edge to version 126 or newer."
            : "Checking…",
    },
  ];

  return (
    <div
      id="notice"
      className="mt-[14px] rounded-lg border border-line bg-chip px-[14px] py-[10px] text-[13px] text-dim"
    >
      <ul className="m-0 flex list-none flex-col gap-1.5 p-0">
        {rows.map((row) => (
          <li key={row.key} className="flex items-start gap-2">
            <span
              aria-hidden="true"
              title={row.status}
              className={`mt-[3px] inline-block h-2.5 w-2.5 shrink-0 rounded-full ${DOT[row.status]}`}
            />
            <span>
              <strong className="font-semibold text-ink">{row.label}</strong> — {row.detail}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
