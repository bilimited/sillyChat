@echo off
setlocal

:: 定义输出目录名称
set OUTPUT_DIR=build_output

:: 获取脚本所在目录，作为项目根目录
set SCRIPT_DIR=%~dp0
cd /d "%SCRIPT_DIR%"

echo.
echo ===========================================
echo   Flutter 一键构建脚本
echo   目标: Android APK Windows EXE
echo ===========================================
echo.

:: 2. 创建输出目录
echo --- 创建输出目录: %OUTPUT_DIR% ---
if exist "%OUTPUT_DIR%" (
    rmdir /s /q "%OUTPUT_DIR%"
)
mkdir "%OUTPUT_DIR%"
if %ERRORLEVEL% NEQ 0 (
    echo 错误: 无法创建输出目录。
    pause
    exit /b %ERRORLEVEL%
)
echo.

:: 3. 构建 Android APK (Release)
echo --- 构建 Android APK (Release) ---
flutter build apk --release
if %ERRORLEVEL% NEQ 0 (
    echo 错误: Android APK 构建失败。
    echo 请确保您的 Android SDK 和 Gradle 配置正确。
    pause
    exit /b %ERRORLEVEL%
)
echo.

:: 4. 复制 Android APK 到输出目录
echo --- 复制 Android APK 到 %OUTPUT_DIR% ---
xcopy /y "build\app\outputs\flutter-apk\app-release.apk" "%OUTPUT_DIR%\"
if %ERRORLEVEL% NEQ 0 (
    echo 警告: 无法复制 Android APK。可能未找到文件。
)
echo.

:: 5. 构建 Windows EXE (Release)
echo --- 构建 Windows EXE (Release) ---
flutter build windows --release
if %ERRORLEVEL% NEQ 0 (
    echo 错误: Windows EXE 构建失败。
    echo 请确保您已安装 C++ 桌面开发工作负载 (Visual Studio)。
    pause
    exit /b %ERRORLEVEL%
)
echo.

:: 6. 复制 Windows 构建产物到输出目录
echo --- 复制 Windows 构建产物到 %OUTPUT_DIR% ---
:: Windows 构建会将所有文件放在 build\windows\x64\runner\Release 目录下
xcopy /e /i /y "build\windows\x64\runner\Release" "%OUTPUT_DIR%\Windows_App"
if %ERRORLEVEL% NEQ 0 (
    echo 警告: 无法复制 Windows 构建产物。可能未找到文件。
)
echo.

echo ===========================================
echo   构建完成！
echo   所有构建产物已保存到: %OUTPUT_DIR%
echo ===========================================
echo.

pause
endlocal