#!/bin/bash

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

# Create shader output directories
mkdir -p "./GLSL"
mkdir -p "./SPIRV"
mkdir -p "./DXIL"
mkdir -p "./MSL"
mkdir -p "./WGSL"

SHADER_NAME="microui"
SHADER_FILE="${SHADER_NAME}.slang"
SHADER_ERROR=false

# Compile to GLSL (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target glsl \
    -profile glsl_450 \
    -o "./GLSL/${SHADER_NAME}.vert"; then
    echo "Failed to compile vertex shader to GLSL"
    SHADER_ERROR=true
fi

# Compile to GLSL (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target glsl \
    -profile glsl_450 \
    -o "./GLSL/${SHADER_NAME}.frag"; then
    echo "Failed to compile fragment shader to GLSL"
    SHADER_ERROR=true
fi

# Compile to SPIR-V (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target spirv \
    -o "./SPIRV/${SHADER_NAME}.vert.spv"; then
    echo "Failed to compile vertex shader to SPIR-V"
    SHADER_ERROR=true
fi

# Compile to SPIR-V (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target spirv \
    -o "./SPIRV/${SHADER_NAME}.frag.spv"; then
    echo "Failed to compile fragment shader to SPIR-V"
    SHADER_ERROR=true
fi

# Compile to DXIL (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target dxil \
    -profile sm_6_0 \
    -o "./DXIL/${SHADER_NAME}.vert.dxil"; then
    echo "Failed to compile vertex shader to DXIL"
    SHADER_ERROR=true
fi

# Compile to DXIL (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target dxil \
    -profile sm_6_0 \
    -o "./DXIL/${SHADER_NAME}.frag.dxil"; then
    echo "Failed to compile fragment shader to DXIL"
    SHADER_ERROR=true
fi

# Compile to DXBC (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target dxbc \
	-profile vs_5_0 \
    -o "./DXBC/${SHADER_NAME}.vert.dxil"; then
    echo "Failed to compile vertex shader to DXBC"
    SHADER_ERROR=true
fi

# Compile to DXBC (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target dxbc \
	-profile ps_5_0 \
    -o "./DXBC/${SHADER_NAME}.frag.dxil"; then
    echo "Failed to compile fragment shader to DXBC"
    SHADER_ERROR=true
fi

# Compile to MSL (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target metal \
    -fvk-b-shift 0 0 \
    -o "./MSL/${SHADER_NAME}.vert.metal"; then
    echo "Failed to compile vertex shader to MSL"
    SHADER_ERROR=true
fi

# Compile to MSL (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target metal \
    -fvk-b-shift 0 0 \
    -o "./MSL/${SHADER_NAME}.frag.metal"; then
    echo "Failed to compile fragment shader to MSL"
    SHADER_ERROR=true
fi

# Compile to WGSL (vertex)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry vs_main \
    -stage vertex \
    -target wgsl \
    -o "./WGSL/${SHADER_NAME}.vert.wgsl"; then
    echo "Failed to compile vertex shader to WGSL"
    SHADER_ERROR=true
fi

# Compile to WGSL (fragment)
if ! "$SLANGC" "$SHADER_FILE" \
    -entry fs_main \
    -stage fragment \
    -target wgsl \
    -o "./WGSL/${SHADER_NAME}.frag.wgsl"; then
    echo "Failed to compile fragment shader to WGSL"
    SHADER_ERROR=true
fi

if [ "$SHADER_ERROR" = true ]; then
    echo "Some shader compilations failed"
fi
