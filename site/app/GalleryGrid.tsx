"use client";

import { useState } from "react";
import type { ExampleEntry } from "../lib/examples";

type Card = Pick<ExampleEntry, "name" | "title" | "excerpt" | "screenshot" | "source" | "web">;

export default function GalleryGrid({ examples }: { examples: Card[] }) {
  const [filter, setFilter] = useState("");
  const q = filter.toLowerCase().trim();
  const shown = examples.filter(
    (ex) => !q || `${ex.name} ${ex.title} ${ex.excerpt}`.toLowerCase().includes(q),
  );
  return (
    <>
      <input
        id="search"
        type="search"
        placeholder="Filter examples…"
        aria-label="Filter examples"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        className="mb-5 mt-[18px] w-full max-w-[420px] rounded-lg border border-line bg-pre px-3 py-[9px] text-sm text-ink"
      />
      <div id="grid" className="grid grid-cols-[repeat(auto-fill,minmax(300px,1fr))] gap-4">
        {shown.map((ex) => (
          <article
            key={ex.name}
            className="group relative isolate flex flex-col overflow-hidden rounded-[10px] border border-line bg-panel transition-colors hover:border-dim focus-within:border-dim"
            >
            {ex.screenshot ? (
                <span className="block aspect-[16/9] overflow-hidden bg-well">
                <img
                    className="block h-full w-full object-cover transition-transform duration-200 group-hover:scale-[1.03]"
                    src={`e/${ex.name}/${ex.screenshot}`}
                    alt={`${ex.title} screenshot`}
                    loading="lazy"
                    decoding="async"
                />
                </span>
            ) : (
                <span className="flex aspect-[16/9] items-center justify-center overflow-hidden bg-well text-[13px] text-dim">
                No screenshot
                </span>
            )}

            <div className="flex flex-1 flex-col gap-2 px-3.5 pb-3.5 pt-3">
                <h2 className="flex items-center gap-2 text-base">
                {ex.web ? (
                    <a
                    className="text-ink after:absolute after:inset-0 after:content-[''] hover:text-link"
                    href={`e/${ex.name}/`}
                    >
                    {ex.title}
                    </a>
                ) : (
                    <span className="text-ink">{ex.title}</span>
                )}
                {!ex.web && (
                    <span className="rounded border border-line bg-chip px-1.5 py-px text-[11px] font-normal text-dim">
                    Native only
                    <span className="sr-only"> (no live demo available)</span>
                    </span>
                )}
                </h2>

                <p className="flex-1 text-[13px] leading-[1.5] text-dim line-clamp-3">
                {ex.excerpt || "No description yet."}
                </p>

                <div className="relative z-10 mt-1 flex flex-wrap gap-2">
                {ex.web && (
                    <a
                    href={`e/${ex.name}/`}
                    className="inline-flex items-center gap-1 rounded-md border border-link/30 bg-link/10 px-2.5 py-1 text-[12px] font-medium text-link transition-colors hover:border-link/50 hover:bg-link/15"
                    >
                    Open live
                    <span aria-hidden="true">&rarr;</span>
                    </a>
                )}
                <a
                    href={ex.source}
                    aria-label={`Source for ${ex.title}`}
                    className="inline-flex items-center gap-1 rounded-md border border-line px-2.5 py-1 text-[12px] font-medium text-dim transition-colors hover:border-dim hover:text-ink"
                >
                    Source
                </a>
                </div>
            </div>
            </article>
        ))}
      </div>
      {shown.length === 0 && <p className="text-dim">No examples match.</p>}
    </>
  );
}
