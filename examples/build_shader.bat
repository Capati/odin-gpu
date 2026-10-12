@echo off
setlocal enabledelayedexpansion

:: Check if slangc is available
where slangc.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
	if "%VULKAN_SDK%" == "" (
		echo slangc.exe not found in PATH and VULKAN_SDK not set. Skipping shader compilation.
		goto :skip_shaders
	)
	set "SLANGC=%VULKAN_SDK%\Bin\slangc.exe"
	if not exist "!SLANGC!" (
		echo slangc.exe not found. Skipping shader compilation.
		goto :skip_shaders
	)
) else (
	set "SLANGC=slangc.exe"
)

:: Check if spirv-cross is available (only needed for GLES)
set "SPIRV_CROSS=spirv-cross.exe"
where spirv-cross.exe >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
	if not "%VULKAN_SDK%" == "" (
		set "SPIRV_CROSS=%VULKAN_SDK%\Bin\spirv-cross.exe"
	)
	if not exist "!SPIRV_CROSS!" (
		echo spirv-cross.exe not found. GLSL ES output will be skipped.
		set "SPIRV_CROSS="
	)
)

:: ── Argument parsing ────────────────────────────────────────────────────────

set "SHADER_FILE="
set "SHADER_DIR="
set "TARGETS=all"

:parse_args
if "%~1"=="" goto :args_done

if /i "%~1"=="-t"        ( set "TARGETS=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="--target"  ( set "TARGETS=%~2" & shift & shift & goto :parse_args )
if /i "%~1"=="-h"        goto :usage
if /i "%~1"=="--help"    goto :usage

:: Positional: first = shader file, second = output folder
if "!SHADER_FILE!"=="" (
	set "SHADER_FILE=%~1"
) else if "!SHADER_DIR!"=="" (
	set "SHADER_DIR=%~1"
) else (
	echo Unexpected argument: %~1
	goto :usage
)
shift
goto :parse_args

:args_done

if "!SHADER_FILE!"=="" goto :usage

:: Extract shader name and output directory
for %%F in ("!SHADER_FILE!") do (
	set "SHADER_NAME=%%~nF"
	set "SHADER_SRC_DIR=%%~dpF"
)
if "!SHADER_DIR!"=="" set "SHADER_DIR=!SHADER_SRC_DIR!"

:: Normalize: forward slashes -> backslashes, and ensure a trailing backslash
set "SHADER_DIR=!SHADER_DIR:/=\!"
if not "!SHADER_DIR:~-1!"=="\" set "SHADER_DIR=!SHADER_DIR!\"

:: The file name decides the stage:
::   name.vert.slang -> vertex only
::   name.frag.slang -> fragment only
::   anything else   -> both
set "DO_VERT=true"
set "DO_FRAG=true"

set "NAME_TAIL=!SHADER_NAME:~-5!"

if /i "!NAME_TAIL!"==".vert" set "DO_FRAG=false"
if /i "!NAME_TAIL!"==".vert" set "SHADER_NAME=!SHADER_NAME:~0,-5!"

if /i "!NAME_TAIL!"==".frag" set "DO_VERT=false"
if /i "!NAME_TAIL!"==".frag" set "SHADER_NAME=!SHADER_NAME:~0,-5!"

:: ── Resolve target selection ────────────────────────────────────────────────

set "DO_DXIL=false"
set "DO_DXBC=false"
set "DO_GLSL=false"
set "DO_SPIRV=false"
set "DO_WGSL=false"

set "TARGETS_LIST=!TARGETS:,= !"
for %%T in (!TARGETS_LIST!) do (
	set "KNOWN=false"
	if /i "%%T"=="all"   ( set "DO_DXIL=true" & set "DO_DXBC=true" & set "DO_GLSL=true" & set "DO_SPIRV=true" & set "DO_WGSL=true" & set "KNOWN=true" )
	if /i "%%T"=="dxil"  ( set "DO_DXIL=true"  & set "KNOWN=true" )
	if /i "%%T"=="dxbc"  ( set "DO_DXBC=true"  & set "KNOWN=true" )
	if /i "%%T"=="glsl"  ( set "DO_GLSL=true"  & set "KNOWN=true" )
	if /i "%%T"=="spirv" ( set "DO_SPIRV=true" & set "KNOWN=true" )
	if /i "%%T"=="wgsl"  ( set "DO_WGSL=true"  & set "KNOWN=true" )
	if "!KNOWN!"=="false" (
		echo Unknown target: %%T
		goto :usage
	)
)

:: Create output directories (only for the selected targets)
if "!DO_SPIRV!"=="true" if not exist "!SHADER_DIR!SPIRV"        mkdir "!SHADER_DIR!SPIRV"
if "!DO_DXIL!"=="true"  if not exist "!SHADER_DIR!DXIL"         mkdir "!SHADER_DIR!DXIL"
if "!DO_DXBC!"=="true"  if not exist "!SHADER_DIR!DXBC"         mkdir "!SHADER_DIR!DXBC"
if "!DO_GLSL!"=="true"  if not exist "!SHADER_DIR!GLSL\Desktop" mkdir "!SHADER_DIR!GLSL\Desktop"
if "!DO_WGSL!"=="true"  if not exist "!SHADER_DIR!WGSL"         mkdir "!SHADER_DIR!WGSL"

set "SHADER_ERROR=false"

:: ── DXIL ────────────────────────────────────────────────────────────────────

if "!DO_DXIL!"=="true" (
	if "!DO_VERT!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry vs_main ^
			-matrix-layout-column-major ^
			-stage vertex ^
			-target dxil ^
			-profile sm_6_0 ^
			-D __DXIL__ ^
			-o "!SHADER_DIR!DXIL\!SHADER_NAME!.vert.dxil"
		if errorlevel 1 (
			echo Failed to compile vertex shader to DXIL
			set "SHADER_ERROR=true"
		)
	)
	if "!DO_FRAG!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry fs_main ^
			-matrix-layout-column-major ^
			-stage fragment ^
			-target dxil ^
			-profile sm_6_0 ^
			-D __DXIL__ ^
			-o "!SHADER_DIR!DXIL\!SHADER_NAME!.frag.dxil"
		if errorlevel 1 (
			echo Failed to compile fragment shader to DXIL
			set "SHADER_ERROR=true"
		)
	)
)

:: ── DXBC ────────────────────────────────────────────────────────────────────

if "!DO_DXBC!"=="true" (
	if "!DO_VERT!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry vs_main ^
			-matrix-layout-column-major ^
			-target dxbc ^
			-profile vs_5_1 ^
			-o "!SHADER_DIR!DXBC\!SHADER_NAME!.vert.dxbc"
		if errorlevel 1 (
			echo Failed to compile vertex shader to DXBC
			set "SHADER_ERROR=true"
		)
	)
	if "!DO_FRAG!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry fs_main ^
			-matrix-layout-column-major ^
			-target dxbc ^
			-profile ps_5_1 ^
			-o "!SHADER_DIR!DXBC\!SHADER_NAME!.frag.dxbc"
		if errorlevel 1 (
			echo Failed to compile pixel shader to DXBC
			set "SHADER_ERROR=true"
		)
	)
)

:: ── GLSL Desktop (direct from Slang) ────────────────────────────────────────

if "!DO_GLSL!"=="true" (
	if "!DO_VERT!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry vs_main ^
			-stage vertex ^
			-target glsl ^
			-profile glsl_450 ^
			-D USE_COMBINED_SAMPLER ^
			-D __GLSL__ ^
			-o "!SHADER_DIR!GLSL\Desktop\!SHADER_NAME!.vert.glsl"
		if errorlevel 1 (
			echo Failed to compile vertex shader to GLSL
			set "SHADER_ERROR=true"
		)
	)
	if "!DO_FRAG!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry fs_main ^
			-stage fragment ^
			-target glsl ^
			-profile glsl_450 ^
			-D USE_COMBINED_SAMPLER ^
			-D __GLSL__ ^
			-o "!SHADER_DIR!GLSL\Desktop\!SHADER_NAME!.frag.glsl"
		if errorlevel 1 (
			echo Failed to compile fragment shader to GLSL
			set "SHADER_ERROR=true"
		)
	)
)

:: ── SPIR-V ──────────────────────────────────────────────────────────────────

if "!DO_SPIRV!"=="true" (
	if "!DO_VERT!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry vs_main ^
			-fvk-use-entrypoint-name ^
			-matrix-layout-column-major ^
			-stage vertex ^
			-target spirv ^
			-profile spirv_1_5 ^
			-D __SPIRV__ ^
			-o "!SHADER_DIR!SPIRV\!SHADER_NAME!.vert.spv"
		if errorlevel 1 (
			echo Failed to compile vertex shader to SPIR-V
			set "SHADER_ERROR=true"
		)
	)
	if "!DO_FRAG!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry fs_main ^
			-fvk-use-entrypoint-name ^
			-matrix-layout-column-major ^
			-stage fragment ^
			-target spirv ^
			-profile spirv_1_5 ^
			-D __SPIRV__ ^
			-o "!SHADER_DIR!SPIRV\!SHADER_NAME!.frag.spv"
		if errorlevel 1 (
			echo Failed to compile fragment shader to SPIR-V
			set "SHADER_ERROR=true"
		)
	)
)

:: ── GLSL ES (via spirv-cross) ────────────────────────────────────────────────

rem if not "!SPIRV_CROSS!"=="" (
rem 	:: GLSL ES 300 (vertex)
rem 	call "!SPIRV_CROSS!" "!SHADER_DIR!\SPIRV\%SHADER_NAME%.vert.spv" ^
rem 	    --es ^
rem 	    --version 300 ^
rem 	    --stage vert ^
rem 	    --entry vs_main ^
rem 	    --output "!SHADER_DIR!\GLSL\ES\%SHADER_NAME%.vert.glsl"
rem 	if errorlevel 1 (
rem 		echo Failed to cross-compile vertex shader to GLSL ES
rem 		set "SHADER_ERROR=true"
rem 	)

rem 	:: GLSL ES 300 (fragment)
rem 	call "!SPIRV_CROSS!" "!SHADER_DIR!\SPIRV\%SHADER_NAME%.frag.spv" ^
rem 		--es ^
rem 		--version 300 ^
rem 		--stage frag ^
rem 		--entry fs_main ^
rem 		--output "!SHADER_DIR!\GLSL\ES\%SHADER_NAME%.frag.glsl"
rem 	if errorlevel 1 (
rem 		echo Failed to cross-compile fragment shader to GLSL ES
rem 		set "SHADER_ERROR=true"
rem 	)
rem )

:: ── WGSL ────────────────────────────────────────────────

if "!DO_WGSL!"=="true" (
	if "!DO_VERT!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry vs_main ^
			-matrix-layout-column-major ^
			-stage vertex ^
			-target wgsl ^
			-D __WGSL__ ^
			-o "!SHADER_DIR!WGSL\!SHADER_NAME!.vert.wgsl"
		if errorlevel 1 (
			echo Failed to compile vertex shader to WGSL
			set "SHADER_ERROR=true"
		)
	)
	if "!DO_FRAG!"=="true" (
		call "!SLANGC!" "!SHADER_FILE!" ^
			-entry fs_main ^
			-matrix-layout-column-major ^
			-stage fragment ^
			-target wgsl ^
			-D __WGSL__ ^
			-o "!SHADER_DIR!WGSL\!SHADER_NAME!.frag.wgsl"
		if errorlevel 1 (
			echo Failed to compile fragment shader to WGSL
			set "SHADER_ERROR=true"
		)
	)
)

if "!SHADER_ERROR!"=="true" (
	echo Some shader compilations failed
	endlocal & exit /b 1
)
goto :skip_shaders

:usage
echo Usage: %~nx0 ^<relative_path_to_shader.slang^> [output_folder] [-t targets]
echo.
echo   -t, --target   comma-separated: dxil,dxbc,glsl,spirv,wgsl,all   (default: all)
echo.
echo   The stage is taken from the file name:
echo     name.vert.slang  -^> vertex only
echo     name.frag.slang  -^> fragment only
echo     name.slang       -^> both vertex and fragment
echo.
echo Examples:
echo   %~nx0 shaders\textured.frag.slang
echo   %~nx0 shaders\textured.frag.slang out -t spirv
echo   %~nx0 shaders\fixed_size_points.vert.slang out -t spirv,wgsl
endlocal & exit /b 1

:skip_shaders
endlocal
