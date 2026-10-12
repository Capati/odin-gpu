#!/bin/bash

# Shader compiler driver: DXIL, DXBC, GLSL Desktop, SPIRV and WGSL from a single
# .slang file (GLSL ES stays disabled, as in the .bat). Usage: build_shader.sh
# <relative_path_to_shader.slang> [output_dir]
#
# The stage is taken from the file name:
#
#   - name.vert.slang -> vertex only
#   - name.frag.slang -> fragment only
#   - anything else   -> both

# Check if slangc is available
if ! command -v slangc &> /dev/null; then
    if [ -z "$VULKAN_SDK" ]; then
        echo "slangc not found in PATH and VULKAN_SDK not set. Skipping shader compilation."
        exit 0
    fi
    SLANGC="$VULKAN_SDK/bin/slangc"
    if [ ! -f "$SLANGC" ]; then
        echo "slangc not found. Skipping shader compilation."
        exit 0
    fi
else
    SLANGC="slangc"
fi

# Check if shader file is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $(basename "$0") <relative_path_to_shader.slang> [output_dir]"
    echo ""
    echo "  The stage is taken from the file name:"
    echo "    name.vert.slang  -> vertex only"
    echo "    name.frag.slang  -> fragment only"
    echo "    name.slang       -> both vertex and fragment"
    exit 1
fi

# Extract shader file, name, and output directory
SHADER_FILE="$1"
SHADER_NAME="$(basename "${SHADER_FILE%.*}")"

if [ -z "$2" ]; then
    SHADER_DIR="$(dirname "$SHADER_FILE")"
else
    SHADER_DIR="$2"
fi

# Strip trailing slash (if any) so paths below can be built with a single "/"
SHADER_DIR="${SHADER_DIR%/}"

# The file name decides the stage (case-insensitive, like build_shader.bat).
DO_VERT=true
DO_FRAG=true
NAME_TAIL="${SHADER_NAME: -5}"
NAME_TAIL_LOWER="$(echo "$NAME_TAIL" | tr '[:upper:]' '[:lower:]')"
if [ "$NAME_TAIL_LOWER" = ".vert" ]; then
    DO_FRAG=false
    SHADER_NAME="${SHADER_NAME%.*}"
fi
if [ "$NAME_TAIL_LOWER" = ".frag" ]; then
    DO_VERT=false
    SHADER_NAME="${SHADER_NAME%.*}"
fi

# Create shader output directories
for sub in SPIRV DXIL DXBC "GLSL/Desktop" WGSL; do
    mkdir -p "${SHADER_DIR}/${sub}"
done

SHADER_ERROR=false

# Helper: run a command, print a message and flag SHADER_ERROR on failure
compile_or_fail() {
    local err_msg="$1"
    shift
    "$@"
    if [ $? -ne 0 ]; then
        echo "$err_msg"
        SHADER_ERROR=true
    fi
}

# ── DXIL ─────────────────────────────────────────────────────────────────────

if [ "$DO_VERT" = true ]; then
    compile_or_fail "Failed to compile vertex shader to DXIL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry vs_main \
        -matrix-layout-column-major \
        -stage vertex \
        -target dxil \
        -profile sm_6_0 \
        -D __DXIL__ \
        -o "${SHADER_DIR}/DXIL/${SHADER_NAME}.vert.dxil"
fi

if [ "$DO_FRAG" = true ]; then
    compile_or_fail "Failed to compile fragment shader to DXIL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry fs_main \
        -matrix-layout-column-major \
        -stage fragment \
        -target dxil \
        -profile sm_6_0 \
        -D __DXIL__ \
        -o "${SHADER_DIR}/DXIL/${SHADER_NAME}.frag.dxil"
fi

# ── DXBC ─────────────────────────────────────────────────────────────────────

if [ "$DO_VERT" = true ]; then
    compile_or_fail "Failed to compile vertex shader to DXBC" \
        "$SLANGC" "$SHADER_FILE" \
        -entry vs_main \
        -matrix-layout-column-major \
        -target dxbc \
        -profile vs_5_1 \
        -o "${SHADER_DIR}/DXBC/${SHADER_NAME}.vert.dxbc"
fi

if [ "$DO_FRAG" = true ]; then
    compile_or_fail "Failed to compile fragment shader to DXBC" \
        "$SLANGC" "$SHADER_FILE" \
        -entry fs_main \
        -matrix-layout-column-major \
        -target dxbc \
        -profile ps_5_1 \
        -o "${SHADER_DIR}/DXBC/${SHADER_NAME}.frag.dxbc"
fi

# ── GLSL Desktop (direct from Slang) ─────────────────────────────────────────

if [ "$DO_VERT" = true ]; then
    compile_or_fail "Failed to compile vertex shader to GLSL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry vs_main \
        -stage vertex \
        -target glsl \
        -profile glsl_450 \
        -D USE_COMBINED_SAMPLER \
        -D __GLSL__ \
        -o "${SHADER_DIR}/GLSL/Desktop/${SHADER_NAME}.vert.glsl"
fi

if [ "$DO_FRAG" = true ]; then
    compile_or_fail "Failed to compile fragment shader to GLSL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry fs_main \
        -stage fragment \
        -target glsl \
        -profile glsl_450 \
        -D USE_COMBINED_SAMPLER \
        -D __GLSL__ \
        -o "${SHADER_DIR}/GLSL/Desktop/${SHADER_NAME}.frag.glsl"
fi

# ── SPIR-V ───────────────────────────────────────────────────────────────────

if [ "$DO_VERT" = true ]; then
    compile_or_fail "Failed to compile vertex shader to SPIR-V" \
        "$SLANGC" "$SHADER_FILE" \
        -entry vs_main \
        -fvk-use-entrypoint-name \
        -matrix-layout-column-major \
        -stage vertex \
        -target spirv \
        -profile spirv_1_5 \
        -D __SPIRV__ \
        -o "${SHADER_DIR}/SPIRV/${SHADER_NAME}.vert.spv"
fi

if [ "$DO_FRAG" = true ]; then
    compile_or_fail "Failed to compile fragment shader to SPIR-V" \
        "$SLANGC" "$SHADER_FILE" \
        -entry fs_main \
        -fvk-use-entrypoint-name \
        -matrix-layout-column-major \
        -stage fragment \
        -target spirv \
        -profile spirv_1_5 \
        -D __SPIRV__ \
        -o "${SHADER_DIR}/SPIRV/${SHADER_NAME}.frag.spv"
fi

# ── GLSL ES (via spirv-cross) ────────────────────────────────────────────────
# Disabled, mirroring build_shader.bat: the cross-compiled output needs
# per-shader interface renames that don't generalize. Re-enable with a
# spirv-cross invocation tuned to the shader at hand.
#
# if command -v spirv-cross &> /dev/null; then
#     SPIRV_CROSS="spirv-cross"
# elif [ -n "$VULKAN_SDK" ] && [ -f "$VULKAN_SDK/bin/spirv-cross" ]; then
#     SPIRV_CROSS="$VULKAN_SDK/bin/spirv-cross"
# fi
#
# if [ -n "$SPIRV_CROSS" ] && [ "$DO_VERT" = true ]; then
#     compile_or_fail "Failed to cross-compile vertex shader to GLSL ES" \
#         "$SPIRV_CROSS" "${SHADER_DIR}/SPIRV/${SHADER_NAME}.vert.spv" \
#         --es \
#         --version 300 \
#         --stage vert \
#         --entry vs_main \
#         --output "${SHADER_DIR}/GLSL/ES/${SHADER_NAME}.vert.glsl"
# fi
#
# if [ -n "$SPIRV_CROSS" ] && [ "$DO_FRAG" = true ]; then
#     compile_or_fail "Failed to cross-compile fragment shader to GLSL ES" \
#         "$SPIRV_CROSS" "${SHADER_DIR}/SPIRV/${SHADER_NAME}.frag.spv" \
#         --es \
#         --version 300 \
#         --stage frag \
#         --entry fs_main \
#         --output "${SHADER_DIR}/GLSL/ES/${SHADER_NAME}.frag.glsl"
# fi

# ── WGSL ─────────────────────────────────────────────────────────────────────

if [ "$DO_VERT" = true ]; then
    compile_or_fail "Failed to compile vertex shader to WGSL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry vs_main \
        -matrix-layout-column-major \
        -stage vertex \
        -target wgsl \
        -D __WGSL__ \
        -o "${SHADER_DIR}/WGSL/${SHADER_NAME}.vert.wgsl"
fi

if [ "$DO_FRAG" = true ]; then
    compile_or_fail "Failed to compile fragment shader to WGSL" \
        "$SLANGC" "$SHADER_FILE" \
        -entry fs_main \
        -matrix-layout-column-major \
        -stage fragment \
        -target wgsl \
        -D __WGSL__ \
        -o "${SHADER_DIR}/WGSL/${SHADER_NAME}.frag.wgsl"
fi

if [ "$SHADER_ERROR" = true ]; then
    echo "Some shader compilations failed"
    exit 1
fi

exit 0
