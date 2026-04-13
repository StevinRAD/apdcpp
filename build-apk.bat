@echo off
echo ========================================
echo   BUILD APK FLUTTER - CMD MODE
echo ========================================
echo.

REM Cek apakah sudah run as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Harap run sebagai Administrator!
    echo Klik kanan file ini -^> Run as administrator
    pause
    exit /b 1
)

echo [1/5] Menutup aplikasi yang memakan RAM...
taskkill /f /im "Code.exe" >nul 2>&1
taskkill /f /im "idea64.exe" >nul 2>&1
taskkill /f /im "studio64.exe" >nul 2>&1
echo     - Selesai
echo.

echo [2/5] Navigasi ke folder project...
cd /d "%~dp0"
echo     - Folder: %CD%
echo.

echo [3/5] Membersihkan cache...
call flutter clean
echo     - Selesai
echo.

echo [4/5] Download dependencies...
call flutter pub get
echo     - Selesai
echo.

echo [5/5] Building APK...
echo Pilih build type:
echo   1. APK Universal (satu file, ukuran besar)
echo   2. APK Split Per-ABI (3 file, ukuran lebih kecil)
echo.
set /p choice="Masukkan pilihan (1/2): "

if "%choice%"=="1" (
    echo     - Building APK Universal...
    call flutter build apk --release
) else if "%choice%"=="2" (
    echo     - Building APK Split Per-ABI...
    call flutter build apk --release --split-per-abi
) else (
    echo [ERROR] Pilihan tidak valid!
    pause
    exit /b 1
)

if %errorLevel% equ 0 (
    echo.
    echo ========================================
    echo   BUILD SUCCESS!
    echo ========================================
    echo Lokasi APK: build\app\outputs\flutter-apk\
    echo.
    echo Membuka folder output...
    explorer "build\app\outputs\flutter-apk"
) else (
    echo.
    echo ========================================
    echo   BUILD FAILED!
    echo ========================================
    echo Error code: %errorLevel%
)

echo.
pause
