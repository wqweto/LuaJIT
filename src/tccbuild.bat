@echo off
rem Script to build LuaJIT with Tiny C Compiler (tcc).

setlocal enabledelayedexpansion
set PATH=C:\Work\Temp\Lua\lua_forum\tcc-0.9.26\win32;%PATH%
(where tcc > nul 2>&1) || goto :FAIL

set LJHOSTCOMPILE=tcc -c -D__GNUC__=4
set LJCOMPILE=tcc -c -D__GNUC__=4
set LJLINK=tcc -L.
set LJMT=mt /nologo
set LJLIB=tiny_libmaker
set DASMDIR=..\dynasm
set DASM=%DASMDIR%\dynasm.lua
set LJDLLNAME=lua51.dll
set LJLIBNAME=luajit.a
set ALL_LIB=lib_base.c lib_math.c lib_bit.c lib_string.c lib_table.c lib_io.c lib_os.c lib_package.c lib_debug.c lib_jit.c lib_ffi.c

%LJHOSTCOMPILE% host\minilua.c
if errorlevel 1 goto :BAD
%LJLINK% -o minilua.exe minilua.o
if errorlevel 1 goto :BAD
if exist minilua.exe.manifest^
  %LJMT% -manifest minilua.exe.manifest -outputresource:minilua.exe

set DASMFLAGS=-D WIN -D JIT -D FFI -D P64
set LJARCH=x64
minilua
if errorlevel 8 goto :X64
set DASMFLAGS=-D WIN -D JIT -D FFI
set LJARCH=x86
:X64
minilua %DASM% -LN %DASMFLAGS% -o host\buildvm_arch.h vm_x86.dasc
if errorlevel 1 goto :BAD

for %%i in (host\buildvm*.c) do %LJHOSTCOMPILE% -I "." -I %DASMDIR% %%i
if errorlevel 1 goto :BAD
call :GLOB buildvm*.o
%LJLINK% -o buildvm.exe %GLOB%
if errorlevel 1 goto :BAD
if exist buildvm.exe.manifest^
  %LJMT% -manifest buildvm.exe.manifest -outputresource:buildvm.exe

buildvm.exe -m elfasm -o lj_vm.tmp
echo> tcc_asm.tmp for line in io.lines() do
echo>>tcc_asm.tmp   if line:find(".section") then os.exit(0) end
echo>>tcc_asm.tmp   io.write(line:gsub("%%.p2align", ".align"):gsub("%%.hidden", "#.hidden"):gsub("%%.L", "_L"):gsub("@PLT", " # @PLT"), "\n")
echo>>tcc_asm.tmp end
minilua.exe tcc_asm.tmp < lj_vm.tmp > lj_vm.S
%LJHOSTCOMPILE% -o lj_vm.o lj_vm.S
if errorlevel 1 goto :BAD
buildvm -m bcdef -o lj_bcdef.h %ALL_LIB%
if errorlevel 1 goto :BAD
buildvm -m ffdef -o lj_ffdef.h %ALL_LIB%
if errorlevel 1 goto :BAD
buildvm -m libdef -o lj_libdef.h %ALL_LIB%
if errorlevel 1 goto :BAD
buildvm -m recdef -o lj_recdef.h %ALL_LIB%
if errorlevel 1 goto :BAD
buildvm -m vmdef -o jit\vmdef.lua %ALL_LIB%
if errorlevel 1 goto :BAD
buildvm -m folddef -o lj_folddef.h lj_opt_fold.c
if errorlevel 1 goto :BAD

if "%1" neq "debug" goto :NODEBUG
shift
set LJCOMPILE=%LJCOMPILE% -DLUA_USE_APICHECK -DLUA_USE_ASSERT -g
set LJLINK=%LJLINK% -g
:NODEBUG
if "%1"=="amalg" goto :AMALGDLL
if "%1"=="static" goto :STATIC
for %%i in (lj_*.c lib_*.c) do %LJCOMPILE% -DLUA_BUILD_AS_DLL %%i
if errorlevel 1 goto :BAD
call :GLOB lj_*.o lib_*.o
%LJLINK% -shared -o %LJDLLNAME% %GLOB%
if errorlevel 1 goto :BAD
set LJLINKOPT=-l%LJDLLNAME:~,-4%
goto :MTDLL
:STATIC
for %%i in (lj_*.c lib_*.c) do %LJCOMPILE% %%i
if errorlevel 1 goto :BAD
call :GLOB lj_*.o lib_*.o
%LJLIB% %LJLIBNAME% %GLOB%
if errorlevel 1 goto :BAD
set LJLINKOPT=%LJLIBNAME%
goto :MTDLL
:AMALGDLL
%LJCOMPILE% -DLUA_BUILD_AS_DLL ljamalg.c
if errorlevel 1 goto :BAD
%LJLINK% -shared -o %LJDLLNAME% ljamalg.o lj_vm.o
if errorlevel 1 goto :BAD
set LJLINKOPT=-l%LJDLLNAME:~,-4%
:MTDLL
if exist %LJDLLNAME%.manifest^
  %LJMT% -manifest %LJDLLNAME%.manifest -outputresource:%LJDLLNAME%;2

%LJCOMPILE% luajit.c
if errorlevel 1 goto :BAD
%LJLINK% -o luajit.exe luajit.o %LJLINKOPT%
if errorlevel 1 goto :BAD
if exist luajit.exe.manifest^
  %LJMT% -manifest luajit.exe.manifest -outputresource:luajit.exe

del *.obj *.o *.manifest minilua.exe buildvm.exe *.S *.tmp
echo.
echo === Successfully built LuaJIT for Windows/%LJARCH% ===

goto :END
:BAD
echo.
echo *******************************************************
echo *** Build FAILED -- Please check the error messages ***
echo *******************************************************
goto :END
:FAIL
echo Tiny C not found in PATH
goto :END
:GLOB
set GLOB=
for %%i in (%*) do set GLOB=!GLOB! "%%i"
goto :eof
:END
