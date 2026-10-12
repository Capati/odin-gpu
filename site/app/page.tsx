import type { Metadata } from "next";
import CapabilityCheck from "./CapabilityCheck";
import GalleryGrid from "./GalleryGrid";
import { getExamples } from "../lib/examples";

export const metadata: Metadata = {
  icons: { icon: [{ url: "shared/favicon.ico" }] },
  manifest: "shared/site.webmanifest",
};

export default function Home() {
  const examples = getExamples().map(({ name, title, excerpt, screenshot, source, web }) => ({
    name,
    title,
    excerpt,
    screenshot,
    source,
    web: web !== false,
  }));
  const live = examples.filter((ex) => ex.web).length;
  return (
    <main className="mx-auto max-w-[1100px] px-5 pb-[60px] pt-7">
      <header className="flex flex-wrap items-baseline gap-x-4 gap-y-2">
        <h1 className="text-[26px]">odin-gpu examples</h1>
        <a className="text-link hover:underline" href="https://github.com/Capati/odin-gpu">
          repository
        </a>
      </header>
      <p className="mt-2 leading-[1.5] text-dim">
        {live} live WebGPU demos, built from{" "}
        <code className="rounded bg-chip px-1.5 py-px">examples/</code> with{" "}
        <code className="rounded bg-chip px-1.5 py-px">
          build.[bat|sh] &lt;name&gt; web release
        </code>
        .
      </p>
      <CapabilityCheck />
      <GalleryGrid examples={examples} />
      <footer className="mt-9 text-[13px] text-dim">
        Built with{" "}
        <a className="text-link hover:underline" href="https://nextjs.org/">
          Next.js
        </a>{" "}
        &middot;{" "}
        <a className="text-link hover:underline" href="https://github.com/Capati/odin-gpu">
          Capati/odin-gpu
        </a>
      </footer>
    </main>
  );
}
