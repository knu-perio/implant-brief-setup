@echo off
chcp 65001 >nul
setlocal EnableExtensions DisableDelayedExpansion
rem 임플란트 브리핑 생성기 설치 시작 파일. 사용자 범위만 쓰며 관리자 권한이 필요 없다. 다시 실행해도 안전하다.
rem 결과는 %USERPROFILE%\ImplantBrief_install_log.txt에 이어 쓰고, 끝 줄은 항상 "=== 설치 끝: 성공 ===" 또는 "=== 설치 끝: 실패 ===".
rem 이 파일은 UTF-8(BOM 없음), CRLF 줄바꿈이어야 한다.

set "LOG=%USERPROFILE%\ImplantBrief_install_log.txt"
set "APP=%USERPROFILE%\ImplantBrief"
set "REPO=https://github.com/knu-perio/implant-brief"
set "LOCALGIT=%LOCALAPPDATA%\Programs\Git\cmd\git.exe"
set "GIT="
set "RC=0"

>>"%LOG%" echo --- [%date% %time%] 설치 시작 파일: 폴더 %APP% ---
echo 임플란트 브리핑 설치를 시작합니다. 끝날 때까지 이 창을 닫지 마세요.

rem (1) Git 찾기 → 없으면 winget → 그래도 없으면 GitHub에서 받아 설치
for /f "delims=" %%G in ('"%SystemRoot%\System32\where.exe" git 2^>nul') do if not defined GIT set "GIT=%%G"
if defined GIT goto git_ready
if exist "%LOCALGIT%" set "GIT=%LOCALGIT%"
if defined GIT goto git_ready

call :step "Git 찾기" "실패" "없음 - winget으로 설치합니다"
"%SystemRoot%\System32\where.exe" winget >nul 2>nul
if errorlevel 1 goto git_no_winget
echo Git을 설치하는 중입니다. 몇 분 걸릴 수 있습니다.
winget install -e --id Git.Git --scope user --silent --accept-package-agreements --accept-source-agreements >>"%LOG%" 2>&1
set "RC=%errorlevel%"
if exist "%LOCALGIT%" set "GIT=%LOCALGIT%"
if defined GIT goto git_installed
call :step "Git 설치(winget)" "실패" "종료 코드 %RC%"
goto git_web

:git_no_winget
call :step "Git 설치(winget)" "실패" "winget 없음"

:git_web
echo Git을 GitHub에서 받아 설치하는 중입니다.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; $release=Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/git-for-windows/git/releases/latest' -Headers @{'User-Agent'='ImplantBrief-setup'}; $asset=$release.assets | Where-Object { $_.name -like 'Git-*-64-bit.exe' } | Select-Object -First 1; if (-not $asset) { throw 'no 64-bit.exe asset' }; $file=Join-Path $env:TEMP $asset.name; Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $file; $process=Start-Process -FilePath $file -ArgumentList '/VERYSILENT','/CURRENTUSER','/NORESTART' -Wait -PassThru; exit $process.ExitCode" >>"%LOG%" 2>&1
set "RC=%errorlevel%"
if exist "%LOCALGIT%" set "GIT=%LOCALGIT%"
if defined GIT goto git_installed
call :step "Git 설치(GitHub)" "실패" "종료 코드 %RC%"
goto fail

:git_installed
rem 새로 설치한 Git은 이 창의 PATH에 없으므로 전체 경로로 쓴다.
call :step "Git 설치" "성공" "%GIT%"
goto clone

:git_ready
call :step "Git 찾기" "성공" "%GIT%"

:clone
rem (2) 프로그램 받기
if exist "%APP%\.git" goto clone_exists
echo GitHub 로그인 창이 뜨면 로그인하세요.
"%GIT%" clone "%REPO%" "%APP%" >>"%LOG%" 2>&1
set "RC=%errorlevel%"
if not "%RC%"=="0" goto clone_failed
call :step "프로그램 받기(git clone)" "성공" "%APP%"
goto run_install

:clone_exists
call :step "프로그램 받기(git clone)" "성공" "이미 있음 - %APP%"
goto run_install

:clone_failed
call :step "프로그램 받기(git clone)" "실패" "종료 코드 %RC% - 로그인·인터넷·저장소 권한을 확인하세요. 폴더 %APP%가 이미 있고 비어 있지 않으면 받을 수 없습니다"
goto fail

:run_install
rem (3) 설치 본체. install.ps1이 끝 표시를 직접 쓴다.
if exist "%APP%\tool\install\install.ps1" goto run_install_go
call :step "설치 스크립트 찾기" "실패" "%APP%\tool\install\install.ps1 없음"
goto fail

:run_install_go
call :count_marks
set "BEFORE=%MARKS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%APP%\tool\install\install.ps1"
set "RC=%errorlevel%"
call :count_marks
if not "%MARKS%"=="%BEFORE%" exit /b %RC%
rem install.ps1이 아예 실행되지 못해 끝 표시가 없을 때
call :step "설치 스크립트 실행" "실패" "install.ps1이 끝 표시 없이 끝남(종료 코드 %RC%)"
goto fail

:fail
>>"%LOG%" echo === 설치 끝: 실패 ===
echo 설치하지 못했습니다.
set "IB_TITLE=임플란트 브리핑 설치"
set "IB_MSG=설치하지 못했습니다. 설치를 부탁한 AI에게 결과를 물어보거나, 관리자에게 %%USERPROFILE%%\ImplantBrief_install_log.txt 파일을 보내 주세요."
powershell -NoProfile -Command "Add-Type -AssemblyName System.Windows.Forms; $owner=New-Object System.Windows.Forms.Form; $owner.TopMost=$true; [void][System.Windows.Forms.MessageBox]::Show($owner, $env:IB_MSG, $env:IB_TITLE, 'OK', 'Error')" >nul 2>nul
exit /b 1

:step
>>"%LOG%" echo [%date% %time%] %~1 — %~2 — %~3
echo %~1 — %~2 — %~3
exit /b 0

:count_marks
set "MARKS=0"
if not exist "%LOG%" exit /b 0
rem Git Bash 등에서 PATH의 다른 find가 잡히지 않게 Windows find.exe를 전체 경로로 쓴다.
for /f %%N in ('type "%LOG%" ^| "%SystemRoot%\System32\find.exe" /c "=== "') do set "MARKS=%%N"
exit /b 0
