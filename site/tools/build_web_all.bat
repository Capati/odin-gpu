@echo off
rem Build every example for the web and stage each app.wasm into the showcase site.
rem
rem Usage:
rem   tools\build_web_all.bat [release] [only <name>...]
rem
rem Examples:
rem   tools\build_web_all.bat release
rem   tools\build_web_all.bat release only triangle cube
rem
rem Requires: odin on PATH, and staged site files (node site\tools\prep_examples.mjs).
rem Each example is built with the existing examples\build.bat ("web" target),
rem then build\app.wasm is moved to site\public\e\<name>\app.wasm.

setlocal enabledelayedexpansion
set ROOT=%~dp0..\..
set OUT=site
set MODE=
set ONLY=

:parse
if "%~1"=="" goto :parsed
if /i "%~1"=="release" ( set MODE=release & shift & goto :parse )
if /i "%~1"=="only" ( shift & goto :only )
set ONLY=!ONLY! %~1
shift
goto :parse
:only
if "%~1"=="" goto :parsed
set ONLY=!ONLY! %~1
shift
goto :only
:parsed

if "!ONLY!"=="" (
    set LIST_TMP=%TEMP%\odin_gpu_site_list.txt
    node "%ROOT%\site\tools\prep_examples.mjs" --list > "!LIST_TMP!"
)

set FAILED=
set BUILT=0

if "!ONLY!"=="" (
    for /f "usebackq delims=" %%n in ("!LIST_TMP!") do call :build_one %%n
) else (
    for %%n in (!ONLY!) do call :build_one %%n
)

echo [SITE] --- Done: !BUILT! built.
if defined FAILED (
    echo [SITE] --- Failed:!FAILED!
    exit /b 1
)
exit /b 0

:build_one
set NAME=%~1
echo [SITE] --- Building '!NAME!' for web...
pushd "%ROOT%\examples"
if "!MODE!"=="" ( call build.bat !NAME! web ) else ( call build.bat !NAME! web !MODE! )
set ERR=!ERRORLEVEL!
popd
if not "!ERR!"=="0" (
    set FAILED=!FAILED! !NAME!
    exit /b 0
)
if not exist "%ROOT%\examples\build\app.wasm" (
    echo [SITE] --- Missing app.wasm after building '!NAME!'
    set FAILED=!FAILED! !NAME!
    exit /b 0
)
if not exist "%ROOT%\!OUT!\public\e\!NAME!" mkdir "%ROOT%\!OUT!\public\e\!NAME!"
move /Y "%ROOT%\examples\build\app.wasm" "%ROOT%\!OUT!\public\e\!NAME!\app.wasm" >nul
set /a BUILT+=1
echo [SITE] --- Staged public/e/!NAME!/app.wasm
exit /b 0
