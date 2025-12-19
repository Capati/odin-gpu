import typescript from "@rollup/plugin-typescript";
import { nodeResolve } from "@rollup/plugin-node-resolve";
import commonjs from "@rollup/plugin-commonjs";
import { terser } from "rollup-plugin-terser";

export default {
    input: "gpu.ts",
    output: {
        file: "gpu.js",
        format: "esm",
        sourcemap: true,
    },
    plugins: [
        nodeResolve({
            browser: true,
        }),
        typescript({
            tsconfig: "./tsconfig.json",
            sourceMap: true,
        }),
        commonjs(),
        terser({
            format: {
                comments: false,
            },
            compress: {
                drop_console: true,
            },
        }),
    ],
};
