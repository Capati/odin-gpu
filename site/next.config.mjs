/** @type {import('next').NextConfig} */
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.dirname(fileURLToPath(import.meta.url));

const nextConfig = {
  // Static export for GitHub Pages (no server at runtime).
  output: "export",
  // Emit e/<name>/index.html so relative ../../shared/* paths keep working.
  trailingSlash: true,
  // Project Pages live under /odin-gpu; CI sets NEXT_BASE_PATH=/odin-gpu.
  basePath: process.env.NEXT_BASE_PATH || "",
  // No Image Optimization API on static hosting; plain <img> is used anyway.
  images: { unoptimized: true },
  // Pin the workspace root so stray lockfiles above site/ are ignored.
  turbopack: { root },
};

export default nextConfig;
