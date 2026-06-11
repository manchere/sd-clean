@echo off
REM ============================================================================
REM StreamDiffusion-R15 - Automatic Installer
REM ============================================================================
REM This script installs all required dependencies for StreamDiffusion-R15
REM with ControlNet on Windows.
REM
REM Prerequisites:
REM   - Smode Compose installed (provides Python 3.11.9 in the parent folder)
REM   - NVIDIA GPU (RTX 2000/3000/4000/5000) with 8+ GB VRAM
REM   - CUDA 12.9+ installed (recent NVIDIA drivers)
REM   - Internet connection (15-20 GB to download)
REM
REM Recommended GPUs:
REM   - RTX 3060/3070/3080 (12 GB): SD 1.5 + ControlNet
REM   - RTX 4070/4080/4090 (16+ GB): SD 1.5 + SDXL + ControlNet
REM   - RTX 5080/5090 (16+ GB): SD 1.5 + SDXL + ControlNet + StreamV2V
REM ============================================================================

setlocal enabledelayedexpansion
color 0A

echo.
echo ============================================================================
echo  StreamDiffusion-R15 - Automatic Installer
echo ============================================================================
echo.

REM ============================================================================
REM Step 0: Preliminary checks
REM ============================================================================

echo [Step 0/4] Checking prerequisites...
echo.

REM Use the bundled Python 3.11.9 from Smode (same as StartStreamDiffusion.bat)
set "PYTHON_EXE=%CD%\..\python-3_11_9\python.exe"

if not exist "%PYTHON_EXE%" (
    color 0C
    echo [ERROR] Smode Python 3.11.9 not found:
    echo    %PYTHON_EXE%
    echo.
    echo Make sure Smode Compose is installed and this package
    echo is located in Smode's Packages/ directory.
    echo.
    exit /b 1
)

REM Show Python version
for /f "tokens=2" %%i in ('"%PYTHON_EXE%" --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [OK] Python %PYTHON_VERSION% detected (Smode).

REM Check CUDA Toolkit installation (required for torch.compile / Triton)
set "CUDA_FOUND=0"
REM Check CUDA_PATH (set by the CUDA installer)
if defined CUDA_PATH (
    if exist "%CUDA_PATH%\bin\nvcc.exe" set "CUDA_FOUND=1"
)
REM Fallback: look for CUDA 12.9 (installed by winget) in the standard location
if "%CUDA_FOUND%"=="0" (
    if exist "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v12.9\bin\nvcc.exe" set "CUDA_FOUND=1"
)
if "%CUDA_FOUND%"=="0" (
    color 0E
    echo [WARNING] CUDA Toolkit 12.9 not detected.
    echo    torch.compile() and Triton will not work without it.
    echo    Install manually if needed:
    echo      winget install Nvidia.CUDA --version 12.9
    echo    or: https://developer.nvidia.com/cuda-toolkit-archive
    echo    Then re-run this installer.
    echo.
    color 0A
) else (
    echo [OK] CUDA Toolkit detected.
)
echo [INFO] Detailed GPU verification is performed in step 2 (PyTorch CUDA check).

echo.
echo ============================================================================
echo [Step 1/4] Creating Python virtual environment
echo ============================================================================
echo.

REM Check if .venv already exists and is functional
if exist ".venv\Scripts\activate.bat" (
    echo [INFO] Existing virtual environment detected and functional.
    echo [INFO] Using the existing environment.
    goto :skip_venv_creation
)
if exist ".venv" (
    echo [INFO] Corrupt virtual environment detected, removing...
    rmdir /s /q .venv
    echo [OK] Old environment removed.
)

echo [INFO] Installing virtualenv...
"%PYTHON_EXE%" -m pip install virtualenv --quiet
echo [INFO] Creating the virtual environment in .venv...
"%PYTHON_EXE%" -m virtualenv --copies .venv
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to create the virtual environment.
    echo.
    exit /b 1
)
echo [OK] Virtual environment created successfully (Python %PYTHON_VERSION%).

:skip_venv_creation

echo.
echo [INFO] Activating the virtual environment...
call .venv\Scripts\activate.bat
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Failed to activate the virtual environment.
    echo.
    exit /b 1
)
echo [OK] Virtual environment activated.

REM Update pip (after activation, python = venv Python 3.11.9)
echo.
echo [INFO] Updating pip...
python -m pip install --upgrade pip --quiet
if %errorlevel% neq 0 (
    color 0C
    echo [ERROR] Pip upgrade failed.
    echo.
    exit /b 1
)
echo [OK] pip updated.
echo [OK] pip updated

echo.
echo ============================================================================
echo [Step 2/4] Installing dependencies (requirements.txt)
echo ============================================================================
echo.

if not exist "requirements.txt" (
    color 0C
    echo [ERROR] The file requirements.txt is not found.
    echo Make sure you are in the correct directory.
    echo.
    exit /b 1
)

echo [INFO] Installing all dependencies from requirements.txt...
echo [INFO] This step may take 15-20 minutes depending on your connection...
echo.
echo Main packages that will be installed:
echo   - PyTorch 2.10.0 stable + CUDA 12.8 (PyTorch runtime)
echo   - TensorRT 10.9.0.34
echo   - diffusers 0.36.0 (Hugging Face)
echo   - transformers 4.57.1
echo   - controlnet-aux 0.0.10 (Canny, Depth, OpenPose)
echo   - easy-dwpose 1.0.2 (pose detection)
echo   - triton-windows 3.3.1 (torch.compile)
echo.
echo [INFO] Installation will start now. Keep this terminal open...
echo.

python -m pip install -r requirements.txt --verbose

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] Dependency installation failed.
    echo.
    exit /b 1
)

echo.
echo [OK] All dependencies installed successfully.

REM Install easy-dwpose separately (workaround for huggingface_hub<0.25 conflict, API unchanged)
echo.
echo [INFO] Installing easy-dwpose (--no-deps)...
python -m pip install easy-dwpose==1.0.2 --no-deps --quiet
echo [OK] easy-dwpose installed.

REM Install insightface from prebuilt Windows wheel (avoids MSVC build)
REM Required for IP-Adapter FaceID. Incompatible with numpy 2.x.
echo.
echo [INFO] Installing insightface (IP-Adapter FaceID)...
python -m pip install "https://github.com/Gourieff/Assets/raw/main/Insightface/insightface-0.7.3-cp311-cp311-win_amd64.whl" --quiet
echo [OK] insightface installed (numpy 1.26.4 for compatibility).
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] insightface installation failed.
    echo.
    exit /b 1
)

REM Downgrade numpy for insightface compatibility (scipy/opencv remain compatible)
python -m pip install "numpy==1.26.4" --quiet
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] numpy downgrade failed.
    echo.
    exit /b 1
)

REM Verify that PyTorch and CUDA work
echo.
echo [INFO] Verifying PyTorch and CUDA...
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}'); print(f'CUDA version: {torch.version.cuda}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')"

if %errorlevel% neq 0 (
    color 0E
    echo.
    echo [WARNING] PyTorch or CUDA does not appear to be working correctly.
    echo Check your CUDA installation and NVIDIA drivers.
    echo [INFO] Installation will continue...
) else (
    echo [OK] PyTorch and CUDA are working correctly.
)

echo.
echo ============================================================================
echo [Step 3/4] Configuring CUDA binaries and Python headers
echo ============================================================================
echo.

echo [INFO] Configuring torch.compile() and Triton...
echo [INFO] This step copies CUDA tools and required Python headers.
echo.

python setup_venv.py

if %errorlevel% neq 0 (
    color 0E
    echo.
    echo [WARNING] Binary configuration failed partially.
    echo StreamDiffusion will still run, but torch.compile() may not.
    echo [INFO] Installation will continue...
) else (
    echo [OK] CUDA binaries and Python headers configured.
)

echo.
echo ============================================================================
echo [Step 4/4] Installation verification
echo ============================================================================
echo.

echo [INFO] Test de l'installation...
echo.

python verify_install.py

if %errorlevel% neq 0 (
    color 0C
    echo.
    echo [ERROR] Installation test failed.
    echo Check the error messages above.
    echo.
    exit /b 1
)

echo.
echo ============================================================================
echo  Installation Completed Successfully!
echo ============================================================================
echo.
echo Next steps:
echo.
echo 1. Models will be downloaded automatically on first launch:
echo    - Stable Diffusion 1.5 / SDXL (HuggingFace cache)
echo    - DWPose (dw-ll_ucoco_384.onnx, yolox_l.onnx — for OpenPose)
echo.
echo 2. To use in Smode:
echo    - Load the StreamDiffusion-R15 package in Smode
echo    - The SmodeStreamDiffusion.py script will launch automatically
echo.
echo 3. Documentation: see the docs/ folder
echo.
echo Disk space usage: ~12-15 GB total
echo   - .venv environment: ~3 GB
echo   - HuggingFace models cache: ~5-8 GB
echo   - DWPose checkpoints (OpenPose): ~400 MB on first launch
echo.
echo ============================================================================

color 0A
echo.
echo Closing script.
exit /b 0
endlocal
