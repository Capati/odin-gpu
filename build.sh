#!/bin/bash

# Set default values
RELEASE_MODE=false
BUILD_TARGET="$1"
ERROR_OCCURRED=false
RUN_AFTER_BUILD=false
CLEAN_BUILD=false
WEB_BUILD=false
COMPILE_SHADERS=false
ADDITIONAL_ARGS=""

# Check for arguments
ARG_COUNTER=0
for arg in "$@"; do
    if [ $ARG_COUNTER -eq 0 ]; then
        # Skip the first argument
        :
    else
        case "${arg,,}" in
            release)
                RELEASE_MODE=true
                ;;
            run)
                RUN_AFTER_BUILD=true
                ;;
            clean)
                CLEAN_BUILD=true
                ;;
            web)
                WEB_BUILD=true
                ;;
            shaders)
                COMPILE_SHADERS=true
                ;;
            *)
                ADDITIONAL_ARGS="$ADDITIONAL_ARGS -define:$arg=true"
                ;;
        esac
    fi
    ARG_COUNTER=$((ARG_COUNTER + 1))
done

# Set mode string
if [ "$RELEASE_MODE" = true ]; then
    MODE="RELEASE"
else
    MODE="DEBUG"
fi

# Set build arguments based on target and mode
if [ "$WEB_BUILD" = true ]; then
    # Web build arguments
    if [ "$RELEASE_MODE" = true ]; then
        ARGS="-o:size -disable-assert -no-bounds-check"
    else
        ARGS="-debug"
    fi
else
    # Native build arguments
    if [ "$RELEASE_MODE" = true ]; then
        ARGS="-o:speed -disable-assert -no-bounds-check"
    else
        ARGS="-debug"
    fi
fi

OUT="./build"
OUT_FLAG="-out:$OUT"

# Check if a build target was provided
if [ -z "$BUILD_TARGET" ]; then
    echo "[BUILD] --- Error: Please provide a folder name to build"
    echo "[BUILD] --- Usage: ./build.sh folder_name [release] [run] [clean] [web] [shaders]"
    echo "[BUILD] --- Options:"
    echo "[BUILD] ---   release  : Build in release mode"
    echo "[BUILD] ---   run      : Run the executable after building"
    echo "[BUILD] ---   clean    : Clean build artifacts before building"
    echo "[BUILD] ---   web      : Build for WebAssembly"
    echo "[BUILD] ---   shaders  : Force recompile shader"
    exit 1
fi

TARGET_NAME=$(basename "$BUILD_TARGET")

# Clean build if requested
if [ "$CLEAN_BUILD" = true ]; then
    echo "[BUILD] --- Cleaning artifacts..."
    rm -f "$OUT"/*.exe
    rm -f "$OUT"/*.pdb
    rm -f "$OUT"/*.wasm
    rm -f "$OUT"/wgpu.js
    rm -f "$OUT"/odin.js
    rm -f "$OUT"/utils.js
fi

INITIAL_MEMORY_PAGES=2000
MAX_MEMORY_PAGES=65536
PAGE_SIZE=65536
INITIAL_MEMORY_BYTES=$((INITIAL_MEMORY_PAGES * PAGE_SIZE))
MAX_MEMORY_BYTES=$((MAX_MEMORY_PAGES * PAGE_SIZE))

# Get and set ODIN_ROOT environment variable
ODIN_ROOT=$(odin root)
ODIN_ROOT="${ODIN_ROOT%/}"

# Handle web build
if [ "$WEB_BUILD" = true ]; then
    echo "[BUILD] --- Building '$TARGET_NAME' for web in $MODE mode..."
    odin build "./$BUILD_TARGET" \
        "$OUT_FLAG/app.wasm" \
        $ARGS \
        -target:js_wasm32 \
        -extra-linker-flags:"--export-table --import-memory --initial-memory=$INITIAL_MEMORY_BYTES --max-memory=$MAX_MEMORY_BYTES"

    if [ $? -ne 0 ]; then
        echo "[BUILD] --- Error building '$TARGET_NAME' for web"
        ERROR_OCCURRED=true
    else
        # Build gpu.js
        pushd ./wasm > /dev/null
        tsc
        popd > /dev/null
        cp "$ODIN_ROOT/core/sys/wasm/js/odin.js" "$OUT/odin.js"
        cp "./wasm/wgpu.js" "$OUT/wgpu.js"
        cp "./wasm/utils.js" "$OUT/utils.js"
        echo "[BUILD] --- Web build completed successfully."
    fi
else
    # Build the target (regular build)
    echo "[BUILD] --- Building '$TARGET_NAME' in $MODE mode..."
    odin build "./$BUILD_TARGET" $ARGS $ADDITIONAL_ARGS "$OUT_FLAG/$TARGET_NAME"

    if [ $? -ne 0 ]; then
        echo "[BUILD] --- Error building '$TARGET_NAME'"
        ERROR_OCCURRED=true
    fi
fi

# Check if build was successful
if [ "$ERROR_OCCURRED" = true ]; then
    echo "[BUILD] --- Build process failed."
    exit 1
fi

echo "[BUILD] --- Build process completed successfully."

# Run after build if requested
if [ "$RUN_AFTER_BUILD" = true ]; then
    if [ "$WEB_BUILD" = true ]; then
        echo "[BUILD] --- Note: Cannot automatically run web builds. Please serve the build folder."
    else
        echo "[BUILD] --- Running $TARGET_NAME..."
        pushd build > /dev/null
        "./$TARGET_NAME"
        popd > /dev/null
    fi
fi

exit 0
