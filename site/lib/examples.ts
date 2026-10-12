import { readFileSync } from "node:fs";
import path from "node:path";

export interface ExampleEntry {
  name: string;
  title: string;
  excerpt: string;
  screenshot: string | null;
  source: string;
  /** False for native-only examples (e.g. imgui): card shown, no live demo. */
  web: boolean;
}

/** Read the staged manifest (written by tools/prep_examples.mjs). Build-time only. */
export function getExamples(): ExampleEntry[] {
  const file = path.join(process.cwd(), "data", "examples.json");
  return JSON.parse(readFileSync(file, "utf8")) as ExampleEntry[];
}
