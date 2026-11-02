@echo off
setlocal EnableExtensions
rem Copies DialogueUI_UALL into a WoW client's AddOns folder. See docs\TESTING.md.
rem
rem   install.bat                    -> _forever_ (default)
rem   install.bat _anniversary_      -> TBC Anniversary, bridge only
rem   install.bat _anniversary_ deps -> also copy UALLF (and Dialogue UI if missing) from _forever_
rem   install.bat _retail_ deps      -> same for Retail
rem
rem The addon is built for Forever only. For another client (testing) the installed copy's TOC
rem also gets that client's own interface number, read from .build.info, or the client would
rem list it as "Incompatible".
rem
rem Set WOW_ROOT to override the install folder. Close the game first: a new addon folder
rem is only picked up when the client starts (a /reload is enough for file changes).

set "WOW_ROOT_DIR=%WOW_ROOT%"
if "%WOW_ROOT_DIR%"=="" set "WOW_ROOT_DIR=C:\Program Files (x86)\World of Warcraft"
set "FLAVOR=%~1"
if "%FLAVOR%"=="" set "FLAVOR=_forever_"
set "DEPS=%~2"

set "SRC=%~dp0DialogueUI_UALL"
set "CLIENT=%WOW_ROOT_DIR%\%FLAVOR%"
set "ADDONS=%CLIENT%\Interface\AddOns"
set "FOREVER_ADDONS=%WOW_ROOT_DIR%\_forever_\Interface\AddOns"

if not exist "%SRC%\DialogueUI_UALL.toc" (
    echo [error] not found: "%SRC%\DialogueUI_UALL.toc"
    goto :fail
)
if not exist "%CLIENT%\.flavor.info" (
    echo [error] "%CLIENT%" is not an installed WoW client ^(no .flavor.info^).
    echo         Installed clients:
    for /d %%D in ("%WOW_ROOT_DIR%\_*_") do if exist "%%D\.flavor.info" echo           %%~nxD
    goto :fail
)
if not exist "%ADDONS%" mkdir "%ADDONS%"

echo Installing DialogueUI_UALL into %FLAVOR% ...
robocopy "%SRC%" "%ADDONS%\DialogueUI_UALL" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1
if errorlevel 8 goto :copyfail

if /i "%FLAVOR%"=="_forever_" goto :check

powershell -NoProfile -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$product = (Get-Content -LiteralPath '%CLIENT%\.flavor.info')[-1].Trim();" ^
  "$rows = Get-Content -LiteralPath '%WOW_ROOT_DIR%\.build.info'; $head = $rows[0].Split('|');" ^
  "$vi = [Array]::FindIndex($head, [Predicate[string]]{ $args[0] -like 'Version!*' });" ^
  "$pi = [Array]::FindIndex($head, [Predicate[string]]{ $args[0] -like 'Product!*' });" ^
  "$row = $rows | Select-Object -Skip 1 | Where-Object { $_.Split('|')[$pi] -eq $product } | Select-Object -First 1;" ^
  "$v = $row.Split('|')[$vi].Split('.'); $iface = [int]$v[0]*10000 + [int]$v[1]*100 + [int]$v[2];" ^
  "$toc = '%ADDONS%\DialogueUI_UALL\DialogueUI_UALL.toc'; $t = [IO.File]::ReadAllText($toc);" ^
  "if ($t -notmatch ('## Interface:[^\n]*\b' + $iface + '\b')) { $t = $t -replace '(## Interface:[^\r\n]*)', ('$1, ' + $iface); [IO.File]::WriteAllText($toc, $t) };" ^
  "Write-Host ('  test copy: interface ' + $iface + ' added to the installed TOC')"
if errorlevel 1 echo [warning] could not read this client's interface number; the addon may show as Incompatible.

if /i not "%DEPS%"=="deps" goto :check

echo Copying UALLF from _forever_ ...
robocopy "%FOREVER_ADDONS%\UALLF" "%ADDONS%\UALLF" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1
if errorlevel 8 goto :copyfail
if not exist "%ADDONS%\DialogueUI\DialogueUI.toc" (
    echo Dialogue UI missing in %FLAVOR%: copying it from _forever_ ...
    robocopy "%FOREVER_ADDONS%\DialogueUI" "%ADDONS%\DialogueUI" /MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1
    if errorlevel 8 goto :copyfail
)

:check
echo.
for %%A in (DialogueUI UALLF DialogueUI_UALL) do (
    if exist "%ADDONS%\%%A\%%A.toc" (
        echo   ok       %%A
    ) else (
        echo   MISSING  %%A   ^(run: install.bat %FLAVOR% deps^)
    )
)
if /i not "%FLAVOR%"=="_forever_" (
    echo.
    echo   Not Forever: UALLF and DialogueUI_UALL are "out of date" here. Tick
    echo   "Load out of date AddOns" in the AddOns list at character select.
)
echo.
echo Done: %ADDONS%\DialogueUI_UALL
if "%~1"=="" pause
exit /b 0

:copyfail
echo [error] robocopy failed ^(code %errorlevel%^). Is the game running or the folder read-only?
:fail
if "%~1"=="" pause
exit /b 1
