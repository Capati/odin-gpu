@echo off
setlocal enabledelayedexpansion

:: Set default values
set RELEASE_MODE=false
set BUILD_TARGET=%1
set ERROR_OCCURRED=false
set RUN_AFTER_BUILD=false
set CLEAN_BUILD=false
set WEB_BUILD=false
set COMPILE_SHADERS=false
set ADDITIONAL_ARGS=

:: Check for arguments
set ARG_COUNTER=0
for %%i in (%*) do (
	if !ARG_COUNTER! equ 0 (
		rem Skip the first argument
	) else (
		if /i "%%i"=="release" (
			set RELEASE_MODE=true
		) else if /i "%%i"=="run" (
			set RUN_AFTER_BUILD=true
		) else if /i "%%i"=="clean" (
			set CLEAN_BUILD=true
		) else if /i "%%i"=="web" (
			set WEB_BUILD=true
		) else if /i "%%i"=="shaders" (
			set COMPILE_SHADERS=true
		) else (
			set "ADDITIONAL_ARGS=!ADDITIONAL_ARGS! -define:%%i=true"
		)
	)
	set /a ARG_COUNTER+=1
)

:: Set mode string
if "%RELEASE_MODE%"=="true" (
	set MODE=RELEASE
) else (
	set MODE=DEBUG
)

:: Set build arguments based on target and mode
if "%WEB_BUILD%"=="true" (
	:: Web build arguments
	if "%RELEASE_MODE%"=="true" (
		set ARGS=-o:size -disable-assert -no-bounds-check
	) else (
		set ARGS=-debug
	)
) else (
	:: Native build arguments
	if "%RELEASE_MODE%"=="true" (
		set ARGS=-o:speed -disable-assert -no-bounds-check -subsystem:windows
	) else (
		set ARGS=-debug
	)
)

set OUT=.\build
set OUT_FLAG=-out:%OUT%

:: Check if a build target was provided
if "%BUILD_TARGET%"=="" (
	echo [BUILD] --- Error: Please provide a folder name to build
	echo [BUILD] --- Usage: build.bat folder_name [release] [run] [clean] [web] [shaders]
	echo [BUILD] --- Options:
	echo [BUILD] ---   release  : Build in release mode
	echo [BUILD] ---   run      : Run the executable after building
	echo [BUILD] ---   clean    : Clean build artifacts before building
	echo [BUILD] ---   web      : Build for WebAssembly
	echo [BUILD] ---   shaders  : Force recompile shader
	exit /b 1
)

for %%i in ("%BUILD_TARGET:\=" "%") do set TARGET_NAME=%%~ni

:: Clean build if requested
if "%CLEAN_BUILD%"=="true" (
	echo [BUILD] --- Cleaning artifacts...
	if exist "%OUT%\*.exe" del /F /Q %OUT%\*.exe
	if exist "%OUT%\*.pdb" del /F /Q %OUT%\*.pdb
	if exist "%OUT%\*.wasm" del /F /Q %OUT%\*.wasm
	if exist "%OUT%\wgpu.js" del /F /Q %OUT%\wgpu.js
	if exist "%OUT%\odin.js" del /F /Q %OUT%\odin.js
	if exist "%OUT%\utils.js" del /F /Q %OUT%\utils.js
)

set INITIAL_MEMORY_PAGES=2000
set MAX_MEMORY_PAGES=65536

set PAGE_SIZE=65536
set /a INITIAL_MEMORY_BYTES=%INITIAL_MEMORY_PAGES% * %PAGE_SIZE%
set /a MAX_MEMORY_BYTES=%MAX_MEMORY_PAGES% * %PAGE_SIZE%

:: Get and set ODIN_ROOT environment variable
for /f "delims=" %%i in ('odin.exe root') do set "ODIN_ROOT=%%i"
set "ODIN_ROOT=%ODIN_ROOT:"=%"
if "%ODIN_ROOT:~-1%"=="\" set "ODIN_ROOT=%ODIN_ROOT:~0,-1%"
set ODIN_ROOT=%ODIN_ROOT%

:: Handle web build
if "%WEB_BUILD%"=="true" (
	echo [BUILD] --- Building '%TARGET_NAME%' for web in %MODE% mode...
	call odin build .\%BUILD_TARGET% ^
		%OUT_FLAG%\app.wasm ^
		%ARGS% ^
		-target:js_wasm32 ^
		-extra-linker-flags:"--export-table --import-memory --initial-memory=!INITIAL_MEMORY_BYTES! --max-memory=!MAX_MEMORY_BYTES!"
	if errorlevel 1 (
		echo [BUILD] --- Error building '%TARGET_NAME%' for web
		set ERROR_OCCURRED=true
	) else (
		copy "%ODIN_ROOT%\core\sys\wasm\js\odin.js" "%OUT%\odin.js" >nul
		copy ".\wasm\wgpu.js" "%OUT%\wgpu.js" >nul
		copy ".\wasm\utils.js" "%OUT%\utils.js" >nul
		echo [BUILD] --- Web build completed successfully.
	)
) else (
	:: Build the target (regular build)
	echo [BUILD] --- Building '%TARGET_NAME%' in %MODE% mode...
	call odin build .\%BUILD_TARGET% %ARGS% %ADDITIONAL_ARGS% %OUT_FLAG%\%TARGET_NAME%.exe
	if errorlevel 1 (
		echo [BUILD] --- Error building '%TARGET_NAME%'
		set ERROR_OCCURRED=true
	)
)

:: Check if build was successful
if "%ERROR_OCCURRED%"=="true" (
	echo [BUILD] --- Build process failed.
	exit /b 1
)

echo [BUILD] --- Build process completed successfully.

:: Run after build if requested
if "%RUN_AFTER_BUILD%"=="true" (
	if "%WEB_BUILD%"=="true" (
		echo [BUILD] --- Note: Cannot automatically run web builds. Please serve the build folder.
	) else (
		echo [BUILD] --- Running %TARGET_NAME%...
		pushd build
		call %TARGET_NAME%.exe
		popd
	)
)

exit /b %ERRORLEVEL%
