#!/usr/bin/env node
// Stage everything the Next.js site needs to build the showcase.
//
// Reads each runnable example in examples/*/ (title + description from its
// README.md, thumbnail from its *.png) and stages, under site/:
//
//   site/data/examples.json    manifest (title, excerpt, screenshot, source,
//                              web flag)
//   site/public/e/<name>/*.png screenshots next to their page + app.wasm
//   site/public/shared/        odin.js, webgpu.js, utils.js, third-party/, icons
//   site/public/assets/        from examples/build/assets (needs the submodule)
//
// An example is native-only (web: false, no live demo) when it cannot compile
// for js_wasm32, detected via #+build !js on its main file (e.g. imgui).
// The per-example app.wasm files are NOT built here, see build_web_all.*.
//
// Usage (from repo root):
//   node site/tools/prep_examples.mjs [--list] [--assets copy|link|skip]
//   --list prints web-buildable example names only (used by build_web_all.*).
//
// Local preview:
//   node site/tools/prep_examples.mjs [--assets skip]
//   site/tools/build_web_all.bat release [only <name>...]
//   npm --prefix site run build; serve site/out.

import { cpSync, existsSync, mkdirSync, readdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const SITE_DIR = path.join(ROOT, "site");
const SITE_PUBLIC = path.join(SITE_DIR, "public");
const SITE_DATA = path.join(SITE_DIR, "data");
const EXAMPLES_DIR = path.join(ROOT, "examples");
const WASM_DIR = path.join(ROOT, "wasm");
const ASSETS_SRC = path.join(EXAMPLES_DIR, "build", "assets");

const REPO_URL = "https://github.com/Capati/odin-gpu";

// Gallery order, matching examples/README.md table of contents.
// "info" is intentionally excluded: console-only, nothing to showcase.
const ORDER = [
  "minimal", "clear_screen", "triangle", "square", "blend",
  "vertex_buffer", "coordinate_system", "cube", "rotating_cube", "two_cubes",
  "instanced_cube", "textured_cube", "fractal_cube", "cubemap", "texture_3d",
  "points", "prng", "out_of_bounds_viewport", "stencil_triangles",
  "pristine_grid", "microui", "imgui", "gltf_cube", "obj_model", "gltf_viewer",
];

const SHARED_FILES = ["odin.js", "webgpu.js", "utils.js"];
const ICON_FILES = [
  "favicon.ico", "favicon-16x16.png", "favicon-32x32.png",
  "apple-touch-icon.png", "android-chrome-192x192.png", "android-chrome-512x512.png",
];
const MANIFEST = `{"name": "odin-gpu examples", "short_name": "odin-gpu",
"icons": [{"src": "android-chrome-192x192.png", "sizes": "192x192", "type": "image/png"},
{"src": "android-chrome-512x512.png", "sizes": "512x512", "type": "image/png"}],
"theme_color": "#0b0e14", "background_color": "#0b0e14", "display": "standalone"}
`;

const IMAGE_EXT = /\.(png|jpe?g|gif|svg|webp)$/i;

function stripMarkdown(text) {
  return text
    .replace(/!\[([^\]]*)\]\([^)]+\)/g, "$1")
    .replace(/\[([^\]]+)\]\([^)]+\)/g, "$1")
    .replace(/`([^`]+)`/g, "$1")
    .replace(/\*\*([^*]+)\*\*/g, "$1")
    .replace(/^#{1,3}\s+/gm, "")
    .replace(/^[-*]\s+/gm, "")
    .replace(/\s+/g, " ")
    .trim();
}

function parseReadme(dir) {
  const md = readFileSync(path.join(dir, "README.md"), "utf8");
  const lines = md.split("\n");
  let title = path.basename(dir);
  let bodyStart = 0;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].startsWith("# ")) {
      title = lines[i].slice(2).trim();
      bodyStart = i + 1;
      break;
    }
  }
  const body = lines.slice(bodyStart).join("\n");
  let excerpt = "";
  for (const chunk of body.split(/\n\s*\n/)) {
    const t = chunk.trim();
    if (!t || t.startsWith("```") || t.startsWith("#") || t.startsWith("-") ||
        t.startsWith("![") || t.startsWith("http") || t.startsWith("Ref:") ||
        t.startsWith("TODO")) continue;
    excerpt = stripMarkdown(t);
    break;
  }
  if (excerpt.length > 240) {
    const cut = excerpt.slice(0, 237);
    excerpt = (cut.includes(" ") ? cut.slice(0, cut.lastIndexOf(" ")) : cut) + "...";
  }
  return { title, excerpt };
}

function discover() {
  const found = [];
  for (const name of ORDER) {
    const dir = path.join(EXAMPLES_DIR, name);
    if (!existsSync(path.join(dir, "README.md"))) {
      console.log(`warn: examples/${name} missing or has no README.md, skipped`);
      continue;
    }
    found.push(dir);
  }
  return found;
}

// Native-only if the example cannot compile for js_wasm32: its main file
// (<name>.odin, else every top-level .odin file) carries #+build !js.
function isNativeOnly(dir, name) {
  const main = path.join(dir, `${name}.odin`);
  const files = existsSync(main)
    ? [main]
    : readdirSync(dir).filter((f) => f.endsWith(".odin")).map((f) => path.join(dir, f));
  if (files.length === 0) return false;
  return files.every((f) => {
    const head = readFileSync(f, "utf8").split("\n").slice(0, 10).join("\n");
    return /#\+build[^\n]*!js/.test(head);
  });
}

function copyShared() {
  const shared = path.join(SITE_PUBLIC, "shared");
  mkdirSync(path.join(shared, "third-party"), { recursive: true });
  for (const name of SHARED_FILES) {
    const src = path.join(WASM_DIR, name);
    if (existsSync(src)) cpSync(src, path.join(shared, name));
    else console.log(`warn: wasm/${name} missing, not copied`);
  }
  const tp = path.join(WASM_DIR, "third-party");
  if (existsSync(tp)) {
    for (const f of readdirSync(tp)) cpSync(path.join(tp, f), path.join(shared, "third-party", f));
  }
  for (const name of ICON_FILES) {
    const src = path.join(WASM_DIR, name);
    if (existsSync(src)) cpSync(src, path.join(shared, name));
  }
  writeFileSync(path.join(shared, "site.webmanifest"), MANIFEST);
  writeFileSync(path.join(SITE_PUBLIC, ".nojekyll"), "");
}

function copyAssets(mode) {
  if (mode === "skip") return;
  if (!existsSync(ASSETS_SRC)) {
    console.log("warn: examples/build/assets not checked out (submodule?), site assets skipped");
    return;
  }
  const dest = path.join(SITE_PUBLIC, "assets");
  rmSync(dest, { recursive: true, force: true });
  if (mode === "link") {
    try {
      symlinkSync(ASSETS_SRC, dest, "dir");
      console.log(`linked assets -> ${ASSETS_SRC}`);
      return;
    } catch (e) {
      console.log(`warn: symlink failed (${e.message}), copying instead`);
    }
  }
  cpSync(ASSETS_SRC, dest, { recursive: true, filter: (src) => !src.endsWith(".git") });
  console.log("copied assets");
}

function main(argv) {
  const args = argv.slice(2);
  let assetsMode = "copy";
  const ai = args.indexOf("--assets");
  if (ai !== -1 && args[ai + 1]) assetsMode = args[ai + 1];
  if (!["copy", "link", "skip"].includes(assetsMode)) {
    console.error(`unknown --assets mode: ${assetsMode}`);
    process.exitCode = 1;
    return;
  }
  const dirs = discover();
  if (args.includes("--list")) {
    // Web-buildable examples only; native-only ones can't compile for wasm.
    for (const d of dirs) {
      const name = path.basename(d);
      if (!isNativeOnly(d, name)) console.log(name);
    }
    return;
  }

  copyShared();
  copyAssets(assetsMode);

  const entries = [];
  for (const dir of dirs) {
    const name = path.basename(dir);
    const { title, excerpt } = parseReadme(dir);
    const web = !isNativeOnly(dir, name);
    const dest = path.join(SITE_PUBLIC, "e", name);
    mkdirSync(dest, { recursive: true });
    let shot = null;
    const pngs = readdirSync(dir).filter((f) => IMAGE_EXT.test(f)).sort();
    for (const png of pngs) {
      cpSync(path.join(dir, png), path.join(dest, png));
      if (shot === null && png === `${name}.png`) shot = png;
    }
    if (shot === null && pngs.length > 0) shot = pngs[0];
    if (web && !existsSync(path.join(dest, "app.wasm"))) {
      console.log(`note: site/public/e/${name}/app.wasm missing (run tools/build_web_all to build it)`);
    }
    entries.push({
      name,
      title,
      excerpt,
      screenshot: shot,
      source: `${REPO_URL}/tree/main/examples/${name}`,
      web,
    });
  }

  mkdirSync(SITE_DATA, { recursive: true });
  writeFileSync(path.join(SITE_DATA, "examples.json"), JSON.stringify(entries, null, 2) + "\n");
  const native = entries.filter((e) => !e.web).map((e) => e.name);
  console.log(`site: ${entries.length} examples staged${native.length ? ` (native-only: ${native.join(", ")})` : ""}`);
}

main(process.argv);
