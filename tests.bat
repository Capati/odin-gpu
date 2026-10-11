@echo off
setlocal

set FAILED=0

if not "%~1"=="" (
    call :scan "%~f1"
    goto :done
)

for %%R in (
    tests
	gpu
	gpu/allocator
	gpu/small_vec
	utils/gltf
	utils/tobj
) do call :scan "%%~fR"

:done
if %FAILED% neq 0 (
    echo.
    echo %FAILED% packages failed
    exit /b 1
)
exit /b 0

:scan
call :run "%~1"
for /r "%~1" /d %%D in (*) do call :run "%%~fD"
exit /b 0

:run
if not exist "%~1\*_tests.odin" exit /b 0
echo === %~1
odin test "%~1"
if errorlevel 1 set /a FAILED+=1
exit /b 0
